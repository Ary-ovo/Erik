module rt_algorithm (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [3:0]  sample_channel,
    input  wire [11:0] sample_data,
    input  wire        sample_valid,
    input  wire        sweep_done,
    input  wire        tx_accept,
    output wire [7:0]  tx_data,
    output wire        tx_valid
);

    reg [11:0] samples [0:15];
    reg [5:0]  byte_index;
    reg [7:0]  checksum;
    reg [7:0]  sequence;
    reg        sending;

    assign tx_valid = sending;
    assign tx_data  = packet_byte(byte_index);

    function [7:0] sample_hi_byte;
        input [3:0] index;
        begin
            sample_hi_byte = {index, samples[index][11:8]};
        end
    endfunction

    function [7:0] sample_lo_byte;
        input [3:0] index;
        begin
            sample_lo_byte = samples[index][7:0];
        end
    endfunction

    function [7:0] packet_byte;
        input [5:0] index;
        begin
            case (index)
            6'd0:  packet_byte = 8'hA5;
            6'd1:  packet_byte = 8'h5A;
            6'd2:  packet_byte = sequence;
            6'd3:  packet_byte = sample_hi_byte(4'd0);
            6'd4:  packet_byte = sample_lo_byte(4'd0);
            6'd5:  packet_byte = sample_hi_byte(4'd1);
            6'd6:  packet_byte = sample_lo_byte(4'd1);
            6'd7:  packet_byte = sample_hi_byte(4'd2);
            6'd8:  packet_byte = sample_lo_byte(4'd2);
            6'd9:  packet_byte = sample_hi_byte(4'd3);
            6'd10: packet_byte = sample_lo_byte(4'd3);
            6'd11: packet_byte = sample_hi_byte(4'd4);
            6'd12: packet_byte = sample_lo_byte(4'd4);
            6'd13: packet_byte = sample_hi_byte(4'd5);
            6'd14: packet_byte = sample_lo_byte(4'd5);
            6'd15: packet_byte = sample_hi_byte(4'd6);
            6'd16: packet_byte = sample_lo_byte(4'd6);
            6'd17: packet_byte = sample_hi_byte(4'd7);
            6'd18: packet_byte = sample_lo_byte(4'd7);
            6'd19: packet_byte = sample_hi_byte(4'd8);
            6'd20: packet_byte = sample_lo_byte(4'd8);
            6'd21: packet_byte = sample_hi_byte(4'd9);
            6'd22: packet_byte = sample_lo_byte(4'd9);
            6'd23: packet_byte = sample_hi_byte(4'd10);
            6'd24: packet_byte = sample_lo_byte(4'd10);
            6'd25: packet_byte = sample_hi_byte(4'd11);
            6'd26: packet_byte = sample_lo_byte(4'd11);
            6'd27: packet_byte = sample_hi_byte(4'd12);
            6'd28: packet_byte = sample_lo_byte(4'd12);
            6'd29: packet_byte = sample_hi_byte(4'd13);
            6'd30: packet_byte = sample_lo_byte(4'd13);
            6'd31: packet_byte = sample_hi_byte(4'd14);
            6'd32: packet_byte = sample_lo_byte(4'd14);
            6'd33: packet_byte = sample_hi_byte(4'd15);
            6'd34: packet_byte = sample_lo_byte(4'd15);
            6'd35: packet_byte = checksum;
            6'd36: packet_byte = 8'h0D;
            6'd37: packet_byte = 8'h0A;
            default: packet_byte = 8'h00;
            endcase
        end
    endfunction

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 16; i = i + 1) begin
                samples[i] <= 12'd0;
            end

            byte_index <= 6'd0;
            checksum   <= 8'd0;
            sequence   <= 8'd0;
            sending    <= 1'b0;
        end else begin
            if (sample_valid) begin
                samples[sample_channel] <= sample_data;
            end

            if (sweep_done && !sending) begin
                byte_index <= 6'd0;
                checksum   <= 8'd0;
                sending    <= 1'b1;
            end else if (sending && tx_accept) begin
                if (byte_index <= 6'd34) begin
                    checksum <= checksum + tx_data;
                end

                if (byte_index == 6'd37) begin
                    byte_index <= 6'd0;
                    sending    <= 1'b0;
                    sequence   <= sequence + 1'b1;
                end else begin
                    byte_index <= byte_index + 1'b1;
                end
            end
        end
    end

endmodule
