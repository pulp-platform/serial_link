// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Yannick Baumann <baumanny@student.ethz.ch>

/// A package declareing some type definitions.
package noc_bridge_pkg;

  ////////////////////////////////////////////
  // PARAMETRIZATION - VARIABLE PARAMETERS  //
  ////////////////////////////////////////////

  // With this parameter you can set the maximal credit count for the NoC bridge. If set to 0, the NoC-bridge without
  // virtualization will be used instead.
  localparam int NumCredNocBridge = 8;

  ///////////////////////////////////////////
  // DEPENDANT PARAMETERS - DO NOT CHANGE  //
  ///////////////////////////////////////////

  // load the flit types
  import floo_axi_pkg::*;

  localparam int ReqFlitSize  = $bits(floo_req_chan_t);
  localparam int RspFlitSize  = $bits(floo_rsp_chan_t);
  // identify the larger of the two types
  localparam int FlitTypes[5] = {ReqFlitSize, RspFlitSize, 0, 0, 0};
  // the minimal flit-data-size requirement corresponds to the larger of the two channels, exclusive the handshake signals.
  localparam int FlitDataSize = serial_link_pkg::find_max_channel(FlitTypes)-2;

  typedef logic [FlitDataSize-1:0] flit_data_t;
  typedef logic [ReqFlitSize-3:0] flit_req_data_t;
  typedef logic [RspFlitSize-3:0] flit_rsp_data_t;

  typedef enum logic [0:0] {
    response  = 'd0,
    request   = 'd1
  } channel_hdr_e;

  typedef logic [$clog2(NumCredNocBridge+1)-1:0] bridge_credit_t;

  // User bits utilized in the AXIS interface
  typedef struct packed {
    logic data_validity;
    channel_hdr_e credits_hdr;
    bridge_credit_t credits;
  } user_bit_t;

  // Data bits utilized in the AXIS interface
  typedef struct packed {
    channel_hdr_e data_hdr;
    flit_data_t data;
  } data_bits_t;

  // packet type used in the virtual-channel noc_bridge
  typedef struct packed {
    channel_hdr_e data_hdr;
    flit_data_t data;
    logic data_validity;
    channel_hdr_e credits_hdr;
    bridge_credit_t credits;
  } axis_packet_t;

endpackage : noc_bridge_pkg
