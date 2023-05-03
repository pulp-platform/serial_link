// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>
// Modified: Yannick Baumann <baumanny@student.ethz.ch>

`include "common_cells/registers.svh"
`include "common_cells/assertions.svh"

// Implements the Network layer of the Serial Link
// Translates from the AXI to the AXIStream interface and vice-versa
module serial_link_axi_network #(
    parameter type axi_req_t  = logic,
    parameter type axi_rsp_t  = logic,
    parameter type axis_req_t = logic,
    parameter type axis_rsp_t = logic,
    parameter type aw_chan_t  = logic,
    parameter type w_chan_t   = logic,
    parameter type b_chan_t   = logic,
    parameter type ar_chan_t  = logic,
    parameter type r_chan_t   = logic,
    parameter type payload_t  = logic
) (
  input  logic      clk_i,
  input  logic      rst_ni,
  input  axi_req_t  axi_in_req_i,
  output axi_rsp_t  axi_in_rsp_o,
  output axi_req_t  axi_out_req_o,
  input  axi_rsp_t  axi_out_rsp_i,
  output axis_req_t axis_out_req_o,
  input  axis_rsp_t axis_out_rsp_i,
  input  axis_req_t axis_in_req_i,
  output axis_rsp_t axis_in_rsp_o
);

  import serial_link_pkg::*;

  typedef enum logic [1:0] {
    Idle = 'b00,
    ArPend = 'b01,
    AwPend = 'b10,
    ArAwPend = 'b11
  } commiter_state_e;

  logic entropy_q, entropy_d;
  commiter_state_e commiter_state_q, commiter_state_d;

  payload_t axis_out_data_reg_in, payload_in;

  logic aw_gnt, w_gnt, b_gnt, ar_gnt, r_gnt;

  logic axis_out_valid_reg_out, axis_out_ready_reg_out;
  logic axis_out_valid_reg_in, axis_out_ready_reg_in;
  payload_t axis_out_data_reg_out;

  always_comb begin : commiter
    aw_gnt  = 1'b0;
    w_gnt   = 1'b0;
    b_gnt   = 1'b0;
    ar_gnt  = 1'b0;
    r_gnt   = 1'b0;
    commiter_state_d = commiter_state_q;

    // Priorities:
    // 1) B responses are always granted as they can be sent along other req/rsp
    // 2) AR/AW beats have priority unless there is already a same request in flight
    // 3) R/W beats have lowest priority unless there already is an AR/AW beat in flight.
    //    Additionally, W are not granted before the coresponding AW
    unique case(commiter_state_q)
      Idle: begin
        if (axi_in_req_i.aw_valid) begin
          aw_gnt = (axi_in_req_i.ar_valid)? entropy_q : 1'b1;
        end
        if (axi_in_req_i.ar_valid) begin
          ar_gnt = (axi_in_req_i.aw_valid)? ~entropy_q : 1'b1;
        end

        // Only r responses can be served in this state
        if (!ar_gnt & !aw_gnt) begin
          r_gnt = axi_out_rsp_i.r_valid;
        end

        if (aw_gnt & axi_in_rsp_o.aw_ready) commiter_state_d = AwPend;
        if (ar_gnt & axi_in_rsp_o.ar_ready) commiter_state_d = ArPend;
      end

      AwPend: begin
        if (axi_in_req_i.ar_valid) begin
          // We can no longer grant AW request but we can still grant AR requests
          ar_gnt = 1'b1;
        end else begin
          // Otherwise we grant R/W beats
          // Deciding between R/W requests with entropy prevents starvation
          if (axi_out_rsp_i.r_valid) begin
            r_gnt = (axi_in_req_i.w_valid)? entropy_q : 1'b1;
          end
          if (axi_in_req_i.w_valid) begin
            w_gnt = (axi_out_rsp_i.r_valid)? ~entropy_q : 1'b1;
          end
        end

        // Once last W is granted we can terminate AW burst and/or accepted a AR beat
        if (axi_in_req_i.w_valid & axi_in_rsp_o.w_ready & axi_in_req_i.w.last) begin
          commiter_state_d = (ar_gnt & axi_in_rsp_o.ar_ready)? ArPend : Idle;
        end else begin
          commiter_state_d = (ar_gnt & axi_in_rsp_o.ar_ready)? ArAwPend : AwPend;
        end
      end

      ArPend: begin
        if (axi_in_req_i.aw_valid) begin
          // We can no longer grant AR request but we can still grant AW requests
          aw_gnt = 1'b1;
        end else begin
          // Otherwise we grant R/W beats
          // Deciding between R/W requests with entropy prevents starvation
          if (axi_out_rsp_i.r_valid) begin
            r_gnt = (axi_in_req_i.w_valid)? entropy_q : 1'b1;
          end
          if (axi_in_req_i.w_valid) begin
            w_gnt = (axi_out_rsp_i.r_valid)? ~entropy_q : 1'b1;
          end
        end

        // Once last R response is out we can terminate AR burst and/or accepted a AW beat
        if (axi_in_rsp_o.r_valid & axi_in_req_i.r_ready & axi_in_rsp_o.r.last) begin
          commiter_state_d = (aw_gnt & axi_in_rsp_o.aw_ready)? AwPend : Idle;
        end else begin
          commiter_state_d = (aw_gnt & axi_in_rsp_o.aw_ready)? ArAwPend : ArPend;
        end
      end

      ArAwPend: begin
        // Only R/W are accepted
        if (axi_out_rsp_i.r_valid) begin
          r_gnt = (axi_in_req_i.w_valid)? entropy_q : 1'b1;
        end
        if (axi_in_req_i.w_valid) begin
          w_gnt = (axi_out_rsp_i.r_valid)? ~entropy_q : 1'b1;
        end

        // Check for last R/W packet
        if (axi_in_rsp_o.r_valid & axi_in_req_i.r_ready & axi_in_rsp_o.r.last) begin
          commiter_state_d[0] = 1'b0; // AwPend or Idle
        end
        if (axi_in_req_i.w_valid & axi_in_rsp_o.w_ready & axi_in_req_i.w.last) begin
          commiter_state_d[1] = 1'b0; // ArPend or Idle
        end
      end

      default:;
    endcase

    // Always serve B responses
    b_gnt = axi_out_rsp_i.b_valid;
  end

  `FF(commiter_state_q, commiter_state_d, Idle)

  always_comb begin : sender
    axis_out_data_reg_in.hdr = TagIdle;
    axis_out_data_reg_in.axi_ch = '0;
    axis_out_data_reg_in.b = '0;
    axis_out_data_reg_in.b_valid = '0;

    if (aw_gnt) begin
      axis_out_data_reg_in.axi_ch = axi_in_req_i.aw;
      axis_out_data_reg_in.hdr = TagAW;
    end else if (w_gnt) begin
      axis_out_data_reg_in.axi_ch = axi_in_req_i.w;
      axis_out_data_reg_in.hdr = TagW;
    end else if (ar_gnt) begin
      axis_out_data_reg_in.axi_ch = axi_in_req_i.ar;
      axis_out_data_reg_in.hdr = TagAR;
    end else if (r_gnt) begin
      axis_out_data_reg_in.axi_ch = axi_out_rsp_i.r;
      axis_out_data_reg_in.hdr = TagR;
    end

    if (b_gnt) begin
      axis_out_data_reg_in.b_valid = 1'b1;
      axis_out_data_reg_in.b = axi_out_rsp_i.b;
    end

    axis_out_valid_reg_in = (axis_out_data_reg_in.hdr != TagIdle) | axis_out_data_reg_in.b_valid;

    // Send responses if request was sent
    axi_in_rsp_o.aw_ready = aw_gnt & axis_out_ready_reg_in & axis_out_valid_reg_in;
    axi_in_rsp_o.w_ready  = w_gnt & axis_out_ready_reg_in & axis_out_valid_reg_in;
    axi_out_req_o.b_ready = b_gnt & axis_out_ready_reg_in & axis_out_valid_reg_in;
    axi_in_rsp_o.ar_ready = ar_gnt & axis_out_ready_reg_in & axis_out_valid_reg_in;
    axi_out_req_o.r_ready = r_gnt & axis_out_ready_reg_in & axis_out_valid_reg_in;
  end

  stream_fifo #(
    .DEPTH  ( 2         ),
    .T      ( payload_t )
  ) i_axis_out_reg (
    .clk_i      ( clk_i                  ),
    .rst_ni     ( rst_ni                 ),
    .flush_i    ( 1'b0                   ),
    .testmode_i ( 1'b0                   ),
    .usage_o    (                        ),
    .valid_i    ( axis_out_valid_reg_in  ),
    .ready_o    ( axis_out_ready_reg_in  ),
    .data_i     ( axis_out_data_reg_in   ),

    .valid_o    ( axis_out_valid_reg_out ),
    .ready_i    ( axis_out_ready_reg_out ),
    .data_o     ( axis_out_data_reg_out  )
  );

  assign axis_out_req_o.t.data = axis_out_data_reg_out;
  assign axis_out_ready_reg_out = axis_out_rsp_i.tready;
  assign axis_out_req_o.tvalid = axis_out_valid_reg_out;

  logic axi_ch_sent_q, axi_ch_sent_d;
  logic b_sent_q, b_sent_d;
  logic ar_sent_q, ar_sent_d;
  logic aw_sent_q, aw_sent_d;
  logic w_sent_q, w_sent_d;
  logic r_sent_q, r_sent_d;
  logic two_ch_packet, credit_only_packet;

  typedef enum logic { Normal, Sync } unpack_state_e;

  unpack_state_e unpack_state_q, unpack_state_d;

  assign aw_sent_d  = axi_out_req_o.aw_valid & axi_out_rsp_i.aw_ready |
                      ((unpack_state_q == Sync) & aw_sent_q);
  assign w_sent_d   = axi_out_req_o.w_valid & axi_out_rsp_i.w_ready |
                      ((unpack_state_q == Sync) & w_sent_q);
  assign ar_sent_d  = axi_out_req_o.ar_valid & axi_out_rsp_i.ar_ready |
                      ((unpack_state_q == Sync) & ar_sent_q);
  assign r_sent_d   = axi_in_rsp_o.r_valid & axi_in_req_i.r_ready |
                      ((unpack_state_q == Sync) & r_sent_q);
  assign b_sent_d   = axi_in_rsp_o.b_valid & axi_in_req_i.b_ready |
                      ((unpack_state_q == Sync) & b_sent_q);
  assign axi_ch_sent_d = aw_sent_d | w_sent_d | ar_sent_d | r_sent_d;

  assign payload_in = payload_t'(axis_in_req_i.t.data);
  assign two_ch_packet = (payload_in.hdr != TagIdle) & payload_in.b_valid;
  assign credit_only_packet = (payload_in.hdr == TagIdle) & ~payload_in.b_valid;

  always_comb begin : unpacker
    axi_out_req_o.aw_valid = 1'b0;
    axi_out_req_o.w_valid = 1'b0;
    axi_out_req_o.ar_valid = 1'b0;
    axi_in_rsp_o.r_valid = 1'b0;
    axi_in_rsp_o.b_valid = 1'b0;

    axis_in_rsp_o = '0;

    axi_out_req_o.aw = aw_chan_t'(payload_in.axi_ch);
    axi_out_req_o.w = w_chan_t'(payload_in.axi_ch);
    axi_in_rsp_o.b = b_chan_t'(payload_in.b);
    axi_out_req_o.ar = ar_chan_t'(payload_in.axi_ch);
    axi_in_rsp_o.r = r_chan_t'(payload_in.axi_ch);

    unpack_state_d = unpack_state_q;

    // The incoming payload can pack a AW,W,AR,R + an additional B channel
    // Both channels have to be accepted, if only one of them is accepted
    // at a time we have to synch
    unique case (unpack_state_q)

      Normal: begin
        if (axis_in_req_i.tvalid) begin
          axi_out_req_o.aw_valid = (payload_in.hdr == TagAW);
          axi_out_req_o.w_valid = (payload_in.hdr == TagW);
          axi_out_req_o.ar_valid = (payload_in.hdr == TagAR);
          axi_in_rsp_o.r_valid = (payload_in.hdr == TagR);
          axi_in_rsp_o.b_valid = payload_in.b_valid;

          // If there is a AXI channel + B response,
          // check if only one of them was accepted
          if (two_ch_packet) begin
            // I only one was able to send -> need to synchronize
            if (axi_ch_sent_d ^ b_sent_d) begin
              unpack_state_d = Sync;
            // if both were able to send -> accept payload
            end else if (axi_ch_sent_d & b_sent_d) begin
              axis_in_rsp_o.tready = 1'b1;
            end
          end else if (credit_only_packet) begin
            axis_in_rsp_o.tready = 1'b1;
          end else begin
            // accept payload if either one of them was able to send
            if (axi_ch_sent_d | b_sent_d) begin
              axis_in_rsp_o.tready = 1'b1;
            end
          end
        end
      end

      Sync: begin
        // If AXI channel was not sent yet, raise AXI request
        axi_out_req_o.aw_valid = (payload_in.hdr == TagAW) & ~axi_ch_sent_q;
        axi_out_req_o.w_valid = (payload_in.hdr == TagW) & ~axi_ch_sent_q;
        axi_out_req_o.ar_valid = (payload_in.hdr == TagAR) & ~axi_ch_sent_q;
        axi_in_rsp_o.r_valid = (payload_in.hdr == TagR) & ~axi_ch_sent_q;
        // Same for B response
        axi_in_rsp_o.b_valid = payload_in.b_valid & ~b_sent_q;

        // Once both AXI and B channel has been sent out, we can go
        // back to the Normal mode and accept payload
        if (axi_ch_sent_d & b_sent_d) begin
          axis_in_rsp_o.tready = 1'b1;
          unpack_state_d = Normal;
        end
      end

      default:;
    endcase
  end

  assign entropy_d = entropy_q + (axis_out_req_o.tvalid & axis_out_rsp_i.tready);
  `FF(entropy_q, entropy_d, '0)
  `FF(aw_sent_q, aw_sent_d, '0)
  `FF(w_sent_q, w_sent_d, '0)
  `FF(ar_sent_q, ar_sent_d, '0)
  `FF(r_sent_q, r_sent_d, '0)
  `FF(b_sent_q, b_sent_d, '0)
  `FF(axi_ch_sent_q, axi_ch_sent_d, '0)
  `FF(unpack_state_q, unpack_state_d, Normal)

  ////////////////////
  //   ASSERTIONS   //
  ////////////////////
  `ASSERT(AxiComitterAw, axi_in_req_i.w_valid & axi_in_rsp_o.w_ready & axi_in_req_i.w.last
          |=> $fell(commiter_state_q[1]))
  `ASSERT(AxiComitterAr, axi_in_rsp_o.r_valid & axi_in_req_i.r_ready & axi_in_rsp_o.r.last
          |=> $fell(commiter_state_q[0]))
  `ASSERT(AxisStable, axis_out_req_o.tvalid & !axis_out_rsp_i.tready |=> $stable(axis_out_req_o.t))
  `ASSERT(AxisHandshake, axis_out_req_o.tvalid & !axis_out_rsp_i.tready |=> axis_out_req_o.tvalid)

endmodule
