# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## 2.0.0 - 2026-04-07

### Added
- Added support for Single-Data-Rate (SDR) PHY option for simpler links.

### Changed
- **Breaking**: Renamed all `serial_link_*` IP modules and files to `slink_*` (e.g., `serial_link.sv` -> `slink.sv`, `serial_link_physical.sv` -> `slink_phys_layer.sv`). Users instantiating the core will need to update module names.
- **Breaking**: Migrated register generation from `reggen` to `systemRDL` and changed the register interface to APB. This updates the register memory map headers and RTL files (`slink_reg.sv`, `slink_reg_pkg.sv`).
- **Breaking**: Renamed the `occamy_wrapper` module to `slink_isolate` to reflect its general utility for isolation in other projects.
- Architecturally renamed the "network layer" to the "protocol layer" (`slink_prot_layer`).
- Removed internal `axis` dependencies and `axi_channel_compare` in favor of their upstream versions, and shifted to a cleaned-up internal wiring architecture.
- Cleaned up the `slink_pkg` package by removing redundant or obsolete constants and types.
- Replaced the project `Makefile` with a `justfile` for build automation.
- Switched to `uv` for handling Python dependencies, replacing the standard `pip`/`requirements.txt` workflow.
- Testbenches are no longer automatically imported under the `Bender` simulation target.
- Migrated project license checking to REUSE.

### Fixed
- **Breaking**: Fixed the `ddr_sel` output path in the PHY with a `tc_clk_mux2`. This means users will need to make sure to have a `tc_clk_mux2` technology cell specified for FPGA or ASIC implementations.
- Fixed testbench port assignments in `tb_channel_allocator` and other refactoring typos in the hardware layers.

## 1.1.2 - 2024-08-30

- Removed ternary statement in `serial_link_physical` for better EDA tool compatibility.

## 1.1.1 - 2024-02-07

### Changed

- The DDR output data is now muxed by a normal signal instead of a clock signal. Some tools infer a clock gate when a clock signal is used as a mux select signal.

## 1.1.0 - 2023-07-03

### Changed
- Renamed clock division configuration registers to deliberately introduce breaking changes when using the old incorrect configuration registers.

### Fixed
- SW Clock division configuration

## 1.0.1 - 2023-03-13

### Changed
- Added `NoRegCdc` parameter to `serial_link` module to disable the CDC between the RegBus Clock and the System Clock

## 1.0.0 - 2023-01-26
- Initial release
