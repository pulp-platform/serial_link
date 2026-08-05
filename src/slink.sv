// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
//  - Tim Fischer <fischeti@iis.ee.ethz.ch>
//  - Manuel Eggimann <meggimann@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

/// A simple serial link to go off-chip.
module slink
  import slink_reg_pkg::*;
#(
  // Number of credits for flow control
  parameter int NumCredits        = 8,
  // Whether to use a register CDC for the configuration registers
  parameter bit NoRegCdc          = 1'b0,
  parameter type axi_req_t  = logic,
  parameter type axi_rsp_t  = logic,
  parameter type aw_chan_t  = logic,
  parameter type ar_chan_t  = logic,
  parameter type r_chan_t   = logic,
  parameter type w_chan_t   = logic,
  parameter type b_chan_t   = logic,
  parameter type apb_req_t  = logic,
  parameter type apb_rsp_t  = logic,
  parameter type apb_addr_t = logic[31:0],
  parameter type apb_data_t = logic[31:0],
  parameter type apb_strb_t = logic[3:0]
) (
  // There are 3 different clock/resets:
  // 1) clk_i & rst_ni: "always-on" clock & reset coming from the SoC domain. Only config registers are conected to this clock
  // 2) clk_sl_i & rst_sl_ni: Same as 1) but clock is gated and reset is SW synchronized. This is the clock that drives the serial link
  //    i.e. protocol, data-link and physical layer all run on this clock and can be clock gated if needed. If no clock gating, reset synchronization
  //    is desired, you can tie clk_sl_i -> clk_i resp. rst_sl_ni -> rst_ni
  // 3) clk_reg_i & rst_reg_ni: peripheral clock and reset. Only connected to RegBus CDC. If NoRegCdc is set, this clock must be the same as 1)
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
  input  apb_req_t                  apb_req_i,
  output apb_rsp_t                  apb_rsp_o,
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

  localparam int unsigned NumBitsPerCycle = NumLanes * (1 + EnDdr);
  localparam int unsigned RawModeFifoDepth = 2**Log2RawModeTXFifoDepth;
  localparam int unsigned MaxClkDiv = 2**Log2MaxClkDiv;

  typedef logic [NumBitsPerCycle-1:0] phy_data_t;
  typedef logic [$clog2(MaxClkDiv):0] clk_div_t;

  phy_data_t [NumChannels-1:0]  serializer2phy_data_out;
  logic      [NumChannels-1:0]  serializer2phy_data_out_valid;
  logic      [NumChannels-1:0]  phy2serializer_data_out_ready;

  phy_data_t [NumChannels-1:0]  phy2serializer_data_in;
  logic      [NumChannels-1:0]  phy2serializer_data_in_valid;
  logic      [NumChannels-1:0]  serializer2phy_data_in_ready;

  clk_div_t [NumChannels-1:0]   tx_phy_clk_div;
  clk_div_t [NumChannels-1:0]   tx_phy_clk_shift_start;
  clk_div_t [NumChannels-1:0]   tx_phy_clk_shift_end;

  ////////////////////////////
  //   SERIALIZER (FRONT-END) //
  ////////////////////////////

  slink_serializer #(
    .NumCredits     ( NumCredits    ),
    .NoRegCdc       ( NoRegCdc      ),
    .axi_req_t      ( axi_req_t     ),
    .axi_rsp_t      ( axi_rsp_t     ),
    .aw_chan_t      ( aw_chan_t     ),
    .ar_chan_t      ( ar_chan_t     ),
    .r_chan_t       ( r_chan_t      ),
    .w_chan_t       ( w_chan_t      ),
    .b_chan_t       ( b_chan_t      ),
    .apb_req_t      ( apb_req_t     ),
    .apb_rsp_t      ( apb_rsp_t     ),
    .apb_addr_t     ( apb_addr_t    ),
    .apb_data_t     ( apb_data_t    ),
    .apb_strb_t     ( apb_strb_t    )
  ) i_slink_serializer (
    .clk_i                    ( clk_i                          ),
    .rst_ni                   ( rst_ni                         ),
    .clk_sl_i                 ( clk_sl_i                       ),
    .rst_sl_ni                ( rst_sl_ni                      ),
    .clk_reg_i                ( clk_reg_i                      ),
    .rst_reg_ni               ( rst_reg_ni                     ),
    .axi_in_req_i             ( axi_in_req_i                   ),
    .axi_in_rsp_o             ( axi_in_rsp_o                   ),
    .axi_out_req_o            ( axi_out_req_o                  ),
    .axi_out_rsp_i            ( axi_out_rsp_i                  ),
    .apb_req_i                ( apb_req_i                      ),
    .apb_rsp_o                ( apb_rsp_o                      ),
    .phy_data_out_o           ( serializer2phy_data_out         ),
    .phy_data_out_valid_o     ( serializer2phy_data_out_valid   ),
    .phy_data_out_ready_i     ( phy2serializer_data_out_ready   ),
    .phy_data_in_i            ( phy2serializer_data_in          ),
    .phy_data_in_valid_i      ( phy2serializer_data_in_valid    ),
    .phy_data_in_ready_o      ( serializer2phy_data_in_ready    ),
    .tx_phy_clk_div_o         ( tx_phy_clk_div                  ),
    .tx_phy_clk_shift_start_o ( tx_phy_clk_shift_start          ),
    .tx_phy_clk_shift_end_o   ( tx_phy_clk_shift_end            ),
    .isolated_i               ( isolated_i                     ),
    .isolate_o                ( isolate_o                      ),
    .clk_ena_o                ( clk_ena_o                      ),
    .reset_no                 ( reset_no                       )
  );

  ////////////////////////
  //   PHYSICAL LAYER   //
  ////////////////////////

  for (genvar i = 0; i < NumChannels; i++) begin : gen_phy_channels
    slink_phys_layer #(
      .NumLanes         ( NumLanes          ),
      .FifoDepth        ( RawModeFifoDepth  ),
      .MaxClkDiv        ( MaxClkDiv         ),
      .EnDdr            ( EnDdr             ),
      .phy_data_t       ( phy_data_t        )
    ) i_slink_phys_layer (
      .clk_i             ( clk_sl_i                         ),
      .rst_ni            ( rst_sl_ni                        ),
      .clk_div_i         ( tx_phy_clk_div[i]                ),
      .clk_shift_start_i ( tx_phy_clk_shift_start[i]         ),
      .clk_shift_end_i   ( tx_phy_clk_shift_end[i]           ),
      .ddr_rcv_clk_i     ( ddr_rcv_clk_i[i]                 ),
      .ddr_rcv_clk_o     ( ddr_rcv_clk_o[i]                 ),
      .data_out_i        ( serializer2phy_data_out[i]        ),
      .data_out_valid_i  ( serializer2phy_data_out_valid[i]  ),
      .data_out_ready_o  ( phy2serializer_data_out_ready[i]  ),
      .data_in_o         ( phy2serializer_data_in[i]         ),
      .data_in_valid_o   ( phy2serializer_data_in_valid[i]   ),
      .data_in_ready_i   ( serializer2phy_data_in_ready[i]   ),
      .ddr_i             ( ddr_i[i]                         ),
      .ddr_o             ( ddr_o[i]                         )
    );
  end

endmodule : slink
