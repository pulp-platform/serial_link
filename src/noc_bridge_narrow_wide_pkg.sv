// Author: Yannick Baumann <baumanny@student.ethz.ch>

/// A package declareing some type definitions.
package noc_bridge_narrow_wide_pkg;

  ////////////////////////////////////////////
  // PARAMETRIZATION - VARIABLE PARAMETERS  //
  ////////////////////////////////////////////

  // With this parameter you can set the maximal credit count for the NoC bridge. If set to 0, the NoC-bridge without
  // virtualization will be used instead.
  localparam int NumCred_NocBridge = 8;

  ///////////////////////////////////////////
  // DEPENDANT PARAMETERS - DO NOT CHANGE  //
  ///////////////////////////////////////////

  // load the flit types
  import floo_narrow_wide_flit_pkg::*;

  localparam int NarrowReqFlitSize  = $bits(narrow_req_flit_t);
  localparam int NarrowRspFlitSize  = $bits(narrow_rsp_flit_t);
  // identify the larger of the two types
  localparam int NarrowFlitTypes[5] = {NarrowReqFlitSize, NarrowRspFlitSize, 0, 0, 0};
  // the minimal flit-data-size requirement corresponds to the larger of the two channels, exclusive the handshake signals.
  localparam int NarrowFlitDataSize = serial_link_pkg::find_max_channel(NarrowFlitTypes)-2;

  typedef logic [NarrowFlitDataSize-1:0] narrow_flit_data_t;
  typedef logic [NarrowReqFlitSize-3:0] narrow_flit_req_data_t;
  typedef logic [NarrowRspFlitSize-3:0] narrow_flit_rsp_data_t;


  localparam int WideFlitSize  = $bits(wide_flit_t);
  localparam int WideFlitDataSize = WideFlitSize-2;

  typedef logic [WideFlitDataSize-1:0] wide_flit_data_t;

  typedef enum logic [1:0] {
    narrow_response = 'd0,
    narrow_request  = 'd1,
    wide_channel    = 'd2
  } channel_hdr_e;

  typedef enum logic [0:0] {
    narrowChan = 'd0,
    wideChan   = 'd1
  } selected_channel_type_e;

  localparam int strobeSize   = (($bits(wide_flit_data_t)+$bits(channel_hdr_e)+7)/8);
  localparam int narrowStrobe = (($bits(narrow_flit_data_t)+$bits(channel_hdr_e)+7)/8);

  typedef logic [strobeSize-1:0] strb_noc_t;

  localparam strb_noc_t NarrowStrobe = {narrowStrobe{1'b1}};
  localparam strb_noc_t WideStrobe   = {strobeSize{1'b1}};

  localparam int WideChannelHdr = $bits(channel_hdr_e);

  typedef logic [$clog2(NumCred_NocBridge+1)-1:0] bridge_credit_t;

  // User bits utilized in the AXIS interface
  typedef struct packed {
    logic data_validity;
    channel_hdr_e credits_hdr;
    bridge_credit_t credits;
  } user_bits_t;

  // Data bits utilized in the AXIS interface
  typedef struct packed {
    channel_hdr_e data_hdr;
    wide_flit_data_t data;
  } data_bits_t;

  // packet type used in the virtual-channel noc_bridge
  typedef struct packed {
    channel_hdr_e data_hdr;
    wide_flit_data_t data;
    logic data_validity;
    channel_hdr_e credits_hdr;
    bridge_credit_t credits;
  } axis_packet_t;

  typedef struct packed {
    channel_hdr_e data_hdr;
    narrow_flit_data_t data;
    logic data_validity;
    channel_hdr_e credits_hdr;
    bridge_credit_t credits;
  } narrow_axis_packet_t;

endpackage : noc_bridge_narrow_wide_pkg
