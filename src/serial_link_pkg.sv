// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

/// A simple serial link package
package serial_link_pkg;

  typedef enum logic [3:0]  {
    TagIdle = 4'd0,
    TagAW   = 4'd1,
    TagW    = 4'd2,
    TagAR   = 4'd3,
    TagR    = 4'd4
  } tag_e;

  function automatic int find_max_channel(input int channel[5]);
    int max_value = 0;
    for (int i = 0; i < 5; i++) begin
      if (max_value < channel[i]) max_value = channel[i];
    end
    return max_value;
  endfunction

endpackage : serial_link_pkg
