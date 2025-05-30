`timescale 1 ns/1 ps
`ifndef INT4_MAC
`define INT4_MAC

module int4_mac (
    input wire clk,
    input wire rst_n,
    input wire int4_en,
    input wire [263:0] a_vec,
    input wire [263:0] b_vec,
    input wire [23:0] partial_sum_in,
    output reg [23:0] partial_sum_out
);

    wire [3:0] a [0:63];
    wire [3:0] b [0:63];
    wire [23:0] mult_sum;

    genvar j;
    generate
        for (j = 0; j < 64; j = j + 1) begin
            assign a[j] = a_vec[(j * 4) +: 4];
            assign b[j] = b_vec[(j * 4) +: 4];
        end
    endgenerate

    assign mult_sum = 
        a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3] +
        a[4] * b[4] + a[5] * b[5] + a[6] * b[6] + a[7] * b[7] +
        a[8] * b[8] + a[9] * b[9] + a[10] * b[10] + a[11] * b[11] +
        a[12] * b[12] + a[13] * b[13] + a[14] * b[14] + a[15] * b[15] +
        a[16] * b[16] + a[17] * b[17] + a[18] * b[18] + a[19] * b[19] +
        a[20] * b[20] + a[21] * b[21] + a[22] * b[22] + a[23] * b[23] +
        a[24] * b[24] + a[25] * b[25] + a[26] * b[26] + a[27] * b[27] +
        a[28] * b[28] + a[29] * b[29] + a[30] * b[30] + a[31] * b[31] +
        a[32] * b[32] + a[33] * b[33] + a[34] * b[34] + a[35] * b[35] +
        a[36] * b[36] + a[37] * b[37] + a[38] * b[38] + a[39] * b[39] +
        a[40] * b[40] + a[41] * b[41] + a[42] * b[42] + a[43] * b[43] +
        a[44] * b[44] + a[45] * b[45] + a[46] * b[46] + a[47] * b[47] +
        a[48] * b[48] + a[49] * b[49] + a[50] * b[50] + a[51] * b[51] +
        a[52] * b[52] + a[53] * b[53] + a[54] * b[54] + a[55] * b[55] +
        a[56] * b[56] + a[57] * b[57] + a[58] * b[58] + a[59] * b[59] +
        a[60] * b[60] + a[61] * b[61] + a[62] * b[62] + a[63] * b[63];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            partial_sum_out <= 0;
        end
        else if (int4_en) begin
            partial_sum_out <= mult_sum + partial_sum_in;
        end
        else begin
            partial_sum_out <= 0;
        end 
    end

endmodule

`endif