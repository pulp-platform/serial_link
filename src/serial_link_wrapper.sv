// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Alessandro Ottaviano <aottaviano@iis.ee.ethz.ch>

/// A wrapper around the Serial Link intended to enable single and multi-channel
/// configurations
module serial_link_wrapper #(
  parameter type axi_req_t  = logic,
  parameter type axi_rsp_t  = logic,
  parameter type aw_chan_t  = logic,
  parameter type ar_chan_t  = logic,
  parameter type r_chan_t   = logic,
  parameter type w_chan_t   = logic,
  parameter type b_chan_t   = logic,
  parameter type cfg_req_t  = logic,
  parameter type cfg_rsp_t  = logic,
  parameter int NumChannels = 1,
  parameter int NumLanes = 4,
  parameter bit EnDdr = 1'b1,
  parameter int NumCredits = 8,
  parameter int MaxClkDiv = 32,
  parameter bit UseDelayLine = 1'b0
) (
  input  logic                      clk_i,
  input  logic                      rst_ni,
  input  logic                      clk_sl_i,
  input  logic                      rst_sl_ni,
  input  logic                      clk_reg_i,
  input  logic                      rst_reg_ni,
  input  logic                      testmode_i,
  input  axi_req_t                  axi_in_req_i,
  output axi_rsp_t                  axi_in_rsp_o,
  output axi_req_t                  axi_out_req_o,
  input  axi_rsp_t                  axi_out_rsp_i,
  input  cfg_req_t                  cfg_req_i,
  output cfg_rsp_t                  cfg_rsp_o,
  input  logic [NumChannels-1:0]    ddr_rcv_clk_i,
  output logic [NumChannels-1:0]    ddr_rcv_clk_o,
  input  logic [NumChannels-1:0][NumLanes-1:0] ddr_i,
  output logic [NumChannels-1:0][NumLanes-1:0] ddr_o,
  // AXI isolation signals (in/out), if not used tie to 0
  input  logic [1:0]                isolated_i,
  output logic [1:0]                isolate_o,
  // Clock gate register
  output logic                      clk_ena_o,
  // synch-reset register
  output logic                      reset_no
);

  if (NumChannels > 1) begin : gen_multi_channel_serial_link
    serial_link #(
      .axi_req_t        ( axi_req_t   ),
      .axi_rsp_t        ( axi_rsp_t   ),
      .aw_chan_t        ( aw_chan_t   ),
      .w_chan_t         ( w_chan_t    ),
      .b_chan_t         ( b_chan_t    ),
      .ar_chan_t        ( ar_chan_t   ),
      .r_chan_t         ( r_chan_t    ),
      .cfg_req_t        ( cfg_req_t   ),
      .cfg_rsp_t        ( cfg_rsp_t   ),
      .hw2reg_t         ( serial_link_reg_pkg::serial_link_hw2reg_t ),
      .reg2hw_t         ( serial_link_reg_pkg::serial_link_reg2hw_t ),
      .NumChannels      ( NumChannels ),
      .NumLanes         ( NumLanes    ),
      .EnDdr            ( EnDdr       ),
      .NumCredits       ( NumCredits  ),
      .MaxClkDiv        ( MaxClkDiv   ),
      .UseDelayLine     ( UseDelayLine )
    ) i_serial_link (
      .clk_i,
      .rst_ni,
      .clk_sl_i,
      .rst_sl_ni,
      .clk_reg_i,
      .rst_reg_ni,
      .testmode_i,
      .axi_in_req_i,
      .axi_in_rsp_o,
      .axi_out_req_o,
      .axi_out_rsp_i,
      .cfg_req_i,
      .cfg_rsp_o,
      .ddr_rcv_clk_i,
      .ddr_rcv_clk_o,
      .ddr_i,
      .ddr_o,
      .isolated_i,
      .isolate_o,
      .clk_ena_o,
      .reset_no
    );
  end else begin : gen_single_channel_serial_link
    serial_link #(
      .axi_req_t        ( axi_req_t   ),
      .axi_rsp_t        ( axi_rsp_t   ),
      .aw_chan_t        ( aw_chan_t   ),
      .w_chan_t         ( w_chan_t    ),
      .b_chan_t         ( b_chan_t    ),
      .ar_chan_t        ( ar_chan_t   ),
      .r_chan_t         ( r_chan_t    ),
      .cfg_req_t        ( cfg_req_t   ),
      .cfg_rsp_t        ( cfg_rsp_t   ),
      .hw2reg_t         ( serial_link_single_channel_reg_pkg::serial_link_single_channel_hw2reg_t ),
      .reg2hw_t         ( serial_link_single_channel_reg_pkg::serial_link_single_channel_reg2hw_t ),
      .NumChannels      ( NumChannels ),
      .NumLanes         ( NumLanes    ),
      .EnDdr            ( EnDdr       ),
      .NumCredits       ( NumCredits  ),
      .MaxClkDiv        ( MaxClkDiv   ),
      .UseDelayLine     ( UseDelayLine )
    ) i_serial_link (
      .clk_i,
      .rst_ni,
      .clk_sl_i,
      .rst_sl_ni,
      .clk_reg_i,
      .rst_reg_ni,
      .testmode_i,
      .axi_in_req_i,
      .axi_in_rsp_o,
      .axi_out_req_o,
      .axi_out_rsp_i,
      .cfg_req_i,
      .cfg_rsp_o,
      .ddr_rcv_clk_i,
      .ddr_rcv_clk_o,
      .ddr_i,
      .ddr_o,
      .isolated_i,
      .isolate_o,
      .clk_ena_o,
      .reset_no
    );
  end

endmodule
