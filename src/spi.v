module ads7953_spi #(
    parameter SCLK_HALF_PERIOD = 5
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [15:0] tx_word,
    input  wire        miso,
    output reg         cs_n,
    output reg         sclk,
    output reg         mosi,
    output reg  [15:0] rx_word,
    output reg         busy,
    output reg         done
);

    reg [15:0] tx_shift;
    reg [15:0] rx_shift;
    reg [4:0]  bit_cnt;
    reg [15:0] div_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cs_n     <= 1'b1;
            sclk     <= 1'b0;
            mosi     <= 1'b0;
            rx_word  <= 16'd0;
            busy     <= 1'b0;
            done     <= 1'b0;
            tx_shift <= 16'd0;
            rx_shift <= 16'd0;
            bit_cnt  <= 5'd0;
            div_cnt  <= 16'd0;
        end else begin
            done <= 1'b0;

            if (!busy) begin
                sclk    <= 1'b0;
                div_cnt <= 16'd0;

                if (start) begin
                    cs_n     <= 1'b0;
                    busy     <= 1'b1;
                    mosi     <= tx_word[15];
                    tx_shift <= {tx_word[14:0], 1'b0};
                    rx_shift <= 16'd0;
                    bit_cnt  <= 5'd0;
                end else begin
                    cs_n <= 1'b1;
                end
            end else begin
                if (div_cnt == SCLK_HALF_PERIOD - 1) begin
                    div_cnt <= 16'd0;

                    if (!sclk) begin
                        sclk     <= 1'b1;
                        rx_shift <= {rx_shift[14:0], miso};
                    end else begin
                        sclk <= 1'b0;

                        if (bit_cnt == 5'd15) begin
                            cs_n    <= 1'b1;
                            busy    <= 1'b0;
                            done    <= 1'b1;
                            rx_word <= rx_shift;
                        end else begin
                            bit_cnt  <= bit_cnt + 1'b1;
                            mosi     <= tx_shift[15];
                            tx_shift <= {tx_shift[14:0], 1'b0};
                        end
                    end
                end else begin
                    div_cnt <= div_cnt + 1'b1;
                end
            end
        end
    end

endmodule
