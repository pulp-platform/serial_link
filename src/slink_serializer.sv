// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
//  - Tim Fischer <fischeti@iis.ee.ethz.ch>
//  - Manuel Eggimann <meggimann@iis.ee.ethz.ch>

`include "common_cells/registers.svh"
`include "common_cells/assertions.svh"
`include "axi_stream/typedef.svh"
`include "rdl_assign.svh"

/// Protocol + Data Link + Channel Allocator + config-register front-end of the serial link.
/// Converts AXI4 to a per-channel packet stream (`phy_data_t`) meant to be driven into any
/// physical backend (e.g. `slink_phys_layer`, or a different transport such as UCIe RDI).
module slink_serializer #(
  // Number of credits for flow control
  parameter int NumCredits                     = 8,
  parameter int unsigned NumChannels           = 1,
  parameter int unsigned NumLanes              = 8,
  parameter bit          EnDdr                 = 1'b1,
  parameter int unsigned Log2MaxClkDiv         = 10,
  parameter int unsigned Log2RawModeTXFifoDepth = 3,
  parameter bit          EnChAlloc             = (NumChannels > 1),
  parameter type axi_req_t  = logic,
  parameter type axi_rsp_t  = logic,
  parameter type aw_chan_t  = logic,
  parameter type ar_chan_t  = logic,
  parameter type r_chan_t   = logic,
  parameter type w_chan_t   = logic,
  parameter type b_chan_t   = logic,
  parameter type hwif_in_t  = logic,
  parameter type hwif_out_t = logic,
  // Local shorthand so port declarations below don't need to repeat the expression.
  // (`phy_data_t` itself is a typedef, not usable in the port list, so the raw-bit
  // port width is derived here and re-wrapped into `phy_data_t` inside the body.)
  localparam int unsigned NumBitsPerCycle = NumLanes * (1 + EnDdr),
  localparam int unsigned MaxClkDiv = 2**Log2MaxClkDiv
) (
  // There are 2 different clock/resets relevant to this module:
  // 1) clk_i & rst_ni: "always-on" clock & reset coming from the SoC domain.
  // 2) clk_sl_i & rst_sl_ni: Same as 1) but clock is gated and reset is SW synchronized. This is the clock that drives the serial link
  //    i.e. protocol, data-link and channel allocator all run on this clock and can be clock gated if needed. If no clock gating, reset synchronization
  //    is desired, you can tie clk_sl_i -> clk_i resp. rst_sl_ni -> rst_ni
  input  logic                      clk_i,
  input  logic                      rst_ni,
  input  logic                      clk_sl_i,
  input  logic                      rst_sl_ni,
  input  axi_req_t                  axi_in_req_i,
  output axi_rsp_t                  axi_in_rsp_o,
  output axi_req_t                  axi_out_req_o,
  input  axi_rsp_t                  axi_out_rsp_i,
  input  hwif_out_t                 hwif_out_i,  // was the internal reg2hw
  output hwif_in_t                  hwif_in_o,   // was the internal hw2reg
  // Per-channel packet stream towards/from the physical backend (`phy_data_t` width)
  output logic [NumChannels-1:0][NumBitsPerCycle-1:0] phy_data_out_o,
  output logic [NumChannels-1:0]                      phy_data_out_valid_o,
  input  logic [NumChannels-1:0]                      phy_data_out_ready_i,
  input  logic [NumChannels-1:0][NumBitsPerCycle-1:0] phy_data_in_i,
  input  logic [NumChannels-1:0]                      phy_data_in_valid_i,
  output logic [NumChannels-1:0]                      phy_data_in_ready_o,
  // Per-channel TX clock-divider/phase-shift configuration for a DDR/SDR PHY backend.
  // Unused (and safe to leave unconnected) for backends that don't forward a source-synchronous clock.
  output logic [NumChannels-1:0][$clog2(MaxClkDiv):0] tx_phy_clk_div_o,
  output logic [NumChannels-1:0][$clog2(MaxClkDiv):0] tx_phy_clk_shift_start_o,
  output logic [NumChannels-1:0][$clog2(MaxClkDiv):0] tx_phy_clk_shift_end_o,
  // AXI isolation signals (in/out), if not used tie to 0
  input  logic [1:0]                isolated_i,
  output logic [1:0]                isolate_o,
  // Clock gate register
  output logic                      clk_ena_o,
  // synch-reset register
  output logic                      reset_no
);

  localparam int unsigned RawModeFifoDepth = 2**Log2RawModeTXFifoDepth;
  localparam int unsigned NumRawModeDataWords =
      (NumBitsPerCycle > 32) ? ((NumBitsPerCycle + 31) / 32) : 1;
  localparam int unsigned RawModeDataBits = NumRawModeDataWords * 32;

  typedef logic [$clog2(NumCredits):0] credit_t;
  typedef logic [NumBitsPerCycle-1:0] phy_data_t;
  typedef logic [RawModeDataBits-1:0] raw_mode_words_t;

  // Determine the largest sized AXI channel
  localparam int AxiChannels[5] = {$bits(b_chan_t),
                          $bits(aw_chan_t),
                          $bits(w_chan_t),
                          $bits(ar_chan_t),
                          $bits(r_chan_t)};
  localparam int MaxAxiChannelBits =
  slink_pkg::find_max_channel(AxiChannels);


  // The payload that is converted into an AXI stream consists of
  // 1) AXI Beat
  // 2) B Channel (which is always transmitted)
  // 3) Header
  // 4) Credit for flow control
  typedef struct packed {
    logic [MaxAxiChannelBits-1:0] axi_ch;
    logic b_valid;
    b_chan_t b;
    slink_pkg::tag_e hdr;
    credit_t credit;
  } payload_t;

  localparam int BandWidth = NumChannels * NumBitsPerCycle; // doubled BW if DDR enabled
  localparam int PayloadSplits = ($bits(payload_t) + BandWidth - 1) / BandWidth;
  localparam int RecvFifoDepth = NumCredits * PayloadSplits;

  // Axi stream dimension must be a multiple of 8 bits
  localparam int StreamDataBytes = ($bits(payload_t) + 7) / 8;

  // Typdefs for Axi Stream interface
  // All except tdata_t are unused at the moment
  typedef logic [StreamDataBytes*8-1:0] tdata_t;
  typedef logic [StreamDataBytes-1:0] tstrb_t;
  typedef logic [StreamDataBytes-1:0] tkeep_t;
  typedef logic tid_t;
  typedef logic tdest_t;
  typedef logic tuser_t;
  `AXI_STREAM_TYPEDEF_ALL(axis, tdata_t, tstrb_t, tkeep_t, tid_t, tdest_t, tuser_t)

  axis_req_t  axis_out_req, axis_in_req;
  axis_rsp_t  axis_out_rsp, axis_in_rsp;

  phy_data_t [NumChannels-1:0]  data_link2alloc_data_out;
  logic [NumChannels-1:0]       data_link2alloc_data_out_valid;
  logic                         alloc2data_link_data_out_ready;

  phy_data_t [NumChannels-1:0]  alloc2data_link_data_in;
  logic [NumChannels-1:0]       alloc2data_link_data_in_valid;
  logic [NumChannels-1:0]       data_link2alloc_data_in_ready;


  ////////////////////////
  //   PROTOCOL LAYER   //
  ////////////////////////

  slink_prot_layer #(
    .NumCredits     ( NumCredits    ),
    .axi_req_t      ( axi_req_t     ),
    .axi_rsp_t      ( axi_rsp_t     ),
    .axis_req_t     ( axis_req_t    ),
    .axis_rsp_t     ( axis_rsp_t    ),
    .aw_chan_t      ( aw_chan_t     ),
    .w_chan_t       ( w_chan_t      ),
    .b_chan_t       ( b_chan_t      ),
    .ar_chan_t      ( ar_chan_t     ),
    .r_chan_t       ( r_chan_t      ),
    .payload_t      ( payload_t     ),
    .credit_t       ( credit_t      )
  ) i_serial_link_protocol (
    .clk_i          ( clk_sl_i        ),
    .rst_ni         ( rst_sl_ni       ),
    .axi_in_req_i   ( axi_in_req_i    ),
    .axi_in_rsp_o   ( axi_in_rsp_o    ),
    .axi_out_req_o  ( axi_out_req_o   ),
    .axi_out_rsp_i  ( axi_out_rsp_i   ),
    .axis_in_req_i  ( axis_in_req     ),
    .axis_in_rsp_o  ( axis_in_rsp     ),
    .axis_out_req_o ( axis_out_req    ),
    .axis_out_rsp_i ( axis_out_rsp    )
  );

  /////////////////////////
  //   DATA LINK LAYER   //
  /////////////////////////

  logic cfg_flow_control_fifo_clear;
  logic cfg_raw_mode_out_data_fifo_clear;
  logic raw_mode_out_data_valid;
  logic [NumChannels-1:0] raw_mode_in_data_valid;
  logic [NumChannels-1:0] raw_mode_out_ch_mask;

  assign cfg_flow_control_fifo_clear =
      hwif_out_i.flow_control_fifo_clear.wr_data.flow_control_fifo_clear
    & hwif_out_i.flow_control_fifo_clear.req
    & hwif_out_i.flow_control_fifo_clear.req_is_wr
    & hwif_out_i.flow_control_fifo_clear.wr_biten.flow_control_fifo_clear;
  assign cfg_raw_mode_out_data_fifo_clear =
      hwif_out_i.raw_mode_out_data_fifo_ctrl.wr_data.clear
    & hwif_out_i.raw_mode_out_data_fifo_ctrl.req
    & hwif_out_i.raw_mode_out_data_fifo_ctrl.req_is_wr
    & hwif_out_i.raw_mode_out_data_fifo_ctrl.wr_biten.clear;
  for (genvar i = 0; i < NumChannels; i++) begin : gen_raw_mode_in_data_valid
    assign raw_mode_out_ch_mask[i] =
      hwif_out_i.raw_mode_out_ch_mask[i].raw_mode_out_ch_mask.value;
  end

  phy_data_t raw_mode_in_data_out;
  phy_data_t raw_mode_in_data_shadow_q;
  logic raw_mode_in_data_rd_pending;
  logic raw_mode_in_data_capture;
  raw_mode_words_t raw_mode_in_data_read_words;
  raw_mode_words_t raw_mode_out_data_words;
  logic [cc_pkg::cnt_width(RawModeFifoDepth)-1:0] raw_mode_out_data_fill_state;
  logic raw_mode_out_data_is_full;

  slink_link_layer #(
    .axis_req_t       ( axis_req_t        ),
    .axis_rsp_t       ( axis_rsp_t        ),
    .phy_data_t       ( phy_data_t        ),
    .NumChannels      ( NumChannels       ),
    .NumLanes         ( NumLanes          ),
    .RecvFifoDepth    ( RecvFifoDepth     ),
    .RawModeFifoDepth ( RawModeFifoDepth  ),
    .PayloadSplits    ( PayloadSplits     ),
    .EnDdr            ( EnDdr             )
  ) i_serial_link_data_link (
    .clk_i                                   ( clk_sl_i                                         ),
    .rst_ni                                  ( rst_sl_ni                                        ),
    .axis_in_req_i                           ( axis_out_req                                     ),
    .axis_in_rsp_o                           ( axis_out_rsp                                     ),
    .axis_out_req_o                          ( axis_in_req                                      ),
    .axis_out_rsp_i                          ( axis_in_rsp                                      ),
    .data_out_o                              ( data_link2alloc_data_out                         ),
    .data_out_valid_o                        ( data_link2alloc_data_out_valid                   ),
    .data_out_ready_i                        ( alloc2data_link_data_out_ready                   ),
    .data_in_i                               ( alloc2data_link_data_in                          ),
    .data_in_valid_i                         ( alloc2data_link_data_in_valid                    ),
    .data_in_ready_o                         ( data_link2alloc_data_in_ready                    ),
    .cfg_flow_control_fifo_clear_i           ( cfg_flow_control_fifo_clear                      ),
    .cfg_raw_mode_en_i                       ( hwif_out_i.raw_mode_en.raw_mode_en.value ),
    .cfg_raw_mode_in_ch_sel_i                (
      hwif_out_i.raw_mode_in_ch_sel.raw_mode_in_ch_sel.value[cc_pkg::idx_width(NumChannels)-1:0] ),
    .cfg_raw_mode_in_data_o                  ( raw_mode_in_data_out ),
    .cfg_raw_mode_in_data_valid_o            ( raw_mode_in_data_valid                           ),
    .cfg_raw_mode_in_data_ready_i            ( raw_mode_in_data_rd_pending                      ),
    .cfg_raw_mode_out_ch_mask_i              ( raw_mode_out_ch_mask                             ),
    .cfg_raw_mode_out_data_i                 ( phy_data_t'(raw_mode_out_data_words) ),
    .cfg_raw_mode_out_data_valid_i           ( raw_mode_out_data_valid ),
    .cfg_raw_mode_out_en_i                   (
      hwif_out_i.raw_mode_out_en.raw_mode_out_en.value ),
    .cfg_raw_mode_out_data_fifo_clear_i      ( cfg_raw_mode_out_data_fifo_clear                 ),
    .cfg_raw_mode_out_data_fifo_fill_state_o ( raw_mode_out_data_fill_state ),
    .cfg_raw_mode_out_data_fifo_is_full_o    ( raw_mode_out_data_is_full )
  );

  assign raw_mode_in_data_capture =
      hwif_out_i.raw_mode_in_data[0].req & ~hwif_out_i.raw_mode_in_data[0].req_is_wr;
  assign raw_mode_in_data_rd_pending = raw_mode_in_data_capture;

  always_ff @(posedge clk_sl_i or negedge rst_sl_ni) begin
    if (!rst_sl_ni) begin
      raw_mode_in_data_shadow_q <= '0;
    end else if (raw_mode_in_data_capture) begin
      raw_mode_in_data_shadow_q <= raw_mode_in_data_out;
    end
  end

  // Capture the raw-mode output data into a word array for easier access
  always_comb begin
    raw_mode_out_data_words = '0;
    for (int i = 0; i < NumRawModeDataWords; i++) begin
      raw_mode_out_data_words[i*32 +: 32] =
          hwif_out_i.raw_mode_out_data_fifo[i].raw_mode_out_data_fifo.value;
    end
  end

  always_comb begin
    raw_mode_in_data_read_words = raw_mode_words_t'(raw_mode_in_data_shadow_q);
    if (raw_mode_in_data_capture) begin
      raw_mode_in_data_read_words = raw_mode_words_t'(raw_mode_in_data_out);
    end

    for (int i = 0; i < NumRawModeDataWords; i++) begin
      hwif_in_o.raw_mode_in_data[i].rd_data = '0;
      hwif_in_o.raw_mode_in_data[i].rd_data.raw_mode_in_data =
          raw_mode_in_data_read_words[i*32 +: 32];
      `SLINK_SET_RDL_RD_ACK(raw_mode_in_data[i], hwif_in_o, hwif_out_i)
    end
  end

  always_comb begin
    hwif_in_o.raw_mode_out_data_fifo_ctrl.rd_data = '0;
    hwif_in_o.raw_mode_out_data_fifo_ctrl.rd_data.fill_state = raw_mode_out_data_fill_state;
    hwif_in_o.raw_mode_out_data_fifo_ctrl.rd_data.is_full = raw_mode_out_data_is_full;
    for (int i = 0; i < NumChannels; i++) begin
      hwif_in_o.raw_mode_in_data_valid[i].rd_data = '0;
      hwif_in_o.raw_mode_in_data_valid[i].rd_data.raw_mode_in_data_valid =
          raw_mode_in_data_valid[i];
      `SLINK_SET_RDL_RD_ACK(raw_mode_in_data_valid[i], hwif_in_o, hwif_out_i)
    end
  end

  `SLINK_ASSIGN_RDL_RD_ACK(raw_mode_out_data_fifo_ctrl, hwif_in_o, hwif_out_i)
  `SLINK_ASSIGN_RDL_WR_ACK(raw_mode_out_data_fifo_ctrl, hwif_in_o, hwif_out_i)
  `SLINK_ASSIGN_RDL_WR_ACK(flow_control_fifo_clear, hwif_in_o, hwif_out_i)

  `FF(raw_mode_out_data_valid,
      hwif_out_i.raw_mode_out_data_fifo[NumRawModeDataWords-1].raw_mode_out_data_fifo.swmod, '0)

  ///////////////////////
  // CHANNEL ALLOCATOR //
  ///////////////////////

  if (!EnChAlloc) begin : gen_no_channel_alloc
    // Don't instantiate the channel allocator for the single channel serial
    // link variant. We just feedthrough all the connections

    assign phy_data_out_o = data_link2alloc_data_out;
    assign phy_data_out_valid_o = data_link2alloc_data_out_valid;
    assign alloc2data_link_data_out_ready = phy_data_out_ready_i;

    assign alloc2data_link_data_in = phy_data_in_i;
    assign alloc2data_link_data_in_valid = phy_data_in_valid_i;
    assign phy_data_in_ready_o = data_link2alloc_data_in_ready;

  end else begin : gen_channel_alloc

    logic cfg_tx_clear, cfg_rx_clear;
    logic cfg_tx_flush_trigger;
    logic [NumChannels-1:0] cfg_tx_channel_en, cfg_rx_channel_en;

    assign cfg_tx_clear = hwif_out_i.channel_alloc_tx_ctrl.wr_data.clear
      & hwif_out_i.channel_alloc_tx_ctrl.req
      & hwif_out_i.channel_alloc_tx_ctrl.req_is_wr
      & hwif_out_i.channel_alloc_tx_ctrl.wr_biten.clear;
    assign cfg_rx_clear = hwif_out_i.channel_alloc_rx_ctrl.wr_data.clear
      & hwif_out_i.channel_alloc_rx_ctrl.req
      & hwif_out_i.channel_alloc_rx_ctrl.req_is_wr
      & hwif_out_i.channel_alloc_rx_ctrl.wr_biten.clear;
    assign cfg_tx_flush_trigger = hwif_out_i.channel_alloc_tx_ctrl.wr_data.flush
      & hwif_out_i.channel_alloc_tx_ctrl.req
      & hwif_out_i.channel_alloc_tx_ctrl.req_is_wr
      & hwif_out_i.channel_alloc_tx_ctrl.wr_biten.flush;
    for (genvar i = 0; i < NumChannels; i++) begin : gen_channel_en
      assign cfg_tx_channel_en[i] =
        hwif_out_i.channel_alloc_tx_ch_en[i].channel_alloc_tx_ch_en.value;
      assign cfg_rx_channel_en[i] =
        hwif_out_i.channel_alloc_rx_ch_en[i].channel_alloc_rx_ch_en.value;
    end

    slink_ch_alloc #(
      .phy_data_t  ( phy_data_t    ),
      .NumChannels ( NumChannels   )
    ) i_channel_allocator(
      .clk_i                     ( clk_sl_i                                       ),
      .rst_ni                    ( rst_sl_ni                                      ),
      .cfg_tx_clear_i            ( cfg_tx_clear                                   ),
      .cfg_tx_channel_en_i       ( cfg_tx_channel_en                              ),
      .cfg_tx_bypass_en_i        ( hwif_out_i.channel_alloc_tx_cfg.bypass_en.value ),
      .cfg_tx_auto_flush_en_i    ( hwif_out_i.channel_alloc_tx_cfg.auto_flush_en.value ),
      .cfg_tx_auto_flush_count_i ( hwif_out_i.channel_alloc_tx_cfg.auto_flush_count.value ),
      .cfg_tx_flush_trigger_i    ( cfg_tx_flush_trigger                           ),
      .cfg_rx_clear_i            ( cfg_rx_clear                                   ),
      .cfg_rx_bypass_en_i        ( hwif_out_i.channel_alloc_rx_cfg.bypass_en.value ),
      .cfg_rx_channel_en_i       ( cfg_rx_channel_en                              ),
      .cfg_rx_auto_flush_en_i    ( hwif_out_i.channel_alloc_rx_cfg.auto_flush_en.value ),
      .cfg_rx_auto_flush_count_i ( hwif_out_i.channel_alloc_rx_cfg.auto_flush_count.value ),
      .cfg_rx_sync_en_i          ( hwif_out_i.channel_alloc_rx_cfg.sync_en.value ),
      // From Data Link Layer
      .data_out_i                ( data_link2alloc_data_out                       ),
      .data_out_valid_i          ( data_link2alloc_data_out_valid                 ),
      .data_out_ready_o          ( alloc2data_link_data_out_ready                 ),
      // To Phy
      .data_out_o                ( phy_data_out_o                                 ),
      .data_out_valid_o          ( phy_data_out_valid_o                           ),
      .data_out_ready_i          ( phy_data_out_ready_i                           ),
      // From Phy
      .data_in_i                 ( phy_data_in_i                                  ),
      .data_in_valid_i           ( phy_data_in_valid_i                            ),
      .data_in_ready_o           ( phy_data_in_ready_o                            ),
      // To Data Link Layer
      .data_in_o                 ( alloc2data_link_data_in                        ),
      .data_in_valid_o           ( alloc2data_link_data_in_valid                  ),
      .data_in_ready_i           ( data_link2alloc_data_in_ready                  )
    );
  end


  ///////////////////////////////////////////
  //   TX PHY CLOCK CONFIG (for PHY use)   //
  ///////////////////////////////////////////

  for (genvar i = 0; i < NumChannels; i++) begin : gen_tx_phy_clk_cfg
    assign tx_phy_clk_div_o[i]         = hwif_out_i.tx_phy_clk_div[i].clk_divs.value;
    assign tx_phy_clk_shift_start_o[i] = hwif_out_i.tx_phy_clk_start[i].clk_divs.value;
    assign tx_phy_clk_shift_end_o[i]   = hwif_out_i.tx_phy_clk_end[i].clk_shift_end.value;
  end

  assign clk_ena_o = hwif_out_i.ctrl.clk_ena.value;
  assign reset_no = hwif_out_i.ctrl.reset_n.value;
  assign isolate_o = {hwif_out_i.ctrl.axi_out_isolate.value,
                      hwif_out_i.ctrl.axi_in_isolate.value};

  always_comb begin
    hwif_in_o.isolated.rd_data  = '0;
    hwif_in_o.isolated.rd_data.axi_in = isolated_i[0];
    hwif_in_o.isolated.rd_data.axi_out = isolated_i[1];
  end

  `SLINK_ASSIGN_RDL_RD_ACK(isolated, hwif_in_o, hwif_out_i)

  if (EnChAlloc) begin : gen_channel_alloc_regs
    `SLINK_ASSIGN_RDL_WR_ACK(channel_alloc_tx_ctrl, hwif_in_o, hwif_out_i)
    `SLINK_ASSIGN_RDL_WR_ACK(channel_alloc_rx_ctrl, hwif_in_o, hwif_out_i)
  end else begin : gen_no_channel_alloc_regs
    assign hwif_in_o.channel_alloc_tx_ctrl = '{default: '0};
    assign hwif_in_o.channel_alloc_rx_ctrl = '{default: '0};
  end

  ////////////////////
  //   ASSERTIONS   //
  ////////////////////

  `ASSERT_INIT(RawModeFifoDim, RecvFifoDepth >= RawModeFifoDepth)

endmodule : slink_serializer
