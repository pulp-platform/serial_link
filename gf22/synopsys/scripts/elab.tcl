# Copyright (c) 2020 ETH Zurich
# Sergio Mazzola <smazzola@student.ethz.ch>

###################
##  ELABORATION  ##
###################

# Elaborate the design => make sure to match the name of the library script!!!
source [file dirname [info script]]/seriallink_lib.tcl
# # TODO: or is it this path?
# source [file dirname [info script]]/../seriallink_lib.tcl

if {![info exists TCK               ]} {set TCK                1000}
if {![info exists TIMESTAMP         ]} {set TIMESTAMP nulltimestamp}

# set the name of the design => please give your design a reasonable name
set DESIGN serial_link_narrow_wide
set OUTNAME ${DESIGN}
set REPDIR $SYNDIR/reports/$OUTNAME
exec mkdir -p $REPDIR

# Timing variables
set_app_var timing_enable_through_paths true

# Do not write out net RC info into SDC
set_app_var write_sdc_output_lumped_net_capacitance false
set_app_var write_sdc_output_net_resistance         false

# Set libraries
dz_set_pvt [list \
    GF22FDX_SC8T_104CPP_BASE_CSC20SL_SSG_0P72V_0P00V_0P00V_0P00V_125C \
    GF22FDX_SC8T_104CPP_BASE_CSC24SL_SSG_0P72V_0P00V_0P00V_0P00V_125C \
    GF22FDX_SC8T_104CPP_BASE_CSC28SL_SSG_0P72V_0P00V_0P00V_0P00V_125C \
    GF22FDX_SC8T_104CPP_BASE_CSC20L_SSG_0P72V_0P00V_0P00V_0P00V_125C  \
    GF22FDX_SC8T_104CPP_BASE_CSC24L_SSG_0P72V_0P00V_0P00V_0P00V_125C  \
    GF22FDX_SC8T_104CPP_BASE_CSC28L_SSG_0P72V_0P00V_0P00V_0P00V_125C  ]

# # Add all memories => TODO: is this part required?
# foreach db $MEMCUTS {
#     lappend link_library ${db}_104cpp_TT_0P800V_0P000V_0P000V_025C.db
# }

# Remove any existing designs
remove_design -designs

# Analyze the source files
redirect -tee -file $REPDIR/analyze.rpt {
    # "equivalent" to the analyze command from the ex6 of VLSI 1
    analyze_bender
}

# Elaborate
redirect -tee -file $REPDIR/elaborate.rpt {
    # Elaborate the design => make sure to match the name of the topmodule (the one to be elaborated, no file-ending required)
    # with parameters: elaborate <name> -param <parameterName>=>32
    elaborate floo_serial_link_narrow_wide_synth_wrapper

    define_name_rules verilog -preserve_struct_ports
    change_names -rules verilog -hierarchy

    # Rename to a friendlier name
    rename_design [current_design] ${DESIGN}
    current_design ${DESIGN}
}

# Write elaborated code
write_file -format ddc -hierarchy -output DDC/${OUTNAME}.ddc

# Ciao!
# exit