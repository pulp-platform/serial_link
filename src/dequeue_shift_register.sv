// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Yannick Baumann <baumanny@student.ethz.ch>

`include "common_cells/registers.svh"
`include "common_cells/assertions.svh"

////////////////////////Input pattern example/////////////////////
/*

  |dddddd?|dddddd?|dddddd?|dddddd?|dddddd?|dddddd?|dddddd?|dddddd?|
   block_1 block_2 block_3 block_4 block_5 block_6 block_7 block_8

  d := data_bytes
  ? := interleaved msg start bit (indicates the beginning of a msg)

  NOTE: while the start bit (?) will be included in the input stream,
         the output stream will remove the interleaved bits.

*/
/////////////////////////End of the example/////////////////////////


module dequeue_shift_register
import serial_link_pkg::*;
#(
  parameter  type data_i_t     = logic, // contains block control bits
  // Leads to an offset in the block control bit. The header_o outputs the data header.
  parameter  type header_t     = logic,
  // If set to one, the last header-size bits of data_o are replaced with the transfer header.
  parameter  bit  UseHeader    = 0,
  // Remove the header-bits from the output-stream
  parameter  bit  UseShiftedBlockBit = UseHeader,

  parameter  type data_block_t = logic,
  localparam int  BlockSize    = $bits(data_block_t),
  localparam int  NumBlocks    = ($bits(data_i_t) + BlockSize - 1) / BlockSize,

  localparam type data_o_t     = logic[$bits(data_i_t)-NumBlocks-1:0], // no control bits anymore.

  localparam int  NumHdrBits   = (UseShiftedBlockBit) ? $bits(header_t) : 0,
  localparam type block_in_t   = logic [BlockSize-1:0],
  localparam type block_out_t  = logic [BlockSize-2:0],
  localparam type block_cntr_t = logic [$clog2(NumBlocks)-1:0],
  localparam int  BitRemovalIndex = (UseShiftedBlockBit) ? $bits(header_t) : 0
) (
    input  logic      clk_i,      // Clock
    input  logic      rst_ni,     // Asynchronous active-low reset
    input  logic      shift_en_i, // enable or disable the operation
    input  block_in_t new_packet_i, // new input value to be shifted into the front position
    // Input port
    input  logic      valid_i,
    output logic      ready_o,
    input  data_i_t   data_i, // The data input has 1 interleaved bit per sub-split in the LSB pos.
    // Output port
    output logic      valid_o,
    input  logic      ready_i,
    output data_o_t   data_o,

    // This port is HIGH whenever new data is loaded, until the data is being
    // consumed again. Opposed to valid_o, it does not represent whether or not
    // the data_o outputs a valid data output stream.
    output logic      cont_data_o,
    // HIGH if the first output handshake of the current data-element occurs.
    output logic      shift_en_o,
    // Is HIGH if the current output handshake is the first output handshake for the currently
    // received data-stream.
    output logic      first_hs_o,
    output header_t   header_o
);

    logic        contains_valid_data, load_new_data, all_data_consumed;
    logic        valid_shift_pos, first_outstanding_q, first_outstanding_d;
    block_in_t   [NumBlocks-1:0] data_in_blocks, data_in, data_out;
    block_out_t  [NumBlocks-1:0] data_out_blocks;
    block_cntr_t block_idx_q, block_idx_d;
    data_o_t     data_out_flattened;
    logic        block_start_bit;

    assign cont_data_o     = contains_valid_data;
    assign ready_o         = all_data_consumed | ~contains_valid_data;
    assign load_new_data   = valid_i & ready_o;
    assign block_start_bit = data_out[0][NumHdrBits];
    assign valid_shift_pos = block_start_bit & contains_valid_data;
    assign valid_o         = contains_valid_data & valid_shift_pos;
    assign shift_en_o      =
           ~load_new_data & (ready_i | ~valid_shift_pos) & shift_en_i & contains_valid_data;
    assign first_hs_o      = valid_o & ready_i & first_outstanding_q;


    always_comb begin : find_first_transaction
      first_outstanding_d = first_outstanding_q;
      if (valid_o & ready_i) begin
        first_outstanding_d = 0;
      end
      if (load_new_data) begin
        first_outstanding_d = 1;
      end
    end

    always_comb begin : assemble_data_o
      // remove the interleaved start bits from the data-stream
      data_o = data_out_flattened;
      if (UseHeader) begin
        data_o = {data_out_flattened[$bits(data_o_t)-1:NumHdrBits], header_o};
      end
    end

    always_comb begin : data_consumption_checker
      block_idx_d = block_idx_q;
      all_data_consumed = 0;
      if (shift_en_o) begin
        block_idx_d = block_idx_q + 1;
      end
      if (load_new_data) begin
        block_idx_d = '0;
      end
      if (block_idx_q == (NumBlocks - 1)) begin
        if (valid_shift_pos) begin
          all_data_consumed = ready_i;
        end else begin
          all_data_consumed = 1;
        end
      end
    end

    assign data_in_blocks = data_i;

    for (genvar i = 0; i < NumBlocks; i++) begin : gen_load_or_shift_data
      // assign inputs of the FFs
      always_comb begin
        data_in[i] = data_out[i];
        if (shift_en_o) begin
          if (i == NumBlocks - 1) begin
            data_in[i] = new_packet_i;
          end else begin
            data_in[i] = data_out[i+1];
          end
        end

        if (load_new_data) begin
          data_in[i] = data_in_blocks[i];
        end
      end

      if (BitRemovalIndex==0) begin : gen_remove_block_ctrl_bit
        assign data_out_blocks[i] = data_out[i][BlockSize-1:1];
      end else if (BitRemovalIndex==BlockSize) begin : gen_remove_block_ctrl_bit
        assign data_out_blocks[i] = data_out[i][BlockSize-2:0];
      end else begin : gen_remove_block_ctrl_bit
        assign data_out_blocks[i] =
               {data_out[i][BlockSize-1:BitRemovalIndex+1], data_out[i][BitRemovalIndex-1:0]};
      end

      `FF(data_out[i], data_in[i], '0)
    end

    assign data_out_flattened = data_out_blocks;

    `FFL(contains_valid_data, valid_i, ready_o, 1'b0, clk_i, rst_ni)
    `FF(block_idx_q, block_idx_d, '0)
    `FF(first_outstanding_q, first_outstanding_d, 1)

    if (UseHeader) begin : gen_use_hdr
      `FFL(header_o, data_i, load_new_data, 1'b0, clk_i, rst_ni)
    end else begin : gen_use_hdr
      assign header_o = '0;
    end

  ////////////////////
  //   ASSERTIONS   //
  ////////////////////

  `ASSERT(HdrTooBig, NumHdrBits<BlockSize)

endmodule
