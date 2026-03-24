# Copyright 2022 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
# Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

set dotenv-load := true
set shell := ["bash", "-cu"]

bender := env_var_or_default("BENDER", "bender")
vsim := env_var_or_default("VSIM", "vsim")
work := env_var_or_default("WORK", "work")
vlogan := env_var_or_default("VLOGAN", "vlogan")
vcs := env_var_or_default("VCS", "vcs")
bender_flags := "-t slink_test -t test"
vlog_flags := "-suppress vlog-2583 -suppress vlog-13314 -suppress vlog-13233 -timescale 1ns/1ps -work " + work
vsim_flags := "-work " + work
vlogan_args := "-timescale=1ns/1ps"
vcs_flags := "-full64 -Mlib=" + work + " -Mdir=" + work

# List all available recipes
default:
    @just --list

# Generate register files from SystemRDL source (pass SLINK_* overrides as args)
[group("regs")]
gen-regs *args="":
    make -f slink.mk slink-gen-regs SLINK_ROOT={{ justfile_directory() }} {{ args }}

# Compile design (sim: vsim [default], vcs)
[group("sim")]
compile sim="vsim" tb="tb_axi_slink" *args="":
    just _compile-{{ sim }} {{ tb }} {{ args }}

# Run simulation GUI (sim: vsim [default], vcs)
[group("sim")]
run sim="vsim" tb="tb_axi_slink" *sim_args="":
    just _run-{{ sim }}-gui {{ tb }} {{ sim_args }}

# Run simulation in batch mode (sim: vsim [default], vcs)
[group("sim")]
run-batch sim="vsim" tb="tb_axi_slink" *sim_args="":
    just _run-{{ sim }}-batch {{ tb }} {{ sim_args }}

# Remove build artefacts (sim: vsim, vcs; default: all)
[group("sim")]
clean sim="all":
    just _clean-{{ sim }}

####################
# Private: QuestaSim
####################

[private]
_compile-vsim tb *args:
    mkdir -p scripts
    {{ bender }} script vsim --vlog-arg="{{ vlog_flags }}" {{ bender_flags }} > scripts/compile_vsim.tcl
    {{ vsim }} -c -work {{ work }} -do "source scripts/compile_vsim.tcl; quit" | tee scripts/vsim.log
    ! grep -P "Errors: [1-9]*," scripts/vsim.log

[private]
_run-vsim-gui tb *sim_args:
    {{ vsim }} {{ vsim_flags }} {{ sim_args }} -voptargs=+acc -do "log -r /*" -do util/wave.tcl {{ tb }}

[private]
_run-vsim-batch tb *sim_args:
    {{ vsim }} -c {{ vsim_flags }} {{ sim_args }} {{ tb }} -do "run -all; quit"

[private]
_clean-vsim:
    rm -rf scripts/compile_vsim.tcl work* vsim.wlf transcript modelsim.ini *.vstf scripts/vsim.log

################
# Private: VCS
################

[private]
_compile-vcs tb *vcs_params:
    mkdir -p scripts
    {{ bender }} script vcs {{ bender_flags }} --vlogan-args="{{ vlogan_args }}" --vlogan-bin "{{ vlogan }}" \
        | grep -v "ROOT=" | sed '3 i ROOT="."' > scripts/compile_vcs.sh
    chmod +x scripts/compile_vcs.sh
    scripts/compile_vcs.sh > scripts/compile_vcs.log
    mkdir -p {{ work }}/bin
    {{ vcs }} {{ vcs_flags }} {{ vcs_params }} {{ tb }} -o {{ work }}/bin/{{ tb }}.vcs

[private]
_run-vcs-gui tb *sim_args:
    {{ work }}/bin/{{ tb }}.vcs +permissive -exitstatus +permissive-off {{ sim_args }}

[private]
_run-vcs-batch tb *sim_args:
    {{ work }}/bin/{{ tb }}.vcs +permissive -exitstatus +permissive-off {{ sim_args }}

[private]
_clean-vcs:
    rm -rf AN.DB scripts/compile_vcs.sh ucli.key vc_hdrs.h logs/*.vcs.log scripts/compile_vcs.log

[private]
_clean-all:
    just _clean-vsim
    just _clean-vcs
