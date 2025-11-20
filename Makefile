# Copyright 2022 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

BENDER 		?= bender
VSIM 		  ?= vsim
WORK 		  ?= work
PEAKRDL 	?= peakrdl

all: vsim-compile

clean: vsim-clean vcs-clean

run: vsim-run

# Ensure half-built targets are purged
.DELETE_ON_ERROR:

#################################
# SystemRDL register generation #
#################################

include slink.mk

.PHONY: update-regs
update-regs: slink-update-regs

########################
# QuestaSim Simulation #
########################

TB_DUT ?= tb_axi_serial_link

BENDER_FLAGS := -t test -t simulation

VLOG_FLAGS += -suppress vlog-2583
VLOG_FLAGS += -suppress vlog-13314
VLOG_FLAGS += -suppress vlog-13233
VLOG_FLAGS += -timescale 1ns/1ps
VLOG_FLAGS += -work $(WORK)

VSIM_FLAGS += -work $(WORK)

VSIM_FLAGS_GUI += -voptargs=+acc
VSIM_FLAGS_GUI += -do "log -r /*"
VSIM_FLAGS_GUI += -do util/serial_link_wave.tcl

.PHONY: vsim-compile vsim-clean vsim-run vsim-run-batch

scripts/compile_vsim.tcl: Bender.lock
	@mkdir -p scripts
	$(BENDER) script vsim --vlog-arg="$(VLOG_FLAGS)" $(BENDER_FLAGS) >> $@

vsim-compile: scripts/compile_vsim.tcl
	$(VSIM) -c -work $(WORK) -do "source $<; quit" | tee $(dir $<)vsim.log
	@! grep -P "Errors: [1-9]*," $(dir $<)vsim.log

vsim-clean:
	@rm -rf scripts/compile_vsim.tcl
	@rm -rf work*
	@rm -rf vsim.wlf
	@rm -rf transcript
	@rm -rf modelsim.ini
	@rm -rf *.vstf
	@rm -rf scripts/vsim.log

vsim-run:
	$(VSIM) $(VSIM_FLAGS) $(SIM_ARGS) $(VSIM_FLAGS_GUI) $(TB_DUT)

vsim-run-batch:
	$(VSIM) -c $(VSIM_FLAGS) $(SIM_ARGS) $(TB_DUT) -do "run -all; quit"


##################
# VCS Simulation #
##################

.PHONY: vcs-compile vcs-clean

VLOGAN_ARGS += -timescale=1ns/1ps

VCS_FLAGS    += -full64
VCS_FLAGS    += -Mlib=$(WORK)
VCS_FLAGS    += -Mdir=$(WORK)

VCS_PARAMS  ?=
TB_DUT 		?= tb_axi_serial_link

VLOGAN  	?= vlogan
VCS		    ?= vcs

VLOGAN_REL_PATHS ?= | grep -v "ROOT=" | sed '3 i ROOT="."'

scripts/compile_vcs.sh: Bender.yml Bender.lock
	@mkdir -p scripts
	$(BENDER) script vcs -t test -t rtl -t simulation --vlog-arg "\$(VLOGAN_ARGS)" --vlogan-bin "$(VLOGAN)" $(VLOGAN_REL_PATHS) > $@
	chmod +x $@

bin/%.vcs: scripts/compile_vcs.sh
	$< > scripts/compile_vcs.log
	mkdir -p bin
	$(VCS) $(VCS_FLAGS) $(VCS_PARAMS) $(TB_DUT) -o $@

vcs-compile: bin/$(TB_DUT).vcs

vcs-run vcs-run-batch:
	bin/$(TB_DUT).vcs +permissive -exitstatus +permissive-off $(SIM_ARGS)

vcs-clean:
	@rm -rf AN.DB
	@rm -f  scripts/compile_vcs.sh
	@rm -rf bin
	@rm -rf work-vcs
	@rm -f  ucli.key
	@rm -f  vc_hdrs.h
	@rm -f  logs/*.vcs.log
	@rm -f  scripts/compile_vcs.log
