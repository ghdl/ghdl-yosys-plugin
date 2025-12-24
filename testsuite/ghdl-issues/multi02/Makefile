net/top_synth.json: src/top.v src/sub.vhdl
	#yosys -m ghdl -l log/synth.log -p 'ghdl src/sub.vhdl src/top.vhdl -e top; synth_gatemate -top top -luttree -json net/top_synth.json'
	yosys -m ghdl -l log/synth.log -p 'ghdl src/sub.vhdl -e xor_generic; read_verilog src/top.v; synth_gatemate -top top -luttree -json net/top_synth.json'

top.txt: net/top_synth.json src/top.ccf
	nextpnr-himbaechel --device CCGM1A1 --json net/top_synth.json --vopt ccf=src/top.ccf --vopt out=top.txt --router router2

top.bit: top.txt
	gmpack top.txt top.bit
