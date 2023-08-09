// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
//  - Tim Fischer <fischeti@iis.ee.ethz.ch>
//  - Yannick Baumann <baumanny@ethz.student.ch>

module tb_floo_serial_link_narrow_wide();

  `include "axi/assign.svh"
  `include "axi/typedef.svh"

  `include "register_interface/assign.svh"
  `include "register_interface/typedef.svh"

  import floo_pkg::*;
  import serial_link_pkg::*;
  import serial_link_reg_pkg::*;
  import floo_narrow_wide_flit_pkg::*;
  import noc_bridge_narrow_wide_pkg::*;
  import serial_link_single_channel_reg_pkg::*;

  // ==============
  //    Config
  // ==============
  localparam int unsigned TestDuration    = 100;
  localparam int unsigned NumLanes        = serial_link_pkg::NumLanes;
  localparam int unsigned NumChannels     = serial_link_pkg::NumChannels;
  localparam int unsigned MaxClkDiv       = serial_link_pkg::MaxClkDiv;

  localparam time         TckSys1         = 50ns;
  // localparam time         TckSys2         = 50ns;
  localparam time         TckSys2         = 54ns;
  localparam time         TckReg          = 200ns;
  localparam int unsigned RstClkCyclesSys = 1;

  // Random-master/slave behaviour (randomized delays)
  localparam int          min_wait_cycles = 0;
  localparam int          max_wait_cycles = 0;
  // localparam int          max_wait_cycles = 100;

  localparam int unsigned RegAddrWidth    = 32;
  localparam int unsigned RegDataWidth    = 32;
  localparam int unsigned RegStrbWidth    = RegDataWidth / 8;

  localparam logic [NumLanes*2-1:0] CalibrationPattern = {{NumLanes/4}{4'b1010, 4'b0101}};

  // narrow channel
  localparam int unsigned NarrowReorderBufferSize = 64;
  localparam int unsigned NarrowMaxTxns           = 32;
  localparam int unsigned NarrowMaxTxnsPerId      = 32;

  // wide channel
  localparam int unsigned WideReorderBufferSize = 64;
  localparam int unsigned WideMaxTxns           = 32;
  localparam int unsigned WideMaxTxnsPerId      = 32;

  // Stop the simulation if this simulation time (ns) is exceeded.
  // localparam int stopSimAfter = 200000000;
  localparam int stopSimAfter = 75000000;

  // ==============
  //    DDR Link
  // ==============

  // AXI types for typedefs of narrow channel
  typedef logic [NarrowInIdWidth-1:0  ]   narrow_in_id_t;
  typedef logic [NarrowInAddrWidth-1:0]   narrow_in_addr_t;
  typedef logic [NarrowInDataWidth-1:0]   narrow_in_data_t;
  typedef logic [NarrowInDataWidth/8-1:0] narrow_in_strb_t;
  typedef logic [NarrowInUserWidth-1:0]   narrow_in_user_t;

  `AXI_TYPEDEF_ALL(narrow_axi_in, narrow_in_addr_t, narrow_in_id_t, narrow_in_data_t, narrow_in_strb_t, narrow_in_user_t)

  typedef logic [NarrowOutIdWidth-1:0  ]   narrow_out_id_t;
  typedef logic [NarrowOutAddrWidth-1:0]   narrow_out_addr_t;
  typedef logic [NarrowOutDataWidth-1:0]   narrow_out_data_t;
  typedef logic [NarrowOutDataWidth/8-1:0] narrow_out_strb_t;
  typedef logic [NarrowOutUserWidth-1:0]   narrow_out_user_t;

  `AXI_TYPEDEF_ALL(narrow_axi_out, narrow_out_addr_t, narrow_out_id_t, narrow_out_data_t, narrow_out_strb_t, narrow_out_user_t)

  // AXI types for typedefs of wide channel
  typedef logic [WideInIdWidth-1:0  ]   wide_in_id_t;
  typedef logic [WideInAddrWidth-1:0]   wide_in_addr_t;
  typedef logic [WideInDataWidth-1:0]   wide_in_data_t;
  typedef logic [WideInDataWidth/8-1:0] wide_in_strb_t;
  typedef logic [WideInUserWidth-1:0]   wide_in_user_t;

  `AXI_TYPEDEF_ALL(wide_axi_in, wide_in_addr_t, wide_in_id_t, wide_in_data_t, wide_in_strb_t, wide_in_user_t)

  typedef logic [WideOutIdWidth-1:0  ]   wide_out_id_t;
  typedef logic [WideOutAddrWidth-1:0]   wide_out_addr_t;
  typedef logic [WideOutDataWidth-1:0]   wide_out_data_t;
  typedef logic [WideOutDataWidth/8-1:0] wide_out_strb_t;
  typedef logic [WideOutUserWidth-1:0]   wide_out_user_t;

  `AXI_TYPEDEF_ALL(wide_axi_out, wide_out_addr_t, wide_out_id_t, wide_out_data_t, wide_out_strb_t, wide_out_user_t)

  // RegBus types for typedefs
  typedef logic [RegAddrWidth-1:0] cfg_addr_t;
  typedef logic [RegDataWidth-1:0] cfg_data_t;
  typedef logic [RegStrbWidth-1:0] cfg_strb_t;

  `REG_BUS_TYPEDEF_ALL(cfg, cfg_addr_t, cfg_data_t, cfg_strb_t)

  // Model signals
  logic [NumChannels-1:0]  ddr_rcv_clk_1, ddr_rcv_clk_2;

  // narrow channels
  narrow_axi_out_req_t  narrow_axi_out_req_1, narrow_axi_out_req_2;
  narrow_axi_out_resp_t narrow_axi_out_rsp_1, narrow_axi_out_rsp_2;
  narrow_axi_in_req_t   narrow_axi_in_req_1,  narrow_axi_in_req_2;
  narrow_axi_in_resp_t  narrow_axi_in_rsp_1,  narrow_axi_in_rsp_2;

  narrow_req_flit_t  narrow_flit_req_out_1, narrow_flit_req_out_2;
  narrow_rsp_flit_t  narrow_flit_rsp_out_1, narrow_flit_rsp_out_2;
  narrow_req_flit_t  narrow_flit_req_in_1, narrow_flit_req_in_2;
  narrow_rsp_flit_t  narrow_flit_rsp_in_1, narrow_flit_rsp_in_2;

  // wide channels
  wide_axi_out_req_t  wide_axi_out_req_1, wide_axi_out_req_2;
  wide_axi_out_resp_t wide_axi_out_rsp_1, wide_axi_out_rsp_2;
  wide_axi_in_req_t   wide_axi_in_req_1, wide_axi_in_req_2;
  wide_axi_in_resp_t  wide_axi_in_rsp_1, wide_axi_in_rsp_2;

  wide_flit_t wide_flit_out_1, wide_flit_out_2;
  wide_flit_t wide_flit_in_1, wide_flit_in_2;

  // configuration
  cfg_req_t   cfg_req_1;
  cfg_rsp_t   cfg_rsp_1;
  cfg_req_t   cfg_req_2;
  cfg_rsp_t   cfg_rsp_2;

  // link
  wire [NumChannels*NumLanes-1:0] ddr_o;
  wire [NumChannels*NumLanes-1:0] ddr_i;

  // clock and reset
  logic clk_1, clk_2, clk_reg;
  logic rst_1_n, rst_2_n, rst_reg_n;

  // benchmarking wires/variables
  logic [31:0] serial_link_0_valid_cycles_from_phys, serial_link_0_valid_cycles_to_phys, serial_link_0_number_cycles;
  logic [31:0] data_link_0_num_cred_only_pack_sent, data_link_0_sum_stalled_cyc_cred_cntrs, network_0_number_cycles;
  logic [31:0] network_0_valid_cycles_to_phys, network_0_valid_cycles_from_phys, network_0_num_cred_only_pack_sent;
  logic [31:0] network_0_sum_stalled_cyc_cred_cntrs;

  logic [31:0] serial_link_1_valid_cycles_from_phys, serial_link_1_valid_cycles_to_phys, serial_link_1_number_cycles;
  logic [31:0] data_link_1_num_cred_only_pack_sent, data_link_1_sum_stalled_cyc_cred_cntrs, network_1_number_cycles;
  logic [31:0] network_1_valid_cycles_to_phys, network_1_valid_cycles_from_phys, network_1_num_cred_only_pack_sent;
  logic [31:0] network_1_sum_stalled_cyc_cred_cntrs;

  logic [31:0] lat_0, lat_1, lat_2, lat_3, lat_4, lat_5, lat_6, lat_7, lat_8, lat_9;
  logic [31:0] lat_10, lat_11, lat_12, lat_13, lat_14, lat_15, lat_16, lat_17, lat_18, lat_19;
  logic [31:0] lat_20, lat_21, lat_22, lat_23, lat_24, lat_25, lat_26, lat_27, lat_28, lat_29;
  logic [31:0] lat_30, lat_31, lat_32, lat_33, lat_34, lat_35, lat_36, lat_37, lat_38, lat_39;

  // system clock and reset
  clk_rst_gen #(
    .ClkPeriod    ( TckReg          ),
    .RstClkCycles ( RstClkCyclesSys )
  ) i_clk_rst_gen_reg (
    .clk_o  ( clk_reg   ),
    .rst_no ( rst_reg_n )
  );

  clk_rst_gen #(
    .ClkPeriod    ( TckSys1         ),
    .RstClkCycles ( RstClkCyclesSys )
  ) i_clk_rst_gen_sys_1 (
    .clk_o  ( clk_1   ),
    .rst_no ( rst_1_n )
  );

  clk_rst_gen #(
    .ClkPeriod    ( TckSys2          ),
    .RstClkCycles ( RstClkCyclesSys  )
  ) i_clk_rst_gen_sys_2 (
    .clk_o  ( clk_2   ),
    .rst_no ( rst_2_n )
  );

  // first serial instance
  floo_narrow_wide_chimney #(
    .RouteAlgo               ( floo_pkg::IdTable ),
    .NarrowMaxTxns           ( NarrowMaxTxns           ),
    .NarrowMaxTxnsPerId      ( NarrowMaxTxnsPerId      ),
    .NarrowReorderBufferSize ( NarrowReorderBufferSize ),
    .WideMaxTxns             ( WideMaxTxns             ),
    .WideMaxTxnsPerId        ( WideMaxTxnsPerId        ),
    .WideReorderBufferSize   ( WideReorderBufferSize   )
  ) i_floo_axi_chimney_0 (
    .clk_i            ( clk_1                ),
    .rst_ni           ( rst_1_n              ),
    .sram_cfg_i       ( '0                   ),
    .test_enable_i    ( 1'b0                 ),
    .narrow_in_req_i  ( narrow_axi_in_req_1  ),
    .narrow_in_rsp_o  ( narrow_axi_in_rsp_1  ),
    .narrow_out_req_o ( narrow_axi_out_req_1 ),
    .narrow_out_rsp_i ( narrow_axi_out_rsp_1 ),
    .wide_in_req_i    ( wide_axi_in_req_1     ),
    .wide_in_rsp_o    ( wide_axi_in_rsp_1     ),
    .wide_out_req_o   ( wide_axi_out_req_1    ),
    .wide_out_rsp_i   ( wide_axi_out_rsp_1    ),
    .xy_id_i          (                       ),
    .id_i             ( '0                    ),
    .narrow_req_o     ( narrow_flit_req_out_1 ),
    .narrow_rsp_o     ( narrow_flit_rsp_out_1 ),
    .narrow_req_i     ( narrow_flit_req_in_1  ),
    .narrow_rsp_i     ( narrow_flit_rsp_in_1  ),
    .wide_o           ( wide_flit_out_1       ),
    .wide_i           ( wide_flit_in_1        )
  );

  floo_serial_link_narrow_wide #(
    .narrow_req_flit_t ( narrow_req_flit_t ),
    .narrow_rsp_flit_t ( narrow_rsp_flit_t ),
    .wide_flit_t       ( wide_flit_t       ),
    .cfg_req_t         ( cfg_req_t         ),
    .cfg_rsp_t         ( cfg_rsp_t         ),
    .hw2reg_t          ( serial_link_reg_pkg::serial_link_hw2reg_t ),
    .reg2hw_t          ( serial_link_reg_pkg::serial_link_reg2hw_t ),
    .NumChannels       ( NumChannels       ),
    .NumLanes          ( NumLanes          ),
    .MaxClkDiv         ( MaxClkDiv         ),
    .printFeedback     ( 1'b1              )
  ) i_serial_link_0 (
    .clk_i         ( clk_1                 ),
    .rst_ni        ( rst_1_n               ),
    .clk_sl_i      ( clk_1                 ),
    .rst_sl_ni     ( rst_1_n               ),
    .clk_reg_i     ( clk_reg               ),
    .rst_reg_ni    ( rst_reg_n             ),
    .narrow_req_i  ( narrow_flit_req_out_1 ),
    .narrow_rsp_i  ( narrow_flit_rsp_out_1 ),
    .narrow_req_o  ( narrow_flit_req_in_1  ),
    .narrow_rsp_o  ( narrow_flit_rsp_in_1  ),
    .wide_i        ( wide_flit_out_1       ),
    .wide_o        ( wide_flit_in_1        ),
    .cfg_req_i     ( cfg_req_1             ),
    .cfg_rsp_o     ( cfg_rsp_1             ),
    .ddr_rcv_clk_i ( ddr_rcv_clk_2         ),
    .ddr_rcv_clk_o ( ddr_rcv_clk_1         ),
    .ddr_i         ( ddr_i                 ),
    .ddr_o         ( ddr_o                 ),
    .isolated_i    ( '0                    ),
    .testmode_i    ( '0                    ),
    .isolate_o     (                       ),
    .clk_ena_o     (                       ),
    .reset_no      (                       )
  );

  // second serial instance
  floo_serial_link_narrow_wide #(
    .narrow_req_flit_t ( narrow_req_flit_t ),
    .narrow_rsp_flit_t ( narrow_rsp_flit_t ),
    .wide_flit_t       ( wide_flit_t       ),
    .cfg_req_t         ( cfg_req_t         ),
    .cfg_rsp_t         ( cfg_rsp_t         ),
    .hw2reg_t          ( serial_link_reg_pkg::serial_link_hw2reg_t ),
    .reg2hw_t          ( serial_link_reg_pkg::serial_link_reg2hw_t ),
    .NumChannels       ( NumChannels       ),
    .NumLanes          ( NumLanes          ),
    .MaxClkDiv         ( MaxClkDiv         )
  ) i_serial_link_1 (
    .clk_i         ( clk_2                 ),
    .rst_ni        ( rst_2_n               ),
    .clk_sl_i      ( clk_2                 ),
    .rst_sl_ni     ( rst_2_n               ),
    .clk_reg_i     ( clk_reg               ),
    .rst_reg_ni    ( rst_reg_n             ),
    .narrow_req_i  ( narrow_flit_req_out_2 ),
    .narrow_rsp_i  ( narrow_flit_rsp_out_2 ),
    .narrow_req_o  ( narrow_flit_req_in_2  ),
    .narrow_rsp_o  ( narrow_flit_rsp_in_2  ),
    .wide_i        ( wide_flit_out_2       ),
    .wide_o        ( wide_flit_in_2        ),
    .cfg_req_i     ( cfg_req_2             ),
    .cfg_rsp_o     ( cfg_rsp_2             ),
    .ddr_rcv_clk_i ( ddr_rcv_clk_1         ),
    .ddr_rcv_clk_o ( ddr_rcv_clk_2         ),
    .ddr_i         ( ddr_o                 ),
    .ddr_o         ( ddr_i                 ),
    .isolated_i    ( '0                    ),
    .testmode_i    ( '0                    ),
    .isolate_o     (                       ),
    .clk_ena_o     (                       ),
    .reset_no      (                       )
  );

  floo_narrow_wide_chimney #(
    .RouteAlgo               ( floo_pkg::IdTable       ),
    .NarrowMaxTxns           ( NarrowMaxTxns           ),
    .NarrowMaxTxnsPerId      ( NarrowMaxTxnsPerId      ),
    .NarrowReorderBufferSize ( NarrowReorderBufferSize ),
    .WideMaxTxns             ( WideMaxTxns             ),
    .WideMaxTxnsPerId        ( WideMaxTxnsPerId        ),
    .WideReorderBufferSize   ( WideReorderBufferSize   )
  ) i_floo_axi_chimney_1 (
    .clk_i            ( clk_2                 ),
    .rst_ni           ( rst_2_n               ),
    .sram_cfg_i       ( '0                    ),
    .test_enable_i    ( 1'b0                  ),
    .narrow_in_req_i  ( narrow_axi_in_req_2   ),
    .narrow_in_rsp_o  ( narrow_axi_in_rsp_2   ),
    .narrow_out_req_o ( narrow_axi_out_req_2  ),
    .narrow_out_rsp_i ( narrow_axi_out_rsp_2  ),
    .wide_in_req_i    ( wide_axi_in_req_2     ),
    .wide_in_rsp_o    ( wide_axi_in_rsp_2     ),
    .wide_out_req_o   ( wide_axi_out_req_2    ),
    .wide_out_rsp_i   ( wide_axi_out_rsp_2    ),
    .xy_id_i          (                       ),
    .id_i             ( '0                    ),
    .narrow_req_o     ( narrow_flit_req_out_2 ),
    .narrow_rsp_o     ( narrow_flit_rsp_out_2 ),
    .narrow_req_i     ( narrow_flit_req_in_2  ),
    .narrow_rsp_i     ( narrow_flit_rsp_in_2  ),
    .wide_o           ( wide_flit_out_2       ),
    .wide_i           ( wide_flit_in_2        )
  );

  REG_BUS #(
    .ADDR_WIDTH (RegAddrWidth),
    .DATA_WIDTH (RegDataWidth)
  ) cfg_1(clk_reg), cfg_2(clk_reg);

  `REG_BUS_ASSIGN_TO_REQ(cfg_req_1, cfg_1)
  `REG_BUS_ASSIGN_FROM_RSP(cfg_1, cfg_rsp_1)

  `REG_BUS_ASSIGN_TO_REQ(cfg_req_2, cfg_2)
  `REG_BUS_ASSIGN_FROM_RSP(cfg_2, cfg_rsp_2)

  typedef reg_test::reg_driver #(
    .AW ( RegAddrWidth ),
    .DW ( RegDataWidth ),
    .TA ( 100ps        ),
    .TT ( 500ps        )
  ) reg_master_t;

  static reg_master_t reg_master_1 = new ( cfg_1 );
  static reg_master_t reg_master_2 = new ( cfg_2 );

  // narrow busses
  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( NarrowInAddrWidth ),
    .AXI_DATA_WIDTH ( NarrowInDataWidth ),
    .AXI_ID_WIDTH   ( NarrowInIdWidth   ),
    .AXI_USER_WIDTH ( NarrowInUserWidth )
  ) narrow_axi_in_1(clk_1), narrow_axi_in_2(clk_2);

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( NarrowOutAddrWidth ),
    .AXI_DATA_WIDTH ( NarrowOutDataWidth ),
    .AXI_ID_WIDTH   ( NarrowOutIdWidth   ),
    .AXI_USER_WIDTH ( NarrowOutUserWidth )
  ) narrow_axi_out_1(clk_1), narrow_axi_out_2(clk_2);

  // wide busses
  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( WideInAddrWidth ),
    .AXI_DATA_WIDTH ( WideInDataWidth ),
    .AXI_ID_WIDTH   ( WideInIdWidth   ),
    .AXI_USER_WIDTH ( WideInUserWidth )
  ) wide_axi_in_1(clk_1), wide_axi_in_2(clk_2);

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( WideOutAddrWidth ),
    .AXI_DATA_WIDTH ( WideOutDataWidth ),
    .AXI_ID_WIDTH   ( WideOutIdWidth   ),
    .AXI_USER_WIDTH ( WideOutUserWidth )
  ) wide_axi_out_1(clk_1), wide_axi_out_2(clk_2);

  // narrow assignments
  `AXI_ASSIGN_TO_REQ(narrow_axi_in_req_1, narrow_axi_in_1)
  `AXI_ASSIGN_FROM_RESP(narrow_axi_in_1, narrow_axi_in_rsp_1)

  `AXI_ASSIGN_TO_REQ(narrow_axi_in_req_2, narrow_axi_in_2)
  `AXI_ASSIGN_FROM_RESP(narrow_axi_in_2, narrow_axi_in_rsp_2)

  `AXI_ASSIGN_FROM_REQ(narrow_axi_out_1, narrow_axi_out_req_1)
  `AXI_ASSIGN_TO_RESP(narrow_axi_out_rsp_1, narrow_axi_out_1)

  `AXI_ASSIGN_FROM_REQ(narrow_axi_out_2, narrow_axi_out_req_2)
  `AXI_ASSIGN_TO_RESP(narrow_axi_out_rsp_2, narrow_axi_out_2)

  // wide assignments
  `AXI_ASSIGN_TO_REQ(wide_axi_in_req_1, wide_axi_in_1)
  `AXI_ASSIGN_FROM_RESP(wide_axi_in_1, wide_axi_in_rsp_1)

  `AXI_ASSIGN_TO_REQ(wide_axi_in_req_2, wide_axi_in_2)
  `AXI_ASSIGN_FROM_RESP(wide_axi_in_2, wide_axi_in_rsp_2)

  `AXI_ASSIGN_FROM_REQ(wide_axi_out_1, wide_axi_out_req_1)
  `AXI_ASSIGN_TO_RESP(wide_axi_out_rsp_1, wide_axi_out_1)

  `AXI_ASSIGN_FROM_REQ(wide_axi_out_2, wide_axi_out_req_2)
  `AXI_ASSIGN_TO_RESP(wide_axi_out_rsp_2, wide_axi_out_2)

  // narrow master type
  typedef axi_test::axi_rand_master #(
    .AW                   ( NarrowInAddrWidth ),
    .DW                   ( NarrowInDataWidth ),
    .IW                   ( NarrowInIdWidth   ),
    .UW                   ( NarrowInUserWidth ),
    .TA                   ( 100ps             ),
    .TT                   ( 500ps             ),
    .MAX_READ_TXNS        ( 4                 ),
    .MAX_WRITE_TXNS       ( 4                 ),
    .AX_MIN_WAIT_CYCLES   ( min_wait_cycles   ),
    .AX_MAX_WAIT_CYCLES   ( max_wait_cycles   ),
    .W_MIN_WAIT_CYCLES    ( min_wait_cycles   ),
    .W_MAX_WAIT_CYCLES    ( max_wait_cycles   ),
    .RESP_MIN_WAIT_CYCLES ( min_wait_cycles   ),
    .RESP_MAX_WAIT_CYCLES ( max_wait_cycles   ),
    // .AXI_MAX_BURST_LEN    ( 1                 ),
    .TRAFFIC_SHAPING      ( 1                 ),
    .AXI_EXCLS            ( 1'b0              ),
    .AXI_ATOPS            ( 1'b0              ),
    .AXI_BURST_FIXED      ( 1'b1              ),
    .AXI_BURST_INCR       ( 1'b1              ),
    .AXI_BURST_WRAP       ( 1'b0              )
  ) narrow_axi_rand_master_t;

  // narrow slave type
  typedef axi_test::axi_rand_slave #(
    .AW                   ( NarrowOutAddrWidth ),
    .DW                   ( NarrowOutDataWidth ),
    .IW                   ( NarrowOutIdWidth   ),
    .UW                   ( NarrowOutUserWidth ),
    .TA                   ( 100ps              ),
    .TT                   ( 500ps              ),
    .RAND_RESP            ( 0                  ),
    .AX_MIN_WAIT_CYCLES   ( min_wait_cycles    ),
    .AX_MAX_WAIT_CYCLES   ( max_wait_cycles    ),
    .R_MIN_WAIT_CYCLES    ( min_wait_cycles    ),
    .R_MAX_WAIT_CYCLES    ( max_wait_cycles    ),
    .RESP_MIN_WAIT_CYCLES ( min_wait_cycles    ),
    .RESP_MAX_WAIT_CYCLES ( max_wait_cycles    )
  ) narrow_axi_rand_slave_t;

  // wide master type
  typedef axi_test::axi_rand_master #(
    .AW                   ( WideInAddrWidth ),
    .DW                   ( WideInDataWidth ),
    .IW                   ( WideInIdWidth   ),
    .UW                   ( WideInUserWidth ),
    .TA                   ( 100ps           ),
    .TT                   ( 500ps           ),
    .MAX_READ_TXNS        ( 32              ),
    .MAX_WRITE_TXNS       ( 32              ),
    .AX_MIN_WAIT_CYCLES   ( min_wait_cycles ),
    .AX_MAX_WAIT_CYCLES   ( max_wait_cycles ),
    .W_MIN_WAIT_CYCLES    ( min_wait_cycles ),
    .W_MAX_WAIT_CYCLES    ( max_wait_cycles ),
    .RESP_MIN_WAIT_CYCLES ( min_wait_cycles ),
    .RESP_MAX_WAIT_CYCLES ( max_wait_cycles ),
    // .AXI_MAX_BURST_LEN    ( 0               ),
    .TRAFFIC_SHAPING      ( 1               ),
    .AXI_EXCLS            ( 1'b0            ),
    .AXI_ATOPS            ( 1'b0            ),
    .AXI_BURST_FIXED      ( 1'b1            ),
    .AXI_BURST_INCR       ( 1'b1            ),
    .AXI_BURST_WRAP       ( 1'b0            )
  ) wide_axi_rand_master_t;

  // wide slave type
  typedef axi_test::axi_rand_slave #(
    .AW                   ( WideOutAddrWidth ),
    .DW                   ( WideOutDataWidth ),
    .IW                   ( WideOutIdWidth   ),
    .UW                   ( WideOutUserWidth ),
    .TA                   ( 100ps            ),
    .TT                   ( 500ps            ),
    .RAND_RESP            ( 0                ),
    .AX_MIN_WAIT_CYCLES   ( min_wait_cycles  ),
    .AX_MAX_WAIT_CYCLES   ( max_wait_cycles  ),
    .R_MIN_WAIT_CYCLES    ( min_wait_cycles  ),
    .R_MAX_WAIT_CYCLES    ( max_wait_cycles  ),
    .RESP_MIN_WAIT_CYCLES ( min_wait_cycles  ),
    .RESP_MAX_WAIT_CYCLES ( max_wait_cycles  )
  ) wide_axi_rand_slave_t;

  // narrow channels
  static narrow_axi_rand_master_t narrow_rand_master_1 = new ( narrow_axi_in_1  );
  static narrow_axi_rand_master_t narrow_rand_master_2 = new ( narrow_axi_in_2  );

  static narrow_axi_rand_slave_t  narrow_rand_slave_1  = new ( narrow_axi_out_1 );
  static narrow_axi_rand_slave_t  narrow_rand_slave_2  = new ( narrow_axi_out_2 );

  // wide channels
  static wide_axi_rand_master_t wide_rand_master_1 = new ( wide_axi_in_1  );
  static wide_axi_rand_master_t wide_rand_master_2 = new ( wide_axi_in_2  );

  static wide_axi_rand_slave_t  wide_rand_slave_1  = new ( wide_axi_out_1 );
  static wide_axi_rand_slave_t  wide_rand_slave_2  = new ( wide_axi_out_2 );

  logic [3:0] mst_done;
  logic config_done_1, config_done_2;
  int time_narrow_1;
  int time_narrow_2;
  int time_wide_1;
  int time_wide_2;

  // By default perform Testduration Reads & Writes (to disable a master, assign its read and write count to zero)
  int NumWrites_narrow_1 = TestDuration;
  int NumReads_narrow_1  = TestDuration;
  int NumWrites_narrow_2 = 0;
  int NumReads_narrow_2  = 0;
  int NumWrites_wide_1   = 0;
  int NumReads_wide_1    = 0;
  int NumWrites_wide_2   = TestDuration;
  int NumReads_wide_2    = TestDuration;

  initial begin
    narrow_rand_slave_1.reset();
    wait_for_reset_1();
    narrow_rand_slave_1.run();
  end

  initial begin
    narrow_rand_slave_2.reset();
    wait_for_reset_2();
    narrow_rand_slave_2.run();
  end

  initial begin
    wide_rand_slave_1.reset();
    wait_for_reset_1();
    wide_rand_slave_1.run();
  end

  initial begin
    wide_rand_slave_2.reset();
    wait_for_reset_2();
    wide_rand_slave_2.run();
  end

  initial begin : stimuli_process
    // Activate the config wait blocks
    config_done_1 = 0;
    config_done_2 = 0;
    if (TckSys2 == TckSys1) begin
      $display("INFO: The connected chiplets share the same clock frequency.");
    end else begin
      $display("INFO: The two sides of the off-chip link do not share the same frequency.");
    end
    $display("max_possible_bandwidth_physical_link !%0d Mbit/s, %0d Mbit/s",(1000*i_serial_link_0.i_serial_link_data_link.BandWidth)/(TckSys1*8),(1000*i_serial_link_1.i_serial_link_data_link.BandWidth)/(TckSys2*8));
    reg_master_1.reset_master();
    reg_master_2.reset_master();
    fork
      wait_for_reset_1();
      wait_for_reset_2();
    join
    $info("[SYS] Reset complete");
    fork
      start_link(reg_master_1, 1);
      start_link(reg_master_2, 2);
    join
    $info("[SYS] Links are ready");
    // The random masters are being started
    while (mst_done != '1) begin
      @(posedge clk_1);
      if ($time >= stopSimAfter) begin
        $error("Simulation terminated");
        $display("INFO: Simulation timed out after %1d ns. => You may change the stop time in the tb_floo_serial_link_narrow_wide testbench (localparam).", $time);
        $stop;
      end
    end
    stop_sim();
  end

  initial begin : start_narrow_master_1
    automatic time start_cycle, end_cycle;
    automatic int unsigned data_sent = 0;
    automatic int unsigned data_received = 0;

    if ($value$plusargs("NUM_WRITES_1=%d", NumWrites_narrow_1)) begin
      $info("[DDR1] Number of writes specified as %d", NumWrites_narrow_1);
    end
    if ($value$plusargs("NUM_READS_1=%d", NumReads_narrow_1)) begin
      $info("[DDR1] Number of reads specified as %d", NumReads_narrow_1);
    end
    mst_done[0] = 0;
    narrow_rand_master_1.reset();
    wait_for_reset_1();
    narrow_rand_master_1.add_traffic_shaping_fixed_size(1, 3, 1);

    wait_for_config_1();
    start_cycle = $realtime;
    fork
      narrow_rand_master_1.run(NumWrites_narrow_1, NumReads_narrow_1);
      forever begin
        @(posedge clk_1);
        if (narrow_axi_in_rsp_1.r_valid & narrow_axi_in_req_1.r_ready) data_received += $bits(narrow_axi_in_rsp_1.r);
        if (narrow_axi_in_rsp_1.b_valid & narrow_axi_in_req_1.b_ready) data_received += $bits(narrow_axi_in_rsp_1.b);
        if (narrow_axi_in_req_1.ar_valid & narrow_axi_in_rsp_1.ar_ready) data_sent += $bits(narrow_axi_in_req_1.ar);
        if (narrow_axi_in_req_1.aw_valid & narrow_axi_in_rsp_1.aw_ready) data_sent += $bits(narrow_axi_in_req_1.aw);
        if (narrow_axi_in_req_1.w_valid & narrow_axi_in_rsp_1.w_ready) data_sent += $bits(narrow_axi_in_req_1.w);
      end
    join_any
    end_cycle = $realtime;
    $display("benchmarking: narrow1 BW %0d/%0d (sent/rcv) Mbit/s @ %0d/%0d MHz (SoC/PHY)",
      data_sent * 1000 / (end_cycle - start_cycle),
      data_received * 1000 / (end_cycle - start_cycle),
      1000 / TckSys1,
      1000 / TckSys1 / 8);
    $display("INFO: narrow_rand_master_1 finished (time = %0d ns)", (end_cycle - start_cycle));
    time_narrow_1 = (end_cycle - start_cycle);
    mst_done[0] = 1;
  end

  initial begin : start_narrow_master_2
    automatic time start_cycle_narrow2, end_cycle_narrow2;
    automatic int unsigned data_sent_narrow2 = 0;
    automatic int unsigned data_received_narrow2 = 0;

    if ($value$plusargs("NUM_WRITES_2=%d", NumWrites_narrow_2)) begin
      $info("[DDR2] Number of writes specified as %d", NumWrites_narrow_2);
    end
    if ($value$plusargs("NUM_READS_2=%d", NumReads_narrow_2)) begin
      $info("[DDR2] Number of reads specified as %d", NumReads_narrow_2);
    end
    mst_done[1] = 0;
    narrow_rand_master_2.reset();
    wait_for_reset_2();
    narrow_rand_master_2.add_traffic_shaping_fixed_size(1, 3, 1);

    wait_for_config_2();
    start_cycle_narrow2 = $realtime;
    fork
      narrow_rand_master_2.run(NumWrites_narrow_2, NumReads_narrow_2);
      forever begin
        @(posedge clk_2);
        if (narrow_axi_in_rsp_2.r_valid & narrow_axi_in_req_2.r_ready) data_received_narrow2 += $bits(narrow_axi_in_rsp_2.r);
        if (narrow_axi_in_rsp_2.b_valid & narrow_axi_in_req_2.b_ready) data_received_narrow2 += $bits(narrow_axi_in_rsp_2.b);
        if (narrow_axi_in_req_2.ar_valid & narrow_axi_in_rsp_2.ar_ready) data_sent_narrow2 += $bits(narrow_axi_in_req_2.ar);
        if (narrow_axi_in_req_2.aw_valid & narrow_axi_in_rsp_2.aw_ready) data_sent_narrow2 += $bits(narrow_axi_in_req_2.aw);
        if (narrow_axi_in_req_2.w_valid & narrow_axi_in_rsp_2.w_ready) data_sent_narrow2 += $bits(narrow_axi_in_req_2.w);
      end
    join_any
    end_cycle_narrow2 = $realtime;
    $display("benchmarking: narrow2 BW %0d/%0d (sent/rcv) Mbit/s @ %0d/%0d MHz (SoC/PHY)",
      data_sent_narrow2 * 1000 / (end_cycle_narrow2 - start_cycle_narrow2),
      data_received_narrow2 * 1000 / (end_cycle_narrow2 - start_cycle_narrow2),
      1000 / TckSys2,
      1000 / TckSys2 / 8);

    $display("INFO: narrow_rand_master_2 finished (time = %0d ns)", (end_cycle_narrow2 - start_cycle_narrow2));
    time_narrow_2 = (end_cycle_narrow2 - start_cycle_narrow2);
    mst_done[1] = 1;
  end

  initial begin : start_wide_master_1
    automatic time start_cycle_wide, end_cycle_wide;
    automatic int unsigned data_sent_wide = 0;
    automatic int unsigned data_received_wide = 0;

    mst_done[2] = 0;
    wide_rand_master_1.reset();
    wait_for_reset_1();
    wide_rand_master_1.add_traffic_shaping_fixed_size(32, 6, 1);

    wait_for_config_1();
    start_cycle_wide = $realtime;
    fork
      wide_rand_master_1.run(NumWrites_wide_1, NumReads_wide_1);
      forever begin
        @(posedge clk_1);
        if (wide_axi_in_rsp_1.r_valid & wide_axi_in_req_1.r_ready) data_received_wide += $bits(wide_axi_in_rsp_1.r);
        if (wide_axi_in_rsp_1.b_valid & wide_axi_in_req_1.b_ready) data_received_wide += $bits(wide_axi_in_rsp_1.b);
        if (wide_axi_in_req_1.ar_valid & wide_axi_in_rsp_1.ar_ready) data_sent_wide += $bits(wide_axi_in_req_1.ar);
        if (wide_axi_in_req_1.aw_valid & wide_axi_in_rsp_1.aw_ready) data_sent_wide += $bits(wide_axi_in_req_1.aw);
        if (wide_axi_in_req_1.w_valid & wide_axi_in_rsp_1.w_ready) data_sent_wide += $bits(wide_axi_in_req_1.w);
      end
    join_any
    end_cycle_wide = $realtime;
    $display("benchmarking: wide1 BW %0d/%0d (sent/rcv) Mbit/s @ %0d/%0d MHz (SoC/PHY)",
      data_sent_wide * 1000 / (end_cycle_wide - start_cycle_wide),
      data_received_wide * 1000 / (end_cycle_wide - start_cycle_wide),
      1000 / TckSys1,
      1000 / TckSys1 / 8);
    $display("INFO: wide_rand_master_1 finished (time = %0d ns)", (end_cycle_wide - start_cycle_wide));
    time_wide_1 = (end_cycle_wide - start_cycle_wide);
    mst_done[2] = 1;
  end

  initial begin : start_wide_master_2
    automatic time start_cycle_wide2, end_cycle_wide2;
    automatic int unsigned data_sent_wide2 = 0;
    automatic int unsigned data_received_wide2 = 0;

    mst_done[3] = 0;
    wide_rand_master_2.reset();
    wait_for_reset_2();
    wide_rand_master_2.add_traffic_shaping_fixed_size(32, 6, 1);

    wait_for_config_2();
    start_cycle_wide2 = $realtime;
    fork
      wide_rand_master_2.run(NumWrites_wide_2, NumReads_wide_2);
      forever begin
        @(posedge clk_2);
        if (wide_axi_in_rsp_2.r_valid & wide_axi_in_req_2.r_ready) data_received_wide2 += $bits(wide_axi_in_rsp_2.r);
        if (wide_axi_in_rsp_2.b_valid & wide_axi_in_req_2.b_ready) data_received_wide2 += $bits(wide_axi_in_rsp_2.b);
        if (wide_axi_in_req_2.ar_valid & wide_axi_in_rsp_2.ar_ready) data_sent_wide2 += $bits(wide_axi_in_req_2.ar);
        if (wide_axi_in_req_2.aw_valid & wide_axi_in_rsp_2.aw_ready) data_sent_wide2 += $bits(wide_axi_in_req_2.aw);
        if (wide_axi_in_req_2.w_valid & wide_axi_in_rsp_2.w_ready) data_sent_wide2 += $bits(wide_axi_in_req_2.w);
      end
    join_any
    end_cycle_wide2 = $realtime;
    $display("benchmarking: wide2 BW %0d/%0d (sent/rcv) Mbit/s @ %0d/%0d MHz (SoC/PHY)",
      data_sent_wide2 * 1000 / (end_cycle_wide2 - start_cycle_wide2),
      data_received_wide2 * 1000 / (end_cycle_wide2 - start_cycle_wide2),
      1000 / TckSys2,
      1000 / TckSys2 / 8);
    $display("INFO: wide_rand_master_2 finished (time = %0d ns)", (end_cycle_wide2 - start_cycle_wide2));
    time_wide_2 = (end_cycle_wide2 - start_cycle_wide2);
    mst_done[3] = 1;
  end


  // =============================
  //    Checks - narrow_channel
  // =============================

  narrow_axi_in_req_t narrow_remapped_out_req_1, narrow_remapped_out_req_2;
  narrow_axi_in_resp_t narrow_remapped_out_rsp_1, narrow_remapped_out_rsp_2;

  axi_chan_compare #(
    .IgnoreId  ( 1'b1                      ),
    .aw_chan_t ( narrow_axi_in_aw_chan_t   ),
    .w_chan_t  ( narrow_axi_in_w_chan_t    ),
    .b_chan_t  ( narrow_axi_in_b_chan_t    ),
    .ar_chan_t ( narrow_axi_in_ar_chan_t   ),
    .r_chan_t  ( narrow_axi_in_r_chan_t    ),
    .req_t     ( narrow_axi_in_req_t       ),
    .resp_t    ( narrow_axi_in_resp_t      )
  ) i_narrow_channel_compare_1_to_2 (
    .clk_a_i   ( clk_1                     ),
    .clk_b_i   ( clk_2                     ),
    .axi_a_req ( narrow_axi_in_req_1       ),
    .axi_a_res ( narrow_axi_in_rsp_1       ),
    .axi_b_req ( narrow_remapped_out_req_2 ),
    .axi_b_res ( narrow_remapped_out_rsp_2 )
  );

  `AXI_ASSIGN_REQ_STRUCT(narrow_remapped_out_req_2, narrow_axi_out_req_2)
  `AXI_ASSIGN_RESP_STRUCT(narrow_remapped_out_rsp_2, narrow_axi_out_rsp_2)

  axi_chan_compare #(
    .IgnoreId  ( 1'b1                      ),
    .aw_chan_t ( narrow_axi_in_aw_chan_t   ),
    .w_chan_t  ( narrow_axi_in_w_chan_t    ),
    .b_chan_t  ( narrow_axi_in_b_chan_t    ),
    .ar_chan_t ( narrow_axi_in_ar_chan_t   ),
    .r_chan_t  ( narrow_axi_in_r_chan_t    ),
    .req_t     ( narrow_axi_in_req_t       ),
    .resp_t    ( narrow_axi_in_resp_t      )
  ) i_narrow_channel_compare_2_to_1 (
    .clk_a_i   ( clk_2                     ),
    .clk_b_i   ( clk_1                     ),
    .axi_a_req ( narrow_axi_in_req_2       ),
    .axi_a_res ( narrow_axi_in_rsp_2       ),
    .axi_b_req ( narrow_remapped_out_req_1 ),
    .axi_b_res ( narrow_remapped_out_rsp_1 )
  );

  `AXI_ASSIGN_REQ_STRUCT(narrow_remapped_out_req_1, narrow_axi_out_req_1)
  `AXI_ASSIGN_RESP_STRUCT(narrow_remapped_out_rsp_1, narrow_axi_out_rsp_1)

  // ===========================
  //    Checks - wide_channel
  // ===========================

  wide_axi_in_req_t wide_remapped_out_req_1, wide_remapped_out_req_2;
  wide_axi_in_resp_t wide_remapped_out_rsp_1, wide_remapped_out_rsp_2;

  axi_chan_compare #(
    .IgnoreId  ( 1'b1                    ),
    .aw_chan_t ( wide_axi_in_aw_chan_t   ),
    .w_chan_t  ( wide_axi_in_w_chan_t    ),
    .b_chan_t  ( wide_axi_in_b_chan_t    ),
    .ar_chan_t ( wide_axi_in_ar_chan_t   ),
    .r_chan_t  ( wide_axi_in_r_chan_t    ),
    .req_t     ( wide_axi_in_req_t       ),
    .resp_t    ( wide_axi_in_resp_t      )
  ) i_wide_channel_compare_1_to_2 (
    .clk_a_i   ( clk_1                   ),
    .clk_b_i   ( clk_2                   ),
    .axi_a_req ( wide_axi_in_req_1       ),
    .axi_a_res ( wide_axi_in_rsp_1       ),
    .axi_b_req ( wide_remapped_out_req_2 ),
    .axi_b_res ( wide_remapped_out_rsp_2 )
  );

  `AXI_ASSIGN_REQ_STRUCT(wide_remapped_out_req_2, wide_axi_out_req_2)
  `AXI_ASSIGN_RESP_STRUCT(wide_remapped_out_rsp_2, wide_axi_out_rsp_2)

  axi_chan_compare #(
    .IgnoreId  ( 1'b1                    ),
    .aw_chan_t ( wide_axi_in_aw_chan_t   ),
    .w_chan_t  ( wide_axi_in_w_chan_t    ),
    .b_chan_t  ( wide_axi_in_b_chan_t    ),
    .ar_chan_t ( wide_axi_in_ar_chan_t   ),
    .r_chan_t  ( wide_axi_in_r_chan_t    ),
    .req_t     ( wide_axi_in_req_t       ),
    .resp_t    ( wide_axi_in_resp_t      )
  ) i_wide_channel_compare_2_to_1 (
    .clk_a_i   ( clk_2                   ),
    .clk_b_i   ( clk_1                   ),
    .axi_a_req ( wide_axi_in_req_2       ),
    .axi_a_res ( wide_axi_in_rsp_2       ),
    .axi_b_req ( wide_remapped_out_req_1 ),
    .axi_b_res ( wide_remapped_out_rsp_1 )
  );

  `AXI_ASSIGN_REQ_STRUCT(wide_remapped_out_req_1, wide_axi_out_req_1)
  `AXI_ASSIGN_RESP_STRUCT(wide_remapped_out_rsp_1, wide_axi_out_rsp_1)

  // =======================
  //    Benchmarking unit
  // =======================

  serial_link_benchmarking_unit #(
    .narrow_axi_rand_master_t ( narrow_axi_rand_master_t ),
    .narrow_axi_rand_slave_t  ( narrow_axi_rand_slave_t  ),
    .wide_axi_rand_master_t   ( wide_axi_rand_master_t   ),
    .wide_axi_rand_slave_t    ( wide_axi_rand_slave_t    )
  ) i_benchmarking (
    .serial_link_0_valid_cycles_from_phys   ( serial_link_0_valid_cycles_from_phys   ),
    .serial_link_0_number_cycles            ( serial_link_0_number_cycles            ),
    .serial_link_0_valid_cycles_to_phys     ( serial_link_0_valid_cycles_to_phys     ),
    .serial_link_1_valid_cycles_from_phys   ( serial_link_1_valid_cycles_from_phys   ),
    .serial_link_1_number_cycles            ( serial_link_1_number_cycles            ),
    .serial_link_1_valid_cycles_to_phys     ( serial_link_1_valid_cycles_to_phys     ),
    .data_link_0_num_cred_only_pack_sent    ( data_link_0_num_cred_only_pack_sent    ),
    .data_link_0_sum_stalled_cyc_cred_cntrs ( data_link_0_sum_stalled_cyc_cred_cntrs ),
    .data_link_1_num_cred_only_pack_sent    ( data_link_1_num_cred_only_pack_sent    ),
    .data_link_1_sum_stalled_cyc_cred_cntrs ( data_link_1_sum_stalled_cyc_cred_cntrs ),
    .network_0_valid_cycles_to_phys         ( network_0_valid_cycles_to_phys         ),
    .network_0_number_cycles                ( network_0_number_cycles                ),
    .network_0_num_cred_only_pack_sent      ( network_0_num_cred_only_pack_sent      ),
    .network_0_valid_cycles_from_phys       ( network_0_valid_cycles_from_phys       ),
    .network_0_sum_stalled_cyc_cred_cntrs   ( network_0_sum_stalled_cyc_cred_cntrs   ),
    .network_1_valid_cycles_to_phys         ( network_1_valid_cycles_to_phys         ),
    .network_1_number_cycles                ( network_1_number_cycles                ),
    .network_1_num_cred_only_pack_sent      ( network_1_num_cred_only_pack_sent      ),
    .network_1_valid_cycles_from_phys       ( network_1_valid_cycles_from_phys       ),
    .network_1_sum_stalled_cyc_cred_cntrs   ( network_1_sum_stalled_cyc_cred_cntrs   ),

    .lat_0  ( lat_0  ),
    .lat_1  ( lat_1  ),
    .lat_2  ( lat_2  ),
    .lat_3  ( lat_3  ),
    .lat_4  ( lat_4  ),
    .lat_5  ( lat_5  ),
    .lat_6  ( lat_6  ),
    .lat_7  ( lat_7  ),
    .lat_8  ( lat_8  ),
    .lat_9  ( lat_9  ),
    .lat_10 ( lat_10 ),
    .lat_11 ( lat_11 ),
    .lat_12 ( lat_12 ),
    .lat_13 ( lat_13 ),
    .lat_14 ( lat_14 ),
    .lat_15 ( lat_15 ),
    .lat_16 ( lat_16 ),
    .lat_17 ( lat_17 ),
    .lat_18 ( lat_18 ),
    .lat_19 ( lat_19 ),
    .lat_20 ( lat_20 ),
    .lat_21 ( lat_21 ),
    .lat_22 ( lat_22 ),
    .lat_23 ( lat_23 ),
    .lat_24 ( lat_24 ),
    .lat_25 ( lat_25 ),
    .lat_26 ( lat_26 ),
    .lat_27 ( lat_27 ),
    .lat_28 ( lat_28 ),
    .lat_29 ( lat_29 ),
    .lat_30 ( lat_30 ),
    .lat_31 ( lat_31 ),
    .lat_32 ( lat_32 ),
    .lat_33 ( lat_33 ),
    .lat_34 ( lat_34 ),
    .lat_35 ( lat_35 ),
    .lat_36 ( lat_36 ),
    .lat_37 ( lat_37 ),
    .lat_38 ( lat_38 ),
    .lat_39 ( lat_39 )
  );

  // ===========
  //    Tasks
  // ===========

  task automatic wait_for_config_1();
    while (config_done_1 != 1) begin
      @(posedge clk_1);
    end
  endtask

  task automatic wait_for_config_2();
    while (config_done_2 != 1) begin
      @(posedge clk_2);
    end
  endtask

  task automatic wait_for_reset_1();
    @(posedge rst_1_n);
  endtask

  task automatic wait_for_reset_2();
    @(posedge rst_2_n);
  endtask

  task automatic stop_sim();
    repeat(50) begin
      @(posedge clk_1);
    end
    $display("[SYS] Simulation Stopped (%d ns)", $time);
    // benchmarking simulation results printout
    $display("latency_array: %0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
      lat_0, lat_1, lat_2, lat_3, lat_4, lat_5, lat_6, lat_7, lat_8, lat_9,
      lat_10, lat_11, lat_12, lat_13, lat_14, lat_15, lat_16, lat_17, lat_18, lat_19,
      lat_20, lat_21, lat_22, lat_23, lat_24, lat_25, lat_26, lat_27, lat_28, lat_29,
      lat_30, lat_31, lat_32, lat_33, lat_34, lat_35, lat_36, lat_37, lat_38, lat_39);
    $display("numberOfTransactions: %0d %0d %0d %0d %0d %0d %0d %0d",NumWrites_narrow_1,NumReads_narrow_1,NumWrites_narrow_2,NumReads_narrow_2,NumWrites_wide_1,NumReads_wide_1,NumWrites_wide_2,NumReads_wide_2);
    $display("benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.benchmarking_attempts ||| \
valid_coverage_to_phys %3.2f%%, valid_coverage_from_phys %3.2f%%, total_cycles %4d - %4d - %4d",
      100*serial_link_0_valid_cycles_to_phys/(1.0*serial_link_0_number_cycles),
      100*serial_link_0_valid_cycles_from_phys/(1.0*serial_link_0_number_cycles), serial_link_0_number_cycles, serial_link_0_valid_cycles_to_phys,
      serial_link_0_valid_cycles_from_phys);
    $display("benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.num_cred_only ||| cred_only_packets_sent(...and_others) %0d,%0d",
      data_link_0_num_cred_only_pack_sent, data_link_0_sum_stalled_cyc_cred_cntrs);
    $display("benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.noc_bridge_benchmarking ||| %3.2f%% %3.2f%% %0d %0d",
      100*network_0_valid_cycles_to_phys/(1.0*network_0_number_cycles), 100*network_0_valid_cycles_from_phys/(1.0*network_0_number_cycles),
      network_0_num_cred_only_pack_sent, network_0_sum_stalled_cyc_cred_cntrs);
    $display("benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.benchmarking_attempts ||| valid_coverage_to_phys %3.2f%%, \
valid_coverage_from_phys %3.2f%%, total_cycles %4d - %4d - %4d", 100*serial_link_1_valid_cycles_to_phys/(1.0*serial_link_1_number_cycles),
      100*serial_link_1_valid_cycles_from_phys/(1.0*serial_link_1_number_cycles), serial_link_1_number_cycles, serial_link_1_valid_cycles_to_phys,
      serial_link_1_valid_cycles_from_phys);
    $display("benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.num_cred_only ||| cred_only_packets_sent(...and_others) %0d,%0d",
      data_link_1_num_cred_only_pack_sent, data_link_1_sum_stalled_cyc_cred_cntrs);
    $display("benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.noc_bridge_benchmarking ||| %3.2f%% %3.2f%% %0d %0d",
      100*network_1_valid_cycles_to_phys/(1.0*network_1_number_cycles), 100*network_1_valid_cycles_from_phys/(1.0*network_1_number_cycles),
      network_1_num_cred_only_pack_sent, network_1_sum_stalled_cyc_cred_cntrs);
    $display("benchmarking: additionalMetricsForTheSweepScript ||| %0d %0d", data_link_0_sum_stalled_cyc_cred_cntrs,
      data_link_1_sum_stalled_cyc_cred_cntrs);
    $display("benchmarking: Performance Rating (lower is better): %0d (avg)", (time_narrow_1+time_narrow_2+time_wide_1+time_wide_2)/(TestDuration*4));
    $stop();
  endtask

  task automatic cfg_write(reg_master_t drv, cfg_addr_t addr, cfg_data_t data, cfg_strb_t strb='1);
    automatic logic resp;
    drv.send_write(addr, data, strb, resp);
    assert (!resp) else $error("Not able to write cfg reg");
  endtask

  task automatic cfg_read(reg_master_t drv, cfg_addr_t addr, output cfg_data_t data);
    automatic logic resp;
    drv.send_read(addr, data, resp);
    assert (!resp) else $error("Not able to write cfg reg");
  endtask

  task automatic start_link(reg_master_t drv, int id);
    automatic phy_data_t pattern, pattern_q[$];
    automatic cfg_data_t data;
    $info("[DDR%0d]: Enabling clock and deassert link reset.", id);
    // Reset and clock gate sequence, AXI isolation remains enabled
    // De-assert reset
    cfg_write(drv, SERIAL_LINK_CTRL_OFFSET, 32'h300);
    // Assert reset
    cfg_write(drv, SERIAL_LINK_CTRL_OFFSET, 32'h302);
    // Enable clock
    cfg_write(drv, SERIAL_LINK_CTRL_OFFSET, 32'h303);
    // Enable channel allocator bypass mode and
    // auto flush feature but disable sync for RX side
    cfg_write(drv, SERIAL_LINK_CHANNEL_ALLOC_TX_CFG_OFFSET, 32'h3);
    cfg_write(drv, SERIAL_LINK_CHANNEL_ALLOC_RX_CFG_OFFSET, 32'h3);
    // Wait for some clock cycles
    repeat(50) drv.cycle_end();
    // De-isolate AXI ports
    $info("[DDR%0d] Enabling AXI ports...",id);
    cfg_write(drv, SERIAL_LINK_CTRL_OFFSET, 32'h03);
    do begin
      cfg_read(drv, SERIAL_LINK_ISOLATED_OFFSET, data);
    end while(data != 0); // Wait until both isolation status bits are 0 to
                          // indicate disabling of isolation
    $info("[DDR%0d] Link is ready", id);
    if (id == 1) begin
      config_done_1 = 1;
    end else if (id == 2) begin
      config_done_2 = 1;
    end
  endtask;

endmodule : tb_floo_serial_link_narrow_wide
