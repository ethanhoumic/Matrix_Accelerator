`timescale 1 ns/1 ps
`include "Matrix_Accelerator.v"

module final_tb;

    parameter LANE_NUM = 16;
    parameter LATCH_WIDTH = 384; 
    parameter LATCH_HEIGHT = 16;
    parameter ACCUM_SIZE = 768;
    parameter DATA_WIDTH = 24;
    
    reg clk;
    reg [DATA_WIDTH - 1:0] data_out [0:LANE_NUM - 1];

    reg [7:0] matrix_a[0:63][0:63];
    reg [7:0] matrix_b[0:63][0:63];
    reg [7:0] matrix_ans[0:63][0:63];
    reg [7:0] buffer [0:63][0:63];
    reg [1:0] config_in;
    reg [11:0] error;
    integer file, i, j, cycle_count, row_idx, col_idx, cycle_offset, data;

    always #5 clk = ~clk;

    Matrix_Accelerator uut(
        .clk(clk),
        .config_in(config_in),
        .matrix_a(matrix_a),
        .matrix_b(matrix_b),
        .to_PPU(data_out)
    );

    initial begin
        // Initialize test variables
        clk = 0;
        row_idx = 0;
        col_idx = 0;
        cycle_offset = 0;
        error = 0;
        cycle_count = 0;

        $fsdbDumpfile("simulation.fsdb");
        $fsdbDumpvars(0, final_tb);

        // Display test start message
        $display("------------------------------------------------------------");
        $display("START!!! Matrix Accelerator Simulation Start .....");
        $display("------------------------------------------------------------");

        file = $fopen("matrix_a.txt", "r");
        if (!file) begin
            $display("Cannot open matrix_a.txt.");
            $finish;
        end
        else begin
            $display("Reading matrix_a.txt...");
            for (i = 0; i < 64; i = i + 1) begin
                for (j = 0; j < 64; j = j + 1) begin
                    data = $fscanf(file, "%d", matrix_a[i][j]);
                end
            end
        end
        
        $fclose(file);

        file = $fopen("matrix_b.txt", "r");
        if (!file) begin
            $display("Cannot open matrix_b.txt.");
            $finish;
        end
        else begin 
            $display("Reading matrix_b.txt...");
            for (i = 0; i < 64; i = i + 1) begin
                for (j = 0; j < 64; j = j + 1) begin
                    data = $fscanf(file, "%d", matrix_b[i][j]);
                end
            end
        end
        $fclose(file);

        file = $fopen("ans.txt", "r");
        if (!file) begin
            $display("Cannot open ans.txt.");
            $finish;
        end
        else begin 
            $display("Reading ans.txt...");
            for (i = 0; i < 64; i = i + 1) begin
                for (j = 0; j < 64; j = j + 1) begin
                    data = $fscanf(file, "%d", matrix_ans[i][j]);
                end
            end
        end
        $fclose(file);

        file = $fopen("config.txt", "r");
        if (!file) begin
            $display("Cannot open config.txt.");
            $finish;
        end
        else begin 
            $display("Reading config.txt...");
            data = $fscanf(file, "%d", config_in);
        end
        $fclose(file);

        $display("File reading complete. Starting computation...");
    end

    // Maximum cycle detection
    initial begin
        #50000; // 5000 cycles at 10ns per cycle
        $display("============================================================");
        $display("Simulation time is longer than expected.");
        $display("The test result is .....FAIL :(");
        $display("============================================================");
        $finish;
    end

    always @(posedge clk) begin
        cycle_count = cycle_count + 1;
        
        if (cycle_count % 100 == 0) begin
            $display("Cycle %d: Processing row %d", cycle_count, row_idx);
        end
        
        for (j = 0; j < 16; j = j + 1) begin
            if (col_idx + j * 4 < 64) begin  // Bounds check to avoid array overflow
                buffer[row_idx][col_idx + j * 4] = data_out[j];
            end
        end

        if (cycle_offset == 3) begin
            $display("Checking row %d results...", row_idx);
            for (j = 0; j < 64; j = j + 1) begin
                if (buffer[row_idx][j] !== matrix_ans[row_idx][j]) begin
                    $display("Mismatch at row %d, col %d: Expected %d, Got %d", row_idx, j, matrix_ans[row_idx][j], buffer[row_idx][j]);
                    error = error + 1;
                end
            end

            row_idx = row_idx + 1;
            col_idx = 0;
            cycle_offset = 0;
        end else begin
            col_idx = col_idx + 1;
            cycle_offset = cycle_offset + 1;
        end

        if (row_idx == 64) begin
            $display("============================================================");
            if (error == 0) begin
                $display("Success!");
                $display("The test result is .....PASS :)");
            end
            else begin
                $display("There are total %4d errors in the matrix results", error);
                $display("The test result is .....FAIL :(");
            end
            $display("============================================================");
            $finish;
        end
    end

endmodule

module control_unit #(
    parameter INT8_KVS = 2,
    parameter INT8_NAD = 4,
    parameter INT8_MVL = 4,
    parameter INT4_KVS = 1,
    parameter INT4_NAD = 4,
    parameter INT4_MVL = 4
)(
    input wire clk,
    input [1:0] config_in,
    output reg rst_n,
    output reg int8_sram_start,
    output reg int4_sram_start,
    output reg to_MAC_en,
    output reg from_MAC_en,
    output reg to_PPU_en,
    output reg is_int8_mode,
    output reg is_int4_mode,
    output reg is_vsq
);

    localparam IDLE = 3'b000;
    localparam INT8_SRAM = 3'b001;
    localparam INT8_CALC = 3'b010;
    localparam INT4_SRAM = 3'b011;
    localparam INT4_CALC = 3'b100;
    localparam OUTPUT_TO_PPU_INT8 = 3'b101;
    localparam OUTPUT_TO_PPU_INT4 = 3'b110;

    reg [2:0] state;
    reg [5:0] counter;
    reg [1:0] big_counter; 

    always @(posedge clk) begin
        case (state)
            IDLE: begin
                if (config_in == 0) begin
                    state <= IDLE;
                    counter <= 0;
                    big_counter <= 0;
                    rst_n <= 0;
                    int8_sram_start <= 0;
                    int4_sram_start <= 0;
                    to_MAC_en <= 0;
                    from_MAC_en <= 0;
                    to_PPU_en <= 0;
                    is_int8_mode <= 0;
                    is_int4_mode <= 0;
                    is_vsq <= 0;
                end
                else if (config_in == 2'b01) begin     // int8 mode
                    state <= INT8_SRAM;
                    counter <= 0;
                    big_counter <= 0;
                    rst_n <= 1;
                    int8_sram_start <= 1;
                    int4_sram_start <= 0;
                    to_MAC_en <= 0;
                    from_MAC_en <= 0;
                    to_PPU_en <= 0;
                    is_int8_mode <= 1;
                    is_int4_mode <= 0;
                    is_vsq <= 0;
                end
                else if (config_in == 2'b10) begin     // int4 mode
                    state <= INT4_SRAM;
                    counter <= 0;
                    big_counter <= 0;
                    rst_n <= 1;
                    int8_sram_start <= 0;
                    int4_sram_start <= 1;
                    to_MAC_en <= 0;
                    from_MAC_en <= 0;
                    to_PPU_en <= 0;
                    is_int8_mode <= 0;
                    is_int4_mode <= 1;
                    is_vsq <= 0;
                end
                else if (config_in == 2'b11) begin     // int4-vsq mode
                    state <= INT4_SRAM;
                    counter <= 0;
                    big_counter <= 0;
                    rst_n <= 1;
                    int8_sram_start <= 0;
                    int4_sram_start <= 1;
                    to_MAC_en <= 0;
                    from_MAC_en <= 0;
                    to_PPU_en <= 0;
                    is_int8_mode <= 0;
                    is_int4_mode <= 1;
                    is_vsq <= 1;
                end
            end
            INT8_SRAM: begin
                if (counter == 127) begin
                    state <= INT8_CALC;
                    to_MAC_en <= 1;
                    from_MAC_en <= 1;
                    int8_sram_start <= 0;
                    counter <= 0;
                end
                else counter <= counter + 1;
            end
            INT8_CALC: begin
                if (big_counter == 3 && counter == 31) begin
                    state <= IDLE;
                    to_MAC_en <= 0;
                    from_MAC_en <= 0;
                    counter <= 0;
                    to_PPU_en <= 0;
                end
                else if (counter == 31) begin
                    state <= OUTPUT_TO_PPU_INT8;
                    big_counter <= big_counter + 1;
                    counter <= 0;
                end
                else counter <= counter + 1;
            end
            INT4_SRAM: begin
                if (counter == 63) begin
                    state <= INT4_CALC;
                    to_MAC_en <= 1;
                    from_MAC_en <= 1;
                    int4_sram_start <= 0;
                    counter <= 0;
                end
                else counter <= counter + 1;
            end
            INT4_CALC: begin
                if (counter == 63) begin
                    state <= OUTPUT_TO_PPU_INT4;
                    to_MAC_en <= 0;
                    from_MAC_en <= 0;
                    counter <= 0;
                    to_PPU_en <= 1;
                end
                else counter <= counter + 1;
            end
            OUTPUT_TO_PPU_INT8: begin
                if (counter == 15) begin
                    state <= INT8_CALC;
                    counter <= 0;
                    to_PPU_en <= 0;
                end
                else counter <= counter + 1;
            end
            OUTPUT_TO_PPU_INT4: begin
                if (counter == 15) begin
                    state <= INT4_CALC;
                    counter <= 0;
                    to_PPU_en <= 0;
                end
                else counter <= counter + 1;
            end
            default: begin
                state <= IDLE;
                counter <= 0;
            end
        endcase
    end
    
endmodule

module a_sram_writer #(
    parameter MATRIX_SIZE = 32,
    parameter LANE_NUM = 16
)(
    input wire clk,
    input wire rst_n,
    input wire [7:0] matrix[0:63][0:63],
    input wire start,
    output reg write_en,                
    output reg [6:0] addr,
    output reg [263:0] data_in [0:15] 
);

    integer row, column, block_row, block_column, i, j;

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            write_en <= 0;
            addr <= 0;
            row <= 0;
            column <= 0;
            block_row <= 0;
            block_column <= 0;
            for (i = 0; i < 16; i = i + 1) begin
                data_in[i] <= 0;
            end
        end

        else begin

            write_en <= 1;

            if (start) begin
                row <= block_row * LANE_NUM;
                column <= block_column * MATRIX_SIZE;

                for (i = 0; i < 16; i = i + 1) begin
                    for (j = 0; j < 32; j = j + 1) begin
                        data_in[i][8*(j+1)-1 -: 8] <= matrix[row + (31-j)][column + i];
                    end
                end

                addr <= addr + 1;
                block_column <= block_column + 1;

                if (block_column == 2) begin
                    block_column <= 0;
                    block_row <= block_row + 1;
                    if (block_row == 4) begin
                        block_row <= 0;
                        write_en <= 0; 
                    end
                end
            end

            else begin
                write_en <= 0;
            end

        end
    end
    
endmodule

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

module a_sram_16bank (
    input wire clk,
    input wire rst_n,
    input wire write_en,
    input wire [6:0] addr,   // 0-127, height
    input wire [263:0] data_in [0:15],
    input wire output_en,
    output wire [263:0] data_out [0:15]
);
    reg [263:0] sram [0:15][0:127];
    reg [1:0] state;
    reg [6:0] write_index;
    integer i;
    integer j;

    genvar k;
    generate
        for (k = 0; k < 16; k = k + 1) begin: read_logic
            assign data_out[k] = sram[k][addr] & output_en;
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_index <= 0;
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

        else begin
            
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

module accumulation_collector #(
    parameter LANE_NUM = 16,
    parameter LATCH_WIDTH = 384, 
    parameter LATCH_HEIGHT = 16,
    parameter DATA_WIDTH = 24
)(
    input wire clk,
    input wire rst_n,
    input wire to_MAC_en,
    input wire from_MAC_en,
    input wire to_PPU_en,
    input wire [DATA_WIDTH - 1:0] from_MAC [0:LANE_NUM - 1], 
    output reg [DATA_WIDTH - 1:0] to_MAC [0:LANE_NUM - 1], 
    output reg [DATA_WIDTH - 1:0] to_PPU [0:LANE_NUM - 1],
    output reg ACC_done
);

    reg [LATCH_WIDTH - 1:0] latch_array [LATCH_HEIGHT - 1:0];
    integer i;
    reg [3:0] read_height;
    reg [3:0] MAC_write_height;
    reg [3:0] to_PPU_height;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

            read_height <= 0;
            MAC_write_height <= 0;
            to_PPU_height <= 0;

            for (i = 0; i < LATCH_HEIGHT; i = i + 1) begin
                latch_array[i] <= 0;
            end
        end
        else if (to_MAC_en) begin
            for (i = 0; i < LANE_NUM; i = i + 1) begin
                to_MAC[i] <= latch_array[read_height][(i * 24) +: 24];
            end
            read_height <= (read_height + 1) % LATCH_HEIGHT;
        end
        else if (from_MAC_en) begin
            for (i = 0; i < LANE_NUM; i = i + 1) begin
                latch_array[read_height][i * 24 +: 24] <= from_MAC[i];
            end
            MAC_write_height <= (read_height + 1) % LATCH_HEIGHT;
        end
        else if (to_PPU_en) begin
            for (i = 0; i < LANE_NUM; i = i + 1) begin
                to_PPU[i] <= latch_array[to_PPU_height][i * 24 +: 24];
            end
            to_PPU_height <= (to_PPU_height + 1) % LATCH_HEIGHT;
        end
    end

endmodule