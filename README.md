
# Serial Link
[![SHL-0.51 license](https://img.shields.io/badge/license-SHL--0.51-green)](LICENSE)

The serial link is a simple all-digital Double-Data-Rate (DDR) or Single-Data-Rate (SDR) link with a source-synchronous interface. The link is scalable and can be used for high-bandwidth low latency applications like Die2Die communication as well as lower demanding tasks like binary preloading. The link has an AXI4 interface and implements Protocol, Data Link and Physical layer. The serial link is part of the [PULP (Parallel Ultra-Low Power) Platform](https://pulp-platform.org/) and is being used in various chip tapeouts e.g. [Snitch based Systems](https://github.com/pulp-platform/snitch)

## 🎨 Architecture Overview
The serial link implements the 3 lowest layers of the OSI reference model:
* **Protocol Layer:** AXI requests and the responses are serialized and translated to an AXI-Stream interface
* **Data Link Layer:** Splits the payload of the AXI stream into multiple packets which are distributed over the physical channels. A *Channel Allocator* reshuffles the packets and is able to recover defects of physical channels. It is able to apply back-pressure with a credit-based flow control mechanism. It also synchronizes the packets of multiple channels.
* **Physical Layer:** Parametrizable number of channels and wires per channel. Each TX channel forwards its own source-synchronous clock which is a divided clock of the system clock. The RX channels samples the data with the received clock and has a CDC to synchronize to the local system clock.

## 🔐 License
The Serial Link is released under Solderpad v0.51 (SHL-0.51) see [`LICENSE`](LICENSE):

## ⭐ Getting started

### 🔗 Dependencies

The link uses [bender](https://github.com/pulp-platform/bender) to manage its dependencies and to automatically generate compilation scripts. If you want to change the configuration of the serial link, you need to regenerate the register files, which requires `Python >= 3.11` and the [peakrdl](https://peakrdl-regblock.readthedocs.io/en/latest/) package. For standalone usages of the link with the testbenches, you need additional dependencies (see [pyproject.toml](pyproject.toml)) and we recommend to use [uv](https://docs.astral.sh/uv/) to manage them (see also [CI configuration](.github/workflows/lint.yml)).

### 💡 Integration

The Serial Link provides a make fragment `slink.mk` to simplify the integration into projects. To use it, simply include the fragment in your `Makefile`, e.g.:

```Makefile
# Set root path of the serial link (e.g. using bender)
SLINK_ROOT = $(shell bender path serial_link)

# Overwrite default parameters (optional)
SLINK_NUM_CHANNELS = 2 # default: 1
SLINK_NUM_LANES = 4 # default: 8

# Include the make fragment
include $(SLINK_ROOT)/slink.mk

# Add generated sources as prerequisite to your target (e.g. `all`)
all: $(SLINK_ROOT)/src/regs/slink_reg.sv
```

### 🔬 Simulation

If you want to use or test the Serial Link as a standalone design, it can be simulated with the following steps:

```sh
# To compile the link, run the following command:
make all
# Run the simulation. This will start the simulation in batch mode.
make <simulator>-run-batch
# To open it in the GUI mode, run the following command:
# This command will also add all interesting waves to the wave window.
make <simulator>-run
```

where `<simulator>` can be either `vsim` (for ModelSim/QuestaSim) or `vcs` (for Synopsys VCS). To test the testbench (defaults to `tb_axi_slink`), you can set the `TB_DUT` variable:
```sh
make <simulator>-run TB_DUT=tb_ch_calib_slink
```

## 🔧 Configuration

The link can be parametrized with arbitrary AXI interfaces resp. structs (`axi_req_t`, `axi_rsp_t`). The number of channels and lanes is also configurable at design time. To do this, you have to regenerate the SystemRDL register files with the following command:

```sh
# Generates the registers for the desired configuration
make slink-gen-regs SLINK_NUM_CHANNELS=<num_channels> SLINK_NUM_LANES=<num_lanes>
# Additionall generates the address-map header file required for some testbenches
make slink-gen-regs-all SLINK_NUM_CHANNELS=<num_channels> SLINK_NUM_LANES=<num_lanes>
```

The registers are generated with [peakrdl](https://peakrdl-regblock.readthedocs.io/en/latest/) with the parametrized SystemRDL config file [`slink_reg.rdl`](src/regs/slink_reg.rdl).

### Single-Channel
For simple use cases with lower low bandwidth requirements (e.g. binary preloading), it is recommended to use a single-channel configuration, possibly with Single-Data-Rate. Single-channel configurations come with less overhead for channel synchronization and fault detection.

### Multi-Channel
For use cases that require a higher bandwidth (e.g. Die2Die communication), a multi-channel configuration is recommended. In multi-channel configurations, each channel has its own source-synchronous forwarded clock and the channels are synchronized on the receiver side again. Further, a channel allocator handles faulty channels by redistributing the packets to functional channels. The detection of faulty channels can be done entirely in SW with a special _Raw Mode_ that decouples the link from the AXI interface and allows full controllability and observability of independent channels.
