PROJ = blink
#PROJ = fixed1
#PROJ = multi1
#PROJ = multi2
#PROJ = rotate1
#PROJ = rotate2
#PROJ = rotate3
#PROJ = rotate4
#PROJ = spin1
#PROJ = spin2

PIN_DEF = leds.pcf
DEVICE = hx1k

all: $(PROJ).bin

%.json: leds.vhdl %.vhdl
	yosys -m ghdl -p 'ghdl $^ -e leds; synth_ice40 -json $@'

%.asc: %.json
	nextpnr-ice40 --package $(DEVICE) --pcf $(PIN_DEF) --json $< --asc $@

%.bin: %.asc
	icepack $< $@

prog: $(PROJ).bin
	iceprog $<

clean:
	rm -f $(PROJ).json $(PROJ).asc $(PROJ).bin

.SECONDARY:

.PHONY: all prog clean
