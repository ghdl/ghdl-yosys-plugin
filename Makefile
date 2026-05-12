# Build ghdl module for yosys

# Name or path to the ghdl executable.
GHDL=ghdl

YOSYS_CONFIG=yosys-config
SOEXT=so

CFLAGS ?= -O

LIBGHDL_LIB:=$(shell $(GHDL) --libghdl-library-path)
LIBGHDL_INC:=$(shell $(GHDL) --libghdl-include-dir)

ALL_LDFLAGS=$(LIBGHDL_LIB) -Wl,-rpath,$(dir $(LIBGHDL_LIB)) $(LDFLAGS)
PLUGINDIR:=$(shell $(YOSYS_CONFIG) --datdir)/plugins

ALL_CFLAGS=-fPIC -DYOSYS_ENABLE_GHDL -I$(LIBGHDL_INC) $(CFLAGS)

VER_HASH=$(shell git rev-parse --short HEAD || echo "unknown")

OBJS=ghdl.o ghdl_rename.o vhdl_backend.o

all: ghdl.$(SOEXT)

ghdl.$(SOEXT): $(OBJS)
	$(YOSYS_CONFIG) --exec --cxx --cxxflags --ldflags -o $@ $^ -shared $(ALL_LDFLAGS)

ghdl.o: src/ghdl.cc
	$(YOSYS_CONFIG) --exec --cxx -c --cxxflags -o $@ $< $(ALL_CFLAGS) -DGHDL_VER_HASH="\"$(VER_HASH)\""

ghdl_rename.o: src/ghdl_rename.cc
	$(YOSYS_CONFIG) --exec --cxx -c --cxxflags -o $@ $< $(ALL_CFLAGS)

vhdl_backend.o: src/vhdl_backend.cc src/vhdl_backend.h
	$(YOSYS_CONFIG) --exec --cxx -c --cxxflags -o $@ $< $(ALL_CFLAGS)

clean: force
	$(RM) -f ghdl.$(SOEXT) $(OBJS)

install: ghdl.$(SOEXT)
	mkdir -p $(DESTDIR)$(PLUGINDIR)
	cp $< $(DESTDIR)$(PLUGINDIR)

-include src/ghdl.d
.PHONY: all clean install force

force:
