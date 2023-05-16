// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>
// Modified: Yannick Baumann <baumanny@student.ethz.ch>
// Currently the module is not functional. It is a copy only to be used as a template...!!!

// TODO: This is only a template. I still need to change it to the noc interface...
module floo_serial_link_occamy_wrapper #(
  parameter type req_flit_t   = logic,
  parameter type rsp_flit_t   = logic,
  parameter type cfg_req_t    = logic,
  parameter type cfg_rsp_t    = logic,
  parameter int NumChannels   = 1,
  parameter int NumLanes      = 4,
  parameter int MaxClkDiv     = 32,
  parameter bit printFeedback = 1'b0
) (
  input  logic                      clk_i,
  input  logic                      rst_ni,
  input  logic                      clk_reg_i,
  input  logic                      rst_reg_ni,
  input  logic                      testmode_i,
  input  req_flit_t                 req_i,
  input  rsp_flit_t                 rsp_i,
  output req_flit_t                 req_o,
  output rsp_flit_t                 rsp_o,
  input  cfg_req_t                  cfg_req_i,
  output cfg_rsp_t                  cfg_rsp_o,
  input  logic [NumChannels-1:0]    ddr_rcv_clk_i,
  output logic [NumChannels-1:0]    ddr_rcv_clk_o,
  input  logic [NumChannels-1:0][NumLanes-1:0] ddr_i,
  output logic [NumChannels-1:0][NumLanes-1:0] ddr_o  
);

  logic clk_serial_link;
  logic rst_serial_link_n;

  logic clk_ena;
  logic reset_n;

  // Quadrant clock gate controlled by register
  tc_clk_gating i_tc_clk_gating (
    .clk_i,
    .en_i (clk_ena),
    .test_en_i (testmode_i),
    .clk_o (clk_serial_link)
  );

  // Reset directly from register (i.e. (de)assertion inherently synchronized)
  // Multiplex with glitchless multiplexor, top reset for testing purposes
  tc_clk_mux2 i_tc_reset_mux (
    .clk0_i (reset_n),
    .clk1_i (rst_ni),
    .clk_sel_i (testmode_i),
    .clk_o (rst_serial_link_n)
  );

  logic [1:0] isolated, isolate;

  if (NumChannels > 1) begin : gen_multi_channel_serial_link
    floo_serial_link #(
      .req_flit_t       ( req_flit_t    ),
      .rsp_flit_t       ( rsp_flit_t    ),
      .cfg_req_t        ( cfg_req_t     ),
      .cfg_rsp_t        ( cfg_rsp_t     ),
      .hw2reg_t         ( serial_link_reg_pkg::serial_link_hw2reg_t ),
      .reg2hw_t         ( serial_link_reg_pkg::serial_link_reg2hw_t ),
      .NumChannels      ( NumChannels   ),
      .NumLanes         ( NumLanes      ),
      .MaxClkDiv        ( MaxClkDiv     ),
      .printFeedback    ( printFeedback )
    ) i_serial_link (
      .clk_i          ( clk_i             ),
      .rst_ni         ( rst_ni            ),
      .clk_sl_i       ( clk_serial_link   ),
      .rst_sl_ni      ( rst_serial_link_n ),
      .clk_reg_i      ( clk_reg_i         ),
      .rst_reg_ni     ( rst_reg_ni        ),
      .testmode_i     ( 1'b0              ),
      .req_i          ( req_i             ),
      .rsp_i          ( rsp_i             ),
      .req_o          ( req_o             ),
      .rsp_o          ( rsp_o             ),
      .cfg_req_i      ( cfg_req_i         ),
      .cfg_rsp_o      ( cfg_rsp_o         ),
      .ddr_rcv_clk_i  ( ddr_rcv_clk_i     ),
      .ddr_rcv_clk_o  ( ddr_rcv_clk_o     ),
      .ddr_i          ( ddr_i             ),
      .ddr_o          ( ddr_o             ),
      .isolated_i     ( isolated          ),
      .isolate_o      ( isolate           ),
      .clk_ena_o      ( clk_ena           ),
      .reset_no       ( reset_n           )
    );
  end else begin : gen_single_channel_serial_link
    floo_serial_link #(
      .req_flit_t       ( req_flit_t    ),
      .rsp_flit_t       ( rsp_flit_t    ),
      .cfg_req_t        ( cfg_req_t     ),
      .cfg_rsp_t        ( cfg_rsp_t     ),
      .hw2reg_t         ( serial_link_single_channel_reg_pkg::serial_link_single_channel_hw2reg_t ),
      .reg2hw_t         ( serial_link_single_channel_reg_pkg::serial_link_single_channel_reg2hw_t ),
      .NumChannels      ( NumChannels   ),
      .NumLanes         ( NumLanes      ),
      .MaxClkDiv        ( MaxClkDiv     ),
      .printFeedback    ( printFeedback )
    ) i_serial_link (
      .clk_i          ( clk_i             ),
      .rst_ni         ( rst_ni            ),
      .clk_sl_i       ( clk_serial_link   ),
      .rst_sl_ni      ( rst_serial_link_n ),
      .clk_reg_i      ( clk_reg_i         ),
      .rst_reg_ni     ( rst_reg_ni        ),
      .testmode_i     ( 1'b0              ),
      .req_i          ( req_i             ),
      .rsp_i          ( rsp_i             ),
      .req_o          ( req_o             ),
      .rsp_o          ( rsp_o             ),
      .cfg_req_i      ( cfg_req_i         ),
      .cfg_rsp_o      ( cfg_rsp_o         ),
      .ddr_rcv_clk_i  ( ddr_rcv_clk_i     ),
      .ddr_rcv_clk_o  ( ddr_rcv_clk_o     ),
      .ddr_i          ( ddr_i             ),
      .ddr_o          ( ddr_o             ),
      .isolated_i     ( isolated          ),
      .isolate_o      ( isolate           ),
      .clk_ena_o      ( clk_ena           ),
      .reset_no       ( reset_n           )
    );
  end

endmodule
