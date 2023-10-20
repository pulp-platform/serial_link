// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
//  - Yannick Baumann <baumanny@student.ethz.ch>
`include "axi/typedef.svh"
`include "axi/assign.svh"
`include "floo_noc/typedef.svh"
`include "axis/typedef.svh"

module tb_floo_noc_bridge;

  import floo_pkg::*;
  import noc_bridge_pkg::*;
  import serial_link_pkg::*;
  import floo_axi_pkg::*;

  localparam time CyclTime = 10ns;
  localparam time ApplTime = 2ns;
  localparam time TestTime = 8ns;

  localparam NumReads0    = 100;
  localparam NumWrites0   = 100;
  localparam NumReads1    = 100;
  localparam NumWrites1   = 100;

  localparam NumTargets   = 2;

  localparam channelCount = 2;

  localparam int unsigned ReorderBufferSize = 64;
  localparam int unsigned MaxTxns           = 32;
  localparam int unsigned MaxTxnsPerId      = 32;

  localparam bit BridgeVirtualChannels = (NumCredNocBridge > 0);

  // minimal AXIS data size (also contain the hdr-bit, thus + 1)
  localparam int axis_data_size = FlitDataSize + 1;

  // Axi stream dimension must be a multiple of 8 bits
  localparam int StreamDataBytes = (axis_data_size + 7) / 8;
  // Typdefs for Axi Stream interface
  // All except tdata_t are unused at the moment
  localparam type tdata_t  = logic [StreamDataBytes*8-1:0];
  localparam type tstrb_t  = logic [StreamDataBytes-1:0];
  localparam type tkeep_t  = logic [StreamDataBytes-1:0];
  localparam type tlast_t  = logic;
  localparam type tid_t    = logic;
  localparam type tdest_t  = logic;
  // The user bits serve as transfer line for the credit information utilized in the virtual-channel version of the noc-bridge.
  // The first bit of the user-bits is reserved for a data-specific valid field. (consider the hdr bit in the data_line)
  localparam type tuser_t  = user_bit_t;
  localparam type tready_t = logic;
  `AXIS_TYPEDEF_ALL(axis, tdata_t, tstrb_t, tkeep_t, tlast_t, tid_t, tdest_t, tuser_t, tready_t)

  logic clk, rst_n;

  axi_in_req_t [NumTargets-1:0] node_man_req;
  axi_in_rsp_t [NumTargets-1:0] node_man_rsp;

  axi_out_req_t [NumTargets-1:0] node_sub_req;
  axi_out_rsp_t [NumTargets-1:0] node_sub_rsp;

  axi_in_req_t [NumTargets-1:0] sub_req_id_mapped;
  axi_in_rsp_t [NumTargets-1:0] sub_rsp_id_mapped;

  for (genvar i = 0; i < NumTargets; i++) begin : gen_axi_assign
    `AXI_ASSIGN_REQ_STRUCT(sub_req_id_mapped[i], node_sub_req[i])
    `AXI_ASSIGN_RESP_STRUCT(sub_rsp_id_mapped[i], node_sub_rsp[i])
  end

  floo_req_t [NumTargets-1:0] chimney_0_req;
  floo_rsp_t [NumTargets-1:0] chimney_0_rsp;
  floo_req_t [NumTargets-1:0] chimney_1_req;
  floo_rsp_t [NumTargets-1:0] chimney_1_rsp;

  axis_req_t [NumTargets-1:0] bridge_req;
  axis_rsp_t [NumTargets-1:0] bridge_rsp;

  logic [NumTargets-1:0] end_of_sim;

  floo_req_t req_bridge_0_o, req_bridge_1_o;
  floo_rsp_t rsp_bridge_0_o, rsp_bridge_1_o;

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
    .AxiAddrWidth   ( AxiInAddrWidth     ),
    .AxiDataWidth   ( AxiInDataWidth     ),
    .AxiIdOutWidth  ( AxiInIdWidth       ),
    .AxiIdInWidth   ( AxiOutIdWidth      ),
    .AxiUserWidth   ( AxiInUserWidth     ),
    .mst_req_t      ( axi_in_req_t       ),
    .mst_rsp_t      ( axi_in_rsp_t       ),
    .slv_req_t      ( axi_out_req_t      ),
    .slv_rsp_t      ( axi_out_rsp_t      ),
    .ApplTime       ( ApplTime           ),
    .TestTime       ( TestTime           ),
    .AxiMaxBurstLen ( ReorderBufferSize  ),
    .NumAddrRegions ( NumAddrRegions     ),
    .rule_t         ( node_addr_region_t ),
    .AddrRegions    ( AddrRegions        ),
    .NumReads       ( NumReads0          ),
    .NumWrites      ( NumWrites0         )
  ) i_test_node_0 (
    .clk_i          ( clk                ),
    .rst_ni         ( rst_n              ),
    .mst_port_req_o ( node_man_req[0]    ),
    .mst_port_rsp_i ( node_man_rsp[0]    ),
    .slv_port_req_i ( node_sub_req[0]    ),
    .slv_port_rsp_o ( node_sub_rsp[0]    ),
    .end_of_sim     ( end_of_sim[0]      )
  );

  axi_chan_compare #(
  	.IgnoreId  ( 1'b1                 ),
    .aw_chan_t ( axi_in_aw_chan_t     ),
    .w_chan_t  ( axi_in_w_chan_t      ),
    .b_chan_t  ( axi_in_b_chan_t      ),
    .ar_chan_t ( axi_in_ar_chan_t     ),
    .r_chan_t  ( axi_in_r_chan_t      ),
    .req_t     ( axi_in_req_t         ),
    .resp_t    ( axi_in_rsp_t        )
  ) i_axi_channel_compare_0 (
    .clk_a_i   ( clk                  ),
    .clk_b_i   ( clk                  ),
    .axi_a_req ( node_man_req[0]      ),
    .axi_a_res ( node_man_rsp[0]      ),
    .axi_b_req ( sub_req_id_mapped[1] ),
    .axi_b_res ( sub_rsp_id_mapped[1] )
  );

  floo_axi_chimney #(
    .RouteAlgo         ( floo_pkg::IdTable ),
    .MaxTxns           ( MaxTxns           ),
    .MaxTxnsPerId      ( MaxTxnsPerId      ),
    .ReorderBufferSize ( ReorderBufferSize )
  ) i_floo_axi_chimney_0 (
    .clk_i         ( clk              ),
    .rst_ni        ( rst_n            ),
    .sram_cfg_i    ( '0               ),
    .test_enable_i ( 1'b0             ),
    .axi_in_req_i  ( node_man_req[0]  ),
    .axi_in_rsp_o  ( node_man_rsp[0]  ),
    .axi_out_req_o ( node_sub_req[0]  ),
    .axi_out_rsp_i ( node_sub_rsp[0]  ),
    .xy_id_i       ( '0               ),
    .id_i          ( '0               ),
    .floo_req_o    ( chimney_0_req[0] ),
    .floo_rsp_o    ( chimney_0_rsp[0] ),
    .floo_req_i    ( chimney_0_req[1] ),
    .floo_rsp_i    ( chimney_0_rsp[1] )
  );

  if (BridgeVirtualChannels) begin : gen_vc_bridge
    serial_link_floo_vc_network #(
      .floo_req_t       ( floo_req_t       ),
      .floo_rsp_t       ( floo_rsp_t       ),
      .axis_req_t       ( axis_req_t       ),
      .axis_rsp_t       ( axis_rsp_t       ),
      .NumNocChanPerDir ( channelCount     )
    ) i_floo_axis_noc_bridge_0 (
      .clk_i            ( clk              ),
      .rst_ni           ( rst_n            ),
      .floo_req_o       ( req_bridge_0_o   ),
      .floo_rsp_o       ( rsp_bridge_0_o   ),
      .floo_req_i       ( chimney_0_req[0] ),
      .floo_rsp_i       ( chimney_0_rsp[0] ),
      .axis_out_req_o   ( bridge_req[0]    ),
      .axis_in_rsp_o    ( bridge_rsp[0]    ),
      .axis_in_req_i    ( bridge_req[1]    ),
      .axis_out_rsp_i   ( bridge_rsp[1]    )
    );

    serial_link_floo_vc_network #(
    	.IgnoreAssert     ( BridgeBypass     ),
      .floo_req_t       ( floo_req_t       ),
      .floo_rsp_t       ( floo_rsp_t       ),
      .axis_req_t       ( axis_req_t       ),
      .axis_rsp_t       ( axis_rsp_t       ),
      .NumNocChanPerDir ( channelCount     )
    ) i_floo_axis_noc_bridge_1 (
      .clk_i            ( clk              ),
      .rst_ni           ( rst_n            ),
      .floo_req_o       ( req_bridge_1_o   ),
      .floo_rsp_o       ( rsp_bridge_1_o   ),
      .floo_req_i       ( chimney_1_req[1] ),
      .floo_rsp_i       ( chimney_1_rsp[1] ),
      .axis_out_req_o   ( bridge_req[1]    ),
      .axis_in_rsp_o    ( bridge_rsp[1]    ),
      .axis_in_req_i    ( bridge_req[0]    ),
      .axis_out_rsp_i   ( bridge_rsp[0]    )
    );
  end else begin : gen_bridge
    serial_link_floo_network #(
    	.IgnoreAssert     ( BridgeBypass     ),
      .floo_req_t       ( floo_req_t       ),
      .floo_rsp_t       ( floo_rsp_t       ),
      .axis_req_t       ( axis_req_t       ),
      .axis_rsp_t       ( axis_rsp_t       ),
      .NumNocChanPerDir ( channelCount     )
    ) i_floo_axis_noc_bridge_0 (
      .clk_i            ( clk              ),
      .rst_ni           ( rst_n            ),
      .floo_req_o            ( req_bridge_0_o   ),
      .floo_rsp_o            ( rsp_bridge_0_o   ),
      .floo_req_i            ( chimney_0_req[0] ),
      .floo_rsp_i            ( chimney_0_rsp[0] ),
      .axis_out_req_o   ( bridge_req[0]    ),
      .axis_in_rsp_o    ( bridge_rsp[0]    ),
      .axis_in_req_i    ( bridge_req[1]    ),
      .axis_out_rsp_i   ( bridge_rsp[1]    )
    );

    serial_link_floo_network #(
    	.IgnoreAssert     ( BridgeBypass     ),
      .floo_req_t       ( floo_req_t       ),
      .floo_rsp_t       ( floo_rsp_t       ),
      .axis_req_t       ( axis_req_t       ),
      .axis_rsp_t       ( axis_rsp_t       ),
      .NumNocChanPerDir ( channelCount     )
    ) i_floo_axis_noc_bridge_1 (
      .clk_i            ( clk              ),
      .rst_ni           ( rst_n            ),
      .floo_req_o            ( req_bridge_1_o   ),
      .floo_rsp_o            ( rsp_bridge_1_o   ),
      .floo_req_i            ( chimney_1_req[1] ),
      .floo_rsp_i            ( chimney_1_rsp[1] ),
      .axis_out_req_o   ( bridge_req[1]    ),
      .axis_in_rsp_o    ( bridge_rsp[1]    ),
      .axis_in_req_i    ( bridge_req[0]    ),
      .axis_out_rsp_i   ( bridge_rsp[0]    )
    );
  end

  assign Bridge_0_req_o = req_bridge_0_o.valid & chimney_0_req[0].ready;
  assign Bridge_0_req_i = chimney_0_req[0].valid & req_bridge_0_o.ready;
  assign Bridge_0_rsp_o = rsp_bridge_0_o.valid & chimney_0_rsp[0].ready;
  assign Bridge_0_rsp_i = chimney_0_rsp[0].valid & rsp_bridge_0_o.ready;

  assign Bridge_1_req_o = req_bridge_1_o.valid & chimney_1_req[1].ready;
  assign Bridge_1_req_i = chimney_1_req[1].valid & req_bridge_1_o.ready;
  assign Bridge_1_rsp_o = rsp_bridge_1_o.valid & chimney_1_rsp[1].ready;
  assign Bridge_1_rsp_i = chimney_1_rsp[1].valid & rsp_bridge_1_o.ready;

  assign chimney_1_req[0] = BridgeBypass ? chimney_0_req[0] : req_bridge_1_o;
  assign chimney_1_rsp[0] = BridgeBypass ? chimney_0_rsp[0] : rsp_bridge_1_o;
  assign chimney_0_req[1] = BridgeBypass ? chimney_1_req[1] : req_bridge_0_o;
  assign chimney_0_rsp[1] = BridgeBypass ? chimney_1_rsp[1] : rsp_bridge_0_o;

  floo_axi_chimney #(
    .RouteAlgo         ( floo_pkg::IdTable ),
    .MaxTxns           ( MaxTxns           ),
    .MaxTxnsPerId      ( MaxTxnsPerId      ),
    .ReorderBufferSize ( ReorderBufferSize )
  ) i_floo_axi_chimney_1 (
    .clk_i         ( clk              ),
    .rst_ni        ( rst_n            ),
    .sram_cfg_i    ( '0               ),
    .test_enable_i ( 1'b0             ),
    .axi_in_req_i  ( node_man_req[1]  ),
    .axi_in_rsp_o  ( node_man_rsp[1]  ),
    .axi_out_req_o ( node_sub_req[1]  ),
    .axi_out_rsp_i ( node_sub_rsp[1]  ),
    .xy_id_i       (                  ),
    .id_i          ( '0               ),
    .floo_req_o    ( chimney_1_req[1] ),
    .floo_rsp_o    ( chimney_1_rsp[1] ),
    .floo_req_i    ( chimney_1_req[0] ),
    .floo_rsp_i    ( chimney_1_rsp[0] )
  );

  axi_chan_compare #(
  	.IgnoreId  ( 1'b1                 ),
    .aw_chan_t ( axi_in_aw_chan_t     ),
    .w_chan_t  ( axi_in_w_chan_t      ),
    .b_chan_t  ( axi_in_b_chan_t      ),
    .ar_chan_t ( axi_in_ar_chan_t     ),
    .r_chan_t  ( axi_in_r_chan_t      ),
    .req_t     ( axi_in_req_t         ),
    .resp_t    ( axi_in_rsp_t         )
  ) i_axi_channel_compare_1 (
    .clk_a_i   ( clk                  ),
    .clk_b_i   ( clk                  ),
    .axi_a_req ( node_man_req[1]      ),
    .axi_a_res ( node_man_rsp[1]      ),
    .axi_b_req ( sub_req_id_mapped[0] ),
    .axi_b_res ( sub_rsp_id_mapped[0] )
  );

  floo_axi_test_node #(
    .AxiAddrWidth   ( AxiInAddrWidth     ),
    .AxiDataWidth   ( AxiInDataWidth     ),
    .AxiIdInWidth   ( AxiOutIdWidth      ),
    .AxiIdOutWidth  ( AxiInIdWidth       ),
    .AxiUserWidth   ( AxiInUserWidth     ),
    .mst_req_t      ( axi_in_req_t       ),
    .mst_rsp_t      ( axi_in_rsp_t       ),
    .slv_req_t      ( axi_out_req_t      ),
    .slv_rsp_t      ( axi_out_rsp_t      ),
    .ApplTime       ( ApplTime           ),
    .TestTime       ( TestTime           ),
    .AxiMaxBurstLen ( ReorderBufferSize  ),
    .NumAddrRegions ( NumAddrRegions     ),
    .rule_t         ( node_addr_region_t ),
    .AddrRegions    ( AddrRegions        ),
    .NumReads       ( NumReads1          ),
    .NumWrites      ( NumWrites1         )
  ) i_test_node_1 (
    .clk_i          ( clk                ),
    .rst_ni         ( rst_n              ),
    .mst_port_req_o ( node_man_req[1]    ),
    .mst_port_rsp_i ( node_man_rsp[1]    ),
    .slv_port_req_i ( node_sub_req[1]    ),
    .slv_port_rsp_o ( node_sub_rsp[1]    ),
    .end_of_sim     ( end_of_sim[1]      )
  );

  task automatic stop_sim();
    repeat(50) begin
      @(posedge clk);
    end
    $display("[SYS] Simulation Stopped (%d ns)", $time);
    $stop();
  endtask

  initial begin
    wait(&end_of_sim);
    stop_sim();
  end

endmodule
