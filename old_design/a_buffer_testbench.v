`timescale 1 ns/1 ps
`include "a_buffer.v"

module tb;

    reg clk;
    reg rst_n;
    reg [7:0] matrix_a[0:63][0:63];
    reg output_en;
    reg [6:0] addr;
    reg [263:0] output_buffer [0:127][0:15];
    reg [7:0] extracted_data[0:31];

    wire write_en;
    wire [263:0] data_in [0:15];
    wire [263:0] data_out [0:15];

    integer cycle_count, file, i, j, temp, bank, row, col, trash, errors;

    a_sram_writer a_sw(
        .clk(clk),
        .rst_n(rst_n),
        .matrix(matrix_a),
        .start(1'b1),
        .write_en(write_en),                
        .data_in(data_in) 
    );

    a_sram_16bank a_s(
        .clk(clk),
        .rst_n(rst_n),
        .write_en(write_en),
        .data_in(data_in),
        .output_en(output_en),
        .data_out(data_out)
    );

    always #5 clk = ~clk;

    initial begin
        $fsdbDumpfile("simulation.fsdb");
        $fsdbDumpvars(0, tb);

        clk = 0;
        rst_n = 0;
        cycle_count = 1;
        addr = 0;
        output_en = 0;
        errors = 0;

        file = $fopen("matrix_a.txt", "r");
        if (!file) begin
            $display("Cannot open matrix_a.txt. ");
            $finish;
        end
        else begin
            $display("Reading matrix_a.txt ...");
            for (i = 0; i < 64; i = i + 1) begin
                for (j = 0; j < 64; j = j + 1) begin
                    trash = $fscanf(file, "%d", temp);
                    matrix_a[i][j] = temp[7:0];
                end
            end
        end
        $fclose(file);

        #5;
        rst_n = 1;

        #200;

        output_en = 1;
        
        #1000; // Wait for data to be read into output_buffer
        
        // Added a separate block for verification after data is collected
        begin
            for (i = 0; i < 8; i = i + 1) begin
                for (bank = 0; bank < 16; bank = bank + 1) begin
                    // Extract 32 8-bit data from output_buffer
                    for (j = 0; j < 32; j = j + 1) begin
                        extracted_data[j] = output_buffer[i][bank][(j*8) +: 8];
                    end

                    // Compare with matrix_a
                    for (col = 0; col < 32; col = col + 1) begin
                        if (matrix_a[(i / 2) * 16 + bank][(i % 2) * 32 + col] !== extracted_data[col]) begin
                            $display("Mismatch at matrix_a[%0d][%0d]: Expected %0d, Got %0d",
                                    (i / 2) * 16 + bank, (i % 2) * 32 + col,
                                    matrix_a[(i / 2) * 16 + bank][(i % 2) * 32 + col], 
                                    extracted_data[col]);
                            errors = errors + 1;
                        end
                    end
                end
            end

            if (errors == 0) begin
                $display("Test PASSED: All values match!");
            end
            else begin
                $display("Test FAILED: %0d mismatches found.", errors);
            end
            $finish;
        end
    end

    always @(posedge clk) begin
        cycle_count = cycle_count + 1;
        if (cycle_count > 10) begin
            if (output_en) begin
                for (j = 0; j < 16; j = j + 1) begin
                    output_buffer[addr][j] <= data_out[j]; // Fixed indexing: buffer[addr][bank]
                end
                
                if (addr == 127) begin
                    output_en <= 0;
                    addr <= 0;
                end
                else begin
                    addr <= addr + 1;
                end
            end
        end
    end
endmodule