# Copyright 2022 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Author: Tim Fischer <fischeti@iis.ee.ethz.ch>
# Modified: Yannick Baumann <baumanny@student.ethz.ch>

GIT 		?= git
BENDER 		?= bender
# VSIM 		?= vsim
VSIM 		?= questa-2022.3 vsim
REGGEN 		?= $(shell ${BENDER} path register_interface)/vendor/lowrisc_opentitan/util/regtool.py
WORK 		?= work

.PHONY: sim sim_c sim_clean sim_compile rebuild
sim: compile_questa	run_questa_gui

sim_c: compile_questa run_questa

sim_clean: clean_questa

sim_compile: compile_questa

clean: clean_bender clean_questa clean_vcs

rebuild: clean clean Bender.lock

run: run_questa

# Ensure half-built targets are purged
.DELETE_ON_ERROR:

# --------------
# General
# --------------

.PHONY: clean_bender

Bender.lock:
	$(BENDER) update

clean_bender:
	rm -rf .bender
	rm -rf Bender.lock


# --------------
# Registers
# --------------

.PHONY: update-regs

update-regs: src/regs/*.hjson
	echo $(REGGEN)
	$(REGGEN) src/regs/serial_link.hjson -r -t src/regs
	$(REGGEN) src/regs/serial_link_single_channel.hjson -r -t src/regs

# --------------
# QuestaSim
# --------------

# TB_DUT ?= tb_axi_serial_link
# TB_DUT ?= tb_floo_noc_bridge
# Below option is not yet available...
TB_DUT ?= tb_floo_serial_link
WaveDo ?= $(TB_DUT)_wave.do

BENDER_FLAGS := -t test -t simulation

VLOG_FLAGS += -suppress vlog-2583
VLOG_FLAGS += -suppress vlog-13314
VLOG_FLAGS += -suppress vlog-13233
VLOG_FLAGS += -timescale 1ns/1ps
VLOG_FLAGS += -work $(WORK)

ifeq ($(TB_DUT),tb_floo_noc_bridge)
	StopTime := "399,190"
# 	StopTime := "380,400"
else ifeq ($(TB_DUT),tb_axi_serial_link)
	StopTime := "25,159,350"
# 	StopTime := "26,389,950"
else ifeq ($(TB_DUT),tb_floo_serial_link)
	StopTime := "30,183,400"
else 
	StopTime := "???"
endif

.PHONY: compile_questa clean_questa run_questa run_questa_gui

scripts/compile_vsim.tcl: Bender.lock
	@mkdir -p scripts
	@echo 'set ROOT [file normalize [file dirname [info script]]/..]' > $@
	$(BENDER) script vsim --vlog-arg="$(VLOG_FLAGS)" $(BENDER_FLAGS) | grep -v "set ROOT" >> $@
	@echo >> $@

compile_questa: scripts/compile_vsim.tcl
ifeq ($(SINGLE_CHANNEL),1)
	@sed 's/NumChannels = [0-9]*/NumChannels = 1/' src/serial_link_pkg.sv -i.prev
	$(VSIM) -64 -c -work $(WORK) -do "source $<; quit" | tee $(dir $<)vsim.log | grep --color -P "Error|"
	@mv src/serial_link_pkg.sv.prev src/serial_link_pkg.sv
else
	$(VSIM) -64 -c -work $(WORK) -do "source $<; quit" | tee $(dir $<)vsim.log | grep --color -P "Error|"
endif
	@! grep -P "Errors: [1-9]*," $(dir $<)vsim.log
	@echo -e "\033[1;32m______________________________CompilationSummary______________________________\033[0m"
	@cat $(dir $<)vsim.log | grep --color -e Error -e Warning || true
	@echo -e "\033[1;32m________________________________CompilationEnd________________________________\033[0m"

clean_questa:
	@rm -rf scripts/compile_vsim.tcl
	@rm -rf work*
	@rm -rf vsim.wlf
	@rm -rf transcript
	@rm -rf modelsim.ini
	@rm -rf *.vstf
	@rm -rf scripts/vsim.log
	@rm -rf scripts/vsim_consoleSimulation.log

run_questa:
	@echo -e "\033[0;34mRunning the testbench: \033[1m$(TB_DUT)\033[0m"
	@echo -e "\033[0;34mExpected stop time is \033[1m$(StopTime) ns\033[0m"
	$(VSIM) $(TB_DUT) -work $(WORK) $(RUN_ARGS) -c -do "run -all; exit" | tee $(dir $<)vsim_consoleSimulation.log | grep --color -P "Error|"
	@echo -e "\033[0;34mTestbench: \033[1m$(TB_DUT)\033[0m"
	@echo -e "\033[0;34mStop time of the original design was: \033[1m$(StopTime) ns\033[0m"	
	@echo -e "\033[1;32m______________________________Simulation-Summary______________________________\033[0m"
	@cat $(dir $<)vsim_consoleSimulation.log | grep --color -e Error -e Warning -e "AW queue is empty!" -e "AW mismatch!" -e "W queue is empty!" -e "W mismatch!" -e "AR queue is empty!" -e "AR mismatch!" -e "B queue is empty!" -e "B mismatch!" -e "R queue is empty!" -e "R mismatch!" -e "ASSERT FAILED" || true
	@cat $(dir $<)vsim_consoleSimulation.log | grep --color "INFO: " | sed "s/INFO/`printf '\033[1;35mINFO\033[0m'`/g" || true
	@cat $(dir $<)vsim_consoleSimulation.log | grep -o -e "# Errors\: [0-9]*," | tr -d "#,:Erso " | sed -e "s/\(.*\)/'\1'/" | sed "s/'0'/good/g" | sed -e "s/'\([0-9]\+\)'/error/g" | sed "s/good/`printf '\033[1;37;42mStatus: It all looks good!\033[0m'`/g" | sed "s/error/`printf '\033[1;37;41mStatus: There are errors!\033[0m'`/g" || true
	@echo -e "\033[1;32m________________________________Simulation-End________________________________\033[0m"

run_questa_gui:
	$(VSIM) $(TB_DUT) -work $(WORK) $(RUN_ARGS) -voptargs=+acc -do "log -r /*; do util/$(WaveDo); echo \"Running the testbench: $(TB_DUT)\"; echo \"Stop time of the original design was: $(StopTime) ns\"; run -all"

# --------------
# VCS
# --------------

.PHONY: compile_vcs clean_vcs

VLOGAN_ARGS := -assert svaext
VLOGAN_ARGS += -assert disable_cover
VLOGAN_ARGS += -full64
VLOGAN_ARGS += -sysc=q
VLOGAN_ARGS += -q
VLOGAN_ARGS += -timescale=1ns/1ps

VCS_ARGS    := -full64
VCS_ARGS    += -Mlib=$(WORK)
VCS_ARGS    += -Mdir=$(WORK)
VCS_ARGS    += -debug_access+pp
VCS_ARGS    += -j 8
VCS_ARGS    += -CFLAGS "-Os"

VCS_PARAMS  ?=
TB_DUT 		?= tb_axi_serial_link

VLOGAN  	?= vlogan
VCS		    ?= vcs

VLOGAN_REL_PATHS ?= | grep -v "ROOT=" | sed '3 i ROOT="."'

scripts/compile_vcs.sh: Bender.yml Bender.lock
	@mkdir -p scripts
	$(BENDER) script vcs -t test -t rtl -t simulation --vlog-arg "\$(VLOGAN_ARGS)" --vlogan-bin "$(VLOGAN)" $(VLOGAN_REL_PATHS) > $@
	chmod +x $@

compile_vcs: scripts/compile_vcs.sh
ifeq ($(SINGLE_CHANNEL),1)
	@sed 's/NumChannels = [0-9]*/NumChannels = 1/' src/serial_link_pkg.sv -i.prev
	$< > scripts/compile_vcs.log
	@mv src/serial_link_pkg.sv.prev src/serial_link_pkg.sv
else
	$< > scripts/compile_vcs.log
endif

bin/%.vcs: scripts/compile_vcs.sh compile_vcs
	mkdir -p bin
	$(VCS) $(VCS_ARGS) $(VCS_PARAMS) $(TB_DUT) -o $@

clean_vcs:
	@rm -rf AN.DB
	@rm -f  scripts/compile_vcs.sh
	@rm -rf bin
	@rm -rf work-vcs
	@rm -f  ucli.key
	@rm -f  vc_hdrs.h
	@rm -f  logs/*.vcs.log
	@rm -f  scripts/compile_vcs.log

# --------------
# CI
# --------------

.PHONY: bender

bender:
ifeq (,$(wildcard ./bender))
	curl --proto '=https' --tlsv1.2 -sSf https://pulp-platform.github.io/bender/init \
		| bash -s -- 0.25.3
	touch bender
endif

.PHONY: remove_bender
remove_bender:
	rm -f bender
