`timescale 1ns/1ps
`ifndef PPU
`define PPU

module ppu (
    input wire clk,
    input wire rst_n,
    input wire [1:0] mode,
    input wire [383:0] partial_sum,
    input wire [7:0] scale_a,
    input wire [7:0] scale_w,
    input wire [7:0] bias,
    input wire valid,
    output wire [127:0] quantized_data_wire,
    output wire [127:0] output_data,
    output wire q_done,
    output wire s_done
);
    integer i;
    wire    [639:0] scaled_sum_wire;
    wire    [255:0] from_latch_array;
    wire    [639:0] biased_sum;
    wire    [639:0] relu_sum;
    wire    [255:0] truncated_sum;
    wire            reciprocal_done_wire;
    wire    [15:0]  vec_max_wire;
    wire    [15:0]  reciprocal_wire;
    assign done_wire = (q_done && s_done);

    // scaling module
    scaling_module scaling_module_inst(
        .scale_a(scale_a),
        .scale_w(scale_w),
        .partial_sum(partial_sum),
        .scaled_sum(scaled_sum_wire)
    );

    // biasing
    
    biasing_module biasing_module_inst(
        .bias(bias),
        .scaled_sum(scaled_sum_wire),
        .biased_sum(biased_sum)
    );

    // relu
    relu_module relu_module_inst(
        .biased_sum(biased_sum),
        .relu_sum(relu_sum)
    );

    // truncation
    truncation_module truncation_module_inst(
        .relu_sum(relu_sum),
        .truncated_sum(truncated_sum)
    );

    // vector max
    max_module max_module_inst(
        .clk(clk),
        .rst_n(rst_n),
        .from_trunc(truncated_sum),
        .input_valid(valid),
        .output_en(latch_full),
        .vec_max_wire(vec_max_wire)
    );

    // reciprocal
    reciprocal_module reciprocal_module_inst(
        .clk(clk),
        .rst_n(rst_n),
        .latch_done(latch_full),
        .mode(mode),
        .vec_max_wire(vec_max_wire),
        .reciprocal_wire(reciprocal_wire),
        .reciprocal_done_wire(reciprocal_done_wire)
    );

    // vsq buffer
    latch_array latch_array_inst (
        .clk(clk),
        .rst_n(rst_n),
        .write_en(valid),
        .write_data(truncated_sum),
        .full(latch_full),
        .read_data(from_latch_array)
    );

    quantization_module quantization_module(
        .clk(clk),
        .rst_n(rst_n),
        .mode(mode),
        .from_latch_array(from_latch_array),
        .reciprocal_wire(reciprocal_wire),
        .q_en(latch_full),
        .q_out(quantized_data_wire),
        .q_done(q_done)
    );
    

    approx_softmax_module approx_softmax_module(
        .clk(clk),
        .rst_n(rst_n),
        .quantized_data_wire(quantized_data_wire),  // high 8 bits are max value
        .vec_max_wire(vec_max_wire),
        .softmax_en(q_done),
        .approx_softmax_wire(output_data),
        .approx_softmax_done_wire(s_done)
    );

endmodule

`endif

`ifndef LATCH_ARRAY
`define LATCH_ARRAY

module latch_array (
    input  wire          clk,
    input  wire          rst_n,
    input  wire          write_en,
    input  wire [255:0]  write_data,
    output wire          full,
    output wire [255:0]  read_data
);

    integer i;
    reg [255:0] latch_array [0:127];
    reg [8:0] write_addr;
    reg [6:0] read_addr;
    reg full_reg;
    assign full = full_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_addr <= 6'b0;
            write_addr <= 6'b0;
            for (i = 0; i < 127; i = i + 1) begin
                latch_array[i] <= 256'b0;
            end
            full_reg <= 0;
        end 
        else if (write_en) begin
            if (write_addr <= 255) begin
                latch_array[write_addr] <= write_data;
                write_addr <= write_addr + 1;
            end
            else begin
                full_reg <= 1;
            end
        end
        else if (full) begin
            read_addr <= (read_addr == 255) ? 0 : read_addr + 1;
        end
        else begin
            read_addr <= read_addr;
            write_addr <= write_addr;
        end
    end

    assign read_data = (full) ? latch_array[read_addr] : 256'b0;

endmodule
`endif

`ifndef SCALING_MODULE
`define SCALING_MODULE

module scaling_module (
    input  wire [7:0]   scale_a,               // scale in FP8 (E4M3)
    input  wire [7:0]   scale_w,
    input  wire [383:0] partial_sum,           // 16 * 24-bit input
    output wire [639:0] scaled_sum             // 16 * 40-bit output
);

    // FP8 decoding
    wire        sign_a = scale_a[7];
    wire [3:0]  exp_a  = scale_a[6:3];           // exponent with bias 7
    wire [2:0]  mant_a = scale_a[2:0];           // mantissa (fractional)

    // Convert FP8 to fixed-point Q8.8
    wire [15:0] scale_fixed_a;
    wire [7:0]  frac_part_a = {mant_a, 5'b0};        // mantissa in Q8.8
    wire [15:0] base_a = 16'h0100 + frac_part_a;     // 1 + mant in Q8.8 = 0x0100 + frac_part
    wire [4:0]  shift_a = (exp_a >= 7) ? (exp_a - 7) : (7 - exp_a);

    wire [15:0] scaled_val_temp_a;
    assign scaled_val_temp_a = (exp_a >= 7) ? (base_a << shift_a) : (base_a >> shift_a);
    assign scale_fixed_a = sign_a ? (~scaled_val_temp_a + 1'b1) : scaled_val_temp_a;  // signed value

    // FP8 decoding
    wire        sign_w = scale_w[7];
    wire [3:0]  exp_w  = scale_w[6:3];           // exponent with bias 7
    wire [2:0]  mant_w = scale_w[2:0];           // mantissa (fractional)

    // Convert FP8 to fixed-point Q8.8
    wire [15:0] scale_fixed_w;
    wire [7:0]  frac_part_w = {mant_w, 5'b0};        // mantissa in Q8.8
    wire [15:0] base_w = 16'h0100 + frac_part_w;     // 1 + mant in Q8.8 = 0x0100 + frac_part
    wire [4:0]  shift_w = (exp_w >= 7) ? (exp_w - 7) : (7 - exp_w);

    wire [15:0] scaled_val_temp_w;
    assign scaled_val_temp_w = (exp_w >= 7) ? (base_w << shift_w) : (base_w >> shift_w);
    assign scale_fixed_w = sign_w ? (~scaled_val_temp_w + 1'b1) : scaled_val_temp_w;  // signed value

    // Scale partial_sum
    genvar j;
    generate
        for (j = 0; j < 16; j = j + 1) begin: SCALING
            wire signed [23:0] in_val = partial_sum[(j * 24) +: 24];
            wire signed [39:0] product = ((in_val * $signed(scale_fixed_a) >>> 8) * $signed(scale_fixed_w)) >>> 8;
            assign scaled_sum[(j * 40) +: 40] = product;
        end
    endgenerate

endmodule

`endif

`ifndef BIASING_MODULE
`define BIASING_MODULE

module biasing_module (
    input  wire [7:0]   bias,
    input  wire [639:0] scaled_sum,
    output wire [639:0] biased_sum
);

    genvar j;
    generate
        for (j = 0; j < 16; j = j + 1) begin: BIASING
            wire [39:0] in_bias = scaled_sum[(j * 40) +: 40];
            assign biased_sum[(j * 40) +: 40] = in_bias + {16'b0, bias, 16'b0};
        end
    endgenerate
    
endmodule

`endif

`ifndef RELU_MODULE
`define RELU_MODULE

module relu_module (
    input  wire [639:0] biased_sum,
    output wire [639:0] relu_sum
);

    genvar j;
    generate
        for (j = 0; j < 16; j = j + 1) begin: RELU
            wire [39:0] in_relu = biased_sum[(j * 40) +: 40];
            assign relu_sum[(j * 40) +: 40] = ($signed(in_relu) < 0) ? 40'b0 : in_relu;
        end
    endgenerate

endmodule
`endif

`ifndef TRUNCATION_MODULE
`define TRUNCATION_MODULE

module truncation_module (
    input  wire [639:0] relu_sum,
    output wire [255:0] truncated_sum
);

    genvar j;
    generate
        for (j = 0; j < 16; j = j + 1) begin: TRUNCATION
            assign truncated_sum[(j * 16) +: 16] = relu_sum[(j * 40) + 31 -: 16]; // Truncate to high 16 bits
        end
    endgenerate
endmodule

`endif

`ifndef MAX_MODULE
`define MAX_MODULE

module max_module(
    input  wire         clk,
    input  wire         rst_n,
    input  wire [255:0] from_trunc,
    input  wire         input_valid,
    input  wire         output_en,
    output wire [15:0]  vec_max_wire
);

    reg signed [15:0] vec_max [0:63];
    reg signed [15:0] temp_max;
    reg [5:0] write_addr;
    reg [5:0] read_addr;
    reg buffer;
    integer i;

    assign vec_max_wire = (output_en) ? vec_max[read_addr] : 0;

    always@(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 63; i = i + 1) begin
                vec_max[i] <= 0;
            end
            write_addr <= 0;
            read_addr <= 0;
            buffer <= 0;
        end
        else if (input_valid) begin
            if (buffer) begin
                vec_max[write_addr] <= temp_max;
                write_addr <= write_addr + 1;
            end
            else begin
                buffer <= 1;
            end
            temp_max = from_trunc[15:0];
            for (i = 1; i < 16; i = i + 1) begin
                if ($signed(from_trunc[i * 16 +: 16]) > temp_max) begin
                    temp_max = from_trunc[i * 16 +:16];
                end
            end
        end
        else if (output_en) begin
            read_addr <= read_addr + 1;
        end
        else begin
            vec_max <= vec_max;
        end
    end

endmodule

`endif

`ifndef RECIPROCAL_MODULE
`define RECIPROCAL_MODULE

module reciprocal_module(
    input wire clk,
    input wire rst_n,
    input wire latch_done,
    input wire [1:0] mode,
    input wire [15:0] vec_max_wire,
    output wire [15:0] reciprocal_wire,
    output wire reciprocal_done_wire
);

    reg [15:0] reciprocal;
    reg reciprocal_done;
    assign reciprocal_wire = reciprocal;
    assign reciprocal_done_wire = reciprocal_done;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reciprocal <= 0;
            reciprocal_done <= 1'b0;
        end
        else if (latch_done) begin
            if (mode == 0) begin
                reciprocal <= (vec_max_wire == 0) ? 16'hffff : (127 << 8)/ vec_max_wire;
            end
            else begin
                reciprocal <= (vec_max_wire == 0) ? 16'hffff : (7 << 8)/ vec_max_wire;
            end
            reciprocal_done <= 1'b1;
        end
        else begin
            reciprocal <= reciprocal;
            reciprocal_done <= reciprocal_done;
        end
    end

endmodule

`endif

`ifndef APPROX_SOFTMAX_MODULE
`define APPROX_SOFTMAX_MODULE

module approx_softmax_module (
    input  wire         clk,
    input  wire         rst_n,
    input  wire [127:0] quantized_data_wire,
    input  wire [15:0]  vec_max_wire,
    input  wire         softmax_en,
    output wire [127:0] approx_softmax_wire,
    output wire         approx_softmax_done_wire
);
    reg         approx_softmax_done;
    reg [7:0]   shift_val   [15:0];
    reg [7:0]   shift_amt;
    reg [15:0]  exp_sum;
    reg [7:0]   softmax_val [15:0];
    reg [2:0]   state;
    reg [127:0] approx_softmax;
    assign approx_softmax_wire      = approx_softmax;
    assign approx_softmax_done_wire = approx_softmax_done;

    integer i;
    localparam IDLE = 3'b000, SHIFT = 3'b001, SUM = 3'b010, DIV = 3'b011, DONE = 3'b100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            approx_softmax <= 0;
            state <= IDLE;
            approx_softmax_done <= 0;
            exp_sum <= 0;
            i = 0;
        end
        else begin
            case (state)
                IDLE: begin
                    if (softmax_en) begin
                        state <= SHIFT;
                        approx_softmax_done <= 0;
                        exp_sum <= 0;
                    end
                end 
                SHIFT: begin
                    for (i = 0; i < 16; i = i + 1) begin
                        shift_amt = vec_max_wire - quantized_data_wire[(i * 8) +: 8];
                        if (shift_amt > 7)
                            shift_amt = 7; // maximum shift amount is 7
                        shift_val[i] <= 8'd128 >> shift_amt;
                    end
                    state <= SUM;
                end
                SUM: begin
                    exp_sum <= shift_val[0] + shift_val[1] + shift_val[2] + shift_val[3] +
                               shift_val[4] + shift_val[5] + shift_val[6] + shift_val[7] +
                               shift_val[8] + shift_val[9] + shift_val[10] + shift_val[11] +
                               shift_val[12] + shift_val[13] + shift_val[14] + shift_val[15];
                    state <= DIV;
                end
                DIV: begin
                    for (i = 0; i < 16; i = i + 1) begin
                        if (exp_sum != 0) begin
                            softmax_val[i] <= (shift_val[i] * 255) / exp_sum;
                        end
                        else softmax_val[i] <= 0;
                    end
                    state <= DONE;
                end
                DONE: begin
                    for (i = 0; i < 16; i = i + 1) begin
                        approx_softmax[8 * i +: 8] <= softmax_val[i];
                    end
                    approx_softmax_done <= 1;
                    state <= IDLE;
                end
                default: begin
                    state <= state;
                    approx_softmax <= approx_softmax;
                    approx_softmax_done <= approx_softmax_done;
                    exp_sum <= exp_sum;
                    for (i = 0; i < 16; i = i + 1) begin
                        shift_val[i] <= shift_val[i];
                        softmax_val[i] <= softmax_val[i];
                    end
                end
            endcase
        end
    end
    
endmodule

module quantization_module (
    input  wire         clk,
    input  wire         rst_n,
    input  wire [1:0]   mode,
    input  wire [255:0] from_latch_array,
    input  wire [15:0]  reciprocal_wire,
    input  wire         q_en,
    output wire [127:0] q_out,
    output wire         q_done
);

    integer i;
    reg [127:0] quantized_data;
    reg signed [15:0] temp_val [0:15];
    reg quantization_done;
    assign q_done = quantization_done;
    assign q_out = (q_done) ? quantized_data : 0;
    
    always @(*) begin
        if (q_en && reciprocal_wire != 0) begin
            for (i = 0; i < 16; i = i + 1) begin
                temp_val[i] <= (($signed(from_latch_array[i*16 +: 16]) * reciprocal_wire) >> 8);
            end
        end

    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            quantized_data <= 0;
            for (i = 0; i < 16; i = i + 1) begin
                temp_val[i] <= 0;
            end
            quantization_done <= 0;
        end
        else if (q_en && reciprocal_wire != 0) begin
            if (mode == 0) begin
                for (i = 0; i < 16; i = i + 1) begin
                    if (temp_val[i] > 127) begin
                        quantized_data[i * 8 +: 8] <= 8'd127;
                    end
                    else if (temp_val[i] < -128) begin
                        quantized_data[i * 8 +: 8] <= 8'h80;
                    end
                    else begin
                        quantized_data[i * 8 +: 8] <= temp_val[i][7:0];
                    end
                end
            end
            else begin
                for (i = 0; i < 16; i = i + 1) begin
                    if (temp_val[i] > 7) begin
                        quantized_data[i * 4 +: 4] <= 4'd7;
                    end
                    else if (temp_val[i] < -8) begin
                        quantized_data[i * 4 +: 4] <= 4'h8;
                    end
                    else begin
                        quantized_data[i * 4 +: 4] <= temp_val[i][3:0];
                    end
                    quantized_data[i * 4 + 4 +: 4] <= 4'b0;
                end
            end
            quantization_done <= 1;
        end
        else begin
            quantization_done <= 0;
            quantized_data <= 0;
        end
    end

endmodule

`endif
    // reg [1:0] state;
    // localparam IDLE = 2'b00;
    // localparam INPUT = 2'b01;
    // localparam OUTPUT = 2'b10;
    // reading and writing vsq buffer
    // always @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //         state <= IDLE;
    //         counter <= 4'b0000;
    //         read_en <= 1'b0;
    //         latch_done <= 1'b0;
    //         write_en <= 1'b0;
    //         reset_addr <= 1'b0;
    //     end
    //     else begin
    //         case (state)
    //             IDLE: begin
    //                 if (reciprocal_done_wire) begin 
    //                     state <= OUTPUT;
    //                     read_en <= 1'b1;
    //                     latch_done <= 1'b0;
    //                     counter <= 0;
    //                     reset_addr <= 1'b1;
    //                 end 
    //                 else if (valid) begin
    //                     state <= INPUT;
    //                     write_en <= 1'b1;
    //                 end
    //                 else begin
    //                     state <= IDLE;
    //                     read_en <= 1'b0;
    //                     latch_done <= 1'b0;
    //                     counter <= 4'b0000;
    //                 end
    //             end
    //             INPUT: begin
    //                 if (counter == 4'b1111) begin
    //                     state <= OUTPUT;
    //                     read_en <= 1'b1;
    //                     write_en <= 1'b0;
    //                     latch_done <= 1'b0;
    //                     counter <= 0;
    //                 end
    //                 else begin
    //                     counter <= counter + 1;
    //                 end
    //             end
    //             OUTPUT: begin
    //                 if (counter == 4'b1111) begin
    //                     state <= IDLE;
    //                     counter <= 0;
    //                     latch_done <= 1;
    //                     read_en <= 0;
    //                 end
    //                 else begin
    //                     counter <= counter + 1;
    //                     reset_addr <= 1'b0;
    //                 end
    //             end
    //         endcase
    //     end
    // end