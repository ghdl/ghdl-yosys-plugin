# Build ghdl module for yosys

# Name or path to the ghdl executable.
GHDL=ghdl

YOSYS_CONFIG=yosys-config
SOEXT=so

CFLAGS ?= -O

LIBGHDL_LIB:=$(shell $(GHDL) --libghdl-library-path)
LIBGHDL_INC:=$(shell $(GHDL) --libghdl-include-dir)

ALL_LDFLAGS=$(LIBGHDL_LIB) -Wl,-rpath,$(dir $(LIBGHDL_LIB)) $(LDFLAGS)
DATDIR:=$(shell $(YOSYS_CONFIG) --datdir)

ALL_CFLAGS=-fPIC -DYOSYS_ENABLE_GHDL -I$(LIBGHDL_INC) $(CFLAGS)

VER_HASH=$(shell git rev-parse --short HEAD || echo "unknown")

all: ghdl.$(SOEXT)

ghdl.$(SOEXT): ghdl.o
	$(YOSYS_CONFIG) --build $@ $< -shared $(ALL_LDFLAGS)

ghdl.o: src/ghdl.cc
	$(YOSYS_CONFIG) --exec --cxx -c --cxxflags -o $@ $< $(ALL_CFLAGS) -DGHDL_VER_HASH="\"$(VER_HASH)\""

clean: force
	$(RM) -f ghdl.$(SOEXT) ghdl.o

install: ghdl.$(SOEXT)
	$(YOSYS_CONFIG) --exec mkdir -p $(DESTDIR)$(DATDIR)/plugins
	$(YOSYS_CONFIG) --exec cp $< $(DESTDIR)$(DATDIR)/plugins

-include src/ghdl.d

force:
