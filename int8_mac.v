`timescale 1 ns/1 ps
`ifndef INT8_MAC
`define INT8_MAC

module int8_mac #(
    parameter NUM = 33
)(
    input wire clk,
    input wire rst_n,
    input wire int8_en,
    input wire [263:0] a_vec,
    input wire [263:0] b_vec,
    input wire [23:0] partial_sum_in,
    output reg [23:0] partial_sum_out
);

    wire signed [7:0] a [0:NUM-1];
    wire signed [7:0] b [0:NUM-1];
    wire signed [31:0] products [0:NUM-1];
    wire signed [31:0] dot_sum;

    genvar i;
    generate
        for (i = 0; i < NUM; i = i + 1) begin : unpack
            assign a[i] = a_vec[i * 8 +: 8];
            assign b[i] = b_vec[i * 8 +: 8];
            assign products[i] = a[i] * b[i];
        end
    endgenerate

    assign dot_sum =
        products[0] + products[1] + products[2] + products[3] +
        products[4] + products[5] + products[6] + products[7] +
        products[8] + products[9] + products[10] + products[11] +
        products[12] + products[13] + products[14] + products[15] +
        products[16] + products[17] + products[18] + products[19] +
        products[20] + products[21] + products[22] + products[23] +
        products[24] + products[25] + products[26] + products[27] +
        products[28] + products[29] + products[30] + products[31] +
        products[32];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            partial_sum_out <= 0;
        else if (int8_en)
            partial_sum_out <= (dot_sum + partial_sum_in) & 24'hFFFFFF;
        else
            partial_sum_out <= 0;
    end

endmodule

`endif
