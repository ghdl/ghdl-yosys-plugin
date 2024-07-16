
USE_DOCKER?=

# choose one project to build
PROJ ?= blink
#PROJ = fixed1
#PROJ = multi1
#PROJ = multi2
#PROJ = rotate1
#PROJ = rotate2
#PROJ = rotate3
#PROJ = rotate4
#PROJ = spin1
#PROJ = spin2

TOPLEVEL ?= leds

VHDL_SYN_FILES = leds.vhdl ./*.vhdl

PCF_DEF = leds.pcf
PACKAGE = tq144

PLATFORM = ice40
DEVICE = hx1k

include ../../tools.mk
include ../../common.mk
