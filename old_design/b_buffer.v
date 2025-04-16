`timescale 1ns/1ps

`ifndef B_BUFFER
`define B_BUFFER

module b_sram_writer #(
    parameter MATRIX_SIZE = 32,
    parameter ACC_DEPTH = 16
)(
    input wire clk,
    input wire rst_n,
    input reg [7:0] matrix [0:63][0:63],
    input wire start,
    output reg write_en,                         
    output reg [10:0] addr,
    output reg [263:0] data_in
);

    integer row, column, block_row, block_column, vec, i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_en <= 0;
            addr <= 0;
            row <= 0;
            column <= 0;
            block_row <= 0;
            block_column <= 0;
            vec <= 0;
            for (i = 0; i < 16; i = i + 1) begin
                data_in <= 0;
            end
        end
        else begin

            write_en <= 1;

            if (start) begin
                row <= block_row * MATRIX_SIZE;
                column <= block_column * ACC_DEPTH;

                data_in = {
                    matrix[row][column+31], matrix[row][column+30], matrix[row][column+29], matrix[row][column+28],
                    matrix[row][column+27], matrix[row][column+26], matrix[row][column+25], matrix[row][column+24],
                    matrix[row][column+23], matrix[row][column+22], matrix[row][column+21], matrix[row][column+20],
                    matrix[row][column+19], matrix[row][column+18], matrix[row][column+17], matrix[row][column+16],
                    matrix[row][column+15], matrix[row][column+14], matrix[row][column+13], matrix[row][column+12],
                    matrix[row][column+11], matrix[row][column+10], matrix[row][column+9], matrix[row][column+8],
                    matrix[row][column+7], matrix[row][column+6], matrix[row][column+5], matrix[row][column+4],
                    matrix[row][column+3], matrix[row][column+2], matrix[row][column+1], matrix[row][column+0]
                };

                addr <= vec;
                vec <= vec + 1;

                if (vec == 16) begin
                    vec <= 0;
                    block_row <= block_row + 1;
                    if (block_row == 2) begin
                        block_row <= 0;
                        block_column <= block_column + 1;
                        if (block_column == 4) begin
                            block_column <= 0;
                            write_en <= 0; 
                        end
                    end
                end
            end

            else begin
                write_en <= 0;
            end

        end
    end
    
endmodule

module b_sram #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 264
)(
    input wire clk,
    input wire rst_n,
    input wire write_en,
    input wire output_en,
    input wire [10:0] addr,
    input wire [DATA_WIDTH - 1:0] data_in,
    output reg [DATA_WIDTH - 1:0] data_out
);

    reg [DATA_WIDTH - 1:0] mem [0:(1 << ADDR_WIDTH) - 1];
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 1 << ADDR_WIDTH; i = i + 1) begin
                mem[i] <= 0;
            end
            data_out <= 0;
        end
        else if (write_en) begin
            mem[addr] <= data_in;
        end
        if (output_en) begin
            data_out <= mem[addr];
        end
    end
    
endmodule

`endif