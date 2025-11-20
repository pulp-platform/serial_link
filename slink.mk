# Copyright 2025 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

PEAKRDL 	?= peakrdl

#################################
# SystemRDL register generation #
#################################

SLINK_NUM_CHANNELS               	?= 1
SLINK_NUM_LANES                  	?= 8
SLINK_LOG2_MAX_CLK_DIV           	?= 10
SLINK_LOG2_RAW_MODE_TX_FIFO_DEPTH	?= 3

PEAKRDL_PARAMS += -P NumChannels=$(SLINK_NUM_CHANNELS)
PEAKRDL_PARAMS += -P NumLanes=$(SLINK_NUM_LANES)
PEAKRDL_PARAMS += -P Log2MaxClkDiv=$(SLINK_LOG2_MAX_CLK_DIV)
PEAKRDL_PARAMS += -P Log2RawModeTXFifoDepth=$(SLINK_LOG2_RAW_MODE_TX_FIFO_DEPTH)

COPYRIGHT_NOTICE = // Copyright 2025 ETH Zurich and University of Bologna.\n// Solderpad Hardware License, Version 0.51, see LICENSE for details.\n// SPDX-License-Identifier: SHL-0.51\n

# the Makefile variables to configure the serial link do not have a timestamp, meaning Make does not see a reason
# to update the generated sources once they exist. Therefore we force regeneration when parameters change
# with a dummy .params file that changes the timestamp when parameters change
.PHONY: SLINK_FORCE
SLINK_FORCE:

$(SLINK_ROOT)/.params: SLINK_FORCE
	@printf '%s\n' "$(PEAKRDL_PARAMS)" | cmp -s - $@ || printf '%s\n' "$(PEAKRDL_PARAMS)" > $@


$(SLINK_ROOT)/src/regs/rtl/serial_link_reg.sv:$(SLINK_ROOT)/src/regs/rtl/serial_link_reg_pkg.sv
$(SLINK_ROOT)/src/regs/rtl/serial_link_reg_pkg.sv: $(SLINK_ROOT)/src/regs/rdl/serial_link.rdl $(SLINK_ROOT)/.params
	$(PEAKRDL) regblock $< -o $(dir $@) --default-reset arst_n --cpuif apb4-flat $(PEAKRDL_PARAMS)
	@sed -i '1i$(COPYRIGHT_NOTICE)' $@ $(dir $@)/serial_link_reg.sv

$(SLINK_ROOT)/src/regs/rtl/serial_link_addrmap.svh: $(SLINK_ROOT)/src/regs/rdl/serial_link.rdl $(SLINK_ROOT)/.params
	$(PEAKRDL) raw-header $< -o $@ --format svh $(PEAKRDL_PARAMS)
	@sed -i '1i$(COPYRIGHT_NOTICE)' $@

.PHONY: slink-gen-regs slink-gen-regs-only
slink-gen-regs: $(SLINK_ROOT)/src/regs/rtl/serial_link_reg.sv $(SLINK_ROOT)/src/regs/rtl/serial_link_addrmap.svh
slink-gen-regs-only: $(SLINK_ROOT)/src/regs/rtl/serial_link_reg.sv
