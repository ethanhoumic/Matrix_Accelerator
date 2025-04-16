`timescale 1ns/1ps

module sram_writer_tb;

    // Parameters
    parameter MATRIX_SIZE = 64;
    parameter LANE_NUM = 16;

    // Signals
    reg clk;
    reg rst_n;
    reg start;
    reg [7:0] matrix [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];
    wire write_en;
    wire [263:0] data_in [0:15];
    
    reg output_en;
    wire [263:0] data_out [0:15];
    integer i, j, error_count;

    // Instantiate SRAM writer
    a_sram_writer #(.MATRIX_SIZE(MATRIX_SIZE), .LANE_NUM(LANE_NUM)) writer (
        .clk(clk),
        .rst_n(rst_n),
        .matrix(matrix),
        .start(start),
        .write_en(write_en),
        .data_in(data_in)
    );

    // Instantiate SRAM banks
    a_sram_16bank sram (
        .clk(clk),
        .rst_n(rst_n),
        .write_en(write_en),
        .data_in(data_in),
        .output_en(output_en),
        .data_out(data_out)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Test sequence
    initial begin
        // Initialize signals

        $fsdbDumpfile("simulation.fsdb");
        $fsdbDumpvars(0, sram_writer_tb);
        $dumpvars(1, data_in);

        clk = 0;
        rst_n = 0;
        start = 0;
        output_en = 0;
        error_count = 0;
        
        // Initialize matrix with test data
        for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
            for (j = 0; j < MATRIX_SIZE; j = j + 1) begin
                matrix[i][j] = (i + j) % 256;  // Example data
            end
        end
        
        // $display("=== matrix ===");
        // for (i = 0; i < 64; i = i + 1) begin
        //     for (j = 0; j < 64; j = j + 1) begin
        //         $write("%h ", matrix[i][j]);
        //     end
        //     $write("\n");
        // end
        // $display("===================================");

        // Reset the system
        #10 rst_n = 1;
        
        // Start the writing process
        #10 start = 1;
        #10 start = 0;
        
        // Wait for write operation to complete
        #200;
        
        // Enable output readback
        output_en = 1;
        #200;
        
        $display("Comparing sram and matrix...");
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin // 只檢查前 8 筆 (對應 address 0~7)
                if (sram.sram[i][j] !== expected_data(i, j)) begin
                    $display("Wrong: SRAM[%0d][%0d] = %h, should be %h", 
                             i, j, sram.sram[i][j], expected_data(i, j));
                    error_count = error_count + 1;
                end
                else begin
                    $display("Correct: SRAM[%0d][%0d] = %h, should be %h", 
                             i, j, sram.sram[i][j], expected_data(i, j));
                end
            end
        end

        // 顯示測試結果
        if (error_count == 0) begin
            $display("Pass !");
        end else begin
            $display("Fail, %0d errors", error_count);
        end
        
        $finish;
    end

    function [263:0] expected_data;
        input integer lane;
        input integer addr;
        integer row, col, k;
        begin
            row = (addr / 2) * 16 + lane;
            col = (addr % 2) * 32;
            expected_data = 0;
            for (k = 0; k < 32; k = k + 1) begin
                expected_data[8*(k+1)-1 -: 8] = matrix[row][col + (31 - k)];
            end
        end
    endfunction

endmodule
