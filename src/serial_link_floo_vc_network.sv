// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
//  - Yannick Baumann <baumanny@student.ethz.ch>
`include "common_cells/assertions.svh"

module serial_link_floo_vc_network
#(
  // If the parameter is set to 1, all the assertion checks within this module will be ignored.
  parameter  bit  IgnoreAssert      = 1'b0,
  // If the parameter is set to 1, a set of debug messages will be printed upon arival of data
  // from the axis channel. This feature is temporary and is supposed to ease the developement.
  // It will be removed at a later stage...
  parameter  bit  AllowDebugMsg   = 1'b0,
  parameter  type floo_rsp_t        = logic,
  parameter  type floo_req_t        = logic,
  parameter  type axis_req_t        = logic,
  parameter  type axis_rsp_t        = logic,
  parameter  int  ForceSendThresh   = noc_bridge_pkg::NumCredNocBridge-4,
  // currently this parameter should not be changed!
  parameter  int  NumNocChanPerDir  = 2
) (
  // global signals
  input  logic      clk_i,
  input  logic      rst_ni,
  // flits from the NoC
    // flits to be sent out
  output floo_req_t floo_req_o,
  output floo_rsp_t floo_rsp_o,
    // flits to be received
  input  floo_req_t floo_req_i,
  input  floo_rsp_t floo_rsp_i,
  // AXIS channels
    // AXIS outgoing data
  output axis_req_t axis_out_req_o,
  input  axis_rsp_t axis_out_rsp_i,
    // AXIS incoming data
  input  axis_req_t axis_in_req_i,
  output axis_rsp_t axis_in_rsp_o
);

  import noc_bridge_pkg::*;

  logic axis_out_ready, axis_out_valid;
  logic axis_data_in_req_valid, axis_data_in_rsp_valid;
  logic axis_data_in_req_ready, axis_data_in_rsp_ready;
  logic axis_cred_in_req_valid, axis_cred_in_rsp_valid;

  // data_bits_t req_rsp_queue_in
  axis_packet_t req_rsp_queue_in, req_arbiter_in, rsp_arbiter_in;
  axis_packet_t req_rsp_arbiter_out, req_rsp_axis_out;

  // the axis data payload also contains the header bit which is why the flit data width is
  // one bit smaller than the payload
  flit_data_t req_i_data, rsp_i_data, req_data_synchr_out, rsp_data_synchr_out;
  logic req_valid_synchr_out, rsp_valid_synchr_out, req_ready_synchr_out, rsp_ready_synchr_out;

  bridge_credit_t credits_to_send_req, credits_to_send_rsp;
  logic credits_only_packet_req, credits_only_packet_rsp;
  logic forward_req_credits, forward_rsp_credits;
  logic force_consume_req_credits, force_consume_rsp_credits;

  logic credit_only_pack_val, response_ready, request_ready;
  logic req_read_incoming_credits, rsp_read_incoming_credits;

  flit_req_data_t req_reg_data_in;
  flit_rsp_data_t rsp_reg_data_in;

  ////////////////////////////////////////////////
  //  CONNECT INCOMING FLITS WITH THE AXIS_OUT  //
  ////////////////////////////////////////////////

  // Assignment required to match the data width of the two channels
  // (rr_arb_tree needs equi-size signals)
  assign req_i_data = floo_req_i.req;
  assign rsp_i_data = floo_rsp_i.rsp;

  // Credit channel selection
  always_comb begin
    if (credits_to_send_req > credits_to_send_rsp) begin
      forward_req_credits = 1'b1;
      forward_rsp_credits = 1'b0;
    end else begin
      forward_req_credits = 1'b0;
      forward_rsp_credits = 1'b1;
    end
  end

  serial_link_credit_synchronization #(
    .credit_t               ( bridge_credit_t           ),
    .data_t                 ( flit_data_t               ),
    .NumCredits             ( NumCredNocBridge          ),
    .ForceSendThresh        ( ForceSendThresh           ),
    .CredOnlyConsCred       ( 0                         )
  ) i_synchronization_req (
    .clk_i                  ( clk_i                     ),
    .rst_ni                 ( rst_ni                    ),
    .data_i                 ( req_i_data                ),
    .data_o                 ( req_data_synchr_out       ),
    .credit_send_o          ( credits_to_send_req       ),
    .data_ready_o           ( floo_req_o.ready          ),
    .data_valid_i           ( floo_req_i.valid          ),
    .data_valid_o           ( req_valid_synchr_out      ),
    .data_ready_i           ( req_ready_synchr_out      ),
    .req_cred_to_buffer_msg ( 1'b1                      ),
    .credit_rcvd_i          ( req_rsp_queue_in.credits  ),
    .receive_cred_i         ( req_read_incoming_credits ),
    .buffer_queue_out_val_i ( floo_req_o.valid          ),
    .buffer_queue_out_rdy_i ( floo_req_i.ready          ),
    .credits_only_packet_o  ( credits_only_packet_req   ),
    .allow_cred_consume_i   ( forward_req_credits       ),
    .consume_cred_to_send_i ( force_consume_req_credits )
  );

  assign req_read_incoming_credits = (axis_cred_in_req_valid & axis_in_rsp_o.tready);
  assign force_consume_req_credits =
         axis_out_valid & axis_out_ready & (req_rsp_arbiter_out.credits_hdr == request);

  // TODO: for debugging only. Please remove the always_ff block...
  always_ff @(posedge clk_i) begin
    if (req_read_incoming_credits & AllowDebugMsg) begin
      $display("INFO: received credits for req-channel = %1d", req_rsp_queue_in.credits);
    end
  end

  assign req_arbiter_in.data          = req_data_synchr_out;
  assign req_arbiter_in.data_validity = ~credits_only_packet_req;
  assign req_arbiter_in.credits       =
         (forward_req_credits) ? credits_to_send_req : credits_to_send_rsp;
  assign req_arbiter_in.data_hdr      = request;
  assign req_arbiter_in.credits_hdr   = (forward_req_credits) ? request : response;

  serial_link_credit_synchronization #(
    .credit_t               ( bridge_credit_t           ),
    .data_t                 ( flit_data_t               ),
    .NumCredits             ( NumCredNocBridge         ),
    .ForceSendThresh        ( ForceSendThresh           ),
    .CredOnlyConsCred       ( 0                         )
  ) i_synchronization_rsp (
    .clk_i                  ( clk_i                     ),
    .rst_ni                 ( rst_ni                    ),
    .data_i                 ( rsp_i_data                ),
    .data_o                 ( rsp_data_synchr_out       ),
    .credit_send_o          ( credits_to_send_rsp       ),
    .data_ready_o           ( floo_rsp_o.ready          ),
    .data_valid_i           ( floo_rsp_i.valid          ),
    .data_valid_o           ( rsp_valid_synchr_out      ),
    .data_ready_i           ( rsp_ready_synchr_out      ),
    .req_cred_to_buffer_msg ( 1'b1                      ),
    .credit_rcvd_i          ( req_rsp_queue_in.credits  ),
    .receive_cred_i         ( rsp_read_incoming_credits ),
    .buffer_queue_out_val_i ( floo_rsp_o.valid          ),
    .buffer_queue_out_rdy_i ( floo_rsp_i.ready          ),
    .credits_only_packet_o  ( credits_only_packet_rsp   ),
    .allow_cred_consume_i   ( forward_rsp_credits       ),
    .consume_cred_to_send_i ( force_consume_rsp_credits )
  );

  assign rsp_read_incoming_credits = (axis_cred_in_rsp_valid & axis_in_rsp_o.tready);
  assign force_consume_rsp_credits =
         axis_out_valid & axis_out_ready & (req_rsp_arbiter_out.credits_hdr == response);

  // TODO: for debugging only. Please remove the always_ff block...
  always_ff @(posedge clk_i) begin
    if (rsp_read_incoming_credits & AllowDebugMsg) begin
      $display("INFO: received credits for rsp-channel = %1d", req_rsp_queue_in.credits);
    end
  end

  assign rsp_arbiter_in.data          = rsp_data_synchr_out;
  assign rsp_arbiter_in.data_validity = ~credits_only_packet_rsp;
  assign rsp_arbiter_in.credits       =
         (forward_rsp_credits) ? credits_to_send_rsp : credits_to_send_req;
  assign rsp_arbiter_in.data_hdr      = response;
  assign rsp_arbiter_in.credits_hdr   = (forward_rsp_credits) ? response : request;

  rr_arb_tree #(
    .NumIn      ( NumNocChanPerDir ),
    .DataType   ( axis_packet_t    ),
    .ExtPrio    ( 1'b0             ),
    .AxiVldRdy  ( 1'b1             ),
    .LockIn     ( 1'b0             )
  ) i_rr_arb_tree (
    .clk_i      ( clk_i                                        ),
    .rst_ni     ( rst_ni                                       ),
    // Clears the arbiter state. Only used if `ExtPrio` is `1'b0` or `LockIn` is `1'b1`.
    .flush_i    ( 1'b0                                         ),
    // Input requests arbitration.
    .req_i      ( {req_valid_synchr_out, rsp_valid_synchr_out} ),
    // Input request is granted.
    .gnt_o      ( {req_ready_synchr_out, rsp_ready_synchr_out} ),
    // Input data for arbitration.
    .data_i     ( {req_arbiter_in, rsp_arbiter_in}             ),
    // Output request is valid.
    .req_o      ( axis_out_valid                               ),
    // Output request is granted.
    .gnt_i      ( axis_out_ready                               ),
    // Output data.
    .data_o     ( req_rsp_arbiter_out                          ),
    // Index from which input the data came from.
    // => I don't need the index anymore as the info is contained in the data-line
    .idx_o      (                                              )
  );

  // required for a stable AXIS output
  stream_fifo #(
    .T          ( axis_packet_t         ),
    .DEPTH      ( 2                     )
  ) i_axis_out_reg (
    .clk_i      ( clk_i                 ),
    .rst_ni     ( rst_ni                ),
    .flush_i    ( 1'b0                  ),
    .testmode_i ( 1'b0                  ),
    .usage_o    (                       ),
    .valid_i    ( axis_out_valid        ),
    .ready_o    ( axis_out_ready        ),
    .data_i     ( req_rsp_arbiter_out   ),
    .valid_o    ( axis_out_req_o.tvalid ),
    .ready_i    ( axis_out_rsp_i.tready ),
    .data_o     ( req_rsp_axis_out      )
  );

  assign axis_out_req_o.t.data = {req_rsp_axis_out.data_hdr, req_rsp_axis_out.data};
  assign axis_out_req_o.t.strb = '1;
  assign axis_out_req_o.t.keep = '0;
  assign axis_out_req_o.t.last = '0;
  assign axis_out_req_o.t.id   = '0;
  assign axis_out_req_o.t.dest = '0;
  assign axis_out_req_o.t.user =
         {req_rsp_axis_out.data_validity, req_rsp_axis_out.credits_hdr, req_rsp_axis_out.credits};


  ///////////////////////////////////////////////
  //  CONNECT AXIS_IN WITH THE OUTGOING FLITS  //
  ///////////////////////////////////////////////

  assign {req_rsp_queue_in.data_hdr, req_rsp_queue_in.data} = axis_in_req_i.t.data;
  assign {req_rsp_queue_in.data_validity, req_rsp_queue_in.credits_hdr, req_rsp_queue_in.credits} =
         axis_in_req_i.t.user;

  // TODO: for debugging only. Please remove the always_ff block...
  always_ff @(posedge clk_i) begin
    if (axis_in_req_i.tvalid & axis_in_rsp_o.tready & AllowDebugMsg) begin
      $display("INFO: received axis packet (@%8d) = | %1d | %30d | %1d | %1d | %2d |", $time,
        req_rsp_queue_in.data_hdr, req_rsp_queue_in.data, req_rsp_queue_in.data_validity,
        req_rsp_queue_in.credits_hdr, req_rsp_queue_in.credits);
    end
  end
  // FOR THE TIME BEING THE SIGNALS BELOW ARE IGNORED...
  // assign ??? = axis_in_req_i.t.strb;
  // assign ??? = axis_in_req_i.t.keep;
  // assign ??? = axis_in_req_i.t.last;
  // assign ??? = axis_in_req_i.t.id;
  // assign ??? = axis_in_req_i.t.dest;

  assign axis_data_in_req_valid = (req_rsp_queue_in.data_hdr    == request)  ?
         (axis_in_req_i.tvalid & req_rsp_queue_in.data_validity) : 0;
  assign axis_data_in_rsp_valid = (req_rsp_queue_in.data_hdr    == response) ?
         (axis_in_req_i.tvalid & req_rsp_queue_in.data_validity) : 0;
  assign axis_cred_in_req_valid = (req_rsp_queue_in.credits_hdr == request)  ?
         axis_in_req_i.tvalid : 0;
  assign axis_cred_in_rsp_valid = (req_rsp_queue_in.credits_hdr == response) ?
         axis_in_req_i.tvalid : 0;

  assign request_ready        = (axis_data_in_req_ready & axis_data_in_req_valid);
  assign response_ready       = (axis_data_in_rsp_ready & axis_data_in_rsp_valid);
  assign credit_only_pack_val = (axis_in_req_i.tvalid   & ~req_rsp_queue_in.data_validity);
  assign axis_in_rsp_o.tready = request_ready || response_ready || credit_only_pack_val;

  // Input queue for the req channel.
  stream_fifo #(
    .T          ( flit_req_data_t        ),
    .DEPTH      ( NumCredNocBridge      )
  ) i_axis_in_req_reg (
    .clk_i      ( clk_i                  ),
    .rst_ni     ( rst_ni                 ),
    .flush_i    ( 1'b0                   ),
    .testmode_i ( 1'b0                   ),
    .usage_o    (                        ),
    .valid_i    ( axis_data_in_req_valid ),
    .ready_o    ( axis_data_in_req_ready ),
    .data_i     ( req_reg_data_in        ),
    .valid_o    ( floo_req_o.valid       ),
    .ready_i    ( floo_req_i.ready       ),
    .data_o     ( floo_req_o.req         )
  );
  // size casting to avoid error msg
  assign req_reg_data_in = req_rsp_queue_in.data;

  // Input queue for the rsp channel.
  stream_fifo #(
    .T          ( flit_rsp_data_t   ),
    .DEPTH      ( NumCredNocBridge  )
  ) i_axis_in_rsp_reg (
    .clk_i      ( clk_i                  ),
    .rst_ni     ( rst_ni                 ),
    .flush_i    ( 1'b0                   ),
    .testmode_i ( 1'b0                   ),
    .usage_o    (                        ),
    .valid_i    ( axis_data_in_rsp_valid ),
    .ready_o    ( axis_data_in_rsp_ready ),
    .data_i     ( rsp_reg_data_in        ),
    .valid_o    ( floo_rsp_o.valid       ),
    .ready_i    ( floo_rsp_i.ready       ),
    .data_o     ( floo_rsp_o.rsp         )
  );
  // size casting to avoid error msg
  assign rsp_reg_data_in = req_rsp_queue_in.data;


  //////////////////
  //  ASSERTIONS  //
  //////////////////

if (~IgnoreAssert) begin : gen_assertion
  `ASSERT(AxisStable, axis_out_req_o.tvalid & !axis_out_rsp_i.tready |=> $stable(axis_out_req_o.t))
end

endmodule
