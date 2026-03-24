
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

The link uses [bender](https://github.com/pulp-platform/bender) to manage its dependencies and to automatically generate compilation scripts. Simulation and register generation are driven by [just](https://github.com/casey/just). If you want to change the configuration of the serial link, you need to regenerate the register files, which requires `Python >= 3.11` and the [peakrdl](https://peakrdl-regblock.readthedocs.io/en/latest/) package. Register generation uses [uv](https://github.com/astral-sh/uv) to run peakrdl without requiring a manual environment setup.

Tool versions for EDA tools (simulators, bender) can be configured via a `.env` file. A template for IIS-internal tool versions is provided in [`.iis_env`](.iis_env):

```sh
ln -s .iis_env .env
```

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
# Compile the design (simulator: vsim [default], vcs)
just compile
just compile vcs

# Run in batch mode
just run-batch
just run-batch vcs

# Open in GUI mode (also loads wave files)
just run
just run vcs
```

To use a different testbench (default: `tb_axi_slink`), pass it as the second argument:
```sh
just compile vcs tb_ch_calib_slink
just run-batch vcs tb_ch_calib_slink
```

## 🔧 Configuration

The link can be parametrized with arbitrary AXI interfaces resp. structs (`axi_req_t`, `axi_rsp_t`). The number of channels and lanes is also configurable at design time. To do this, you have to regenerate the SystemRDL register files with the following command:

```sh
# Generates the registers for the desired configuration
just gen-regs SLINK_NUM_CHANNELS=<num_channels> SLINK_NUM_LANES=<num_lanes>
```

The registers are generated with [peakrdl](https://peakrdl-regblock.readthedocs.io/en/latest/) with the parametrized SystemRDL config file [`slink_reg.rdl`](src/regs/slink_reg.rdl).

### Single-Channel
For simple use cases with lower low bandwidth requirements (e.g. binary preloading), it is recommended to use a single-channel configuration, possibly with Single-Data-Rate. Single-channel configurations come with less overhead for channel synchronization and fault detection.

### Multi-Channel
For use cases that require a higher bandwidth (e.g. Die2Die communication), a multi-channel configuration is recommended. In multi-channel configurations, each channel has its own source-synchronous forwarded clock and the channels are synchronized on the receiver side again. Further, a channel allocator handles faulty channels by redistributing the packets to functional channels. The detection of faulty channels can be done entirely in SW with a special _Raw Mode_ that decouples the link from the AXI interface and allows full controllability and observability of independent channels.
