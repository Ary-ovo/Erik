module adc_scanner #(
    parameter CLK_FREQ_HZ       = 50000000,
    parameter FRAME_RATE_HZ     = 200,
    parameter SCLK_HALF_PERIOD  = 5
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        adc_miso,
    output wire        adc_cs_n,
    output wire        adc_sclk,
    output wire        adc_mosi,
    output reg  [3:0]  sample_channel,
    output reg  [11:0] sample_data,
    output reg         sample_valid,
    output reg         sweep_done
);

    localparam FRAME_PERIOD_CLKS = CLK_FREQ_HZ / FRAME_RATE_HZ;

    localparam ST_WAIT  = 2'd0;
    localparam ST_START = 2'd1;
    localparam ST_BUSY  = 2'd2;

    reg [1:0]  state;
    reg [31:0] frame_cnt;
    reg [3:0]  request_ch;
    reg [4:0]  valid_count;
    reg        warmup_done;
    reg        spi_start;
    reg [15:0] spi_tx_word;

    wire        spi_busy;
    wire        spi_done;
    wire [15:0] spi_rx_word;

    function [15:0] manual_command;
        input [3:0] channel;
        begin
            manual_command = {4'b0001, 1'b1, channel, 1'b0, 1'b0, 5'b00000};
        end
    endfunction

    ads7953_spi #(
        .SCLK_HALF_PERIOD(SCLK_HALF_PERIOD)
    ) u_ads7953_spi (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (spi_start),
        .tx_word (spi_tx_word),
        .miso    (adc_miso),
        .cs_n    (adc_cs_n),
        .sclk    (adc_sclk),
        .mosi    (adc_mosi),
        .rx_word (spi_rx_word),
        .busy    (spi_busy),
        .done    (spi_done)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= ST_WAIT;
            frame_cnt      <= 32'd0;
            request_ch     <= 4'd0;
            valid_count    <= 5'd0;
            warmup_done    <= 1'b0;
            spi_start      <= 1'b0;
            spi_tx_word    <= 16'd0;
            sample_channel <= 4'd0;
            sample_data    <= 12'd0;
            sample_valid   <= 1'b0;
            sweep_done     <= 1'b0;
        end else begin
            spi_start    <= 1'b0;
            sample_valid <= 1'b0;
            sweep_done   <= 1'b0;

            case (state)
            ST_WAIT: begin
                request_ch  <= 4'd0;
                valid_count <= 5'd0;
                warmup_done <= 1'b0;

                if (frame_cnt >= FRAME_PERIOD_CLKS - 1) begin
                    frame_cnt <= 32'd0;
                    state     <= ST_START;
                end else begin
                    frame_cnt <= frame_cnt + 1'b1;
                end
            end

            ST_START: begin
                if (!spi_busy) begin
                    spi_tx_word <= manual_command(request_ch);
                    spi_start   <= 1'b1;
                    state       <= ST_BUSY;
                end
            end

            ST_BUSY: begin
                if (spi_done) begin
                    if (warmup_done) begin
                        sample_channel <= spi_rx_word[15:12];
                        sample_data    <= spi_rx_word[11:0];
                        sample_valid   <= 1'b1;

                        if (valid_count == 5'd15) begin
                            sweep_done  <= 1'b1;
                            state       <= ST_WAIT;
                            request_ch  <= 4'd0;
                            valid_count <= 5'd0;
                            warmup_done <= 1'b0;
                        end else begin
                            valid_count <= valid_count + 1'b1;
                            request_ch  <= request_ch + 1'b1;
                            state       <= ST_START;
                        end
                    end else begin
                        warmup_done <= 1'b1;
                        request_ch  <= request_ch + 1'b1;
                        state       <= ST_START;
                    end
                end
            end

            default: begin
                state <= ST_WAIT;
            end
            endcase
        end
    end

endmodule
