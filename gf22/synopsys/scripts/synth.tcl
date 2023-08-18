# Copyright (c) 2020 ETH Zurich
# Sergio Mazzola <smazzola@student.ethz.ch>

#################
##  SYNTHESIS  ##
#################

# synthesize the design => make sure to match the name of the library script!!!
source [file dirname [info script]]/seriallink_lib.tcl
set_host_options -max_cores 16

# TCK used in the constraints section (time in ps) => set the clock frequency
if {![info exists TCK               ]} {set TCK        1000  }
if {![info exists TIMESTAMP         ]} {set TIMESTAMP  [exec date | tr " " "_" | cut -d "_" -f1]_[exec date | tr " " "_" | cut -d "_" -f3]_[exec date | tr " " "_" | cut -d "_" -f2]_([exec date | tr " " "_" | cut -d "_" -f4]) }

# set the name of the design => please give your design a reasonable name
set DESIGN serial_link_narrow_wide
set OUTNAME ${DESIGN}-clk_is_${TCK}ps-${TIMESTAMP}
set REPDIR $SYNDIR/reports/$OUTNAME

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

    echo "serial_link.sdc:"
    echo [exec cat [file dirname [info script]]/constraints/serial_link.sdc]
    source [file dirname [info script]]/constraints/serial_link.sdc
    echo "common_cells_sdc:"
    echo [exec cat [file dirname [info script]]/constraints/common_cells.sdc]
    source [file dirname [info script]]/constraints/common_cells.sdc

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