# Build ghdl module for yosys

# Name or path to the ghdl executable.
GHDL=ghdl

YOSYS_CONFIG=yosys-config
SOEXT=so

CFLAGS ?= -O

LIBGHDL_LIB:=$(shell $(GHDL) --libghdl-library-path)
LIBGHDL_INC:=$(shell $(GHDL) --libghdl-include-dir)

ALL_LDFLAGS=$(LIBGHDL_LIB) -Wl,-rpath,$(dir $(LIBGHDL_LIB)) $(LDFLAGS)

ALL_CFLAGS=-fPIC -DYOSYS_ENABLE_GHDL -I$(LIBGHDL_INC) $(CFLAGS)

all: ghdl.$(SOEXT)

ghdl.$(SOEXT): ghdl.o
	$(YOSYS_CONFIG) --build $@ $< -shared $(ALL_LDFLAGS)

ghdl.o: src/ghdl.cc
	$(YOSYS_CONFIG) --exec --cxx -c --cxxflags -o $@ $< $(ALL_CFLAGS)

clean: force
	$(RM) -f ghdl.$(SOEXT) ghdl.o

install: ghdl.$(SOEXT)
	$(YOSYS_CONFIG) --exec mkdir -p --datdir/plugins
	$(YOSYS_CONFIG) --exec cp $< --datdir/plugins

force:
