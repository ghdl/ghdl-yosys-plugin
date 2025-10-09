
USE_DOCKER?=

PROJ ?= versa_ecp5_top
TOPLEVEL ?= versa_ecp5_top

VHDL_SYN_FILES = versa_ecp5_top.vhdl pll_mac.vhd
VHDL_SYN_FILES += soc_iomap_pkg.vhdl
VHDL_SYN_FILES += uart.vhdl uart_tx.vhdl uart_rx.vhdl fifobuf.vhdl

LPF_DEF = versa_ecp5.lpf
PACKAGE = CABGA381

NEXTPNR_FLAGS = --um5g-45k --freq 100
NEXTPNR_FLAGS += --lpf-allow-unconstrained

OPENOCD_JTAG_CONFIG = ../../openocd/ecp5-versa.cfg
OPENOCD_DEVICE_CONFIG = ../../openocd/LFE5UM5G-45F.cfg

VERILOG_FILES = $(PLUGIN_LIB)/wrapper/primitives.v
VERILOG_FILES += $(PLUGIN_LIB)/wrapper/bram.v

GHDL_FLAGS = -Plib
PLATFORM = ecp5

LOCAL_LIB=./lib

include ../tools.mk
include ../common.mk

# this project requires verilog wrappers to enable vendor black-box components
# these are defined in project-root/library
# the following targets compile these wrappers into a project specific directory

# NOTE: if you're using VHDL-2008 you MUST rename the file suffix to "-std08.cf"

lib:
	mkdir $@

$(LOCAL_LIB)/ecp5um-std93.cf: $(PLUGIN_LIB)/ecp5u/components.vhdl | lib
	$(GHDL) -i --workdir=$(dir $@) --work=ecp5um $<

DEPENDENCIES = $(LOCAL_LIB)/ecp5um-std93.cf
pll_mac.vhd: $(DEPENDENCIES)
