
USE_DOCKER?=

PROJ ?= uart
TOPLEVEL ?= uart_top

VHDL_SYN_FILES = ./hdl/*.vhd

PCF_DEF = ./syn/constraints/uart.pcf
PACKAGE = tq144

PLATFORM = ice40
DEVICE = hx1k

NEXTPNR_FLAGS=--pcf-allow-unconstrained

include ../../tools.mk
include ../../common.mk
