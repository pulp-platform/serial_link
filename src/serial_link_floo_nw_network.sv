// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Yannick Baumann <baumanny@student.ethz.ch>
`include "common_cells/assertions.svh"
`include "common_cells/registers.svh"

module serial_link_floo_nw_network
#(
  // If the parameter is set to 1, all the assertion checks within this module will be ignored.
  parameter  bit  IgnoreAssert      = 1'b0,
  parameter  type floo_rsp_t = logic,
  parameter  type floo_req_t = logic,
  parameter  type floo_wide_t       = logic,
  parameter  type axis_req_t        = logic,
  parameter  type axis_rsp_t        = logic
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
  input  floo_wide_t       floo_wide_i,
  output floo_wide_t       floo_wide_o,
  // AXIS channels
    // AXIS outgoing data
  output axis_req_t axis_out_req_o,
  input  axis_rsp_t axis_out_rsp_i,
    // AXIS incoming data
  input  axis_req_t axis_in_req_i,
  output axis_rsp_t axis_in_rsp_o
);

  import noc_bridge_narrow_wide_pkg::*;

  typedef struct packed {
    logic [NarrowFlitDataSize-1:0] flit_data;
    channel_hdr_e hdr;
  } narrow_axis_data_t;

    typedef struct packed {
    logic [WideFlitDataSize-1:0] flit_data;
    channel_hdr_e hdr;
  } wide_axis_data_t;

    typedef struct packed {
    logic [NarrowFlitDataSize-1:0] flit_data;
    channel_hdr_e hdr;
  } axis_data_t;

  selected_channel_type_e selChanType_q, selChanType_d;

  narrow_axis_data_t arbiter_out_payload;
  wide_axis_data_t axis_out_payload, axis_in_payload;
  wide_axis_data_t axis_out_data_reg_out;
  logic axis_out_ready, axis_out_valid;
  logic arbiter_ready_in, arbiter_valid_out;

  // the axis data payload also contains the header bit which is why the flit data width is one
  // bit smaller than the payload
  narrow_axis_data_t narrow_req_i_data, narrow_rsp_i_data;

  ////////////////////////////////////////////////
  //  CONNECT INCOMING FLITS WITH THE AXIS_OUT  //
  ////////////////////////////////////////////////

  // Assignment required to match the data width of the two channels
  // (rr_arb_tree needs equi-size signals)
  assign narrow_req_i_data = { floo_req_i.req, narrow_request  };
  assign narrow_rsp_i_data = { floo_rsp_i.rsp, narrow_response };

  rr_arb_tree #(
    .NumIn     ( 2                  ),
    .DataType  ( narrow_axis_data_t ),
    .ExtPrio   ( 1'b0               ),
    .AxiVldRdy ( 1'b1               ),
    .LockIn    ( 1'b0               )
  ) i_rr_arb_tree (
    .clk_i     ( clk_i                                    ),
    .rst_ni    ( rst_ni                                   ),
    /// Clears the arbiter state. Only used if `ExtPrio` is `1'b0` or `LockIn` is `1'b1`.
    .flush_i   ( 1'b0                                     ),
    /// Input requests arbitration.
    .req_i     ( {floo_req_i.valid, floo_rsp_i.valid} ),
    /* verilator lint_off UNOPTFLAT */
    /// Input request is granted.
    .gnt_o     ( {floo_req_o.ready, floo_rsp_o.ready} ),
    /* verilator lint_on UNOPTFLAT */
    /// Input data for arbitration.
    .data_i    ( {narrow_req_i_data, narrow_rsp_i_data}   ),
    /// Output request is valid.
    .req_o     ( arbiter_valid_out                        ),
    /// Output request is granted.
    .gnt_i     ( arbiter_ready_in                         ),
    /// Output data.
    .data_o    ( {arbiter_out_payload.flit_data, arbiter_out_payload.hdr} ),
    .idx_o     (                                          ),
    .rr_i      (                                          )
  );

  always_comb begin
    selChanType_d    = selChanType_q;
    floo_wide_o.ready     = '0;
    axis_out_valid   = '0;
    arbiter_ready_in = '0;
    axis_out_payload = '0;
    unique case (selChanType_q)
      narrowChan : begin
        axis_out_payload.hdr = arbiter_out_payload.hdr;
        axis_out_payload.flit_data = arbiter_out_payload.flit_data;
        axis_out_valid   = arbiter_valid_out;
        arbiter_ready_in = axis_out_ready;
        if (floo_wide_i.valid & !arbiter_valid_out) begin
          selChanType_d = wideChan;
        end
      end
      wideChan : begin
        axis_out_payload.hdr = wide_channel;
        axis_out_payload.flit_data = floo_wide_i.wide;
        axis_out_valid = floo_wide_i.valid;
        floo_wide_o.ready   = axis_out_ready;
        if ((!floo_wide_i.valid | floo_wide_o.ready) & arbiter_valid_out) begin
          selChanType_d = narrowChan;
        end
      end
      default : /* default */;
    endcase
  end

  `FF(selChanType_q, selChanType_d, narrowChan);

  stream_fifo #(
    .T          ( wide_axis_data_t      ),
    .DEPTH      ( 2                     )
  ) i_axis_out_reg (
    .clk_i      ( clk_i                 ),
    .rst_ni     ( rst_ni                ),
    .flush_i    ( 1'b0                  ),
    .testmode_i ( 1'b0                  ),
    .usage_o    (                       ),
    .valid_i    ( axis_out_valid        ),
    .ready_o    ( axis_out_ready        ),
    .data_i     ( axis_out_payload      ),
    .valid_o    ( axis_out_req_o.tvalid ),
    .ready_i    ( axis_out_rsp_i.tready ),
    .data_o     ( axis_out_data_reg_out )
  );

  assign axis_out_req_o.t.data = axis_out_data_reg_out;
  assign axis_out_req_o.t.strb =
         (axis_out_data_reg_out.hdr == wide_channel) ? WideStrobe : NarrowStrobe;
  assign axis_out_req_o.t.keep = '0;
  assign axis_out_req_o.t.last = '0;
  assign axis_out_req_o.t.id   = '0;
  assign axis_out_req_o.t.dest = '0;
  assign axis_out_req_o.t.user = '0;

  ///////////////////////////////////////////////
  //  CONNECT AXIS_IN WITH THE OUTGOING FLITS  //
  ///////////////////////////////////////////////

  assign axis_in_payload = wide_axis_data_t'(axis_in_req_i.t.data);
  assign axis_in_rsp_o.tready = (floo_req_i.ready & floo_req_o.valid) ||
                                (floo_rsp_i.ready & floo_rsp_o.valid) ||
                                (floo_wide_i.ready & floo_wide_o.valid);
  assign floo_req_o.valid   = (axis_in_payload.hdr == narrow_request) ? axis_in_req_i.tvalid : 0;
  assign floo_rsp_o.valid   = (axis_in_payload.hdr == narrow_response)? axis_in_req_i.tvalid : 0;
  assign floo_wide_o.valid  = (axis_in_payload.hdr == wide_channel) ? axis_in_req_i.tvalid : 0;
  assign floo_req_o.req   = axis_in_payload.flit_data;
  assign floo_rsp_o.rsp   = axis_in_payload.flit_data;
  assign floo_wide_o.wide = axis_in_payload.flit_data;

  // FOR THE TIME BEING THE SIGNALS BELOW ARE IGNORED...
  // assign ??? = axis_in_req_i.t.strb;
  // assign ??? = axis_in_req_i.t.keep;
  // assign ??? = axis_in_req_i.t.last;
  // assign ??? = axis_in_req_i.t.id;
  // assign ??? = axis_in_req_i.t.dest;
  // assign ??? = axis_in_req_i.t.user;

  //////////////////
  //  ASSERTIONS  //
  //////////////////

if (~IgnoreAssert) begin : gen_assertion
  `ASSERT(AxisStable, axis_out_req_o.tvalid & !axis_out_rsp_i.tready |=> $stable(axis_out_req_o.t))
end

endmodule
