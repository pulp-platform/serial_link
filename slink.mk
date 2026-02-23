# Copyright 2025 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

PEAKRDL    ?= peakrdl
BENDER     ?= bender
SLINK_ROOT ?= $(shell $(BENDER) path serial_link)

#################################
# SystemRDL register generation #
#################################

SLINK_NUM_CHANNELS               	?= 1
SLINK_NUM_LANES                  	?= 8
SLINK_LOG2_MAX_CLK_DIV           	?= 10
SLINK_LOG2_RAW_MODE_TX_FIFO_DEPTH	?= 3

SLINK_PEAKRDL_PARAMS += -P NumChannels=$(SLINK_NUM_CHANNELS)
SLINK_PEAKRDL_PARAMS += -P NumLanes=$(SLINK_NUM_LANES)
SLINK_PEAKRDL_PARAMS += -P Log2MaxClkDiv=$(SLINK_LOG2_MAX_CLK_DIV)
SLINK_PEAKRDL_PARAMS += -P Log2RawModeTXFifoDepth=$(SLINK_LOG2_RAW_MODE_TX_FIFO_DEPTH)

SLINK_COPYRIGHT_NOTICE = // Copyright 2025 ETH Zurich and University of Bologna.\n// Solderpad Hardware License, Version 0.51, see LICENSE for details.\n// SPDX-License-Identifier: SHL-0.51\n

# Track the currently generated configuration in the .generated file.
# On every invocation of make, compare the specified configuration with the
# currently generated one and modify the timestamp of the .generated file if they differ.
# The new timestamp will trigger regeneration of the register files.
.PHONY: SLINK_FORCE
SLINK_FORCE:

$(SLINK_ROOT)/.generated: SLINK_FORCE
	@printf '%s\n' "$(SLINK_PEAKRDL_PARAMS)" | cmp -s - $@ || printf '%s\n' "$(SLINK_PEAKRDL_PARAMS)" > $@


$(SLINK_ROOT)/src/regs/slink_reg.sv:$(SLINK_ROOT)/src/regs/slink_reg_pkg.sv
$(SLINK_ROOT)/src/regs/slink_reg_pkg.sv: $(SLINK_ROOT)/src/regs/slink_reg.rdl $(SLINK_ROOT)/.generated
	$(PEAKRDL) regblock $< -o $(dir $@) --default-reset arst_n --cpuif apb4-flat $(SLINK_PEAKRDL_PARAMS)
	@sed -i '1i$(SLINK_COPYRIGHT_NOTICE)' $@ $(dir $@)/slink_reg.sv

$(SLINK_ROOT)/src/regs/slink_addrmap.svh: $(SLINK_ROOT)/src/regs/slink_reg.rdl $(SLINK_ROOT)/.generated
	$(PEAKRDL) raw-header $< -o $@ --format svh $(SLINK_PEAKRDL_PARAMS)
	@sed -i '1i$(SLINK_COPYRIGHT_NOTICE)' $@

.PHONY: slink-gen-regs
slink-gen-regs: $(SLINK_ROOT)/src/regs/slink_reg.sv $(SLINK_ROOT)/src/regs/slink_addrmap.svh
