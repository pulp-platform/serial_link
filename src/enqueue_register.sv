// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Yannick Baumann <baumanny@student.ethz.ch>

`include "common_cells/registers.svh"
`include "common_cells/assertions.svh"

///  This module can collect multiple smaller messages and wrap them
///  into one single physical transfer. The information on the size is
///  contained in the AXIS strobe signal, where each leading 1 indicates
///  an active/valid data byte.
///  The incoming messages are only collected and bundled together, as
///  long as no additional delay results from the performed operation.
///  The assumption is, that every output transaction requires ClkDiv
///  clock cycles to finish, leaving that many extra cycles for processing
///  incoming data, while waiting for the output to be ready again.
///
///  The output stream has control bits inserted. They are at the bit
///  position zero of each individual blocks. A value of one indicates
///  the start position of a message. This module is to be used in
///  combination with dequeue_shift_register.
module enqueue_register
  import serial_link_pkg::*;
#(
    // If parameter is set to 1, the input strobe will be considered to calculate the msg-size
    // Otherwise, the largest possible input message is assumed.
    parameter  bit  AllowVarAxisLen           = 1'b0,
    // sets the remaining wait cycles & the NumDatBlocks
    // DataBlocks: The input stream is separated into data-blocks. They mark fixed shift positions
    // which will be used to collect and shift input messages into the desired position.
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
    // Same as above, but only the first data packet features these additional bits.
    parameter  int  NumExternalBitsAddedFirst = 0,
    // The minimal number of strobe bits to be set (smallest possible message). Will be used to
    // calculate the number of blocks which are required to process the smallest possible message.
    parameter  int  NarrowStrbCount           = 1,
    // Dependent parameters, do not change!
    // Represents the number of blocks for the whole data-stream.
    // However, only the first ClkDiv blocks are relevant for data-flow control.
    localparam int  NumDatBlocks = ClkDiv * MaxPossibleTransferSplits,
    localparam int  StrbSize     = $bits(strb_t),
    localparam int  NumDatBitsIn = $bits(data_in_t),
    localparam type data_out_t   = logic[NumDatBitsIn+NumDatBlocks-1:0],

    localparam int  BlockSize   = $bits(data_block_t),
    // exclude the block control bits (they will be added to the output but are not
    // included in the input data stream)
    localparam type block_in_t   = logic [BlockSize-2:0],
    localparam type block_cntr_t = logic [$clog2(NumDatBlocks+1)-1:0],

    // TODO: remove the last parameter...
    localparam int  MinDataSize  =
                    8*NarrowStrbCount + NumExternalBitsAdded + NumExternalBitsAddedFirst,
    localparam int  MinReqBlocks = (MinDataSize + BlockSize - 2) / (BlockSize-1),
    // Find the number of required register blocks
    localparam int  NumRegBlocks = 2*ClkDiv - 2*MinReqBlocks
) (
    input  logic        clk_i,
    input  logic        rst_ni,

    input  logic        valid_i,
    output logic        ready_o,
    input  data_in_t    data_i,
    input  strb_t       strb_i,

    output logic        valid_o,
    input  logic        ready_i,
    output data_out_t   data_o,  // block control bits will be insterted into output stream.

    output split_cntr_t num_splits_o
);


  ///////////////////////////////////
  //  SIGNAL AND TYPE DECLARATION  //
  ///////////////////////////////////

  // The output block also contains the block control bits which are insterted
  typedef struct packed {
    block_in_t data;
    logic block_ctrl_bit;
  } block_out_t;

  block_in_t  [NumDatBlocks-1:0] data_in_blocks;
  block_out_t [NumDatBlocks-1:0] data_with_ctrl_bits;
  block_out_t [NumRegBlocks-1:0] reg_blocks_d;
  block_out_t [NumRegBlocks-1:0] reg_blocks_q;
  block_out_t [NumDatBlocks-1:0] data_out_blocks;
  data_out_t                     data_out;

  localparam int CntLength = $clog2(ClkDiv);

  logic [CntLength-1:0] cycle_delay_q, cycle_delay_d;
  split_cntr_t          splits_by_data_in, num_splits_reg_in;
  block_cntr_t          utilized_blocks, required_blocks;
  block_cntr_t          occupied_blocks_q, occupied_blocks_d;
  block_cntr_t          remaining_shifts_q, remaining_shifts_d;
  logic                 allow_new_out_transac, msg_bypass, shift_shift_regs;
  logic                 valid_data_into_reg, can_receive_new_data;
  logic                 no_ongoing_shift, no_lat_introduced, enough_time_left;
  logic                 valid_reg_in, ready_reg_in, contains_valid_data;
  logic                 valid_reg_data, acceptable_size, accept_next_block, is_first_element;
  logic                 allow_shifts, shift_in_progress, shift_for_no_lat, empty_shift_pos;


  ////////////////////////////
  //  FIND REQUIRED BLOCKS  //
  ////////////////////////////

  find_req_blocks #(
    .ClkDiv                    ( ClkDiv                    ),
    .StrbSize                  ( StrbSize                  ),
    .MaxPossibleTransferSplits ( MaxPossibleTransferSplits ),
    .NumExternalBitsAddedFirst ( NumExternalBitsAddedFirst ),
    .NumExternalBitsAdded      ( NumExternalBitsAdded      ),
    .block_cntr_t              ( block_cntr_t              ),
    .AllowVarAxisLen           ( AllowVarAxisLen           ),
    .BlockSize                 ( BlockSize                 )
  ) i_block_counter (
    .use_first_externals_i ( is_first_element | (valid_i & ~contains_valid_data)),
    .strb_i                ( strb_i           ),
    .required_blocks_o     ( required_blocks  )
  );


  //////////////////////////
  //  SIGNAL ASSIGNMENTS  //
  //////////////////////////

  assign num_splits_reg_in    = (utilized_blocks + ClkDiv - 1)/ClkDiv;
  assign valid_data_into_reg  = valid_reg_data & ~msg_bypass;
  assign can_receive_new_data = ready_o | (valid_reg_in & ready_reg_in);

  `FFL(contains_valid_data, valid_reg_data, can_receive_new_data, 1'b0, clk_i, rst_ni)

  assign msg_bypass      = ~(contains_valid_data | valid_reg_data);
  assign utilized_blocks = (msg_bypass) ? required_blocks : occupied_blocks_q;
  assign ready_o         = (msg_bypass) ? ready_reg_in : (valid_reg_data | ~contains_valid_data);
  assign valid_reg_in    = (msg_bypass) ? valid_i : (contains_valid_data & allow_new_out_transac);

  // The number of shifts required to shift an element from the input to the last shift-position.
  localparam int ShiftDepth = ClkDiv - MinReqBlocks;

  logic [CntLength:0] block_cycl_sum;
  assign block_cycl_sum = cycle_delay_q + occupied_blocks_q;

  // Is the incoming data size small enough to fit at least 2
  assign acceptable_size   = required_blocks <= ShiftDepth;
  // I should not have an ongoing (un-terminated) shiftoperation
  // no_ongoing_shift  = remaining_shifts_q <= 1;
  assign no_ongoing_shift  = (remaining_shifts_q == 'd1 & allow_shifts) | remaining_shifts_q == '0;
  // Is a delayless shift insertion possible?
  assign no_lat_introduced = ShiftDepth < block_cycl_sum;
  // Am I in a delay phase (output not yet ready) and I have sufficient time to
  // shift the input message into the out_block section )
  assign enough_time_left  = required_blocks < cycle_delay_q + MinReqBlocks;
  // Combination of above signals to evaluate if I am able to receive new blocks
  assign accept_next_block =
         no_ongoing_shift & no_lat_introduced & enough_time_left &
         (occupied_blocks_q + required_blocks <= ClkDiv);
  // shift_register it emptied, resulting in the new incoming element to be the first in the reg.
  assign is_first_element  = contains_valid_data & allow_new_out_transac & ready_reg_in;

  // The data block has not yet moved out of the input-intersecting region.
  assign shift_in_progress = remaining_shifts_q != 0;
  // I need to shift in order to not introduce latency. (No more shift delaying allowed)
  assign shift_for_no_lat  = contains_valid_data & (ShiftDepth+remaining_shifts_q>=block_cycl_sum);
  // I still have free shift positions: Shifting further will not result in loosing data-blocks
  assign empty_shift_pos   = occupied_blocks_q - remaining_shifts_q < ShiftDepth;

  // If the input data is valid and has an acceptable size, it may be consumed,
  // given it does not conflict with existing data and can be fully shifted
  // into position within the given delay_cycle time.
  assign valid_reg_data = valid_i & acceptable_size & (accept_next_block | is_first_element);
  // Declares if the register chain is allowed to right-shift the data blocks by another position
  assign allow_shifts   = (shift_in_progress | shift_for_no_lat) & empty_shift_pos;


  /////////////////////////////////////
  //  COLLECT AND SEND DATA PACKETS  //
  /////////////////////////////////////

  // Insertion of block-control-bits into the data stream
  assign data_in_blocks = data_i;
  for (genvar i = 0; i < NumDatBlocks; i++) begin : gen_insert_block_ctrl_bit
    localparam bit BlockCtrlBit   = (i==0) ? 1'b1 : 1'b0;
    assign data_with_ctrl_bits[i] = {data_in_blocks[i], BlockCtrlBit};
  end

  // Assign input data or register content to the output
  for (genvar i = 0; i < NumDatBlocks; i++) begin : gen_assign_data_output
    if (i < ClkDiv) begin : gen_block_type
      assign data_out_blocks[i] = (msg_bypass) ? data_with_ctrl_bits[i] : reg_blocks_q[i];
    end else begin : gen_block_type
      assign data_out_blocks[i] = data_with_ctrl_bits[i];
    end
  end


  /////////////////////////
  //  INTERNAL COUNTERS  //
  /////////////////////////

  always_comb begin : total_num_occupied_blocks
    occupied_blocks_d  = occupied_blocks_q;
    if ( valid_data_into_reg ) begin
      occupied_blocks_d = occupied_blocks_q + required_blocks;
    end
    // When I force shift, I occupie another block with an empty block element.
    if (~shift_in_progress & shift_for_no_lat) begin
      occupied_blocks_d = occupied_blocks_q + 1;
    end
    if ( valid_reg_in & ready_reg_in ) begin
      if ( valid_i & ready_o & ~msg_bypass ) begin
        occupied_blocks_d = required_blocks;
      end else begin
        occupied_blocks_d = '0;
      end
    end
  end
  `FF(occupied_blocks_q, occupied_blocks_d, '0)

  always_comb begin : available_space
    remaining_shifts_d = remaining_shifts_q - allow_shifts;
    if ( valid_data_into_reg ) begin
      remaining_shifts_d = required_blocks;
    end else if (remaining_shifts_q == 0 | ~empty_shift_pos) begin
      remaining_shifts_d = 0;
    end
  end
  `FF(remaining_shifts_q, remaining_shifts_d, '0)

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
  `FF(cycle_delay_q, cycle_delay_d, '0)


  ///////////////////////
  //  SHIFT REGISTERS  //
  ///////////////////////

  for (genvar i = 0; i < NumRegBlocks; i++) begin : gen_load_and_shift_register
    if (i < ShiftDepth) begin : gen_register_type
      assign reg_blocks_d[i] = reg_blocks_q[i + 1];
      `FFL(reg_blocks_q[i], reg_blocks_d[i], allow_shifts, '0, clk_i, rst_ni)
    end else begin : gen_register_type
      if (i == NumRegBlocks - 1) begin : gen_assign_reg_block
        // The first register block has no other register block to
        // read the data from when in shift mode.
        assign reg_blocks_d[i] = (valid_data_into_reg) ? data_with_ctrl_bits[i - ShiftDepth] : '0;
      end else begin : gen_assign_reg_block
        assign reg_blocks_d[i] =
               (valid_data_into_reg) ? data_with_ctrl_bits[i - ShiftDepth] : reg_blocks_q[i + 1];
      end
      `FFL(reg_blocks_q[i], reg_blocks_d[i], (valid_data_into_reg|allow_shifts), '0, clk_i, rst_ni)
    end
  end


  ////////////////////////////
  //  DATA OUTPUT REGISTER  //
  ////////////////////////////

  localparam int  StrRegWdt   = $bits(data_out_t) + $bits(split_cntr_t);
  localparam type dat_and_spl_t = logic [StrRegWdt-1:0];

  // suppress size missmatch warning...
  assign data_out = data_out_blocks;

  // Hold the created output for ClkDiv consequtive cycles.
  // It's a necessity to ensure the signal can fully propagate through the slower (physical) link.
  stream_register #(
    .T ( dat_and_spl_t )
  ) i_data_sampler (
    .clk_i      (  clk_i                        ),
    .rst_ni     (  rst_ni                       ),
    .clr_i      (  1'b0                         ),
    .testmode_i (  1'b0                         ),
    .valid_i    (  valid_reg_in                 ),
    .ready_o    (  ready_reg_in                 ),
    .data_i     ( {data_out, num_splits_reg_in} ),
    .valid_o    (  valid_o                      ),
    .ready_i    (  ready_i                      ),
    .data_o     ( {data_o, num_splits_o}        )
  );

endmodule


module find_req_blocks #(
  parameter  bit  AllowVarAxisLen           = 1'b0,
  parameter  int  ClkDiv                    = 1,
  parameter  int  StrbSize                  = 1,
  parameter  type block_cntr_t              = logic,
  parameter  int  MaxPossibleTransferSplits = 1,
  parameter  int  NumExternalBitsAdded      = 0,
  parameter  int  NumExternalBitsAddedFirst = 0,

  parameter  int  BlockSize                 = 2,
  localparam int  TotalNumBlocks            = MaxPossibleTransferSplits*ClkDiv
) (
input  logic use_first_externals_i,
input  logic [StrbSize-1:0] strb_i,
output block_cntr_t         required_blocks_o
);

localparam int NumDataBits = $clog2(9*StrbSize+NumExternalBitsAdded+NumExternalBitsAddedFirst+1);
localparam int StrobeCounter = $clog2(StrbSize+1);

logic [NumDataBits-1:0]   required_bits;
logic [StrobeCounter-1:0] num_trailing_ones;

if (AllowVarAxisLen) begin : gen_split_determination
  logic all_ones;

  lzc #(
    .WIDTH ( StrbSize ),
    .MODE  ( 1'b0     )
  ) i_trailing_ones_counter (
    .in_i    ( ~strb_i           ),
    .cnt_o   ( num_trailing_ones ),
    .empty_o ( all_ones          )
  );

  // One set strobe bit corresponds to 8 bits (1 byte) of data.
  assign required_bits = (use_first_externals_i) ?
                       (8*num_trailing_ones + NumExternalBitsAdded + NumExternalBitsAddedFirst) :
                       (8*num_trailing_ones + NumExternalBitsAdded);
  // When input strobe is fully '1, all blocks are occupied. The condition is needed to ensure
  // the max is not exceeded, which could happen when the front most data byte is not a full byte
  // (not all bits are required). This would lead to a mismatch in the determined MaxNumSplits
  // opposed to the optained number by comparing the block count.
  assign required_blocks_o =
         (all_ones) ? block_cntr_t'(TotalNumBlocks) : (required_bits+BlockSize-2)/(BlockSize-1);
end else begin : gen_split_determination
  assign required_blocks_o = block_cntr_t'(TotalNumBlocks);
end

endmodule
