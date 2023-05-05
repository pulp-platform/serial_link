// Yannick Baumann <baumanny@student.ethz.ch>
`include "common_cells/assertions.svh"

module floo_axis_noc_bridge
#(
  // If the parameter is set to 1, all the module intern assertion checks will be ignored.
  parameter bit   ignore_assert = 1'b0,
  parameter type  rsp_flit_t    = logic,
  parameter type  req_flit_t    = logic,
  parameter type  axis_req_t    = logic,
  parameter type  axis_rsp_t    = logic,
  parameter type  axis_data_t   = logic
) (
  // global signals
  input  logic      clk_i,
  input  logic      rst_ni,
  // flits from the NoC
    // flits to be sent out
  output req_flit_t req_o,
  output rsp_flit_t rsp_o,
    // flits to be received
  input  req_flit_t req_i,
  input  rsp_flit_t rsp_i,
  // AXIS channels
    // AXIS outgoing data
  output axis_req_t axis_out_req_o,
  input  axis_rsp_t axis_out_rsp_i,
    // AXIS incoming data
  input  axis_req_t axis_in_req_i,
  output axis_rsp_t axis_in_rsp_o
);
  // typedef struct packed {
  //   logic hdr;
  //   logic [FlitDataSize-1:0] flit_data;
  // } axis_payload_t;
  axis_data_t axis_out_payload, axis_in_payload;

  logic [$bits(axis_data_t)-1:0] req_data, rsp_data;

  // Connect incoming flits with the AXIS_out








assign req_data = req_i.data;
assign rsp_data = rsp_i.data;

  rr_arb_tree #(
    .NumIn      ( 2                          ),
    .DataWidth  ( $bits(axis_data_t) -1      ),
    .ExtPrio    ( 1'b0                       ),
    .AxiVldRdy  ( 1'b1                       ),
    .LockIn     ( 1'b0                       )
  ) i_rr_arb_tree (
    .clk_i      ( clk_i                      ),
    .rst_ni     ( rst_ni                     ),
    /// Clears the arbiter state. Only used if `ExtPrio` is `1'b0` or `LockIn` is `1'b1`.
    .flush_i    ( 1'b0                       ),
    /// Input requests arbitration.
    .req_i      ( {req_i.valid, rsp_i.valid} ),
    /* verilator lint_off UNOPTFLAT */
    /// Input request is granted.
    .gnt_o      ( {req_o.ready, rsp_o.ready} ),
    /* verilator lint_on UNOPTFLAT */
    /// Input data for arbitration.
    .data_i     ( {req_data, rsp_data}       ),
    /// Output request is valid.
    .req_o      ( axis_out_req_o.tvalid      ),
    /// Output request is granted.
    .gnt_i      ( axis_out_rsp_i.tready      ),
    /// Output data.
    .data_o     ( axis_out_payload.flit_data ),
    /// Index from which input the data came from.
    .idx_o      ( axis_out_payload.hdr       )
  );

  assign axis_out_req_o.t.data = axis_out_payload;
  assign axis_out_req_o.t.strb = '1;
  assign axis_out_req_o.t.keep = '0;
  assign axis_out_req_o.t.last = 0;
  assign axis_out_req_o.t.id   = 0;
  assign axis_out_req_o.t.dest = 0;
  assign axis_out_req_o.t.user = 0;
  
  // Connect AXIS_in with the outgoing flits

  assign axis_in_payload = axis_data_t'(axis_in_req_i.t.data);
  assign axis_in_rsp_o.tready = req_i.ready & rsp_i.ready;
  assign req_o.valid = (axis_in_payload.hdr == 1'b0) ? axis_in_req_i.tvalid : 0;
  assign rsp_o.valid = (axis_in_payload.hdr == 1'b1) ? axis_in_req_i.tvalid : 0;
  assign req_o.data = axis_in_payload.flit_data;
  assign rsp_o.data = axis_in_payload.flit_data;

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
