# icestick-uart
Simple UART sender and receiver for the lattice icestick. It echoes every received word back.
Configuration: 115200 8N1

## Repository structure
- hdl: Contains the hardware design.
- syn: Contains the scripts and constraints for synthesis.

## Usage
- `cd syn && ./synth.sh`
- configure and open putty or another serial terminal and type something