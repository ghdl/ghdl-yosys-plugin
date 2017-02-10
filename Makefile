# Build ghdl module for yosys

# Prefix where ghdl has been installed
GHDL_PREFIX=

ifeq ($(GHDL_PREFIX),)
$(error GHDL_PREFIX not defined)
endif

ghdl.so: ghdl/ghdl.cc
	yosys-config --exec --cxx --cxxflags --ldflags -o $@ -shared $< -DYOSYS_ENABLE_GHDL -I$(GHDL_PREFIX)/include $(GHDL_PREFIX)/lib/libghdlsynth.so -Wl,-rpath,$(GHDL_PREFIX)/lib --ldlibs
