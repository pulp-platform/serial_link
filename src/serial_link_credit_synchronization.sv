`include "common_cells/registers.svh"
`include "common_cells/assertions.svh"

// Can be used to implement credit-based synchronization or control the dataflow over virtual channels.
// Its internal credit coutners are used to control the handshaking interfaces. Therefore, it may be
// used to intercept an existing data line with valid/ready handshaking.
module serial_link_credit_synchronization #(
  parameter  type credit_t        = logic,
  // declare eighter the data_t type or alternatively assign the data-width directly. In the latter case the type will
  // not be considered.
  parameter  type data_t          = logic,
  parameter  int  data_width      = $bits(data_t),
  // For credit-based control flow
  parameter  int  NumCredits      = -1,
  // Force send out credits belonging to the other side
  // after ForceSendThresh is reached
  parameter  int ForceSendThresh  = NumCredits - 4,
  // Assign the number of credits that an outgoing credits_only packet will consume (see credits_only_packet_o port).
  parameter  int CredOnlyConsCred = 1,
  // Alter this parameter, if an outgoing data packet can consume more than 1 credit. This option does not make sense
  // in the normal operation mode, however, is useful in combination with the variable message sizes of the
  // serial_link_data_link. While wider messages might occupy more space in the receiving fifo, narrower packets
  // might only consume one entry of the fifo. Use this parameter in combination with the input pin "req_cred_to_buffer_msg".
  parameter  int MaxCredPerPktOut = 1,

  // dependant parameters: Do not change!
  localparam type credit_decrem_t = logic[$clog2(MaxCredPerPktOut+1)-1:0]
) (
  // clock signal
  input  logic                  clk_i,
  // reset on low
  input  logic                  rst_ni,
  // When receive_cred_i is driven to 1, the internal counter value (available credits) is incremented by the amount
  // signaled by credits_received_i. The port is therewith used to receive credits which are being returned from the
  // other sides serial_link_credit_synchronization (via credits_to_send_o).
  input  credit_t               credits_received_i,
  // Whenever the local input buffer-fifo-queue releases an element, the amount of credits that can be returned to the
  // opposite credit counter module can be incremented. The resulting number of credits is outputed via
  // credits_to_send_o. For further infos see the description of the buffer_queue_out_*_i ports.
  output credit_t               credits_to_send_o,
  // Data which should be sent to the receiver side.
  input  logic [data_width-1:0] data_to_send_i,
  // Data being sent to the receiver. In case of a force-send credit scenario the control logic of this module may
  // disconnect from the incoming data-stream and tie this value to zero instead. The credits_only_packet_o signal
  // below contains information on the type of data-packet (valid-data packet or credits-only packet without valid data.)
  output logic [data_width-1:0] data_to_send_o,
  // The valid signal indicating if the data received on data_to_send_i is valid.
  input  logic                  send_valid_i,
  // Connect to the data source feeding data_to_send_i to signal that new data can be received.
  output logic                  send_ready_o,
  // This signal indicates if the queue (to be provided externally & should be able to buffer NumCredits amount of data)
  // has valid data to be released. A handshake with buffer_queue_out_rdy_i indicates that a data element has been released and
  // new space is available in the fifo-queue.
  input  logic                  buffer_queue_out_val_i,
  // The ready signal of the data sink, signaling to the queue that data can be consumed. Works in combination with
  // buffer_queue_out_val_i, acting as handshaking signals.
  input  logic                  buffer_queue_out_rdy_i,
  // indicates if the number of credits provided via credits_received_i port can be restored and added to available credits.
  input  logic                  receive_cred_i,
  // Asserted if the data_to_send_o port contains valid data. Alternatively, credits-only packets (credits_only_packet_o
  // will be driven to high) might override this value and set the port to valid, even when no valid input data is available.
  output logic                  send_valid_o,
  // Signal coming from the receiver indicating whether or not the receiver is ready to receive data.
  input  logic                  send_ready_i,
  // This port is usually assigned to 1. If the parameter MaxCredPerPktOut is assigned a value larger than 1, however, the
  // pin can signal how many credits are required in order to buffer the outgoing message. This feature is originally intended
  // to be used in the serial_link_data_link to support a more efficient use of credits for variable message sizes.
  input  credit_decrem_t        req_cred_to_buffer_msg,
  // If a credits only packet is being sent, this value is driven to high. This value might be wrapped into the data-stream
  // to indicate if valid data is contained.
  output logic                  credits_only_packet_o,
  // This input can be tied to 1 should it not be required.
  // Intended to specify if the credits_to_send_o port can be forwarded. If the input is set to zero, the
  // credits_to_send_o port can still update its value, but in case of a valid data_transfer (data_to_send_o is sent) the
  // credits are not consumed. This feature is meant to be used if multiple channels are to be
  // arbitrated and send over a virtual channel. In this case, it allows decoupling of the selected channel data and
  // the credits to be sent. For example: I might forward the data of channel 1, but sent the credits info of channel 2.
  input logic                   allow_cred_consume_i,
  // This pin can be used in combination with the above pin. While the previous input blocks
  // credits_to_send_o to be consumed in case of a valid data output handshake, this pin (consume_cred_to_send_i)
  // can force the consumption of the credits. This allows the credits to be consumed, eventhough the data at
  // data_to_send_o is not forwarded (and not handshake between send_valid_o & send_ready_i occurs).
  input logic                   consume_cred_to_send_i
);

  import serial_link_pkg::*;

  logic send_normal_packet_d, send_normal_packet_q, send_valid_i_q;
  credit_decrem_t req_credits_for_msg;
  logic cannot_send_data_but_credits_only;

  credit_t credits_available_q, credits_available_d;
  credit_t credits_to_send_q, credits_to_send_d;
  // The hidden counter values are supposed to allow the credits_to_send_o value to be fixed once the output valid signal is
  // driven high, while still keeping track of the incoming credits
  credit_t credits_to_send_hidden_q, credits_to_send_hidden_d;
  logic force_send_credits, force_send_credits_q;

  credit_decrem_t credits_available_decrement;
  logic credits_to_send_increment, credits_to_send_hidden_increment;
  credit_t credits_available_increment, credits_to_send_offset, credits_to_send_decrement, credits_to_send_hidden_decrement;

  assign send_ready_o          = send_ready_i & send_normal_packet_q & send_valid_o;
  assign credits_to_send_o     = credits_to_send_q;
  assign credits_only_packet_o = ~send_normal_packet_q;


  //////////////////////////
  //  FLOW-CONTROL LOGIC  //
  //////////////////////////

  // stabalize the output data if a credit_only packet needs to be sent
  always_comb begin : ouput_data_control
    // Though it might be unsusual to read from the D-side, this prevents us from loosing an additional clock cycle
    if (credits_only_packet_o) begin
      data_to_send_o = '0;
    end else begin
      data_to_send_o = data_to_send_i;
    end
  end

  // TODO: improve readability of the below code block:
  // feasibility of packet types to be sent
  always_comb begin : can_only_send_credit_only
    cannot_send_data_but_credits_only = '0;
    if ((credits_available_q > req_cred_to_buffer_msg) || ( credits_available_q == req_cred_to_buffer_msg && credits_to_send_q > 0 && allow_cred_consume_i)) begin
      // can send data
    end else begin
      // cannot send data
      if ((credits_available_q > CredOnlyConsCred) || ( credits_available_q == CredOnlyConsCred && credits_to_send_q > 0 && allow_cred_consume_i)) begin
        // can send credits_only
        cannot_send_data_but_credits_only = 1;
      end
    end
  end

  // select if a credits_only packet should be outputed, or if there is valid data to be sent (or credits & data)
  always_comb begin : packet_source_selection
    send_normal_packet_d = send_normal_packet_q;
    if ((~send_valid_i | cannot_send_data_but_credits_only) & force_send_credits) begin
      // When I don't have valid data at the input and I overstepped the ForceSendThreshold, I switch to the credits_only mode.
      // EXCEPTION: When there is valid data at the input and I have force_send_credits=1, but I cannot send the data due to a
      // lack of available credits, I can switch to credit_only packet mode in case such a packet can be forwarded instantly.
      send_normal_packet_d = 0;
    end else begin
      if (send_valid_o & send_ready_i) begin
        // When there are valid input data, or I don't have to force send credits anymore. Meanwhile, I have a valid output handshake.
        // If both of these conditions are met, the normal_packet mode is entered (I don't need to force send credits_only packets)
        send_normal_packet_d = 1;
      end
    end
  end

  // logic block for the output valid signal
  always_comb begin : output_valid_control
    force_send_credits = 1'b0;
    // Send empty packets with credits if there are too many
    // credits to send but no AXI request transaction
    if (credits_to_send_q >= ForceSendThresh) begin
      force_send_credits = 1'b1;
    end
    // There is a potential deadlock situation, when the final credits on the local side
    // are consumed and all the credits from the other side are currently in-flight.
    // To prevent this situation, the last credits are only consumed if credit is also sent back
    // => force the output valid signal to zero if no credits are available or I want to prevent the deadlock situation from above
    send_valid_o = '0;
    if ((credits_available_q > req_credits_for_msg) || ( credits_available_q == req_credits_for_msg && credits_to_send_q > 0 && allow_cred_consume_i)) begin
      send_valid_o = (send_valid_i | credits_only_packet_o);
    end
  end

  // find out how many credits are used when a valid output handshake occurs
  always_comb begin : required_credits_for_msg
    req_credits_for_msg = req_cred_to_buffer_msg;
    if (credits_only_packet_o) begin
      req_credits_for_msg = CredOnlyConsCred;
    end
  end


  ///////////////////////
  //  CREDIT COUNTERS  //
  ///////////////////////

  always_comb begin : available_credit_counter  // => keeps track of the remaining credits
    // When a valid output handshake occurs (and I don't have a credits_only_packet),
    // there are fewer credits available. The decrement value is determined by the required
    // size of the outgoing message in the fifo queue. It is signaled via "req_credits_for_msg"
    credits_available_decrement = '0;
    if (send_valid_o & send_ready_i) begin
      credits_available_decrement = req_credits_for_msg;
    end

    credits_available_increment = '0;
    if (receive_cred_i) begin
      // increment the available credits counter by the amount of credits received.
      credits_available_increment = credits_received_i;
    end
  end

  assign credits_available_d = credits_available_q + credits_available_increment - credits_available_decrement;

  always_comb begin : credits_to_send_counter  // => keeps track of the credits that can be returned (released from the queue)
    credits_to_send_increment = '0;
    credits_to_send_decrement = '0;
    credits_to_send_offset    = '0;

    // There is a valid output handshake or credits are force consumed, allowing the shadow (hidden) counter to be transfered
    if ((send_valid_o & send_ready_i) | (consume_cred_to_send_i & allow_cred_consume_i)) begin
      // The hidden credits are transfered to the visible counter
      credits_to_send_offset = credits_to_send_hidden_q;
    end
    // Credits are only released if they are allowed to be consumed & I have a valid packet or force consume credits.
    if ((send_valid_o & send_ready_i & allow_cred_consume_i) | (consume_cred_to_send_i & allow_cred_consume_i)) begin
      // The counter is decremented by the amount of credits being released
      credits_to_send_decrement = credits_to_send_q;
    end
    // potential increments are only ignored if (send_valid_o & ~send_ready_i) as in this case the hidden counter
    // is incremented instead.
    if (~send_valid_o | (send_valid_o & send_ready_i)) begin
      credits_to_send_increment = (buffer_queue_out_val_i & buffer_queue_out_rdy_i);
    end
  end

  assign credits_to_send_d = credits_to_send_q + credits_to_send_offset + credits_to_send_increment - credits_to_send_decrement;

  always_comb begin : credits_to_send_hidden_counter // => complements the previous counter: used if send_valid_o is asserted
    // When the buffer queue releases one element, I can increment the amount of credits to be returned by one.
    credits_to_send_hidden_increment = '0;
    credits_to_send_hidden_decrement = '0;

    // I don't have a handshake yet, but valid is set to high. Therefore, the hidden counter is being increased instead
    // such as not to change the credits_to_send_o while valid data is being available.
    if (send_valid_o & ~send_ready_i) begin
      // increment if the buffer queue releases an element.
      credits_to_send_hidden_increment = (buffer_queue_out_val_i & buffer_queue_out_rdy_i);
    end

    if ((send_valid_o & send_ready_i) | (consume_cred_to_send_i & allow_cred_consume_i)) begin
      // In the case of a valid data-out handshake, the hidden counter
      // value will be assigned to the visible counter after releasing the packet. Therefore, these assigned credits
      // can be removed from the hidden counter.
      credits_to_send_hidden_decrement = credits_to_send_hidden_q;
    end
  end

  assign credits_to_send_hidden_d = credits_to_send_hidden_q + credits_to_send_hidden_increment - credits_to_send_hidden_decrement;


  //////////////////////
  //    FLIP-FLOPS    //
  //////////////////////

  `FF(credits_available_q, credits_available_d, NumCredits)
  `FF(credits_to_send_q, credits_to_send_d, 0)
  `FF(credits_to_send_hidden_q, credits_to_send_hidden_d, 0)
  `FF(send_normal_packet_q, send_normal_packet_d, 1)


  ////////////////////
  //   ASSERTIONS   //
  ////////////////////

  // The threshold should be at least 1
  `ASSERT_INIT(ForceSendTh, ForceSendThresh > 0)
  `ASSERT(MaxCredits, credits_available_q <= NumCredits)
  `ASSERT(MaxSendCredits, (credits_to_send_q + credits_to_send_hidden_q) <= NumCredits)
  `ASSERT(CredConsParamTooLarge, CredOnlyConsCred < 2**$bits(credit_decrem_t))

endmodule
