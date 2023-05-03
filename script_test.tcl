# This script was generated automatically by bender.
set ROOT "/home/msc23f11/serial_link"

if {[catch {vlog -incr -sv \
    +define+TARGET_SIMULATION \
    +define+TARGET_VSIM \
    "$ROOT/.bender/git/checkouts/common_verification-b9b3d4314a9056c5/src/clk_rst_gen.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-b9b3d4314a9056c5/src/rand_id_queue.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-b9b3d4314a9056c5/src/rand_stream_mst.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-b9b3d4314a9056c5/src/rand_synch_holdable_driver.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-b9b3d4314a9056c5/src/rand_verif_pkg.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-b9b3d4314a9056c5/src/signal_highlighter.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-b9b3d4314a9056c5/src/sim_timeout.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-b9b3d4314a9056c5/src/stream_watchdog.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-b9b3d4314a9056c5/src/rand_synch_driver.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-b9b3d4314a9056c5/src/rand_stream_slv.sv"
}]} {return 1}

if {[catch {vlog -incr -sv \
    +define+TARGET_SIMULATION \
    +define+TARGET_VSIM \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-239be677936a4ff9/src/rtl/tc_sram.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-239be677936a4ff9/src/rtl/tc_sram_impl.sv"
}]} {return 1}

if {[catch {vlog -incr -sv \
    +define+TARGET_SIMULATION \
    +define+TARGET_VSIM \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-239be677936a4ff9/src/rtl/tc_clk.sv"
}]} {return 1}

if {[catch {vlog -incr -sv \
    +define+TARGET_SIMULATION \
    +define+TARGET_VSIM \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-239be677936a4ff9/src/deprecated/cluster_pwr_cells.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-239be677936a4ff9/src/deprecated/generic_memory.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-239be677936a4ff9/src/deprecated/generic_rom.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-239be677936a4ff9/src/deprecated/pad_functional.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-239be677936a4ff9/src/deprecated/pulp_buffer.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-239be677936a4ff9/src/deprecated/pulp_pwr_cells.sv"
}]} {return 1}

if {[catch {vlog -incr -sv \
    +define+TARGET_SIMULATION \
    +define+TARGET_VSIM \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-239be677936a4ff9/src/tc_pwr.sv"
}]} {return 1}

if {[catch {vlog -incr -sv \
    +define+TARGET_SIMULATION \
    +define+TARGET_VSIM \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-239be677936a4ff9/src/deprecated/pulp_clock_gating_async.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-239be677936a4ff9/src/deprecated/cluster_clk_cells.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-239be677936a4ff9/src/deprecated/pulp_clk_cells.sv"
}]} {return 1}

if {[catch {vlog -incr -sv \
    +define+TARGET_SIMULATION \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/include" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/binary_to_gray.sv"
}]} {return 1}

if {[catch {vlog -incr -sv \
    +define+TARGET_SIMULATION \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/include" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/cb_filter_pkg.sv"
}]} {return 1}

if {[catch {vlog -incr -sv \
    +define+TARGET_SIMULATION \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/include" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/cc_onehot.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/cf_math_pkg.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/clk_int_div.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/delta_counter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/ecc_pkg.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/edge_propagator_tx.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/exp_backoff.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/fifo_v3.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/gray_to_binary.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/isochronous_4phase_handshake.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/isochronous_spill_register.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/lfsr.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/lfsr_16bit.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/lfsr_8bit.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/mv_filter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/onehot_to_bin.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/plru_tree.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/popcount.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/rr_arb_tree.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/rstgen_bypass.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/serial_deglitch.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/shift_reg.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/shift_reg_gated.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/spill_register_flushable.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/stream_demux.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/stream_filter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/stream_fork.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/stream_intf.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/stream_join.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/stream_mux.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/stream_throttle.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/sub_per_hash.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/sync.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/sync_wedge.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/unread.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/read.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/cdc_reset_ctrlr_pkg.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/addr_decode_napot.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/cdc_2phase.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/cdc_4phase.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/addr_decode.sv"
}]} {return 1}

if {[catch {vlog -incr -sv \
    +define+TARGET_SIMULATION \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/include" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/cb_filter.sv"
}]} {return 1}

if {[catch {vlog -incr -sv \
    +define+TARGET_SIMULATION \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/include" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/cdc_fifo_2phase.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/counter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/ecc_decode.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/ecc_encode.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/edge_detect.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/lzc.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/max_counter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/rstgen.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/spill_register.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/stream_delay.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/stream_fifo.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/stream_fork_dynamic.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/clk_mux_glitch_free.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/cdc_reset_ctrlr.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/cdc_fifo_gray.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/fall_through_register.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/id_queue.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/stream_to_mem.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/stream_arbiter_flushable.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/stream_fifo_optimal_wrap.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/stream_register.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/stream_xbar.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/cdc_fifo_gray_clearable.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/cdc_2phase_clearable.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/mem_to_banks.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/stream_arbiter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/stream_omega_net.sv"
}]} {return 1}

if {[catch {vlog -incr -sv \
    +define+TARGET_SIMULATION \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/include" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/deprecated/sram.sv"
}]} {return 1}

if {[catch {vlog -incr -sv \
    +define+TARGET_SIMULATION \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/include" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/deprecated/clock_divider_counter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/deprecated/clk_div.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/deprecated/find_first_one.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/deprecated/generic_LFSR_8bit.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/deprecated/generic_fifo.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/deprecated/prioarbiter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/deprecated/pulp_sync.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/deprecated/pulp_sync_wedge.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/deprecated/rrarbiter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/deprecated/clock_divider.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/deprecated/fifo_v2.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/deprecated/fifo_v1.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/edge_propagator_ack.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/edge_propagator.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/src/edge_propagator_rx.sv"
}]} {return 1}

if {[catch {vlog -incr -sv \
    +define+TARGET_SIMULATION \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/include" \
    "+incdir+$ROOT/.bender/git/checkouts/apb-80f3858be2a80ca9/include" \
    "$ROOT/.bender/git/checkouts/apb-80f3858be2a80ca9/src/apb_pkg.sv" \
    "$ROOT/.bender/git/checkouts/apb-80f3858be2a80ca9/src/apb_intf.sv" \
    "$ROOT/.bender/git/checkouts/apb-80f3858be2a80ca9/src/apb_err_slv.sv" \
    "$ROOT/.bender/git/checkouts/apb-80f3858be2a80ca9/src/apb_regs.sv" \
    "$ROOT/.bender/git/checkouts/apb-80f3858be2a80ca9/src/apb_cdc.sv" \
    "$ROOT/.bender/git/checkouts/apb-80f3858be2a80ca9/src/apb_demux.sv"
}]} {return 1}

if {[catch {vlog -incr -sv \
    +define+TARGET_SIMULATION \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/include" \
    "+incdir+$ROOT/.bender/git/checkouts/apb-80f3858be2a80ca9/include" \
    "$ROOT/.bender/git/checkouts/apb-80f3858be2a80ca9/src/apb_test.sv"
}]} {return 1}

if {[catch {vlog -incr -sv \
    +define+TARGET_SIMULATION \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/include" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/include" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_pkg.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_intf.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_atop_filter.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_burst_splitter.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_cdc_dst.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_cdc_src.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_cut.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_delayer.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_demux.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_dw_downsizer.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_dw_upsizer.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_fifo.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_id_remap.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_id_prepend.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_isolate.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_join.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_lite_demux.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_lite_join.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_lite_lfsr.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_lite_mailbox.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_lite_mux.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_lite_regs.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_lite_to_apb.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_lite_to_axi.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_modify_address.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_mux.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_serializer.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_throttle.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_to_mem.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_cdc.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_err_slv.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_dw_converter.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_id_serialize.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_lfsr.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_multicut.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_to_axi_lite.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_to_mem_banked.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_to_mem_interleaved.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_to_mem_split.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_iw_converter.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_lite_xbar.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_xbar.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_xp.sv"
}]} {return 1}

if {[catch {vlog -incr -sv \
    +define+TARGET_SIMULATION \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/include" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/include" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_dumper.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_sim_mem.sv" \
    "$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/src/axi_test.sv"
}]} {return 1}

if {[catch {vlog -incr -sv \
    +define+TARGET_SIMULATION \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/include" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/include" \
    "+incdir+$ROOT/.bender/git/checkouts/floo_noc-7f75d94d307df533/include" \
    "$ROOT/.bender/git/checkouts/floo_noc-7f75d94d307df533/src/floo_axi_flit_pkg.sv" \
    "$ROOT/.bender/git/checkouts/floo_noc-7f75d94d307df533/src/floo_narrow_wide_flit_pkg.sv" \
    "$ROOT/.bender/git/checkouts/floo_noc-7f75d94d307df533/src/floo_pkg.sv" \
    "$ROOT/.bender/git/checkouts/floo_noc-7f75d94d307df533/src/floo_param_pkg.sv" \
    "$ROOT/.bender/git/checkouts/floo_noc-7f75d94d307df533/src/floo_cut.sv" \
    "$ROOT/.bender/git/checkouts/floo_noc-7f75d94d307df533/src/floo_fifo.sv" \
    "$ROOT/.bender/git/checkouts/floo_noc-7f75d94d307df533/src/floo_route_select.sv" \
    "$ROOT/.bender/git/checkouts/floo_noc-7f75d94d307df533/src/floo_vc_arbiter.sv" \
    "$ROOT/.bender/git/checkouts/floo_noc-7f75d94d307df533/src/floo_wormhole_arbiter.sv" \
    "$ROOT/.bender/git/checkouts/floo_noc-7f75d94d307df533/src/floo_simple_rob.sv" \
    "$ROOT/.bender/git/checkouts/floo_noc-7f75d94d307df533/src/floo_rob.sv" \
    "$ROOT/.bender/git/checkouts/floo_noc-7f75d94d307df533/src/floo_axi_chimney.sv" \
    "$ROOT/.bender/git/checkouts/floo_noc-7f75d94d307df533/src/floo_narrow_wide_chimney.sv" \
    "$ROOT/.bender/git/checkouts/floo_noc-7f75d94d307df533/src/floo_router.sv" \
    "$ROOT/.bender/git/checkouts/floo_noc-7f75d94d307df533/src/synth/floo_synth_axi_chimney.sv" \
    "$ROOT/.bender/git/checkouts/floo_noc-7f75d94d307df533/src/synth/floo_synth_narrow_wide_chimney.sv" \
    "$ROOT/.bender/git/checkouts/floo_noc-7f75d94d307df533/src/synth/floo_synth_router.sv" \
    "$ROOT/.bender/git/checkouts/floo_noc-7f75d94d307df533/src/synth/floo_synth_router_simple.sv" \
    "$ROOT/.bender/git/checkouts/floo_noc-7f75d94d307df533/src/synth/floo_synth_narrow_wide_router.sv" \
    "$ROOT/.bender/git/checkouts/floo_noc-7f75d94d307df533/src/synth/floo_synth_endpoint.sv"
}]} {return 1}

if {[catch {vlog -incr -sv \
    +define+TARGET_SIMULATION \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/include" \
    "+incdir+$ROOT/.bender/git/checkouts/apb-80f3858be2a80ca9/include" \
    "+incdir+$ROOT/.bender/git/checkouts/register_interface-0c9dbd1f93566288/include" \
    "+incdir+$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/include" \
    "$ROOT/.bender/git/checkouts/register_interface-0c9dbd1f93566288/src/reg_intf.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-0c9dbd1f93566288/vendor/lowrisc_opentitan/src/prim_subreg_arb.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-0c9dbd1f93566288/vendor/lowrisc_opentitan/src/prim_subreg_ext.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-0c9dbd1f93566288/src/apb_to_reg.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-0c9dbd1f93566288/src/axi_to_reg.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-0c9dbd1f93566288/src/periph_to_reg.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-0c9dbd1f93566288/src/reg_cdc.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-0c9dbd1f93566288/src/reg_demux.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-0c9dbd1f93566288/src/reg_err_slv.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-0c9dbd1f93566288/src/reg_mux.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-0c9dbd1f93566288/src/reg_to_apb.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-0c9dbd1f93566288/src/reg_to_mem.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-0c9dbd1f93566288/src/reg_uniform.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-0c9dbd1f93566288/src/reg_to_tlul.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-0c9dbd1f93566288/vendor/lowrisc_opentitan/src/prim_subreg_shadow.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-0c9dbd1f93566288/vendor/lowrisc_opentitan/src/prim_subreg.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-0c9dbd1f93566288/src/axi_lite_to_reg.sv"
}]} {return 1}

if {[catch {vlog -incr -sv \
    +define+TARGET_SIMULATION \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/include" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/include" \
    "+incdir+$ROOT/.bender/git/checkouts/register_interface-0c9dbd1f93566288/include" \
    "+incdir+$ROOT/.bender/git/checkouts/floo_noc-7f75d94d307df533/include" \
    "+incdir+$ROOT/src/axis/include" \
    "$ROOT/src/regs/serial_link_reg_pkg.sv" \
    "$ROOT/src/regs/serial_link_reg_top.sv" \
    "$ROOT/src/regs/serial_link_single_channel_reg_pkg.sv" \
    "$ROOT/src/regs/serial_link_single_channel_reg_top.sv" \
    "$ROOT/src/serial_link_pkg.sv" \
    "$ROOT/src/channel_allocator/stream_chopper.sv" \
    "$ROOT/src/channel_allocator/stream_dechopper.sv" \
    "$ROOT/src/channel_allocator/channel_despread_sfr.sv" \
    "$ROOT/src/channel_allocator/channel_spread_sfr.sv" \
    "$ROOT/src/channel_allocator/serial_link_channel_allocator.sv" \
    "$ROOT/src/serial_link_network.sv" \
    "$ROOT/src/serial_link_data_link.sv" \
    "$ROOT/src/serial_link_physical.sv" \
    "$ROOT/src/serial_link.sv" \
    "$ROOT/src/serial_link_occamy_wrapper.sv"
}]} {return 1}

if {[catch {vlog -incr -sv \
    +define+TARGET_SIMULATION \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/floo_noc-7f75d94d307df533/include" \
    "+incdir+$ROOT/src/axis/include" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-159565ae76c27ec7/include" \
    "+incdir+$ROOT/.bender/git/checkouts/axi-30f10c4765a62545/include" \
    "+incdir+$ROOT/.bender/git/checkouts/register_interface-0c9dbd1f93566288/include" \
    "$ROOT/test/axi_channel_compare.sv" \
    "$ROOT/test/tb_axi_serial_link.sv" \
    "$ROOT/test/tb_ch_calib_serial_link.sv" \
    "$ROOT/test/tb_stream_chopper.sv" \
    "$ROOT/test/tb_stream_chopper_dechopper.sv" \
    "$ROOT/test/tb_channel_allocator.sv"
}]} {return 1}
