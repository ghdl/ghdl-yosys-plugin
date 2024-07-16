# examples

Simple examples showing the usage of this plugin.

## Contents

- *ecp5_versa*: Elaborate Mixed-Language ECP5 example with UART, I2C and PLL support. This shows how to include Verilog for synthesis
- *ice40hx8k*: Very simple LED demonstration
- *icestick/leds*: A lot of LED animations and examples
- *icestick/uart*: A loopback UART Transceiver module
- *icezum*: Small demo for the [IceZUM](https://github.com/FPGAwars/icezum) board

## Usage

```bash
make all
```

All examples use `makefile` for compilation.
Simply run `make` to generate a bitstream.
You can then program a board manually or using `make prog`
Programming from the docker container may only work on linux.
See the repository's main README for more details.

In case you don't have all tools installed on your machine you can use tools from the official docker container.
Simply use `make USE_DOCKER=1`.
Be aware that currently only images for `amd64` exist.

The makefiles are split up in a way that each example project only defines variables and imports the `tools.mk` and `common.mk` makefiles in this directory.
These contain all build targets.

Note: these example project are somewhat opinionated with regard to style, structure, and usage.
Your own projects don't have to follow these examples.
The plugin can be adapted to virtually any yosys workflow.
