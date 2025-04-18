`timescale 1 ns/1 ps
`ifndef MAC_16
`define MAC_16

module mac_16 (
    input wire clk,
    input wire rst_n,
    input wire[4223:0] a_vec,
    input wire[263:0] b_vec,
    input wire is_int8_mode,
    input wire is_int4_mode,
    input wire is_vsq,
    output reg [6143:0] latch_array_out
);

    reg [23:0] partial_sum_out [0:15];
    wire [23:0] partial_sum_in [0:15];
    reg [3:0] counter, counter_next;

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin: mac_units
            MAC_datapath mac_inst(
                .a_vec(a_vec[i * 264  + 263 -: 264]),
                .b_vec(b_vec),
                .is_int4_mode(is_int4_mode),
                .is_int8_mode(is_int8_mode),
                .is_vsq(is_vsq),
                .partial_sum_in(partial_sum_out[i]),
                .partial_sum_out(partial_sum_in[i])
            );
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 4'b0000;
        end
        else begin
            if (counter == 4'b1111)
                counter <= 4'b0000;
            else
                counter <= counter + 1;
        end
    end

    integer j;
    always @(*) begin
        if (!rst_n) begin     // reset 
            for (j = 0; j < 16; j = j + 1) begin
                partial_sum_out[j] = 24'b0;
            end
            latch_array_out = 6144'b0;
        end
        else if (!clk) begin    // neg clk latch
            for (j = 0; j < 16; j = j + 1) begin
                latch_array_out[j * 384 + counter * 24 + 23 -: 24] = partial_sum_in[j];
            end
        end
        else if (clk) begin     // pos clk latch
            for (j = 0; j < 16; j = j + 1) begin
                partial_sum_out[j] = latch_array_out[j * 384 + counter * 24 + 23 -: 24];
            end
        end
    end

endmodule

`endif

`ifndef MAC_DATAPATH
`define MAC_DATAPATH

module MAC_datapath (
    input wire[263:0] a_vec,
    input wire[263:0] b_vec,
    input wire is_int8_mode,
    input wire is_int4_mode,
    input wire is_vsq,
    input wire [23:0] partial_sum_in,
    output reg [23:0] partial_sum_out
);

    wire [23:0] partial_sum_int8;
    wire [23:0] partial_sum_int4;
    wire [23:0] partial_sum_vsq;

    int8_mac int8_inst(
        .int8_en(is_int8_mode),
        .a_vec(a_vec),
        .b_vec(b_vec),
        .partial_sum_in(partial_sum_in),
        .partial_sum_out(partial_sum_int8)
    );

    int4_mac int4_inst(
        .int4_en(is_int4_mode),
        .a_vec(a_vec),
        .b_vec(b_vec),
        .partial_sum_in(partial_sum_in),
        .partial_sum_out(partial_sum_int4)
    );
    vsq_support vsq_inst(
        .is_vsq(is_vsq),
        .a_factor(a_vec[7:0]),
        .b_factor(b_vec[7:0]),
        .partial_sum_in(partial_sum_in),
        .partial_sum_out(partial_sum_vsq)
    )

    always @(*) begin
        if (is_int8_mode) partial_sum_out = partial_sum_int8;
        else if (is_int4_mode) partial_sum_out = partial_sum_int4;
        else if (is_vsq) partial_sum_out = partial_sum_vsq;
        else partial_sum_out = 24'b0; 
    end

endmodule

`endif