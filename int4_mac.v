`timescale 1 ns/1 ps
`ifndef INT4_MAC
`define INT4_MAC

module int4_mac (
    input  wire                int4_en,
    input  wire        [263:0] a_vec,
    input  wire        [263:0] b_vec,
    input  wire signed [23:0]  partial_sum_in,
    output wire signed [23:0]  partial_sum_out
);

    wire signed [3:0] a [0:64];
    wire signed [3:0] b [0:64];

    genvar j;
    generate
        for (j = 0; j < 65; j = j + 1) begin : UNPACK
            assign a[j] = $signed(a_vec[(j * 4) +: 4]);
            assign b[j] = $signed(b_vec[(j * 4) +: 4]);
        end
    endgenerate

    wire signed [31:0] products [2:64];

    generate
        for (j = 2; j <= 64; j = j + 1) begin : MULTIPLY
            assign products[j] = a[j] * b[j];
        end
    endgenerate

    wire signed [23:0] sum_lvl1 [0:15];
    wire signed [23:0] sum_lvl2 [0:7];
    wire signed [23:0] sum_lvl3 [0:3];
    wire signed [23:0] sum_lvl4 [0:1];
    wire signed [23:0] sum_final;

    generate
        for (j = 0; j < 16; j = j + 1)
            assign sum_lvl1[j] = products[2*j+2] + products[2*j+3];

        for (j = 0; j < 8; j = j + 1)
            assign sum_lvl2[j] = sum_lvl1[2*j] + sum_lvl1[2*j+1];

        for (j = 0; j < 4; j = j + 1)
            assign sum_lvl3[j] = sum_lvl2[2*j] + sum_lvl2[2*j+1];

        for (j = 0; j < 2; j = j + 1)
            assign sum_lvl4[j] = sum_lvl3[2*j] + sum_lvl3[2*j+1];
    endgenerate

    assign sum_final = sum_lvl4[0] + sum_lvl4[1];

    // output
    assign partial_sum_out = int4_en ? (partial_sum_in + sum_final) : 24'sd0;

endmodule

`endif