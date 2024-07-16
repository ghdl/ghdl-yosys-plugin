
USE_DOCKER?=

PROJ ?= leds
TOPLEVEL ?= leds

VHDL_SYN_FILES = leds.vhdl

# choose one implementation
VHDL_SYN_FILES += spin1.vhdl
# VHDL_SYN_FILES += spin2.vhdl

PCF_DEF = pinmap.pcf
PACKAGE = ct256

PLATFORM = ice40
DEVICE = hx8k

include ../tools.mk
include ../common.mk
