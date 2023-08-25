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


module enqueue_register
import serial_link_pkg::*;
#(
    parameter  int  clk_div                    = 1,
    parameter  type split_cntr_t               = logic,
    parameter  bit  AllowVarAxisLen            = 1'b0,
    parameter  int  MaxPossibleTransferSplits  = 0,
    parameter  type data_in_t                  = logic,
    parameter  type strb_t                     = logic,
    parameter  int  BandWidth                  = 1,
    parameter  int  MaxNumOfBitsToBeTransfered = 1,

    // Represents the number of blocks for the whole data-stream.
    // However, only the first clk_div blocks are relevant for data-flow control.
    localparam int  num_blocks  = clk_div * MaxPossibleTransferSplits,
    localparam int  StrbSize    = $bits(strb_t),
    localparam type data_out_t  = logic[$bits(data_in_t)+num_blocks-1:0],

    localparam int  output_size = $bits(data_out_t),
    localparam int  block_size  = (output_size + num_blocks - 1) / num_blocks,
    localparam type block_in_t  = logic [block_size-2:0],
    localparam type block_out_t = logic [block_size-1:0]
) (
    input  logic      clk_i,    // Clock
    input  logic      rst_ni,   // Asynchronous active-low reset

    input  logic      valid_i,
    output logic      ready_o,
    input  data_in_t  data_i,   // TODO
    input  strb_t     strb_i,
    input  logic      send_hdr_is_credits_only,

    output logic      valid_o,
    input  logic      ready_i,
    // The output port will be wider than the input stream, since block bits are added.
    output data_out_t data_o,

    output split_cntr_t send_hdr_req_num_splits,
    output logic [$clog2(MaxNumOfBitsToBeTransfered+1)-1:0] remainingBitsToBeSent,
    output split_cntr_t requiredSplits
);

  block_in_t  [num_blocks-1:0] data_in_blocks;
  block_out_t [num_blocks-1:0] data_out_blocks;

  strb_t strb_o;

  // TODO: insert stream_register in-between
  assign valid_o        = valid_i;
  assign ready_o        = ready_i;
  assign data_in_blocks = data_i;

  for (genvar i = 0; i < num_blocks; i++) begin
    localparam bit is_start_block = (i==0) ? 1 : 0;
    assign data_out_blocks[i] = {data_in_blocks[i], is_start_block};
  end
  assign data_o = data_out_blocks;
  assign strb_o = strb_i;

  split_cntr_t trailing_zero_counter;
  logic [MaxPossibleTransferSplits-1:0] splitSegmentsToBeSent;
  logic [$clog2(MaxNumOfBitsToBeTransfered+1)-1:0] remainingBitsForBitmask;
  logic [$clog2(StrbSize+1)-1:0] numLeadZero;
  logic all_zeros;

  if (AllowVarAxisLen) begin : splitDetermination

    lzc #(
      .WIDTH ( StrbSize ),
      .MODE  ( 1'b1                )
    ) i_leading_zero_counter (
    // TODO: or do I need the input strobe?
      .in_i    ( strb_o      ),
      .cnt_o   ( numLeadZero ),
      .empty_o (             )
    );

    // alternative implementation to the cealing division.
    for (genvar i = 0; i < MaxPossibleTransferSplits; i++) begin
      assign splitSegmentsToBeSent[i] = remainingBitsForBitmask <= (i*BandWidth);
    end

    // For synthesis: make the port and connection width match...
    localparam int cnt_o_port_width = cf_math_pkg::idx_width(MaxPossibleTransferSplits);
    logic [cnt_o_port_width-1:0] numTrailingZeros;
    assign trailing_zero_counter = numTrailingZeros;

    lzc #(
      .WIDTH ( MaxPossibleTransferSplits ),
      .MODE  ( 1'b0                      )
    ) i_trailing_zero_counter (
      .in_i    ( splitSegmentsToBeSent ),
      .cnt_o   ( numTrailingZeros      ),
      .empty_o ( all_zeros             )
    );

    // lzc module does not output the correct amount of trailing zeroes when the entire input consists of zeroes only.
    assign requiredSplits = ((all_zeros) ? MaxPossibleTransferSplits : trailing_zero_counter);
    // moreover, a credit_only packet will require only 1 split (resulting number needs to be adjusted).
    assign send_hdr_req_num_splits =  (send_hdr_is_credits_only) ? 'd1 : requiredSplits;

    assign remainingBitsForBitmask = (MaxNumOfBitsToBeTransfered - {numLeadZero,3'b0});
    // Assigning the remainingBitsToBeSent to 1 in case of credits_only is not the correct number, but works nonetheless.
    // It is only important to have a low number, such that only one sending split will require. (TODO: do this or the data_out
    // limit comparison with the multiplication? Compare to TODO: alternativeApproachWithMultiplication)
    assign remainingBitsToBeSent   = (send_hdr_is_credits_only) ? 'd1 : remainingBitsForBitmask;

  end else begin
    assign send_hdr_req_num_splits = MaxPossibleTransferSplits;
    assign remainingBitsForBitmask = MaxNumOfBitsToBeTransfered;
    assign remainingBitsToBeSent   = remainingBitsForBitmask;
    assign requiredSplits          = MaxPossibleTransferSplits;
  end

endmodule
