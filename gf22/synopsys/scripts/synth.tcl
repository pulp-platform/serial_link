# Copyright (c) 2020 ETH Zurich
# Sergio Mazzola <smazzola@student.ethz.ch>

#################
##  SYNTHESIS  ##
#################

# synthesize the design => make sure to match the name of the library script!!!
source [file dirname [info script]]/seriallink_lib.tcl
set_host_options -max_cores 16

# TCK used in the constraints section (time in ps) => set the clock frequency
if {![info exists TCK               ]} {set TCK                  1000           }
if {![info exists TIMESTAMP         ]} {set TIMESTAMP  [exec date | tr " " "_"] }

# set the name of the design => please give your design a reasonable name
set DESIGN serial_link_narrow_wide
set OUTNAME ${DESIGN}-clk_is_${TCK}ps-${TIMESTAMP}
set REPDIR $SYNDIR/reports/$OUTNAME

# set the constraints => select the input delay (ID), output delay (OD) and the load (LOAD)
set ID 100
set OD 100
set LOAD 0.1
exec mkdir -p $REPDIR

puts "# started [exec date] on [exec hostname]"
puts "# TCK         = $TCK"
puts "# OUTNAME     = $OUTNAME"
puts "# REPDIR      = $REPDIR"

# Timing variables
set_app_var timing_enable_through_paths true

# Do not write out net RC info into SDC
set_app_var write_sdc_output_lumped_net_capacitance false
set_app_var write_sdc_output_net_resistance         false

#####################
##   LOAD DESIGN   ##
#####################

redirect -tee -file $REPDIR/synth_loadDesign.log {
    # Set libraries
    dz_set_pvt [list \
                    GF22FDX_SC8T_104CPP_BASE_CSC20SL_TT_0P80V_0P00V_0P00V_0P00V_25C\
                    GF22FDX_SC8T_104CPP_BASE_CSC24SL_TT_0P80V_0P00V_0P00V_0P00V_25C\
                    GF22FDX_SC8T_104CPP_BASE_CSC28SL_TT_0P80V_0P00V_0P00V_0P00V_25C\
                    GF22FDX_SC8T_104CPP_BASE_CSC20L_TT_0P80V_0P00V_0P00V_0P00V_25C \
                    GF22FDX_SC8T_104CPP_BASE_CSC24L_TT_0P80V_0P00V_0P00V_0P00V_25C \
                    GF22FDX_SC8T_104CPP_BASE_CSC28L_TT_0P80V_0P00V_0P00V_0P00V_25C ]

    # # TODO: Are these lines required?
    # # Load the memory libraries
    # foreach cut $MEMCUTS {
    #   lappend link_library ${cut}_104cpp_TT_0P800V_0P000V_0P000V_025C.db
    # }

    # Load the design
    read_file -format ddc $SYNDIR/DDC/${OUTNAME}.ddc

    # Link the design
    link
}

#####################
##   CONSTRAINTS   ## => add your constraints here
#####################

# Read constraints (to print out in the synth_constraints file, put an echo of the command before the actual command)
redirect -tee -file $REPDIR/synth_constraints.rpt {
    echo "create_clock clk_i -period ${TCK}"
    create_clock clk_i -period ${TCK}

    echo "set_input_delay ${ID} -clock clk_i [remove_from_collection [all_inputs] clk_i]"
    set_input_delay ${ID} -clock clk_i [remove_from_collection [all_inputs] clk_i]
    echo "set_output_delay ${OD} -clock clk_i [all_outputs]"
    set_output_delay ${OD} -clock clk_i [all_outputs]
    echo "set_driving_cell -no_design_rule -lib_cell SC8T_BUFX6_CSC20L -pin Z -from_pin A [all_inputs]"
    set_driving_cell -no_design_rule -lib_cell SC8T_BUFX6_CSC20L -pin Z -from_pin A [all_inputs]
    echo "set_load ${LOAD} [all_outputs]"
    set_load ${LOAD} [all_outputs]

    # set_ideal_network : no delay, ...
    # set_ideal_network [get_ports rst_ni]
    # set_dont_touch_network [get_ports rst_ni]
    # set_ideal_network [get_ports clk_i]
    # set_dont_touch_network [get_ports clk_i]
    # set_driving_cell -no_design_rule -lib_cell SC8T_BUFX6_CSC20L -pin Z -from_pin A [all_inputs]
    # set_load 0.1 [all_outputs]
    #
    # # Assume all inputs driven from FF
    # set_input_delay 100 -clock clk_i [remove_from_collection [all_inputs] clk_i]
    # # set_input_delay 100 -clock clk_i [remove_from_collection [all_inputs] clk_i]
    # # Assume all outputs drive FF
    # set_output_delay 20 -clock clk_i [all_outputs]
    # #set_output_delay 20 -clock clk_i [all_outputs]
    #
    # # Reset
    # # set_ideal_network : no delay, ...
    # set_ideal_network [get_ports arst]
    # # set_ideal_network [get_ports rst_ni]
    # # don't modify this path (add buffers etc)
    # set_dont_touch_network [get_ports arst]
    # # set_dont_touch_network [get_ports rst_ni]
}

######################
##   COMPILE CORE   ##
######################

redirect -tee -file $REPDIR/synth_compile.log {
    # Compile
    compile_ultra -no_autoungroup
}

#  #############################
#  ##   INCREMENTAL COMPILE   ##
#  #############################
#
#  redirect -tee -file $REPDIR/synth_compile_incr.rpt {
#
#    # Do an incremental compile, independently on slack
#    compile_ultra -no_autoungroup -incremental
#    # High-effort area optimization
#    optimize_netlist -area
#  }

###############
##  REPORTS  ##
###############

# Absolute critical path
report_timing -nosplit > $REPDIR/synth_timing_report.rpt
report_area -hierarchy -nosplit > $REPDIR/synth_area_report.rpt
report_resource -hierarchy -nosplit > $REPDIR/synth_resources_report.rpt
report_register -nosplit > $REPDIR/synth_registers_report.rpt
# Ciao!
# exit

# suggested by the VLSI_1 ex6 to verify whether the run was successful or not => uncomment if needed
check_design > $REPDIR/synth_checkDesign.log

# ------------------------------------------------------------------------------
# Write Out Data
# ------------------------------------------------------------------------------
# Change names for Verilog.
change_names -rule verilog -hierarchy

# Write Verilog netlist.
sh mkdir $REPDIR/netlist
write -hierarchy -format verilog -output $REPDIR/netlist/${DESIGN}.v
exec cp $REPDIR/netlist/${DESIGN}.v $SYNDIR/netlists/${OUTNAME}.v
link > $REPDIR/synth_final_link_command.log
echo "$OUTNAME: No comment" >> $SYNDIR/reports/versionLog.log