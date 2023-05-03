`include "axi/typedef.svh"
`include "axi/assign.svh"
`include "floo_noc/typedef.svh"
`include "axis/typedef.svh"

module tb_floo_noc_bridge;

  import floo_pkg::*;
  import floo_axi_flit_pkg::*;
  import serial_link_pkg::*;

  localparam time CyclTime = 10ns;
  localparam time ApplTime = 2ns;
  localparam time TestTime = 8ns;

  localparam NumReads0 = 100;
  localparam NumWrites0 = 100;
  localparam NumReads1 = 100;
  localparam NumWrites1 = 100;

  localparam NumTargets = 2;

  localparam int unsigned ReorderBufferSize = 64;
  localparam int unsigned MaxTxns = 32;
  localparam int unsigned MaxTxnsPerId = 32;

  // set to zero if the noc_bridge should be inserted. Assign to one if the bridge should be ignored/bypassede
  localparam BridgeBypass = 0;

  // disable this line if no arbitration should be used and both, the request and the response channels of the NoC-flits
  // should be send over the AXIS channel. This results in a wider AXIS bus...

  // `define useArbitration 1

  `ifdef useArbitration
    localparam int FlitTypes[5] = {$bits(req_flit_t), $bits(rsp_flit_t), 0, 0, 0};
    localparam int FlitDataSize = serial_link_pkg::find_max_channel(FlitTypes)-2;
    typedef struct packed {
      logic hdr;
      logic [FlitDataSize-1:0] flit_data;
    } axis_payload_t;
    localparam BridgeArbitr = 1;
  `else 
    typedef struct packed { 
      logic [$bits(req_flit_t)-3:0] req_data;
      logic req_valid;
      logic req_ready;
      logic [$bits(rsp_flit_t)-3:0] rsp_data;
      logic rsp_valid;
      logic rsp_ready;
    } axis_payload_t;  
    localparam BridgeArbitr = 0;
  `endif

  // Axi stream dimension must be a multiple of 8 bits
  localparam int StreamDataBytes = ($bits(axis_payload_t) + 7) / 8;
  // Typdefs for Axi Stream interface
  // All except tdata_t are unused at the moment
  localparam type tdata_t = logic [StreamDataBytes*8-1:0];
  localparam type tstrb_t = logic [StreamDataBytes-1:0];
  localparam type tkeep_t = logic [StreamDataBytes-1:0];
  localparam type tlast_t = logic;
  localparam type tid_t = logic;
  localparam type tdest_t = logic;
  localparam type tuser_t = logic;
  localparam type tready_t = logic;
  `AXIS_TYPEDEF_ALL(axis, tdata_t, tstrb_t, tkeep_t, tlast_t, tid_t, tdest_t, tuser_t, tready_t)

  logic clk, rst_n;

  axi_in_req_t [NumTargets-1:0] node_man_req;
  axi_in_resp_t [NumTargets-1:0] node_man_rsp;

  axi_out_req_t [NumTargets-1:0] node_sub_req;
  axi_out_resp_t [NumTargets-1:0] node_sub_rsp;

  axi_in_req_t [NumTargets-1:0] sub_req_id_mapped;
  axi_in_resp_t [NumTargets-1:0] sub_rsp_id_mapped;

  for (genvar i = 0; i < NumTargets; i++) begin : gen_axi_assign
    `AXI_ASSIGN_REQ_STRUCT(sub_req_id_mapped[i], node_sub_req[i])
    `AXI_ASSIGN_RESP_STRUCT(sub_rsp_id_mapped[i], node_sub_rsp[i])
  end

  req_flit_t [NumTargets-1:0] chimney_0_req;
  rsp_flit_t [NumTargets-1:0] chimney_0_rsp;
  req_flit_t [NumTargets-1:0] chimney_1_req;
  rsp_flit_t [NumTargets-1:0] chimney_1_rsp;

  axis_req_t [NumTargets-1:0] bridge_req;
  axis_rsp_t [NumTargets-1:0] bridge_rsp;

  logic [NumTargets-1:0] end_of_sim;

  req_flit_t req_bridge_0_o, req_bridge_1_o;
  rsp_flit_t rsp_bridge_0_o, rsp_bridge_1_o;

  clk_rst_gen #(
    .ClkPeriod    ( CyclTime ),
    .RstClkCycles ( 5        )
  ) i_clk_gen (
    .clk_o  ( clk   ),
    .rst_no ( rst_n )
  );

  typedef struct packed {
    logic [AxiInAddrWidth-1:0] start_addr;
    logic [AxiInAddrWidth-1:0] end_addr;
  } node_addr_region_t;

  localparam int unsigned NumAddrRegions = 1;
  localparam node_addr_region_t [NumAddrRegions-1:0] AddrRegions = '{
    '{start_addr: 32'h0000_0000, end_addr: 32'h0000_8000}
  };

  floo_axi_test_node #(
    .AxiAddrWidth   ( AxiInAddrWidth      ),
    .AxiDataWidth   ( AxiInDataWidth      ),
    .AxiIdOutWidth  ( AxiInIdWidth        ),
    .AxiIdInWidth   ( AxiOutIdWidth       ),
    .AxiUserWidth   ( AxiInUserWidth      ),
    .mst_req_t      ( axi_in_req_t        ),
    .mst_rsp_t      ( axi_in_resp_t       ),
    .slv_req_t      ( axi_out_req_t       ),
    .slv_rsp_t      ( axi_out_resp_t      ),
    .ApplTime       ( ApplTime            ),
    .TestTime       ( TestTime            ),
    .AxiMaxBurstLen ( ReorderBufferSize   ),
    .NumAddrRegions ( NumAddrRegions      ),
    .rule_t         ( node_addr_region_t  ),
    .AddrRegions    ( AddrRegions         ),
    .NumReads       ( NumReads0           ),
    .NumWrites      ( NumWrites0          )
  ) i_test_node_0 (
    .clk_i          ( clk             ),
    .rst_ni         ( rst_n           ),
    .mst_port_req_o ( node_man_req[0] ),
    .mst_port_rsp_i ( node_man_rsp[0] ),
    .slv_port_req_i ( node_sub_req[0] ),
    .slv_port_rsp_o ( node_sub_rsp[0] ),
    .end_of_sim     ( end_of_sim[0]   )
  );

  axi_channel_compare #(
    .aw_chan_t  ( axi_in_aw_chan_t ),
    .w_chan_t   ( axi_in_w_chan_t  ),
    .b_chan_t   ( axi_in_b_chan_t  ),
    .ar_chan_t  ( axi_in_ar_chan_t ),
    .r_chan_t   ( axi_in_r_chan_t  ),
    .req_t      ( axi_in_req_t     ),
    .resp_t     ( axi_in_resp_t    )
  ) i_axi_channel_compare_0 (
    .clk_i      ( clk               ),
    .axi_a_req  ( node_man_req[0]   ),
    .axi_a_res  ( node_man_rsp[0]   ),
    .axi_b_req  ( sub_req_id_mapped[1] ),
    .axi_b_res  ( sub_rsp_id_mapped[1] )
  );

  floo_axi_chimney #(
    .RouteAlgo          ( floo_pkg::IdTable   ),
    .MaxTxns            ( MaxTxns             ),
    .MaxTxnsPerId       ( MaxTxnsPerId        ),
    .ReorderBufferSize  ( ReorderBufferSize   )
  ) i_floo_axi_chimney_0 (
    .clk_i          ( clk               ),
    .rst_ni         ( rst_n             ),
    .sram_cfg_i     ( '0                ),
    .test_enable_i  ( 1'b0              ),
    .axi_in_req_i   ( node_man_req[0]   ),
    .axi_in_rsp_o   ( node_man_rsp[0]   ),
    .axi_out_req_o  ( node_sub_req[0]   ),
    .axi_out_rsp_i  ( node_sub_rsp[0]   ),
    .xy_id_i        (                   ),
    .id_i           ( '0                ),
    .req_o          ( chimney_0_req[0]  ),
    .rsp_o          ( chimney_0_rsp[0]  ),
    .req_i          ( chimney_0_req[1]  ),
    .rsp_i          ( chimney_0_rsp[1]  )
  );

  if (BridgeArbitr == 1) begin : bridge
    floo_axis_noc_bridge_withArbitration #(
      .req_flit_t      ( req_flit_t                ),
      .rsp_flit_t      ( rsp_flit_t                ),
      .axis_req_t      ( axis_req_t                ),
      .axis_rsp_t      ( axis_rsp_t                ),
      .axis_data_t     ( axis_payload_t            )
    ) i_floo_axis_noc_bridge_0 (
      .clk_i           ( clk                       ),
      .rst_ni          ( rst_n                     ),
      .req_o           ( req_bridge_0_o            ),
      .rsp_o           ( rsp_bridge_0_o            ),
      .req_i           ( chimney_0_req[0]          ),
      .rsp_i           ( chimney_0_rsp[0]          ),
      .axis_out_req_o  ( bridge_req[0]             ),
      .axis_in_rsp_o   ( bridge_rsp[0]             ),
      .axis_in_req_i   ( bridge_req[1]             ),
      .axis_out_rsp_i  ( bridge_rsp[1]             )
    );

    floo_axis_noc_bridge_withArbitration #(
      .req_flit_t      ( req_flit_t                ),
      .rsp_flit_t      ( rsp_flit_t                ),
      .axis_req_t      ( axis_req_t                ),
      .axis_rsp_t      ( axis_rsp_t                ),
      .axis_data_t     ( axis_payload_t            )
    ) i_floo_axis_noc_bridge_1 (
      .clk_i           ( clk                       ),
      .rst_ni          ( rst_n                     ),
      .req_o           ( req_bridge_1_o            ),
      .rsp_o           ( rsp_bridge_1_o            ),
      .req_i           ( chimney_1_req[1]          ),
      .rsp_i           ( chimney_1_rsp[1]          ),
      .axis_out_req_o  ( bridge_req[1]             ),
      .axis_in_rsp_o   ( bridge_rsp[1]             ),
      .axis_in_req_i   ( bridge_req[0]             ),
      .axis_out_rsp_i  ( bridge_rsp[0]             )
    );    
  end else begin : bridge
    floo_axis_noc_bridge #(
      .req_flit_t      ( req_flit_t                ),
      .rsp_flit_t      ( rsp_flit_t                ),
      .axis_req_t      ( axis_req_t                ),
      .axis_rsp_t      ( axis_rsp_t                ),
      .axis_data_t     ( axis_payload_t            )
    ) i_floo_axis_noc_bridge_0 (
      .clk_i           ( clk                       ),
      .rst_ni          ( rst_n                     ),
      .req_o           ( req_bridge_0_o            ),
      .rsp_o           ( rsp_bridge_0_o            ),
      .req_i           ( chimney_0_req[0]          ),
      .rsp_i           ( chimney_0_rsp[0]          ),
      .axis_out_req_o  ( bridge_req[0]             ),
      .axis_in_rsp_o   ( bridge_rsp[0]             ),
      .axis_in_req_i   ( bridge_req[1]             ),
      .axis_out_rsp_i  ( bridge_rsp[1]             )
    );

    floo_axis_noc_bridge #(
      .req_flit_t      ( req_flit_t                ),
      .rsp_flit_t      ( rsp_flit_t                ),
      .axis_req_t      ( axis_req_t                ),
      .axis_rsp_t      ( axis_rsp_t                ),
      .axis_data_t     ( axis_payload_t            )
    ) i_floo_axis_noc_bridge_1 (
      .clk_i           ( clk                       ),
      .rst_ni          ( rst_n                     ),
      .req_o           ( req_bridge_1_o            ),
      .rsp_o           ( rsp_bridge_1_o            ),
      .req_i           ( chimney_1_req[1]          ),
      .rsp_i           ( chimney_1_rsp[1]          ),
      .axis_out_req_o  ( bridge_req[1]             ),
      .axis_in_rsp_o   ( bridge_rsp[1]             ),
      .axis_in_req_i   ( bridge_req[0]             ),
      .axis_out_rsp_i  ( bridge_rsp[0]             )
    );
  end

  assign chimney_1_req[0] = (BridgeBypass==1) ? chimney_0_req[0] : req_bridge_1_o;
  assign chimney_1_rsp[0] = (BridgeBypass==1) ? chimney_0_rsp[0] : rsp_bridge_1_o;
  assign chimney_0_req[1] = (BridgeBypass==1) ? chimney_1_req[1] : req_bridge_0_o;
  assign chimney_0_rsp[1] = (BridgeBypass==1) ? chimney_1_rsp[1] : rsp_bridge_0_o;

  floo_axi_chimney #(
    .RouteAlgo          ( floo_pkg::IdTable   ),
    .MaxTxns            ( MaxTxns             ),
    .MaxTxnsPerId       ( MaxTxnsPerId        ),
    .ReorderBufferSize  ( ReorderBufferSize   )
  ) i_floo_axi_chimney_1 (
    .clk_i          ( clk                   ),
    .rst_ni         ( rst_n                 ),
    .sram_cfg_i     ( '0                    ),
    .test_enable_i  ( 1'b0                  ),
    .axi_in_req_i   ( node_man_req[1]       ),
    .axi_in_rsp_o   ( node_man_rsp[1]       ),
    .axi_out_req_o  ( node_sub_req[1]       ),
    .axi_out_rsp_i  ( node_sub_rsp[1]       ),
    .xy_id_i        (                       ),
    .id_i           ( '0                    ),
    .req_o          ( chimney_1_req[1]      ),
    .rsp_o          ( chimney_1_rsp[1]      ),
    .req_i          ( chimney_1_req[0]      ),
    .rsp_i          ( chimney_1_rsp[0]      )
  );

  axi_channel_compare #(
    .aw_chan_t  ( axi_in_aw_chan_t ),
    .w_chan_t   ( axi_in_w_chan_t  ),
    .b_chan_t   ( axi_in_b_chan_t  ),
    .ar_chan_t  ( axi_in_ar_chan_t ),
    .r_chan_t   ( axi_in_r_chan_t  ),
    .req_t      ( axi_in_req_t     ),
    .resp_t     ( axi_in_resp_t    )
  ) i_axi_channel_compare_1 (
    .clk_i(clk),
    .axi_a_req  ( node_man_req[1] ),
    .axi_a_res  ( node_man_rsp[1] ),
    .axi_b_req  ( sub_req_id_mapped[0] ),
    .axi_b_res  ( sub_rsp_id_mapped[0] )
  );

  floo_axi_test_node #(
    .AxiAddrWidth   ( AxiInAddrWidth      ),
    .AxiDataWidth   ( AxiInDataWidth      ),
    .AxiIdInWidth   ( AxiOutIdWidth       ),
    .AxiIdOutWidth  ( AxiInIdWidth        ),
    .AxiUserWidth   ( AxiInUserWidth      ),
    .mst_req_t      ( axi_in_req_t        ),
    .mst_rsp_t      ( axi_in_resp_t       ),
    .slv_req_t      ( axi_out_req_t       ),
    .slv_rsp_t      ( axi_out_resp_t      ),
    .ApplTime       ( ApplTime            ),
    .TestTime       ( TestTime            ),
    .AxiMaxBurstLen ( ReorderBufferSize   ),
    .NumAddrRegions ( NumAddrRegions      ),
    .rule_t         ( node_addr_region_t  ),
    .AddrRegions    ( AddrRegions         ),
    .NumReads       ( NumReads1           ),
    .NumWrites      ( NumWrites1          )
  ) i_test_node_1 (
    .clk_i          ( clk             ),
    .rst_ni         ( rst_n           ),
    .mst_port_req_o ( node_man_req[1] ),
    .mst_port_rsp_i ( node_man_rsp[1] ),
    .slv_port_req_i ( node_sub_req[1] ),
    .slv_port_rsp_o ( node_sub_rsp[1] ),
    .end_of_sim     ( end_of_sim[1]   )
  );

  initial begin
    if (BridgeBypass == 1) begin
      $display("INFO: The NoC-bridge is not inserted in the test chain and will be ignored!");
    end else begin
      $display("INFO: The NoC-bridge is actively connected!");
      if (BridgeArbitr == 1) begin
        $display("INFO: The NoC-bridge sends either the request or the response flit-channel to the AXIS side.");
      end else begin
        $display("INFO: The NoC-bridge does not contain arbitration logic and sends request and response channels simultaneously over AXIS.");
      end    
    end
    wait(&end_of_sim);
    $stop;
  end


endmodule