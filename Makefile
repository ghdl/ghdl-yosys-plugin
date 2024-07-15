# Build ghdl module for yosys

# Name or path to the ghdl executable.
GHDL=ghdl
GIT_VERSION_RAW := "$(shell git describe --dirty --always --tags)"
GIT_VERSION = '$(GIT_VERSION_RAW)'

YOSYS_CONFIG=yosys-config
SOEXT=so

CFLAGS ?= -O

LIBGHDL_LIB:=$(shell $(GHDL) --libghdl-library-path)
LIBGHDL_INC:=$(shell $(GHDL) --libghdl-include-dir)

ALL_LDFLAGS=$(LIBGHDL_LIB) -Wl,-rpath,$(dir $(LIBGHDL_LIB)) $(LDFLAGS)
PLUGINDIR:=$(shell $(YOSYS_CONFIG) --datdir)/plugins

ALL_CFLAGS=-fPIC -DYOSYS_ENABLE_GHDL -DVERSION=$(GIT_VERSION) -I$(LIBGHDL_INC) $(CFLAGS)

VER_HASH=$(shell git rev-parse --short HEAD || echo "unknown")

all: ghdl.$(SOEXT)

ghdl.$(SOEXT): ghdl.o vhdl_backend.o
	$(YOSYS_CONFIG) --build $@ $^ -shared $(ALL_LDFLAGS)

ghdl.o: src/ghdl.cc
	$(YOSYS_CONFIG) --exec --cxx -c --cxxflags -o $@ $< $(ALL_CFLAGS) -DGHDL_VER_HASH="\"$(VER_HASH)\""

vhdl_backend.o: src/vhdl_backend.cc
	$(YOSYS_CONFIG) --exec --cxx -c --cxxflags -o $@ $< $(ALL_CFLAGS)

clean: force
	$(RM) -f ghdl.$(SOEXT) ghdl.o vhdl_backend.o

install: ghdl.$(SOEXT)
	$(YOSYS_CONFIG) --exec mkdir -p $(DESTDIR)$(PLUGINDIR)
	$(YOSYS_CONFIG) --exec cp $< $(DESTDIR)$(PLUGINDIR)

-include src/ghdl.d

force:
