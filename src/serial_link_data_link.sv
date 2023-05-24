// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>
// Modified: Yannick Baumann <baumanny@student.ethz.ch>

`include "common_cells/registers.svh"
`include "common_cells/assertions.svh"

// Implements the Data Link layer of the Serial Link
// Handles the RAW mode
module serial_link_data_link
import serial_link_pkg::*;
#(
  parameter type axis_req_t      = logic,
  parameter type axis_rsp_t      = logic,
  parameter type payload_t       = logic,
  parameter type phy_data_t      = serial_link_pkg::phy_data_t,
  parameter int  NumChannels     = serial_link_pkg::NumChannels,
  parameter int  NumLanes        = serial_link_pkg::NumLanes,
  // For credit-based control flow
  parameter type credit_t        = logic,
  parameter int  NumCredits      = -1,
  parameter int  ForceSendThresh = NumCredits - 4,

  //////////////////////////
  // Dependant parameters //
  //////////////////////////

  localparam int NumUserBits      = $bits(axis_in_req_i.t.user),
  // The width used to transfer all the data contained in one axis-packet (so far data & user bits are supported)
  localparam int axis_pak_width   = $bits(payload_t) + NumUserBits,
  localparam int Log2NumChannels  = (NumChannels > 1)? $clog2(NumChannels) : 1,
  localparam int RawModeFifoDepth = serial_link_pkg::RawModeFifoDepth,
  localparam int BandWidth        = NumChannels * NumLanes * 2,
  // (the +1 is required to transmit the info whether or not it is a credits_only packet which is being sent)
  localparam int PayloadSplits    = (1 + $bits(payload_t) + $bits(credit_t) + NumUserBits + BandWidth - 1) / BandWidth,
  localparam int RecvFifoDepth    = NumCredits * PayloadSplits,
  localparam int unsigned Log2RawModeFifoDepth = $clog2(RawModeFifoDepth)
) (
  input  logic                            clk_i,
  input  logic                            rst_ni,
  // AXI Stream interface signals
  input  axis_req_t                       axis_in_req_i,
  output axis_rsp_t                       axis_in_rsp_o,
  output axis_req_t                       axis_out_req_o,
  input  axis_rsp_t                       axis_out_rsp_i,
  // Phy Channel interface signals
  output phy_data_t [NumChannels-1:0]     data_out_o,
  output logic      [NumChannels-1:0]     data_out_valid_o,
  input  logic                            data_out_ready_i,
  input  phy_data_t [NumChannels-1:0]     data_in_i,
  input  logic      [NumChannels-1:0]     data_in_valid_i,
  output logic      [NumChannels-1:0]     data_in_ready_o,
  // Debug/Calibration signals
  input  logic                            cfg_flow_control_fifo_clear_i,
  input  logic                            cfg_raw_mode_en_i,
  input  logic [Log2NumChannels-1:0]      cfg_raw_mode_in_ch_sel_i,
  output phy_data_t                       cfg_raw_mode_in_data_o,
  output logic [NumChannels-1:0]          cfg_raw_mode_in_data_valid_o,
  input  logic                            cfg_raw_mode_in_data_ready_i,
  input  logic [NumChannels-1:0]          cfg_raw_mode_out_ch_mask_i,
  input  phy_data_t                       cfg_raw_mode_out_data_i,
  input  logic                            cfg_raw_mode_out_data_valid_i,
  input  logic                            cfg_raw_mode_out_en_i,
  input  logic                            cfg_raw_mode_out_data_fifo_clear_i,
  output logic [Log2RawModeFifoDepth-1:0] cfg_raw_mode_out_data_fifo_fill_state_o,
  output logic                            cfg_raw_mode_out_data_fifo_is_full_o
);

  // These unfiltered axis_out signals will have to be analyzed for credits_only packets
  // which will not be allowed to propagate to the axis output.
  axis_req_t axis_out_req_unfiltered;
  axis_rsp_t axis_out_rsp_unfiltered;

  // credit-based-flow-control related signals (The axis user-bits are now also packed and transfered)
  logic [axis_pak_width-1:0] axis_in_data_to_physical;
  logic axis_in_req_tvalid_afterFlowControl;
  logic axis_in_rsp_tready_afterFlowControl;
  credit_t credits_to_send, credits_incoming;
  logic credits_only_packet_out, credits_only_packet_in;

  logic [PayloadSplits-1:0] recv_reg_in_valid, recv_reg_in_ready;
  logic [PayloadSplits-1:0] recv_reg_out_valid, recv_reg_out_ready;
  phy_data_t [PayloadSplits-1:0][NumChannels-1:0] recv_reg_data;
  logic [$clog2(PayloadSplits)-1:0] recv_reg_index_q, recv_reg_index_d;

  link_state_e link_state_q, link_state_d;
  logic [$clog2(PayloadSplits*NumChannels*NumLanes*2):0] link_out_index_q, link_out_index_d;

  logic raw_mode_fifo_full, raw_mode_fifo_empty;
  logic raw_mode_fifo_push, raw_mode_fifo_pop;
  phy_data_t raw_mode_fifo_data_in, raw_mode_fifo_data_out;

  // Declare the stream of data to be sent via the off-chip link
  localparam int transfer_data_width = $bits({axis_in_data_to_physical, credits_to_send, credits_only_packet_out});
  logic [transfer_data_width-1:0] wrapped_output_data;
  assign wrapped_output_data = {axis_in_data_to_physical, credits_to_send, credits_only_packet_out};

  ////////////////////////////////
  //   FLOW-CONTROL-INSERTION   //
  ////////////////////////////////

  serial_link_credit_synchronization #(
    .credit_t   ( credit_t   ),
    .data_width ( axis_pak_width ),
    .NumCredits ( NumCredits )
  ) i_synchronization_flow_control (
    .clk_i               ( clk_i                   ),
    .rst_ni              ( rst_ni                  ),

    // It is likely, that the port size is smaller than the .t.data size. This is because the .t.data line is extended
    // to consist of an integer number of bytes, whereas the port does not have any such restrictions and therefore can
    // be made smaller, without loosing any information...
    .data_to_send_in     ( {axis_in_req_i.t.data, axis_in_req_i.t.user} ),
    .data_to_send_out    ( axis_in_data_to_physical ),

    // towards button (internal)
    .credits_to_send_o   ( credits_to_send ),
    // top
    .send_ready_o        ( axis_in_rsp_o.tready    ),
    // top
    .send_valid_i        ( axis_in_req_i.tvalid    ),
    // button
    .send_valid_o        ( axis_in_req_tvalid_afterFlowControl  ),
    // button
    .send_ready_i        ( axis_in_rsp_tready_afterFlowControl  ),
    
    .credits_received_i  ( credits_incoming  ),
    .receive_valid_i     ( axis_out_req_unfiltered.tvalid   ),
    .receive_ready_i     ( axis_out_rsp_unfiltered.tready   ),
    // TODO: append this bit in the data load and therewith avoid the need to reconstruct if it is a credit only packet
    .credits_only_packet ( credits_only_packet_out )
  );

  /////////////////
  //   DATA IN   //
  /////////////////

  //Datatype for the stream fifo and register
  typedef phy_data_t [NumChannels-1:0] phy_data_chan_t;
  phy_data_chan_t flow_control_fifo_data_out;
  logic flow_control_fifo_valid_out, flow_control_fifo_ready_out;
  logic flow_control_fifo_valid_in, flow_control_fifo_ready_in;

  stream_fifo #(
    .T(phy_data_chan_t),
    .DEPTH (RecvFifoDepth)
  ) i_flow_control_fifo (
    .clk_i      ( clk_i                         ),
    .rst_ni     ( rst_ni                        ),
    .flush_i    ( cfg_flow_control_fifo_clear_i ),
    .testmode_i ( 1'b0                          ),
    .usage_o    (                               ),
    .data_i     ( data_in_i                     ),
    .valid_i    ( flow_control_fifo_valid_in    ),
    .ready_o    ( flow_control_fifo_ready_in    ),
    .data_o     ( flow_control_fifo_data_out    ),
    .valid_o    ( flow_control_fifo_valid_out   ),
    .ready_i    ( flow_control_fifo_ready_out   )
  );

  for (genvar i = 0; i < PayloadSplits; i++) begin : gen_recv_reg
    stream_register #(
      .T (phy_data_chan_t)
    ) i_recv_reg (
      .clk_i      ( clk_i                       ),
      .rst_ni     ( rst_ni                      ),
      .clr_i      ( 1'b0                        ),
      .testmode_i ( 1'b0                        ),
      .valid_i    ( recv_reg_in_valid[i]        ),
      .ready_o    ( recv_reg_in_ready[i]        ),
      .data_i     ( flow_control_fifo_data_out  ),
      .valid_o    ( recv_reg_out_valid[i]       ),
      .ready_i    ( recv_reg_out_ready[i]       ),
      .data_o     ( recv_reg_data[i]            )
    );
  end

  always_comb begin
    recv_reg_in_valid = '0;
    data_in_ready_o = '0;
    recv_reg_index_d = recv_reg_index_q;
    axis_out_req_unfiltered.tvalid = 1'b0;
    {axis_out_req_unfiltered.t.data, axis_out_req_unfiltered.t.user, credits_incoming, credits_only_packet_in} = recv_reg_data;
    recv_reg_out_ready = '0;
    cfg_raw_mode_in_data_o = '0;
    cfg_raw_mode_in_data_valid_o = '0;
    flow_control_fifo_valid_in = 1'b0;
    flow_control_fifo_ready_out = 1'b0;

    if (cfg_raw_mode_en_i) begin
      // Raw mode
      cfg_raw_mode_in_data_valid_o = data_in_valid_i;
      // Ready is asserted if there is a read access
      if (cfg_raw_mode_in_data_ready_i) begin
        // Select channel to read from and wait for valid data
        if (data_in_valid_i[cfg_raw_mode_in_ch_sel_i]) begin
          // Pop item from CDC RX FIFO
          data_in_ready_o[cfg_raw_mode_in_ch_sel_i] = 1'b1;
          // respond with data from selected channel
          cfg_raw_mode_in_data_o = data_in_i[cfg_raw_mode_in_ch_sel_i];
        end else begin
          // TODO: send out Error response
        end
      end
    end else begin
      // Normal operating mode
      // If all inputs of each channel have valid data, push it to fifo
      flow_control_fifo_valid_in = &data_in_valid_i;
      data_in_ready_o = {NumChannels{flow_control_fifo_valid_in & flow_control_fifo_ready_in}};
      // Pop from Fifo and assemble in register
      if (flow_control_fifo_valid_out & recv_reg_in_ready[recv_reg_index_q]) begin
        recv_reg_in_valid[recv_reg_index_q] = 1'b1;
        flow_control_fifo_ready_out = 1'b1;
        // Increment recv reg counter
        recv_reg_index_d = (recv_reg_index_q == PayloadSplits - 1)? 0 : recv_reg_index_q + 1;
      end

      // Once all Recv Stream Registers are filled -> generate AXI stream request
      axis_out_req_unfiltered.tvalid = &recv_reg_out_valid;
      recv_reg_out_ready = {PayloadSplits{axis_out_rsp_unfiltered.tready}};
    end
  end

  `FF(recv_reg_index_q, recv_reg_index_d, '0)

  //////////////////
  //   DATA OUT   //
  //////////////////

  always_comb begin
    axis_in_rsp_tready_afterFlowControl = 1'b0;
    data_out_o = '0;
    data_out_valid_o = '0;
    link_out_index_d = link_out_index_q;
    link_state_d = link_state_q;
    raw_mode_fifo_pop = 1'b0;

    if (cfg_raw_mode_en_i) begin
      // Raw mode
      if (cfg_raw_mode_out_en_i & ~raw_mode_fifo_empty) begin
        data_out_valid_o = cfg_raw_mode_out_ch_mask_i;
        data_out_o = {{NumChannels}{raw_mode_fifo_data_out}};
        if (data_out_ready_i) begin
          raw_mode_fifo_pop = 1'b1;
        end
      end
    end else begin
      // Normal operating mode
      unique case (link_state_q)
        LinkSendIdle: begin
          if (axis_in_req_tvalid_afterFlowControl) begin
            link_out_index_d = NumChannels * NumLanes * 2;
            data_out_valid_o = '1;
            data_out_o = wrapped_output_data;
            if (data_out_ready_i) begin
              link_state_d = LinkSendBusy;
              if (link_out_index_d >= $bits(wrapped_output_data)) begin
                link_state_d = LinkSendIdle;
                axis_in_rsp_tready_afterFlowControl = 1'b1;
              end
            end
          end
        end

        LinkSendBusy: begin
          data_out_valid_o = '1;
          data_out_o = wrapped_output_data >> link_out_index_q;
          if (data_out_ready_i) begin
            link_out_index_d = link_out_index_q + NumChannels * NumLanes * 2;
            if (link_out_index_d >= $bits(wrapped_output_data)) begin
              link_state_d = LinkSendIdle;
              axis_in_rsp_tready_afterFlowControl = 1'b1;
            end
          end
        end
        default:;
      endcase
    end
  end

  // Credit only packets should not be forwarded as they do not contain valid data
  always_comb begin
    axis_out_req_o.tvalid = (credits_only_packet_in == 1) ? 0 : axis_out_req_unfiltered.tvalid;
    axis_out_req_o.t.data = axis_out_req_unfiltered.t.data;
    axis_out_req_o.t.user = axis_out_req_unfiltered.t.user;
    // make the credit only packet disappear (consume it)
    axis_out_rsp_unfiltered.tready = axis_out_rsp_i.tready || (credits_only_packet_in == 1);
  end

  // // This Block is for debuggin only: Uncomment if not used...
  // always_ff @(posedge clk_i) begin
  //   if (axis_out_req_unfiltered.tvalid & axis_out_rsp_unfiltered.tready) begin
  //     if (credits_only_packet_in == 1) begin
  //       $display("INFO: axis pack to be sent (@%8d) = | %1d | %30d | %1d | %2d | => not forwarded", $time, axis_out_req_unfiltered.t.data[$bits(axis_out_req_unfiltered.t.data)-6], axis_out_req_unfiltered.t.data[$bits(axis_out_req_unfiltered.t.data)-7:0], axis_out_req_unfiltered.t.user[$bits(axis_out_req_unfiltered.t.user)-1], axis_out_req_unfiltered.t.user[$bits(axis_out_req_unfiltered.t.user)-2:0]);
  //     end else begin
  //       $display("INFO: axis pack to be sent (@%8d) = | %1d | %30d | %1d | %2d |", $time, axis_out_req_unfiltered.t.data[$bits(axis_out_req_unfiltered.t.data)-6], axis_out_req_unfiltered.t.data[$bits(axis_out_req_unfiltered.t.data)-7:0], axis_out_req_unfiltered.t.user[$bits(axis_out_req_unfiltered.t.user)-1], axis_out_req_unfiltered.t.user[$bits(axis_out_req_unfiltered.t.user)-2:0]);
  //     end
  //   end    
  // end  

  fifo_v3 #(
    .dtype  ( phy_data_t        ),
    .DEPTH  ( RawModeFifoDepth  )
  ) i_raw_mode_fifo (
    .clk_i      ( clk_i                                   ),
    .rst_ni     ( rst_ni                                  ),
    .flush_i    ( cfg_raw_mode_out_data_fifo_clear_i      ),
    .testmode_i ( 1'b0                                    ),
    .full_o     ( raw_mode_fifo_full                      ),
    .empty_o    ( raw_mode_fifo_empty                     ),
    .usage_o    ( cfg_raw_mode_out_data_fifo_fill_state_o ),
    .data_i     ( raw_mode_fifo_data_in                   ),
    .push_i     ( raw_mode_fifo_push                      ),
    .data_o     ( raw_mode_fifo_data_out                  ),
    .pop_i      ( raw_mode_fifo_pop                       )
  );

  assign cfg_raw_mode_out_data_fifo_is_full_o = raw_mode_fifo_full;
  assign raw_mode_fifo_push = cfg_raw_mode_out_data_valid_i & ~raw_mode_fifo_full;
  assign raw_mode_fifo_data_in = cfg_raw_mode_out_data_i;

  `FF(link_out_index_q, link_out_index_d, '0)
  `FF(link_state_q, link_state_d, LinkSendIdle)

  ////////////////////
  //   ASSERTIONS   //
  ////////////////////

  `ASSERT_INIT(RawModeFifoDim, RecvFifoDepth >= RawModeFifoDepth)

endmodule
