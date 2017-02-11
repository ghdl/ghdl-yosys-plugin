# Build ghdl module for yosys

# Prefix where ghdl has been installed
GHDL_PREFIX=

# GHDL_PREFIX must be defined.
ifeq ($(GHDL_PREFIX),)
$(error GHDL_PREFIX not defined)
endif

LDFLAGS=
CFLAGS=-O

ALL_LDFLAGS=$(GHDL_PREFIX)/lib/libghdlsynth.so -Wl,-rpath,$(GHDL_PREFIX)/lib $(LDFLAGS)

ALL_CFLAGS=-fPIC -DYOSYS_ENABLE_GHDL -I$(GHDL_PREFIX)/include $(CFLAGS)

COMPILE=yosys-config --exec --cxx

all: ghdl.so

ghdl.so: ghdl.o
	$(COMPILE) -o $@ -shared $< -shared $(ALL_LDFLAGS) --ldflags --ldlibs

ghdl.o: ghdl/ghdl.cc
	$(COMPILE) -c --cxxflags -o $@ $< $(ALL_CFLAGS)

clean: force
	$(RM) -f ghdl.so ghdl.o

force:
