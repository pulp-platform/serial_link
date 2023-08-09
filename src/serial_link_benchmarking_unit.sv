// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
//  - Yannick Baumann <baumanny@ethz.student.ch>

// This benchmarking unit is to be used in the tb_floo_serial_link_narrow_wide.sv
// testbench in combination with the analyzePerformance.tcl script.
module serial_link_benchmarking_unit #(
  parameter type narrow_axi_rand_master_t = logic,
  parameter type narrow_axi_rand_slave_t = logic,
  parameter type wide_axi_rand_master_t = logic,
  parameter type wide_axi_rand_slave_t = logic
) (
  output logic[31:0] serial_link_0_number_cycles,
  output logic[31:0] serial_link_0_valid_cycles_to_phys,
  output logic[31:0] serial_link_0_valid_cycles_from_phys,
  output logic[31:0] serial_link_1_number_cycles,
  output logic[31:0] serial_link_1_valid_cycles_to_phys,
  output logic[31:0] serial_link_1_valid_cycles_from_phys,
  output logic[31:0] data_link_0_num_cred_only_pack_sent,
  output logic[31:0] data_link_0_sum_stalled_cyc_cred_cntrs,
  output logic[31:0] data_link_1_num_cred_only_pack_sent,
  output logic[31:0] data_link_1_sum_stalled_cyc_cred_cntrs,
  output logic[31:0] network_0_number_cycles,
  output logic[31:0] network_0_valid_cycles_to_phys,
  output logic[31:0] network_0_valid_cycles_from_phys,
  output logic[31:0] network_0_num_cred_only_pack_sent,
  output logic[31:0] network_0_sum_stalled_cyc_cred_cntrs,
  output logic[31:0] network_1_number_cycles,
  output logic[31:0] network_1_valid_cycles_to_phys,
  output logic[31:0] network_1_valid_cycles_from_phys,
  output logic[31:0] network_1_num_cred_only_pack_sent,
  output logic[31:0] network_1_sum_stalled_cyc_cred_cntrs,

  output logic[31:0] lat_0,
  output logic[31:0] lat_1,
  output logic[31:0] lat_2,
  output logic[31:0] lat_3,
  output logic[31:0] lat_4,
  output logic[31:0] lat_5,
  output logic[31:0] lat_6,
  output logic[31:0] lat_7,
  output logic[31:0] lat_8,
  output logic[31:0] lat_9,
  output logic[31:0] lat_10,
  output logic[31:0] lat_11,
  output logic[31:0] lat_12,
  output logic[31:0] lat_13,
  output logic[31:0] lat_14,
  output logic[31:0] lat_15,
  output logic[31:0] lat_16,
  output logic[31:0] lat_17,
  output logic[31:0] lat_18,
  output logic[31:0] lat_19,
  output logic[31:0] lat_20,
  output logic[31:0] lat_21,
  output logic[31:0] lat_22,
  output logic[31:0] lat_23,
  output logic[31:0] lat_24,
  output logic[31:0] lat_25,
  output logic[31:0] lat_26,
  output logic[31:0] lat_27,
  output logic[31:0] lat_28,
  output logic[31:0] lat_29,
  output logic[31:0] lat_30,
  output logic[31:0] lat_31,
  output logic[31:0] lat_32,
  output logic[31:0] lat_33,
  output logic[31:0] lat_34,
  output logic[31:0] lat_35,
  output logic[31:0] lat_36,
  output logic[31:0] lat_37,
  output logic[31:0] lat_38,
  output logic[31:0] lat_39
);

  // When designs are being synthesized, the variable performSynthesis should be defined.
  // This prevents the elaboration of the benchmarking module and therefore avoids error messages.
  `ifndef performSynthesis


    /////////////////////////////////////
    //  min & max latency calculation  //
    /////////////////////////////////////


    // =====================================
    //    i_narrow_channel_compare_1_to_2
    // =====================================
    int narrow_1_to_2_aw_sent [$];
    int narrow_1_to_2_w_sent  [$];
    int narrow_1_to_2_b_sent  [$];
    int narrow_1_to_2_ar_sent [$];
    int narrow_1_to_2_r_sent  [$];
    int narrow_1_to_2_aw_max_latency = 0;
    int narrow_1_to_2_w_max_latency  = 0;
    int narrow_1_to_2_b_max_latency  = 0;
    int narrow_1_to_2_ar_max_latency = 0;
    int narrow_1_to_2_r_max_latency  = 0;
    int narrow_1_to_2_aw_min_latency = 2147483640;
    int narrow_1_to_2_w_min_latency  = 2147483640;
    int narrow_1_to_2_b_min_latency  = 2147483640;
    int narrow_1_to_2_ar_min_latency = 2147483640;
    int narrow_1_to_2_r_min_latency  = 2147483640;

    always_ff @(posedge i_narrow_channel_compare_1_to_2.clk_a_i) begin : narrow_1_to_2_req_sent
      // aw sent
      if (i_narrow_channel_compare_1_to_2.axi_a_req.aw_valid & i_narrow_channel_compare_1_to_2.axi_a_res.aw_ready)
        narrow_1_to_2_aw_sent.push_back($time);
      // w sent
      if (i_narrow_channel_compare_1_to_2.axi_a_req.w_valid & i_narrow_channel_compare_1_to_2.axi_a_res.w_ready)
        narrow_1_to_2_w_sent.push_back($time);
      // ar sent
      if (i_narrow_channel_compare_1_to_2.axi_a_req.ar_valid & i_narrow_channel_compare_1_to_2.axi_a_res.ar_ready)
        narrow_1_to_2_ar_sent.push_back($time);
    end
    always_ff @(posedge i_narrow_channel_compare_1_to_2.clk_b_i) begin : narrow_1_to_2_res_sent
      // b sent
      if (i_narrow_channel_compare_1_to_2.axi_b_res.b_valid & i_narrow_channel_compare_1_to_2.axi_b_req.b_ready)
        narrow_1_to_2_b_sent.push_back($time);
      // r sent
      if (i_narrow_channel_compare_1_to_2.axi_b_res.r_valid & i_narrow_channel_compare_1_to_2.axi_b_req.r_ready)
        narrow_1_to_2_r_sent.push_back($time);
    end
    always_ff @(posedge i_narrow_channel_compare_1_to_2.clk_b_i) begin : narrow_1_to_2_req_received
      // aw received
      if (i_narrow_channel_compare_1_to_2.axi_b_req.aw_valid & i_narrow_channel_compare_1_to_2.axi_b_res.aw_ready) begin
        automatic int required_time;
        required_time = $time - narrow_1_to_2_aw_sent.pop_front();
        if (required_time > narrow_1_to_2_aw_max_latency) narrow_1_to_2_aw_max_latency = required_time;
        if (required_time < narrow_1_to_2_aw_min_latency) narrow_1_to_2_aw_min_latency = required_time;
      end
      // w received
      if (i_narrow_channel_compare_1_to_2.axi_b_req.w_valid & i_narrow_channel_compare_1_to_2.axi_b_res.w_ready) begin
        automatic int required_time;
        required_time = $time - narrow_1_to_2_w_sent.pop_front();
        if (required_time > narrow_1_to_2_w_max_latency) narrow_1_to_2_w_max_latency = required_time;
        if (required_time < narrow_1_to_2_w_min_latency) narrow_1_to_2_w_min_latency = required_time;
      end
      // ar received
      if (i_narrow_channel_compare_1_to_2.axi_b_req.ar_valid & i_narrow_channel_compare_1_to_2.axi_b_res.ar_ready) begin
        automatic int required_time;
        required_time = $time - narrow_1_to_2_ar_sent.pop_front();
        if (required_time > narrow_1_to_2_ar_max_latency) narrow_1_to_2_ar_max_latency = required_time;
        if (required_time < narrow_1_to_2_ar_min_latency) narrow_1_to_2_ar_min_latency = required_time;
      end
    end
    always_ff @(posedge i_narrow_channel_compare_1_to_2.clk_a_i) begin : narrow_1_to_2_res_received
      // b received
      if (i_narrow_channel_compare_1_to_2.axi_a_res.b_valid & i_narrow_channel_compare_1_to_2.axi_a_req.b_ready) begin
        automatic int required_time;
        required_time = $time - narrow_1_to_2_b_sent.pop_front();
        if (required_time > narrow_1_to_2_b_max_latency) narrow_1_to_2_b_max_latency = required_time;
        if (required_time < narrow_1_to_2_b_min_latency) narrow_1_to_2_b_min_latency = required_time;
      end
      // r received
      if (i_narrow_channel_compare_1_to_2.axi_a_res.r_valid & i_narrow_channel_compare_1_to_2.axi_a_req.r_ready) begin
        automatic int required_time;
        required_time = $time - narrow_1_to_2_r_sent.pop_front();
        if (required_time > narrow_1_to_2_r_max_latency) narrow_1_to_2_r_max_latency = required_time;
        if (required_time < narrow_1_to_2_r_min_latency) narrow_1_to_2_r_min_latency = required_time;
      end
    end

    assign lat_0 = narrow_1_to_2_aw_max_latency;
    assign lat_1 = narrow_1_to_2_w_max_latency;
    assign lat_2 = narrow_1_to_2_b_max_latency;
    assign lat_3 = narrow_1_to_2_ar_max_latency;
    assign lat_4 = narrow_1_to_2_r_max_latency;
    assign lat_5 = narrow_1_to_2_aw_min_latency;
    assign lat_6 = narrow_1_to_2_w_min_latency;
    assign lat_7 = narrow_1_to_2_b_min_latency;
    assign lat_8 = narrow_1_to_2_ar_min_latency;
    assign lat_9 = narrow_1_to_2_r_min_latency;


    // =====================================
    //    i_narrow_channel_compare_2_to_1
    // =====================================
    int narrow_2_to_1_aw_sent [$];
    int narrow_2_to_1_w_sent  [$];
    int narrow_2_to_1_b_sent  [$];
    int narrow_2_to_1_ar_sent [$];
    int narrow_2_to_1_r_sent  [$];
    int narrow_2_to_1_aw_max_latency = 0;
    int narrow_2_to_1_w_max_latency  = 0;
    int narrow_2_to_1_b_max_latency  = 0;
    int narrow_2_to_1_ar_max_latency = 0;
    int narrow_2_to_1_r_max_latency  = 0;
    int narrow_2_to_1_aw_min_latency = 2147483640;
    int narrow_2_to_1_w_min_latency  = 2147483640;
    int narrow_2_to_1_b_min_latency  = 2147483640;
    int narrow_2_to_1_ar_min_latency = 2147483640;
    int narrow_2_to_1_r_min_latency  = 2147483640;

    always_ff @(posedge i_narrow_channel_compare_2_to_1.clk_a_i) begin : narrow_2_to_1_req_sent
      // aw sent
      if (i_narrow_channel_compare_2_to_1.axi_a_req.aw_valid & i_narrow_channel_compare_2_to_1.axi_a_res.aw_ready)
        narrow_2_to_1_aw_sent.push_back($time);
      // w sent
      if (i_narrow_channel_compare_2_to_1.axi_a_req.w_valid & i_narrow_channel_compare_2_to_1.axi_a_res.w_ready)
        narrow_2_to_1_w_sent.push_back($time);
      // ar sent
      if (i_narrow_channel_compare_2_to_1.axi_a_req.ar_valid & i_narrow_channel_compare_2_to_1.axi_a_res.ar_ready)
        narrow_2_to_1_ar_sent.push_back($time);
    end
    always_ff @(posedge i_narrow_channel_compare_2_to_1.clk_b_i) begin : narrow_2_to_1_res_sent
      // b sent
      if (i_narrow_channel_compare_2_to_1.axi_b_res.b_valid & i_narrow_channel_compare_2_to_1.axi_b_req.b_ready)
        narrow_2_to_1_b_sent.push_back($time);
      // r sent
      if (i_narrow_channel_compare_2_to_1.axi_b_res.r_valid & i_narrow_channel_compare_2_to_1.axi_b_req.r_ready)
        narrow_2_to_1_r_sent.push_back($time);
    end
    always_ff @(posedge i_narrow_channel_compare_2_to_1.clk_b_i) begin : narrow_2_to_1_req_received
      // aw received
      if (i_narrow_channel_compare_2_to_1.axi_b_req.aw_valid & i_narrow_channel_compare_2_to_1.axi_b_res.aw_ready) begin
        automatic int required_time;
        required_time = $time - narrow_2_to_1_aw_sent.pop_front();
        if (required_time > narrow_2_to_1_aw_max_latency) narrow_2_to_1_aw_max_latency = required_time;
        if (required_time < narrow_2_to_1_aw_min_latency) narrow_2_to_1_aw_min_latency = required_time;
      end
      // w received
      if (i_narrow_channel_compare_2_to_1.axi_b_req.w_valid & i_narrow_channel_compare_2_to_1.axi_b_res.w_ready) begin
        automatic int required_time;
        required_time = $time - narrow_2_to_1_w_sent.pop_front();
        if (required_time > narrow_2_to_1_w_max_latency) narrow_2_to_1_w_max_latency = required_time;
        if (required_time < narrow_2_to_1_w_min_latency) narrow_2_to_1_w_min_latency = required_time;
      end
      // ar received
      if (i_narrow_channel_compare_2_to_1.axi_b_req.ar_valid & i_narrow_channel_compare_2_to_1.axi_b_res.ar_ready) begin
        automatic int required_time;
        required_time = $time - narrow_2_to_1_ar_sent.pop_front();
        if (required_time > narrow_2_to_1_ar_max_latency) narrow_2_to_1_ar_max_latency = required_time;
        if (required_time < narrow_2_to_1_ar_min_latency) narrow_2_to_1_ar_min_latency = required_time;
      end
    end
    always_ff @(posedge i_narrow_channel_compare_2_to_1.clk_a_i) begin : narrow_2_to_1_res_received
      // b received
      if (i_narrow_channel_compare_2_to_1.axi_a_res.b_valid & i_narrow_channel_compare_2_to_1.axi_a_req.b_ready) begin
        automatic int required_time;
        required_time = $time - narrow_2_to_1_b_sent.pop_front();
        if (required_time > narrow_2_to_1_b_max_latency) narrow_2_to_1_b_max_latency = required_time;
        if (required_time < narrow_2_to_1_b_min_latency) narrow_2_to_1_b_min_latency = required_time;
      end
      // r received
      if (i_narrow_channel_compare_2_to_1.axi_a_res.r_valid & i_narrow_channel_compare_2_to_1.axi_a_req.r_ready) begin
        automatic int required_time;
        required_time = $time - narrow_2_to_1_r_sent.pop_front();
        if (required_time > narrow_2_to_1_r_max_latency) narrow_2_to_1_r_max_latency = required_time;
        if (required_time < narrow_2_to_1_r_min_latency) narrow_2_to_1_r_min_latency = required_time;
      end
    end

    assign lat_10 = narrow_2_to_1_aw_max_latency;
    assign lat_11 = narrow_2_to_1_w_max_latency;
    assign lat_12 = narrow_2_to_1_b_max_latency;
    assign lat_13 = narrow_2_to_1_ar_max_latency;
    assign lat_14 = narrow_2_to_1_r_max_latency;
    assign lat_15 = narrow_2_to_1_aw_min_latency;
    assign lat_16 = narrow_2_to_1_w_min_latency;
    assign lat_17 = narrow_2_to_1_b_min_latency;
    assign lat_18 = narrow_2_to_1_ar_min_latency;
    assign lat_19 = narrow_2_to_1_r_min_latency;



    // ===================================
    //    i_wide_channel_compare_1_to_2
    // ===================================
    int wide_1_to_2_aw_sent [$];
    int wide_1_to_2_w_sent  [$];
    int wide_1_to_2_b_sent  [$];
    int wide_1_to_2_ar_sent [$];
    int wide_1_to_2_r_sent  [$];
    int wide_1_to_2_aw_max_latency = 0;
    int wide_1_to_2_w_max_latency  = 0;
    int wide_1_to_2_b_max_latency  = 0;
    int wide_1_to_2_ar_max_latency = 0;
    int wide_1_to_2_r_max_latency  = 0;
    int wide_1_to_2_aw_min_latency = 2147483640;
    int wide_1_to_2_w_min_latency  = 2147483640;
    int wide_1_to_2_b_min_latency  = 2147483640;
    int wide_1_to_2_ar_min_latency = 2147483640;
    int wide_1_to_2_r_min_latency  = 2147483640;

    always_ff @(posedge i_wide_channel_compare_1_to_2.clk_a_i) begin : wide_1_to_2_req_sent
      // aw sent
      if (i_wide_channel_compare_1_to_2.axi_a_req.aw_valid & i_wide_channel_compare_1_to_2.axi_a_res.aw_ready)
        wide_1_to_2_aw_sent.push_back($time);
      // w sent
      if (i_wide_channel_compare_1_to_2.axi_a_req.w_valid & i_wide_channel_compare_1_to_2.axi_a_res.w_ready)
        wide_1_to_2_w_sent.push_back($time);
      // ar sent
      if (i_wide_channel_compare_1_to_2.axi_a_req.ar_valid & i_wide_channel_compare_1_to_2.axi_a_res.ar_ready)
        wide_1_to_2_ar_sent.push_back($time);
    end
    always_ff @(posedge i_wide_channel_compare_1_to_2.clk_b_i) begin : wide_1_to_2_res_sent
      // b sent
      if (i_wide_channel_compare_1_to_2.axi_b_res.b_valid & i_wide_channel_compare_1_to_2.axi_b_req.b_ready)
        wide_1_to_2_b_sent.push_back($time);
      // r sent
      if (i_wide_channel_compare_1_to_2.axi_b_res.r_valid & i_wide_channel_compare_1_to_2.axi_b_req.r_ready)
        wide_1_to_2_r_sent.push_back($time);
    end
    always_ff @(posedge i_wide_channel_compare_1_to_2.clk_b_i) begin : wide_1_to_2_req_received
      // aw received
      if (i_wide_channel_compare_1_to_2.axi_b_req.aw_valid & i_wide_channel_compare_1_to_2.axi_b_res.aw_ready) begin
        automatic int required_time;
        required_time = $time - wide_1_to_2_aw_sent.pop_front();
        if (required_time > wide_1_to_2_aw_max_latency) wide_1_to_2_aw_max_latency = required_time;
        if (required_time < wide_1_to_2_aw_min_latency) wide_1_to_2_aw_min_latency = required_time;
      end
      // w received
      if (i_wide_channel_compare_1_to_2.axi_b_req.w_valid & i_wide_channel_compare_1_to_2.axi_b_res.w_ready) begin
        automatic int required_time;
        required_time = $time - wide_1_to_2_w_sent.pop_front();
        if (required_time > wide_1_to_2_w_max_latency) wide_1_to_2_w_max_latency = required_time;
        if (required_time < wide_1_to_2_w_min_latency) wide_1_to_2_w_min_latency = required_time;
      end
      // ar received
      if (i_wide_channel_compare_1_to_2.axi_b_req.ar_valid & i_wide_channel_compare_1_to_2.axi_b_res.ar_ready) begin
        automatic int required_time;
        required_time = $time - wide_1_to_2_ar_sent.pop_front();
        if (required_time > wide_1_to_2_ar_max_latency) wide_1_to_2_ar_max_latency = required_time;
        if (required_time < wide_1_to_2_ar_min_latency) wide_1_to_2_ar_min_latency = required_time;
      end
    end
    always_ff @(posedge i_wide_channel_compare_1_to_2.clk_a_i) begin : wide_1_to_2_res_received
      // b received
      if (i_wide_channel_compare_1_to_2.axi_a_res.b_valid & i_wide_channel_compare_1_to_2.axi_a_req.b_ready) begin
        automatic int required_time;
        required_time = $time - wide_1_to_2_b_sent.pop_front();
        if (required_time > wide_1_to_2_b_max_latency) wide_1_to_2_b_max_latency = required_time;
        if (required_time < wide_1_to_2_b_min_latency) wide_1_to_2_b_min_latency = required_time;
      end
      // r received
      if (i_wide_channel_compare_1_to_2.axi_a_res.r_valid & i_wide_channel_compare_1_to_2.axi_a_req.r_ready) begin
        automatic int required_time;
        required_time = $time - wide_1_to_2_r_sent.pop_front();
        if (required_time > wide_1_to_2_r_max_latency) wide_1_to_2_r_max_latency = required_time;
        if (required_time < wide_1_to_2_r_min_latency) wide_1_to_2_r_min_latency = required_time;
      end
    end

    assign lat_20 = wide_1_to_2_aw_max_latency;
    assign lat_21 = wide_1_to_2_w_max_latency;
    assign lat_22 = wide_1_to_2_b_max_latency;
    assign lat_23 = wide_1_to_2_ar_max_latency;
    assign lat_24 = wide_1_to_2_r_max_latency;
    assign lat_25 = wide_1_to_2_aw_min_latency;
    assign lat_26 = wide_1_to_2_w_min_latency;
    assign lat_27 = wide_1_to_2_b_min_latency;
    assign lat_28 = wide_1_to_2_ar_min_latency;
    assign lat_29 = wide_1_to_2_r_min_latency;



    // ===================================
    //    i_wide_channel_compare_2_to_1
    // ===================================
    int wide_2_to_1_aw_sent [$];
    int wide_2_to_1_w_sent  [$];
    int wide_2_to_1_b_sent  [$];
    int wide_2_to_1_ar_sent [$];
    int wide_2_to_1_r_sent  [$];
    int wide_2_to_1_aw_max_latency = 0;
    int wide_2_to_1_w_max_latency  = 0;
    int wide_2_to_1_b_max_latency  = 0;
    int wide_2_to_1_ar_max_latency = 0;
    int wide_2_to_1_r_max_latency  = 0;
    int wide_2_to_1_aw_min_latency = 2147483640;
    int wide_2_to_1_w_min_latency  = 2147483640;
    int wide_2_to_1_b_min_latency  = 2147483640;
    int wide_2_to_1_ar_min_latency = 2147483640;
    int wide_2_to_1_r_min_latency  = 2147483640;

    always_ff @(posedge i_wide_channel_compare_2_to_1.clk_a_i) begin : wide_2_to_1_req_sent
      // aw sent
      if (i_wide_channel_compare_2_to_1.axi_a_req.aw_valid & i_wide_channel_compare_2_to_1.axi_a_res.aw_ready)
        wide_2_to_1_aw_sent.push_back($time);
      // w sent
      if (i_wide_channel_compare_2_to_1.axi_a_req.w_valid & i_wide_channel_compare_2_to_1.axi_a_res.w_ready)
        wide_2_to_1_w_sent.push_back($time);
      // ar sent
      if (i_wide_channel_compare_2_to_1.axi_a_req.ar_valid & i_wide_channel_compare_2_to_1.axi_a_res.ar_ready)
        wide_2_to_1_ar_sent.push_back($time);
    end
    always_ff @(posedge i_wide_channel_compare_2_to_1.clk_b_i) begin : wide_2_to_1_res_sent
      // b sent
      if (i_wide_channel_compare_2_to_1.axi_b_res.b_valid & i_wide_channel_compare_2_to_1.axi_b_req.b_ready)
        wide_2_to_1_b_sent.push_back($time);
      // r sent
      if (i_wide_channel_compare_2_to_1.axi_b_res.r_valid & i_wide_channel_compare_2_to_1.axi_b_req.r_ready)
        wide_2_to_1_r_sent.push_back($time);
    end
    always_ff @(posedge i_wide_channel_compare_2_to_1.clk_b_i) begin : wide_2_to_1_req_received
      // aw received
      if (i_wide_channel_compare_2_to_1.axi_b_req.aw_valid & i_wide_channel_compare_2_to_1.axi_b_res.aw_ready) begin
        automatic int required_time;
        required_time = $time - wide_2_to_1_aw_sent.pop_front();
        if (required_time > wide_2_to_1_aw_max_latency) wide_2_to_1_aw_max_latency = required_time;
        if (required_time < wide_2_to_1_aw_min_latency) wide_2_to_1_aw_min_latency = required_time;
      end
      // w received
      if (i_wide_channel_compare_2_to_1.axi_b_req.w_valid & i_wide_channel_compare_2_to_1.axi_b_res.w_ready) begin
        automatic int required_time;
        required_time = $time - wide_2_to_1_w_sent.pop_front();
        if (required_time > wide_2_to_1_w_max_latency) wide_2_to_1_w_max_latency = required_time;
        if (required_time < wide_2_to_1_w_min_latency) wide_2_to_1_w_min_latency = required_time;
      end
      // ar received
      if (i_wide_channel_compare_2_to_1.axi_b_req.ar_valid & i_wide_channel_compare_2_to_1.axi_b_res.ar_ready) begin
        automatic int required_time;
        required_time = $time - wide_2_to_1_ar_sent.pop_front();
        if (required_time > wide_2_to_1_ar_max_latency) wide_2_to_1_ar_max_latency = required_time;
        if (required_time < wide_2_to_1_ar_min_latency) wide_2_to_1_ar_min_latency = required_time;
      end
    end
    always_ff @(posedge i_wide_channel_compare_2_to_1.clk_a_i) begin : wide_2_to_1_res_received
      // b received
      if (i_wide_channel_compare_2_to_1.axi_a_res.b_valid & i_wide_channel_compare_2_to_1.axi_a_req.b_ready) begin
        automatic int required_time;
        required_time = $time - wide_2_to_1_b_sent.pop_front();
        if (required_time > wide_2_to_1_b_max_latency) wide_2_to_1_b_max_latency = required_time;
        if (required_time < wide_2_to_1_b_min_latency) wide_2_to_1_b_min_latency = required_time;
      end
      // r received
      if (i_wide_channel_compare_2_to_1.axi_a_res.r_valid & i_wide_channel_compare_2_to_1.axi_a_req.r_ready) begin
        automatic int required_time;
        required_time = $time - wide_2_to_1_r_sent.pop_front();
        if (required_time > wide_2_to_1_r_max_latency) wide_2_to_1_r_max_latency = required_time;
        if (required_time < wide_2_to_1_r_min_latency) wide_2_to_1_r_min_latency = required_time;
      end
    end

    assign lat_30 = wide_2_to_1_aw_max_latency;
    assign lat_31 = wide_2_to_1_w_max_latency;
    assign lat_32 = wide_2_to_1_b_max_latency;
    assign lat_33 = wide_2_to_1_ar_max_latency;
    assign lat_34 = wide_2_to_1_r_max_latency;
    assign lat_35 = wide_2_to_1_aw_min_latency;
    assign lat_36 = wide_2_to_1_w_min_latency;
    assign lat_37 = wide_2_to_1_b_min_latency;
    assign lat_38 = wide_2_to_1_ar_min_latency;
    assign lat_39 = wide_2_to_1_r_min_latency;


    ////////////////////////////////
    //  benchmarking header-info  //
    ////////////////////////////////

    // Helper objects to read out the different fields of the types
    narrow_axi_rand_master_t test_object_narrow_axi_rand_master;
    narrow_axi_rand_slave_t test_object_narrow_axi_rand_slave;
    wide_axi_rand_master_t test_object_wide_axi_rand_master;
    wide_axi_rand_slave_t test_object_wide_axi_rand_slave;

    // print out relevant information concerning the configuration and selected parameters for the respective benchmarking run
    initial begin
      $display("settings: latency_of_delay_module;%0d_ns bandwidth_physical_channel;%0d_bits_per_offchip_rising_clockedge number_of_channels;%0d \
number_of_lanes;%0d max_data_transfer_size;%0d_bits data_link_stream_fifo_depth;%0d",
      i_serial_link_0.i_signal_shifter.delay, i_serial_link_0.i_serial_link_data_link.BandWidth, i_serial_link_0.i_serial_link_data_link.NumChannels,
      i_serial_link_0.i_serial_link_data_link.NumLanes, i_serial_link_0.i_serial_link_data_link.MaxNumOfBitsToBeTransfered,
      i_serial_link_0.i_serial_link_data_link.RecvFifoDepth);

      $display("rand_device: narrow_axi_rand_master_t.AW$%0d", test_object_narrow_axi_rand_master.AW);
      $display("rand_device: narrow_axi_rand_master_t.DW$%0d", test_object_narrow_axi_rand_master.DW);
      $display("rand_device: narrow_axi_rand_master_t.IW$%0d", test_object_narrow_axi_rand_master.IW);
      $display("rand_device: narrow_axi_rand_master_t.UW$%0d", test_object_narrow_axi_rand_master.UW);
      $display("rand_device: narrow_axi_rand_master_t.TA$%0d", test_object_narrow_axi_rand_master.TA);
      $display("rand_device: narrow_axi_rand_master_t.TT$%0d", test_object_narrow_axi_rand_master.TT);
      $display("rand_device: narrow_axi_rand_master_t.MAX_READ_TXNS$%0d", test_object_narrow_axi_rand_master.MAX_READ_TXNS);
      $display("rand_device: narrow_axi_rand_master_t.MAX_WRITE_TXNS$%0d", test_object_narrow_axi_rand_master.MAX_WRITE_TXNS);
      $display("rand_device: narrow_axi_rand_master_t.AX_MIN_WAIT_CYCLES$%0d", test_object_narrow_axi_rand_master.AX_MIN_WAIT_CYCLES);
      $display("rand_device: narrow_axi_rand_master_t.AX_MAX_WAIT_CYCLES$%0d", test_object_narrow_axi_rand_master.AX_MAX_WAIT_CYCLES);
      $display("rand_device: narrow_axi_rand_master_t.W_MIN_WAIT_CYCLES$%0d", test_object_narrow_axi_rand_master.W_MIN_WAIT_CYCLES);
      $display("rand_device: narrow_axi_rand_master_t.W_MAX_WAIT_CYCLES$%0d", test_object_narrow_axi_rand_master.W_MAX_WAIT_CYCLES);
      $display("rand_device: narrow_axi_rand_master_t.RESP_MIN_WAIT_CYCLES$%0d", test_object_narrow_axi_rand_master.RESP_MIN_WAIT_CYCLES);
      $display("rand_device: narrow_axi_rand_master_t.RESP_MAX_WAIT_CYCLES$%0d", test_object_narrow_axi_rand_master.RESP_MAX_WAIT_CYCLES);
      $display("rand_device: narrow_axi_rand_master_t.TRAFFIC_SHAPING$%0d", test_object_narrow_axi_rand_master.TRAFFIC_SHAPING);
      $display("rand_device: narrow_axi_rand_master_t.AXI_EXCLS$%0d", test_object_narrow_axi_rand_master.AXI_EXCLS);
      $display("rand_device: narrow_axi_rand_master_t.AXI_ATOPS$%0d", test_object_narrow_axi_rand_master.AXI_ATOPS);
      $display("rand_device: narrow_axi_rand_master_t.AXI_BURST_FIXED$%0d", test_object_narrow_axi_rand_master.AXI_BURST_FIXED);
      $display("rand_device: narrow_axi_rand_master_t.AXI_BURST_INCR$%0d", test_object_narrow_axi_rand_master.AXI_BURST_INCR);
      $display("rand_device: narrow_axi_rand_master_t.AXI_BURST_WRAP$%0d", test_object_narrow_axi_rand_master.AXI_BURST_WRAP);

      $display("rand_device: wide_axi_rand_master_t.AW$%0d", test_object_wide_axi_rand_master.AW);
      $display("rand_device: wide_axi_rand_master_t.DW$%0d", test_object_wide_axi_rand_master.DW);
      $display("rand_device: wide_axi_rand_master_t.IW$%0d", test_object_wide_axi_rand_master.IW);
      $display("rand_device: wide_axi_rand_master_t.UW$%0d", test_object_wide_axi_rand_master.UW);
      $display("rand_device: wide_axi_rand_master_t.TA$%0d", test_object_wide_axi_rand_master.TA);
      $display("rand_device: wide_axi_rand_master_t.TT$%0d", test_object_wide_axi_rand_master.TT);
      $display("rand_device: wide_axi_rand_master_t.MAX_READ_TXNS$%0d", test_object_wide_axi_rand_master.MAX_READ_TXNS);
      $display("rand_device: wide_axi_rand_master_t.MAX_WRITE_TXNS$%0d", test_object_wide_axi_rand_master.MAX_WRITE_TXNS);
      $display("rand_device: wide_axi_rand_master_t.AX_MIN_WAIT_CYCLES$%0d", test_object_wide_axi_rand_master.AX_MIN_WAIT_CYCLES);
      $display("rand_device: wide_axi_rand_master_t.AX_MAX_WAIT_CYCLES$%0d", test_object_wide_axi_rand_master.AX_MAX_WAIT_CYCLES);
      $display("rand_device: wide_axi_rand_master_t.W_MIN_WAIT_CYCLES$%0d", test_object_wide_axi_rand_master.W_MIN_WAIT_CYCLES);
      $display("rand_device: wide_axi_rand_master_t.W_MAX_WAIT_CYCLES$%0d", test_object_wide_axi_rand_master.W_MAX_WAIT_CYCLES);
      $display("rand_device: wide_axi_rand_master_t.RESP_MIN_WAIT_CYCLES$%0d", test_object_wide_axi_rand_master.RESP_MIN_WAIT_CYCLES);
      $display("rand_device: wide_axi_rand_master_t.RESP_MAX_WAIT_CYCLES$%0d", test_object_wide_axi_rand_master.RESP_MAX_WAIT_CYCLES);
      $display("rand_device: wide_axi_rand_master_t.TRAFFIC_SHAPING$%0d", test_object_wide_axi_rand_master.TRAFFIC_SHAPING);
      $display("rand_device: wide_axi_rand_master_t.AXI_EXCLS$%0d", test_object_wide_axi_rand_master.AXI_EXCLS);
      $display("rand_device: wide_axi_rand_master_t.AXI_ATOPS$%0d", test_object_wide_axi_rand_master.AXI_ATOPS);
      $display("rand_device: wide_axi_rand_master_t.AXI_BURST_FIXED$%0d", test_object_wide_axi_rand_master.AXI_BURST_FIXED);
      $display("rand_device: wide_axi_rand_master_t.AXI_BURST_INCR$%0d", test_object_wide_axi_rand_master.AXI_BURST_INCR);
      $display("rand_device: wide_axi_rand_master_t.AXI_BURST_WRAP$%0d", test_object_wide_axi_rand_master.AXI_BURST_WRAP);

      $display("rand_device: narrow_axi_rand_slave_t.AW$%0d", test_object_narrow_axi_rand_slave.AW);
      $display("rand_device: narrow_axi_rand_slave_t.DW$%0d", test_object_narrow_axi_rand_slave.DW);
      $display("rand_device: narrow_axi_rand_slave_t.IW$%0d", test_object_narrow_axi_rand_slave.IW);
      $display("rand_device: narrow_axi_rand_slave_t.UW$%0d", test_object_narrow_axi_rand_slave.UW);
      $display("rand_device: narrow_axi_rand_slave_t.TA$%0d", test_object_narrow_axi_rand_slave.TA);
      $display("rand_device: narrow_axi_rand_slave_t.TT$%0d", test_object_narrow_axi_rand_slave.TT);
      $display("rand_device: narrow_axi_rand_slave_t.RAND_RESP$%0d", test_object_narrow_axi_rand_slave.RAND_RESP);
      $display("rand_device: narrow_axi_rand_slave_t.AX_MIN_WAIT_CYCLES$%0d", test_object_narrow_axi_rand_slave.AX_MIN_WAIT_CYCLES);
      $display("rand_device: narrow_axi_rand_slave_t.AX_MAX_WAIT_CYCLES$%0d", test_object_narrow_axi_rand_slave.AX_MAX_WAIT_CYCLES);
      $display("rand_device: narrow_axi_rand_slave_t.R_MIN_WAIT_CYCLES$%0d", test_object_narrow_axi_rand_slave.R_MIN_WAIT_CYCLES);
      $display("rand_device: narrow_axi_rand_slave_t.R_MAX_WAIT_CYCLES$%0d", test_object_narrow_axi_rand_slave.R_MAX_WAIT_CYCLES);
      $display("rand_device: narrow_axi_rand_slave_t.RESP_MIN_WAIT_CYCLES$%0d", test_object_narrow_axi_rand_slave.RESP_MIN_WAIT_CYCLES);
      $display("rand_device: narrow_axi_rand_slave_t.RESP_MAX_WAIT_CYCLES$%0d", test_object_narrow_axi_rand_slave.RESP_MAX_WAIT_CYCLES);

      $display("rand_device: wide_axi_rand_slave_t.AW$%0d", test_object_wide_axi_rand_slave.AW);
      $display("rand_device: wide_axi_rand_slave_t.DW$%0d", test_object_wide_axi_rand_slave.DW);
      $display("rand_device: wide_axi_rand_slave_t.IW$%0d", test_object_wide_axi_rand_slave.IW);
      $display("rand_device: wide_axi_rand_slave_t.UW$%0d", test_object_wide_axi_rand_slave.UW);
      $display("rand_device: wide_axi_rand_slave_t.TA$%0d", test_object_wide_axi_rand_slave.TA);
      $display("rand_device: wide_axi_rand_slave_t.TT$%0d", test_object_wide_axi_rand_slave.TT);
      $display("rand_device: wide_axi_rand_slave_t.RAND_RESP$%0d", test_object_wide_axi_rand_slave.RAND_RESP);
      $display("rand_device: wide_axi_rand_slave_t.AX_MIN_WAIT_CYCLES$%0d", test_object_wide_axi_rand_slave.AX_MIN_WAIT_CYCLES);
      $display("rand_device: wide_axi_rand_slave_t.AX_MAX_WAIT_CYCLES$%0d", test_object_wide_axi_rand_slave.AX_MAX_WAIT_CYCLES);
      $display("rand_device: wide_axi_rand_slave_t.R_MIN_WAIT_CYCLES$%0d", test_object_wide_axi_rand_slave.R_MIN_WAIT_CYCLES);
      $display("rand_device: wide_axi_rand_slave_t.R_MAX_WAIT_CYCLES$%0d", test_object_wide_axi_rand_slave.R_MAX_WAIT_CYCLES);
      $display("rand_device: wide_axi_rand_slave_t.RESP_MIN_WAIT_CYCLES$%0d", test_object_wide_axi_rand_slave.RESP_MIN_WAIT_CYCLES);
      $display("rand_device: wide_axi_rand_slave_t.RESP_MAX_WAIT_CYCLES$%0d", test_object_wide_axi_rand_slave.RESP_MAX_WAIT_CYCLES);
    end


    //////////////////////////////////
    //  valid_coverage_serial_link  //
    //////////////////////////////////

    // ===========================
    //    variable declarations
    // ===========================
    int cntr_var_serial_link_0_number_cycles = 0;
    int cntr_var_serial_link_0_valid_cycles_to_phys = 0;
    int cntr_var_serial_link_0_valid_cycles_from_phys = 0;

    int cntr_var_serial_link_1_number_cycles = 0;
    int cntr_var_serial_link_1_valid_cycles_to_phys = 0;
    int cntr_var_serial_link_1_valid_cycles_from_phys = 0;

    // ========================
    //    benchmarking logic
    // ========================
    always_ff @(posedge i_serial_link_0.clk_sl_i or negedge i_serial_link_0.rst_sl_ni) begin : valid_coverage_serial_link_0
      if (!i_serial_link_0.rst_sl_ni) begin
        cntr_var_serial_link_0_number_cycles = 0;
        cntr_var_serial_link_0_valid_cycles_to_phys = 0;
        cntr_var_serial_link_0_valid_cycles_from_phys = 0;
      end else begin
        cntr_var_serial_link_0_number_cycles++;
        if (i_serial_link_0.alloc2phy_data_out_valid) begin
          cntr_var_serial_link_0_valid_cycles_to_phys++;
        end
        if (i_serial_link_0.phy2alloc_data_in_valid) begin
          cntr_var_serial_link_0_valid_cycles_from_phys++;
        end
      end
    end

    always_ff @(posedge i_serial_link_1.clk_sl_i or negedge i_serial_link_1.rst_sl_ni) begin : valid_coverage_serial_link_1
      if (!i_serial_link_1.rst_sl_ni) begin
        cntr_var_serial_link_1_number_cycles = 0;
        cntr_var_serial_link_1_valid_cycles_to_phys = 0;
        cntr_var_serial_link_1_valid_cycles_from_phys = 0;
      end else begin
        cntr_var_serial_link_1_number_cycles++;
        if (i_serial_link_1.alloc2phy_data_out_valid) begin
          cntr_var_serial_link_1_valid_cycles_to_phys++;
        end
        if (i_serial_link_1.phy2alloc_data_in_valid) begin
          cntr_var_serial_link_1_valid_cycles_from_phys++;
        end
      end
    end

    // ======================
    //    port assignments
    // ======================
    always_comb begin : serial_link_port_assignments
      serial_link_0_number_cycles          = cntr_var_serial_link_0_number_cycles;
      serial_link_0_valid_cycles_to_phys   = cntr_var_serial_link_0_valid_cycles_to_phys;
      serial_link_0_valid_cycles_from_phys = cntr_var_serial_link_0_valid_cycles_from_phys;

      serial_link_1_number_cycles          = cntr_var_serial_link_1_number_cycles;
      serial_link_1_valid_cycles_to_phys   = cntr_var_serial_link_1_valid_cycles_to_phys;
      serial_link_1_valid_cycles_from_phys = cntr_var_serial_link_1_valid_cycles_from_phys;
    end


    ////////////////////////////////
    //  valid_coverage_data_link  //
    ////////////////////////////////

    // ===========================
    //    variable declarations
    // ===========================
    int cntr_var_data_link_0_num_cred_only_pack_sent    = 0;
    int cntr_var_data_link_0_sum_stalled_cyc_cred_cntrs = 0;

    int cntr_var_data_link_1_num_cred_only_pack_sent    = 0;
    int cntr_var_data_link_1_sum_stalled_cyc_cred_cntrs = 0;

    // ========================
    //    benchmarking logic
    // ========================
    always_ff @(posedge i_serial_link_0.i_serial_link_data_link.clk_i or negedge i_serial_link_0.i_serial_link_data_link.rst_ni) begin : valid_coverage_data_link_0
      if (!i_serial_link_0.i_serial_link_data_link.rst_ni) begin
        cntr_var_data_link_0_num_cred_only_pack_sent    = 0;
        cntr_var_data_link_0_sum_stalled_cyc_cred_cntrs = 0;
      end else begin
        if (i_serial_link_0.i_serial_link_data_link.send_hdr.is_credits_only && i_serial_link_0.i_serial_link_data_link.axis_in_req_tvalid_afterFlowControl &&
        i_serial_link_0.i_serial_link_data_link.axis_in_rsp_tready_afterFlowControl) begin
          cntr_var_data_link_0_num_cred_only_pack_sent++;
        end
        if (i_serial_link_0.i_serial_link_data_link.axis_in_req_i.tvalid && !i_serial_link_0.i_serial_link_data_link.axis_in_req_tvalid_afterFlowControl) begin
          cntr_var_data_link_0_sum_stalled_cyc_cred_cntrs++;
        end
      end
    end

    always_ff @(posedge i_serial_link_1.i_serial_link_data_link.clk_i or negedge i_serial_link_1.i_serial_link_data_link.rst_ni) begin : valid_coverage_data_link_1
      if (!i_serial_link_1.i_serial_link_data_link.rst_ni) begin
        cntr_var_data_link_1_num_cred_only_pack_sent    = 0;
        cntr_var_data_link_1_sum_stalled_cyc_cred_cntrs = 0;
      end else begin
        if (i_serial_link_1.i_serial_link_data_link.send_hdr.is_credits_only && i_serial_link_1.i_serial_link_data_link.axis_in_req_tvalid_afterFlowControl &&
        i_serial_link_1.i_serial_link_data_link.axis_in_rsp_tready_afterFlowControl) begin
          cntr_var_data_link_1_num_cred_only_pack_sent++;
        end
        if (i_serial_link_1.i_serial_link_data_link.axis_in_req_i.tvalid && !i_serial_link_1.i_serial_link_data_link.axis_in_req_tvalid_afterFlowControl) begin
          cntr_var_data_link_1_sum_stalled_cyc_cred_cntrs++;
        end
      end
    end

    // ======================
    //    port assignments
    // ======================
    always_comb begin : data_link_port_assignments
      data_link_0_num_cred_only_pack_sent    = cntr_var_data_link_0_num_cred_only_pack_sent;
      data_link_0_sum_stalled_cyc_cred_cntrs = cntr_var_data_link_0_sum_stalled_cyc_cred_cntrs;

      data_link_1_num_cred_only_pack_sent    = cntr_var_data_link_1_num_cred_only_pack_sent;
      data_link_1_sum_stalled_cyc_cred_cntrs = cntr_var_data_link_1_sum_stalled_cyc_cred_cntrs;
    end


    //////////////////////////////
    //  valid_coverage_network  //
    //////////////////////////////

    if (i_serial_link_0.BridgeVirtualChannels) begin
      // ===========================
      //    variable declarations
      // ===========================
      int cntr_var_network_0_number_cycles = 0;
      int cntr_var_network_0_valid_cycles_to_phys = 0;
      int cntr_var_network_0_valid_cycles_from_phys = 0;
      int cntr_var_network_0_num_cred_only_pack_sent = 0;
      int cntr_var_network_0_sum_stalled_cyc_cred_cntrs = 0;

      int cntr_var_network_1_number_cycles = 0;
      int cntr_var_network_1_valid_cycles_to_phys = 0;
      int cntr_var_network_1_valid_cycles_from_phys = 0;
      int cntr_var_network_1_num_cred_only_pack_sent = 0;
      int cntr_var_network_1_sum_stalled_cyc_cred_cntrs = 0;

      // ========================
      //    benchmarking logic
      // ========================
      always_ff @(posedge i_serial_link_0.bridge.i_serial_link_network.clk_i or negedge i_serial_link_0.bridge.i_serial_link_network.rst_ni) begin : valid_coverage_network_0
        if (!i_serial_link_0.bridge.i_serial_link_network.rst_ni) begin
          cntr_var_network_0_number_cycles = 0;
          cntr_var_network_0_valid_cycles_to_phys = 0;
          cntr_var_network_0_valid_cycles_from_phys = 0;
          cntr_var_network_0_num_cred_only_pack_sent = 0;
          cntr_var_network_0_sum_stalled_cyc_cred_cntrs = 0;
        end else begin
          cntr_var_network_0_number_cycles++;
          if (i_serial_link_0.bridge.i_serial_link_network.narrow_req_i.valid || i_serial_link_0.bridge.i_serial_link_network.narrow_rsp_i.valid ||
          i_serial_link_0.bridge.i_serial_link_network.wide_i.valid) begin
            cntr_var_network_0_valid_cycles_to_phys++;
          end
          if (i_serial_link_0.bridge.i_serial_link_network.axis_in_req_i.tvalid) begin
            cntr_var_network_0_valid_cycles_from_phys++;
          end
          if (i_serial_link_0.bridge.i_serial_link_network.axis_out_rsp_i.tready && i_serial_link_0.bridge.i_serial_link_network.axis_out_req_o.tvalid &&
          i_serial_link_0.bridge.i_serial_link_network.narrow_wide_axis_out.data_validity == 0) begin
            cntr_var_network_0_num_cred_only_pack_sent++;
          end
          if ((i_serial_link_0.bridge.i_serial_link_network.wide_i.valid && !i_serial_link_0.bridge.i_serial_link_network.wide_valid_synchr_out) ||
          (i_serial_link_0.bridge.i_serial_link_network.narrow_rsp_i.valid && !i_serial_link_0.bridge.i_serial_link_network.rsp_valid_synchr_out) ||
          (i_serial_link_0.bridge.i_serial_link_network.narrow_req_i.valid && !i_serial_link_0.bridge.i_serial_link_network.req_valid_synchr_out)) begin
            cntr_var_network_0_sum_stalled_cyc_cred_cntrs++;
          end
        end
      end

      always_ff @(posedge i_serial_link_1.bridge.i_serial_link_network.clk_i or negedge i_serial_link_1.bridge.i_serial_link_network.rst_ni) begin : valid_coverage_network_1
        if (!i_serial_link_1.bridge.i_serial_link_network.rst_ni) begin
          cntr_var_network_1_number_cycles = 0;
          cntr_var_network_1_valid_cycles_to_phys = 0;
          cntr_var_network_1_valid_cycles_from_phys = 0;
          cntr_var_network_1_num_cred_only_pack_sent = 0;
          cntr_var_network_1_sum_stalled_cyc_cred_cntrs = 0;
        end else begin
          cntr_var_network_1_number_cycles++;
          if (i_serial_link_1.bridge.i_serial_link_network.narrow_req_i.valid || i_serial_link_1.bridge.i_serial_link_network.narrow_rsp_i.valid ||
          i_serial_link_1.bridge.i_serial_link_network.wide_i.valid) begin
            cntr_var_network_1_valid_cycles_to_phys++;
          end
          if (i_serial_link_1.bridge.i_serial_link_network.axis_in_req_i.tvalid) begin
            cntr_var_network_1_valid_cycles_from_phys++;
          end
          if (i_serial_link_1.bridge.i_serial_link_network.axis_out_rsp_i.tready && i_serial_link_1.bridge.i_serial_link_network.axis_out_req_o.tvalid &&
          i_serial_link_1.bridge.i_serial_link_network.narrow_wide_axis_out.data_validity == 0) begin
            cntr_var_network_1_num_cred_only_pack_sent++;
          end
          if ((i_serial_link_1.bridge.i_serial_link_network.wide_i.valid && !i_serial_link_1.bridge.i_serial_link_network.wide_valid_synchr_out) ||
          (i_serial_link_1.bridge.i_serial_link_network.narrow_rsp_i.valid && !i_serial_link_1.bridge.i_serial_link_network.rsp_valid_synchr_out) ||
          (i_serial_link_1.bridge.i_serial_link_network.narrow_req_i.valid && !i_serial_link_1.bridge.i_serial_link_network.req_valid_synchr_out)) begin
            cntr_var_network_1_sum_stalled_cyc_cred_cntrs++;
          end
        end
      end

      // ======================
      //    port assignments
      // ======================
      always_comb begin : network_port_assignments
        network_0_number_cycles              = cntr_var_network_0_number_cycles;
        network_0_valid_cycles_to_phys       = cntr_var_network_0_valid_cycles_to_phys;
        network_0_valid_cycles_from_phys     = cntr_var_network_0_valid_cycles_from_phys;
        network_0_num_cred_only_pack_sent    = cntr_var_network_0_num_cred_only_pack_sent;
        network_0_sum_stalled_cyc_cred_cntrs = cntr_var_network_0_sum_stalled_cyc_cred_cntrs;

        network_1_number_cycles              = cntr_var_network_1_number_cycles;
        network_1_valid_cycles_to_phys       = cntr_var_network_1_valid_cycles_to_phys;
        network_1_valid_cycles_from_phys     = cntr_var_network_1_valid_cycles_from_phys;
        network_1_num_cred_only_pack_sent    = cntr_var_network_1_num_cred_only_pack_sent;
        network_1_sum_stalled_cyc_cred_cntrs = cntr_var_network_1_sum_stalled_cyc_cred_cntrs;
      end
    end
  `endif

endmodule
