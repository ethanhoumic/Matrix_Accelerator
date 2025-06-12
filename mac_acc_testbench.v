`timescale 1ns/1ps
`include "matrix_accelerator.v"

// Define file paths for patterns and scales

`define PATTERN_A_INT8 "./data_files/A_int8.txt"
`define PATTERN_A_INT4 "./data_files/A_int4.txt"
`define PATTERN_A_VSQ "./data_files/A_int4_vsq.txt"

`define A_SCALE_INT8 "./data_files/A_int8_fp8.txt"
`define A_SCALE_INT4 "./data_files/A_int4_fp8.txt"
`define A_SCALE_VSQ "./data_files/A_vsq_fp8.txt"

`define PATTERN_B_INT8 "./data_files/B_int8.txt"
`define PATTERN_B_INT4 "./data_files/B_int4.txt"
`define PATTERN_B_VSQ "./data_files/B_int4_vsq.txt"

`define B_SCALE_INT8 "./data_files/B_int8_fp8.txt"
`define B_SCALE_INT4 "./data_files/B_int4_fp8.txt"
`define B_SCALE_VSQ "./data_files/B_vsq_fp8.txt"

`define PATTERN_C "./data_files/C_correct.txt"
`define PATTERN_C_SOFTMAX "./data_files/C_softmax.txt"
`define CMD "./data_files/cmd.txt"

`define HEIGHT 32
`define VL 16
`define AD 16
`define ACC_COUNT 4

module A_tile (
    input wire clk,
    input wire rst_n,
    input wire [1:0] mode,
    input wire [8*4225 - 1:0] a_input,
    output wire [4223:0] a_vec_wire,
    output wire done_wire
);
    wire [519:0] a_data [0:64];

    genvar k;
    generate
    for (k = 0; k < 65; k = k + 1) begin
        assign a_data[k] = a_input[k * 520 +: 520]; // high 8 bits are scale, verilog reads datas from left to right
    end
    endgenerate


    integer i, j;
    reg done;
    reg column;
    reg buffer;
    reg [1:0] row;
    reg [4223:0] a_vec;
    

    assign a_vec_wire = a_vec;
    assign done_wire = done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            row <= 0;
            column <= 0;
            buffer <= 0;
        end
        else begin
            case (mode)
                2'b00: begin //int8
                    for (i = 0; i < 16; i = i + 1) begin
                        a_vec[i * 264 +: 264] <= {a_data[row * 16 + i][column * 256 +: 256], 8'b1};
                    end
                    if (row == 3) begin
                        if (column == 1) begin
                            if (buffer) begin
                                a_vec <= 0;
                                done <= 1;
                                row <= 0;
                                column <= 0;
                            end
                            else begin
                                buffer <= 1;
                            end
                        end
                        else begin
                            column <= 1;
                        end
                    end
                    else begin
                        if (column == 1) begin
                            column <= 0;
                            row <= row + 1;
                        end
                        else begin
                            column <= 1;
                        end
                    end
                end
                2'b01: begin //int4
                    for (i = 0; i < 16; i = i + 1) begin
                        logic [263:0] vec;
                        for (j = 0; j < 64; j = j + 1) begin
                            vec[j * 4 +: 4] = a_data[row * 16 + i][j * 8 +: 4];  // 取每個 byte 的低 4 bits
                        end
                        a_vec[i * 264 +: 264] <= {vec, 8'b1};
                    end
                    if (row == 3) begin
                        if (buffer) begin
                            a_vec <= 0;
                            done <= 1;
                            row <= 0;
                            column <= 0;
                        end
                        else begin
                            buffer <= 1;
                        end
                    end
                    else begin
                        row <= row + 1;
                    end
                end
                2'b10: begin //vsq
                    for (i = 0; i < 16; i = i + 1) begin
                        logic [263:0] vec;
                        for (j = 0; j < 64; j = j + 1) begin
                            vec[j * 4 +: 4] = a_data[row * 16 + i][j * 8 +: 4];
                        end
                        a_vec[i * 264 +: 264] <= {vec, a_data[row * 16 + i][519:512]};
                    end
                    if (row == 3) begin
                        if (buffer) begin
                            a_vec <= 0;
                            done <= 1;
                            row <= 0;
                            column <= 0;
                        end
                        else begin
                            buffer <= 1;
                        end
                    end
                    else begin
                        row <= row + 1;
                    end
                end
            endcase
        end
    end
    
endmodule

module B_tile (
    input wire clk,
    input wire rst_n,
    input wire [1:0] mode,
    input wire [8*4225 - 1:0] b_input,
    output wire [263:0] b_vec_wire,
    output wire done_wire
);
    wire [519:0] b_data [0:65];

    genvar j;
    generate
    for (j = 0; j < 65; j = j + 1) begin
        assign b_data[j] = b_input[j * 520 +: 520]; // row 65 are scales
    end
    endgenerate


    integer i;
    reg done;
    reg [2:0] column;
    reg [3:0] small_column;
    reg row;
    reg buffer;
    reg [263:0] b_vec;
    assign b_vec_wire = b_vec;
    assign done_wire = done;

    wire [255:0] b_vec_int8;
    wire [255:0] b_vec_int4;
    wire [263:0] b_vec_vsq;

    generate
        for (j = 0; j < 32; j = j + 1) begin : pack_b_vec
            assign b_vec_int8[j * 8 +: 8] = b_data[row * 32 + j][column * 128 + small_column * 8 +: 8];
        end
        for (j = 0; j < 64; j = j + 1) begin : pack_b_vec_int4
            assign b_vec_int4[j * 4 +: 4] = b_data[j][column * 128 + small_column * 8 +: 4];
        end
        assign b_vec_vsq[7:0] = b_data[64][column * 128 + small_column * 8 +: 8];
        for (j = 2; j < 66; j = j + 1) begin : pack_b_vec_vsq
            assign b_vec_vsq[j * 4 +: 4] = b_data[j - 2][column * 128 + small_column * 8 +: 4];
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            row <= 0;
            column <= 0;
            small_column <= 0;
            b_vec <= 0;
        end
        else begin
            case (mode)
                2'b00: begin //int8
                    b_vec <= {b_vec_int8, 8'b1};
                    if (column == 3) begin
                        if (small_column == 15) begin
                            if (row == 1) begin
                                if (buffer) begin
                                    b_vec <= 0;
                                    done <= 1;
                                    column <= 0;
                                    small_column <= 0;
                                    row <= 0;
                                end
                                else begin
                                    buffer <= 1;
                                end
                            end
                            else begin
                                row <= 1;
                                small_column <= 0;
                            end
                        end
                        else begin
                            small_column <= small_column + 1;
                        end
                    end
                    else begin
                        if (small_column == 15) begin
                            if (row == 1) begin
                                row <= 0;
                                column <= column + 1;
                                small_column <= 0;
                            end
                            else begin
                                row <= 1;
                                small_column <= 0;
                            end
                        end
                        else begin
                            small_column <= small_column + 1;
                        end
                    end
                end
                2'b01: begin //int4
                    b_vec <= {b_vec_int4, 8'b1};
                    if (column == 7) begin
                        if (small_column == 15) begin
                            if (buffer) begin
                                b_vec <= 0;
                                done <= 1;
                                column <= 0;
                                small_column <= 0;
                                row <= 0;
                            end
                            else begin
                                buffer <= 1;
                            end
                        end
                        else begin
                            small_column <= small_column + 1;
                        end
                    end
                    else begin
                        if (small_column == 15) begin
                            small_column <= 0;
                            column <= column + 1;
                        end
                        else begin
                            small_column <= small_column + 1;
                        end
                    end
                end
                2'b10: begin //vsq
                    b_vec <= b_vec_vsq;
                    if (column == 7) begin
                        if (small_column == 15) begin
                            if (buffer) begin
                                b_vec <= 0;
                                done <= 1;
                                column <= 0;
                                small_column <= 0;
                                row <= 0;
                            end
                            else begin
                                buffer <= 1;
                            end
                        end
                        else begin
                            small_column <= small_column + 1;
                        end
                    end
                    else begin
                        if (small_column == 15) begin
                            small_column <= 0;
                            column <= column + 1;
                        end
                        else begin
                            small_column <= small_column + 1;
                        end
                    end
                end
            endcase
        end
    end
    
endmodule

module tb ;
    
    // ---------------------Control signals------------------------------------

    reg clk;
    reg rst_n;
    reg start;
    reg buff;
    reg buff_2;
    reg [1:0] mode;          // 00: int8, 01: int4, 10: vsq
    reg [8:0] cycle_count;
    reg [7:0] addr_count;
    reg output_en;

    // --------------------Memory for A and B vectors------------------------------

    reg [7:0] a_mem [0:4224];  // 65 * 65
    reg [7:0] b_mem [0:4224];  // 65 * 65

    wire [8*4225 - 1:0] a_mem_wire;  // mem to tiling
    wire [8*4225 - 1:0] b_mem_wire;  // mem to tiling

    wire [4223:0] a_vec_wire;    // tiling to buff
    wire [263:0]  b_vec_wire;    // tiling to buff

    // --------------------Buffers for A and B vectors------------------------------

    reg [263:0] a_buffer_0  [0:127];
    reg [263:0] a_buffer_1  [0:127];
    reg [263:0] a_buffer_2  [0:127];
    reg [263:0] a_buffer_3  [0:127];
    reg [263:0] a_buffer_4  [0:127];
    reg [263:0] a_buffer_5  [0:127];
    reg [263:0] a_buffer_6  [0:127];
    reg [263:0] a_buffer_7  [0:127];
    reg [263:0] a_buffer_8  [0:127];
    reg [263:0] a_buffer_9  [0:127];
    reg [263:0] a_buffer_10 [0:127];
    reg [263:0] a_buffer_11 [0:127];
    reg [263:0] a_buffer_12 [0:127];
    reg [263:0] a_buffer_13 [0:127];
    reg [263:0] a_buffer_14 [0:127];
    reg [263:0] a_buffer_15 [0:127];
    reg [3:0]   a_addr;
    reg [3:0]   w_a_addr;
    reg [1:0]   a_addr_counter;
    

    reg [263:0] b_buffer [0:2047];
    reg [6:0]   b_addr;
    reg [6:0]   w_b_addr;

    wire [4223:0] a_from_buff;   // buff to mac
    wire [263:0]  b_from_buff;   // buff to mac

    // --------------------Buffers for output------------------------------

    reg [383:0] output_buffer [0:255];
    reg [10:0]   output_addr;

    // --------------------Data wires--------------------------------------
    wire mac_start;
    wire done_a;
    wire stall;
    wire done_b;
    wire mac_done_wire;
    wire calc_done_wire;
    wire acc_done_wire;
    wire [383:0] partial_sum_out;
    wire [383:0] partial_sum_in;
    wire [383:0] to_ppu_wire;

    // --------------------Integers-------------------------------------------

    integer i, j, cmd_file;

    // --------------------Assignments-------------------------------------------

    assign a_from_buff = (done_a && done_b) ? {a_buffer_0[w_a_addr], a_buffer_1[w_a_addr], a_buffer_2[w_a_addr], a_buffer_3[w_a_addr],
                          a_buffer_4[w_a_addr], a_buffer_5[w_a_addr], a_buffer_6[w_a_addr], a_buffer_7[w_a_addr],
                          a_buffer_8[w_a_addr], a_buffer_9[w_a_addr], a_buffer_10[w_a_addr], a_buffer_11[w_a_addr],
                          a_buffer_12[w_a_addr], a_buffer_13[w_a_addr], a_buffer_14[w_a_addr], a_buffer_15[w_a_addr]}: 0;
    
    assign b_from_buff = (done_a && done_b) ? b_buffer[w_b_addr] : 0;
    assign mac_start = (done_a && done_b) ? 1 : 0;

    genvar k;
    generate
    for (k = 0; k < 4225; k = k + 1) begin : flatten_mem
        assign a_mem_wire[k * 8 +: 8] = a_mem[k];
        assign b_mem_wire[k * 8 +: 8] = b_mem[k];
    end
    endgenerate

    // --------------------Module Instantiations--------------------------------

    A_tile a_tile (
        .clk(clk),
        .rst_n(rst_n),
        .mode(mode),
        .a_input(a_mem_wire),
        .a_vec_wire(a_vec_wire),
        .done_wire(done_a)
    );

    B_tile b_tile (
        .clk(clk),
        .rst_n(rst_n),
        .mode(mode),
        .b_input(b_mem_wire),
        .b_vec_wire(b_vec_wire),
        .done_wire(done_b)
    );

    mac_16 mac16_inst (
        .clk(clk),
        .rst_n(rst_n),
        .a_vec(a_from_buff),
        .b_vec(b_from_buff),
        .is_int8_mode(mode == 2'b00),
        .is_int4_mode(mode == 2'b01),
        .is_vsq(mode == 2'b10),
        .valid(mac_start),
        .partial_sum_in(partial_sum_in),
        .stall(stall),
        .partial_sum_out(partial_sum_out),
        .mac_done_wire(mac_done_wire),
        .calc_done_wire(calc_done_wire)
    );

    acc_collector acc_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(mac_start),
        .ppu(calc_done_wire),
        .mac_done(mac_done_wire),
        .partial_sum_in(partial_sum_out),
        .to_mac(partial_sum_in),
        .to_ppu(to_ppu_wire),
        .done_wire(acc_done_wire)
    );

    always #5 clk = ~clk; // 10 ns clock period

    // --------------------Testbench Initialization--------------------------------

    initial begin
        
        $fsdbDumpfile("simulation.fsdb");
        $fsdbDumpvars(0, tb);

        clk = 0;
        rst_n = 0;

        a_addr = 0;
        b_addr = 0;
        w_a_addr = 0;
        w_b_addr = 0;
        buff = 0;
        buff_2 = 0;
        mode = 0;
        start = 0;
        output_addr = 0;
        addr_count = 0;
        output_en = 0;
        a_addr_counter = 0;

        //-------------------- Initialize memory and buffers ----------------------------

        for (i = 0; i < 4225; i = i + 1) begin
            a_mem[i] = 0;
            b_mem[i] = 0;
        end
        for (i = 0; i < 128; i = i + 1) begin
            a_buffer_0[i] = 0;
            a_buffer_1[i] = 0;
            a_buffer_2[i] = 0;
            a_buffer_3[i] = 0;
            a_buffer_4[i] = 0;
            a_buffer_5[i] = 0;
            a_buffer_6[i] = 0;
            a_buffer_7[i] = 0;
            a_buffer_8[i] = 0;
            a_buffer_9[i] = 0;
            a_buffer_10[i] = 0;
            a_buffer_11[i] = 0;
            a_buffer_12[i] = 0;
            a_buffer_13[i] = 0;
            a_buffer_14[i] = 0;
            a_buffer_15[i] = 0;
        end

        for (i = 0; i < 2048; i = i + 1) begin
            b_buffer[i] = 0;
        end

        for (i = 0; i < 128; i = i + 1) begin
            output_buffer[i] = 0;
        end

        // ----------------------Load command file and datas-----------------------------

        #10;

        start = 1;
        rst_n = 1;
        // Load data from files

        cmd_file = $fopen(`CMD, "r");
        if (cmd_file) begin
            $fscanf(cmd_file, "%b", mode);
            $display("Mode set to: %b", mode);
            $fclose(cmd_file);
        end
        else begin
            $display("Error opening command file.");
            $finish;
        end

        case (mode) 
            2'b00: begin
                $readmemb(`PATTERN_A_INT8, a_mem);
                $readmemb(`PATTERN_B_INT8, b_mem);
            end
            2'b01: begin
                $readmemb(`PATTERN_A_INT4, a_mem);
                $readmemb(`PATTERN_B_INT4, b_mem);
            end
            2'b10: begin
                $readmemb(`PATTERN_A_VSQ, a_mem);
                $readmemb(`PATTERN_B_VSQ, b_mem);
            end
        endcase

        #5000;

        // $finish;


    end

    always @(posedge clk or negedge rst_n) begin

        if (stall) output_en <= 1;
        else output_en <= 0;
        if (!rst_n) begin
            for (i = 0; i < 4225; i = i + 1) begin
                a_mem[i] = 0;
                b_mem[i] = 0;
            end
            a_addr <= 0;
            b_addr <= 0;
            cycle_count <= 0;
        end

        else if (output_en) begin
            output_buffer[output_addr] <= to_ppu_wire;
            if (mode == 0) begin
                if (output_addr == 256) begin
                    $display("Output buffer filled.");
                    for (i = 0; i < 256; i = i + 1) begin
                        $display("Output %d: %h", i, output_buffer[i]);
                    end
                    $finish;
                end
            end
            else begin
                if (output_addr == 128) begin
                    $display("Output buffer filled.");
                    for (i = 0; i < 128; i = i + 1) begin
                        $display("Output %d: %h", i, output_buffer[i]);
                    end
                    $finish;
                end
            end
            output_addr <= output_addr + 1;
            w_a_addr <= w_a_addr;
            w_b_addr <= w_b_addr; // stop sending data into mac
        end
        else if (done_a && done_b) begin
            a_addr <= 200;
            b_addr <= 200;   // move away the address to avoid overwriting
            start = 0;

            //--------------------- Debugging for input tiling part-----------------------------------

            // for (i = 0; i < 10; i = i + 1) begin
            //     $display("a_buffer_0[%d] = %h", i, a_buffer_0[i]);
            //     $display("a_buffer_1[%d] = %h", i, a_buffer_1[i]);
            //     $display("a_buffer_2[%d] = %h", i, a_buffer_2[i]);
            //     $display("a_buffer_3[%d] = %h", i, a_buffer_3[i]);
            //     $display("a_buffer_4[%d] = %h", i, a_buffer_4[i]);
            //     $display("a_buffer_5[%d] = %h", i, a_buffer_5[i]);
            //     $display("a_buffer_6[%d] = %h", i, a_buffer_6[i]);
            //     $display("a_buffer_7[%d] = %h", i, a_buffer_7[i]);
            //     $display("a_buffer_8[%d] = %h", i, a_buffer_8[i]);
            //     $display("a_buffer_9[%d] = %h", i, a_buffer_9[i]);
            //     $display("a_buffer_10[%d] = %h", i, a_buffer_10[i]);
            //     $display("a_buffer_11[%d] = %h", i, a_buffer_11[i]);
            //     $display("a_buffer_12[%d] = %h", i, a_buffer_12[i]);
            //     $display("a_buffer_13[%d] = %h", i, a_buffer_13[i]);
            //     $display("a_buffer_14[%d] = %h", i, a_buffer_14[i]);
            //     $display("a_buffer_15[%d] = %h", i, a_buffer_15[i]);
            // end

            // for (i = 0; i < 70; i = i + 1) begin
            //     $display("b_buffer[%d] = %h", i, b_buffer[i]);
            // end
            // $finish;

            //--------------------- Debugging for input tiling part-----------------------------------

            if (stall) begin
                addr_count <= 0;
                w_a_addr <= w_a_addr;
                w_b_addr <= w_b_addr;
                $display("--------------------------------------------------------------------------------------");
                $display("---------------------Stall condition met, waiting for next cycle----------------------");
                $display("--------------------------------------------------------------------------------------");

            end

            else begin
                addr_count <= addr_count + 1;
                if ((addr_count + 1) % 16 == 0) begin
                    if ((addr_count + 1) % 32 == 0 && a_addr_counter == 3) begin
                        w_a_addr <= w_a_addr + 1;
                        a_addr_counter <= 0;
                    end 
                    else if ((addr_count + 1) % 32 == 0 && a_addr_counter != 3) begin
                        w_a_addr = w_a_addr - 1;
                        a_addr_counter <= a_addr_counter + 1;
                    end
                    else begin
                        w_a_addr <= w_a_addr + 1;
                    end
                end
                else begin
                    w_a_addr <= w_a_addr;
                end 
                w_b_addr <= (w_b_addr + 1) % 64;
                // $display("Processing next data: a_addr = %d, b_addr = %d", w_a_addr, w_b_addr);
                // $display("a_vec_wire = %h", a_from_buff);
                // $display("b_vec_wire = %h", b_from_buff);
            end

        end

        else if (start && buff == 1) begin
            cycle_count <= cycle_count + 1;
            if (done_a) begin
                a_addr <= 0;
            end
            else begin
                a_buffer_0[a_addr] <= a_vec_wire[263:0];
                a_buffer_1[a_addr] <= a_vec_wire[527:264];
                a_buffer_2[a_addr] <= a_vec_wire[791:528];
                a_buffer_3[a_addr] <= a_vec_wire[1055:792];
                a_buffer_4[a_addr] <= a_vec_wire[1319:1056];
                a_buffer_5[a_addr] <= a_vec_wire[1583:1320];
                a_buffer_6[a_addr] <= a_vec_wire[1847:1584];
                a_buffer_7[a_addr] <= a_vec_wire[2111:1848];
                a_buffer_8[a_addr] <= a_vec_wire[2375:2112];
                a_buffer_9[a_addr] <= a_vec_wire[2639:2376];
                a_buffer_10[a_addr] <= a_vec_wire[2903:2640];
                a_buffer_11[a_addr] <= a_vec_wire[3167:2904];
                a_buffer_12[a_addr] <= a_vec_wire[3431:3168];
                a_buffer_13[a_addr] <= a_vec_wire[3695:3432];
                a_buffer_14[a_addr] <= a_vec_wire[3959:3696];
                a_buffer_15[a_addr] <= a_vec_wire[4223:3960];
                a_addr <= a_addr + 1;
            end

            if (done_b) begin
                b_addr <= 0;
            end
            
            else begin
                b_buffer[b_addr] <= b_vec_wire;
                b_addr <= b_addr + 1;
            end

        end

        else if (start) begin
            buff <= 1;
        end
    end

endmodule

// module tb;

//     integer i;

//     reg clk;
//     reg rst_n;
//     reg [4223:0] a_vec;
//     reg [263:0] b_vec;
//     reg is_int8_mode;
//     reg is_int4_mode;
//     reg is_vsq;
//     reg [4:0] addr;
//     reg [4:0] cycle_cnt;
//     reg valid_mac;

//     reg [7:0] scale;
//     reg [7:0] bias;
//     reg done;
//     reg valid_ppu;
//     wire [639:0] scaled_sum_wire;
//     wire [127:0] output_data;
//     wire [15:0] reciprocal_wire;
//     wire [15:0] vec_max;
//     wire [135:0] quantized_data_wire;

//     matrix_accelerator #(
//         .CALC_BIT_WIDTH(5),    // Width of the counter
//         .CALC_COUNT(32)        // Number of cycles for the calculation
//     ) uut (
//         .clk(clk),
//         .rst_n(rst_n),
//         .a_vec(a_vec),
//         .b_vec(b_vec),
//         .is_int8_mode(is_int8_mode),
//         .is_int4_mode(is_int4_mode),
//         .is_vsq(is_vsq),
//         .valid_mac(valid_mac),
//         .scale(scale),
//         .bias(bias),
//         .valid_ppu(valid_ppu),
//         .scaled_sum_wire(scaled_sum_wire),
//         .vec_max_wire(vec_max),
//         .reciprocal_wire(reciprocal_wire),
//         .quantized_data_wire(quantized_data_wire),
//         .softmax_out(output_data),
//         .done_wire(done)
//     );

//     reg [263:0] a_buffer [0:`HEIGHT-1];
//     reg [263:0] b_buffer [0:`HEIGHT-1];

//     always #5 clk = ~clk;

//     initial begin

//         $fsdbDumpfile("simulation_2.fsdb");
//         $fsdbDumpvars(0, tb);

//         clk = 0;
//         rst_n = 0;
//         a_vec = 0;
//         b_vec = 0;
//         is_int8_mode = 0;
//         is_int4_mode = 0;
//         is_vsq = 0;
//         valid_mac = 0;
//         addr = 0;
//         cycle_cnt = 0;
//         valid_ppu = 0;
//         scale = 0;
//         bias = 0;

//         $readmemb(`PATTERN_A, a_buffer);
//         $readmemb(`PATTERN_B, b_buffer);

//         for (i = 0; i < `HEIGHT + 1; i = i + 1) begin
//             $display("The %dth input value of a_buffer is %d", i, a_buffer[0][i * 8 +: 8]);
//         end

//         #10;

//         /* Input datas in mac are (4900, 5600) * (2800, 6300) and (42000, 49000) * (3500, 5600),
//            so the quantized data in sram should be (6, 7) * (3, 7) and (6, 7) * (4, 7),
//            the per vector scale factor are (800, 900) and (7000, 800)
//            and second quantization yields gamma = 55.11811024 = 0x65 in fp8,
//            so the scales are (14, 16) and (127, 14). 
//            Hence, in sram, the data should be (6, 7, 14) * (3, 7, 16) and (6, 7, 127) * (4, 7, 14), while gamma = 0x65
//            The output of mac should be (6 * 3 + 7 * 7) * 14 * 16 = 15008 and (6 * 4 + 7 * 7) * 127 * 14 = 129794,
//            and the scale is 0x4e. */
//         rst_n = 1;
//         is_int8_mode = 1;
//         scale = 8'h65;
//         bias = 8'd1;
//         valid_mac = 1;
//         valid_ppu = 1;

//         $display("scale = %d", scale);
//         $display("bias = %d", bias);

//         #650;
//         valid_ppu = 0;

//         #1000;
//         $finish;

//     end

//     always @(posedge clk) begin
//         if (done) begin
//             for (i = 0; i < 16; i = i + 1) begin
//                 $display("The %dth scaled sum is %d", i, scaled_sum_wire[i * 40 +: 40]);
//             end
//             $display("The maximal element is %d", vec_max);
//             $display("The per vector scale factor is %d", reciprocal_wire);
//             for (i = 0; i < 16; i = i + 1) begin
//                 $display("The %dth quantized data is %d", i, quantized_data_wire[i * 8 +: 8]);
//             end
//             for (i = 0; i < 16; i = i + 1) begin
//                 $display("The %dth softmax data is %d", i, output_data[i*8 +: 8]);
//             end
//             $finish;
//         end
//     end
    
//     always @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin
//             cycle_cnt <= 0;
//             a_vec <= 0;
//             b_vec <= 0;
//         end 
//         else begin
//             if (valid_mac) begin
//                 b_vec <= b_buffer[cycle_cnt];
//                 if (cycle_cnt % 16 == 0) begin
//                     a_vec <= {
//                         a_buffer[cycle_cnt],
//                         a_buffer[cycle_cnt + 1],
//                         a_buffer[cycle_cnt + 2],
//                         a_buffer[cycle_cnt + 3],
//                         a_buffer[cycle_cnt + 4],
//                         a_buffer[cycle_cnt + 5],
//                         a_buffer[cycle_cnt + 6],
//                         a_buffer[cycle_cnt + 7],
//                         a_buffer[cycle_cnt + 8],
//                         a_buffer[cycle_cnt + 9],
//                         a_buffer[cycle_cnt + 10],
//                         a_buffer[cycle_cnt + 11],
//                         a_buffer[cycle_cnt + 12],
//                         a_buffer[cycle_cnt + 13],
//                         a_buffer[cycle_cnt + 14],
//                         a_buffer[cycle_cnt + 15]
//                     };
//                 end
//                 cycle_cnt <= cycle_cnt + 1;
//             end
//         end
//     end

// endmodule