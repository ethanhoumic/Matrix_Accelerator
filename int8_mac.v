`timescale 1 ns/1 ps

`ifndef INT8_MAC
`define INT8_MAC

module int8_mac (
    input wire int8_en,
    input wire [263:0] a_vec,
    input wire [263:0] b_vec,
    input wire [23:0] partial_sum_in,
    output wire [23:0] partial_sum_out
);

    wire [7:0] a [0:32];
    wire [7:0] b [0:32];
    wire [23:0] mult_sum;

    integer i;

    genvar j;
    generate
        for (j = 0; j < 33; j = j + 1) begin
            assign a[j] = a_vec[(j * 8) +: 8];
            assign b[j] = b_vec[(j * 8) +: 8];
        end
    endgenerate

    assign mult_sum = (    // a[0] is the scale factor
        a[1] * b[1] + a[2] * b[2] + a[3] * b[3] +
        a[4] * b[4] + a[5] * b[5] + a[6] * b[6] + a[7] * b[7] +
        a[8] * b[8] + a[9] * b[9] + a[10] * b[10] + a[11] * b[11] +
        a[12] * b[12] + a[13] * b[13] + a[14] * b[14] + a[15] * b[15] +
        a[16] * b[16] + a[17] * b[17] + a[18] * b[18] + a[19] * b[19] +
        a[20] * b[20] + a[21] * b[21] + a[22] * b[22] + a[23] * b[23] +
        a[24] * b[24] + a[25] * b[25] + a[26] * b[26] + a[27] * b[27] +
        a[28] * b[28] + a[29] * b[29] + a[30] * b[30] + a[31] * b[31] +
        a[32] * b[32]
    ) & 21'b111111111111111111111; // Mask to 21 bits

    assign partial_sum_out = (int8_en) ? (partial_sum_in + mult_sum) : 0;

endmodule

`endif