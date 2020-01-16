#!/usr/bin/env sh

cd $(dirname $0)

DOCKER_CMD="docker run --rm -v /$(pwd)://wrk -w //wrk"

mkdir -p build

for prj in blink counter led_on pushbutton; do
  $DOCKER_CMD ghdl/synth:beta     yosys -m ghdl -p "ghdl $prj.vhdl -e $prj; synth_ice40 -json build/json"
  $DOCKER_CMD ghdl/synth:nextpnr  nextpnr-ice40 --hx1k --json build/json --pcf icezum.pcf --asc build/asc
  $DOCKER_CMD ghdl/synth:icestorm icepack build/asc build/$prj.bin
done
