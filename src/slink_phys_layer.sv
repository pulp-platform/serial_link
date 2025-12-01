// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>
// Contributor: Chandra de Viragh <devirac@ethz.ch>


`include "common_cells/registers.svh"
`include "common_cells/assertions.svh"

// Implements a single TX channel which forwards the source-synchronous clock
module slink_phys_layer #(
  parameter int NumLanes   = 8,
  parameter int MaxClkDiv  = 32,
  parameter bit EnDdr = 1'b1,
  parameter type phy_data_t = logic,
  parameter type clk_div_t = logic [$clog2(MaxClkDiv):0]
) (
  input  logic                clk_i,
  input  logic                rst_ni,
  input  clk_div_t            clk_div_i,
  input  clk_div_t            clk_shift_start_i,
  input  clk_div_t            clk_shift_end_i,
  input  phy_data_t           data_out_i,
  input  logic                data_out_valid_i,
  output logic                data_out_ready_o,
  output logic                ddr_rcv_clk_o,
  output logic [NumLanes-1:0] ddr_o
);
  phy_data_t  data_out_q;

  clk_div_t clk_cnt_q, clk_cnt_d;
  logic clk_enable;
  logic clk_toggle, clk_slow_toggle;
  logic clk_slow;
  logic ddr_sel;

  // Valid is always set, but
  // src_clk is clock gated
  assign data_out_ready_o = data_out_valid_i & (clk_cnt_q == clk_div_i - 1);

  ///////////////////////////////////////
  //   CLOCK DIVIDER + PHASE SHIFTER   //
  ///////////////////////////////////////

  always_comb begin

    clk_cnt_d = 0;

    if (data_out_valid_i) begin
      clk_cnt_d = (clk_cnt_q == clk_div_i - 1)? '0 : clk_cnt_q + 1;
    end

    clk_enable = data_out_valid_i;
    clk_toggle = (clk_cnt_q == clk_shift_start_i) | (clk_cnt_q == clk_shift_end_i);
    clk_slow_toggle = (clk_cnt_q == 0) | (clk_cnt_q == clk_div_i/2);
  end

  `FF(clk_cnt_q, clk_cnt_d, '0)

  // The ddr_rcv_clk_o T-Flip-Flop intentionally uses blocking assignments! If we were to use
  // non-blocking assignment like we normally do for flip-flops, we would create
  // a race condition when sampling data from the fast clock domain into
  // flip-flops clocked by ddr_rcv_clk_o. To avoid this, we use blocking assignments
  // which is the reccomended method acording to:
  // S. Sutherland and D. Mills,
  // Verilog and System Verilog gotchas: 101 common coding errors and how to
  // avoid them. New York: Springer, 2007. page 64.

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (~rst_ni) begin
      ddr_rcv_clk_o = 1'b1;
      clk_slow <= 1'b0;
      ddr_sel <= 1'b0;
    end else begin
      if (clk_enable) begin
        if (clk_toggle) begin
          ddr_rcv_clk_o = !ddr_rcv_clk_o;
        end
        if (clk_slow_toggle) begin
          clk_slow <= !clk_slow;
          ddr_sel <= !ddr_sel;
        end
      end else begin
        ddr_rcv_clk_o = 1'b1;
        clk_slow <= 1'b0;
        ddr_sel <= 1'b0;
      end
    end
  end

  /////////////////
  //   DDR OUT   //
  /////////////////
  `FF(data_out_q, data_out_i, '0, clk_slow, rst_ni)

  if (EnDdr) begin : gen_ddr_mode
    assign ddr_o = (ddr_sel)? data_out_q[NumLanes-1:0] : data_out_q[NumLanes*2-1:NumLanes];
  end else begin : gen_sdr_mode
    assign ddr_o = data_out_q;
  end

endmodule

// Impelements a single RX channel which samples the data with the received clock
// Synchronizes the data with the System clock with a CDC
module serial_link_physical_rx #(
  parameter int NumLanes      = 8,
  parameter int FifoDepth     = 8,
  parameter int CdcSyncStages = 2,
  parameter bit EnDdr         = 1'b1,
  parameter type phy_data_t   = logic
) (
  input  logic                  clk_i,
  input  logic                  rst_ni,
  input  logic                  ddr_rcv_clk_i,
  output phy_data_t             data_in_o,
  output logic                  data_in_valid_o,
  input  logic                  data_in_ready_i,
  input  logic [NumLanes-1:0]   ddr_i
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
module serial_link_physical #(
  // Number of Wires in one channel
  parameter int NumLanes   = 8,
  // Fifo Depth of CDC, dependent on
  // Num Credit for Flow control
  parameter int FifoDepth  = 8,
  // Maximum factor of ClkDiv
  parameter int MaxClkDiv  = 32,
  // Enable DDR mode
  parameter bit EnDdr = 1'b1,
  // Data input type of the PHY
  parameter type phy_data_t = logic,
  // Clock division type
  parameter type clk_div_t = logic [$clog2(MaxClkDiv):0]
) (
  input  logic                clk_i,
  input  logic                rst_ni,
  input  clk_div_t            clk_div_i,
  input  clk_div_t            clk_shift_start_i,
  input  clk_div_t            clk_shift_end_i,
  input  logic                ddr_rcv_clk_i,
  output logic                ddr_rcv_clk_o,
  input  phy_data_t           data_out_i,
  input  logic                data_out_valid_i,
  output logic                data_out_ready_o,
  output phy_data_t           data_in_o,
  output logic                data_in_valid_o,
  input  logic                data_in_ready_i,
  input  logic [NumLanes-1:0] ddr_i,
  output logic [NumLanes-1:0] ddr_o
);

  ////////////////
  //   PHY TX   //
  ////////////////
  slink_phys_layer #(
    .NumLanes   ( NumLanes    ),
    .EnDdr      ( EnDdr       ),
    .phy_data_t ( phy_data_t  ),
    .clk_div_t  ( clk_div_t   )
  ) i_serial_link_physical_tx (
    .rst_ni,
    .clk_i,
    .clk_div_i,
    .clk_shift_start_i,
    .clk_shift_end_i,
    .data_out_i,
    .data_out_valid_i,
    .data_out_ready_o,
    .ddr_rcv_clk_o,
    .ddr_o
  );

  ////////////////
  //   PHY RX   //
  ////////////////
  serial_link_physical_rx #(
    .NumLanes   ( NumLanes    ),
    .FifoDepth  ( FifoDepth   ),
    .EnDdr      ( EnDdr       ),
    .phy_data_t ( phy_data_t  )
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
