// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Alessandro Ottaviano <aottaviano@iis.ee.ethz.ch>


`include "common_cells/registers.svh"
`include "common_cells/assertions.svh"

// Implements a single TX channel which forwards the source-synchronous clock
module serial_link_physical_delay_line_tx #(
  parameter int NumLanes = 8,
  parameter bit EnDdr    = 1'b1,
  parameter type phy_data_t = logic
) (
  input  logic                clk_i,
  input  logic                rst_ni,
  input  logic                clk_delay_i,
  input  phy_data_t           data_out_i,
  input  logic                data_out_valid_i,
  output logic                data_out_ready_o,
  output logic                ddr_rcv_clk_o,
  output logic [NumLanes-1:0] ddr_o
);

  logic [NumLanes*2-1:0]      data_out_q;

  // Valid is always set, but src_clk is clock gated
  assign data_out_ready_o = data_out_valid_i;

  ///////////////////////////////////////
  //   CLOCK DIVIDER + PHASE SHIFTER   //
  ///////////////////////////////////////

  logic clk90, clk270;

  tc_clk_gating #(
    .IS_FUNCTIONAL(1)
  ) i_clk_gate (
    .clk_i,
    .en_i (data_out_valid_i),
    .test_en_i ('0),
    .clk_o (clk_gate_out)
  );

  // Shift by 270deg = 90deg + inverter to sample data in the eye's center
  configurable_delay #(
    .NUM_STEPS (16)
  ) i_delay90 (
    .clk_i (clk_gate_out),
    `ifndef TARGET_ASIC
    .enable_i (1'b1),
    `endif
    .delay_i(clk_delay_i),
    .clk_o (clk90)
  );

  // Inverting clk90 <=> clk270
  tc_clk_inverter i_tc_clk_inverter_clk_270 (
    .clk_i(clk90),
    .clk_o(clk270)
  );

  // assign output clock
  assign ddr_rcv_clk_o = clk270;

  /////////////////
  //   DDR OUT   //
  /////////////////
  `FF(data_out_q, data_out_i, '0, clk_i, rst_ni)

  if (EnDdr) begin : gen_ddr_mode
    for (genvar i = 0; i < NumLanes; i++) begin
      tc_clk_mux2 i_serial_link_physical_tx_tc_clk_mux2 (
        .clk0_i   (data_out_q[NumLanes+i]),
        .clk1_i   (data_out_q[i]),
        .clk_sel_i(clk_i),
        .clk_o    (ddr_o[i])
      );
    end
  end else begin : gen_sdr_mode
    assign ddr_o = data_out_q;
  end

endmodule

// Impelements a single RX channel which samples the data with the received clock
// Synchronizes the data with the System clock with a CDC
module serial_link_physical_delay_line_rx #(
  parameter int NumLanes      = 8,
  parameter int FifoDepth     = 8,
  parameter int CdcSyncStages = 2,
  parameter bit EnDdr         = 1'b1,
  parameter type phy_data_t   = logic
) (
  input  logic                clk_i,
  input  logic                rst_ni,
  input  logic                ddr_rcv_clk_i,
  output phy_data_t           data_in_o,
  output logic                data_in_valid_o,
  input  logic                data_in_ready_i,
  input  logic [NumLanes-1:0] ddr_i
);

  phy_data_t            data_in;
  logic [NumLanes-1:0]  ddr_q;

  ///////////////////////////////
  //   CLOCK DOMAIN CROSSING   //
  ///////////////////////////////

  cdc_fifo_gray #(
    .T            ( phy_data_t                        ),
    .LOG_DEPTH    ( $clog2(FifoDepth) + CdcSyncStages ),
    .SYNC_STAGES  ( CdcSyncStages                     )
  ) i_cdc_in (
    .src_clk_i   ( ddr_rcv_clk_i    ),
    .src_rst_ni  ( rst_ni           ),
    .src_data_i  ( data_in          ),
    .src_valid_i ( 1'b1             ),
    .src_ready_o (                  ),

    .dst_clk_i   ( clk_i            ),
    .dst_rst_ni  ( rst_ni           ),
    .dst_data_o  ( data_in_o        ),
    .dst_valid_o ( data_in_valid_o  ),
    .dst_ready_i ( data_in_ready_i  )
  );

  // TODO: Fix assertion during reset
  // `ASSERT(CdcRxFifoFull, !(i_cdc_in.src_valid_i & ~i_cdc_in.src_ready_o), ddr_rcv_clk_i, !rst_ni)

  ////////////////
  //   DDR IN   //
  ////////////////
  if (EnDdr) begin : gen_ddr_mode
      always_ff @(negedge ddr_rcv_clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
          ddr_q <= 0;
        end else begin
          ddr_q <= ddr_i;
        end
      end
      assign data_in = {ddr_i, ddr_q};
  end else begin : gen_sdr_mode
    assign data_in = ddr_i;
  end

endmodule

// Implements the Physical Layer of the Serial Link
// The number of Channels and Lanes per Channel is parametrizable
module serial_link_physical_delay_line #(
  // Number of Wires in one channel
  parameter int NumLanes   = 8,
  // Fifo Depth of CDC, dependent on
  // Num Credit for Flow control
  parameter int FifoDepth  = 8,
  // Enable DDR mode
  parameter bit EnDdr = 1'b1,
  // Data input type of the PHY
  parameter type phy_data_t = logic
) (
  input  logic                          clk_i,
  input  logic                          rst_ni,
  input  logic                          clk_delay_i,
  input  logic                          ddr_rcv_clk_i,
  output logic                          ddr_rcv_clk_o,
  input  logic [NumLanes*2-1:0]         data_out_i,
  input  logic                          data_out_valid_i,
  output logic                          data_out_ready_o,
  output logic [NumLanes*2-1:0]         data_in_o,
  output logic                          data_in_valid_o,
  input  logic                          data_in_ready_i,
  input  logic [NumLanes-1:0]           ddr_i,
  output logic [NumLanes-1:0]           ddr_o
);

  ////////////////
  //   PHY TX   //
  ////////////////
  serial_link_physical_delay_line_tx #(
    .NumLanes   ( NumLanes   ),
    .EnDdr      ( EnDdr      ),
    .phy_data_t ( phy_data_t )
  ) i_serial_link_physical_tx (
    .rst_ni,
    .clk_i,
    .clk_delay_i,
    .data_out_i,
    .data_out_valid_i,
    .data_out_ready_o,
    .ddr_rcv_clk_o,
    .ddr_o
  );

  ////////////////
  //   PHY RX   //
  ////////////////
  serial_link_physical_delay_line_rx #(
    .NumLanes   ( NumLanes   ),
    .FifoDepth  ( FifoDepth  ),
    .EnDdr      ( EnDdr      ),
    .phy_data_t ( phy_data_t )
  ) i_serial_link_physical_rx (
    .clk_i,
    .rst_ni,
    .ddr_rcv_clk_i,
    .data_in_o,
    .data_in_valid_o,
    .data_in_ready_i,
    .ddr_i
  );

endmodule
