// Yannick Baumann <baumanny@student.ethz.ch>
`include "common_cells/assertions.svh"

module floo_axis_noc_bridge
#(
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
  //   logic [$bits(req_flit_t)-3:0] req_data;
  //   logic req_valid;
  //   logic req_ready;
  //   logic [$bits(rsp_flit_t)-3:0] rsp_data;
  //   logic rsp_valid;
  //   logic rsp_ready;
  // } axis_data_t;
  axis_data_t axis_out_payload, axis_in_payload;

  // logic payload_in_ready_rsp, payload_in_ready_req;
  logic req_rsp_in_ready;
  logic req_out_ready, rsp_out_ready;
  localparam int req_data_size = $bits(axis_req_t) - 2;
  localparam int rsp_data_size = $bits(axis_rsp_t) - 2;

  // Connect incoming flits with the AXIS_out
  always_comb begin : axis_payload_packing
    axis_out_payload.req_data  = req_i.data;
    axis_out_payload.req_valid = req_i.valid;
    // axis_out_payload.req_ready = req_i.ready;
    axis_out_payload.rsp_data  = rsp_i.data;
    axis_out_payload.rsp_valid = rsp_i.valid;
    // axis_out_payload.rsp_ready = rsp_i.ready;
  end

  // stream_fifo #(
  //   .T          ( axis_data_t               ),
  //   .DEPTH      ( 2                         )
  // ) i_axis_out_reg (
  //   .clk_i      ( clk_i                     ),
  //   .rst_ni     ( rst_ni                    ),
  //   .flush_i    ( 1'b0                      ),
  //   .testmode_i ( 1'b0                      ),
  //   .usage_o    (                           ),
  //   .valid_i    ( req_i.valid | rsp_i.valid ),
  //   .ready_o    ( req_rsp_in_ready          ),
  //   .data_i     ( axis_out_payload          ),
  //   .valid_o    ( axis_out_req_o.tvalid     ),
  //   .ready_i    ( axis_out_rsp_i.tready     ),
  //   .data_o     ( axis_out_req_o.t.data     )
  // );










  // /// Number of inputs to be arbitrated.
  // parameter int unsigned NumIn      = 2,
  // /// Data width of the payload in bits. Not needed if `DataType` is overwritten.
  // parameter int unsigned DataWidth  = $bits(axis_data_t),
  // /// The `ExtPrio` option allows to override the internal round robin counter via the
  // /// `rr_i` signal. This can be useful in case multiple arbiters need to have
  // /// rotating priorities that are operating in lock-step. If static priority arbitration
  // /// is needed, just connect `rr_i` to '0.
  // ///
  // /// Set to 1'b1 to enable.
  // parameter bit          ExtPrio    = 1'b0,
  // /// If `AxiVldRdy` is set, the req/gnt signals are compliant with the AXI style vld/rdy
  // /// handshake. Namely, upstream vld (req) must not depend on rdy (gnt), as it can be deasserted
  // /// again even though vld is asserted. Enabling `AxiVldRdy` leads to a reduction of arbiter
  // /// delay and area.
  // ///
  // /// Set to `1'b1` to treat req/gnt as vld/rdy.
  // parameter bit          AxiVldRdy  = 1'b1,
  // /// The `LockIn` option prevents the arbiter from changing the arbitration
  // /// decision when the arbiter is disabled. I.e., the index of the first request
  // /// that wins the arbitration will be locked in case the destination is not
  // /// able to grant the request in the same cycle.
  // ///
  // /// Set to `1'b1` to enable.
  // parameter bit          LockIn     = 1'b0,
  // /// When set, ensures that throughput gets distributed evenly between all inputs.
  // ///
  // /// Set to `1'b0` to disable.
  // parameter bit          FairArb    = 1'b1,

  // input  logic                clk_i,
  // input  logic                rst_ni,
  // /// Clears the arbiter state. Only used if `ExtPrio` is `1'b0` or `LockIn` is `1'b1`.
  // input  logic                flush_i,
  // /// Input requests arbitration.
  // input  logic    [NumIn-1:0] req_i,
  // /* verilator lint_off UNOPTFLAT */
  // /// Input request is granted.
  // output logic    [NumIn-1:0] gnt_o,
  // /* verilator lint_on UNOPTFLAT */
  // /// Input data for arbitration.
  // input  DataType [NumIn-1:0] data_i,
  // /// Output request is valid.
  // output logic                req_o,
  // /// Output request is granted.
  // input  logic                gnt_i,
  // /// Output data.
  // output DataType             data_o,
  // /// Index from which input the data came from.
  // output idx_t                idx_o












  assign axis_out_req_o.tvalid = req_i.valid | rsp_i.valid;
  assign axis_out_req_o.t.data = axis_out_payload;
  assign req_rsp_in_ready = axis_out_rsp_i;

  assign req_o.ready = req_rsp_in_ready;
  assign rsp_o.ready = req_rsp_in_ready;
  assign axis_out_req_o.t.strb = '1;
  assign axis_out_req_o.t.keep = '0;
  assign axis_out_req_o.t.last = 0;
  assign axis_out_req_o.t.id   = 0;
  assign axis_out_req_o.t.dest = 0;
  assign axis_out_req_o.t.user = 0;
  
  // Connect AXIS_in with the outgoing flits

  assign axis_in_payload = axis_data_t'(axis_in_req_i.t.data);
  assign axis_in_rsp_o.tready = req_i.ready & rsp_i.ready;
  assign req_o.valid = axis_in_payload.req_valid & axis_in_req_i.tvalid;
  assign rsp_o.valid = axis_in_payload.rsp_valid & axis_in_req_i.tvalid;
  assign req_o.data = axis_in_payload.req_data;
  assign rsp_o.data = axis_in_payload.rsp_data;

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

  `ASSERT(AxisStable, axis_out_req_o.tvalid & !axis_out_rsp_i.tready |=> $stable(axis_out_req_o.t))

endmodule
