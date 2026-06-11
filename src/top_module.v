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

    localparam integer CLK_FREQ_HZ = 27000000;
    localparam integer ADC_VREF_MV = 3400;
    localparam [0:0]   ADC_RANGE_2X = 1'b0;
    localparam integer ADC_FULL_SCALE_MV = ADC_RANGE_2X ? (ADC_VREF_MV * 2) : ADC_VREF_MV;

    reg [15:0] reset_cnt = 16'd0;
    wire rst_n = &reset_cnt;

    always @(posedge sys_clk) begin
        if (!rst_n) begin
            reset_cnt <= reset_cnt + 1'b1;
        end
    end

    wire [3:0]  sample_channel;
    wire [11:0] sample_data;
    wire        sample_valid;
    wire        sweep_done;
    wire [15:0] adc_last_rx_word;
    wire [15:0] adc_channel_seen;

    adc_scanner #(
        .CLK_FREQ_HZ      (CLK_FREQ_HZ),
        .FRAME_RATE_HZ    (20),
        .SCLK_HALF_PERIOD (5),
        .RANGE_2X         (ADC_RANGE_2X)
    ) u_adc_scanner (
        .clk            (sys_clk),
        .rst_n          (rst_n),
        .adc_miso       (adc_miso),
        .adc_cs_n       (adc_cs_n),
        .adc_sclk       (adc_sclk),
        .adc_mosi       (adc_mosi),
        .sample_channel (sample_channel),
        .sample_data    (sample_data),
        .sample_valid   (sample_valid),
        .sweep_done     (sweep_done),
        .last_rx_word   (adc_last_rx_word),
        .channel_seen   (adc_channel_seen)
    );

    wire [7:0] packet_tx_data;
    wire       packet_tx_valid;
    wire       packet_tx_accept;

    rt_algorithm #(
        .ADC_FULL_SCALE_MV (ADC_FULL_SCALE_MV)
    ) u_rt_algorithm (
        .clk            (sys_clk),
        .rst_n          (rst_n),
        .sample_channel (sample_channel),
        .sample_data    (sample_data),
        .sample_valid   (sample_valid),
        .sweep_done     (sweep_done),
        .last_rx_word   (adc_last_rx_word),
        .channel_seen   (adc_channel_seen),
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
        .clk             (sys_clk),
        .rst_n           (rst_n),
        .tx_data         (packet_tx_data),
        .tx_valid        (packet_tx_valid),
        .tx_accept       (packet_tx_accept),
        .uart_rdata      (uart_ip_rdata),
        .uart_tx_ready_n (uart_tx_ready_n),
        .uart_wr_en      (uart_ip_wr_en),
        .uart_waddr      (uart_ip_waddr),
        .uart_wdata      (uart_ip_wdata),
        .uart_rd_en      (uart_ip_rd_en),
        .uart_raddr      (uart_ip_raddr)
    );

    UART_MASTER_Top u_uart_master (
        .I_CLK    (sys_clk),
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
        .RIn      (1'b1),
        .DTRn     (uart_dtr_n),
        .RTSn     (uart_rts_n)
    );

    wire [5:0] led_bus;

    led_stream #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .STEP_MS     (120)
    ) u_led_stream (
        .clk   (sys_clk),
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

module uart_master_byte_sender (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] tx_data,
    input  wire       tx_valid,
    output reg        tx_accept,
    input  wire [7:0] uart_rdata,
    input  wire       uart_tx_ready_n,
    output reg        uart_wr_en,
    output reg  [2:0] uart_waddr,
    output reg  [7:0] uart_wdata,
    output reg        uart_rd_en,
    output reg  [2:0] uart_raddr
);

    localparam [2:0] REG_RBR_THR = 3'd0;
    localparam [2:0] REG_LCR     = 3'd3;
    localparam [2:0] REG_LSR     = 3'd5;

    localparam [3:0] ST_INIT_WRITE = 4'd0;
    localparam [3:0] ST_INIT_GAP   = 4'd1;
    localparam [3:0] ST_IDLE       = 4'd2;
    localparam [3:0] ST_RD_SETUP   = 4'd3;
    localparam [3:0] ST_RD_PULSE   = 4'd4;
    localparam [3:0] ST_RD_WAIT    = 4'd5;
    localparam [3:0] ST_RD_CHECK   = 4'd6;
    localparam [3:0] ST_LOAD_BYTE  = 4'd7;
    localparam [3:0] ST_WRITE_BYTE = 4'd8;
    localparam [3:0] ST_WRITE_GAP  = 4'd9;

    reg [3:0] state;
    reg [7:0] byte_latch;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_INIT_WRITE;
            byte_latch <= 8'd0;
            tx_accept <= 1'b0;
            uart_wr_en <= 1'b0;
            uart_waddr <= REG_LCR;
            uart_wdata <= 8'h03;
            uart_rd_en <= 1'b0;
            uart_raddr <= REG_LSR;
        end else begin
            tx_accept <= 1'b0;
            uart_wr_en <= 1'b0;
            uart_rd_en <= 1'b0;

            case (state)
            ST_INIT_WRITE: begin
                uart_waddr <= REG_LCR;
                uart_wdata <= 8'h03;
                uart_wr_en <= 1'b1;
                state <= ST_INIT_GAP;
            end

            ST_INIT_GAP: begin
                state <= ST_IDLE;
            end

            ST_IDLE: begin
                if (tx_valid) begin
                    state <= ST_RD_SETUP;
                end
            end

            ST_RD_SETUP: begin
                uart_raddr <= REG_LSR;
                state <= ST_RD_PULSE;
            end

            ST_RD_PULSE: begin
                uart_rd_en <= 1'b1;
                state <= ST_RD_WAIT;
            end

            ST_RD_WAIT: begin
                state <= ST_RD_CHECK;
            end

            ST_RD_CHECK: begin
                if (tx_valid && (uart_rdata[6] || !uart_tx_ready_n)) begin
                    byte_latch <= tx_data;
                    uart_waddr <= REG_RBR_THR;
                    uart_wdata <= tx_data;
                    tx_accept <= 1'b1;
                    state <= ST_LOAD_BYTE;
                end else if (tx_valid) begin
                    state <= ST_RD_SETUP;
                end else begin
                    state <= ST_IDLE;
                end
            end

            ST_LOAD_BYTE: begin
                uart_waddr <= REG_RBR_THR;
                uart_wdata <= byte_latch;
                state <= ST_WRITE_BYTE;
            end

            ST_WRITE_BYTE: begin
                uart_wr_en <= 1'b1;
                state <= ST_WRITE_GAP;
            end

            ST_WRITE_GAP: begin
                state <= ST_IDLE;
            end

            default: begin
                state <= ST_INIT_WRITE;
            end
            endcase
        end
    end

endmodule
