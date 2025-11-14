// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
//  - Tim Fischer <fischeti@iis.ee.ethz.ch>
//  - Manuel Eggimann <meggimann@iis.ee.ethz.ch>

`include "common_cells/registers.svh"
`include "common_cells/assertions.svh"
`include "axis/typedef.svh"

/// A simple serial link to go off-chip
module serial_link #(
  // The number of physical chnannels
  parameter int NumChannels       = 1,
  // The number of lanes per channel
  parameter int NumLanes          = 8,
  // Whether to enable DDR mode
  parameter bit EnDdr             = 1'b1,
  // Number of credits for flow control
  parameter int NumCredits        = 8,
  // The maximum clock division factor
  parameter int MaxClkDiv         = 1024,
  // Whether to use a register CDC for the configuration registers
  parameter bit NoRegCdc          = 1'b0,
  // The depth of the raw mode FIFO
  parameter int RawModeFifoDepth  = 8,
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
  parameter type apb_strb_t = logic[3:0],
  parameter type hw2reg_t   = logic,
  parameter type reg2hw_t   = logic
) (
  // There are 3 different clock/resets:
  // 1) clk_i & rst_ni: "always-on" clock & reset coming from the SoC domain. Only config registers are conected to this clock
  // 2) clk_sl_i & rst_sl_ni: Same as 1) but clock is gated and reset is SW synchronized. This is the clock that drives the serial link
  //    i.e. network, data-link and physical layer all run on this clock and can be clock gated if needed. If no clock gating, reset synchronization
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

  typedef logic [$clog2(NumCredits):0] credit_t;
  typedef logic [NumBitsPerCycle-1:0] phy_data_t;

  // Determine the largest sized AXI channel
  localparam int AxiChannels[5] = {$bits(b_chan_t),
                          $bits(aw_chan_t),
                          $bits(w_chan_t),
                          $bits(ar_chan_t),
                          $bits(r_chan_t)};
  localparam int MaxAxiChannelBits =
  serial_link_pkg::find_max_channel(AxiChannels);

  // The payload that is converted into an AXI stream consists of
  // 1) AXI Beat
  // 2) B Channel (which is always transmitted)
  // 3) Header
  // 4) Credit for flow control
  typedef struct packed {
    logic [MaxAxiChannelBits-1:0] axi_ch;
    logic b_valid;
    b_chan_t b;
    serial_link_pkg::tag_e hdr;
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
  typedef logic tlast_t;
  typedef logic tid_t;
  typedef logic tdest_t;
  typedef logic tuser_t;
  typedef logic tready_t;
  `AXIS_TYPEDEF_ALL(axis, tdata_t, tstrb_t, tkeep_t, tlast_t, tid_t, tdest_t, tuser_t, tready_t)

  apb_req_t apb_req;
  apb_rsp_t apb_rsp;

  axis_req_t  axis_out_req, axis_in_req;
  axis_rsp_t  axis_out_rsp, axis_in_rsp;

  reg2hw_t reg2hw;
  hw2reg_t hw2reg;

  phy_data_t [NumChannels-1:0]  data_link2alloc_data_out;
  logic [NumChannels-1:0]       data_link2alloc_data_out_valid;
  logic                         alloc2data_link_data_out_ready;

  phy_data_t [NumChannels-1:0]  alloc2data_link_data_in;
  logic [NumChannels-1:0]       alloc2data_link_data_in_valid;
  logic [NumChannels-1:0]       data_link2alloc_data_in_ready;

  phy_data_t [NumChannels-1:0]  alloc2phy_data_out;
  logic [NumChannels-1:0]       alloc2phy_data_out_valid;
  logic [NumChannels-1:0]       phy2alloc_data_out_ready;

  phy_data_t [NumChannels-1:0]  phy2alloc_data_in;
  logic [NumChannels-1:0]       phy2alloc_data_in_valid;
  logic [NumChannels-1:0]       alloc2phy_data_in_ready;


  ///////////////////////
  //   NETWORK LAYER   //
  ///////////////////////

  serial_link_network #(
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
    .NumCredits     ( NumCredits    )
  ) i_serial_link_network (
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
      reg2hw.serial_link.FLOW_CONTROL_FIFO_CLEAR.wr_data.flow_control_fifo_clear
    & reg2hw.serial_link.FLOW_CONTROL_FIFO_CLEAR.req
    & reg2hw.serial_link.FLOW_CONTROL_FIFO_CLEAR.req_is_wr
    & reg2hw.serial_link.FLOW_CONTROL_FIFO_CLEAR.wr_biten.flow_control_fifo_clear;
  assign cfg_raw_mode_out_data_fifo_clear =
      reg2hw.serial_link.RAW_MODE_OUT_DATA_FIFO_CTRL.wr_data.clear
    & reg2hw.serial_link.RAW_MODE_OUT_DATA_FIFO_CTRL.req
    & reg2hw.serial_link.RAW_MODE_OUT_DATA_FIFO_CTRL.req_is_wr
    & reg2hw.serial_link.RAW_MODE_OUT_DATA_FIFO_CTRL.wr_biten.clear;
  for (genvar i = 0; i < NumChannels; i++) begin : gen_raw_mode_in_data_valid
    assign hw2reg.serial_link.RAW_MODE_IN_DATA_VALID[i].rd_data.raw_mode_in_data_valid =
      raw_mode_in_data_valid[i];
    assign raw_mode_out_ch_mask[i] =
      reg2hw.serial_link.RAW_MODE_OUT_CH_MASK[i].raw_mode_out_ch_mask.value;
  end

  serial_link_data_link #(
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
    .cfg_raw_mode_en_i                       ( reg2hw.serial_link.RAW_MODE_EN.raw_mode_en.value ),
    .cfg_raw_mode_in_ch_sel_i                (
      reg2hw.serial_link.RAW_MODE_IN_CH_SEL.raw_mode_in_ch_sel.value ),
    .cfg_raw_mode_in_data_o                  (
      hw2reg.serial_link.RAW_MODE_IN_DATA.rd_data.raw_mode_in_data ),
    .cfg_raw_mode_in_data_valid_o            ( raw_mode_in_data_valid                           ),
    .cfg_raw_mode_in_data_ready_i            (
      reg2hw.serial_link.RAW_MODE_IN_DATA.req & ~reg2hw.serial_link.RAW_MODE_IN_DATA.req_is_wr ),
    .cfg_raw_mode_out_ch_mask_i              ( raw_mode_out_ch_mask                             ),
    .cfg_raw_mode_out_data_i                 (
      phy_data_t'(reg2hw.serial_link.RAW_MODE_OUT_DATA_FIFO.raw_mode_out_data_fifo.value) ),
    .cfg_raw_mode_out_data_valid_i           ( raw_mode_out_data_valid ),
    .cfg_raw_mode_out_en_i                   (
      reg2hw.serial_link.RAW_MODE_OUT_EN.raw_mode_out_en.value ),
    .cfg_raw_mode_out_data_fifo_clear_i      ( cfg_raw_mode_out_data_fifo_clear                 ),
    .cfg_raw_mode_out_data_fifo_fill_state_o (
      hw2reg.serial_link.RAW_MODE_OUT_DATA_FIFO_CTRL.rd_data.fill_state ),
    .cfg_raw_mode_out_data_fifo_is_full_o    (
      hw2reg.serial_link.RAW_MODE_OUT_DATA_FIFO_CTRL.rd_data.is_full )
  );

  `FF(raw_mode_out_data_valid, reg2hw.serial_link.RAW_MODE_OUT_DATA_FIFO.raw_mode_out_data_fifo.swmod, '0)

  ///////////////////////
  // CHANNEL ALLOCATOR //
  ///////////////////////

  if (NumChannels == 1) begin : gen_no_channel_alloc
    // Don't instantiate the channel allocator for the single channel serial
    // link variant. We just feedthrough all the connections

    assign alloc2phy_data_out = data_link2alloc_data_out;
    assign alloc2phy_data_out_valid = data_link2alloc_data_out_valid;
    assign alloc2data_link_data_out_ready = phy2alloc_data_out_ready;

    assign alloc2data_link_data_in = phy2alloc_data_in;
    assign alloc2data_link_data_in_valid = phy2alloc_data_in_valid;
    assign alloc2phy_data_in_ready = data_link2alloc_data_in_ready;

  end else begin :gen_channel_alloc

    logic cfg_tx_clear, cfg_rx_clear;
    logic cfg_tx_flush_trigger;
    logic [NumChannels-1:0] cfg_tx_channel_en, cfg_rx_channel_en;

    assign cfg_tx_clear = reg2hw.serial_link.CHANNEL_ALLOC_TX_CTRL.wr_data.clear
      & reg2hw.serial_link.CHANNEL_ALLOC_TX_CTRL.req
      & reg2hw.serial_link.CHANNEL_ALLOC_TX_CTRL.req_is_wr
      & reg2hw.serial_link.CHANNEL_ALLOC_TX_CTRL.wr_biten.clear;
    assign cfg_rx_clear = reg2hw.serial_link.CHANNEL_ALLOC_RX_CTRL.wr_data.clear
      & reg2hw.serial_link.CHANNEL_ALLOC_RX_CTRL.req
      & reg2hw.serial_link.CHANNEL_ALLOC_RX_CTRL.req_is_wr
      & reg2hw.serial_link.CHANNEL_ALLOC_RX_CTRL.wr_biten.clear;
    assign cfg_tx_flush_trigger = reg2hw.serial_link.CHANNEL_ALLOC_TX_CTRL.wr_data.flush
      & reg2hw.serial_link.CHANNEL_ALLOC_TX_CTRL.req
      & reg2hw.serial_link.CHANNEL_ALLOC_TX_CTRL.req_is_wr
      & reg2hw.serial_link.CHANNEL_ALLOC_TX_CTRL.wr_biten.flush;
    for (genvar i = 0; i < NumChannels; i++) begin : gen_channel_en
      assign cfg_tx_channel_en[i] =
        reg2hw.serial_link.CHANNEL_ALLOC_TX_CH_EN[i].channel_alloc_tx_ch_en.value;
      assign cfg_rx_channel_en[i] =
        reg2hw.serial_link.CHANNEL_ALLOC_RX_CH_EN[i].channel_alloc_rx_ch_en.value;
    end

    serial_link_channel_allocator #(
      .phy_data_t  ( phy_data_t    ),
      .NumChannels ( NumChannels   )
    ) i_channel_allocator(
      .clk_i                     ( clk_sl_i                                       ),
      .rst_ni                    ( rst_sl_ni                                      ),
      .cfg_tx_clear_i            ( cfg_tx_clear                                   ),
      .cfg_tx_channel_en_i       ( cfg_tx_channel_en                              ),
      .cfg_tx_bypass_en_i        ( reg2hw.serial_link.CHANNEL_ALLOC_TX_CFG.bypass_en.value ),
      .cfg_tx_auto_flush_en_i    ( reg2hw.serial_link.CHANNEL_ALLOC_TX_CFG.auto_flush_en.value ),
      .cfg_tx_auto_flush_count_i ( reg2hw.serial_link.CHANNEL_ALLOC_TX_CFG.auto_flush_count.value ),
      .cfg_tx_flush_trigger_i    ( cfg_tx_flush_trigger                           ),
      .cfg_rx_clear_i            ( cfg_rx_clear                                   ),
      .cfg_rx_bypass_en_i        ( reg2hw.serial_link.CHANNEL_ALLOC_RX_CFG.bypass_en.value ),
      .cfg_rx_channel_en_i       ( cfg_rx_channel_en                              ),
      .cfg_rx_auto_flush_en_i    ( reg2hw.serial_link.CHANNEL_ALLOC_RX_CFG.auto_flush_en.value ),
      .cfg_rx_auto_flush_count_i ( reg2hw.serial_link.CHANNEL_ALLOC_RX_CFG.auto_flush_count.value ),
      .cfg_rx_sync_en_i          ( reg2hw.serial_link.CHANNEL_ALLOC_RX_CFG.sync_en.value ),
      // From Data Link Layer
      .data_out_i                ( data_link2alloc_data_out                       ),
      .data_out_valid_i          ( data_link2alloc_data_out_valid                 ),
      .data_out_ready_o          ( alloc2data_link_data_out_ready                 ),
      // To Phy
      .data_out_o                ( alloc2phy_data_out                             ),
      .data_out_valid_o          ( alloc2phy_data_out_valid                       ),
      .data_out_ready_i          ( phy2alloc_data_out_ready                       ),
      // From Phy
      .data_in_i                 ( phy2alloc_data_in                              ),
      .data_in_valid_i           ( phy2alloc_data_in_valid                        ),
      .data_in_ready_o           ( alloc2phy_data_in_ready                        ),
      // To Data Link Layer
      .data_in_o                 ( alloc2data_link_data_in                        ),
      .data_in_valid_o           ( alloc2data_link_data_in_valid                  ),
      .data_in_ready_i           ( data_link2alloc_data_in_ready                  )
    );
  end


  ////////////////////////
  //   PHYSICAL LAYER   //
  ////////////////////////

  for (genvar i = 0; i < NumChannels; i++) begin : gen_phy_channels
    serial_link_physical #(
      .NumLanes         ( NumLanes          ),
      .FifoDepth        ( RawModeFifoDepth  ),
      .MaxClkDiv        ( MaxClkDiv         ),
      .EnDdr            ( EnDdr             ),
      .phy_data_t       ( phy_data_t        )
    ) i_serial_link_physical (
      .clk_i             ( clk_sl_i                     ),
      .rst_ni            ( rst_sl_ni                    ),
      .clk_div_i         ( reg2hw.serial_link.TX_PHY_CLK_DIV[i].clk_divs.value ),
      .clk_shift_start_i ( reg2hw.serial_link.TX_PHY_CLK_START[i].clk_divs.value ),
      .clk_shift_end_i   ( reg2hw.serial_link.TX_PHY_CLK_END[i].clk_shift_end.value ),
      .ddr_rcv_clk_i     ( ddr_rcv_clk_i[i]             ),
      .ddr_rcv_clk_o     ( ddr_rcv_clk_o[i]             ),
      .data_out_i        ( alloc2phy_data_out[i]        ),
      .data_out_valid_i  ( alloc2phy_data_out_valid[i]  ),
      .data_out_ready_o  ( phy2alloc_data_out_ready[i]  ),
      .data_in_o         ( phy2alloc_data_in[i]         ),
      .data_in_valid_o   ( phy2alloc_data_in_valid[i]   ),
      .data_in_ready_i   ( alloc2phy_data_in_ready[i]   ),
      .ddr_i             ( ddr_i[i]                     ),
      .ddr_o             ( ddr_o[i]                     )
    );
  end

  /////////////////////////////////
  //   CONFIGURATION REGISTERS   //
  /////////////////////////////////

  if (!NoRegCdc) begin : gen_reg_cdc
    apb_cdc #(
      .LogDepth ( 1          ),
      .req_t    ( apb_req_t  ),
      .resp_t   ( apb_rsp_t  ),
      .addr_t   ( apb_addr_t ),
      .data_t   ( apb_data_t ),
      .strb_t   ( apb_strb_t )
    ) i_cdc_cfg (
      .src_pclk_i    ( clk_reg_i   ),
      .src_preset_ni ( rst_reg_ni  ),
      .src_req_i     ( apb_req_i   ),
      .src_resp_o    ( apb_rsp_o   ),

      .dst_pclk_i    ( clk_i       ),
      .dst_preset_ni ( rst_ni      ),
      .dst_req_o     ( apb_req     ),
      .dst_resp_i    ( apb_rsp     )
    );
  end else begin : gen_no_reg_cdc
    assign apb_req = apb_req_i;
    assign apb_rsp_o = apb_rsp;
  end

  if (NumChannels == 1) begin : gen_single_channel_cfg_regs
    serial_link_single_channel_reg i_serial_link_reg (
      .clk  (clk_i),
      .arst_n (rst_ni),

      .s_apb_psel    (apb_req.psel),
      .s_apb_penable (apb_req.penable),
      .s_apb_pwrite  (apb_req.pwrite),
      .s_apb_pprot   (apb_req.pprot),
      .s_apb_paddr   (apb_req.paddr[
        serial_link_single_channel_reg_pkg::SERIAL_LINK_SINGLE_CHANNEL_REG_MIN_ADDR_WIDTH-1:0]),
      .s_apb_pwdata  (apb_req.pwdata),
      .s_apb_pstrb   (apb_req.pstrb),
      .s_apb_pready  (apb_rsp.pready),
      .s_apb_prdata  (apb_rsp.prdata),
      .s_apb_pslverr (apb_rsp.pslverr),

      .hwif_in  (hw2reg),
      .hwif_out (reg2hw)
    );
  end else begin : gen_multi_channel_cfg_regs
    serial_link_reg i_serial_link_reg (
      .clk  (clk_i),
      .arst_n (rst_ni),

      .s_apb_psel    (apb_req.psel),
      .s_apb_penable (apb_req.penable),
      .s_apb_pwrite  (apb_req.pwrite),
      .s_apb_pprot   (apb_req.pprot),
      .s_apb_paddr   (apb_req.paddr[serial_link_reg_pkg::SERIAL_LINK_REG_MIN_ADDR_WIDTH-1:0]),
      .s_apb_pwdata  (apb_req.pwdata),
      .s_apb_pstrb   (apb_req.pstrb),
      .s_apb_pready  (apb_rsp.pready),
      .s_apb_prdata  (apb_rsp.prdata),
      .s_apb_pslverr (apb_rsp.pslverr),

      .hwif_in  (hw2reg),
      .hwif_out (reg2hw)
    );
  end

  assign clk_ena_o = reg2hw.serial_link.CTRL.clk_ena.value;
  assign reset_no = reg2hw.serial_link.CTRL.reset_n.value;
  assign isolate_o = {reg2hw.serial_link.CTRL.axi_out_isolate.value,
                      reg2hw.serial_link.CTRL.axi_in_isolate.value};
  assign hw2reg.serial_link.ISOLATED.rd_data.axi_in = isolated_i[0];
  assign hw2reg.serial_link.ISOLATED.rd_data.axi_out = isolated_i[1];

  assign hw2reg.serial_link.ISOLATED.rd_ack = reg2hw.serial_link.ISOLATED.req
    & ~reg2hw.serial_link.ISOLATED.req_is_wr;
  assign hw2reg.serial_link.ISOLATED.rd_data._reserved_31_2 = '0;
  for (genvar i = 0; i < NumChannels; i++) begin : gen_static_raw_mode_in_data_valid
    assign hw2reg.serial_link.RAW_MODE_IN_DATA_VALID[i].rd_ack =
        reg2hw.serial_link.RAW_MODE_IN_DATA_VALID[i].req
      & ~reg2hw.serial_link.RAW_MODE_IN_DATA_VALID[i].req_is_wr;
    assign hw2reg.serial_link.RAW_MODE_IN_DATA_VALID[i].rd_data._reserved_31_1 = '0;
  end
  assign hw2reg.serial_link.RAW_MODE_IN_DATA.rd_ack = reg2hw.serial_link.RAW_MODE_IN_DATA.req
    & ~reg2hw.serial_link.RAW_MODE_IN_DATA.req_is_wr;
  assign hw2reg.serial_link.RAW_MODE_IN_DATA.rd_data._reserved_31_16 = '0;
  assign hw2reg.serial_link.RAW_MODE_OUT_DATA_FIFO_CTRL.rd_ack =
      reg2hw.serial_link.RAW_MODE_OUT_DATA_FIFO_CTRL.req
    & ~reg2hw.serial_link.RAW_MODE_OUT_DATA_FIFO_CTRL.req_is_wr;
  assign hw2reg.serial_link.RAW_MODE_OUT_DATA_FIFO_CTRL.wr_ack =
      reg2hw.serial_link.RAW_MODE_OUT_DATA_FIFO_CTRL.req
    & reg2hw.serial_link.RAW_MODE_OUT_DATA_FIFO_CTRL.req_is_wr;
  assign hw2reg.serial_link.RAW_MODE_OUT_DATA_FIFO_CTRL.rd_data._reserved_7_0 = '0;
  assign hw2reg.serial_link.RAW_MODE_OUT_DATA_FIFO_CTRL.rd_data._reserved_30_11 = '0;
  assign hw2reg.serial_link.FLOW_CONTROL_FIFO_CLEAR.wr_ack =
      reg2hw.serial_link.FLOW_CONTROL_FIFO_CLEAR.req
    & reg2hw.serial_link.FLOW_CONTROL_FIFO_CLEAR.req_is_wr;
  assign hw2reg.serial_link.CHANNEL_ALLOC_TX_CTRL.wr_ack =
      reg2hw.serial_link.CHANNEL_ALLOC_TX_CTRL.req
    & reg2hw.serial_link.CHANNEL_ALLOC_TX_CTRL.req_is_wr;
  assign hw2reg.serial_link.CHANNEL_ALLOC_RX_CTRL.wr_ack =
      reg2hw.serial_link.CHANNEL_ALLOC_RX_CTRL.req
    & reg2hw.serial_link.CHANNEL_ALLOC_RX_CTRL.req_is_wr;

  ////////////////////
  //   ASSERTIONS   //
  ////////////////////

  `ASSERT_INIT(RawModeFifoDim, RecvFifoDepth >= RawModeFifoDepth)

endmodule : serial_link
