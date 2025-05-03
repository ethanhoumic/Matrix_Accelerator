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
    output wire [295:0] from_latch_array,
    output reg read_en
    // output reg [135:0] output_data,
    // output reg done
);

    reg latch_done;
    wire read_en_wire = read_en;
    reg [4:0] counter;

    // scaling
    wire [639:0] scaled_sum;
    genvar j;
    generate
        for (j = 0; j < 16; j = j + 1) begin: SCALING
            wire [23:0] in = partial_sum[(j * 24) +: 24];
            assign scaled_sum[(j * 40) +: 40] = in * scale;
        end
    endgenerate

    // biasing
    wire [639:0] biased_sum;
    generate
        for (j = 0; j < 16; j = j + 1) begin: BIASING
            assign biased_sum[(j * 40) +: 40] = scaled_sum[(j * 40) +: 40] + {32'b0, bias};
        end
    endgenerate

    // relu
    wire [639:0] relu_sum;
    generate
        for (j = 0; j < 16; j = j + 1) begin: RELU
            wire [39:0] in = biased_sum[(j * 40) +: 40];
            assign relu_sum[(j * 40) +: 40] = (in[39]) ? 40'b0 : in;
        end
    endgenerate

    // truncation
    wire [295:0] truncated_sum;
    generate
        for (j = 0; j < 16; j = j + 1) begin: TRUNCATION
            assign truncated_sum[(j * 18) +: 18] = {relu_sum[(j * 40) +: 40]}[39:22]; // Truncate to 18 bits
        end
        assign truncated_sum[295:288] = 8'b0; // Padding to 296 bits
    endgenerate

    // vsq buffer
    latch_array latch_array_inst (
        .clk(clk),
        .rst_n(rst_n),
        .write_en(valid),
        .write_data(truncated_sum),
        .read_en(read_en_wire),
        .read_data(from_latch_array)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 4'b0000;
            read_en <= 1'b0;
            latch_done <= 1'b0;
        end
        else if (valid) begin
            if (counter == 5'b11111) begin
                read_en <= 1'b0;
                latch_done <= 1'b1;
            end
            else if (counter == 5'b01111) begin
                read_en <= 1'b1;
                latch_done <= 1'b0;
            end
            else begin
                read_en <= 1'b0;
                latch_done <= 1'b0;
            end
            counter <= (counter == 5'b11111) ? 5'b00000 : counter + 1;
        end
        else begin
            counter <= counter;
            read_en <= read_en;
            latch_done <= latch_done;
        end
    end

    // vector Max
    // reg [17:0] vec_max;
    // always@(posedge clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //         vec_max <= 0;
    //     end
    //     else if (latch_done) begin
            
    //     end
    //     for (j = 0; j < 16; j = j + 1) begin
    //         if (truncated_sum[(j * 18) +: 18] > vec_max) begin
    //             vec_max = truncated_sum[(j * 18) +: 18];
    //         end
    //     end
    // end


endmodule

`endif

`ifndef LATCH_ARRAY
`define LATCH_ARRAY

module latch_array (
    input  wire clk,
    input  wire rst_n,
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
        end else if (write_en) begin
            latch_array[write_addr] <= write_data;
        end
    end

    assign read_data = (read_en) ? latch_array[read_addr] : 296'b0;

endmodule
`endif