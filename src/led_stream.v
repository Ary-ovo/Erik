module led_stream #(
    parameter CLK_FREQ_HZ = 50000000,
    parameter STEP_MS     = 120
)(
    input  wire       clk,
    input  wire       rst_n,
    output reg [5:0]  led
);

    localparam STEP_CLKS = CLK_FREQ_HZ / 1000 * STEP_MS;

    reg [31:0] step_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led      <= 6'b000001;
            step_cnt <= 32'd0;
        end else begin
            if (step_cnt >= STEP_CLKS - 1) begin
                step_cnt <= 32'd0;
                led      <= {led[4:0], led[5]};
            end else begin
                step_cnt <= step_cnt + 1'b1;
            end
        end
    end

endmodule
