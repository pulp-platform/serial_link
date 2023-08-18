# Copyright 2022 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Thomas Benz <tbenz@iis.ee.ethz.ch>
# Paul Scheffler <paulsc@iis.ee.ethz.ch>
# Based on scripts from:
# Fabian Schuiki <fschuiki@iis.ee.ethz.ch>
# Florian Zaruba <zarubaf@iis.ee.ethz.ch>
# Stefan Mach <smach@iis.ee.ethz.ch>
# Andreas Kurth <andkurt@iis.ee.ethz.ch>
# Synthesis constraints for common_cells in Occamy in GF12
# Dependencies: CDCs assuming distinct clock groups with -asynchronous -allow_paths

################
##   Config   ##
################
if {![info exists cc_cdc_find_clk_delays]} { set cc_cdc_find_clk_delays true }
if {![info exists cc_cdc_static_max_delay]} { set cc_cdc_static_max_delay 1.0 }
# CAREFUL: you may set this to false for debugging, but NOT for signoff!
if {![info exists cc_cdc_missing_clk_fatal]} { set cc_cdc_missing_clk_fatal false }
if {![info exists cc_cdc_missing_clk_delay]} { set cc_cdc_missing_clk_delay 1.0 }

#################
##   Helpers   ##
#################
# TODO: check somehow if src and dst clocks in asynchrounous groups?
proc find_cc_cdc_max_delay {cel cel_type} {
    global cc_cdc_find_clk_delays
    global cc_cdc_static_max_delay
    global cc_cdc_missing_clk_fatal
    global cc_cdc_missing_clk_delay
    if {!$cc_cdc_find_clk_delays} {
        puts "\[common_cells\] Information: ${cel_type} given static max_delay ${cc_cdc_static_max_delay} at ${cel}"
        return ${cc_cdc_static_max_delay}
    }
    set src_clk_obj  [get_attribute [get_pins ${cel}/src_clk_i] clocks]
    set src_clk_name [get_attribute [get_clocks ${src_clk_obj}] name]
    set src_clk_tck  [get_attribute [get_clocks ${src_clk_obj}] period]
    set dst_clk_obj  [get_attribute [get_pins ${cel}/dst_clk_i] clocks]
    set dst_clk_name [get_attribute [get_clocks ${dst_clk_obj}] name]
    set dst_clk_tck  [get_attribute [get_clocks ${dst_clk_obj}] period]
    if {$src_clk_tck ne "" && $dst_clk_tck ne ""} {
            puts "\[common_cells\] Information: ${cel_type} with src ${src_clk_name} (${src_clk_tck}) and dst ${dst_clk_name} (${dst_clk_tck}) at ${cel}"
    } else {
        if {${cc_cdc_missing_clk_fatal}} {
            puts "\[common_cells\] Error: ${cel_type} with undefined src (${src_clk_name}) or dst (${dst_clk_name}) clock at ${cel}"
            exit 67
        } else {
            puts "\[common_cells\] Warning: ${cel_type} with undefined src (${clk_name}) clock at ${cel}; defaulting on maximum delay ${cc_cdc_missing_clk_delay}"
            return ${cc_cdc_missing_clk_delay}
        }
    }
    return [expr min(${src_clk_tck}, ${dst_clk_tck})]
}

#####################
##   Constraints   ##
#####################
# Make sure generated clocks obtain periods
if {$cc_cdc_find_clk_delays} {
    puts "\[common_cells\] Information: Run update_timing to annotate periods of generated clocks"
    update_timing
}

# cdc_2phase
foreach_in_collection cel_ref [get_cells -hierarchical -filter "hdl_template==cdc_2phase"] {
    set cel [get_object_name $cel_ref]
    set mdel [find_cc_cdc_max_delay $cel {cdc_2phase}]
    set_clock_gating_objects -exclude [get_cells "$cel $cel/* $cel/*/*reg*"]
    set_ungroup                 [get_cells "$cel $cel/*"]   false
    set_boundary_optimization   [get_cells "$cel $cel/*"]   false
    set async_pins [get_pins -of_objects [get_cells "$cel $cel/*"] -filter "name=~async*"]
    set_max_delay ${mdel} -through ${async_pins} -through ${async_pins}
    set_false_path -hold -through ${async_pins} -through ${async_pins}
}

# cdc_2phase_clearable
foreach_in_collection cel_ref [get_cells -hierarchical -filter "hdl_template==cdc_2phase_clearable"] {
    set cel [get_object_name $cel_ref]
    set mdel [find_cc_cdc_max_delay $cel {cdc_2phase}]
    set_clock_gating_objects -exclude [get_cells "$cel $cel/* $cel/*/*reg*"]
    set_ungroup                 [get_cells "$cel $cel/*"]   false
    set_boundary_optimization   [get_cells "$cel $cel/*"]   false
    set async_pins [get_pins -of_objects [get_cells "$cel $cel/*"] -filter "name=~async*"]
    set_max_delay ${mdel} -through ${async_pins} -through ${async_pins}
    set_false_path -hold -through ${async_pins} -through ${async_pins}
}

# cdc_fifo_2phase (only constraints in addition to contained cdc_2phase instances)
foreach_in_collection cel_ref [get_cells -hierarchical -filter "hdl_template==cdc_fifo_2phase"] {
    set cel [get_object_name $cel_ref]
    set mdel [find_cc_cdc_max_delay $cel {cdc_fifo_2phase}]
    set async_to [get_pins  $cel/dst_data_o]
    set_clock_gating_objects -exclude [get_cells $cel]
    set_max_delay ${mdel} -to ${async_to}
    set_false_path -hold -to ${async_to}
}

# cdc_fifo_gray
foreach_in_collection cel_ref [get_cells -hierarchical -filter "hdl_template==cdc_fifo_gray"] {
    set cel [get_object_name $cel_ref]
    set mdel [find_cc_cdc_max_delay $cel {cdc_fifo_gray}]
    set_clock_gating_objects -exclude [get_cells "$cel $cel/* $cel/*/*reg*"]
    set_ungroup                 [get_cells "$cel $cel/*"]   false
    set_boundary_optimization   [get_cells "$cel $cel/*"]   false
    set async_pins [get_pins -of_objects [get_cells "$cel $cel/*"] -filter "name=~async*"]
    set_max_delay ${mdel} -through ${async_pins} -through ${async_pins}
    set_false_path -hold -through ${async_pins} -through ${async_pins}
}

# sync
foreach_in_collection cel_ref [get_cells -hierarchical -filter "hdl_template==sync"] {
    set cel [get_object_name $cel_ref]
    set clk_obj  [get_attribute [get_pins ${cel}/clk_i] clocks]
    set clk_name [get_attribute [get_clocks ${clk_obj}] name]
    set clk_tck  [get_attribute [get_clocks ${clk_obj}] period]
    set cel_type sync
    if {$clk_tck ne ""} {
            puts "\[common_cells\] Information: ${cel_type} with ${clk_name} (${clk_tck}) at ${cel}"
    } else {
        puts "\[common_cells\] Warning: ${cel_type} with undefined (${src_clk_name}) or dst (${dst_clk_name}) clock at ${cel}; defaulting on maximum delay ${cc_cdc_missing_clk_delay}"
        return ${cc_cdc_missing_clk_delay}
    }
    set_clock_gating_objects -exclude $cel_ref
    set_ungroup                 $cel_ref false
    set_boundary_optimization   $cel_ref false
    set async_pins [get_pins $cel/serial_i]
    set_max_delay ${clk_tck} -through ${async_pins} -through ${async_pins}
    set_false_path -hold -through ${async_pins} -through ${async_pins}
}


