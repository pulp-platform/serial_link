// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Yannick Baumann <baumanny@student.ethz.ch>

`include "common_cells/registers.svh"
`include "common_cells/assertions.svh"

////////////////////////Input pattern example/////////////////////
/*

  TODO: add a comment

*/
/////////////////////////End of the example/////////////////////////


module find_req_blocks #(
    parameter  bit  AllowVarAxisLen           = 1'b0,
    parameter  int  ClkDiv                   = 1,
    parameter  int  StrbSize                  = 1,
    parameter  type block_cntr_t              = logic,
    parameter  int  MaxPossibleTransferSplits = 1,
    parameter  int  NumExternalBitsAdded      = 0,

    parameter  int  BlockSize                 = 2,
    localparam int  TotalNumBlocks            = MaxPossibleTransferSplits*ClkDiv
) (
  input  logic [StrbSize-1:0] strb_i,
  output block_cntr_t         required_blocks_o
);

  block_cntr_t trailing_zero_counter;
  logic [TotalNumBlocks-1:0] splitSegmentsToBeSent;
  logic [$clog2(9*StrbSize + NumExternalBitsAdded + 1)-1:0] remainingBitsForBitmask;
  logic [$clog2(StrbSize+1)-1:0] numLeadZero;
  logic all_zeros;

  if (AllowVarAxisLen) begin : splitDetermination

    logic all_ones;

    lzc #(
      .WIDTH ( StrbSize ),
      .MODE  ( 1'b0                )
    ) i_trailing_ones_counter (
      .in_i    ( ~strb_i     ),
      .cnt_o   ( numLeadZero ),
      .empty_o ( all_ones    )
    );

    // One set strobe bit corresponds to 8 bits (1 byte) of data.
    assign remainingBitsForBitmask = {numLeadZero,3'b0} + NumExternalBitsAdded;
    // When input strobe is fully '1, all blocks are occupied. The condition is needed to ensure the max is not exceeded,
    // which could happen when the front most date byte is not a full byte (not all bits are required). This would lead
    // to a mismatch in the determined MaxNumSplits opposed to the optained number by comparing the block count.
    assign required_blocks_o = (all_ones) ? TotalNumBlocks : (remainingBitsForBitmask + BlockSize - 2) / (BlockSize-1);
  end else begin
    assign required_blocks_o = TotalNumBlocks;
  end

endmodule


module enqueue_register
import serial_link_pkg::*;
#(
// TODO: adjust descriptions
    // If parameter is set to 1, the input strobe will be considered to calculate the msg-size
    parameter  bit  AllowVarAxisLen           = 1'b0,
    // sets the remaining wait cycles & the NumDatBlocks
    parameter  int  ClkDiv                    = 1,
    // size of the data_block_t should also include the block control bit
    parameter  type data_block_t              = logic,
    parameter  type data_in_t                 = logic,
    parameter  type strb_t                    = logic,
    parameter  type split_cntr_t              = logic,
    parameter  int  MaxPossibleTransferSplits = 1,
    // Additional number of bits which might be added externally to the output stream,
    // resulting in an increased transfer size. INFO: If the input data stream contains
    // data whose size is not correlating with the strobe signal, I might add the offset
    // here as well. Eg. axis user bits
    parameter  int  NumExternalBitsAdded      = 0,
    // The minimal number of strobe bits to be set (smallest possible message). Will be used to
    // calculate the number of blocks which are required to process the smallest possible message.
    parameter  int  NarrowStrbCount           = 1,


    ///////////////////////////////////////////
    //  DEPENDANT PARAMETER - DO NOT CHANGE  //
    ///////////////////////////////////////////

    // Represents the number of blocks for the whole data-stream.
    // However, only the first ClkDiv blocks are relevant for data-flow control.
    localparam int  NumDatBlocks = ClkDiv * MaxPossibleTransferSplits,
    localparam int  StrbSize     = $bits(strb_t),
    localparam type data_out_t   = logic[$bits(data_in_t)+NumDatBlocks-1:0],

    localparam int  BlockSize   = $bits(data_block_t),
    localparam type block_in_t   = logic [BlockSize-2:0],
    localparam type block_cntr_t = logic [$clog2(NumDatBlocks+1)-1:0],

    localparam int  MinDataSize  = 8*NarrowStrbCount + NumExternalBitsAdded,
    localparam int  MinReqBlocks = (MinDataSize + BlockSize - 2) / (BlockSize-1),
    // TODO: add an explanation on how the value is calculated. (compare with Xournall++ sketch)
    localparam int  NumRegBlocks = 2*ClkDiv - 2*MinReqBlocks
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        clr_i,

    input  logic        valid_i,
    output logic        ready_o,
    input  data_in_t    data_i,
    input  strb_t       strb_i,

    output logic        valid_o,
    input  logic        ready_i,
    output data_out_t   data_o,  // block control bits will be insterted into output stream.

    output split_cntr_t num_splits_o
);

  // The output block also contains the block control bits which are insterted
  typedef struct packed {
    block_in_t data;
    logic block_ctrl_bit;
  } block_out_t;

  localparam int cnt_length = $clog2(ClkDiv);

  block_in_t  [NumDatBlocks-1:0] data_in_blocks;
  block_out_t [NumDatBlocks-1:0] data_with_ctrl_bits;
  block_out_t [NumRegBlocks-1:0] reg_blocks_d;
  block_out_t [NumRegBlocks-1:0] reg_blocks_q;
  block_out_t [NumDatBlocks-1:0] data_out_blocks;

  logic [cnt_length-1:0] cycle_delay_q, cycle_delay_d;
  logic                  allow_new_out_transac;
  logic                  valid_reg_data;
  logic                  contains_valid_data;
  logic                  msg_bypass;
  logic                  shift_shift_regs;
  split_cntr_t           splits_by_data_in;
  split_cntr_t           num_splits_reg_in;
  block_cntr_t           utilized_blocks;
  block_cntr_t           required_blocks;
  block_cntr_t           occupied_blocks_q, occupied_blocks_d;
  block_cntr_t           remaining_shifts_q, remaining_shifts_d;
  logic                  valid_reg_in, ready_reg_in;
  logic                  valid_data_into_reg;
  logic                  allow_shifts;

  localparam int  str_reg_wdt   = $bits(data_out_t) + $bits(split_cntr_t);
  localparam type dat_and_spl_t = logic [str_reg_wdt-1:0];

  stream_register #(
    .T ( dat_and_spl_t )
  ) i_data_sampler (
    .clk_i      (  clk_i                                                ),
    .rst_ni     (  rst_ni                                               ),
    .clr_i      (  1'b0                                                 ),
    .testmode_i (  1'b0                                                 ),
    .valid_i    (  valid_reg_in                                 ),
    .ready_o    (  ready_reg_in                                   ),
    .data_i     ( {data_out_blocks, num_splits_reg_in}  ),
    .valid_o    (  valid_o                                       ),
    .ready_i    (  ready_i                                       ),
    .data_o     ( {data_o,    num_splits_o} )
  );

  assign num_splits_reg_in = (utilized_blocks + ClkDiv - 1)/ClkDiv;

  // always_ff @(posedge clk_i or negedge rst_ni) begin
  //   if(valid_reg_in & ready_reg_in) begin
  //     $display("INFO: strb = %76b, splits = %2d", strb_i, num_splits_o);
  //     $display("INFO: occupied_blocks = %3d", occupied_blocks_d);
  //     $error("Simulation not actually started. Prevented by debug block...");
  //     $stop;
  //   end
  // end


  // TODO: add support to consume multiple data elements (as long as they fit)
  // assign data_o         = data_out_blocks;

  // TODO: place assignements into reasonable position in the code
  assign valid_data_into_reg = valid_reg_data & ~msg_bypass;
  // TODO: original line:
  // assign valid_data_into_reg = valid_i & ready_o & ~msg_bypass;
  assign utilized_blocks = (msg_bypass) ? required_blocks : occupied_blocks_q;
  //                 valid_data required ||| The incoming data size small enough to fit at least 2 |||   No shift is ongoing    ||| delayless shift insertion should be possible              ||| msg needs time to shift into out_block section  ||| When multiple elements can fit (size requirement) and register is emptiede, I know I can consume a new element
  assign valid_reg_data  = valid_i        & required_blocks <= (ClkDiv - MinReqBlocks)              & ((remaining_shifts_q <= 1  & ClkDiv - MinReqBlocks - occupied_blocks_q < cycle_delay_q & (required_blocks - MinReqBlocks) < cycle_delay_q) | (valid_reg_in & ready_reg_in & contains_valid_data));
  // assign valid_reg_data  = valid_i        & required_blocks <= (ClkDiv - MinReqBlocks)              & (required_blocks <= cycle_delay_q | (valid_reg_in & ready_reg_in & contains_valid_data));
  // TODO: I need to shift out when elements intersect with data_in line || start shifting, or latency is introduced                || When the last shift position is not yet reached.
  assign allow_shifts    = (remaining_shifts_q != 0 | ClkDiv - occupied_blocks_q + remaining_shifts_q >= cycle_delay_q + MinReqBlocks) & (occupied_blocks_q - remaining_shifts_q < ClkDiv - MinReqBlocks);
  // ClkDiv - occupied_blocks_q + remaining_shifts_q >= cycle_delay_q + MinReqBlocks


  always_comb begin : input_handshake_control
    // valid_i;
    // TODO: get rid of the conditional assignment (split up for increased readibility)
    // TODO: rewrite the condition...
    // When the register is emptied, I can receive new data (signal ready_o goes HIGH),
    // as long as the element is also suited to fit into the register.
    ready_o        = (msg_bypass) ? ready_reg_in : (valid_reg_data | ~contains_valid_data);
  end

  always_comb begin : output_handshake_control
    // TODO: create more readable version for the contains_valid_data extra condition...
    valid_reg_in        = (msg_bypass) ? valid_i : (contains_valid_data & allow_new_out_transac);
    // ready_reg_in;
  end

  // insert control bits into incoming data stream
  assign data_in_blocks = data_i;
  for (genvar i = 0; i < NumDatBlocks; i++) begin
    localparam bit BlockCtrlBit   = (i==0) ? 1'b1 : 1'b0;
    assign data_with_ctrl_bits[i] = {data_in_blocks[i], BlockCtrlBit};
  end

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  for (genvar i = 0; i < NumDatBlocks; i++) begin
    if (i < ClkDiv) begin
      // TODO: remove the current shift-load-mode offset
      assign data_out_blocks[i] = (msg_bypass) ? data_with_ctrl_bits[i] : reg_blocks_q[i];
    end else begin
      // assign non-shiftable part of the input stream to the output
      assign data_out_blocks[i] = data_with_ctrl_bits[i];
    end
  end
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  always_comb begin : total_num_occupied_blocks
    occupied_blocks_d  = occupied_blocks_q;
    if ( valid_data_into_reg ) begin
      occupied_blocks_d = occupied_blocks_q + required_blocks;
    end
    if ( valid_reg_in & ready_reg_in ) begin
      if ( valid_i & ready_o & ~msg_bypass ) begin
        occupied_blocks_d = required_blocks;
      end else begin
        occupied_blocks_d = '0;
      end
    end
  end

  always_comb begin : available_space
    remaining_shifts_d = remaining_shifts_q - 1;
    if ( valid_data_into_reg ) begin
      remaining_shifts_d = required_blocks;
    end else if (remaining_shifts_q == 0) begin
      remaining_shifts_d = 0;
    end
  end

  always_comb begin : delay_control
    allow_new_out_transac = 0;
    cycle_delay_d = cycle_delay_q;
    if ( cycle_delay_q != 0 ) begin
      cycle_delay_d = cycle_delay_q - 1;
    end else begin
      allow_new_out_transac = 1;
      if ( valid_reg_in & ready_reg_in ) begin
        cycle_delay_d = ClkDiv - 1;
      end
    end
  end



  find_req_blocks #(
    .ClkDiv                    ( ClkDiv                    ),
    .StrbSize                  ( StrbSize                  ),
    .NumExternalBitsAdded      ( NumExternalBitsAdded      ),
    .MaxPossibleTransferSplits ( MaxPossibleTransferSplits ),
    .block_cntr_t              ( block_cntr_t              ),
    .AllowVarAxisLen           ( AllowVarAxisLen           ),
    .BlockSize                 ( BlockSize                 )
  ) i_TODO_naming (
    .strb_i            ( strb_i          ),
    .required_blocks_o ( required_blocks )
  );


  // assign reg_ena = (cycle_delay_q != 0 & occupied_blocks_q < ClkDiv) | (valid_i&ready_o);

  for (genvar i = 0; i < NumRegBlocks; i++) begin : load_and_shift_register

    // always_comb begin
    //   if (i==ClkDiv-1) begin
    //     data_out_blocks_d[i] = '0;
    //   end else begin
    //     data_out_blocks_d[i] = data_out_blocks_q[i+1];
    //   end
    // end

    // TODO: change to a signal wire...
    localparam bit reg_clear = 1'b0;

    // TODO: add shift mode (the line below is the bypass mode)
    if (i < ClkDiv - MinReqBlocks) begin
      assign reg_blocks_d[i] = reg_blocks_q[i + 1];
      // TODO: adjust the enable condition...
      `FFLARNC(reg_blocks_q[i], reg_blocks_d[i], allow_shifts, reg_clear, '0, clk_i, rst_ni)
    end else begin
      if (i == NumRegBlocks - 1) begin
        assign reg_blocks_d[i] = (valid_data_into_reg) ? data_with_ctrl_bits[i - ClkDiv + MinReqBlocks] : '0;
      end else begin
        assign reg_blocks_d[i] = (valid_data_into_reg) ? data_with_ctrl_bits[i - ClkDiv + MinReqBlocks] : reg_blocks_q[i + 1];
      end
      // TODO: adjust the enable condition...
      `FFLARNC(reg_blocks_q[i], reg_blocks_d[i], (valid_data_into_reg | allow_shifts), reg_clear, '0, clk_i, rst_ni)
    end
  end

  // TODO: chose if I am in bypass mode or not...
  always_comb begin : mode_selection
    msg_bypass = ~(contains_valid_data | valid_reg_data);
  end

  `FF(remaining_shifts_q, remaining_shifts_d, '0)
  `FF(cycle_delay_q, cycle_delay_d, '0)
  // TODO: do sth with the condition for the enable port...
  `FFLARNC(contains_valid_data, valid_reg_data, ready_o | (valid_reg_in & ready_reg_in), clr_i, 1'b0, clk_i, rst_ni)
  `FFLARNC(occupied_blocks_q, occupied_blocks_d, 1'b1, clr_i, '0, clk_i, rst_ni)

endmodule
