# Copyright 2022 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

bender := env_var_or_default("BENDER", "bender")
vsim   := env_var_or_default("VSIM",   "vsim")
work   := env_var_or_default("WORK",   "work")
vlogan := env_var_or_default("VLOGAN", "vlogan")
vcs    := env_var_or_default("VCS",    "vcs")

bender_flags := "-t slink_test -t test"

vlog_flags  := "-suppress vlog-2583 -suppress vlog-13314 -suppress vlog-13233 -timescale 1ns/1ps -work " + work
vsim_flags  := "-work " + work
vlogan_args := "-timescale=1ns/1ps"
vcs_flags   := "-full64 -Mlib=" + work + " -Mdir=" + work

# Compile for QuestaSim (default)
default: vsim-compile

# Clean all build artefacts
clean: vsim-clean vcs-clean

# Run QuestaSim simulation (alias)
run: vsim-run

#################################
# SystemRDL register generation #
#################################

# Generate register files from SystemRDL source
gen-regs:
    make -f slink.mk slink-gen-regs SLINK_ROOT={{ justfile_directory() }}

########################
# QuestaSim Simulation #
########################

# Generate QuestaSim compilation script
gen-vsim-script:
    mkdir -p scripts
    {{ bender }} script vsim --vlog-arg="{{ vlog_flags }}" {{ bender_flags }} > scripts/compile_vsim.tcl

# Compile design for QuestaSim
vsim-compile: gen-vsim-script
    {{ vsim }} -c -work {{ work }} -do "source scripts/compile_vsim.tcl; quit" | tee scripts/vsim.log
    ! grep -P "Errors: [1-9]*," scripts/vsim.log

# Run QuestaSim simulation (GUI)
vsim-run tb="tb_axi_slink":
    {{ vsim }} {{ vsim_flags }} ${SIM_ARGS:-} -voptargs=+acc -do "log -r /*" -do util/wave.tcl {{ tb }}

# Run QuestaSim simulation (batch)
vsim-run-batch tb="tb_axi_slink":
    {{ vsim }} -c {{ vsim_flags }} ${SIM_ARGS:-} {{ tb }} -do "run -all; quit"

# Remove QuestaSim build artefacts
vsim-clean:
    rm -rf scripts/compile_vsim.tcl work* vsim.wlf transcript modelsim.ini *.vstf scripts/vsim.log

##################
# VCS Simulation #
##################

# Generate VCS compilation script
gen-vcs-script:
    mkdir -p scripts
    {{ bender }} script vcs {{ bender_flags }} --vlog-arg "{{ vlogan_args }}" --vlogan-bin "{{ vlogan }}" \
        | grep -v "ROOT=" | sed '3 i ROOT="."' > scripts/compile_vcs.sh
    chmod +x scripts/compile_vcs.sh

# Compile design for VCS
vcs-compile tb="tb_axi_serial_link": gen-vcs-script
    scripts/compile_vcs.sh > scripts/compile_vcs.log
    mkdir -p bin
    {{ vcs }} {{ vcs_flags }} ${VCS_PARAMS:-} {{ tb }} -o bin/{{ tb }}.vcs

# Run VCS simulation
vcs-run tb="tb_axi_serial_link":
    bin/{{ tb }}.vcs +permissive -exitstatus +permissive-off ${SIM_ARGS:-}

# Run VCS simulation (batch)
vcs-run-batch tb="tb_axi_serial_link":
    bin/{{ tb }}.vcs +permissive -exitstatus +permissive-off ${SIM_ARGS:-}

# Remove VCS build artefacts
vcs-clean:
    rm -rf AN.DB scripts/compile_vcs.sh bin work-vcs ucli.key vc_hdrs.h logs/*.vcs.log scripts/compile_vcs.log
