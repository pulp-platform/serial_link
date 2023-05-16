// Yannick Baumann <baumanny@student.ethz.ch>
`include "common_cells/assertions.svh"

module floo_axis_noc_bridge_virtual_channels
#(
  // If the parameter is set to 1, all the assertion checks within this module will be ignored.
  parameter  bit   ignore_assert = 1'b0,
  parameter  type  rsp_flit_t    = logic,
  parameter  type  req_flit_t    = logic,
  parameter  type  axis_req_t    = logic,
  parameter  type  axis_rsp_t    = logic,
  parameter  int  flit_data_size   = 1,
  parameter  int  numberOfChannels = 2,

  localparam int unsigned IdxWidth      = unsigned'($clog2(numberOfChannels)),
  localparam type         idx_t         = logic [IdxWidth-1:0],
  localparam int          axis_credits  = 3
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

  typedef enum logic [0:0] {
    response  = 'd0,
    request   = 'd1
  } channel_hdr_e;

  idx_t selected_index;

  typedef struct packed {
    channel_hdr_e hdr;
    logic [flit_data_size-1:0] flit_data;
  } axis_data_t;

  axis_data_t axis_out_payload, axis_in_payload;
  axis_data_t axis_out_data_reg_out;
  logic axis_out_ready, axis_out_valid;
  logic axis_in_req_valid, axis_in_rsp_valid;
  logic axis_in_req_ready, axis_in_rsp_ready;
  localparam int payloadSize = $bits(axis_data_t);
  localparam int req_flit_data_size = $bits(req_flit_t) - 2;
  localparam int rsp_flit_data_size = $bits(rsp_flit_t) - 2;

  // the axis data payload also contains the header bit which is why the flit data width is one bit smaller than the payload
  logic [payloadSize-2:0] req_i_data, rsp_i_data, req_data_synchr_out, rsp_data_synchr_out;
  logic req_valid_synchr_out, rsp_valid_synchr_out, req_ready_synchr_out, rsp_ready_synchr_out;

  ////////////////////////////////////////////////
  //  CONNECT INCOMING FLITS WITH THE AXIS_OUT  //
  ////////////////////////////////////////////////

  // Assignment required to match the data width of the two channels (rr_arb_tree needs equi-size signals)
  assign req_i_data = req_i.data;
  assign rsp_i_data = rsp_i.data;

  serial_link_credit_synchronization #(
    .credit_t           ( logic [$clog2(axis_credits)-1:0] ),
    .data_t             ( logic [payloadSize-2:0] ),
    .NumCredits         ( axis_credits ),
    .ForceSendThresh    ( axis_credits )
  ) i_synchronization_req (
    .clk_i              ( clk_i ),
    .rst_ni             ( rst_ni ),
    // It is likely, that the port size is smaller than the .t.data size. This is because the .t.data line is extended
    // to consist of an integer number of bytes, whereas the port does not have any such restrictions and therefore can
    // be made smaller, without loosing any information...
    .data_to_send_in    ( req_i_data ),
    .data_to_send_out   ( req_data_synchr_out ),
    // towards button (internal)
    .credits_to_send_o  (  ),
    // top
    .send_ready_o       ( req_o.ready ),
    // top
    .send_valid_i       ( req_i.valid ),
    // button
    .send_valid_o       ( req_valid_synchr_out ),
    // button
    .send_ready_i       ( req_ready_synchr_out ),
    .credits_received_i ( '0 ),
    .receive_valid_i    ( '0 ),
    .receive_ready_i    ( '0 )
  );

  serial_link_credit_synchronization #(
    .credit_t           ( logic [$clog2(axis_credits)-1:0] ),
    .data_t             ( logic [payloadSize-2:0] ),
    .NumCredits         ( axis_credits ),
    .ForceSendThresh    ( axis_credits )
  ) i_synchronization_rsp (
    .clk_i              ( clk_i ),
    .rst_ni             ( rst_ni ),
    // It is likely, that the port size is smaller than the .t.data size. This is because the .t.data line is extended
    // to consist of an integer number of bytes, whereas the port does not have any such restrictions and therefore can
    // be made smaller, without loosing any information...
    .data_to_send_in    ( rsp_i_data ),
    .data_to_send_out   ( rsp_data_synchr_out ),
    // towards button (internal)
    .credits_to_send_o  (  ),
    // top
    .send_ready_o       ( rsp_o.ready ),
    // top
    .send_valid_i       ( rsp_i.valid ),
    // button
    .send_valid_o       ( rsp_valid_synchr_out ),
    // button
    .send_ready_i       ( rsp_ready_synchr_out ),
    .credits_received_i ( '0 ),
    .receive_valid_i    ( '0 ),
    .receive_ready_i    ( '0 )
  );

  rr_arb_tree #(
    .NumIn      ( 2                          ),
    .DataWidth  ( payloadSize - 1            ),
    .ExtPrio    ( 1'b0                       ),
    .AxiVldRdy  ( 1'b1                       ),
    .LockIn     ( 1'b0                       )
  ) i_rr_arb_tree (
    .clk_i      ( clk_i                      ),
    .rst_ni     ( rst_ni                     ),
    /// Clears the arbiter state. Only used if `ExtPrio` is `1'b0` or `LockIn` is `1'b1`.
    .flush_i    ( 1'b0                       ),
    /// Input requests arbitration.
    .req_i      ( {req_valid_synchr_out, rsp_valid_synchr_out} ),
    /* verilator lint_off UNOPTFLAT */
    /// Input request is granted.
    .gnt_o      ( {req_ready_synchr_out, rsp_ready_synchr_out} ),
    /* verilator lint_on UNOPTFLAT */
    /// Input data for arbitration.
    .data_i     ( {req_data_synchr_out, rsp_data_synchr_out}   ),
    /// Output request is valid.
    .req_o      ( axis_out_valid             ),
    /// Output request is granted.
    .gnt_i      ( axis_out_ready             ),
    /// Output data.
    .data_o     ( axis_out_payload.flit_data ),
    /// Index from which input the data came from.
    .idx_o      ( selected_index             )
  );

  assign axis_out_payload.hdr = channel_hdr_e'(selected_index);

  // required for a stable AXIS output
  stream_fifo #(
    .DATA_WIDTH ( payloadSize           ),
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
  assign axis_out_req_o.t.strb = '1;
  assign axis_out_req_o.t.keep = '0;
  assign axis_out_req_o.t.last =  0;
  assign axis_out_req_o.t.id   =  0;
  assign axis_out_req_o.t.dest =  0;
  assign axis_out_req_o.t.user =  0;

  ///////////////////////////////////////////////
  //  CONNECT AXIS_IN WITH THE OUTGOING FLITS  //
  ///////////////////////////////////////////////

  assign axis_in_req_valid = (axis_in_payload.hdr == request) ? axis_in_req_i.tvalid : 0;
  assign axis_in_rsp_valid = (axis_in_payload.hdr == response) ? axis_in_req_i.tvalid : 0; 

  stream_fifo #(
    .DATA_WIDTH ( req_flit_data_size        ),
    .DEPTH      ( axis_credits              )
  ) i_axis_in_req_reg (
    .clk_i      ( clk_i                     ),
    .rst_ni     ( rst_ni                    ),
    .flush_i    ( 1'b0                      ),
    .testmode_i ( 1'b0                      ),
    .usage_o    (                           ),
    .valid_i    ( axis_in_req_valid         ),
    .ready_o    ( axis_in_req_ready         ),
    .data_i     ( axis_in_payload.flit_data ),
    .valid_o    ( req_o.valid               ),
    .ready_i    ( req_i.ready               ),
    .data_o     ( req_o.data                )
  );

  stream_fifo #(
    .DATA_WIDTH ( rsp_flit_data_size        ),
    .DEPTH      ( axis_credits              )
  ) i_axis_in_rsp_reg (
    .clk_i      ( clk_i                     ),
    .rst_ni     ( rst_ni                    ),
    .flush_i    ( 1'b0                      ),
    .testmode_i ( 1'b0                      ),
    .usage_o    (                           ),
    .valid_i    ( axis_in_rsp_valid         ),
    .ready_o    ( axis_in_rsp_ready         ),
    .data_i     ( axis_in_payload.flit_data ),
    .valid_o    ( rsp_o.valid               ),
    .ready_i    ( rsp_i.ready               ),
    .data_o     ( rsp_o.data                )
  );  

  assign axis_in_payload      = axis_data_t'(axis_in_req_i.t.data);
  assign axis_in_rsp_o.tready = (axis_in_req_ready & axis_in_req_valid) || (axis_in_rsp_ready & axis_in_rsp_valid);

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
