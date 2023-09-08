// Copyright 2022 ETH Zurich and University of Bologna.
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
  parameter  type data_i_t     = logic, // TODO: description
  // TODO: Important parameter to set the header_o output to contain the header bit info which leads to a shift in the input data-stream.
  parameter  type header_t     = logic,
  parameter  bit  use_header   = 0,
  // TODO: remove the bits with a multiple of the header size as index from the stream
  parameter  bit  use_shifted_block_bit = use_header,

  parameter  type data_block_t = logic,
  localparam int  block_size   = $bits(data_block_t),
  localparam int  num_blocks   = ($bits(data_i_t) + block_size - 1) / block_size,

  localparam type data_o_t     = logic[$bits(data_i_t)-num_blocks-1:0], // TODO: description

  localparam int  num_hdr_bits = (use_shifted_block_bit) ? $bits(header_t) : 0,
  localparam type block_in_t   = logic [block_size-1:0],
  localparam type block_out_t  = logic [block_size-2:0],
  localparam type block_cntr_t = logic [$clog2(num_blocks)-1:0],
  localparam int  bit_removal_index = ( use_shifted_block_bit ) ? $bits(header_t) : 0
) (
    input  logic      clk_i,      // Clock
    input  logic      rst_ni,     // Asynchronous active-low reset
    input  logic      clr_i,      // Synchronous clear
    input  logic      shift_en_i, // enable or disable the operation
    input  block_in_t new_packet, // TODO: description
    // Input port
    input  logic      valid_i,
    output logic      ready_o,
    input  data_i_t   data_i,     // The data input has 1 interleaved bit per sub-split in the LSB pos.
    // Output port
    output logic      valid_o,
    input  logic      ready_i,
    output data_o_t   data_o,

    // TODO: this port is HIGH whenever new data is loaded, until the data is being consumed again. Opposed to valid_o, it does not represent
    // whether or not the data_o outputs a valid data output stream.
    output logic      cont_data_o,
    // HIGH if the first output handshake of the current data-element occurs.
    output logic      shift_en_o,
    output logic      first_hs_o,
    output header_t   header_o
);

    logic        contains_valid_data, load_new_data, all_data_consumed;
    logic        valid_shift_pos, first_outstanding_q, first_outstanding_d;
    block_in_t   [num_blocks-1:0] data_in_blocks, data_in, data_out;
    block_out_t  [num_blocks-1:0] data_out_blocks;
    block_cntr_t block_idx_q, block_idx_d;
    data_o_t     data_out_flattened;
    logic        block_start_bit;

  // initial begin
  //   $display("INFO: dequeue_register: input_size  = %0d",$bits(data_i_t));
  //   $display("INFO: dequeue_register: block_in_t  %0d",$bits(block_in_t));
  // end

    assign cont_data_o     = contains_valid_data;
    assign ready_o         = all_data_consumed | ~contains_valid_data;
    assign load_new_data   = valid_i & ready_o;
    assign block_start_bit = data_out[0][num_hdr_bits];
    assign valid_shift_pos = block_start_bit & contains_valid_data;
    assign valid_o         = contains_valid_data & valid_shift_pos;
    assign shift_en_o      = ~load_new_data & (ready_i | ~valid_shift_pos) & shift_en_i & contains_valid_data;
    assign first_hs_o      = valid_o & ready_i & first_outstanding_q;


    always_comb begin : TODO_give_lable
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
      if (use_header) begin
        data_o = {data_out_flattened[$bits(data_o_t)-1:num_hdr_bits], header_o};
      end
    end

    always_comb begin
      block_idx_d = block_idx_q;
      all_data_consumed = 0;
      if (shift_en_o) begin
        block_idx_d = block_idx_q + 1;
      end
      if (load_new_data) begin
        block_idx_d = '0;
      end
      if (block_idx_q == (num_blocks - 1)) begin
        if (valid_shift_pos) begin
          all_data_consumed = ready_i;
        end else begin
          all_data_consumed = 1;
        end
      end
    end

    assign data_in_blocks = data_i;

    for (genvar i = 0; i < num_blocks; i++) begin
      // assign inputs of the FFs
      always_comb begin
        data_in[i] = data_out[i];
        if (shift_en_o) begin
          if (i == num_blocks - 1) begin
            data_in[i] = new_packet;
          end else begin
            data_in[i] = data_out[i+1];
          end
        end

        if (load_new_data) begin
          data_in[i] = data_in_blocks[i];
        end
      end

      if (bit_removal_index==0) begin
        assign data_out_blocks[i] = data_out[i][block_size-1:1];
      end else if (bit_removal_index==block_size) begin
        assign data_out_blocks[i] = data_out[i][block_size-2:0];
      end else begin
        assign data_out_blocks[i] = {data_out[i][block_size-1:bit_removal_index+1], data_out[i][bit_removal_index-1:0]};
      end

      `FFLARNC(data_out[i], data_in[i], 1'b1, clr_i, '0, clk_i, rst_ni)
    end
    assign data_out_flattened = data_out_blocks;

    `FFLARNC(contains_valid_data, valid_i, ready_o, clr_i, 1'b0, clk_i, rst_ni)
    `FF(block_idx_q, block_idx_d, '0)
    `FF(first_outstanding_q, first_outstanding_d, 1)

    if (use_header) begin
      `FFLARNC(header_o, data_i, load_new_data, clr_i, 1'b0, clk_i, rst_ni)
    end else begin
      assign header_o = '0;
    end

  ////////////////////
  //   ASSERTIONS   //
  ////////////////////

  // sample assertions
  // `ASSERT_INIT(RawModeFifoDim, RecvFifoDepth >= RawModeFifoDepth)
  `ASSERT(HdrTooBig, num_hdr_bits<block_size)

endmodule
