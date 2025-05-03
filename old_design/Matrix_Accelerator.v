`timescale 1 ns/1 ps

`ifndef MATRIX_ACCELERATOR
`define MATRIX_ACCELERATOR

module Matrix_Accelerator (
    input wire clk,
    input wire [1:0] config_in,
    input wire [7:0] matrix_a[0:63][0:63],
    input wire [7:0] matrix_b[0:63][0:63],
    output reg [23:0] to_PPU [0:15]
);

    wire rst_n;
    wire int8_sram_start, int4_sram_start;
    wire to_MAC_en;
    wire from_MAC_en;
    wire to_PPU_en;
    wire is_int8_mode;
    wire is_int4_mode;
    wire is_vsq;
    wire write_en_a, write_en_b;
    wire [6:0] addr_a;
    wire [10:0] addr_b;
    wire [263:0] data_in_a [0:15];
    wire [263:0] data_in_b;
    wire [263:0] data_out_a [0:15];
    wire [263:0] data_out_b;
    wire [23:0] partial_sum_from_acc [0:15];
    wire [23:0] partial_sum_from_mac [0:15];
    wire int8_done, acc_done, to_MAC_en;

    control_unit ctrl(
        .clk(clk),
        .config_in(config_in),
        .rst_n(rst_n),
        .int8_sram_start(int8_sram_start),
        .int4_sram_start(int4_sram_start),
        .to_MAC_en(to_MAC_en),
        .from_MAC_en(from_MAC_en),    // to ACC
        .to_PPU_en(to_PPU_en),        // to ACC
        .is_int8_mode(is_int8_mode),  // to MAC
        .is_int4_mode(is_int4_mode),  // to MAC
        .is_vsq(is_vsq)               // to MAC
    );

    a_sram_writer a_writer(
        .clk(clk),
        .rst_n(rst_n),
        .matrix(matrix_a),
        .start(int8_sram_start),
        .write_en(write_en_a),                         
        .addr(addr_a),
        .data_in(data_in_a) 
    );

    b_sram_writer b_writer(
        .clk(clk),
        .rst_n(rst_n),
        .matrix(matrix_b),
        .start(int8_sram_start),
        .write_en(write_en_b),                         
        .addr(addr_b),
        .data_in(data_in_b)
    );

    a_sram_16bank a_sram(
        .clk(clk),
        .rst_n(rst_n),
        .write_en(write_en_a),
        .addr(addr_a),
        .data_in(data_in_a),
        .output_en(to_MAC_en),
        .data_out(data_out_a)
    );

    b_sram b_sram(
        .clk(clk),
        .rst_n(rst_n),
        .write_en(write_en_b),
        .addr(addr_b),
        .data_in(data_in_b),
        .output_en(to_MAC_en),
        .data_out(data_out_b)
    );

    mac_16 mac_16_inst(
        .clk(clk),
        .rst_n(rst_n),
        .a_vec(data_out_a),
        .b_vec(data_out_b),
        .is_int8_mode(is_int8_mode),
        .is_int4_mode(is_int4_mode),
        .is_vsq(is_vsq),
        .partial_sum_in(partial_sum_from_acc),    // from ACC
        .partial_sum_out(partial_sum_from_mac)
    );

    accumulation_collector acc(
        .clk(clk),
        .rst_n(rst_n),
        .to_MAC_en(to_MAC_en),
        .from_MAC_en(from_MAC_en),
        .to_PPU_en(to_PPU_en),
        .from_MAC(partial_sum_from_mac), 
        .to_MAC(partial_sum_from_acc), 
        .to_PPU(to_PPU),
        .ACC_done(acc_done)
    );

endmodule

`endif

`ifndef MAC_16
`define MAC_16

module mac_16 (
    input wire clk,
    input wire rst_n,
    input wire[263:0] a_vec [0:15],
    input wire[263:0] b_vec,
    input wire is_int8_mode,
    input wire is_int4_mode,
    input wire is_vsq,
    // input wire [7:0] a_factor [0:15],
    // input wire [7:0] b_factor [0:15],
    input wire [23:0] partial_sum_in [0:15],
    output reg [23:0] partial_sum_out [0:15]
);
    
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin: mac_units
            MAC_datapath mac_inst(
                .clk(clk),
                .rst_n(rst_n),
                .a_vec(a_vec[i]),
                .b_vec(b_vec),
                .is_int4_mode(is_int4_mode),
                .is_int8_mode(is_int8_mode),
                .is_vsq(is_vsq),
                // .a_factor(a_factor[i]),
                // .b_factor(b_factor[i]),
                .partial_sum_in(partial_sum_in[i]),
                .partial_sum_out(partial_sum_out[i])
            );
        end
    endgenerate

endmodule

`endif

`ifndef MAC_DATAPATH
`define MAC_DATAPATH

module MAC_datapath (
    input wire clk,
    input wire rst_n,
    input wire[263:0] a_vec,
    input wire[263:0] b_vec,
    input wire is_int8_mode,
    input wire is_int4_mode,
    input wire is_vsq,
    // input wire [7:0] a_factor,
    // input wire [7:0] b_factor,
    input wire [23:0] partial_sum_in,
    output reg [23:0] partial_sum_out
);

    wire [23:0] partial_sum_int8;
    wire [23:0] partial_sum_int4;

    int8_mac int8_inst(
        .clk(clk),
        .rst_n(rst_n),
        .int8_en(is_int8_mode),
        .a_vec(a_vec),
        .b_vec(b_vec),
        .partial_sum_in(partial_sum_in),
        .partial_sum_out(partial_sum_int8)
    );

    int4_mac int4_inst(
        .clk(clk),
        .rst_n(rst_n),
        .int4_en(is_int4_mode),
        .a_vec(a_vec),
        .b_vec(b_vec),
        .partial_sum_in(partial_sum_in),
        .partial_sum_out(partial_sum_int4)
    );

    always @(*) begin
        if (is_int8_mode) partial_sum_out = partial_sum_int8;
        else if (is_int4_mode) partial_sum_out = partial_sum_int4;
        else partial_sum_out = 24'b0; 
    end
    
endmodule

`endif

`ifndef INT8_MAC
`define INT8_MAC

module int8_mac #(
    parameter NUM = 64
)(
    input wire clk,
    input wire rst_n,
    input wire int8_en,
    input wire [263:0] a_vec,
    input wire [263:0] b_vec,
    input wire [23:0] partial_sum_in,
    output reg [23:0] partial_sum_out
);

    wire [7:0] a [0:31];
    wire [7:0] b [0:31];
    wire [23:0] mult_sum;

    integer i;

    genvar j;
    generate
        for (j = 0; j < 32; j = j + 1) begin
            assign a[j] = a_vec[(j * 8) +: 8];
            assign b[j] = b_vec[(j * 8) +: 8];
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
        a[28] * b[28] + a[29] * b[29] + a[30] * b[30] + a[31] * b[31];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            partial_sum_out <= 0;
        end
        else if (int8_en) begin
            partial_sum_out <= mult_sum + partial_sum_in;
        end
        else begin
            partial_sum_out <= 0;
        end
    end

endmodule

`endif

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