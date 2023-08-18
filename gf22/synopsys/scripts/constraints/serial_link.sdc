# Copyright 2022 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Author: Tim Fischer <fischeti@iis.ee.ethz.ch>
# Author: Alfio Di Mauro <adimauro@iis.ee.ethz.ch>
# Modified: Yannick Baumann <baumanny@ethz.ch>

# System clock (1 GHz)
set T_CLK 1000

# Peripheral Clock (250 MHz)
set T_REG 2000

# Incoming forwarded clock
set FWD_CLK_DIV 8
set T_FWD_CLK [expr $T_CLK * $FWD_CLK_DIV]

# static signals
set_case_analysis 0 testmode_i

###################
#  SYSTEM CLOCKS  #
###################

# System Clocks
create_clock -period $T_CLK -name clk [get_ports clk_i]
create_clock -period $T_REG -name clk_reg [get_ports clk_reg_i]
create_clock -period $T_CLK -name clk_sl [get_ports clk_sl_i]

################
#  I/O CLOCKS  #
################

# Data should arrive in a +- 5% window of /4 clock cycle
set MARGIN              [expr $T_FWD_CLK / 4 * 0.05]

# We assume data are synchronous to a zero phase shifeted virtual clock,
# and that the received clock is shifted with respect to that by -90 or + 270 degrees (or +90 degrees and inverted)
set edge_list [list [expr $T_FWD_CLK / 4 * 3] [expr $T_FWD_CLK / 4 * 5]]
    # TODO: below line is the original. To me it seems to be wrong though...
# set edge_list [list [expr $FWD_CLK_DIV / 4 * 3] [expr $FWD_CLK_DIV / 4 * 5]]


# This clock is not acctually available inside the RX side, but it is required to constraints ddr_i input delays.
create_clock -name vir_clk_ddr_in -period $T_FWD_CLK
create_clock -name clk_ddr_in -period $T_FWD_CLK -waveform $edge_list [get_ports ddr_rcv_clk_i]

# OUTPUT CLOCKS
# The data launching clock with 0 degree clock phase
create_generated_clock -name clk_slow -source clk_i -divide_by $FWD_CLK_DIV \
    [get_pins -hierarchical clk_slow_reg/Q]

# this is the "forwarded clock", we are assuming it is shifted by -90 or +270 degrees (or +90 degrees and inverted)
create_generated_clock -name clk_ddr_out -source clk_i \
    -edges [list [expr 1 + $T_FWD_CLK / 2 * 3] [expr 1 + $T_FWD_CLK / 2 * 5] [expr 1 + $T_FWD_CLK / 2 * 7]] \
    [get_pins -hierarchical ddr_rcv_clk_o_reg/Q]

    #  TODO: below line is the original. To me it seems to be wrong though...
# create_generated_clock -name clk_ddr_out -source clk_i \
#     -edges [list [expr 1 + $FWD_CLK_DIV / 2 * 3] [expr 1 + $FWD_CLK_DIV / 2 * 5] [expr 1 + $FWD_CLK_DIV / 2 * 7]] \
#     [get_pins -hierarchical ddr_rcv_clk_o_reg/Q]


#####################
#  I/O FALSE PATHS  #
#####################

# since it's DDR, we need to remove the "false" timing arcs between edges:
# - there is no "conventional" setup relationship (rise to rise and fall to fall);
# - we leave only the inter-clock launching edge to capturing edge timing arcs (rise to fall and fall to rise)
set_false_path -setup -rise_from [get_clocks vir_clk_ddr_in] -rise_to [get_clocks clk_ddr_in]
set_false_path -setup -fall_from [get_clocks vir_clk_ddr_in] -fall_to [get_clocks clk_ddr_in]

# - there is no actual hold relationship from non consecutive launching to capturing edges;
#   data change at every edge, therefore we can remove the timing arcs that
#   do not go from the current edge to the previous one (rise to fall and fall to rise)
# - we leave only inter-clocks hold relationship (fall to fall and rise to rise)
set_false_path -hold  -rise_from [get_clocks vir_clk_ddr_in] -fall_to [get_clocks clk_ddr_in]
set_false_path -hold  -fall_from [get_clocks vir_clk_ddr_in] -rise_to [get_clocks clk_ddr_in]

# since it's DDR, we need to remove the "false" timing arcs between edges:
# - there is no "conventional" setup relationship (rise to rise and fall to fall);
# - we leave only the inter-clock launching edge to capturing edge timing arcs (rise to fall and fall to rise)
set_false_path -setup -rise_from [get_clocks clk_slow] -rise_to [get_clocks clk_ddr_out]
set_false_path -setup -fall_from [get_clocks clk_slow] -fall_to [get_clocks clk_ddr_out]

# - there is no actual hold relationship from non consecutive launching to capturing edges;
#   data change at every edge, therefore we can remove the timing arcs that
#   do not go from the current edge to the previous one (rise to fall and fall to rise)
# - we leave only inter-clocks hold relationship (fall to fall and rise to rise)
set_false_path -hold  -rise_from [get_clocks clk_slow] -fall_to [get_clocks clk_ddr_out]
set_false_path -hold  -fall_from [get_clocks clk_slow] -rise_to [get_clocks clk_ddr_out]

################
#  I/O DELAYS  #
################

set IO_delay              [expr $T_CLK / 3]

set_input_delay -max -clock [get_clocks vir_clk_ddr_in] [expr $MARGIN] [get_ports ddr_i]
set_input_delay -add_delay -min -clock [get_clocks vir_clk_ddr_in] [expr -$MARGIN] [get_ports ddr_i]
set_input_delay -add_delay -max -clock_fall -clock [get_clocks vir_clk_ddr_in] [expr $MARGIN] [get_ports ddr_i]
set_input_delay -add_delay -min -clock_fall -clock [get_clocks vir_clk_ddr_in] [expr -$MARGIN] [get_ports ddr_i]

set num_channels          [sizeof_collection [get_ports ddr_rcv_clk_o]]
set num_lanes             [expr [sizeof_collection [get_ports ddr_o]]/[sizeof_collection [get_ports ddr_rcv_clk_o]]]

for {set i 0} {$i < $num_channels} {incr i} {
    set ddr_o_channel_group ""
    for {set p 0} {$p < $num_lanes} {incr p} {
        set ddr_o_channel_group [concat $ddr_o_channel_group ddr_o[[expr ${i}*$num_lanes + $p]]]
    }
    set_output_delay -max -clock [get_clocks clk_ddr_out] [expr $T_FWD_CLK / 4 + $MARGIN] -reference_pin [get_ports ddr_rcv_clk_o[${i}]] $ddr_o_channel_group
    set_output_delay -add_delay -min -clock [get_clocks clk_ddr_out] [expr $T_FWD_CLK / 4 - $MARGIN] -reference_pin [get_ports ddr_rcv_clk_o[${i}]] $ddr_o_channel_group
    set_output_delay -add_delay -max -clock_fall -clock [get_clocks clk_ddr_out] [expr $T_FWD_CLK / 4 + $MARGIN] -reference_pin [get_ports ddr_rcv_clk_o[${i}]] $ddr_o_channel_group
    set_output_delay -add_delay -min -clock_fall -clock [get_clocks clk_ddr_out] [expr $T_FWD_CLK / 4 - $MARGIN] -reference_pin [get_ports ddr_rcv_clk_o[${i}]] $ddr_o_channel_group
}

set_input_delay -clock [get_clocks clk] [expr $IO_delay] [remove_from_collection [all_inputs] [get_ports {clk* ddr* rst*}]]

set_output_delay -clock [get_clocks clk] [expr $IO_delay] [remove_from_collection [all_outputs] [get_ports {*clk_o* ddr* reset_no}]]

#################
#  OUTPUT LOAD  #
#################

set load_cell SC8T_BUFX8_CSC20L
set_load -pin_load [expr 4*[load_of [get_lib_pins */$load_cell/A]]] [remove_from_collection [all_outputs] [get_ports reset_no]]

########################
#  INPUT DRIVING CELL  #
########################

set driving_cell SC8T_BUFX8_CSC20L
set_driving_cell -no_design_rule -lib_cell $driving_cell -pin Z [remove_from_collection [all_inputs] [get_ports {*clk* rst*}]]

###################
#  IDEAL NETWORK  #
###################

set_ideal_network [remove_from_collection [get_ports {rst* reset_no* *clk*}] [get_ports {ddr_rcv_clk_o* clk_ena_o*}]]

##################
#  CLOCK GROUPS  #
##################

set_clock_groups \
    -asynchronous \
    -allow_paths \
    -group [get_clocks {clk clk_ddr_*out* clk_slow*}] \
    -group [get_clocks *in*] \
    -group [get_clocks clk_reg]

# report_clock_gating
update_timing
report_clock
report_clock -groups

