// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
//  - Tim Fischer <fischeti@iis.ee.ethz.ch>
//  - Yannick Baumann <baumanny@ethz.student.ch>
// TODO: currently only a template...

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
  localparam time         TckSys2         = 54ns;
  localparam time         TckReg          = 200ns;
  localparam int unsigned RstClkCyclesSys = 1;

  localparam int unsigned RegAddrWidth    = 32;
  localparam int unsigned RegDataWidth    = 32;
  localparam int unsigned RegStrbWidth    = RegDataWidth / 8;

  localparam logic [NumLanes*2-1:0] CalibrationPattern = {{NumLanes/4}{4'b1010, 4'b0101}};

  localparam int unsigned NarrowReorderBufferSize = 64;
  localparam int unsigned NarrowMaxTxns           = 32;
  localparam int unsigned NarrowMaxTxnsPerId      = 32;

  // Stop the simulation if this simulation time (ns) is exceeded.
  localparam int stopSimAfter = 75000000;

  // ==============
  //    DDR Link
  // ==============

  // AXI types for typedefs of narrow channel
  typedef logic [NarrowInIdWidth-1:0  ]  narrow_in_id_t;
  typedef logic [NarrowInAddrWidth-1:0]  narrow_in_addr_t;
  typedef logic [NarrowInDataWidth-1:0]  narrow_in_data_t;
  typedef logic [NarrowInDataWidth/8-1:0]  narrow_in_strb_t;
  typedef logic [NarrowInUserWidth-1:0]  narrow_in_user_t;

  `AXI_TYPEDEF_ALL(narrow_axi_in, narrow_in_addr_t, narrow_in_id_t, narrow_in_data_t, narrow_in_strb_t, narrow_in_user_t)

  typedef logic [NarrowOutIdWidth-1:0  ]  narrow_out_id_t;
  typedef logic [NarrowOutAddrWidth-1:0]  narrow_out_addr_t;
  typedef logic [NarrowOutDataWidth-1:0]  narrow_out_data_t;
  typedef logic [NarrowOutDataWidth/8-1:0]  narrow_out_strb_t;
  typedef logic [NarrowOutUserWidth-1:0]  narrow_out_user_t;

  `AXI_TYPEDEF_ALL(narrow_axi_out, narrow_out_addr_t, narrow_out_id_t, narrow_out_data_t, narrow_out_strb_t, narrow_out_user_t)
  // RegBus types for typedefs
  typedef logic [RegAddrWidth-1:0]  cfg_addr_t;
  typedef logic [RegDataWidth-1:0]  cfg_data_t;
  typedef logic [RegStrbWidth-1:0]  cfg_strb_t;

  `REG_BUS_TYPEDEF_ALL(cfg, cfg_addr_t, cfg_data_t, cfg_strb_t)

  // Model signals
  logic [NumChannels-1:0]  ddr_rcv_clk_1, ddr_rcv_clk_2;
  narrow_axi_out_req_t   narrow_axi_out_req_1, narrow_axi_out_req_2;
  narrow_axi_out_resp_t  narrow_axi_out_rsp_1, narrow_axi_out_rsp_2;
  narrow_axi_in_req_t   narrow_axi_in_req_1,  narrow_axi_in_req_2;
  narrow_axi_in_resp_t  narrow_axi_in_rsp_1,  narrow_axi_in_rsp_2;
  narrow_req_flit_t  narrow_flit_req_out_1, narrow_flit_req_out_2;
  narrow_rsp_flit_t  narrow_flit_rsp_out_1, narrow_flit_rsp_out_2;
  narrow_req_flit_t  narrow_flit_req_in_1, narrow_flit_req_in_2;
  narrow_rsp_flit_t  narrow_flit_rsp_in_1, narrow_flit_rsp_in_2;
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
    .NarrowReorderBufferSize ( NarrowReorderBufferSize )
    // TODO: add wide channel parameter definitions...
  ) i_floo_axi_chimney_0 (
    .clk_i            ( clk_1                ),
    .rst_ni           ( rst_1_n              ),
    .sram_cfg_i       ( '0                   ),
    .test_enable_i    ( 1'b0                 ),
    .narrow_in_req_i  ( narrow_axi_in_req_1  ),
    .narrow_in_rsp_o  ( narrow_axi_in_rsp_1  ),
    .narrow_out_req_o ( narrow_axi_out_req_1 ),
    .narrow_out_rsp_i ( narrow_axi_out_rsp_1 ),
    // TODO: assign wide channel ports...
    .wide_in_req_i    ( '0                    ),
    // .wide_in_rsp_o    ( TOOD                  ),
    // .wide_out_req_o   ( TODO                  ),
    .wide_out_rsp_i   ( '0                    ),
    .xy_id_i          (                       ),
    .id_i             ( '0                    ),
    .narrow_req_o     ( narrow_flit_req_out_1 ),
    .narrow_rsp_o     ( narrow_flit_rsp_out_1 ),
    .narrow_req_i     ( narrow_flit_req_in_1  ),
    .narrow_rsp_i     ( narrow_flit_rsp_in_1  ),
    // TODO: assign wide channel flit ports...
    // .wide_o           ( TODO                  ),
    .wide_i           ( '0                    )
  );

  floo_serial_link_narrow_wide #(
    .narrow_req_flit_t ( narrow_req_flit_t ),
    .narrow_rsp_flit_t ( narrow_rsp_flit_t ),
    .cfg_req_t         ( cfg_req_t         ),
    .cfg_rsp_t         ( cfg_rsp_t         ),
    .hw2reg_t          ( serial_link_reg_pkg::serial_link_hw2reg_t ),
    // .hw2reg_t          ( serial_link_single_channel_reg_pkg::serial_link_single_channel_hw2reg_t ),
    .reg2hw_t          ( serial_link_reg_pkg::serial_link_reg2hw_t ),
    // .reg2hw_t          ( serial_link_single_channel_reg_pkg::serial_link_single_channel_reg2hw_t ),
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
    .cfg_req_i     ( cfg_req_1             ),
    .cfg_rsp_o     ( cfg_rsp_1             ),
    .ddr_rcv_clk_i ( ddr_rcv_clk_2         ),
    .ddr_rcv_clk_o ( ddr_rcv_clk_1         ),
    .ddr_i         ( ddr_i                 ),
    .ddr_o         ( ddr_o                 )
  );

  // second serial instance
  floo_serial_link_narrow_wide #(
    .narrow_req_flit_t ( narrow_req_flit_t ),
    .narrow_rsp_flit_t ( narrow_rsp_flit_t ),
    .cfg_req_t         ( cfg_req_t         ),
    .cfg_rsp_t         ( cfg_rsp_t         ),
    .hw2reg_t          ( serial_link_reg_pkg::serial_link_hw2reg_t ),
    // .hw2reg_t            ( serial_link_single_channel_reg_pkg::serial_link_single_channel_hw2reg_t ),
    .reg2hw_t          ( serial_link_reg_pkg::serial_link_reg2hw_t ),
    // .reg2hw_t            ( serial_link_single_channel_reg_pkg::serial_link_single_channel_reg2hw_t ),
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
    .cfg_req_i     ( cfg_req_2             ),
    .cfg_rsp_o     ( cfg_rsp_2             ),
    .ddr_rcv_clk_i ( ddr_rcv_clk_1         ),
    .ddr_rcv_clk_o ( ddr_rcv_clk_2         ),
    .ddr_i         ( ddr_o                 ),
    .ddr_o         ( ddr_i                 )
  );

  floo_narrow_wide_chimney #(
    .RouteAlgo               ( floo_pkg::IdTable       ),
    .NarrowMaxTxns           ( NarrowMaxTxns           ),
    .NarrowMaxTxnsPerId      ( NarrowMaxTxnsPerId      ),
    .NarrowReorderBufferSize ( NarrowReorderBufferSize )
    // TODO: add wide channel parameter definitions...
  ) i_floo_axi_chimney_1 (
    .clk_i            ( clk_2                 ),
    .rst_ni           ( rst_2_n               ),
    .sram_cfg_i       ( '0                    ),
    .test_enable_i    ( 1'b0                  ),
    .narrow_in_req_i  ( narrow_axi_in_req_2   ),
    .narrow_in_rsp_o  ( narrow_axi_in_rsp_2   ),
    .narrow_out_req_o ( narrow_axi_out_req_2  ),
    .narrow_out_rsp_i ( narrow_axi_out_rsp_2  ),
    // TODO: assign wide channel axi ports...
    .wide_in_req_i    ( '0                    ),
    // .wide_in_rsp_o    ( TOOD                  ),
    // .wide_out_req_o   ( TODO                  ),
    .wide_out_rsp_i   ( '0                    ),
    .xy_id_i          (                       ),
    .id_i             ( '0                    ),
    .narrow_req_o     ( narrow_flit_req_out_2 ),
    .narrow_rsp_o     ( narrow_flit_rsp_out_2 ),
    .narrow_req_i     ( narrow_flit_req_in_2  ),
    .narrow_rsp_i     ( narrow_flit_rsp_in_2  ),
    // TODO: assign wide channel flit ports...
    // .wide_o           ( TODO                  ),
    .wide_i           ( '0                    )
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

  `AXI_ASSIGN_TO_REQ(narrow_axi_in_req_1, narrow_axi_in_1)
  `AXI_ASSIGN_FROM_RESP(narrow_axi_in_1, narrow_axi_in_rsp_1)

  `AXI_ASSIGN_TO_REQ(narrow_axi_in_req_2, narrow_axi_in_2)
  `AXI_ASSIGN_FROM_RESP(narrow_axi_in_2, narrow_axi_in_rsp_2)

  `AXI_ASSIGN_FROM_REQ(narrow_axi_out_1, narrow_axi_out_req_1)
  `AXI_ASSIGN_TO_RESP(narrow_axi_out_rsp_1, narrow_axi_out_1)

  `AXI_ASSIGN_FROM_REQ(narrow_axi_out_2, narrow_axi_out_req_2)
  `AXI_ASSIGN_TO_RESP(narrow_axi_out_rsp_2, narrow_axi_out_2)

  // master type
  typedef axi_test::axi_rand_master #(
    .AW                   ( NarrowInAddrWidth ),
    .DW                   ( NarrowInDataWidth ),
    .IW                   ( NarrowInIdWidth   ),
    .UW                   ( NarrowInUserWidth ),
    .TA                   ( 100ps             ),
    .TT                   ( 500ps             ),
    .MAX_READ_TXNS        ( 2                 ),
    .MAX_WRITE_TXNS       ( 2                 ),
    .AX_MIN_WAIT_CYCLES   ( 0                 ),
    .AX_MAX_WAIT_CYCLES   ( 0                 ),
    // .AX_MAX_WAIT_CYCLES   ( 100               ),
    .W_MIN_WAIT_CYCLES    ( 0                 ),
    .W_MAX_WAIT_CYCLES    ( 0                 ),
    // .W_MAX_WAIT_CYCLES    ( 100               ),
    .RESP_MIN_WAIT_CYCLES ( 0                 ),
    .RESP_MAX_WAIT_CYCLES ( 0                 ),
    // .RESP_MAX_WAIT_CYCLES ( 100               ),
    .AXI_MAX_BURST_LEN    ( 0                 ),
    .TRAFFIC_SHAPING      ( 0                 ),
    .AXI_EXCLS            ( 1'b1              ),
    .AXI_ATOPS            ( 1'b0              ),
    .AXI_BURST_FIXED      ( 1'b1              ),
    .AXI_BURST_INCR       ( 1'b1              ),
    .AXI_BURST_WRAP       ( 1'b0              )
  ) narrow_axi_rand_master_t;

  // slave type
  typedef axi_test::axi_rand_slave #(
    .AW                   ( NarrowOutAddrWidth ),
    .DW                   ( NarrowOutDataWidth ),
    .IW                   ( NarrowOutIdWidth   ),
    .UW                   ( NarrowOutUserWidth ),
    .TA                   ( 100ps              ),
    .TT                   ( 500ps              ),
    .RAND_RESP            ( 0                  ),
    .AX_MIN_WAIT_CYCLES   ( 0                  ),
    .AX_MAX_WAIT_CYCLES   ( 0                  ),
    // .AX_MAX_WAIT_CYCLES   ( 100                ),
    .R_MIN_WAIT_CYCLES    ( 0                  ),
    .R_MAX_WAIT_CYCLES    ( 0                  ),
    // .R_MAX_WAIT_CYCLES    ( 100                ),
    .RESP_MIN_WAIT_CYCLES ( 0                  ),
    .RESP_MAX_WAIT_CYCLES ( 0                  )
    // .RESP_MAX_WAIT_CYCLES ( 100                )
  ) narrow_axi_rand_slave_t;

  static narrow_axi_rand_master_t narrow_rand_master_1 = new ( narrow_axi_in_1  );
  static narrow_axi_rand_master_t narrow_rand_master_2 = new ( narrow_axi_in_2  );

  static narrow_axi_rand_slave_t  narrow_rand_slave_1  = new ( narrow_axi_out_1 );
  static narrow_axi_rand_slave_t  narrow_rand_slave_2  = new ( narrow_axi_out_2 );

  logic [1:0] mst_done;

  // By default perform Testduration Reads & Writes
  int NumWrites_1 = TestDuration;
  int NumReads_1 = TestDuration;
  int NumWrites_2 = TestDuration;
  int NumReads_2 = TestDuration;

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
    automatic time start_cycle, end_cycle;
    automatic int unsigned data_sent = 0;
    automatic int unsigned data_received = 0;
    if ($value$plusargs("NUM_WRITES_1=%d", NumWrites_1)) begin
      $info("[DDR1] Number of writes specified as %d", NumWrites_1);
    end
    if ($value$plusargs("NUM_READS_1=%d", NumReads_1)) begin
      $info("[DDR1] Number of reads specified as %d", NumReads_1);
    end
    mst_done[0] = 0;
    narrow_rand_master_1.reset();
    wait_for_reset_1();
    start_cycle = $realtime;
    fork
      narrow_rand_master_1.run(NumWrites_1, NumReads_1);
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
    $info("BW %0d/%0d (sent/rcv) Mbit/s @ %0d/%0d MHz (SoC/PHY)",
      data_sent * 1000 / (end_cycle - start_cycle),
      data_received * 1000 / (end_cycle - start_cycle),
      1000 / TckSys1,
      1000 / TckSys1 / 8);
    $display("INFO: time = %0d", (end_cycle - start_cycle));
    mst_done[0] = 1;
  end

  initial begin
    if ($value$plusargs("NUM_WRITES_2=%d", NumWrites_2)) begin
      $info("[DDR2] Number of writes specified as %d", NumWrites_2);
    end
    if ($value$plusargs("NUM_READS_2=%d", NumReads_2)) begin
      $info("[DDR2] Number of reads specified as %d", NumReads_2);
    end
    mst_done[1] = 0;
    narrow_rand_master_2.reset();
    wait_for_reset_2();
    narrow_rand_master_2.run(NumWrites_2, NumReads_2);
    mst_done[1] = 1;
  end

  initial begin : stimuli_process
    if (TckSys2 == TckSys1) begin
      $display("INFO: The connected chiplets share the same clock frequency.");
    end else begin
      $display("INFO: The two sides of the off-chip link do not share the same frequency.");
    end
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

  // ==============
  //    Checks
  // ==============

  narrow_axi_in_req_t axi_remapped_out_req_1, axi_remapped_out_req_2;
  narrow_axi_in_resp_t axi_remapped_out_rsp_1, axi_remapped_out_rsp_2;

  axi_chan_compare #(
    .IgnoreId  ( 1'b1                    ),
    .aw_chan_t ( narrow_axi_in_aw_chan_t ),
    .w_chan_t  ( narrow_axi_in_w_chan_t  ),
    .b_chan_t  ( narrow_axi_in_b_chan_t  ),
    .ar_chan_t ( narrow_axi_in_ar_chan_t ),
    .r_chan_t  ( narrow_axi_in_r_chan_t  ),
    .req_t     ( narrow_axi_in_req_t     ),
    .resp_t    ( narrow_axi_in_resp_t    )
  ) i_axi_channel_compare_1_to_2 (
    .clk_a_i   ( clk_1                  ),
    .clk_b_i   ( clk_2                  ),
    .axi_a_req ( narrow_axi_in_req_1    ),
    .axi_a_res ( narrow_axi_in_rsp_1    ),
    .axi_b_req ( axi_remapped_out_req_2 ),
    .axi_b_res ( axi_remapped_out_rsp_2 )
  );

  `AXI_ASSIGN_REQ_STRUCT(axi_remapped_out_req_2, narrow_axi_out_req_2)
  `AXI_ASSIGN_RESP_STRUCT(axi_remapped_out_rsp_2, narrow_axi_out_rsp_2)

  axi_chan_compare #(
    .IgnoreId  ( 1'b1                    ),
    .aw_chan_t ( narrow_axi_in_aw_chan_t ),
    .w_chan_t  ( narrow_axi_in_w_chan_t  ),
    .b_chan_t  ( narrow_axi_in_b_chan_t  ),
    .ar_chan_t ( narrow_axi_in_ar_chan_t ),
    .r_chan_t  ( narrow_axi_in_r_chan_t  ),
    .req_t     ( narrow_axi_in_req_t     ),
    .resp_t    ( narrow_axi_in_resp_t    )
  ) i_axi_channel_compare_2_to_1 (
    .clk_a_i   ( clk_2                  ),
    .clk_b_i   ( clk_1                  ),
    .axi_a_req ( narrow_axi_in_req_2    ),
    .axi_a_res ( narrow_axi_in_rsp_2    ),
    .axi_b_req ( axi_remapped_out_req_1 ),
    .axi_b_res ( axi_remapped_out_rsp_1 )
  );

  `AXI_ASSIGN_REQ_STRUCT(axi_remapped_out_req_1, narrow_axi_out_req_1)
  `AXI_ASSIGN_RESP_STRUCT(axi_remapped_out_rsp_1, narrow_axi_out_rsp_1)

  // ==============
  //    Tasks
  // ==============

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
  endtask;

endmodule : tb_floo_serial_link_narrow_wide
