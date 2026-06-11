create_clock -name sys_clk -period 37.037 -waveform {0 18.518} [get_ports {sys_clk}]
create_clock -name clk_50m -period 19.943 -waveform {0 9.971} [get_nets {clk_50m}]
