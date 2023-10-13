// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
//  - Yannick Baumann <baumanny@student.ethz.ch>

`include "common_cells/assertions.svh"
`include "common_cells/registers.svh"

module serial_link_floo_nw_vc_network
#(
  parameter  type floo_rsp_t    = logic,
  parameter  type floo_req_t    = logic,
  parameter  type floo_wide_t   = logic,
  parameter  type axis_req_t    = logic,
  parameter  type axis_rsp_t    = logic,
  // Enable if timingpaths between the valid and ready signals of incoming messages is not allowed.
  // Attention: Enabling results in extra area since another register is inserted per channel.
  parameter  bit  CutInput = 1'b0,
  // finde suitable ForceSendThresh margin (do not change line number or ordering!)
  parameter int ForceSendThreshNarrowReq = noc_bridge_narrow_wide_pkg::NumCredNocBridgeNarrowReq-1,
  parameter int ForceSendThreshNarrowRsp = noc_bridge_narrow_wide_pkg::NumCredNocBridgeNarrowRsp-1,
  parameter int ForceSendThreshWideChan  = noc_bridge_narrow_wide_pkg::NumCredNocBridgeWideChan-1
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
  // wide channels
  input  floo_wide_t  floo_wide_i,
  output floo_wide_t  floo_wide_o,
  // AXIS channels
  // AXIS outgoing data
  output axis_req_t axis_out_req_o,
  input  axis_rsp_t axis_out_rsp_i,
  // AXIS incoming data
  input  axis_req_t axis_in_req_i,
  output axis_rsp_t axis_in_rsp_o
);

  import noc_bridge_narrow_wide_pkg::*;

  // axis signals
  logic axis_out_valid, axis_out_ready;
  logic axis_data_in_req_valid, axis_data_in_rsp_valid, axis_data_in_wide_valid;
  logic axis_data_in_req_ready, axis_data_in_rsp_ready, axis_data_in_wide_ready;
  logic axis_cred_in_req_valid, axis_cred_in_rsp_valid, axis_cred_in_wide_valid;

  // axis_in channel selection signals
  logic axis_in_is_cred_only, axis_in_rsp_ready, axis_in_req_ready, axis_in_wide_ready;

  // arbiter signals
  narrow_axis_packet_t narrow_arb_req_in, narrow_arb_rsp_in, narrow_arb_data_out;
  logic narrow_arb_valid_out, narrow_arb_ready_out;
  axis_packet_t wide_arb_wide_in, wide_arb_out;
  axis_packet_t narr_wide_queue_in, narrow_wide_axis_out;

  // narrow credit counter signals in, used for size conversion
  narrow_flit_data_t narrow_req_i_data, narrow_rsp_i_data;

  // credit counter signals out
  narrow_flit_data_t req_data_synchr_out, rsp_data_synchr_out;
  wide_flit_data_t wide_data_synchr_out;
  logic req_valid_synchr_out, rsp_valid_synchr_out, wide_valid_synchr_out;
  logic req_ready_synchr_out, rsp_ready_synchr_out, wide_ready_synchr_out;

  // credit channel selection and control signals
  bridge_credit_t credits_to_send_req, credits_to_send_rsp, credits_to_send_wide;
  logic credits_only_packet_req, credits_only_packet_rsp, credits_only_packet_wide;
  logic forward_req_credits, forward_rsp_credits, forward_wide_credits;
  logic force_consume_req_credits, force_consume_rsp_credits, force_consume_wide_credits;
  logic req_read_incoming_credits, rsp_read_incoming_credits, wide_read_incoming_credits;

  // signals for size casting to avoid error msg
  narrow_flit_req_data_t req_reg_data_in;
  narrow_flit_rsp_data_t rsp_reg_data_in;

  // narrow_wide arbitration state variables
  selected_channel_type_e selChanType_q, selChanType_d;


  ////////////////////////////////////////////////
  //  CONNECT INCOMING FLITS WITH THE AXIS_OUT  //
  ////////////////////////////////////////////////

  // credit channel arbitration
  always_comb begin : credit_channel_arbitration
    if (credits_to_send_rsp>credits_to_send_req & credits_to_send_rsp>credits_to_send_wide) begin
      // forward the credits of the rsp-channel
      forward_req_credits           = 1'b0;
      forward_rsp_credits           = 1'b1;
      forward_wide_credits          = 1'b0;
      narrow_arb_req_in.credits_hdr = narrow_response;
      narrow_arb_rsp_in.credits_hdr = narrow_response;
      wide_arb_wide_in.credits_hdr  = narrow_response;
      narrow_arb_req_in.credits     = credits_to_send_rsp;
      narrow_arb_rsp_in.credits     = credits_to_send_rsp;
      wide_arb_wide_in.credits      = credits_to_send_rsp;
    end else begin
      if (credits_to_send_wide > credits_to_send_req) begin
        // forward the credits of the wide-channel
        forward_req_credits           = 1'b0;
        forward_rsp_credits           = 1'b0;
        forward_wide_credits          = 1'b1;
        narrow_arb_req_in.credits_hdr = wide_channel;
        narrow_arb_rsp_in.credits_hdr = wide_channel;
        wide_arb_wide_in.credits_hdr  = wide_channel;
        narrow_arb_req_in.credits     = credits_to_send_wide;
        narrow_arb_rsp_in.credits     = credits_to_send_wide;
        wide_arb_wide_in.credits      = credits_to_send_wide;
      end else begin
        // forward the credits of the req-channel
        forward_req_credits           = 1'b1;
        forward_rsp_credits           = 1'b0;
        forward_wide_credits          = 1'b0;
        narrow_arb_req_in.credits_hdr = narrow_request;
        narrow_arb_rsp_in.credits_hdr = narrow_request;
        wide_arb_wide_in.credits_hdr  = narrow_request;
        narrow_arb_req_in.credits     = credits_to_send_req;
        narrow_arb_rsp_in.credits     = credits_to_send_req;
        wide_arb_wide_in.credits      = credits_to_send_req;
      end
    end
  end

  // Assignment required to match the data width of the two channels
  // (rr_arb_tree needs equi-size signals)
  assign narrow_req_i_data = floo_req_i.req;
  assign narrow_rsp_i_data = floo_rsp_i.rsp;


  //-------------------//
  //--NARROW CHANNELS--//
  //-------------------//

  // credit counter req-channel
  serial_link_credit_synchronization #(
    .credit_t               ( bridge_credit_t           ),
    .data_t                 ( narrow_flit_data_t        ),
    .NumCredits             ( NumCredNocBridgeNarrowReq ),
    .ForceSendThresh        ( ForceSendThreshNarrowReq  ),
    .CredOnlyConsCred       ( 0                         ),
    .DontUseShadowCtnr      ( 1                         ),
    .CutInput               ( CutInput      )
  ) i_credit_counter_req (
    .clk_i                  ( clk_i                      ),
    .rst_ni                 ( rst_ni                     ),
    .data_i                 ( narrow_req_i_data          ),
    .data_o                 ( req_data_synchr_out        ),
    .credit_send_o          ( credits_to_send_req        ),
    .data_ready_o           ( floo_req_o.ready           ),
    .data_valid_i           ( floo_req_i.valid           ),
    .data_valid_o           ( req_valid_synchr_out       ),
    .data_ready_i           ( req_ready_synchr_out       ),
    .req_cred_to_buffer_msg ( 1'b1                       ),
    .credit_rcvd_i          ( narr_wide_queue_in.credits ),
    .receive_cred_i         ( req_read_incoming_credits  ),
    .buffer_queue_out_val_i ( floo_req_o.valid           ),
    .buffer_queue_out_rdy_i ( floo_req_i.ready           ),
    .credits_only_packet_o  ( credits_only_packet_req    ),
    .allow_cred_consume_i   ( forward_req_credits        ),
    .consume_cred_to_send_i ( force_consume_req_credits  )
  );

  // force consume the credits to send out (if this credit channel is selected) or
  // restore available credits by consuming incoming credits
  assign req_read_incoming_credits = (axis_cred_in_req_valid & axis_in_rsp_o.tready);
  assign force_consume_req_credits =
         axis_out_valid & axis_out_ready & (wide_arb_out.credits_hdr == narrow_request);

  assign narrow_arb_req_in.data_hdr      = narrow_request;
  assign narrow_arb_req_in.data          = req_data_synchr_out;
  assign narrow_arb_req_in.data_validity = ~credits_only_packet_req;

  // credit counter rsp-channel
  serial_link_credit_synchronization #(
    .credit_t               ( bridge_credit_t           ),
    .data_t                 ( narrow_flit_data_t        ),
    .NumCredits             ( NumCredNocBridgeNarrowRsp ),
    .ForceSendThresh        ( ForceSendThreshNarrowRsp  ),
    .CredOnlyConsCred       ( 0                         ),
    .DontUseShadowCtnr      ( 1                         ),
    .CutInput              ( CutInput      )
  ) i_credit_counter_rsp (
    .clk_i                  ( clk_i                      ),
    .rst_ni                 ( rst_ni                     ),
    .data_i                 ( narrow_rsp_i_data          ),
    .data_o                 ( rsp_data_synchr_out        ),
    .credit_send_o          ( credits_to_send_rsp        ),
    .data_ready_o           ( floo_rsp_o.ready           ),
    .data_valid_i           ( floo_rsp_i.valid           ),
    .data_valid_o           ( rsp_valid_synchr_out       ),
    .data_ready_i           ( rsp_ready_synchr_out       ),
    .req_cred_to_buffer_msg ( 1'b1                       ),
    .credit_rcvd_i          ( narr_wide_queue_in.credits ),
    .receive_cred_i         ( rsp_read_incoming_credits  ),
    .buffer_queue_out_val_i ( floo_rsp_o.valid           ),
    .buffer_queue_out_rdy_i ( floo_rsp_i.ready           ),
    .credits_only_packet_o  ( credits_only_packet_rsp    ),
    .allow_cred_consume_i   ( forward_rsp_credits        ),
    .consume_cred_to_send_i ( force_consume_rsp_credits  )
  );

  // force consume the credits to send out (if this credit channel is selected) or
  // restore available credits by consuming incoming credits
  assign rsp_read_incoming_credits = (axis_cred_in_rsp_valid & axis_in_rsp_o.tready);
  assign force_consume_rsp_credits =
         axis_out_valid & axis_out_ready & (wide_arb_out.credits_hdr == narrow_response);

  assign narrow_arb_rsp_in.data_hdr      = narrow_response;
  assign narrow_arb_rsp_in.data          = rsp_data_synchr_out;
  assign narrow_arb_rsp_in.data_validity = ~credits_only_packet_rsp;


  //----------------//
  //--WIDE CHANNEL--//
  //----------------//

  // credit counter wide-channel
  serial_link_credit_synchronization #(
    .credit_t               ( bridge_credit_t          ),
    .data_t                 ( wide_flit_data_t         ),
    .NumCredits             ( NumCredNocBridgeWideChan ),
    .ForceSendThresh        ( ForceSendThreshWideChan  ),
    .CredOnlyConsCred       ( 0                        ),
    .DontUseShadowCtnr      ( 1                        ),
    .CutInput              ( CutInput     )
  ) i_credit_counter_wide (
    .clk_i                  ( clk_i                      ),
    .rst_ni                 ( rst_ni                     ),
    .data_i                 ( floo_wide_i.wide           ),
    .data_o                 ( wide_data_synchr_out       ),
    .credit_send_o          ( credits_to_send_wide       ),
    .data_ready_o           ( floo_wide_o.ready          ),
    .data_valid_i           ( floo_wide_i.valid          ),
    .data_valid_o           ( wide_valid_synchr_out      ),
    .data_ready_i           ( wide_ready_synchr_out      ),
    .req_cred_to_buffer_msg ( 1'b1                       ),
    .credit_rcvd_i          ( narr_wide_queue_in.credits ),
    .receive_cred_i         ( wide_read_incoming_credits ),
    .buffer_queue_out_val_i ( floo_wide_o.valid          ),
    .buffer_queue_out_rdy_i ( floo_wide_i.ready          ),
    .credits_only_packet_o  ( credits_only_packet_wide   ),
    .allow_cred_consume_i   ( forward_wide_credits       ),
    .consume_cred_to_send_i ( force_consume_wide_credits )
  );

  // force consume the credits to send out (if this credit channel is selected) or
  // restore available credits by consuming incoming credits
  assign wide_read_incoming_credits = (axis_cred_in_wide_valid & axis_in_rsp_o.tready);
  assign force_consume_wide_credits =
         axis_out_valid & axis_out_ready & (wide_arb_out.credits_hdr == wide_channel);

  assign wide_arb_wide_in.data_hdr      = wide_channel;
  assign wide_arb_wide_in.data          = wide_data_synchr_out;
  assign wide_arb_wide_in.data_validity = ~credits_only_packet_wide;

  // arbitrate between the two narrow channels
  rr_arb_tree #(
    .NumIn      ( 2                    ),
    .DataType   ( narrow_axis_packet_t ),
    .ExtPrio    ( 1'b0                 ),
    .AxiVldRdy  ( 1'b1                 ),
    .LockIn     ( 1'b0                 )
  ) i_narrow_arbiter (
    .clk_i      ( clk_i                                        ),
    .rst_ni     ( rst_ni                                       ),
    // Clears the arbiter state. Only used if `ExtPrio` is `1'b0` or `LockIn` is `1'b1`.
    .flush_i    ( 1'b0                                         ),
    // Input requests arbitration.
    .req_i      ( {req_valid_synchr_out, rsp_valid_synchr_out} ),
    // Input request is granted.
    .gnt_o      ( {req_ready_synchr_out, rsp_ready_synchr_out} ),
    // Input data for arbitration.
    .data_i     ( {narrow_arb_req_in, narrow_arb_rsp_in}       ),
    // Output request is valid.
    .req_o      ( narrow_arb_valid_out                         ),
    // Output request is granted.
    .gnt_i      ( narrow_arb_ready_out                         ),
    // Output data.
    .data_o     ( narrow_arb_data_out                          ),
    // Index from which input the data came from.
    // => I don't need the index anymore as the info is contained in the data-line
    .idx_o      (                                              ),
    .rr_i       (                                              )
  );

  // arbitrate between the narrow channels and the wide channel
  // (the narrow channels always have priority)
  always_comb begin : narrow_wide_arbitration
    selChanType_d         = selChanType_q;
    wide_arb_out          = '0;
    axis_out_valid        = '0;
    narrow_arb_ready_out  = '0;
    wide_ready_synchr_out = '0;
    unique case (selChanType_q)
      narrowChan : begin
        wide_arb_out.data_hdr      = narrow_arb_data_out.data_hdr;
        wide_arb_out.data          = narrow_arb_data_out.data;
        wide_arb_out.data_validity = narrow_arb_data_out.data_validity;
        wide_arb_out.credits_hdr   = narrow_arb_data_out.credits_hdr;
        wide_arb_out.credits       = narrow_arb_data_out.credits;

        axis_out_valid = narrow_arb_valid_out;
        narrow_arb_ready_out = axis_out_ready;
        if (wide_valid_synchr_out & !narrow_arb_valid_out) begin
          selChanType_d = wideChan;
        end
      end
      wideChan : begin
        wide_arb_out.data_hdr      = wide_arb_wide_in.data_hdr;
        wide_arb_out.data          = wide_arb_wide_in.data;
        wide_arb_out.data_validity = wide_arb_wide_in.data_validity;
        wide_arb_out.credits_hdr   = wide_arb_wide_in.credits_hdr;
        wide_arb_out.credits       = wide_arb_wide_in.credits;

        axis_out_valid = wide_valid_synchr_out;
        wide_ready_synchr_out = axis_out_ready;
        if ((!wide_valid_synchr_out | wide_ready_synchr_out) & narrow_arb_valid_out) begin
          selChanType_d = narrowChan;
        end
      end
      default : /* default */;
    endcase
  end

  `FF(selChanType_q, selChanType_d, narrowChan);

  // required for a stable AXIS output
  stream_register #(
    .T          ( axis_packet_t         )
  ) i_axis_out_reg (
    .clk_i      ( clk_i                 ),
    .rst_ni     ( rst_ni                ),
    .clr_i      ( 1'b0                  ),
    .testmode_i ( 1'b0                  ),
    .valid_i    ( axis_out_valid        ),
    .ready_o    ( axis_out_ready        ),
    .data_i     ( wide_arb_out          ),
    .valid_o    ( axis_out_req_o.tvalid ),
    .ready_i    ( axis_out_rsp_i.tready ),
    .data_o     ( narrow_wide_axis_out  )
  );

  // assign signals to the axis_out interface
  assign axis_out_req_o.t.data = {narrow_wide_axis_out.data, narrow_wide_axis_out.data_hdr};
  assign axis_out_req_o.t.strb =
         (narrow_wide_axis_out.data_hdr == wide_channel) ? WideStrobe : NarrowStrobe;
  assign axis_out_req_o.t.keep = '0;
  assign axis_out_req_o.t.last = '0;
  assign axis_out_req_o.t.id   = '0;
  assign axis_out_req_o.t.dest = '0;
  assign axis_out_req_o.t.user =
         {narrow_wide_axis_out.data_validity, narrow_wide_axis_out.credits_hdr,
         narrow_wide_axis_out.credits};


  ///////////////////////////////////////////////
  //  CONNECT AXIS_IN WITH THE OUTGOING FLITS  //
  ///////////////////////////////////////////////

  // unpack axis_in
  assign {narr_wide_queue_in.data, narr_wide_queue_in.data_hdr} = axis_in_req_i.t.data;
  assign {narr_wide_queue_in.data_validity, narr_wide_queue_in.credits_hdr,
         narr_wide_queue_in.credits} = axis_in_req_i.t.user;

  // calculate channel related handshake signals
  assign axis_data_in_req_valid  = (narr_wide_queue_in.data_hdr    == narrow_request)  ?
                                   (axis_in_req_i.tvalid & narr_wide_queue_in.data_validity) : 0;
  assign axis_data_in_rsp_valid  = (narr_wide_queue_in.data_hdr    == narrow_response) ?
                                   (axis_in_req_i.tvalid & narr_wide_queue_in.data_validity) : 0;
  assign axis_data_in_wide_valid = (narr_wide_queue_in.data_hdr    == wide_channel)    ?
                                   (axis_in_req_i.tvalid & narr_wide_queue_in.data_validity) : 0;
  assign axis_cred_in_req_valid  = (narr_wide_queue_in.credits_hdr == narrow_request)  ?
                                   axis_in_req_i.tvalid : 0;
  assign axis_cred_in_rsp_valid  = (narr_wide_queue_in.credits_hdr == narrow_response) ?
                                   axis_in_req_i.tvalid : 0;
  assign axis_cred_in_wide_valid = (narr_wide_queue_in.credits_hdr == wide_channel)    ?
                                   axis_in_req_i.tvalid : 0;

  assign axis_in_req_ready    = (axis_data_in_req_ready  & axis_data_in_req_valid);
  assign axis_in_rsp_ready    = (axis_data_in_rsp_ready  & axis_data_in_rsp_valid);
  assign axis_in_wide_ready   = (axis_data_in_wide_ready & axis_data_in_wide_valid);
  assign axis_in_is_cred_only = (axis_in_req_i.tvalid    & ~narr_wide_queue_in.data_validity);

  assign axis_in_rsp_o.tready =
         axis_in_req_ready || axis_in_rsp_ready || axis_in_wide_ready || axis_in_is_cred_only;


  //-----------------------------------//
  //--ASSIGN AXIS TO CORRECT CHANNELS--//
  //-----------------------------------//

  // Input queue for the req channel.
  stream_fifo #(
    .T          ( narrow_flit_req_data_t    ),
    .DEPTH      ( NumCredNocBridgeNarrowReq )
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
  assign req_reg_data_in = narr_wide_queue_in.data;

  // Input queue for the rsp channel.
  stream_fifo #(
    .T          ( narrow_flit_rsp_data_t    ),
    .DEPTH      ( NumCredNocBridgeNarrowRsp )
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
  assign rsp_reg_data_in = narr_wide_queue_in.data;

  // Input queue for the wide channel.
  stream_fifo #(
    .T          ( wide_flit_data_t         ),
    .DEPTH      ( NumCredNocBridgeWideChan )
  ) i_axis_in_wide_reg (
    .clk_i      ( clk_i                   ),
    .rst_ni     ( rst_ni                  ),
    .flush_i    ( 1'b0                    ),
    .testmode_i ( 1'b0                    ),
    .usage_o    (                         ),
    .valid_i    ( axis_data_in_wide_valid ),
    .ready_o    ( axis_data_in_wide_ready ),
    .data_i     ( narr_wide_queue_in.data ),
    .valid_o    ( floo_wide_o.valid       ),
    .ready_i    ( floo_wide_i.ready       ),
    .data_o     ( floo_wide_o.wide        )
  );


  //////////////////
  //  ASSERTIONS  //
  //////////////////

  `ASSERT(AxisStable, axis_out_req_o.tvalid & !axis_out_rsp_i.tready |=> $stable(axis_out_req_o.t))
  // I need to always be able to receive any incoming axis messages, since the virtual-channel
  // credit counters ought to only send messages of a channel being ready to receive.
  `ASSERT(ChannelNotPermitted, axis_in_req_i.tvalid |-> axis_in_rsp_o.tready)
  // wide channel must be wider than the narrow channel
  `ASSERT(WideSmallerThanNarrow, $bits(axis_packet_t) >= $bits(narrow_axis_packet_t))

endmodule
