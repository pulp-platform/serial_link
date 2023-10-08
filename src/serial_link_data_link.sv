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
  // The type of the payload sent via data channel of the axis.
  // Must not be a multiple of entire bytes.
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
  // If the parameter is enabled, smaller messages may be collected and sent in a single physical
  // transfer in order to increase the physical links utilization.
  // NOTE: If the physical link is too narrow, this feature is not supported and will be
  // automatically disabled. A warning will be printed to the console, should that be the case.
  parameter bit  PackMultipleMsg = AllowVarAxisLen,


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

  //Datatype for the stream fifo and register
  typedef phy_data_t [NumChannels-1:0] phy_data_chan_t;
  // TODO: fetch the correct clock divider ...
  localparam int  ClockDiv     = 8;
  // The width of phy_data_chan_t corresponds to the BandWidth
  localparam int  InputSize    = $bits(phy_data_chan_t);
  // Find blocksize when input-data is split into ClockDiv number of equi-sized blocks.
  localparam int  BlockSize    = (InputSize + ClockDiv  - 1) / ClockDiv;
  localparam type data_block_t = logic [BlockSize-1:0];

  localparam int NumStrbBitsIncoming = $bits(axis_in_req_i.t.strb);
  typedef  logic [NumStrbBitsIncoming-1:0] axis_strb_bits_t;

  typedef struct packed {
    logic [$bits(payload_t)-1:0] data_bits;
    axis_user_bits_t user_bits;
  } axis_packet_t;

  // Assuming the size of the split counter results at most in one more split,
  // the split count can be found to be:
  // NOTE: There are 'ClockDiv' control bits sent per physical transfer,
  // reducing the effectively available bandwidth.
  localparam int MaxSplitsWithoutCntr  =
             ($bits(credit_t) + $bits(axis_packet_t) + BandWidth - ClockDiv)
             / (BandWidth - ClockDiv);
  // At most one additional split occurs due to the split coutner
  localparam int SplitCntrRequiredBits = $clog2(MaxSplitsWithoutCntr + 1);
  typedef  logic [SplitCntrRequiredBits-1:0] split_cntr_t;

  typedef struct packed {
    split_cntr_t req_num_splits;
    credit_t amount_of_credits;
    logic is_credits_only;
  } data_hdr_info_t;

  // The width used to transfer all the data contained in one axis-packet
  // (so far data, user & strb bits are supported)
  localparam int MaxNumOfBitsToBeTransfered = $bits(axis_packet_t) + $bits(data_hdr_info_t);

  // If PackMultipleMsg is enabled, but the physical link is too narrow, I may disable the
  // parameter automatically.
  localparam bit PackSmallerMsgIntoSingleTransfer =
             (PackMultipleMsg) ? ($bits(data_block_t)>$bits(data_hdr_info_t)) : 0;
  localparam int BlockCount = (PackSmallerMsgIntoSingleTransfer) ? ClockDiv : 0;

  localparam int MaxPossibleTransferSplits =
             (MaxNumOfBitsToBeTransfered + BandWidth - BlockCount - 1) / (BandWidth - BlockCount);
  localparam int RecvFifoDepth =
             (AllowVarAxisLen) ? NumCredits : NumCredits * MaxPossibleTransferSplits;

  // find additional block control bits count.
  localparam int AdditionalBits =
             (PackSmallerMsgIntoSingleTransfer) ? (ClockDiv*MaxPossibleTransferSplits) : 0;

  // The largest possible size of AXIS out data contains the payload itself,
  // the axis user-bits and the shift control bits.
  // The same as axis_packet_t but with inserted block control bits.
  typedef logic [$bits(axis_packet_t)+AdditionalBits-1:0] aligned_axis_t;

  // Software: Print warning if parameter value had to be changed.
  initial begin
    if (PackMultipleMsg & ($bits(data_block_t)<=$bits(data_hdr_info_t))) begin
      $display("INFO: WARNING: PackMultipleMsg was enabled, but got disabled due to the dimensions\
 of the physical link.");
    end
    $display("INFO: PackSmallerMsgIntoSingleTransfer=%0d (%m)", PackSmallerMsgIntoSingleTransfer);
    // $error("Simulation was terminated by debug code section in %m");
    // $stop();
  end

  data_hdr_info_t received_hdr, send_hdr, pre_received_hdr, incoming_hdr;

  // These unfiltered axis_out signals will have to be analyzed for credits_only packets
  // which will not be allowed to propagate to the axis output.
  axis_req_t axis_out_req_unfiltered;
  axis_rsp_t axis_out_rsp_unfiltered;

  // credit-based-flow-control related signals
  // (The axis user-bits are now also packed and transfered)
  axis_packet_t axis_packet_out;
  aligned_axis_t axis_packet_in_synch_out, axis_packet_in_synch_in, axis_packet_in_enqueue_out;
  logic axis_in_req_tvalid_afterFlowControl;
  logic axis_in_rsp_tready_afterFlowControl;
  logic credits_only_packet_in;
  logic consume_incoming_credits;
  credit_t credits_incoming;

  logic [MaxPossibleTransferSplits-1:0] recv_reg_in_valid, recv_reg_in_ready;
  logic [MaxPossibleTransferSplits-1:0] recv_reg_out_valid, recv_reg_out_ready;
  logic [MaxPossibleTransferSplits-1:0] recv_reg_contains_data;
  // The block-control-bits are removed from dequeue_shift_registers output (thus -ClockDiv).
  logic [MaxPossibleTransferSplits-1:0][NumChannels*NumLanes*2-1-BlockCount:0] recv_reg_data;
  logic [$clog2(MaxPossibleTransferSplits)-1:0] recv_reg_index_q, recv_reg_index_d;

  link_state_e link_state_q, link_state_d;
  logic [$clog2(MaxPossibleTransferSplits*NumChannels*NumLanes*2):0] link_out_index_q;
  logic [$clog2(MaxPossibleTransferSplits*NumChannels*NumLanes*2):0] link_out_index_d;

  logic raw_mode_fifo_full, raw_mode_fifo_empty;
  logic raw_mode_fifo_push, raw_mode_fifo_pop;
  phy_data_t raw_mode_fifo_data_in, raw_mode_fifo_data_out;

  data_block_t [MaxPossibleTransferSplits-1:0] last_blocks;
  logic        [MaxPossibleTransferSplits-1:0] first_hs, shift_enable, shifts_allowed;
  logic        fifo_valid_out, fifo_ready_out;

  split_cntr_t required_splits_reg_out;
  logic valid_synch_in, ready_synch_in;

  logic output_handshake;


  //////////////////////////////////////
  //  Collect data to be transmitted  //
  //////////////////////////////////////

  axis_packet_t axis_in_data_in;
  assign axis_in_data_in.user_bits = axis_in_req_i.t.user;
  assign axis_in_data_in.data_bits = axis_in_req_i.t.data;

  if (PackSmallerMsgIntoSingleTransfer) begin : pack_data_and_find_splits
    enqueue_register #(
      .AllowVarAxisLen           ( AllowVarAxisLen                        ),
      .ClkDiv                    ( ClockDiv                               ),
      .data_block_t              ( data_block_t                           ),
      .strb_t                    ( axis_strb_bits_t                       ),
      .data_in_t                 ( axis_packet_t                          ),
      .split_cntr_t              ( split_cntr_t                           ),
      .MaxPossibleTransferSplits ( MaxPossibleTransferSplits              ),
      .NumExternalBitsAdded      ( NumUserBits                            ),
      .NumExternalBitsAddedFirst ( $bits(send_hdr)                        ),
      .NarrowStrbCount           ( noc_bridge_narrow_wide_pkg::NarrowSize )
    ) i_data_collector (
      .clk_i        ( clk_i                   ),
      .rst_ni       ( rst_ni                  ),

      .valid_i      ( axis_in_req_i.tvalid    ),
      .ready_o      ( axis_in_rsp_o.tready    ),
      .data_i       ( axis_in_data_in         ),
      .strb_i       ( axis_in_req_i.t.strb    ),

      .valid_o      ( valid_synch_in          ),
      .ready_i      ( ready_synch_in          ),
      .data_o       ( axis_packet_in_synch_in ),

      .num_splits_o ( required_splits_reg_out )
    );
  end else begin : pack_data_and_find_splits
    assign axis_packet_in_synch_in = axis_in_data_in;
    assign valid_synch_in          = axis_in_req_i.tvalid;
    assign axis_in_rsp_o.tready    = ready_synch_in;

    find_req_blocks #(
      .AllowVarAxisLen           ( AllowVarAxisLen               ),
      .StrbSize                  ( NumStrbBitsIncoming           ),
      .block_cntr_t              ( split_cntr_t                  ),
      .MaxPossibleTransferSplits ( MaxPossibleTransferSplits     ),
      .NumExternalBitsAdded      ( $bits(send_hdr) + NumUserBits ),
      .BlockSize                 ( BandWidth                     )
    ) i_find_splits (
      .use_first_externals_i ( 0                       ),
      .strb_i                ( axis_in_req_i.t.strb    ),
      .required_blocks_o     ( required_splits_reg_out )
    );
  end

  // credit_only messages consume only once split
  if (AllowVarAxisLen) begin
    assign send_hdr.req_num_splits =  (send_hdr.is_credits_only) ? 'd1 : required_splits_reg_out;
  end else begin
    assign send_hdr.req_num_splits =  MaxPossibleTransferSplits;
  end


  ////////////////////////////////
  //   FLOW-CONTROL-INSERTION   //
  ////////////////////////////////

  if (AllowVarAxisLen) begin : choose_consumption_type
    serial_link_credit_synchronization #(
      .credit_t          ( credit_t                  ),
      .data_t            ( aligned_axis_t            ),
      .MaxCredPerPktOut  ( MaxPossibleTransferSplits ),
      .NumCredits        ( NumCredits                ),
      .CredOnlyConsCred  ( 1                         )
    ) i_synchronization_flow_control (
      .clk_i                  ( clk_i                               ),
      .rst_ni                 ( rst_ni                              ),
      .data_to_send_i         ( axis_packet_in_synch_in             ),
      .data_to_send_o         ( axis_packet_in_synch_out            ),
      .credits_to_send_o      ( send_hdr.amount_of_credits          ),
      .send_ready_o           ( ready_synch_in                      ),
      .send_valid_i           ( valid_synch_in                      ),
      .send_valid_o           ( axis_in_req_tvalid_afterFlowControl ),
      .send_ready_i           ( axis_in_rsp_tready_afterFlowControl ),
      .req_cred_to_buffer_msg ( required_splits_reg_out             ),
      .credits_received_i     ( credits_incoming                    ),
      .receive_cred_i         ( consume_incoming_credits            ),
      .buffer_queue_out_val_i ( fifo_valid_out                      ),
      .buffer_queue_out_rdy_i ( fifo_ready_out                      ),
      .credits_only_packet_o  ( send_hdr.is_credits_only            ),
      .allow_cred_consume_i   ( 1'b1                                ),
      .consume_cred_to_send_i ( 1'b0                                )
    );
  end else begin : choose_consumption_type
    serial_link_credit_synchronization #(
      .credit_t          ( credit_t       ),
      .data_t            ( aligned_axis_t ),
      .NumCredits        ( NumCredits     ),
      .CredOnlyConsCred  ( 1              )
    ) i_synchronization_flow_control (
      .clk_i                  ( clk_i                               ),
      .rst_ni                 ( rst_ni                              ),
      .data_to_send_i         ( axis_packet_in_synch_in             ),
      .data_to_send_o         ( axis_packet_in_synch_out            ),
      .credits_to_send_o      ( send_hdr.amount_of_credits          ),
      .send_ready_o           ( ready_synch_in                      ),
      .send_valid_i           ( valid_synch_in                      ),
      .send_valid_o           ( axis_in_req_tvalid_afterFlowControl ),
      .send_ready_i           ( axis_in_rsp_tready_afterFlowControl ),
      .req_cred_to_buffer_msg ( 1'b1                                ),
      .credits_received_i     ( credits_incoming                    ),
      .receive_cred_i         ( consume_incoming_credits            ),
      .buffer_queue_out_val_i ( axis_out_req_unfiltered.tvalid      ),
      .buffer_queue_out_rdy_i ( axis_out_rsp_unfiltered.tready      ),
      .credits_only_packet_o  ( send_hdr.is_credits_only            ),
      .allow_cred_consume_i   ( 1'b1                                ),
      .consume_cred_to_send_i ( 1'b0                                )
    );
  end


  //////////////////
  //   DATA OUT   //
  //////////////////

  // wrapped_output_data stream.
  localparam int TransferDataWidth = $bits({axis_packet_in_synch_out, send_hdr});
  logic [TransferDataWidth-1:0] wrapped_output_data;
  assign wrapped_output_data = {axis_packet_in_synch_out, send_hdr};

  // logic for splitting and transfering the wrapped_output_data stream.
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
            link_out_index_d = 1;
            data_out_valid_o = '1;
            data_out_o = wrapped_output_data;
            if (data_out_ready_i) begin
              link_state_d = LinkSendBusy;
              if (link_out_index_d >= send_hdr.req_num_splits) begin
                link_state_d = LinkSendIdle;
                axis_in_rsp_tready_afterFlowControl = 1'b1;
              end
            end
          end
        end

        LinkSendBusy: begin
          data_out_valid_o = '1;
          data_out_o = wrapped_output_data >> (link_out_index_q * BandWidth);
          if (data_out_ready_i) begin
            link_out_index_d = link_out_index_q + 1;
            if (link_out_index_d >= send_hdr.req_num_splits) begin
              link_state_d = LinkSendIdle;
              axis_in_rsp_tready_afterFlowControl = 1'b1;
            end
          end
        end
        default:;
      endcase
    end
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


  /////////////////
  //   DATA IN   //
  /////////////////

  phy_data_chan_t flow_control_fifo_data_out;
  logic flow_control_fifo_valid_out, flow_control_fifo_ready_out;
  logic flow_control_fifo_valid_in, flow_control_fifo_ready_in;

  // TODO: place blocks in the propper position of the code...
  logic credit_only_packet_incoming;
  credit_t cred_count_for_cred_only;

  if (AllowVarAxisLen) begin : credit_only_control
    always_comb begin
      incoming_hdr   = flow_control_fifo_data_out;
      fifo_ready_out = flow_control_fifo_ready_out;
      cred_count_for_cred_only    = 0;
      credit_only_packet_incoming = 0;
      flow_control_fifo_valid_out = fifo_valid_out;

      if (recv_reg_index_q == 0 & fifo_valid_out) begin
        credit_only_packet_incoming = incoming_hdr.is_credits_only;
        cred_count_for_cred_only    = incoming_hdr.amount_of_credits;
        // make sure the credit only packet is consumed here and not forwarded...
        if (credit_only_packet_incoming) begin
          fifo_ready_out = 1;
          flow_control_fifo_valid_out = 0;
        end
      end
    end
  end else begin : credit_only_control
    always_comb begin
      fifo_ready_out = flow_control_fifo_ready_out;
      cred_count_for_cred_only    = 0;
      credit_only_packet_incoming = 0;
      flow_control_fifo_valid_out = fifo_valid_out;
    end
  end

  // TODO: where should I place these two line?
  assign consume_incoming_credits = (credit_only_packet_incoming | first_hs[0]);
  assign credits_incoming =
         (credit_only_packet_incoming) ? cred_count_for_cred_only : received_hdr.amount_of_credits;

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
    .valid_o    ( fifo_valid_out                ),
    .ready_i    ( fifo_ready_out                )
  );

  for (genvar i = 0; i < MaxPossibleTransferSplits; i++) begin : gen_recv_reg

    if (PackSmallerMsgIntoSingleTransfer) begin : gen_recv_reg_type
      assign last_blocks[i]  = (i<MaxPossibleTransferSplits-1) ? recv_reg_data[i+1] : '0;
      localparam bit UseHdr  = (i==0) ? 1 : 0;
      assign shift_enable[i] = (i==0) ? 1 : shifts_allowed[i-1];

      dequeue_shift_register #(
        .data_block_t ( data_block_t    ),
        .data_i_t     ( phy_data_chan_t ),
        .header_t     ( data_hdr_info_t ),
        .UseHeader    ( UseHdr          ),
        .UseShiftedBlockBit ( 1'b1      )
      ) i_recv_reg (
        .clk_i        ( clk_i                      ),
        .rst_ni       ( rst_ni                     ),
        .shift_en_i   ( shift_enable[i]            ),
        .new_packet_i ( last_blocks[i]             ),
        .valid_i      ( recv_reg_in_valid[i]       ),
        .ready_o      ( recv_reg_in_ready[i]       ),
        .data_i       ( flow_control_fifo_data_out ),
        .valid_o      ( recv_reg_out_valid[i]      ),
        .cont_data_o  ( recv_reg_contains_data[i]  ),
        .ready_i      ( recv_reg_out_ready[i]      ),
        .data_o       ( recv_reg_data[i]           ),
        .first_hs_o   ( first_hs[i]                ),
        .header_o     (                            ),
        .shift_en_o   ( shifts_allowed[i]          )
      );
    end else begin : gen_recv_reg_type
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

      assign first_hs[i] = recv_reg_out_valid[i] & recv_reg_out_ready[i];
      assign recv_reg_contains_data[i] = recv_reg_out_valid[i];
    end

  end

  //extract packet info from recv_reg_data
  assign {axis_packet_out, received_hdr} = recv_reg_data;
  assign axis_out_req_unfiltered.t.user  = axis_packet_out.user_bits;
  assign pre_received_hdr = flow_control_fifo_data_out;

  assign axis_out_req_unfiltered.t.data = axis_packet_out.data_bits;

  // Credit only packets should not be forwarded as they do not contain valid data
  // NOTE: If AllowVarAxisLen is enabled, credit only packets are filtered out before already
  always_comb begin
    axis_out_req_o.tvalid = (credits_only_packet_in == 1) ? 0 : axis_out_req_unfiltered.tvalid;
    axis_out_req_o.t.data = axis_out_req_unfiltered.t.data;
    axis_out_req_o.t.user = axis_out_req_unfiltered.t.user;
    // make the credit only packet disappear (consume it)
    axis_out_rsp_unfiltered.tready = axis_out_rsp_i.tready || (credits_only_packet_in == 1);
  end

  initial begin
    $display("INFO: data_link_hdr = %0d, BandWidth = %0d", $bits(received_hdr), BandWidth);
    $display("INFO: AllowVarAxisLen = %0d", AllowVarAxisLen);
    // $stop();
  end

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
      if (recv_reg_out_valid[0] && recv_reg_contains_data[received_hdr.req_num_splits-1]) begin
        axis_out_req_unfiltered.tvalid = recv_reg_out_valid[0];
      end

      recv_reg_out_ready =
      {MaxPossibleTransferSplits{axis_out_rsp_unfiltered.tready & axis_out_req_unfiltered.tvalid}};

      // If all inputs of each channel have valid data, push it to fifo
      flow_control_fifo_valid_in = &data_in_valid_i;
      data_in_ready_o  = {NumChannels{flow_control_fifo_valid_in & flow_control_fifo_ready_in}};
      output_handshake = axis_out_rsp_unfiltered.tready & axis_out_req_unfiltered.tvalid;
      if (flow_control_fifo_valid_out & recv_reg_in_ready[recv_reg_index_q]) begin
        recv_reg_in_valid[recv_reg_index_q] = 1'b1;
        flow_control_fifo_ready_out = 1'b1;
        // Increment recv reg counter (if I have a valid handshake at the output, consuming the
        // data in the stream_registers, while a new packet is being shifted in, the new header is
        // accessible from the pre_received_hdr and not from the received_hdr)
        if (recv_reg_out_valid[0] & !output_handshake) begin
          // The header info is received and savely stored in the first stream_register
          recv_reg_index_d =
          (recv_reg_index_q == received_hdr.req_num_splits - 1) ? 0 : recv_reg_index_q + 1;
        end else begin
          // The valid header info has not yet passed to the register and is only available in the
          // pre_register stage
          recv_reg_index_d =
          (recv_reg_index_q == pre_received_hdr.req_num_splits - 1) ? 0 : recv_reg_index_q + 1;
        end
      end
    end
  end

  `FF(recv_reg_index_q, recv_reg_index_d, '0)


  ////////////////////
  //   ASSERTIONS   //
  ////////////////////

  `ASSERT_INIT(RawModeFifoDim, RecvFifoDepth >= RawModeFifoDepth)
  // Bandwidth must be large enough to support the packet-header
  // to be sent in the first split of a physical transfer.
  `ASSERT_INIT(BandWidthTooSmall, BandWidth >= $bits(data_hdr_info_t))
  // It is assumed that no valid data can be inputed with a zero strobe (when AllowVarAxisLen
  // is enabled). Should this feature be desired, the port empty_o of the instance
  // i_leading_zero_counter should be utilized to declare what ought to happen in this case.
  `ASSERT(ZeroStrobe, !(AllowVarAxisLen & axis_in_req_i.t.strb == '0 &
    axis_in_req_i.tvalid & axis_in_rsp_o.tready))

endmodule
