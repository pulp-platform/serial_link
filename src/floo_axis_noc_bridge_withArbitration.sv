// Yannick Baumann <baumanny@student.ethz.ch>

// verify which includes/imports are required
`include "common_cells/registers.svh"
`include "common_cells/assertions.svh"
//`include "axi/assign.svh"

module floo_axis_noc_bridge_withArbitration
  //import floo_pkg::*;
  import floo_axi_flit_pkg::*;
  //import serial_link_pkg::*;
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
  //   logic hdr;
  //   logic [FlitDataSize-1:0] flit_data;
  // } axis_data_t;
  axis_data_t axis_out_payload, axis_in_payload;

  typedef enum logic {SendRequest, SendResponse} flit_selection_t;
  typedef enum logic {RequestFlit, ResponseFlit} flit_type_header_t;
  localparam int FlitBitSize = $bits(axis_in_payload.flit_data);
  typedef logic [FlitBitSize-1:0] flit_data_t;
  flit_selection_t sending_state_q, sending_state_d;
  flit_type_header_t axis_hdr;

  logic reg_ready_rsp, reg_ready_req, reg_valid_rsp, reg_valid_req;
  logic payload_in_valid_req, payload_in_valid_rsp;
  flit_data_t reg_data_rsp, reg_data_req;


  /////////////////////////
  //  CHANNEL SELECTION  //
  /////////////////////////
  
  always_comb begin : axis_out_flit_selection
  	sending_state_d = sending_state_q;
    case (sending_state_q)
  		SendRequest : begin
				// if (req_i.valid & rsp_i.valid) begin
				// 	sending_state_d = SEND_REQUEST_THEN_SWITCH_TO_RESPONSE;
				// end
				// if (req_i.valid & ~rsp_i.valid) begin
				// 	sending_state_d = SendRequest;
				// end
				if (~req_i.valid & rsp_i.valid) begin
					sending_state_d = SendResponse;
				end
				// if (~req_i.valid & ~rsp_i.valid) begin
				// 	sending_state_d = DONT_SEND;
				// end
				axis_hdr = RequestFlit;
			end

			SendResponse : begin
				// if (req_i.valid & rsp_i.valid) begin
				// 	sending_state_d = SendResponse;
				// end
				if (req_i.valid & ~rsp_i.valid) begin
					sending_state_d = SendRequest;
				end
				// if (~req_i.valid & rsp_i.valid) begin
				// 	sending_state_d = SendResponse;
				// end
				// if (~req_i.valid & ~rsp_i.valid) begin
				// 	sending_state_d = DONT_SEND;
				// end
				axis_hdr = ResponseFlit;
			end

			default : begin
				sending_state_d = SendResponse;
			end
		endcase
  end


  /////////////////////
  //  FLITS TO AXIS  //
  /////////////////////

  always_comb begin : axis_payload_packing
  	case (sending_state_q)
  		SendRequest : begin
  			axis_out_payload.hdr       = axis_hdr;
  			axis_out_payload.flit_data = req_i.data;
  		end

  		SendResponse : begin
  			axis_out_payload.hdr       = axis_hdr;
  			axis_out_payload.flit_data = rsp_i.data;
  		end

  		default : begin
  			axis_out_payload.hdr       = axis_hdr;
  			axis_out_payload.flit_data = rsp_i.data;
  		end
  	endcase
  end
  
  // Connect incoming flits with the AXIS_out
  assign axis_out_req_o.tvalid = (axis_in_payload.hdr == ResponseFlit) ? rsp_i.valid : req_i.valid;
  assign axis_out_req_o.t.data = axis_out_payload;
  assign req_o.ready = (axis_in_payload.hdr == RequestFlit)  ? axis_out_rsp_i.tready : 0;
  assign rsp_o.ready = (axis_in_payload.hdr == ResponseFlit) ? axis_out_rsp_i.tready : 0;
  assign axis_out_req_o.t.strb = '1;
  assign axis_out_req_o.t.keep = '0;
  assign axis_out_req_o.t.last = 0;
  assign axis_out_req_o.t.id   = 0;
  assign axis_out_req_o.t.dest = 0;
  assign axis_out_req_o.t.user = 0;
  

  /////////////////////
  //  AXIS TO FLITS  //
  /////////////////////

  assign payload_in_valid_req = (axis_in_payload.hdr == RequestFlit)  ? 1 : 0;
  assign payload_in_valid_rsp = (axis_in_payload.hdr == ResponseFlit) ? 1 : 0;

	stream_fifo #(
    .DATA_WIDTH ( FlitBitSize 																),
    .DEPTH      ( 2          																	)
  ) i_req_out_reg (
    .clk_i      ( clk_i               												),
    .rst_ni     ( rst_ni              												),
    .flush_i    ( 1'b0                												),
    .testmode_i ( 1'b0                												),
    .usage_o    (                     												),
    .valid_i    ( payload_in_valid_req & axis_in_req_i.tvalid ),
    .ready_o    ( reg_ready_req               								),
    .data_i     ( axis_in_payload.flit_data    								),
    .valid_o    ( reg_valid_req     													),
    .ready_i    ( req_i.ready										              ),
    .data_o     ( reg_data_req      													)
  );

	stream_fifo #(
    .DATA_WIDTH ( FlitBitSize 																),
    .DEPTH      ( 2          																	)
  ) i_rsp_out_reg (
    .clk_i      ( clk_i               												),
    .rst_ni     ( rst_ni              												),
    .flush_i    ( 1'b0                												),
    .testmode_i ( 1'b0                												),
    .usage_o    (                     												),
    .valid_i    ( payload_in_valid_rsp & axis_in_req_i.tvalid ),
    .ready_o    ( reg_ready_rsp							   								),
    .data_i     ( axis_in_payload.flit_data    								),
    .valid_o    ( reg_valid_rsp     													),
    .ready_i    ( rsp_i.ready                                 ),
    .data_o     ( reg_data_rsp      													)
  );  

  always_comb begin : axis_payload_unpacking
    req_o.data  = reg_data_req;
    rsp_o.data  = reg_data_rsp;
  	req_o.valid = reg_valid_req;
  	rsp_o.valid = reg_valid_rsp;
  	axis_in_rsp_o.tready = (reg_ready_req & reg_ready_rsp);
  end

  assign axis_in_payload = axis_data_t'(axis_in_req_i.t.data);
  // FOR THE TIME BEING THE SIGNALS BELOW ARE IGNORED...
  // assign ??? = axis_in_req_i.t.strb;
  // assign ??? = axis_in_req_i.t.keep;
  // assign ??? = axis_in_req_i.t.last;
  // assign ??? = axis_in_req_i.t.id;
  // assign ??? = axis_in_req_i.t.dest;
  // assign ??? = axis_in_req_i.t.user;

  /////////////////////
	//    FlipFlops    //
	/////////////////////

  `FF(sending_state_q, sending_state_d, SendResponse)


  //////////////////
  //  ASSERTIONS  //
  //////////////////

  `ASSERT(AxisStable, axis_out_req_o.tvalid & !axis_out_rsp_i.tready |=> $stable(axis_out_req_o.t))

endmodule
