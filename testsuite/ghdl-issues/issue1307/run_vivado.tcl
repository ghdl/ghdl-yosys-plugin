read_xdc NexysVideo.xdc
read_edif hdmi_design.edif
link_design -part xc7a35tcpg236-1 -top hdmi_design
opt_design
place_design
route_design
report_utilization
report_timing
write_bitstream -force example.bit
