`include "common_cells/registers.svh"
`include "common_cells/assertions.svh"

// Can be used to implement credit-base synchronization. It contains the control-logic and is meant to intercept with
// the handshake interface.
module serial_link_credit_synchronization #(
  parameter type credit_t       = logic,
  // declare eighter the data_t type or alternatively assign the data-width directly. In the latter case the type will
  // not be considered.
  parameter type data_t         = logic,
  parameter int  data_width     = $bits(data_t),
  // For credit-based control flow
  parameter int  NumCredits     = -1,
  // Force send out credits belonging to the other side
  // after ForceSendThresh is reached
  parameter int ForceSendThresh = NumCredits - 4,
  // Assign this parameter to one in order to prevent the credit_only_packets from consuming credits when sent out.
  parameter bit CredOnlyPktMode = 1'b0
) (
  // clock signal
  input  logic                    clk_i,
  // reset on low
  input  logic                    rst_ni,
  // when the receive_valid & receive_ready signals indicate a handshake, this value is used to signal the control
  // unit the amount of credits that where released by the target side: The amount of elements that where consumed
  // from the data queue of the receiving side of data_to_send_o.
  // Should correspond to the amount of credits received by the time the receive_valid/ready handshake occurs.
  // Therefore, these credits might need to be buffered in the receiving data-queue as well.
  input  credit_t                 credits_received_i,
  // Whenever I receive data (receive_valid & receive_ready indicate a handshake) the value is being increased
  // indicating that further packets can be received. In order to work propperly, it is important to correctly
  // connect the receive_ready/valid signals. => See description below.
  output credit_t                 credits_to_send_o,
  // Data which should be sent to the receiver side.
  input  logic [data_width-1:0]   data_to_send_i,
  // Data being sent to the receiver. The control logic of this module may disconnect from the incoming data-stream
  // and tie this value to zero instead in case of the force-send credit scenario. The credits_only_packet_o signal
  // below contains information on the type of data-packet (valid-data packet or credits-only packet without valid data.)
  output logic [data_width-1:0]   data_to_send_o,
  // The valid signal indicating if the data received on data_to_send_i is valid.
  input  logic                    send_valid_i,
  // Signal coming from the receiver indicating whether or not the receiver is ready to receive data.
  input  logic                    send_ready_i,
  // TODO: This signal indicates if the queue (to be provided externally & should be able to buffer NumCredits amount of data)
  // has valid data to be released. A handshake with buffer_queue_out_rdy_i indicates that a data element has been consumed and
  // therefore will increment the amount of credits that can be returned.
  input  logic                    buffer_queue_out_val_i,
  // TODO: The ready signal of the data sink signaling to the queue that data can be consumed.
  input  logic                    buffer_queue_out_rdy_i,
  // TODO: add a description
  input  logic                    receive_cred_i,
  // Asserted if the data_to_send_o port (and the credits_to_send_o port for that matter) contains valid data.
  output logic                    send_valid_o,
  // Connect to the data source feeding data_to_send_i to signal that new data can be received.
  output logic                    send_ready_o,
  // If a credits only packet is being sent, this value is driven to high. This value might be wrapped into the data-stream
  // to indicate if it also contains valid data or not.
  output logic                    credits_only_packet_o,
  // Optional input pin: Tie to 1 if not used.
  // Intended to specify if the credits_to_send_o port can be forwarded. If the input is set to zero, the
  // credits_to_send_o port might be updated, but in case of a valid data_transfer (data_to_send_o is sent) the
  // credits are not assumed to be consumed as well. This feature is meant to be used if multiple channels are to be
  // arbitrated and send over a virtual channel. In this case, it allows decoupling of the selected channel data and
  // the credits to be sent. For example: I might forward the data of channel 1, but sent the credits info of channel 2.
  input logic                     allow_cred_consume_i,
  // Optional input pin: This pin can be used in combination with the above optional pin. While the previous pin blocks
  // credits_to_send_o to be consumed in the case of a valid data output handshake, this pin (consume_cred_to_send_i)
  // can signal the consumption of the credits. This allows the credits to be consumed and sent, while the data might
  // not be forwarded.
  input logic                     consume_cred_to_send_i
  // Example usage of the above two pins when having 2 channels to be sent over one physical channel (virtual channel
  // principle): The consume_cred_to_send_i has the data-output-handshake signals of the other channels synch. unit
  // assigned, such that the credits of the respective unit might be consumed in the case of eighter a output handshake
  // of the data-out port of this module, or of the other module. Via the allow_cred_consume_i one can signal which
  // channels credits should be forwarded.
);

  import serial_link_pkg::*;

  logic send_normal_packet_d, send_normal_packet_q, send_valid_i_q;

  credit_t credits_available_q, credits_available_d;
  credit_t credits_to_send_q, credits_to_send_d;
  // The hidden counter values are supposed to allow the credits_to_send_o value to be fixed once the output valid signal is
  // driven high, while still keeping track of the incoming credits
  credit_t credits_to_send_hidden_q, credits_to_send_hidden_d;
  logic force_send_credits_d, force_send_credits_q;

  logic credits_available_decrement, credits_to_send_increment, credits_to_send_hidden_increment;
  credit_t credits_available_increment, credits_to_send_offset, credits_to_send_decrement, credits_to_send_hidden_decrement;

  assign send_ready_o          = send_ready_i & send_normal_packet_d & send_valid_o;
  assign credits_to_send_o     = credits_to_send_q;
  assign credits_only_packet_o = ~send_normal_packet_d;


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

  // whenever I initiate a force_send_credits or I get valid data at the input, I evaluate whether or not
  // to send an empty (credits only) packet.
  always_comb begin : packet_source_selection
    send_normal_packet_d = send_normal_packet_q;
    // (positive & negative) edge detection
    if (force_send_credits_d != force_send_credits_q) begin
      if (send_valid_i) begin
        send_normal_packet_d = 1;
      end else begin
        send_normal_packet_d = 0;
      end
    end else if (send_valid_i & ~send_valid_i_q) begin
      if (force_send_credits_d) begin
        send_normal_packet_d = 0;
      end else begin
        send_normal_packet_d = 1;
      end
    end
    // TODO: remove the below code alternative (does not seem to be correct)
    // send_normal_packet_d = 1;
    // if (~send_valid_i & force_send_credits_d) begin
    //   send_normal_packet_d = 0;
    // end
  end

  always_comb begin : output_valid_control
    force_send_credits_d = 1'b0;
    // Send empty packets with credits if there are too many
    // credits to send but no AXI request transaction
    if (credits_to_send_q >= ForceSendThresh) begin
      force_send_credits_d = 1'b1;
    end
    // There is a potential deadlock situation, when the last credit on the local side
    // is consumed and all the credits from the other side are currently in-flight.
    // To prevent this situation, the last credit is only consumed if credit is also sent back
    // => force the output valid signal to zero if no credits are available or I want to prevent the deadlock situation from above
    send_valid_o = '0;
    if ((credits_available_q > 1) || ( credits_available_q == 1 && credits_to_send_q > 0 && allow_cred_consume_i)) begin
      send_valid_o = (send_valid_i | force_send_credits_d);
    end
  end


  ///////////////////////
  //  CREDIT COUNTERS  //
  ///////////////////////

  always_comb begin : available_credit_counter  // => keeps track of the remaining credits
    // When a valid output handshake occurs, there is one less credit available (decrement counter by 1).
    credits_available_decrement = (send_valid_o & send_ready_i);
    if (CredOnlyPktMode) begin
      if (credits_only_packet_o) begin
        credits_available_decrement = 0;
      end
    end

    credits_available_increment = 0;
    if (receive_cred_i) begin
      // increment the available credits counter by the amount of credits received.
      credits_available_increment = credits_received_i;
    end
  end

  assign credits_available_d = credits_available_q + credits_available_increment - credits_available_decrement;

  always_comb begin : credits_to_send_counter  // => keeps track of the credits that can be returned (released from the queue)
    credits_to_send_increment = '0;
    credits_to_send_offset = '0;
    credits_to_send_decrement = '0;

    // There is a valid output handshake and credits are allowed to be consumed
    if ((send_valid_o & send_ready_i & allow_cred_consume_i) | (consume_cred_to_send_i & allow_cred_consume_i)) begin
      // The hidden credits are transfered to the visible counter
      credits_to_send_offset = credits_to_send_hidden_q;
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

    if ((send_valid_o & send_ready_i & allow_cred_consume_i) | (consume_cred_to_send_i & allow_cred_consume_i)) begin
      // In the case of a valid data-out handshake (and credits are allowed to be consumed), the hidden counter
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
  // This is additional logic to prevent datapackages from being stalled in case of a force send.
  // By removing all the force_send_credits_q related parts, this additional logic could be removed...
  `FF(send_normal_packet_q, send_normal_packet_d, 1)
  // FF for edge detection
  `FF(force_send_credits_q, force_send_credits_d, 0)
  `FF(send_valid_i_q, send_valid_i, 0)


  ////////////////////
  //   ASSERTIONS   //
  ////////////////////

  // The threshold should be larger than 1
  `ASSERT_INIT(ForceSendTh, ForceSendThresh > 1)
  `ASSERT(MaxCredits, credits_available_q <= NumCredits)
  `ASSERT(MaxSendCredits, credits_to_send_q <= NumCredits)

endmodule
