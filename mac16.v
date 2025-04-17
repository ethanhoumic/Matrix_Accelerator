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
    reg [3:0] counter;

    // 使用一級暫存器延遲 latch 寫入（模擬計算延遲）
    reg [23:0] result_buffer [0:15];
    reg        result_valid;

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin: mac_units
            MAC_datapath mac_inst(
                .clk(clk),
                .rst_n(rst_n),
                .a_vec(a_vec[i * 264 + 263 -: 264]),
                .b_vec(b_vec),
                .is_int4_mode(is_int4_mode),
                .is_int8_mode(is_int8_mode),
                .is_vsq(is_vsq),
                .partial_sum_in(partial_sum_out[i]),
                .partial_sum_out(partial_sum_in[i])
            );
        end
    endgenerate

    // Counter 控制：每 16 拍循環一次
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            counter <= 0;
        else
            counter <= counter + 1;
    end

    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (j = 0; j < 16; j = j + 1) begin
                partial_sum_out[j] <= 24'b0;
                result_buffer[j] <= 24'b0;
            end
            latch_array_out <= 6144'b0;
            result_valid <= 0;
        end else begin
            // 將上拍的 MAC 結果寫入 latch_array_out（延遲一拍）
            if (result_valid) begin
                for (j = 0; j < 16; j = j + 1) begin
                    latch_array_out[j * 384 + counter * 24 +: 24] <= result_buffer[j];
                end
            end

            // 更新 partial_sum_out（從 latch array 取出資料）
            for (j = 0; j < 16; j = j + 1) begin
                partial_sum_out[j] <= latch_array_out[j * 384 + counter * 24 +: 24];
                result_buffer[j]   <= partial_sum_in[j];  // 保存這一輪計算結果
            end

            result_valid <= 1;
        end
    end

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