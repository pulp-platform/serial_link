// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
//  - Yannick Baumann <baumanny@ethz.student.ch>

// This benchmarking unit is to be used in the tb_floo_serial_link_narrow_wide.sv
// testbench in combination with the analyzePerformance.tcl script.
module serial_link_benchmarking_unit #(
) (
  output logic[31:0] serial_link_0_number_cycles,
  output logic[31:0] serial_link_0_valid_cycles_to_phys,
  output logic[31:0] serial_link_0_valid_cycles_from_phys,
  output logic[31:0] serial_link_1_number_cycles,
  output logic[31:0] serial_link_1_valid_cycles_to_phys,
  output logic[31:0] serial_link_1_valid_cycles_from_phys,
  output logic[31:0] data_link_0_num_cred_only_pack_sent,
  output logic[31:0] data_link_1_num_cred_only_pack_sent,
  output logic[31:0] network_0_number_cycles,
  output logic[31:0] network_0_valid_cycles_to_phys,
  output logic[31:0] network_0_valid_cycles_from_phys,
  output logic[31:0] network_0_num_cred_only_pack_sent,
  output logic[31:0] network_0_sum_stalled_cyc_cred_cntrs,
  output logic[31:0] network_1_number_cycles,
  output logic[31:0] network_1_valid_cycles_to_phys,
  output logic[31:0] network_1_valid_cycles_from_phys,
  output logic[31:0] network_1_num_cred_only_pack_sent,
  output logic[31:0] network_1_sum_stalled_cyc_cred_cntrs
);


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
  int cntr_var_data_link_0_num_cred_only_pack_sent = 0;

  int cntr_var_data_link_1_num_cred_only_pack_sent = 0;

  // ========================
  //    benchmarking logic
  // ========================
  always_ff @(posedge i_serial_link_0.i_serial_link_data_link.clk_i or negedge i_serial_link_0.i_serial_link_data_link.rst_ni) begin : valid_coverage_data_link_0
    if (!i_serial_link_0.i_serial_link_data_link.rst_ni) begin
      cntr_var_data_link_0_num_cred_only_pack_sent = 0;
    end else begin
      if (i_serial_link_0.i_serial_link_data_link.send_hdr.is_credits_only && i_serial_link_0.i_serial_link_data_link.axis_in_req_tvalid_afterFlowControl && i_serial_link_0.i_serial_link_data_link.axis_in_rsp_tready_afterFlowControl) begin
        cntr_var_data_link_0_num_cred_only_pack_sent++;
      end
    end
  end

  always_ff @(posedge i_serial_link_1.i_serial_link_data_link.clk_i or negedge i_serial_link_1.i_serial_link_data_link.rst_ni) begin : valid_coverage_data_link_1
    if (!i_serial_link_1.i_serial_link_data_link.rst_ni) begin
      cntr_var_data_link_1_num_cred_only_pack_sent = 0;
    end else begin
      if (i_serial_link_1.i_serial_link_data_link.send_hdr.is_credits_only && i_serial_link_1.i_serial_link_data_link.axis_in_req_tvalid_afterFlowControl && i_serial_link_1.i_serial_link_data_link.axis_in_rsp_tready_afterFlowControl) begin
        cntr_var_data_link_1_num_cred_only_pack_sent++;
      end
    end
  end

  // ======================
  //    port assignments
  // ======================
  always_comb begin : data_link_port_assignments
    data_link_0_num_cred_only_pack_sent = cntr_var_data_link_0_num_cred_only_pack_sent;

    data_link_1_num_cred_only_pack_sent = cntr_var_data_link_1_num_cred_only_pack_sent;
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
        if (i_serial_link_0.bridge.i_serial_link_network.narrow_req_i.valid || i_serial_link_0.bridge.i_serial_link_network.narrow_rsp_i.valid || i_serial_link_0.bridge.i_serial_link_network.wide_i.valid) begin
          cntr_var_network_0_valid_cycles_to_phys++;
        end
        if (i_serial_link_0.bridge.i_serial_link_network.axis_in_req_i.tvalid) begin
          cntr_var_network_0_valid_cycles_from_phys++;
        end
        if (i_serial_link_0.bridge.i_serial_link_network.axis_out_rsp_i.tready && i_serial_link_0.bridge.i_serial_link_network.axis_out_req_o.tvalid && i_serial_link_0.bridge.i_serial_link_network.narrow_wide_axis_out.data_validity == 0) begin
          cntr_var_network_0_num_cred_only_pack_sent++;
        end
        if ((i_serial_link_0.bridge.i_serial_link_network.wide_i.valid && !i_serial_link_0.bridge.i_serial_link_network.wide_valid_synchr_out) || (i_serial_link_0.bridge.i_serial_link_network.narrow_rsp_i.valid && !i_serial_link_0.bridge.i_serial_link_network.rsp_valid_synchr_out) || (i_serial_link_0.bridge.i_serial_link_network.narrow_req_i.valid && !i_serial_link_0.bridge.i_serial_link_network.req_valid_synchr_out)) begin
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
        if (i_serial_link_1.bridge.i_serial_link_network.narrow_req_i.valid || i_serial_link_1.bridge.i_serial_link_network.narrow_rsp_i.valid || i_serial_link_1.bridge.i_serial_link_network.wide_i.valid) begin
          cntr_var_network_1_valid_cycles_to_phys++;
        end
        if (i_serial_link_1.bridge.i_serial_link_network.axis_in_req_i.tvalid) begin
          cntr_var_network_1_valid_cycles_from_phys++;
        end
        if (i_serial_link_1.bridge.i_serial_link_network.axis_out_rsp_i.tready && i_serial_link_1.bridge.i_serial_link_network.axis_out_req_o.tvalid && i_serial_link_1.bridge.i_serial_link_network.narrow_wide_axis_out.data_validity == 0) begin
          cntr_var_network_1_num_cred_only_pack_sent++;
        end
        if ((i_serial_link_1.bridge.i_serial_link_network.wide_i.valid && !i_serial_link_1.bridge.i_serial_link_network.wide_valid_synchr_out) || (i_serial_link_1.bridge.i_serial_link_network.narrow_rsp_i.valid && !i_serial_link_1.bridge.i_serial_link_network.rsp_valid_synchr_out) || (i_serial_link_1.bridge.i_serial_link_network.narrow_req_i.valid && !i_serial_link_1.bridge.i_serial_link_network.req_valid_synchr_out)) begin
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

endmodule
