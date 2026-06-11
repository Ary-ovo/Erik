create_clock -name sys_clk -period 37.037 -waveform {0 18.518} [get_ports {sys_clk}]
create_clock -name uart_master_rxclk_int -period 542.535 [get_pins {u_uart_master/i4/u_baudset/rxclk_s1/Q}]
