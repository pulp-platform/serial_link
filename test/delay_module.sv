// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
//  - Tim Fischer <fischeti@iis.ee.ethz.ch>

// Non-synthesizable test module that delays a signal by a configurable amount of time.
module delay_module #(
  /// Delay in nanoseconds
  parameter time DelayInNs          = 1ns,
  /// Data width
  parameter int unsigned DataWidth  = 1,
  /// Data type
  parameter type data_t             = logic[DataWidth-1:0]
) (
  input  logic  rst_ni,
  input  data_t data_i,
  output data_t data_o
);

  data_t data_internal;

  assign data_o = data_internal;

  always @(data_i, negedge rst_ni) begin
    if (!rst_ni) begin
      data_internal <= '0;
    end else begin
      #DelayInNs data_internal <= data_i;
    end
  end

endmodule : delay_module
