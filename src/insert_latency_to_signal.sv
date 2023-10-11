// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
//  - Yannick Baumann <baumanny@ethz.student.ch>

// TODO: add a description
module insert_latency_of_one #(
  parameter type data_t = logic
) (
  input  data_t data_in,
  output data_t data_out
);

  always @(data_in) begin
    #1;
    data_out = data_in;
  end

endmodule : insert_latency_of_one

// // TODO: add a description
module insert_latency_to_signal #(
  parameter int    DataWidth    = 1,
  parameter type   data_t       = logic[DataWidth-1:0],
  parameter int    DelayInNs    = 0,
  parameter bit    UseDefault   = 0,
  parameter data_t DefaultValue = '0
) (
  input  data_t signal_i,
  output data_t signal_o
);

  data_t [DelayInNs:0] delay_chain;
  logic  useDefaultVal;

  initial begin
    useDefaultVal = UseDefault;
    #(DelayInNs);
    useDefaultVal = 1'b0;
  end

  for (genvar i = 0; i < DelayInNs; i++) begin : gen_latency_array
    insert_latency_of_one #(
      .data_t   ( data_t )
    ) i_latency_inserter (
      .data_in  ( delay_chain[i]   ),
      .data_out ( delay_chain[i+1] )
    );
  end

  assign delay_chain[0] = signal_i;
  assign signal_o = (useDefaultVal) ? DefaultValue : delay_chain[DelayInNs];

endmodule
