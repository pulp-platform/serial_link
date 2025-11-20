# Copyright 2025 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

PEAKRDL 	?= peakrdl

#################################
# SystemRDL register generation #
#################################

.PHONY: slink-update-regs

SLINK_NUM_CHANNELS               	?= 1
SLINK_NUM_LANES                  	?= 8
SLINK_LOG2_MAX_CLK_DIV           	?= 10
SLINK_LOG2_RAW_MODE_TX_FIFO_DEPTH	?= 3

PEAKRDL_PARAMETER_FLAGS += -P NumChannels=$(SLINK_NUM_CHANNELS)
PEAKRDL_PARAMETER_FLAGS += -P NumLanes=$(SLINK_NUM_LANES)
PEAKRDL_PARAMETER_FLAGS += -P Log2MaxClkDiv=$(SLINK_LOG2_MAX_CLK_DIV)
PEAKRDL_PARAMETER_FLAGS += -P Log2RawModeTXFifoDepth=$(SLINK_LOG2_RAW_MODE_TX_FIFO_DEPTH)

slink-update-regs: src/regs/rdl/*.rdl
	$(PEAKRDL) regblock src/regs/rdl/serial_link.rdl -I src/regs/rdl -o src/regs/rtl/. --default-reset arst_n --cpuif apb4-flat $(PEAKRDL_MC_PARAMETER_FLAGS) $(PEAKRDL_PARAMETER_FLAGS)
	$(PEAKRDL) raw-header src/regs/rdl/serial_link.rdl -o src/regs/rtl/serial_link_addrmap.svh --format svh -I src/regs/rtl $(PEAKRDL_MC_PARAMETER_FLAGS) $(PEAKRDL_PARAMETER_FLAGS)
	@sed -i '1i// Copyright 2025 ETH Zurich and University of Bologna.\n// Solderpad Hardware License, Version 0.51, see LICENSE for details.\n// SPDX-License-Identifier: SHL-0.51\n' src/regs/rtl/*.sv*
