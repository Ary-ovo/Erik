module top_module (
    input  wire sys_clk,

    input  wire adc_miso,
    output wire adc_cs_n,
    output wire adc_sclk,
    output wire adc_mosi,

    output wire uart_tx,
    input  wire uart_rx,

    output wire led0,
    output wire led1,
    output wire led2,
    output wire led3,
    output wire led4,
    output wire led5
);

    wire clk_50m;
    wire clk_locked;
    internal_clock_50m u_internal_clock_50m (
        .clk_27m(sys_clk),
        .clk    (clk_50m),
        .locked (clk_locked)
    );

    reg [15:0] reset_cnt = 16'd0;
    wire rst_n = clk_locked && (&reset_cnt);

    always @(posedge clk_50m) begin
        if (!clk_locked) begin
            reset_cnt <= 16'd0;
        end else if (!rst_n) begin
            reset_cnt <= reset_cnt + 1'b1;
        end
    end

    wire [3:0]  sample_channel;
    wire [11:0] sample_data;
    wire        sample_valid;
    wire        sweep_done;

    adc_scanner #(
        .CLK_FREQ_HZ      (50000000),
        .FRAME_RATE_HZ    (200),
        .SCLK_HALF_PERIOD (5)
    ) u_adc_scanner (
        .clk            (clk_50m),
        .rst_n          (rst_n),
        .adc_miso       (adc_miso),
        .adc_cs_n       (adc_cs_n),
        .adc_sclk       (adc_sclk),
        .adc_mosi       (adc_mosi),
        .sample_channel (sample_channel),
        .sample_data    (sample_data),
        .sample_valid   (sample_valid),
        .sweep_done     (sweep_done)
    );

    wire [7:0] packet_tx_data;
    wire       packet_tx_valid;
    wire       packet_tx_accept;

    rt_algorithm u_rt_algorithm (
        .clk            (clk_50m),
        .rst_n          (rst_n),
        .sample_channel (sample_channel),
        .sample_data    (sample_data),
        .sample_valid   (sample_valid),
        .sweep_done     (sweep_done),
        .tx_accept      (packet_tx_accept),
        .tx_data        (packet_tx_data),
        .tx_valid       (packet_tx_valid)
    );

    wire        uart_ip_wr_en;
    wire [2:0]  uart_ip_waddr;
    wire [7:0]  uart_ip_wdata;
    wire        uart_ip_rd_en;
    wire [2:0]  uart_ip_raddr;
    wire [7:0]  uart_ip_rdata;
    wire        uart_rx_ready_n;
    wire        uart_tx_ready_n;
    wire        uart_ddis;
    wire        uart_intr;
    wire        uart_dtr_n;
    wire        uart_rts_n;

    uart_master_byte_sender u_uart_sender (
        .clk        (clk_50m),
        .rst_n      (rst_n),
        .tx_data    (packet_tx_data),
        .tx_valid   (packet_tx_valid),
        .tx_accept  (packet_tx_accept),
        .uart_rdata (uart_ip_rdata),
        .uart_wr_en (uart_ip_wr_en),
        .uart_waddr (uart_ip_waddr),
        .uart_wdata (uart_ip_wdata),
        .uart_rd_en (uart_ip_rd_en),
        .uart_raddr (uart_ip_raddr)
    );

    UART_MASTER_Top u_uart_master (
        .I_CLK    (clk_50m),
        .I_RESETN (rst_n),
        .I_TX_EN  (uart_ip_wr_en),
        .I_WADDR  (uart_ip_waddr),
        .I_WDATA  (uart_ip_wdata),
        .I_RX_EN  (uart_ip_rd_en),
        .I_RADDR  (uart_ip_raddr),
        .O_RDATA  (uart_ip_rdata),
        .SIN      (uart_rx),
        .RxRDYn   (uart_rx_ready_n),
        .SOUT     (uart_tx),
        .TxRDYn   (uart_tx_ready_n),
        .DDIS     (uart_ddis),
        .INTR     (uart_intr),
        .DCDn     (1'b0),
        .CTSn     (1'b0),
        .DSRn     (1'b0),
        .RIn      (1'b0),
        .DTRn     (uart_dtr_n),
        .RTSn     (uart_rts_n)
    );

    wire [5:0] led_bus;

    led_stream #(
        .CLK_FREQ_HZ (50000000),
        .STEP_MS     (120)
    ) u_led_stream (
        .clk   (clk_50m),
        .rst_n (rst_n),
        .led   (led_bus)
    );

    assign led0 = led_bus[0];
    assign led1 = led_bus[1];
    assign led2 = led_bus[2];
    assign led3 = led_bus[3];
    assign led4 = led_bus[4];
    assign led5 = led_bus[5];

endmodule

module internal_clock_50m (
    input  wire clk_27m,
    output wire clk,
    output wire locked
);
    wire clkoutp_unused;
    wire clkoutd_unused;
    wire clkoutd3_unused;

    rPLL u_pll (
        .CLKOUT  (clk),
        .CLKOUTP (clkoutp_unused),
        .CLKOUTD (clkoutd_unused),
        .CLKOUTD3(clkoutd3_unused),
        .LOCK    (locked),
        .CLKIN   (clk_27m),
        .CLKFB   (1'b0),
        .FBDSEL  (6'b000000),
        .IDSEL   (6'b000000),
        .ODSEL   (6'b000000),
        .DUTYDA  (4'b0000),
        .PSDA    (4'b0000),
        .FDLY    (4'b0000),
        .RESET   (1'b0),
        .RESET_P (1'b0)
    );

    defparam u_pll.FCLKIN = "27";
    defparam u_pll.DYN_IDIV_SEL = "false";
    defparam u_pll.IDIV_SEL = 6;
    defparam u_pll.DYN_FBDIV_SEL = "false";
    defparam u_pll.FBDIV_SEL = 12;
    defparam u_pll.DYN_ODIV_SEL = "false";
    defparam u_pll.ODIV_SEL = 8;
    defparam u_pll.PSDA_SEL = "0000";
    defparam u_pll.DYN_DA_EN = "false";
    defparam u_pll.DUTYDA_SEL = "1000";
    defparam u_pll.CLKOUT_FT_DIR = 1'b1;
    defparam u_pll.CLKOUTP_FT_DIR = 1'b1;
    defparam u_pll.CLKOUT_DLY_STEP = 0;
    defparam u_pll.CLKOUTP_DLY_STEP = 0;
    defparam u_pll.CLKFB_SEL = "internal";
    defparam u_pll.CLKOUT_BYPASS = "false";
    defparam u_pll.CLKOUTP_BYPASS = "false";
    defparam u_pll.CLKOUTD_BYPASS = "false";
    defparam u_pll.DYN_SDIV_SEL = 2;
    defparam u_pll.CLKOUTD_SRC = "CLKOUT";
    defparam u_pll.CLKOUTD3_SRC = "CLKOUT";
    defparam u_pll.DEVICE = "GW1NR-9C";
endmodule

module uart_master_byte_sender (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] tx_data,
    input  wire       tx_valid,
    output reg        tx_accept,
    input  wire [7:0] uart_rdata,
    output reg        uart_wr_en,
    output reg  [2:0] uart_waddr,
    output reg  [7:0] uart_wdata,
    output reg        uart_rd_en,
    output reg  [2:0] uart_raddr
);

    localparam ST_INIT_LOAD  = 4'd0;
    localparam ST_INIT_WRITE = 4'd1;
    localparam ST_IDLE       = 4'd2;
    localparam ST_RD_SETUP   = 4'd3;
    localparam ST_RD_PULSE   = 4'd4;
    localparam ST_RD_WAIT    = 4'd5;
    localparam ST_RD_CHECK   = 4'd6;
    localparam ST_LOAD_BYTE  = 4'd7;
    localparam ST_WRITE_BYTE = 4'd8;

    reg [3:0] state;
    reg [7:0] byte_latch;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= ST_INIT_LOAD;
            byte_latch <= 8'd0;
            tx_accept  <= 1'b0;
            uart_wr_en <= 1'b0;
            uart_waddr <= 3'd0;
            uart_wdata <= 8'd0;
            uart_rd_en <= 1'b0;
            uart_raddr <= 3'd0;
        end else begin
            tx_accept  <= 1'b0;
            uart_wr_en <= 1'b0;
            uart_rd_en <= 1'b0;

            case (state)
            ST_INIT_LOAD: begin
                uart_waddr <= 3'd3;
                uart_wdata <= 8'h03;
                state      <= ST_INIT_WRITE;
            end

            ST_INIT_WRITE: begin
                uart_wr_en <= 1'b1;
                state      <= ST_IDLE;
            end

            ST_IDLE: begin
                if (tx_valid) begin
                    state <= ST_RD_SETUP;
                end
            end

            ST_RD_SETUP: begin
                uart_raddr <= 3'd5;
                state      <= ST_RD_PULSE;
            end

            ST_RD_PULSE: begin
                uart_rd_en <= 1'b1;
                state      <= ST_RD_WAIT;
            end

            ST_RD_WAIT: begin
                state <= ST_RD_CHECK;
            end

            ST_RD_CHECK: begin
                if (uart_rdata[6] && tx_valid) begin
                    state <= ST_LOAD_BYTE;
                end else if (tx_valid) begin
                    state <= ST_RD_SETUP;
                end else begin
                    state <= ST_IDLE;
                end
            end

            ST_LOAD_BYTE: begin
                byte_latch <= tx_data;
                uart_waddr <= 3'd0;
                uart_wdata <= tx_data;
                tx_accept  <= 1'b1;
                state      <= ST_WRITE_BYTE;
            end

            ST_WRITE_BYTE: begin
                uart_wdata <= byte_latch;
                uart_wr_en <= 1'b1;
                state      <= ST_IDLE;
            end

            default: begin
                state <= ST_INIT_LOAD;
            end
            endcase
        end
    end

endmodule
