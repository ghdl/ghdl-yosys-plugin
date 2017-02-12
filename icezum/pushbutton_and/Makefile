PROJ = pushbutton_and
PIN_DEF = $(PROJ).pcf
DEVICE = hx1k

all: $(PROJ).rpt $(PROJ).bin

%.blif: %.vhdl
	ghdl -a $(PROJ).vhdl
	yosys -m ../../ghdl.so -p 'ghdl $(PROJ); synth_ice40 -blif $@'


%.asc: $(PIN_DEF) %.blif
	arachne-pnr -d $(subst hx,,$(subst lp,,$(DEVICE))) -o $@ -p $^

%.bin: %.asc
	icepack $< $@

%.rpt: %.asc
	icetime -d $(DEVICE) -mtr $@ $<

prog: $(PROJ).bin
	iceprog $<

sudo-prog: $(PROJ).bin
	@echo 'Executing prog as root!!!'
	sudo iceprog $<

clean:
	rm -f $(PROJ).blif $(PROJ).asc $(PROJ).rpt $(PROJ).bin work-obj93.cf

.SECONDARY:
.PHONY: all prog clean
