PROJ ?= blink
PIN_DEF = icezum.pcf
DEVICE = hx1k

all: report bin

json: $(PROJ).vhdl
	yosys -m ghdl -p 'ghdl $(PROJ).vhdl -e $(PROJ); synth_ice40 -json $@'

asc: $(PIN_DEF) json
	nextpnr-ice40 --$(DEVICE) --json json --pcf $(PIN_DEF) --asc $@

bin: asc
	icepack $< $@

report: asc
	icetime -d $(DEVICE) -mtr $@ $<

clean:
	rm -f json asc bin report work-obj93.cf

.SECONDARY:
.PHONY: all prog clean
