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
  output logic[31:0] network_1_sum_stalled_cyc_cred_cntrs
);

  // When designs are being synthesized, the variable performSynthesis should be defined.
  // This prevents the elaboration of the benchmarking module and therefore avoids error messages.
  `ifndef performSynthesis

    // Helper objects to read out the different fields of the types
    narrow_axi_rand_master_t test_object_narrow_axi_rand_master;
    narrow_axi_rand_slave_t test_object_narrow_axi_rand_slave;
    wide_axi_rand_master_t test_object_wide_axi_rand_master;
    wide_axi_rand_slave_t test_object_wide_axi_rand_slave;

    // print out relevant information concerning the configuration and selected parameters for the respective benchmarking run
    initial begin
      $display("settings: latency_of_delay_module;%0d_ns bandwidth_physical_channel;%0d_bits_per_offchip_rising_clockedge number_of_channels;%0d \
number_of_lanes;%0d max_data_transer_size;%0d_bits data_link_stream_fifo_depth;%0d",
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
        if (i_serial_link_0.i_serial_link_data_link.send_hdr.is_credits_only && i_serial_link_0.i_serial_link_data_link.axis_in_req_tvalid_afterFlowControl && i_serial_link_0.i_serial_link_data_link.axis_in_rsp_tready_afterFlowControl) begin
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
        if (i_serial_link_1.i_serial_link_data_link.send_hdr.is_credits_only && i_serial_link_1.i_serial_link_data_link.axis_in_req_tvalid_afterFlowControl && i_serial_link_1.i_serial_link_data_link.axis_in_rsp_tready_afterFlowControl) begin
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
  `endif

endmodule
