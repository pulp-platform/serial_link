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
  parameter int ForceSendThresh = NumCredits - 4
) (
  // clock signal
  input  logic                    clk_i,
  // reset on low
  input  logic                    rst_ni,
  // when the receive_valid & receive_ready signals indicate a handshake, this value is used to signal the control
  // unit the amount of credits that where released by the target side: The amount of elements that where consumed
  // from the data queue of the receiving side of data_to_send_out.
  // Should correspond to the amount of credits received by the time the receive_valid/ready handshake occurs.
  // Therefore, these credits might need to be buffered in the receiving data-queue as well.
  input  credit_t                 credits_received_i,
  // Whenever I receive data (receive_valid & receive_ready indicate a handshake) the value is being increased
  // indicating that further packets can be received. In order to work propperly, it is important to correctly
  // connect the receive_ready/valid signals. => See description below.
  output credit_t                 credits_to_send_o,
  // Data which should be sent to the receiver side.
  input  logic [data_width-1:0]   data_to_send_in,
  // Data being sent to the receiver. The control logic of this module may disconnect from the incoming data-stream
  // and tie this value to zero instead in case of the force-send credit scenario. The credits_only_packet signal
  // below contains information on the type of data-packet (valid-data packet or credits-only packet without valid data.)
  output logic [data_width-1:0]   data_to_send_out,
  // The valid signal indicating if the data received on data_to_send_in is valid.
  input  logic                    send_valid_i,
  // Signal coming from the receiver indicating whether or not the receiver is ready to receive data.
  input  logic                    send_ready_i,
  // This signal indicates if the queue (to be provided externally. Should be able to buffer NumCredits amount of data)
  // Has valid data to be released. A handshake with receive_ready_i indicates that a data element has been consumed and
  // therefore will increment the amount of credits that can be returned.
  input  logic                    receive_valid_i,
  // The ready signal of the data sink signaling to the queue that data can be consumed.
  input  logic                    receive_ready_i,
  // Asserted if the data_to_send_out port (and the credits_to_send_o port for that matter) contains valid data.
  output logic                    send_valid_o,
  // Connect to the data source feeding data_to_send_in to signal that new data can be received.
  output logic                    send_ready_o,
  // If a credits only packet is being sent, this value is driven to high. This value might be wrapped into the data-stream
  // to indicate if it also contains valid data or not.
  output logic                    credits_only_packet
);

  import serial_link_pkg::*;

  logic send_normal_packet_d, send_normal_packet_q, send_valid_i_q;
  assign credits_only_packet = ~send_normal_packet_d;

  credit_t credits_available_q, credits_available_d;
  credit_t credits_to_send_q, credits_to_send_d;
  // The hidden counter values are supposed to allow the credits_to_send_o value to be fixed once the output valid signal is
  // driven high, while still keeping track of the incoming credits
  credit_t credits_to_send_hidden_q, credits_to_send_hidden_d;
  logic and_valid_condition, force_send_credits_d, force_send_credits_q;

  assign send_ready_o = send_ready_i & send_normal_packet_d & send_valid_o;
  assign force_send_o = force_send_credits_d;

  // stabalize the output data if a credit_only packet needs to be sent
  always_comb begin : ouput_data_control
    // Though it might be unsusual to read from the D-side, this prevents us from loosing an additional clock cycle
    if (send_normal_packet_d) begin
      data_to_send_out = data_to_send_in;      
    end else begin
      data_to_send_out = '0;
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
  end

  always_comb begin : output_valid_control
    and_valid_condition = 1'b1;
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
    if (credits_available_q == 0) begin
      and_valid_condition = 1'b0;
    end else if (credits_available_q == 1 && credits_to_send_q == 0) begin
      and_valid_condition = 1'b0;
    end
    send_valid_o = (send_valid_i | force_send_credits_d) & and_valid_condition ;
  end

  always_comb begin : credit_counters
    credits_available_d = credits_available_q;
    credits_to_send_d = credits_to_send_q;
    credits_to_send_hidden_d = credits_to_send_hidden_q;
    // I am releasing data, so I can reset the credits that are to be sent back
    if (send_valid_o & send_ready_i) begin
      // I also received a axis_in packet
      if (receive_valid_i & receive_ready_i) begin
        credits_to_send_d = credits_to_send_hidden_q + 1;
        credits_available_d = credits_available_q + credits_received_i - 1;
      // A packet is send, but non was received meanwhile
      end else begin
        credits_to_send_d = credits_to_send_hidden_q;
        credits_available_d = credits_available_q - 1;
      end
      credits_to_send_hidden_d = '0;
    end else begin
      // If an axis_in packet arives I regain available credits
      if (receive_valid_i & receive_ready_i) begin
        credits_available_d = credits_available_q + credits_received_i;
        // The packet was consumed, so I can signal to the other side that we now have free credits
        if (send_valid_o) begin
          credits_to_send_hidden_d = credits_to_send_hidden_q + 1;
        end else begin
          credits_to_send_d = credits_to_send_q + 1;
        end
      end
    end
  end

  assign credits_to_send_o = credits_to_send_q;

  /////////////////////
  //    FlipFlops    //
  ///////////////////// 

  `FF(credits_available_q, credits_available_d, NumCredits)
  `FF(credits_to_send_q, credits_to_send_d, 0)
  `FF(credits_to_send_hidden_q, credits_to_send_hidden_d, 0)
  // This is additional logic to prevent datapackages from being stalled in case of a force send.
  // By removing all the force_send_credits_q related parts, this additional logic might be removed...
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
