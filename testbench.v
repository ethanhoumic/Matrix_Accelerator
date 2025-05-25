`timescale 1 ns/1 ps
`include "int8_mac.v"
`include "int4_mac.v"
`include "vsq_support.v"
`include "mac16.v"
`define PATTERN_A "a_sram_binary.txt"
`define PATTERN_B "b_sram_binary.txt"
`define HEIGHT 32 

module tb;

    reg           clk;
    reg           rst_n;
    reg           valid;
    reg  [4223:0] a_vec;
    reg  [263:0]  b_vec;
    reg           is_int8_mode;
    reg           is_int4_mode;
    reg           is_vsq;
    reg           ppu_done;
    reg  [4:0]    addr;
    reg  [4:0]    cycle_cnt;
    reg           buffer;

    wire [383:0]  partial_sum_out;
    wire [383:0]  partial_sum_in;
    wire          mac_done_wire;
    wire          ppu;
    wire [383:0]  to_ppu_wire;

    mac_16 #(
        .CALC_BIT_WIDTH(5),     // for testing purposes
        .CALC_COUNT(32)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .a_vec(a_vec),
        .b_vec(b_vec),
        .is_int8_mode(is_int8_mode),
        .is_int4_mode(is_int4_mode),
        .is_vsq(is_vsq),
        .valid(valid),
        .partial_sum_in(partial_sum_in),
        .partial_sum_out(partial_sum_out),
        .mac_done_wire(mac_done_wire),
        .calc_done_wire(ppu)
    );

    acc_collector acc_uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(valid),
        .ppu(ppu),
        .mac_done(mac_done_wire),
        .partial_sum_in(partial_sum_out),
        .to_mac(partial_sum_in),
        .to_ppu(to_ppu_wire),
        .done_wire(ppu_done)
    );

    integer i, j;
    reg [263:0] a_buffer [0:`HEIGHT-1];
    reg [263:0] b_buffer [0:`HEIGHT-1];
    reg [383:0] output_buffer [0:`HEIGHT-1];

    always #5 clk = ~clk;

    initial begin

        $fsdbDumpfile("simulation.fsdb");
        $fsdbDumpvars(0, tb);

        // Initialize signals

        clk = 0;
        rst_n = 0;
        is_int8_mode = 0;
        is_int4_mode = 0;
        is_vsq = 0;
        a_vec = 0;
        b_vec = 0;
        addr = 0;
        cycle_cnt = 0;
        valid = 0;

        $readmemb(`PATTERN_A, a_buffer);
        $readmemb(`PATTERN_B, b_buffer);

        #10;
        rst_n = 1;
        is_int8_mode = 1;
        is_int4_mode = 0;
        is_vsq = 0;
        valid = 1;

        #325;
        valid = 0;

        #1000 $finish;
        
    end

    always @(posedge clk) begin
        if (ppu) begin
            if (buffer == 0) begin
                buffer <= 1;
            end
            else begin
                if (addr == 16) begin
                    $finish;
                end
                else begin
                    $display("Output: %h", to_ppu_wire);
                    output_buffer[addr] <= to_ppu_wire;
                    addr <= addr + 1;
                    valid <= 0;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt <= 0;
            a_vec <= 0;
            b_vec <= 0;
            buffer <= 0;
        end 
        else begin
            if (valid) begin
                b_vec <= b_buffer[cycle_cnt];
                if (cycle_cnt % 16 == 0) begin
                    a_vec <= {
                        a_buffer[cycle_cnt],
                        a_buffer[cycle_cnt + 1],
                        a_buffer[cycle_cnt + 2],
                        a_buffer[cycle_cnt + 3],
                        a_buffer[cycle_cnt + 4],
                        a_buffer[cycle_cnt + 5],
                        a_buffer[cycle_cnt + 6],
                        a_buffer[cycle_cnt + 7],
                        a_buffer[cycle_cnt + 8],
                        a_buffer[cycle_cnt + 9],
                        a_buffer[cycle_cnt + 10],
                        a_buffer[cycle_cnt + 11],
                        a_buffer[cycle_cnt + 12],
                        a_buffer[cycle_cnt + 13],
                        a_buffer[cycle_cnt + 14],
                        a_buffer[cycle_cnt + 15]
                    };
                end
                cycle_cnt <= cycle_cnt + 1;
            end
        end
    end


endmodule