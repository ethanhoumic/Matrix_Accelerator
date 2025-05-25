`timescale 1 ns/1 ps
`ifndef MAC_16
`define MAC_16

module mac_16 #(
    parameter CALC_BIT_WIDTH, // Width of the counter
    parameter CALC_COUNT   // Number of cycles for the calculation
)(
    input  wire          clk,
    input  wire          rst_n,
    input  wire [4223:0] a_vec,
    input  wire [263:0]  b_vec,
    input  wire          is_int8_mode,
    input  wire          is_int4_mode,
    input  wire          is_vsq,
    input  wire          valid,
    input  wire [383:0]  partial_sum_in,
    output wire [383:0]  partial_sum_out,
    output wire          mac_done_wire,
    output wire          calc_done_wire
);
    reg mac_done;
    reg calc_done;
    reg [CALC_BIT_WIDTH:0] calc;
    reg state;
    assign mac_done_wire = mac_done;
    assign calc_done_wire = calc_done;

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin: mac_units
            MAC_datapath mac_inst(
                .a_vec(a_vec[i * 264  + 263 -: 264]),
                .b_vec(b_vec),
                .is_int8_mode(is_int8_mode),
                .is_int4_mode(is_int4_mode),
                .is_vsq(is_vsq),
                .partial_sum_in(partial_sum_in[i * 24 + 23 -: 24]),
                .partial_sum_out(partial_sum_out[i * 24 + 23 -: 24])
            );
        end
    endgenerate

    localparam IDLE = 0, CALC = 1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            calc <= 0;
            state <= IDLE;
            mac_done <= 0;
            calc_done <= 0;
        end
        else begin
            if (calc == CALC_COUNT - 1) begin
                state <= IDLE;
                calc <= 0;
                calc_done <= 1; // Signal that calculation is done
                mac_done <= 0; // Reset mac_done for the next cycle
            end
            else if (state == IDLE && valid) begin
                state <= CALC;
                mac_done <= 1;
            end
            else if (state == CALC) begin
                calc <= calc + 1; // Increment the counter
            end
            else begin
                state <= state;
                calc <= calc;
            end
        end
    end

endmodule

`endif

`ifndef MAC_DATAPATH
`define MAC_DATAPATH

module MAC_datapath (
    input  wire [263:0] a_vec,
    input  wire [263:0] b_vec,
    input  wire is_int8_mode,
    input  wire is_int4_mode,
    input  wire is_vsq,
    input  wire [23:0] partial_sum_in,
    output wire [23:0] partial_sum_out
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
    );

    assign partial_sum_out = is_int8_mode ? partial_sum_int8 :
                             is_int4_mode ? partial_sum_int4 :
                             is_vsq       ? partial_sum_vsq  :
                                          24'b0;

endmodule

`endif

`ifndef ACC_COLLECTOR
`define ACC_COLLECTOR

module acc_collector (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire         ppu,            // all MAC done
    input  wire         mac_done,       // MAC one calculation done
    input  wire [383:0] partial_sum_in,
    output wire [383:0] to_mac,
    output wire [383:0] to_ppu,
    output wire         done_wire       // PPU done
);

    reg [383:0] latch_array [0:15];
    reg [3:0]   addr;
    reg [1:0]   state;
    reg         done;

    assign done_wire = done;

    localparam IDLE = 2'b00,
               MAC  = 2'b01,
               PPU  = 2'b10;

    assign to_mac = (state == MAC) ? latch_array[addr] : 384'b0;
    assign to_ppu = (state == PPU) ? latch_array[addr] : 384'b0;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr  <= 0;
            state <= IDLE;
            done  <= 0;
            for (i = 0; i < 16; i = i + 1)
                latch_array[i] <= 384'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= MAC;
                        addr  <= 0;
                    end
                end

                MAC: begin
                    if (mac_done) begin
                        latch_array[addr] <= partial_sum_in;
                        addr <= (addr == 15) ? 0 : addr + 1;
                    end

                    if (ppu) begin
                        state <= PPU;
                        addr  <= 0;
                    end
                end

                PPU: begin
                    if (addr == 15) begin
                        state <= IDLE;
                        addr  <= 0;
                        done  <= 1; // Signal that PPU is done
                    end 
                    else begin
                        addr <= addr + 1;
                    end
                end
            endcase
        end
    end

endmodule

`endif