<p align="center">
  <a title="GHDL synthesis documentation" href="https://ghdl.github.io/ghdl/using/Synthesis.html"><img src="https://img.shields.io/website.svg?label=ghdl.github.io%2Fghdl&longCache=true&style=flat-square&url=http%3A%2F%2Fghdl.github.io%2Fghdl%2Findex.html"></a><!--
  -->
  <a title="Join the chat at https://gitter.im/ghdl1/Lobby" href="https://gitter.im/ghdl1/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge"><img src="https://img.shields.io/badge/chat-on%20gitter-4db797.svg?longCache=true&style=flat-square&logo=gitter&logoColor=e8ecef"></a><!--
  -->
  <a title="Docker Images" href="https://github.com/ghdl/docker"><img src="https://img.shields.io/docker/pulls/ghdl/synth.svg?logo=docker&logoColor=e8ecef&style=flat-square&label=docker"></a><!--
  -->
  <a title="'push' workflow Status" href="https://github.com/ghdl/ghdl-yosys-plugin/actions?query=workflow%3Apush"><img alt="'push' workflow Status" src="https://img.shields.io/github/workflow/status/ghdl/ghdl-yosys-plugin/push?longCache=true&style=flat-square&label=push&logo=Github%20Actions&logoColor=fff"></a>
</p>

# ghdl-yosys-plugin: VHDL synthesis (based on [GHDL](https://github.com/ghdl/ghdl) and [Yosys](https://github.com/YosysHQ/yosys))

**This is experimental and work in progress!** See [ghdl.github.io/ghdl: Using/Synthesis](http://ghdl.github.io/ghdl/using/Synthesis.html).

> TODO: Create table with features of VHDL that are supported, WIP and pending.

## Build as a module (shared library)

> On Windows, Yosys does not support loading modules dynamically. Therefore, this build approach is not possible. See [*Build as part of Yosys*](#build-as-part-of-yosys-not-recommended) below.

- Get and install [Yosys](https://github.com/YosysHQ/yosys).
- Get sources, build and install [GHDL](https://github.com/ghdl/ghdl). Ensure that GHDL is configured with synthesis features (enabled by default since v0.37). See [Building GHDL](https://github.com/ghdl/ghdl#building-ghdl).

> NOTE: GHDL must be built with at least version of 8 GNAT (`gnat-8`).

> HINT: The default build prefix is `/usr/local`. Sudo permission might be required to install tools there.

- Get and build ghdl-yosys-plugin: `make`.

> HINT: If ghdl is not available in the PATH, set `GHDL` explicitly, e.g.: `make GHDL=/my/path/to/ghdl`.

The output is a shared library (`ghdl.so` on GNU/Linux), which can be used directly: `yosys -m ghdl.so`.

To install the module, the library must be copied to `YOSYS_PREFIX/share/yosys/plugins/ghdl.so`, where `YOSYS_PREFIX` is the installation path of yosys. This can be achieved through a make target: `make install`.

Alternatively, the shared library can be copied/installed along with GHDL:

```sh
cp ghdl.so "$GHDL_PREFIX/lib/ghdl_yosys.so"

yosys-config --exec mkdir -p --datdir/plugins
yosys-config --exec ln -s "$GHDL_PREFIX/lib/ghdl_yosys.so" --datdir/plugins/ghdl.so
```

## Build as part of yosys (not recommended)

- Get and build GHDL as in the previous section.

- Get [Yosys](https://github.com/YosysHQ/yosys) sources.

- Get ghdl-yosys-plugin and:
  - Copy `src/*` to `yosys/frontends/ghdl`.
  - Configure Yosys by adding (to) `Makefile.conf`:

```makefile
ENABLE_GHDL := 1
GHDL_PREFIX := <ghdl install dir>
```

- Build and install Yosys.

## Pre-built packages

Some projects provide pre-built packages including GHDL, Yosys and ghdl-yosys-plugin. Unless you have specific requirements (targeting a different arch, OS, build options...), we suggest using one of the following solutions before building ghdl-yosys-plugin from sources.

- [open-tool-forge/fpga-toolchain](https://github.com/open-tool-forge/fpga-toolchain) provides tarballs for GNU/Linux, Windows or macOS, including statically built EDA tools. Packages are available for x86 or amd64.

- On Windows, there is a package group in [MSYS2](https://www.msys2.org/) repositories named [mingw-w64-x86_64-eda](https://packages.msys2.org/group/mingw-w64-x86_64-eda)|[mingw-w64-i686-eda](https://packages.msys2.org/group/mingw-w64-i686-eda). See [hdl/MINGW-packages](https://github.com/hdl/MINGW-packages).

## Usage

Example for IceStick, using GHDL, Yosys, nextpnr and icestorm:

```sh
cd examples/icestick/leds/

# Analyse VHDL sources
ghdl -a leds.vhdl
ghdl -a spin1.vhdl

# Synthesize the design.
# NOTE: if GHDL is built as a module, set MODULE to '-m ghdl' or '-m path/to/ghdl.so',
#       otherwise, unset it.
yosys $MODULE -p 'ghdl leds; synth_ice40 -json leds.json'

# P&R
nextpnr-ice40 --package hx1k --pcf leds.pcf --asc leds.asc --json leds.json

# Generate bitstream
icepack leds.asc leds.bin

# Program FPGA
iceprog leds.bin
```

Alternatively, it is possible to analyze, elaborate and synthesize VHDL sources at once, instead of calling GHDL and Yosys in two steps. In this example:

```
yosys $MODULE -p 'ghdl leds.vhdl spin1.vhdl -e leds; synth_ice40 -json leds.json'
```

## Containers

Container (aka Docker/Podman) image [`hdlc/ghdl:yosys`](https://hub.docker.com/r/hdlc/ghdl/tags) includes GHDL, Yosys and the ghdl-yosys-plugin module (shared library). These can be used to synthesize designs straightaway. For example:

```sh
docker run --rm -t \
  -v $(pwd)/examples/icestick/leds:/src \
  -w /src \
  hdlc/ghdl:yosys \
  yosys -m ghdl -p 'ghdl leds.vhdl blink.vhdl -e leds; synth_ice40 -json leds.json'
```

> In a system with [docker](https://docs.docker.com/install) installed, the image is automatically downloaded the first time invoked.

Furthermore, the snippet above can be extended in order to P&R the design with [nextpnr](https://github.com/YosysHQ/nextpnr) and generate a bitstream with [icestorm](https://github.com/cliffordwolf/icestorm) tools:

```sh
cd examples/icestick/leds/

DOCKER_CMD="$(command -v winpty) docker run --rm -it -v /$(pwd)://wrk -w //wrk"

$DOCKER_CMD hdlc/ghdl:yosys    yosys -m ghdl -p 'ghdl leds.vhdl rotate4.vhdl -e leds; synth_ice40 -json leds.json'
$DOCKER_CMD hdlc/nextpnr:ice40 nextpnr-ice40 --hx1k --json leds.json --pcf leds.pcf --asc leds.asc
$DOCKER_CMD hdlc/icestorm      icepack leds.asc leds.bin

iceprog leds.bin
```

See [hdl/containers](https://github.com/hdl/containers) for further info about containers including other EDA tools.

> NOTE: on GNU/Linux, it should be possible to use board programming tools through `hdlc/icestorm`. On Windows and macOS, accessing USB/COM ports of the host from containers is challenging. Therefore, board programming tools need to be available on the host. Windows users can find several board programming tools available as [MSYS2](https://www.msys2.org/) packages. See [mingw-w64-x86_64-eda](https://packages.msys2.org/group/mingw-w64-x86_64-eda)|[mingw-w64-i686-eda](https://packages.msys2.org/group/mingw-w64-i686-eda) and [hdl/MINGW-packages](https://github.com/hdl/MINGW-packages).
