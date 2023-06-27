// Yannick Baumann <baumanny@student.ethz.ch>
`include "common_cells/assertions.svh"
`include "common_cells/registers.svh"

module floo_axis_noc_bridge_narrow_wide
#(
  // If the parameter is set to 1, all the assertion checks within this module will be ignored.
  parameter  bit  ignore_assert     = 1'b0,
  parameter  type narrow_rsp_flit_t = logic,
  parameter  type narrow_req_flit_t = logic,
  parameter  type wide_flit_t       = logic,
  parameter  type axis_req_t        = logic,
  parameter  type axis_rsp_t        = logic
) (
  // global signals
  input  logic      clk_i,
  input  logic      rst_ni,
  // flits from the NoC
    // flits to be sent out
  output narrow_req_flit_t narrow_req_o,
  output narrow_rsp_flit_t narrow_rsp_o,
    // flits to be received
  input  narrow_req_flit_t narrow_req_i,
  input  narrow_rsp_flit_t narrow_rsp_i,
    // wide channels
  input  wide_flit_t       wide_i,
  output wide_flit_t       wide_o,
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

  // the axis data payload also contains the header bit which is why the flit data width is one bit smaller than the payload
  narrow_axis_data_t narrow_req_i_data, narrow_rsp_i_data;

  ////////////////////////////////////////////////
  //  CONNECT INCOMING FLITS WITH THE AXIS_OUT  //
  ////////////////////////////////////////////////

  // Assignment required to match the data width of the two channels (rr_arb_tree needs equi-size signals)
  assign narrow_req_i_data = { narrow_req_i.data, narrow_request  };
  assign narrow_rsp_i_data = { narrow_rsp_i.data, narrow_response };

  rr_arb_tree #(
    .NumIn      ( 2                  ),
    .DataType   ( narrow_axis_data_t ),
    .ExtPrio    ( 1'b0               ),
    .AxiVldRdy  ( 1'b1               ),
    .LockIn     ( 1'b0               )
  ) i_rr_arb_tree (
    .clk_i      ( clk_i                                    ),
    .rst_ni     ( rst_ni                                   ),
    /// Clears the arbiter state. Only used if `ExtPrio` is `1'b0` or `LockIn` is `1'b1`.
    .flush_i    ( 1'b0                                     ),
    /// Input requests arbitration.
    .req_i      ( {narrow_req_i.valid, narrow_rsp_i.valid} ),
    /* verilator lint_off UNOPTFLAT */
    /// Input request is granted.
    .gnt_o      ( {narrow_req_o.ready, narrow_rsp_o.ready} ),
    /* verilator lint_on UNOPTFLAT */
    /// Input data for arbitration.
    .data_i     ( {narrow_req_i_data, narrow_rsp_i_data}   ),
    /// Output request is valid.
    .req_o      ( arbiter_valid_out                        ),
    /// Output request is granted.
    .gnt_i      ( arbiter_ready_in                         ),
    /// Output data.
    .data_o     ( {arbiter_out_payload.flit_data, arbiter_out_payload.hdr} )
  );

  always_comb begin
    selChanType_d = selChanType_q;
    arbiter_ready_in = 0;
    wide_o.ready = 0;
    unique case (selChanType_q)
      narrowChan : begin
        axis_out_payload.hdr = arbiter_out_payload.hdr;
        axis_out_payload.flit_data = arbiter_out_payload.flit_data;
        axis_out_valid   = arbiter_valid_out;
        arbiter_ready_in = axis_out_ready;
        if (wide_i.valid & !arbiter_valid_out) begin
          selChanType_d = wideChan;
        end
      end
      wideChan : begin
        axis_out_payload.hdr = wide_channel;
        axis_out_payload.flit_data = wide_i.data;
        axis_out_valid = wide_i.valid;
        wide_o.ready   = axis_out_ready;
        if ((!wide_i.valid | wide_o.ready) & arbiter_valid_out) begin
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
  assign axis_out_req_o.t.strb = (axis_out_data_reg_out.hdr == wide_channel) ? WideStrobe : NarrowStrobe;
  assign axis_out_req_o.t.keep = '0;
  assign axis_out_req_o.t.last = '0;
  assign axis_out_req_o.t.id   = '0;
  assign axis_out_req_o.t.dest = '0;
  assign axis_out_req_o.t.user = '0;

  ///////////////////////////////////////////////
  //  CONNECT AXIS_IN WITH THE OUTGOING FLITS  //
  ///////////////////////////////////////////////

  assign axis_in_payload      = wide_axis_data_t'(axis_in_req_i.t.data);
  assign axis_in_rsp_o.tready = (narrow_req_i.ready & narrow_req_o.valid) || (narrow_rsp_i.ready & narrow_rsp_o.valid) || (wide_i.ready & wide_o.valid);
  assign narrow_req_o.valid   = (axis_in_payload.hdr == narrow_request) ? axis_in_req_i.tvalid : 0;
  assign narrow_rsp_o.valid   = (axis_in_payload.hdr == narrow_response) ? axis_in_req_i.tvalid : 0;
  assign wide_o.valid         = (axis_in_payload.hdr == wide_channel) ? axis_in_req_i.tvalid : 0;
  assign narrow_req_o.data    = axis_in_payload.flit_data;
  assign narrow_rsp_o.data    = axis_in_payload.flit_data;
  assign wide_o.data          = axis_in_payload.flit_data;

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

  if (~ignore_assert) begin
    `ASSERT(AxisStable, axis_out_req_o.tvalid & !axis_out_rsp_i.tready |=> $stable(axis_out_req_o.t))
  end

endmodule
