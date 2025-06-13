`timescale 1ns/1ps
`include "ppu.v"
`include "mac16.v"

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

`define BIAS_INT8 "./data_files/bias_int8.txt"
`define BIAS_INT4 "./data_files/bias_int4.txt"

`define PATTERN_C "./data_files/C_correct.txt"
`define PATTERN_C_SOFTMAX "./data_files/C_softmax.txt"
`define CMD "./data_files/cmd.txt"


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
    reg terminate;
    reg [8:0] output_addr;

    // --------------------Memory for A and B matrices------------------------------

    reg [7:0] a_mem [0:4224];  // 65 * 65
    reg [7:0] b_mem [0:4224];  // 65 * 65

    wire [8*4225 - 1:0] a_mem_wire;  // mem to tiling
    wire [8*4225 - 1:0] b_mem_wire;  // mem to tiling

    wire [4223:0] a_vec_wire;    // tiling to buff
    wire [263:0]  b_vec_wire;    // tiling to buff

    // --------------------Buffers for input datas--------------------------------------------

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
    reg [1:0]   a_addr_count;
    

    reg [263:0] b_buffer [0:2047];
    reg [6:0]   b_addr;
    reg [6:0]   w_b_addr;

    wire [4223:0] a_from_buff;   // buff to mac
    wire [263:0]  b_from_buff;   // buff to mac

    reg [7:0] scale_a;
    reg [7:0] scale_w;

    reg  [7:0] bias_mem [0:63];
    reg  [5:0] bias_addr;
    wire [7:0] bias;
    assign bias = (output_en) ? bias_mem[bias_addr] : 0;

    // --------------------Buffers for output------------------------------

    reg [511:0] q_data_mem [0:63];
    reg [511:0] s_data_mem [0:63];
    reg [3:0] q_addr;
    reg [3:0] q_addr_count;
    reg [3:0] s_addr;
    reg [3:0] s_addr_count;

    wire [127:0] q_data_wire;
    wire [127:0] s_data_wire;
    wire q_done_wire;
    wire s_done_wire;

    reg q_display_en;
    reg s_display_en;

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

    integer i, j, cmd_file, scale_a_file, scale_w_file;

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

    ppu ppu_inst (
        .clk(clk),
        .rst_n(rst_n),
        .mode(mode),
        .partial_sum(to_ppu_wire),
        .scale_a(scale_a),
        .scale_w(scale_w),
        .bias(bias),
        .valid(output_en),
        .quantized_data_wire(q_data_wire),
        .output_data(s_data_wire),
        .q_done(q_done_wire),
        .s_done(s_done_wire)
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
        addr_count = 0;
        output_en = 0;
        q_addr = 0;
        s_addr = 0;
        a_addr_count = 0;
        q_addr_count = 0;
        s_addr_count = 0;
        bias_addr = 0;
        terminate = 0;
        output_addr = 0;
        q_display_en = 0;
        s_display_en = 0;

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

        for (i = 0; i < 64; i = i + 1) begin
            q_data_mem[i] = 0;
            s_data_mem[i] = 0;
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

        scale_a_file = $fopen(`A_SCALE_VSQ, "r");
        if (scale_a_file) begin
            $fscanf(scale_a_file, "%b", scale_a);
            $display("Scale a is: %h", scale_a);
            $fclose(scale_a_file);
        end
        else begin
            $display("Error opening scale a file.");
            $finish;
        end

        scale_w_file = $fopen(`B_SCALE_VSQ, "r");
        if (scale_w_file) begin
            $fscanf(scale_w_file, "%b", scale_w);
            $display("Scale w is: %h", scale_w);
            $fclose(scale_w_file);
        end
        else begin
            $display("Error opening scale w file.");
            $finish;
        end

        case (mode) 
            2'b00: begin
                $readmemb(`PATTERN_A_INT8, a_mem);
                $readmemb(`PATTERN_B_INT8, b_mem);
                $readmemb(`BIAS_INT8, bias_mem);
            end
            2'b01: begin
                $readmemb(`PATTERN_A_INT4, a_mem);
                $readmemb(`PATTERN_B_INT4, b_mem);
                $readmemb(`BIAS_INT4, bias_mem);
            end
            2'b10: begin
                $readmemb(`PATTERN_A_VSQ, a_mem);
                $readmemb(`PATTERN_B_VSQ, b_mem);
                $readmemb(`BIAS_INT4, bias_mem);
            end
        endcase

        #45000;

        $finish;


    end

    always @(posedge clk or negedge rst_n) begin

        if (q_addr == 15 && s_addr == 15 && q_addr_count == 15 && s_addr_count == 15 && s_display_en) begin
            $display("====================== Simulation ends ==============================");
            $finish;
        end
        if (q_done_wire) begin
            if (q_addr == 15) begin
                if (q_addr_count == 15 && !q_display_en) begin
                    $display("============================ Quantization data done ==============================");
                    for (i = 0; i < 64; i = i + 1) begin
                        $display("Quantized data at row %d: %h", i, q_data_mem[i]);
                    end
                    q_display_en <= 1;
                end
                else begin
                    q_addr <= 0;
                    q_addr_count <= q_addr_count + 1;
                    q_data_mem[(q_addr_count / 4) * 16 + q_addr][(q_addr_count % 4) * 128 +: 128] <= q_data_wire;
                end
            end
            else begin
                q_data_mem[(q_addr_count / 4) * 16 + q_addr][(q_addr_count % 4) * 128 +: 128] <= q_data_wire;
                q_addr <= q_addr + 1;
            end
        end

        if (s_done_wire) begin
            if (s_addr == 15) begin
                if (s_addr_count == 15 && !s_display_en) begin
                    $display("======================= Softmax data done ==========================");
                    for (i = 0; i < 64; i = i + 1) begin
                        $display("Softmax data at row %d: %h", i, s_data_mem[i]);
                    end
                    s_display_en <= 1;
                end
                else begin
                    s_addr <= 0;
                    s_addr_count <= s_addr_count + 1;
                    s_data_mem[(s_addr_count / 4) * 16 + s_addr][(s_addr_count % 4) * 128 +: 128] <= s_data_wire;
                end
            end
            else begin
                s_data_mem[(s_addr_count / 4) * 16 + s_addr][(s_addr_count % 4) * 128 +: 128] <= s_data_wire;
                s_addr <= s_addr + 1;
            end
        end

        if (stall && !terminate) output_en <= 1;
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
            bias_addr <= bias_addr + 1;
            // output_buffer[output_addr] <= to_ppu_wire;
            if (mode == 0) begin
                if (output_addr == 256) begin
                    $display("============================ All mac calculations done =================================");
                    output_en <= 0;
                    terminate <= 1;
                    // for (i = 0; i < 256; i = i + 1) begin
                    //     $display("Output %d: %h", i, output_buffer[i]);
                    // end
                    // $finish;
                end
            end
            else begin
                if (output_addr == 256) begin
                    $display("============================ All mac calculations done =================================");
                    output_en <= 0;
                    terminate <= 1;
                    // for (i = 0; i < 128; i = i + 1) begin
                    //     $display("Output %d: %h", i, output_buffer[i]);
                    // end
                    // $finish;
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

            if (stall) begin
                addr_count <= 0;
                w_a_addr <= w_a_addr;
                w_b_addr <= w_b_addr;
                // $display("--------------------------------------------------------------------------------------");
                // $display("---------------------Stall condition met, waiting for next cycle----------------------");
                // $display("--------------------------------------------------------------------------------------");

            end

            else begin
                addr_count <= addr_count + 1;
                if ((addr_count + 1) % 16 == 0) begin
                    if ((addr_count + 1) % 32 == 0 && a_addr_count == 3) begin
                        w_a_addr <= w_a_addr + 1;
                        a_addr_count <= 0;
                    end 
                    else if ((addr_count + 1) % 32 == 0 && a_addr_count != 3) begin
                        w_a_addr = w_a_addr - 1;
                        a_addr_count <= a_addr_count + 1;
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