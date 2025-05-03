`timescale 1 ns/1 ps

`ifndef A_BUFFER
`define A_BUFFER

module a_sram_writer #(
    parameter MATRIX_SIZE = 32,
    parameter LANE_NUM = 16
)(
    input wire clk,
    input wire rst_n,
    input wire [7:0] matrix[0:63][0:63],
    input wire start,
    output reg write_en,                
    output reg [263:0] data_in [0:15] 
);
    reg state;
    localparam IDLE = 0, RUN = 1;
    integer i, j;
    reg [2:0] sram_addr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_en <= 0;
            state <= IDLE;
            sram_addr <= 0;
            for (i = 0; i < 16; i = i + 1) begin
                data_in[i] <= 0;
            end
        end
        else begin
            case (state)
                IDLE: begin
                    write_en <= 0;
                    sram_addr <= 0;
                    for (i = 0; i < 16; i = i + 1) begin
                        data_in[i] <= 0;
                    end
                    if (start) state <= RUN;
                    else state <= IDLE;
                end 
                RUN: begin
                    write_en <= 1;
                    
                    // Load data from matrix to data_in
                    for (i = 0; i < 16; i = i + 1) begin
                        for (j = 0; j < 32; j = j + 1) begin
                            // Fixed the bit selection to ensure proper data loading
                            data_in[i][j*8 +: 8] <= matrix[(sram_addr / 2) * 16 + i][(sram_addr % 2) * 32 + j];
                        end
                    end
                    
                    // Increment address
                    sram_addr <= sram_addr + 1;
                    
                    // End condition
                    if (sram_addr == 7) begin
                        state <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule

module a_sram_16bank (
    input wire clk,
    input wire rst_n,
    input wire write_en,
    input wire [263:0] data_in [0:15],
    input wire output_en,
    output wire [263:0] data_out [0:15]
);
    reg [263:0] sram [0:15][0:127];
    reg [6:0] write_index;
    reg [6:0] output_index;
    integer i;
    integer j;

    genvar k;
    generate
        for (k = 0; k < 16; k = k + 1) begin: read_logic
            assign data_out[k] = output_en ? sram[k][output_index] : 264'b0; // Fixed: use conditional operator
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_index <= 0;
            output_index <= 0;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 128; j = j + 1) begin
                    sram[i][j] <= 0;
                end
            end
        end
        else if (write_en) begin
            for (i = 0; i < 16; i = i + 1) begin
                sram[i][write_index] <= data_in[i]; 
            end
            write_index <= (write_index + 1) % 128;
        end
        else if (output_en) begin
            output_index <= (output_index + 1) % 128;
        end
    end
endmodule

`endif