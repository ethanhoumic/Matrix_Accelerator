`timescale 1ns/1ps
`ifndef PPU
`define PPU

module ppu (
    input wire clk,
    input wire rst_n,
    input wire [383:0] partial_sum,
    input wire [7:0] scale,
    input wire [7:0] bias,
    input wire valid,
    output wire [17:0] vec_max_wire,
    output wire [17:0] reciprocal_wire,
    output wire [135:0] output_data,
    output wire done_wire
);
    integer i;
    reg read_en;
    wire read_en_wire = read_en;
    reg write_en;
    wire write_en_wire = write_en;
    reg reset_addr;
    wire reset_addr_wire = reset_addr;
    reg [295:0] from_latch_array;
    reg [3:0] counter;
    reg latch_done;
    reg reciprocal_done;

    // scaling
    wire [639:0] scaled_sum;
    genvar j;
    generate
        for (j = 0; j < 16; j = j + 1) begin: SCALING
            wire [23:0] in_scale = partial_sum[(j * 24) +: 24];
            assign scaled_sum[(j * 40) +: 40] = in_scale * scale;
        end
    endgenerate

    // biasing
    wire [639:0] biased_sum;
    generate
        for (j = 0; j < 16; j = j + 1) begin: BIASING
            wire [39:0] in_bias = scaled_sum[(j * 40) +: 40];
            assign biased_sum[(j * 40) +: 40] = in_bias + {32'b0, bias};
        end
    endgenerate

    // relu
    wire [639:0] relu_sum;
    generate
        for (j = 0; j < 16; j = j + 1) begin: RELU
            wire [39:0] in = biased_sum[(j * 40) +: 40];
            assign relu_sum[(j * 40) +: 40] = ($signed(in) < 0) ? 40'b0 : in;
        end
    endgenerate

    // truncation
    wire [295:0] truncated_sum;
    generate
        for (j = 0; j < 16; j = j + 1) begin: TRUNCATION
            assign truncated_sum[(j * 18) +: 18] = relu_sum[(j * 40) + 39 -: 18]; // Truncate to 18 bits
        end
        assign truncated_sum[295:288] = 8'b0; // Padding to 296 bits
    endgenerate

    // vsq buffer
    latch_array latch_array_inst (
        .clk(clk),
        .rst_n(rst_n),
        .reset_addr(reset_addr_wire),
        .write_en(write_en_wire),
        .write_data(truncated_sum),
        .read_en(read_en_wire),
        .read_data(from_latch_array)
    );

    reg [1:0] state;
    localparam IDLE = 2'b00;
    localparam INPUT = 2'b01;
    localparam OUTPUT = 2'b10;
    // reading and writing vsq buffer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'b0000;
            read_en <= 1'b0;
            latch_done <= 1'b0;
            write_en <= 1'b0;
            reset_addr <= 1'b0;
        end
        else begin
            case (state)
                IDLE: begin
                    if (reciprocal_done) begin 
                        state <= OUTPUT;
                        read_en <= 1'b1;
                        latch_done <= 1'b0;
                        counter <= 0;
                        reset_addr <= 1'b1;
                    end 
                    else if (valid) begin
                        state <= INPUT;
                        write_en <= 1'b1;
                    end
                    else begin
                        state <= IDLE;
                        read_en <= 1'b0;
                        latch_done <= 1'b0;
                        counter <= 4'b0000;
                    end
                end
                INPUT: begin
                    if (counter == 4'b1111) begin
                        state <= OUTPUT;
                        read_en <= 1'b1;
                        write_en <= 1'b0;
                        latch_done <= 1'b0;
                        counter <= 0;
                    end
                    else begin
                        counter <= counter + 1;
                    end
                end
                OUTPUT: begin
                    if (counter == 4'b1111) begin
                        state <= IDLE;
                        counter <= 0;
                        latch_done <= 1;
                        read_en <= 0;
                    end
                    else begin
                        counter <= counter + 1;
                        reset_addr <= 1'b0;
                    end
                end
            endcase
        end
    end
    //     else if (valid) begin
    //         if (counter == 5'b11111) begin
    //             read_en <= 1'b0;
    //             latch_done <= 1'b1;
    //         end
    //         else if (counter >= 5'b01111 && counter < 5'b11111) begin
    //             read_en <= 1'b1;
    //             latch_done <= 1'b0;
    //         end
    //         else begin
    //             read_en <= 1'b0;
    //             latch_done <= 1'b0;
    //         end
    //         counter <= (counter == 5'b11111) ? 5'b00000 : counter + 1;
    //     end
    //     else begin
    //         counter <= counter;
    //         read_en <= read_en;
    //         latch_done <= latch_done;
    //     end
    // end

    // vector max
    reg [17:0] vec_max;
    assign vec_max_wire = vec_max;
    always@(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vec_max <= 0;
        end
        else if (read_en) begin
            for (i = 0; i < 16; i = i + 1) begin
                if (from_latch_array[(i * 18) +: 18] > vec_max) begin
                    vec_max <= from_latch_array[(i * 18) +: 18];
                end
            end
        end
        else begin
            vec_max <= vec_max;
        end
    end

    // reciprocal
    reg [39:0] reciprocal;
    assign reciprocal_wire = reciprocal;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reciprocal <= 0;
            reciprocal_done <= 1'b0;
        end
        else if (latch_done) begin
            reciprocal <= (vec_max == 0) ? 18'hffff : (255 << 13)/ vec_max;
            reciprocal_done <= 1'b1;
        end
        else begin
            reciprocal <= reciprocal;
            reciprocal_done <= reciprocal_done;
        end
    end

    // quantize and round
    reg [135:0] quantized_data;
    reg [17:0] temp_val [0:15];
    reg [3:0] buffer;
    reg done;
    assign output_data = quantized_data;
    assign done_wire = done;
    
    // Simplified quantization logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 17; i = i + 1) begin
                quantized_data[i*8 +: 8] <= 8'b0;
            end
            for (i = 0; i < 16; i = i + 1) begin
                temp_val[i] <= 0;
            end
            done <= 1'b0;
            buffer <= 1'b0;
        end
        else if (reciprocal_done && reciprocal != 0) begin
            if (buffer == 3) begin
                for (i = 0; i < 16; i = i + 1) begin
                    if (temp_val[i] > 255) begin
                        quantized_data[i*8 +: 8] <= 8'd255;
                    end
                    else begin
                        quantized_data[i*8 +: 8] <= temp_val[i][7:0];
                    end
                end
                quantized_data[135:128] <= reciprocal[17:9];
                done <= 1'b1;
                buffer <= 0;
            end
            else if (buffer == 2) begin
                for (i = 0; i < 16; i = i + 1) begin
                    temp_val[i] <= ((from_latch_array[i*18 +: 18] * reciprocal) >> 13);
                end
                buffer <= buffer + 1;
            end
            else begin
                buffer <= buffer + 1;
            end
        end
        else begin
            done <= 1'b0;
        end
    end

endmodule

`endif

`ifndef LATCH_ARRAY
`define LATCH_ARRAY

module latch_array (
    input  wire clk,
    input  wire rst_n,
    input  wire reset_addr,
    input  wire write_en,
    input  wire [295:0]  write_data,
    input  wire read_en,
    output wire [295:0]  read_data
);

    integer i;
    reg [295:0] latch_array [47:0];
    reg [5:0] write_addr;
    reg [5:0] read_addr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_addr <= 6'b0;
            write_addr <= 6'b0;
            for (i = 0; i < 48; i = i + 1)
                latch_array[i] <= 296'b0;
        end 
        else if (reset_addr) begin
            read_addr <= 6'b0;
            write_addr <= 6'b0;
        end
        else if (write_en) begin
            latch_array[write_addr] <= write_data;
            write_addr <= (write_addr == 47) ? 0 : write_addr + 1;
        end
        else if (read_en) begin
            read_addr <= (read_addr == 47) ? 0 : read_addr + 1;
        end
        else begin
            read_addr <= read_addr;
            write_addr <= write_addr;
        end
    end

    assign read_data = (read_en) ? latch_array[read_addr] : 296'b0;

endmodule
`endif