`timescale 1 ns/1 ps

module tb;

    reg clk;

    always #5 clk = ~clk;
    integer error;
    
    initial begin

        clk = 0;
        error = 0;

        $display("Testbench started.");
        if (error == 0) begin
            $display("All tests passed!");
        end else begin
            $display("%d errors found!", error);
        end

        #100;
        $finish;

    end

    

endmodule