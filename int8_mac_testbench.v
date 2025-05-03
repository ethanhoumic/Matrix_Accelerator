`timescale 1 ns/1 ps
`include "int8_mac.v"

module tb ;

    reg clk;
    reg rst_n;
    reg [263:0] a_vec;
    reg [263:0] b_vec;
    reg [23:0] partial_sum_in;
    reg [23:0] ans;
    wire [23:0] partial_sum_out;
    integer file, i, data, cycle_count;

    int8_mac uut(
        .clk(clk),
        .rst_n(rst_n),
        .int8_en(1'b1),
        .a_vec(a_vec),
        .b_vec(b_vec),
        .partial_sum_in(partial_sum_in),
        .partial_sum_out(partial_sum_out)
    );

    always #5 clk = ~clk;

    initial begin

        $fsdbDumpfile("simulation.fsdb");
        $fsdbDumpvars(0, tb);

        clk = 0;
        rst_n = 0;
        cycle_count = 1;
        partial_sum_in = 0;
        
        #5;
        rst_n = 1;

        file = $fopen("a_vec.txt", "r");
        if (!file) begin
            $display("Can't open a_vec.txt. ");
            $finish;
        end
        else begin
            data = $fscanf(file, "%b", a_vec);
        end
        $fclose(file);

        file = $fopen("b_vec.txt", "r");
        if (!file) begin
            $display("Can't open b_vec.txt. ");
            $finish;
        end
        else begin
            data = $fscanf(file, "%b", b_vec);
        end
        $fclose(file);

        file = $fopen("vec_ans.txt", "r");
        if (!file) begin
            $display("Can't open vec_ans.txt. ");
            $finish;
        end
        else begin
            data = $fscanf(file, "%b", ans);
        end
        $fclose(file);

        #100;

    end

    always @(posedge clk) begin
        if (!rst_n) begin
            partial_sum_in <= 0;
        end
        cycle_count = cycle_count + 1;
        if (cycle_count > 10) begin
            if (partial_sum_out !== ans) begin
                $display("Error. Expected answer %d, but get %d instead. ", ans, partial_sum_out);
            end
            else begin
                $display("Correct. Expected answer %d, get %d. ", ans, partial_sum_out);
            end
            $finish;
        end
    end

    
endmodule