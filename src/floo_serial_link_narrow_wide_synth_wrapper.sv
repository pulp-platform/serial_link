// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
//  - Yannick Baumann <baumanny@ethz.student.ch>

  `include "register_interface/typedef.svh"
  // required to suppress elaboration errors
  `define performSynthesis

  import serial_link_reg_pkg::*;
  import floo_narrow_wide_flit_pkg::*;
  import serial_link_single_channel_reg_pkg::*;

  localparam int unsigned RegAddrWidth = 32;
  localparam int unsigned RegDataWidth = 32;
  localparam int unsigned RegStrbWidth = RegDataWidth / 8;

	// RegBus types for typedefs
  typedef logic [RegAddrWidth-1:0] cfg_addr_t;
  typedef logic [RegDataWidth-1:0] cfg_data_t;
  typedef logic [RegStrbWidth-1:0] cfg_strb_t;

  `REG_BUS_TYPEDEF_ALL(cfg, cfg_addr_t, cfg_data_t, cfg_strb_t)

module floo_serial_link_narrow_wide_synth_wrapper
#(
) (
  // There are 3 different clock/resets:
  // 1) clk_i & rst_ni: "always-on" clock & reset coming from the SoC domain. Only config registers are conected to this clock
  // 2) clk_sl_i & rst_sl_ni: Same as 1) but clock is gated and reset is SW synchronized. This is the clock that drives the serial link
  //    i.e. network, data-link and physical layer all run on this clock and can be clock gated if needed. If no clock gating, reset synchronization
  //    is desired, you can tie clk_sl_i -> clk_i resp. rst_sl_ni -> rst_ni
  // 3) clk_reg_i & rst_reg_ni: peripheral clock and reset. Only connected to RegBus CDC. If NoRegCdc is set, this clock must be the same as 1)
  input  logic                                 clk_i,
  input  logic                                 rst_ni,
  input  logic                                 clk_sl_i,
  input  logic                                 rst_sl_ni,
  input  logic                                 clk_reg_i,
  input  logic                                 rst_reg_ni,
  // Tie to zero if not used.
  input  logic                                 testmode_i,
  // TODO: rename intput channel to narrow_sth
  input  narrow_req_flit_t                     narrow_req_i,
  input  narrow_rsp_flit_t                     narrow_rsp_i,
  output narrow_req_flit_t                     narrow_req_o,
  output narrow_rsp_flit_t                     narrow_rsp_o,
  input  wide_flit_t                           wide_i,
  output wide_flit_t                           wide_o,
  input  cfg_req_t                             cfg_req_i,
  output cfg_rsp_t                             cfg_rsp_o,
  input  logic [serial_link_pkg::NumChannels-1:0]               ddr_rcv_clk_i,
  output logic [serial_link_pkg::NumChannels-1:0]               ddr_rcv_clk_o,
  input  logic [serial_link_pkg::NumChannels-1:0][serial_link_pkg::NumLanes-1:0] ddr_i,
  output logic [serial_link_pkg::NumChannels-1:0][serial_link_pkg::NumLanes-1:0] ddr_o,
  // AXI isolation signals (in/out). Tie to zero if not used
  input  logic [1:0]                           isolated_i,
  output logic [1:0]                           isolate_o,
  // Clock gate register
  output logic                                 clk_ena_o,
  // synch-reset register
  output logic                                 reset_no
);


floo_serial_link_narrow_wide #(
    .narrow_req_flit_t ( narrow_req_flit_t                         ),
    .narrow_rsp_flit_t ( narrow_rsp_flit_t                         ),
    .wide_flit_t       ( wide_flit_t                               ),
    .cfg_req_t         ( cfg_req_t                                 ),
    .cfg_rsp_t         ( cfg_rsp_t                                 ),
    .hw2reg_t          ( serial_link_reg_pkg::serial_link_hw2reg_t ),
    .reg2hw_t          ( serial_link_reg_pkg::serial_link_reg2hw_t ),
    .NumChannels       ( serial_link_pkg::NumChannels              ),
    .NumLanes          ( serial_link_pkg::NumLanes                 ),
    .MaxClkDiv         ( serial_link_pkg::MaxClkDiv                )
  ) i_serial_link_1 (
    .clk_i,
    .rst_ni,
    .clk_sl_i,
    .rst_sl_ni,
    .clk_reg_i,
    .rst_reg_ni,
    .narrow_req_i,
    .narrow_rsp_i,
    .narrow_req_o,
    .narrow_rsp_o,
    .wide_i,
    .wide_o,
    .cfg_req_i,
    .cfg_rsp_o,
    .ddr_rcv_clk_i,
    .ddr_rcv_clk_o,
    .ddr_i,
    .ddr_o,
    .isolated_i,
    .testmode_i,
    .isolate_o,
    .clk_ena_o,
    .reset_no
  );

endmodule : floo_serial_link_narrow_wide_synth_wrapper