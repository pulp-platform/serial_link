// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>
// Modified: Yannick Baumann <baumanny@student.ethz.ch>

`include "common_cells/registers.svh"
`include "common_cells/assertions.svh"

// Implements the Data Link layer of the Serial Link
// Handles the RAW mode
module serial_link_data_link
import serial_link_pkg::*;
#(
  parameter type axis_req_t      = logic,
  parameter type axis_rsp_t      = logic,
  // The type of the payload sent via data channel of the axis. Must not be a multiple of entire bytes.
  parameter type payload_t       = logic,
  parameter type phy_data_t      = serial_link_pkg::phy_data_t,
  parameter int  NumChannels     = serial_link_pkg::NumChannels,
  parameter int  NumLanes        = serial_link_pkg::NumLanes,
  // For credit-based control flow
  parameter type credit_t        = logic,
  parameter int  NumCredits      = -1,
  parameter int  ForceSendThresh = NumCredits - 4,
  // Enable (assign to 1) to support valiable data sizes (of the AXIS). If enabled, the AXIS input
  // should contain clearly defined strobe bits (x values are not allowed)!
  // The size of the AXIS beat that is transmitted depends on the strobe. Leading zeros indicate
  // non-valid data which will not be transmitted. After the first 1 in the strobe sequence,
  // everything is transmitted, even if a zero follows in the strb mask later on.
  parameter bit  AllowVarAxisLen = 1'b0,
  // If TransferStrobe is assigned to 1, the strobe at the input is being transmitted
  parameter bit  TransferStrobe  = 1'b0,


  //////////////////////////
  // Dependant parameters //
  //////////////////////////

  localparam int Log2NumChannels  = (NumChannels > 1)? $clog2(NumChannels) : 1,
  localparam int RawModeFifoDepth = serial_link_pkg::RawModeFifoDepth,
  localparam int BandWidth        = NumChannels * NumLanes * 2,
  localparam int unsigned Log2RawModeFifoDepth = $clog2(RawModeFifoDepth)
) (
  input  logic                            clk_i,
  input  logic                            rst_ni,
  // AXI Stream interface signals
  input  axis_req_t                       axis_in_req_i,
  output axis_rsp_t                       axis_in_rsp_o,
  output axis_req_t                       axis_out_req_o,
  input  axis_rsp_t                       axis_out_rsp_i,
  // Phy Channel interface signals
  output phy_data_t [NumChannels-1:0]     data_out_o,
  output logic      [NumChannels-1:0]     data_out_valid_o,
  input  logic                            data_out_ready_i,
  input  phy_data_t [NumChannels-1:0]     data_in_i,
  input  logic      [NumChannels-1:0]     data_in_valid_i,
  output logic      [NumChannels-1:0]     data_in_ready_o,
  // Debug/Calibration signals
  input  logic                            cfg_flow_control_fifo_clear_i,
  input  logic                            cfg_raw_mode_en_i,
  input  logic [Log2NumChannels-1:0]      cfg_raw_mode_in_ch_sel_i,
  output phy_data_t                       cfg_raw_mode_in_data_o,
  output logic [NumChannels-1:0]          cfg_raw_mode_in_data_valid_o,
  input  logic                            cfg_raw_mode_in_data_ready_i,
  input  logic [NumChannels-1:0]          cfg_raw_mode_out_ch_mask_i,
  input  phy_data_t                       cfg_raw_mode_out_data_i,
  input  logic                            cfg_raw_mode_out_data_valid_i,
  input  logic                            cfg_raw_mode_out_en_i,
  input  logic                            cfg_raw_mode_out_data_fifo_clear_i,
  output logic [Log2RawModeFifoDepth-1:0] cfg_raw_mode_out_data_fifo_fill_state_o,
  output logic                            cfg_raw_mode_out_data_fifo_is_full_o
);

  ////////////////////////////////////////////////
  //  Software-controlled parameters and types  //
  ////////////////////////////////////////////////

  localparam int NumUserBits = $bits(axis_in_req_i.t.user);
  typedef  logic [NumUserBits-1:0] axis_user_bits_t;

  localparam int NumStrbBitsIncoming = (AllowVarAxisLen) ? $bits(axis_in_req_i.t.strb) : 0;
  localparam int NumStrbBitsToSend   = (TransferStrobe)  ? $bits(axis_in_req_i.t.strb) : 0;
  typedef  logic [NumStrbBitsIncoming-1:0] axis_strb_bits_t;

  typedef struct packed {
    logic [$bits(payload_t)+NumStrbBitsToSend-1:0] strb_data_bits;
    axis_user_bits_t user_bits;
  } axis_packet_t;

  // Assuming that the size of the split counter will at most result in one more split, its size is found as:
  // (Adjust in case data_hdr_info_t is adjusted. Should contain size of data_hdr_info_t without credit_t)
  localparam int MaxSplitsWithoutCntr  = (($bits(credit_t) + 1 + $bits(axis_packet_t)) + BandWidth - 1) / BandWidth;
  localparam int SplitCntrRequiredBits = $clog2(MaxSplitsWithoutCntr + 1);
  typedef logic [SplitCntrRequiredBits-1:0] split_cntr_t;

  typedef struct packed {
    split_cntr_t req_num_splits;
    credit_t amount_of_credits;
    logic is_credits_only;
  } data_hdr_info_t;

  // The width used to transfer all the data contained in one axis-packet (so far data, user & strb bits are supported)
  localparam int MaxNumOfBitsToBeTransfered = $bits(axis_packet_t) + $bits(data_hdr_info_t);
  localparam int MaxPossibleTransferSplits  = (MaxNumOfBitsToBeTransfered + BandWidth - 1) / BandWidth;
  localparam int RecvFifoDepth = NumCredits * MaxPossibleTransferSplits;

  data_hdr_info_t received_hdr, send_hdr, pre_received_hdr;
  logic pre_received_hdr_valid, received_hdr_valid;

  // These unfiltered axis_out signals will have to be analyzed for credits_only packets
  // which will not be allowed to propagate to the axis output.
  axis_req_t axis_out_req_unfiltered;
  axis_rsp_t axis_out_rsp_unfiltered;

  // credit-based-flow-control related signals (The axis user-bits are now also packed and transfered)
  axis_packet_t axis_packet_in_synch_out, axis_packet_in_synch_in, axis_packet_out;
  logic axis_in_req_tvalid_afterFlowControl;
  logic axis_in_rsp_tready_afterFlowControl;
  logic credits_only_packet_in;
  logic consume_incoming_credits;
  credit_t credits_incoming;

  logic [MaxPossibleTransferSplits-1:0] recv_reg_in_valid, recv_reg_in_ready;
  logic [MaxPossibleTransferSplits-1:0] recv_reg_out_valid, recv_reg_out_ready;
  phy_data_t [MaxPossibleTransferSplits-1:0][NumChannels-1:0] recv_reg_data;
  logic [$clog2(MaxPossibleTransferSplits)-1:0] recv_reg_index_q, recv_reg_index_d;

  link_state_e link_state_q, link_state_d;
  logic [$clog2(MaxPossibleTransferSplits*NumChannels*NumLanes*2):0] link_out_index_q, link_out_index_d;

  logic raw_mode_fifo_full, raw_mode_fifo_empty;
  logic raw_mode_fifo_push, raw_mode_fifo_pop;
  phy_data_t raw_mode_fifo_data_in, raw_mode_fifo_data_out;

  logic [MaxPossibleTransferSplits-1:0] splitSegmentsToBeSent;
  logic [$clog2(MaxNumOfBitsToBeTransfered+1)-1:0] remainingBitsToBeSent;

  logic [$clog2(NumStrbBitsIncoming+1):0] numLeadZero;
  split_cntr_t trailing_zero_counter;
  logic all_zeros;
  logic [NumStrbBitsIncoming-1:0] strb_after_synchronization;


  /////////////////////////////////////////////////
  //  Find the amount of data to be transmitted  //
  /////////////////////////////////////////////////

  generate
    if (AllowVarAxisLen) begin
      lzc #(
        .WIDTH ( NumStrbBitsIncoming ),
        .MODE  ( 1'b1        )
      ) i_leading_zero_counter (
        .in_i    ( strb_after_synchronization ),
        .cnt_o   ( numLeadZero ),
        .empty_o ()
      );

      // alternative implementation to the cealing division.
      for (genvar i = 0; i < MaxPossibleTransferSplits; i++) begin
        assign splitSegmentsToBeSent[i] = remainingBitsToBeSent <= (i*BandWidth);
      end
      lzc #(
        .WIDTH ( MaxPossibleTransferSplits ),
        .MODE  ( 1'b0        )
      ) i_trailing_zero_counter (
        .in_i    ( splitSegmentsToBeSent ),
        .cnt_o   ( trailing_zero_counter ),
        .empty_o ( all_zeros )
      );

      // lzc module does not output the correct amount of trailing zeroes when the entire input consists of zeroes only.
      assign send_hdr.req_num_splits = ((all_zeros) ? MaxPossibleTransferSplits : trailing_zero_counter);
      assign remainingBitsToBeSent = (MaxNumOfBitsToBeTransfered - ({numLeadZero,3'b0} + numLeadZero));

    end else begin
      assign send_hdr.req_num_splits = MaxPossibleTransferSplits;
      assign remainingBitsToBeSent = MaxNumOfBitsToBeTransfered;
    end
  endgenerate

  // TODO: remove the initial begin block below. Only for debugging purposes...
  initial begin
    #3;
    $display("INFO: Parameter and sizes | Number of required splits: %0d (Bandwidth: %0d & Transfer_size: %0d => strb_data_bits: %0d & user_bits: %0d & req_num_splits: %0d & amount_of_credits: %0d & is_credits_only: 1 => strb %0d)",MaxPossibleTransferSplits, BandWidth, MaxNumOfBitsToBeTransfered, ($bits(payload_t)+NumStrbBitsToSend), NumUserBits, SplitCntrRequiredBits, $bits(credit_t), NumStrbBitsToSend);
    $display("INFO: Packet-size definit | Strobe to be sent: %76b", axis_in_req_i.t.strb);
    $display("INFO: Analytics and stats | splitSegmentsToBeSent: %b", splitSegmentsToBeSent);
    $display("INFO: Analytics and stats | trailing_zero_counter: %0d", trailing_zero_counter);
    $display("INFO: Analytics and stats | all_zeros: %1b", all_zeros);
    $display("INFO: Analytics and stats | payload_t: %0d", $bits(payload_t));
    $display("INFO: Actually to be sent | Transfer_size: %0d", remainingBitsToBeSent);
    $display("INFO: Actually to be sent | Number of required splits: %0d", (remainingBitsToBeSent+BandWidth-1) / BandWidth);
    $display("INFO: Actually to be sent | send_hdr.req_num_splits: %0d", send_hdr.req_num_splits);
    $display("INFO: ------------------------------------------------");
    // $error("Simulation not actually started. Prevented by debug block...");
    // $stop;
  end


  /////////////////
  //   DATA IN   //
  /////////////////

  //Datatype for the stream fifo and register
  typedef phy_data_t [NumChannels-1:0] phy_data_chan_t;
  phy_data_chan_t flow_control_fifo_data_out;
  logic flow_control_fifo_valid_out, flow_control_fifo_ready_out;
  logic flow_control_fifo_valid_in, flow_control_fifo_ready_in;

  stream_fifo #(
    .T     ( phy_data_chan_t ),
    .DEPTH ( RecvFifoDepth   )
  ) i_flow_control_fifo (
    .clk_i      ( clk_i                         ),
    .rst_ni     ( rst_ni                        ),
    .flush_i    ( cfg_flow_control_fifo_clear_i ),
    .testmode_i ( 1'b0                          ),
    .usage_o    (                               ),
    .data_i     ( data_in_i                     ),
    .valid_i    ( flow_control_fifo_valid_in    ),
    .ready_o    ( flow_control_fifo_ready_in    ),
    .data_o     ( flow_control_fifo_data_out    ),
    .valid_o    ( flow_control_fifo_valid_out   ),
    .ready_i    ( flow_control_fifo_ready_out   )
  );

  for (genvar i = 0; i < MaxPossibleTransferSplits; i++) begin : gen_recv_reg
    stream_register #(
      .T ( phy_data_chan_t )
    ) i_recv_reg (
      .clk_i      ( clk_i                      ),
      .rst_ni     ( rst_ni                     ),
      .clr_i      ( 1'b0                       ),
      .testmode_i ( 1'b0                       ),
      .valid_i    ( recv_reg_in_valid[i]       ),
      .ready_o    ( recv_reg_in_ready[i]       ),
      .data_i     ( flow_control_fifo_data_out ),
      .valid_o    ( recv_reg_out_valid[i]      ),
      .ready_i    ( recv_reg_out_ready[i]      ),
      .data_o     ( recv_reg_data[i]           )
    );
  end

  //extract packet info from recv_reg_data
  assign {axis_packet_out, received_hdr} = recv_reg_data;
  assign axis_out_req_unfiltered.t.user  = axis_packet_out.user_bits;
  assign pre_received_hdr = flow_control_fifo_data_out;
  generate
    if (TransferStrobe) begin
      for (genvar i = 0; i < NumStrbBitsToSend; i++) begin
        if (8*i+7 < $bits(payload_t)) begin
          assign axis_out_req_unfiltered.t.strb[i] = axis_packet_out.strb_data_bits[9*i];
          assign axis_out_req_unfiltered.t.data[8*i+7:8*i] = axis_packet_out.strb_data_bits[9*i+8:9*i+1];
        end else begin
          // prevent out of bounds warning
          assign axis_out_req_unfiltered.t.strb[i] = axis_packet_out.strb_data_bits[9*i];
          assign axis_out_req_unfiltered.t.data[$bits(payload_t)-1:8*i] = axis_packet_out.strb_data_bits[i+$bits(payload_t):9*i+1];
        end
      end
    end else begin
      // TODO: assign strb bits if they are not sent along (reconstructing) => Do I need the -1?
      assign axis_out_req_unfiltered.t.data = axis_packet_out.strb_data_bits[$bits(payload_t)-1:0];
    end
  endgenerate

  // Handshake and flow control for the stream_registers and the AXIS output interface
  always_comb begin
    recv_reg_in_valid = '0;
    data_in_ready_o = '0;
    recv_reg_index_d = recv_reg_index_q;
    axis_out_req_unfiltered.tvalid = 1'b0;
    credits_only_packet_in = received_hdr.is_credits_only;
    recv_reg_out_ready = '0;
    cfg_raw_mode_in_data_o = '0;
    cfg_raw_mode_in_data_valid_o = '0;
    flow_control_fifo_valid_in = 1'b0;
    flow_control_fifo_ready_out = 1'b0;
    // TOOD: remove the two signals below if not required...
    // indicates if the hdr-info can be read from pre_received_hdr
    pre_received_hdr_valid = 1'b0;
    // indicates if the hdr-info can be read from received_hdr
    received_hdr_valid = recv_reg_out_valid[0];

    if (cfg_raw_mode_en_i) begin
      // Raw mode
      cfg_raw_mode_in_data_valid_o = data_in_valid_i;
      // Ready is asserted if there is a read access
      if (cfg_raw_mode_in_data_ready_i) begin
        // Select channel to read from and wait for valid data
        if (data_in_valid_i[cfg_raw_mode_in_ch_sel_i]) begin
          // Pop item from CDC RX FIFO
          data_in_ready_o[cfg_raw_mode_in_ch_sel_i] = 1'b1;
          // respond with data from selected channel
          cfg_raw_mode_in_data_o = data_in_i[cfg_raw_mode_in_ch_sel_i];
        end else begin
          // TODO: send out Error response
        end
      end
    end else begin
      // Normal operating mode

      // Once all Recv Stream Registers are filled -> generate AXI stream request
      if (recv_reg_out_valid[0]) begin
        // It is important to have this line at the beginning. Due to the sequential evaluation, the code might not work otherwise.
        axis_out_req_unfiltered.tvalid = recv_reg_out_valid[received_hdr.req_num_splits-1];
      end
      recv_reg_out_ready = {MaxPossibleTransferSplits{axis_out_rsp_unfiltered.tready & axis_out_req_unfiltered.tvalid}};

      // If all inputs of each channel have valid data, push it to fifo
      flow_control_fifo_valid_in = &data_in_valid_i;
      data_in_ready_o = {NumChannels{flow_control_fifo_valid_in & flow_control_fifo_ready_in}};
      if (flow_control_fifo_valid_out & recv_reg_in_ready[recv_reg_index_q]) begin
        recv_reg_in_valid[recv_reg_index_q] = 1'b1;
        flow_control_fifo_ready_out = 1'b1;
        // Increment recv reg counter (if I have a valid handshake at the output, consuming the data in the stream_registers, while
        // a new packet is being shifted in, the new header is accessible from the pre_received_hdr and not from the received_hdr)
        if (recv_reg_out_valid[0] & !(axis_out_rsp_unfiltered.tready & axis_out_req_unfiltered.tvalid)) begin
          // The header info is received and savely stored in the first stream_register
          recv_reg_index_d = (recv_reg_index_q == received_hdr.req_num_splits - 1) ? 0 : recv_reg_index_q + 1;
        end else begin
          // The valid header info has not yet passed to the register and is only available in the pre_register stage
          recv_reg_index_d = (recv_reg_index_q == pre_received_hdr.req_num_splits - 1) ? 0 : recv_reg_index_q + 1;
          pre_received_hdr_valid = 1'b1;
        end
      end
    end
  end

  `FF(recv_reg_index_q, recv_reg_index_d, '0)


  ////////////////////////////////
  //   FLOW-CONTROL-INSERTION   //
  ////////////////////////////////

generate
    if (TransferStrobe | AllowVarAxisLen) begin
      serial_link_credit_synchronization #(
        .credit_t   ( credit_t                                   ),
        .data_width ( $bits(axis_packet_t) + NumStrbBitsIncoming ),
        .NumCredits ( NumCredits                                 )
      ) i_synchronization_flow_control (
        .clk_i                  ( clk_i                                                  ),
        .rst_ni                 ( rst_ni                                                 ),
        .data_to_send_i         ( {axis_in_req_i.t.strb, axis_packet_in_synch_in}        ),
        .data_to_send_o         ( {strb_after_synchronization, axis_packet_in_synch_out} ),
        .credits_to_send_o      ( send_hdr.amount_of_credits                             ),
        .send_ready_o           ( axis_in_rsp_o.tready                                   ),
        .send_valid_i           ( axis_in_req_i.tvalid                                   ),
        .send_valid_o           ( axis_in_req_tvalid_afterFlowControl                    ),
        .send_ready_i           ( axis_in_rsp_tready_afterFlowControl                    ),
        .credits_received_i     ( credits_incoming                                       ),
        .receive_cred_i         ( consume_incoming_credits                               ),
        .buffer_queue_out_val_i ( axis_out_req_unfiltered.tvalid                         ),
        .buffer_queue_out_rdy_i ( axis_out_rsp_unfiltered.tready                         ),
        .credits_only_packet_o  ( send_hdr.is_credits_only                               ),
        .allow_cred_consume_i   ( 1'b1                                                   ),
        .consume_cred_to_send_i ( 1'b0                                                   )
      );
    end else begin
      serial_link_credit_synchronization #(
        .credit_t   ( credit_t      ),
        .data_t     ( axis_packet_t ),
        .NumCredits ( NumCredits    )
      ) i_synchronization_flow_control (
        .clk_i                  ( clk_i                               ),
        .rst_ni                 ( rst_ni                              ),
        .data_to_send_i         ( axis_packet_in_synch_in             ),
        .data_to_send_o         ( axis_packet_in_synch_out            ),
        .credits_to_send_o      ( send_hdr.amount_of_credits          ),
        .send_ready_o           ( axis_in_rsp_o.tready                ),
        .send_valid_i           ( axis_in_req_i.tvalid                ),
        .send_valid_o           ( axis_in_req_tvalid_afterFlowControl ),
        .send_ready_i           ( axis_in_rsp_tready_afterFlowControl ),
        .credits_received_i     ( credits_incoming                    ),
        .receive_cred_i         ( consume_incoming_credits            ),
        .buffer_queue_out_val_i ( axis_out_req_unfiltered.tvalid      ),
        .buffer_queue_out_rdy_i ( axis_out_rsp_unfiltered.tready      ),
        .credits_only_packet_o  ( send_hdr.is_credits_only            ),
        .allow_cred_consume_i   ( 1'b1                                ),
        .consume_cred_to_send_i ( 1'b0                                )
      );
    end
  endgenerate

  assign credits_incoming = received_hdr.amount_of_credits;
  assign consume_incoming_credits = axis_out_req_unfiltered.tvalid & axis_out_rsp_unfiltered.tready;


  //////////////////
  //   DATA OUT   //
  //////////////////

  // create outgoing data_stream (pack the data)
  assign axis_packet_in_synch_in.user_bits = axis_in_req_i.t.user;
  generate
    if (TransferStrobe) begin
      for (genvar i = 0; i < NumStrbBitsToSend; i++) begin
        if (8*i+7 < $bits(payload_t)) begin
          assign axis_packet_in_synch_in.strb_data_bits[9*i+8:9*i] = {axis_in_req_i.t.data[8*i+7:8*i], strb_after_synchronization[i]};
        end else begin
          // prevent out of bounds warning:
          assign axis_packet_in_synch_in.strb_data_bits[i+$bits(payload_t):9*i] = {axis_in_req_i.t.data[$bits(payload_t)-1:8*i], strb_after_synchronization[i]};
        end
      end
    end else begin
      assign axis_packet_in_synch_in.strb_data_bits = axis_in_req_i.t.data;
    end
  endgenerate

  // wrapped_output_data stream.
  localparam int transfer_data_width = $bits({axis_packet_in_synch_out, send_hdr});
  logic [transfer_data_width-1:0] wrapped_output_data;
  assign wrapped_output_data = {axis_packet_in_synch_out, send_hdr};

  // logic for splitting and transfering the wapped_output_data stream.
  always_comb begin
    axis_in_rsp_tready_afterFlowControl = 1'b0;
    data_out_o = '0;
    data_out_valid_o = '0;
    link_out_index_d = link_out_index_q;
    link_state_d = link_state_q;
    raw_mode_fifo_pop = 1'b0;

    if (cfg_raw_mode_en_i) begin
      // Raw mode
      if (cfg_raw_mode_out_en_i & ~raw_mode_fifo_empty) begin
        data_out_valid_o = cfg_raw_mode_out_ch_mask_i;
        data_out_o = {{NumChannels}{raw_mode_fifo_data_out}};
        if (data_out_ready_i) begin
          raw_mode_fifo_pop = 1'b1;
        end
      end
    end else begin
      // Normal operating mode
      unique case (link_state_q)
        LinkSendIdle: begin
          if (axis_in_req_tvalid_afterFlowControl) begin
            link_out_index_d = NumChannels * NumLanes * 2;
            data_out_valid_o = '1;
            data_out_o = wrapped_output_data;
            if (data_out_ready_i) begin
              link_state_d = LinkSendBusy;
              if (link_out_index_d >= remainingBitsToBeSent) begin
                link_state_d = LinkSendIdle;
                axis_in_rsp_tready_afterFlowControl = 1'b1;
              end
            end
          end
        end

        LinkSendBusy: begin
          data_out_valid_o = '1;
          data_out_o = wrapped_output_data >> link_out_index_q;
          if (data_out_ready_i) begin
            link_out_index_d = link_out_index_q + NumChannels * NumLanes * 2;
            if (link_out_index_d >= remainingBitsToBeSent) begin
              link_state_d = LinkSendIdle;
              axis_in_rsp_tready_afterFlowControl = 1'b1;
            end
          end
        end
        default:;
      endcase
    end
  end

  // Credit only packets should not be forwarded as they do not contain valid data
  always_comb begin
    axis_out_req_o.tvalid = (credits_only_packet_in == 1) ? 0 : axis_out_req_unfiltered.tvalid;
    axis_out_req_o.t.data = axis_out_req_unfiltered.t.data;
    axis_out_req_o.t.user = axis_out_req_unfiltered.t.user;
    // make the credit only packet disappear (consume it)
    axis_out_rsp_unfiltered.tready = axis_out_rsp_i.tready || (credits_only_packet_in == 1);
  end

  fifo_v3 #(
    .dtype  ( phy_data_t        ),
    .DEPTH  ( RawModeFifoDepth  )
  ) i_raw_mode_fifo (
    .clk_i      ( clk_i                                   ),
    .rst_ni     ( rst_ni                                  ),
    .flush_i    ( cfg_raw_mode_out_data_fifo_clear_i      ),
    .testmode_i ( 1'b0                                    ),
    .full_o     ( raw_mode_fifo_full                      ),
    .empty_o    ( raw_mode_fifo_empty                     ),
    .usage_o    ( cfg_raw_mode_out_data_fifo_fill_state_o ),
    .data_i     ( raw_mode_fifo_data_in                   ),
    .push_i     ( raw_mode_fifo_push                      ),
    .data_o     ( raw_mode_fifo_data_out                  ),
    .pop_i      ( raw_mode_fifo_pop                       )
  );

  assign cfg_raw_mode_out_data_fifo_is_full_o = raw_mode_fifo_full;
  assign raw_mode_fifo_push = cfg_raw_mode_out_data_valid_i & ~raw_mode_fifo_full;
  assign raw_mode_fifo_data_in = cfg_raw_mode_out_data_i;

  `FF(link_out_index_q, link_out_index_d, '0)
  `FF(link_state_q, link_state_d, LinkSendIdle)


  ////////////////////
  //   ASSERTIONS   //
  ////////////////////

  `ASSERT_INIT(RawModeFifoDim, RecvFifoDepth >= RawModeFifoDepth)
  // Bandwidth must be large enough to allow the meta packet header to be sent in one go.
  `ASSERT_INIT(BandWidthTooSmall, BandWidth >= $bits(data_hdr_info_t))

endmodule