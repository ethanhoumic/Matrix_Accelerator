`timescale 1 ns/1 ps

module tb ;

    integer file;

    initial begin

        #10;

        $display("Go!");
        file = $fopen("matrix_a.txt", "r");
        if (!file) begin
            $display("Cannot open matrix_a.txt.");
            $finish;
        end
        else begin
            $display("Matrix loaded.");
            $finish;
        end
    end
    
endmodule