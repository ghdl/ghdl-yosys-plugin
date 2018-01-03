# ghdlsynth-beta
VHDL synthesis (based on ghdl)

This is awfully experimental and work in progress!

## How to build as a module

Get and install yosys.

Get ghdl from github.

Get the latest version of GNAT:
```sh
$ sudo apt-get install gnat-7
```

From ghdl:
```sh
$ ./configure --disable-werror
```

Then build and install `libghdlsynth.so`. You may need sudo permission.
```sh
$ make libghdlsynth.so
$ make install.libghdlsynth.include
$ make install.libghdlsynth.shared
$ make install.libghdlsynth.static
```

From ghdlsynth-beta:

```sh
make GHDL_PREFIX=/usr/local/
```

This generates `ghdl.so`, which can be used directly:

```sh
$ yosys -m ghdl.so
```

## How to build (not recommended)

Get ghdl from github,
build and install
build and install `libghdlsynth.a`:
```sh
$ make libghdlsynth.a
$ make install.libghdlsynth
```

Get yosys.

From ghdlsynth-beta:
Patch yosys sources using `yosys.diff`
Copy the `ghdl/` directory in `yosys/frontends`

## Configure yosys.
In Makefile.conf, add:
```makefile
ENABLE_GHDL := 1
GHDL_DIR := <ghdl install dir>
```

Build yosys.

## How to use

Example for icestick:

```sh
ghdl -a leds.vhdl
ghdl -a spin1.vhdl
yosys -p 'ghdl leds; synth_ice40 -blif leds.blif'
arachne-pnr -d 1k -o leds.asc -p leds.pcf leds.blif
icepack leds.asc leds.bin
iceprog leds.bin
```
