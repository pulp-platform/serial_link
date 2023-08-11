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

// TODO: add a description
module insert_latency_to_signal #(
  parameter int    data_width  = 1,
  parameter type   data_t      = logic[data_width-1:0],
	parameter int    delay       = 0,
  parameter bit    use_default = 0,
  parameter data_t default_val = '0
) (
  input  data_t signal_i,
  output data_t signal_o
);

  logic useDefaultVal;
  data_t [delay:0] delay_chain;

  initial begin
    useDefaultVal = use_default;
    #(delay);
    useDefaultVal = 1'b0;
  end

  for (genvar i = 0; i < delay; i++) begin
    insert_latency_of_one #(
      .data_t   ( data_t )
    ) i_latency_inserter (
      .data_in  ( delay_chain[i]   ),
      .data_out ( delay_chain[i+1] )
    );
  end

  assign delay_chain[0] = signal_i;
  assign signal_o = (useDefaultVal) ? default_val : delay_chain[delay];

  // // alternative, quicker implementation?
  // data_t delay_chain[$];
  // data_t output_sig;

  // always @(signal_i) begin
  //   delay_chain.push_back(signal_i);
  //   delayed_change();
  // end

  // automatic task delayed_change();
  //   #(delay);
  //   output_sig = delay_chain.pop_front();
  // endtask : delayed_change

  // assign signal_o = (useDefaultVal) ? default_val : output_sig;

endmodule
