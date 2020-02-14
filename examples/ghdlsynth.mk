# Common makefile for GHDL synthesis

# Specify:
#
# VHDL_SYN_FILES = VHDL files for synthesis, unordered
# VERILOG_FILES = auxiliary verilog wrappers that might be needed
# PLATFORM: 'ecp5' for now
# TOPLEVEL: top level entity name
# TOPLEVEL_PARAMETER: top level entity name parameters, when passed a generic
# LPF: I/O constraints file

PLATFORM ?= ecp5

ifneq ($(VERILOG_FILES),)
MAYBE_READ_VERILOG = read_verilog $(VERILOG_FILES);
endif

%.json: $(VHDL_SYN_FILES)
	$(YOSYS) -m $(GHDLSYNTH) -p \
		"ghdl $(GHDL_FLAGS) $(GHDL_GENERICS) $^ -e $(TOPLEVEL); \
		$(MAYBE_READ_VERILOG) \
		synth_$(PLATFORM) \
		-top $(TOPLEVEL)$(TOPLEVEL_PARAMETER) -json $@" 2>&1 | tee $*-report.txt

%.config: %.json
	$(NEXTPNR) --json $< --lpf $(LPF) \
		--textcfg $@ $(NEXTPNR_FLAGS) --package $(PACKAGE)

%.svf: %.config
	$(ECPPACK) --svf $*.svf $< $@


.PRECIOUS: %.json %.config
	
