action = "simulation"
sim_tool = "ghdl"
sim_top = "leds"
ghdl_opt = "--std=08 --ieee=standard "
module = "-m ghdl.so"
sim_post_cmd = (
    "yosys {} -p 'ghdl --work=work {} leds; synth_ice40  -json leds.json'".format(
        module, ghdl_opt
    )
)

files = [
    "leds.vhdl",
    "spin1.vhdl",
]
