
ifneq ($(USE_DOCKER),)
# Use Docker tools

DOCKER=docker
#DOCKER=podman

PWD = $(shell pwd)
DOCKERARGS = run --rm -v $(PWD)/../..:/src \
	-w /src/examples/$(notdir $(PWD))

GHDL      = $(DOCKER) $(DOCKERARGS) ghdl/synth:beta ghdl
GHDLSYNTH = ghdl
YOSYS     = $(DOCKER) $(DOCKERARGS) ghdl/synth:beta yosys
NEXTPNR   = $(DOCKER) $(DOCKERARGS) ghdl/synth:nextpnr-$(PLATFORM) nextpnr-$(PLATFORM)
ECPPACK   = $(DOCKER) $(DOCKERARGS) ghdl/synth:trellis ecppack
ICEPACK   = $(DOCKER) $(DOCKERARGS) ghdl/synth:trellis icepack
OPENOCD   = $(DOCKER) $(DOCKERARGS) --device /dev/bus/usb ghdl/synth:prog openocd

ICEPORG   = # ?
ICETIME   = # ?

else
# Use local tools

GHDL      = ghdl
GHDLSYNTH = ghdl
YOSYS     = yosys
NEXTPNR   = nextpnr-$(PLATFORM)
ECPPACK   = ecppack
ICEPACK   = icepack
OPENOCD   = openocd
ICEPROG	  = iceprog
ICETIME	  = icetime

endif
