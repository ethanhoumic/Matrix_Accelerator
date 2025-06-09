`timescale 1ns/1ps
`ifndef PPU
`define PPU

module ppu (
    input wire clk,
    input wire rst_n,
    input wire [383:0] partial_sum,
    input wire [7:0] scale,
    input wire [7:0] bias,
    input wire valid,
    output wire [639:0] scaled_sum_wire,
    output wire [15:0] vec_max_wire,
    output wire [15:0] reciprocal_wire,
    output wire [135:0] quantized_data_wire,
    output wire [127:0] output_data,
    output wire done_wire
);
    integer i;
    reg     read_en;
    wire    read_en_wire = read_en;
    reg     write_en;
    wire    write_en_wire = write_en;
    reg     reset_addr;
    wire    reset_addr_wire = reset_addr;
    reg     [295:0] from_latch_array;
    reg     [3:0] counter;
    reg     latch_done;
    wire    [639:0] biased_sum;
    wire    [639:0] relu_sum;
    wire    [295:0] truncated_sum;
    wire            reciprocal_done_wire;
    genvar  j;

    // scaling module
    scaling_module scaling_module(
        .scale(scale),
        .partial_sum(partial_sum),
        .scaled_sum(scaled_sum_wire)
    );

    // biasing
    
    biasing_module biasing_module(
        .bias(bias),
        .scaled_sum(scaled_sum_wire),
        .biased_sum(biased_sum)
    );

    // relu
    relu_module relu_module(
        .biased_sum(biased_sum),
        .relu_sum(relu_sum)
    );

    // truncation
    truncation_module truncation_module(
        .relu_sum(relu_sum),
        .truncated_sum(truncated_sum)
    );

    // reciprocal
    reciprocal_module reciprocal_module(
        .clk(clk),
        .rst_n(rst_n),
        .latch_done(latch_done),
        .vec_max_wire(vec_max_wire),
        .reciprocal_wire(reciprocal_wire),
        .reciprocal_done_wire(reciprocal_done_wire)
    );

    // vsq buffer
    latch_array latch_array_inst (
        .clk(clk),
        .rst_n(rst_n),
        .reset_addr(reset_addr_wire),
        .write_en(write_en_wire),
        .write_data(truncated_sum),
        .read_en(read_en_wire),
        .read_data(from_latch_array)
    );

    reg [1:0] state;
    localparam IDLE = 2'b00;
    localparam INPUT = 2'b01;
    localparam OUTPUT = 2'b10;
    // reading and writing vsq buffer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'b0000;
            read_en <= 1'b0;
            latch_done <= 1'b0;
            write_en <= 1'b0;
            reset_addr <= 1'b0;
        end
        else begin
            case (state)
                IDLE: begin
                    if (reciprocal_done_wire) begin 
                        state <= OUTPUT;
                        read_en <= 1'b1;
                        latch_done <= 1'b0;
                        counter <= 0;
                        reset_addr <= 1'b1;
                    end 
                    else if (valid) begin
                        state <= INPUT;
                        write_en <= 1'b1;
                    end
                    else begin
                        state <= IDLE;
                        read_en <= 1'b0;
                        latch_done <= 1'b0;
                        counter <= 4'b0000;
                    end
                end
                INPUT: begin
                    if (counter == 4'b1111) begin
                        state <= OUTPUT;
                        read_en <= 1'b1;
                        write_en <= 1'b0;
                        latch_done <= 1'b0;
                        counter <= 0;
                    end
                    else begin
                        counter <= counter + 1;
                    end
                end
                OUTPUT: begin
                    if (counter == 4'b1111) begin
                        state <= IDLE;
                        counter <= 0;
                        latch_done <= 1;
                        read_en <= 0;
                    end
                    else begin
                        counter <= counter + 1;
                        reset_addr <= 1'b0;
                    end
                end
            endcase
        end
    end

    // vector max
    max_module max_module(
        .clk(clk),
        .rst_n(rst_n),
        .latch_en(read_en),
        .from_relu(relu_sum),
        .from_latch_array(from_latch_array),
        .vec_max_wire(vec_max_wire)
    );

    // quantize and round
    reg [135:0] quantized_data;
    reg [17:0] temp_val [0:15];
    reg [3:0] buffer;
    reg quantization_done;
    wire quantization_done_wire = quantization_done;
    assign quantized_data_wire = quantized_data;
    
    // Simplified quantization logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 17; i = i + 1) begin
                quantized_data[i*8 +: 8] <= 8'b0;
            end
            for (i = 0; i < 16; i = i + 1) begin
                temp_val[i] <= 0;
            end
            quantization_done <= 1'b0;
            buffer <= 1'b0;
        end
        else if (reciprocal_done_wire && reciprocal_wire != 0) begin
            if (buffer == 3) begin
                for (i = 0; i < 16; i = i + 1) begin
                    if (temp_val[i] > 255) begin
                        quantized_data[i*8 +: 8] <= 8'd255;
                    end
                    else begin
                        quantized_data[i*8 +: 8] <= temp_val[i][7:0];
                    end
                end
                quantized_data[135:128] <= 8'd255;
                quantization_done <= 1'b1;
                buffer <= 0;
            end
            else if (buffer == 2) begin
                for (i = 0; i < 16; i = i + 1) begin
                    temp_val[i] <= ((from_latch_array[i*16 +: 16] * reciprocal_wire) >> 6);
                end
                buffer <= buffer + 1;
            end
            else begin
                buffer <= buffer + 1;
            end
        end
        else begin
            quantization_done <= 1'b0;
        end
    end

    approx_softmax_module approx_softmax_module(
        .clk(clk),
        .rst_n(rst_n),
        .quantized_data_wire(quantized_data_wire[127:0]),  // high 8 bits are max value
        .vec_max_wire(vec_max_wire),
        .softmax_en(quantization_done_wire),
        .approx_softmax_wire(output_data),
        .approx_softmax_done_wire(done_wire)
    );

endmodule

`endif

`ifndef LATCH_ARRAY
`define LATCH_ARRAY

module latch_array (
    input  wire clk,
    input  wire rst_n,
    input  wire reset_addr,
    input  wire write_en,
    input  wire [295:0]  write_data,
    input  wire read_en,
    output wire [295:0]  read_data
);

    integer i;
    reg [295:0] latch_array [47:0];
    reg [5:0] write_addr;
    reg [5:0] read_addr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_addr <= 6'b0;
            write_addr <= 6'b0;
            for (i = 0; i < 48; i = i + 1)
                latch_array[i] <= 296'b0;
        end 
        else if (reset_addr) begin
            read_addr <= 6'b0;
            write_addr <= 6'b0;
        end
        else if (write_en) begin
            latch_array[write_addr] <= write_data;
            write_addr <= (write_addr == 47) ? 0 : write_addr + 1;
        end
        else if (read_en) begin
            read_addr <= (read_addr == 47) ? 0 : read_addr + 1;
        end
        else begin
            read_addr <= read_addr;
            write_addr <= write_addr;
        end
    end

    assign read_data = (read_en) ? latch_array[read_addr] : 296'b0;

endmodule
`endif

`ifndef SCALING_MODULE
`define SCALING_MODULE

module scaling_module (
    input  wire [7:0]   scale,                 // scale in FP8 (E4M3)
    input  wire [383:0] partial_sum,           // 16 * 24-bit input
    output wire [639:0] scaled_sum             // 16 * 40-bit output
);

    // FP8 decoding
    wire        sign = scale[7];
    wire [3:0]  exp  = scale[6:3];           // exponent with bias 7
    wire [2:0]  mant = scale[2:0];           // mantissa (fractional)

    // Convert FP8 to fixed-point Q8.8
    wire [15:0] scale_fixed;
    wire [7:0] frac_part = {mant, 5'b0};        // mantissa in Q8.8
    wire [15:0] base = 16'h0100 + frac_part;     // 1 + mant in Q8.8 = 0x0100 + frac_part
    wire [4:0]  shift = (exp >= 7) ? (exp - 7) : (7 - exp);

    wire [15:0] scaled_val_temp;
    assign scaled_val_temp = (exp >= 7) ? (base << shift) : (base >> shift);
    assign scale_fixed = sign ? (~scaled_val_temp + 1'b1) : scaled_val_temp;  // signed value

    // Scale partial_sum
    genvar j;
    generate
        for (j = 0; j < 16; j = j + 1) begin: SCALING
            wire signed [23:0] in_val = partial_sum[(j * 24) +: 24];
            wire signed [39:0] product = ((in_val * $signed(scale_fixed) >>> 8) * $signed(scale_fixed)) >>> 8;
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
            assign biased_sum[(j * 40) +: 40] = in_bias + {32'b0, bias};
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
    output wire [295:0] truncated_sum
);

    genvar j;
    generate
        for (j = 0; j < 16; j = j + 1) begin: TRUNCATION
            assign truncated_sum[(j * 16) +: 16] = relu_sum[(j * 40) + 39 -: 16]; // Truncate to high 16 bits
        end
        assign truncated_sum[295:256] = 40'b0; // Padding to 296 bits
    endgenerate
endmodule

`endif

`ifndef MAX_MODULE
`define MAX_MODULE

module max_module(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         latch_en,
    input  wire [639:0] from_relu,
    input  wire [295:0] from_latch_array,
    output wire [15:0]  vec_max_wire
);

    reg [15:0] vec_max;
    integer i;

    assign vec_max_wire = vec_max;

    always@(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vec_max <= 0;
        end
        // else if ()
        else if (latch_en) begin
            for (i = 0; i < 16; i = i + 1) begin
                if (from_latch_array[(i * 16) +: 16] > vec_max) begin
                    vec_max <= from_latch_array[(i * 16) +: 16];
                end
            end
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
    input wire [15:0] vec_max_wire,
    output wire [15:0] reciprocal_wire,
    output wire reciprocal_done_wire
);

    reg [39:0] reciprocal;
    reg reciprocal_done;
    assign reciprocal_wire = reciprocal;
    assign reciprocal_done_wire = reciprocal_done;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reciprocal <= 0;
            reciprocal_done <= 1'b0;
        end
        else if (latch_done) begin
            reciprocal <= (vec_max_wire == 0) ? 18'hffff : (255 << 6)/ vec_max_wire;
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
    input  wire [15:0]   vec_max_wire,
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

`endif