# Build ghdl module for yosys

# Prefix where ghdl has been installed
GHDL_PREFIX=

# GHDL_PREFIX must be defined.
ifeq ($(GHDL_PREFIX),)
$(error GHDL_PREFIX not defined)
endif

YOSYS_CONFIG=yosys-config
SOEXT=so

LDFLAGS=
CFLAGS=-O

ALL_LDFLAGS=$(GHDL_PREFIX)/lib/libghdlsynth.so -Wl,-rpath,$(GHDL_PREFIX)/lib $(LDFLAGS)

ALL_CFLAGS=-fPIC -DYOSYS_ENABLE_GHDL -I$(GHDL_PREFIX)/include $(CFLAGS)

COMPILE=$(YOSYS_CONFIG) --exec --cxx

all: ghdl.$(SOEXT)

ghdl.$(SOEXT): ghdl.o
	$(COMPILE) -o $@ -shared $< -shared $(ALL_LDFLAGS) --ldflags --ldlibs

ghdl.o: ghdl/ghdl.cc
	$(COMPILE) -c --cxxflags -o $@ $< $(ALL_CFLAGS)

clean: force
	$(RM) -f ghdl.$(SOEXT) ghdl.o

install: ghdl.$(SOEXT)
	$(YOSYS_CONFIG) --exec mkdir -p --datdir/plugins
	$(YOSYS_CONFIG) --exec cp $< --datdir/plugins

force:
