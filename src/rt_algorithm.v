module rt_algorithm #(
    parameter integer ADC_FULL_SCALE_MV = 2500
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [3:0]  sample_channel,
    input  wire [11:0] sample_data,
    input  wire        sample_valid,
    input  wire        sweep_done,
    input  wire [15:0] last_rx_word,
    input  wire [15:0] channel_seen,
    input  wire        tx_accept,
    output reg  [7:0]  tx_data,
    output wire        tx_valid
);

    reg [11:0] samples [0:15];
    reg [7:0]  sequence;
    reg [4:0]  field_index;
    reg [3:0]  char_index;
    reg        sending;
    reg [15:0] last_rx_word_latch;
    reg [15:0] channel_seen_latch;

    assign tx_valid = sending;

    function [7:0] hex_char;
        input [3:0] value;
        begin
            if (value < 4'd10) begin
                hex_char = "0" + value;
            end else begin
                hex_char = "A" + (value - 4'd10);
            end
        end
    endfunction

    function [7:0] dec_char;
        input [3:0] value;
        begin
            dec_char = "0" + value;
        end
    endfunction

    function [15:0] sample_mv;
        input [11:0] code;
        reg [31:0] scaled;
        reg [31:0] rounded;
        begin
            scaled = code * ADC_FULL_SCALE_MV;
            rounded = scaled + 32'd2048;
            sample_mv = rounded[27:12];

            if (code == 12'hfff) begin
                sample_mv = ADC_FULL_SCALE_MV;
            end
        end
    endfunction

    function [11:0] sample_value;
        input [3:0] channel;
        begin
            case (channel)
            4'h0: sample_value = samples[0];
            4'h1: sample_value = samples[1];
            4'h2: sample_value = samples[2];
            4'h3: sample_value = samples[3];
            4'h4: sample_value = samples[4];
            4'h5: sample_value = samples[5];
            4'h6: sample_value = samples[6];
            4'h7: sample_value = samples[7];
            4'h8: sample_value = samples[8];
            4'h9: sample_value = samples[9];
            4'ha: sample_value = samples[10];
            4'hb: sample_value = samples[11];
            4'hc: sample_value = samples[12];
            4'hd: sample_value = samples[13];
            4'he: sample_value = samples[14];
            4'hf: sample_value = samples[15];
            default: sample_value = 12'h000;
            endcase
        end
    endfunction

    function [7:0] prefix_byte;
        input [3:0] index;
        begin
            case (index)
            4'd0: prefix_byte = "S";
            4'd1: prefix_byte = "E";
            4'd2: prefix_byte = "Q";
            4'd3: prefix_byte = "=";
            4'd4: prefix_byte = hex_char(sequence[7:4]);
            4'd5: prefix_byte = hex_char(sequence[3:0]);
            4'd6: prefix_byte = " ";
            default: prefix_byte = " ";
            endcase
        end
    endfunction

    function [7:0] channel_byte;
        input [3:0] channel;
        input [3:0] index;
        reg [15:0] mv;
        begin
            mv = sample_mv(sample_value(channel));
            case (index)
            4'd0: channel_byte = " ";
            4'd1: channel_byte = "C";
            4'd2: channel_byte = "H";
            4'd3: channel_byte = hex_char(channel);
            4'd4: channel_byte = "=";
            4'd5: channel_byte = dec_char((mv / 16'd1000) % 16'd10);
            4'd6: channel_byte = ".";
            4'd7: channel_byte = dec_char((mv / 16'd100) % 16'd10);
            4'd8: channel_byte = dec_char((mv / 16'd10) % 16'd10);
            4'd9: channel_byte = dec_char(mv % 16'd10);
            4'd10: channel_byte = "V";
            default: channel_byte = " ";
            endcase
        end
    endfunction

    function [7:0] raw_byte;
        input [3:0] index;
        begin
            case (index)
            4'd0:  raw_byte = " ";
            4'd1:  raw_byte = "R";
            4'd2:  raw_byte = "A";
            4'd3:  raw_byte = "W";
            4'd4:  raw_byte = "=";
            4'd5:  raw_byte = "0";
            4'd6:  raw_byte = "x";
            4'd7:  raw_byte = hex_char(last_rx_word_latch[15:12]);
            4'd8:  raw_byte = hex_char(last_rx_word_latch[11:8]);
            4'd9:  raw_byte = hex_char(last_rx_word_latch[7:4]);
            4'd10: raw_byte = hex_char(last_rx_word_latch[3:0]);
            default: raw_byte = " ";
            endcase
        end
    endfunction

    function [7:0] seen_byte;
        input [3:0] index;
        begin
            case (index)
            4'd0:  seen_byte = " ";
            4'd1:  seen_byte = "S";
            4'd2:  seen_byte = "E";
            4'd3:  seen_byte = "E";
            4'd4:  seen_byte = "N";
            4'd5:  seen_byte = "=";
            4'd6:  seen_byte = "0";
            4'd7:  seen_byte = "x";
            4'd8:  seen_byte = hex_char(channel_seen_latch[15:12]);
            4'd9:  seen_byte = hex_char(channel_seen_latch[11:8]);
            4'd10: seen_byte = hex_char(channel_seen_latch[7:4]);
            4'd11: seen_byte = hex_char(channel_seen_latch[3:0]);
            default: seen_byte = " ";
            endcase
        end
    endfunction

    function [7:0] current_byte;
        input [4:0] field;
        input [3:0] index;
        begin
            if (field == 5'd0) begin
                current_byte = prefix_byte(index);
            end else if (field <= 5'd16) begin
                current_byte = channel_byte(field[3:0] - 4'd1, index);
            end else if (field == 5'd17) begin
                current_byte = raw_byte(index);
            end else if (field == 5'd18) begin
                current_byte = seen_byte(index);
            end else if (field == 5'd19) begin
                current_byte = 8'h0d;
            end else if (field == 5'd20) begin
                current_byte = 8'h0a;
            end else begin
                current_byte = 8'h20;
            end
        end
    endfunction

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 16; i = i + 1) begin
                samples[i] <= 12'd0;
            end

            sequence <= 8'd0;
            field_index <= 5'd0;
            char_index <= 4'd0;
            sending <= 1'b0;
            last_rx_word_latch <= 16'd0;
            channel_seen_latch <= 16'd0;
            tx_data <= 8'h20;
        end else begin
            if (sample_valid) begin
                samples[sample_channel] <= sample_data;
            end

            if (sweep_done && !sending) begin
                field_index <= 5'd0;
                char_index <= 4'd0;
                sending <= 1'b1;
                last_rx_word_latch <= last_rx_word;
                channel_seen_latch <= channel_seen;
                tx_data <= current_byte(5'd0, 4'd0);
            end else if (sending && tx_accept) begin
                if (field_index == 5'd0) begin
                    if (char_index == 4'd6) begin
                        char_index <= 4'd0;
                        field_index <= 5'd1;
                        tx_data <= current_byte(5'd1, 4'd0);
                    end else begin
                        char_index <= char_index + 1'b1;
                        tx_data <= current_byte(5'd0, char_index + 1'b1);
                    end
                end else if (field_index <= 5'd16) begin
                    if (char_index == 4'd10) begin
                        char_index <= 4'd0;
                        field_index <= field_index + 1'b1;
                        tx_data <= current_byte(field_index + 1'b1, 4'd0);
                    end else begin
                        char_index <= char_index + 1'b1;
                        tx_data <= current_byte(field_index, char_index + 1'b1);
                    end
                end else if (field_index == 5'd17) begin
                    if (char_index == 4'd10) begin
                        char_index <= 4'd0;
                        field_index <= 5'd18;
                        tx_data <= current_byte(5'd18, 4'd0);
                    end else begin
                        char_index <= char_index + 1'b1;
                        tx_data <= current_byte(5'd17, char_index + 1'b1);
                    end
                end else if (field_index == 5'd18) begin
                    if (char_index == 4'd11) begin
                        char_index <= 4'd0;
                        field_index <= 5'd19;
                        tx_data <= current_byte(5'd19, 4'd0);
                    end else begin
                        char_index <= char_index + 1'b1;
                        tx_data <= current_byte(5'd18, char_index + 1'b1);
                    end
                end else if (field_index == 5'd19) begin
                    field_index <= 5'd20;
                    tx_data <= current_byte(5'd20, 4'd0);
                end else begin
                    field_index <= 5'd0;
                    char_index <= 4'd0;
                    sending <= 1'b0;
                    sequence <= sequence + 1'b1;
                    tx_data <= 8'h20;
                end
            end
        end
    end

endmodule
