# Common makefile for GHDL synthesis

PLUGIN_LIB = ../../library

ifneq ($(VERILOG_FILES),)
MAYBE_READ_VERILOG = read_verilog $(VERILOG_FILES);
endif

# agnostic synthesis
%.json: $(VHDL_SYN_FILES)
	$(YOSYS) -m $(GHDLSYNTH) -p \
		"ghdl $(GHDL_FLAGS) $(GHDL_GENERICS) $^ -e $(TOPLEVEL); \
		$(MAYBE_READ_VERILOG) \
		synth_$(PLATFORM) \
		-top $(TOPLEVEL)$(TOPLEVEL_PARAMETER) -json $@" 2>&1

# ECP pouting
%.config: %.json
	$(NEXTPNR) --json $< --lpf $(LPF_DEF) \
		--textcfg $@ $(NEXTPNR_FLAGS) --package $(PACKAGE)

# ECP packing
%.svf: %.config
	$(ECPPACK) --svf $*.svf $< $@

# ICE routing
%.asc: %.json
	$(NEXTPNR) --$(DEVICE) --json $< \
	--package $(PACKAGE) --pcf $(PCF_DEF) \
	--asc $@ $(NEXTPNR_FLAGS)

# ICE packing
%.bin: %.asc
	$(ICEPACK) $< $@

ifeq ($(PLATFORM), ecp5)

# ECP5 bitstream target
bitstream: $(PROJ).svf

# ECP programming
prog: $(PROJ).svf
	$(OPENOCD) -f $(OPENOCD_JTAG_CONFIG) -f $(OPENOCD_DEVICE_CONFIG) \
		-c "transport select jtag; init; svf $<; exit"

else ifeq ($(PLATFORM), ice40)

# ICE bitstream target
bitstream: report $(PROJ).bin

# ICE programming
prog: $(PROJ).bin
	$(ICEPROG) $<

# ICE timing report
report: $(PROJ).asc
	$(ICETIME) -d $(DEVICE) -mtr $@.txt $<
endif

clean:
	rm -rf ./*.json ./*.asc ./*.bin ./report.txt ./*.work-obj93.cf \
		./*.work-obj08.cf ./*.config ./*.svf $(LOCAL_LIB)

all: bitstream

.PRECIOUS: %.json %.config
.PHONY: bitstream report clean all
.DEFAULT: all
