# ghdlsynth-beta: VHDL synthesis (based on [ghdl](https://github.com/ghdl/ghdl) and [yosys](https://github.com/YosysHQ/yosys))

**This is experimental and work in progress!**

> TODO: explain purpose of program.
>
> - What is the relationship with GHDL? Is it going to be integrated in GHDL once it is fully featured?
> - What kind of VHDL do we want to support? (GHDL fully supports the 1987, 1993, 2002 versions of the IEEE 1076 VHDL standard, and partially the latest 2008 revision, according to the website)
>- Explain expected input and outputs.
>- Create table with features of VHDL that are supported, WIP and pending.

## Build as a module (shared library)

- Get and install [yosys](https://github.com/YosysHQ/yosys).
- Get sources, build and install [ghdl](https://github.com/ghdl/ghdl). Configure ghdl using at least `--enable-libghdl` and `--enable-synth`:

```sh
$ ./configure --enable-libghdl --enable-synth
$ make
$ make install
```

> NOTE: GHDL must be built with the latest version of GNAT (`gnat-8`).

> HINT: The default build prefix is `/usr/local`. Sudo permission might be required to install tools there.

- Get and build ghdlsynth-beta:

```sh
make
```

> HINT: If ghdl is not available in the PATH, set `GHDL` explicitly, e.g.: `make GHDL=/my/path/to/ghdl`.

The output is a shared library (`ghdl.so` on GNU/Linux), which can be used directly:

```sh
$ yosys -m ghdl.so
```

To install the module, the library must be copied to `YOSYS_PREFIX/share/yosys/plugins/ghdl.so`, where `YOSYS_PREFIX` is the installation path of yosys. This can be achieved through a make target:

```sh
make install
```

Alternatively, the shared library can be copied/installed along with ghdl:

```sh
cp ghdl.so "$GHDL_PREFIX/lib/ghdl_yosys.so"

yosys-config --exec mkdir -p --datdir/plugins
yosys-config --exec ln -s "$GHDL_PREFIX/lib/ghdl_yosys.so" --datdir/plugins/ghdl.so
```

## Build as part of yosys (not recommended)

- Get and build ghdl as in the previous section.

- Get [yosys](https://github.com/YosysHQ/yosys) sources.

- Get ghdlsynth-beta and:
  - Patch yosys sources using `yosys.diff`.
  - Copy `src/*` to `yosys/frontends/ghdl`.
  - Configure yosys by adding (to) `Makefile.conf`:

```makefile
ENABLE_GHDL := 1
GHDL_DIR := <ghdl install dir>
```

- Build and install yosys.

## Usage

Example for icestick, using ghdl, yosys, nextpnr and icestorm:

```sh
cd examples/icestick/

# Analyse VHDL sources
ghdl -a leds.vhdl
ghdl -a spin1.vhdl

# Synthesize the design.
# NOTE: if ghdl is built as a module, set MODULE to '-m ghdl' or '-m path/to/ghdl.so'
yosys $MODULE -p 'ghdl leds; synth_ice40 --json leds.json'

# P&R
nextpnr-ice40 --package hx1k --pcf leds.pcf --asc leds.asc --json leds.json

# Generate bitstream
icepack leds.asc leds.bin

# Program FPGA
iceprog leds.bin
```

Alternatively, it is possible to analyze, elaborate and synthesize VHDL sources at once, instead of calling ghdl and yosys in two steps. In this example: `yosys $MODULE -p 'ghdl leds.vhdl spin1.vhdl -e leds; synth_ice40 --json leds.json`.

## Docker

Docker image [`ghdl/synth:beta`](https://hub.docker.com/r/ghdl/synth/tags) includes yosys, and the ghdl module (shared library). These can be used to synthesize designs straightaway. For example:

```sh
docker run --rm -t \
  -v $(pwd):/src \
  -w /src \
  ghdl/synth:beta \
  yosys -m ghdl -p 'ghdl icestick/leds.vhdl icestick/blink.vhdl -e leds; synth_ice40 -blif leds.blif'
```

> In a system with [docker](https://docs.docker.com/install) installed, the image is automatically downloaded the first time invoked.

Furthermore, the snippet above can be extended in order to P&R the design with [nextpnr](https://github.com/YosysHQ/nextpnr) and generate a bitstream with [icestorm](https://github.com/cliffordwolf/icestorm) tools:

```sh
DOCKER_CMD="$(command -v winpty) docker run --rm -it -v /$(pwd)://wrk -w //wrk"

$DOCKER_CMD ghdl/synth:beta     yosys -m ghdl -p 'ghdl leds.vhdl rotate4.vhdl -e leds; synth_ice40 -json leds.json'
$DOCKER_CMD ghdl/synth:nextpnr  nextpnr-ice40 --hx1k --json leds.json --pcf leds.pcf --asc leds.asc
$DOCKER_CMD ghdl/synth:icestorm icepack leds.asc leds.bin

iceprog leds.bin
```

> NOTE: on GNU/Linux, it should be possible to use `iceprog` through `ghdl/synth:icestorm`. On Windows and macOS, accessing USB/COM ports of the host from containers seems not to be supported yet. Therefore, `iceprog` is required to be available on the host.
