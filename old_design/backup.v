// module address_generator (
//     input wire clk,
//     input wire rst_n,
//     input wire is_a_buffer,
//     input wire start,
//     input wire [11:0] base_addr,
//     input wire [7:0] x_stride,
//     input wire [7:0] y_stride,
//     input wire [7:0] x_dim,
//     input wire [7:0] y_dim,
//     output reg [15:0] addr,
//     output reg [3:0] bank_num,
//     output reg valid
// );
//     reg [7:0] x_counter, y_counter;
//     reg running;

//     always @(posedge clk or negedge rst) begin
//         if (!rst_n) begin
//             addr <= {4'h0, base_addr};
//             x_counter <= 0;
//             y_counter <= 0;
//             bank_num <= 0;
//             valid <= 0;
//             running <= 0;
//         end
//         else begin
//             if (start && !running) begin
//                 addr <= {4'h0, base_addr};
//                 x_counter <= 0;
//                 y_counter <= 0;
//                 bank_num <= 0;
//                 valid <= 1;
//                 running <= 1;
//             end
//             else if (running) begin
//                 if (x_counter < x_dim - 1) begin
//                     x_counter <= x_counter + 1;
//                     addr <= addr + {8'h0, x_stride};
//                     valid <= 1;
//                 end
//                 else if (y_counter < y_dim - 1) begin
//                     x_counter <= 0;
//                     y_counter<= y_counter + 1;
//                     if (is_a_buffer) begin
//                         bank_num <= (bank_num + 1) % 16;
//                         addr <= {4'h0, base_addr} + {8'h0, y_counter + 1} * {8'h0, y_stride};
//                     end
//                     else begin
//                         addr <= {4'h0, base_addr} + {8'h0, y_counter + 1} * {8'h0, y_stride};
//                     end
//                     valid <= 1;
//                 end
//                 else begin
//                     valid <= 0;
//                     running <= 0;
//                 end
//             end
//             else begin
//                 valid <= 0;
//             end
//         end
//     end
    
// endmodule

// module control_unit (
//     input wire clk, 
//     input wire rst_n,
//     input wire [32:0] config_in,
//     input wire start,
//     input wire done,

//     output reg a_buf_start,
//     output reg [11:0] a_base_addr,
//     output reg [7:0] a_x_stride,
//     output reg [7:0] a_y_stride,
//     output reg [7:0] a_x_dim,
//     output reg [7:0] a_y_dim,
//     output reg a_buf_en,

//     output reg b_buf_start,
//     output reg [11:0] b_base_addr,
//     output reg [7:0] b_x_stride,
//     output reg [7:0] b_y_stride,
//     output reg [7:0] b_x_dim,
//     output reg [7:0] b_y_dim,
//     output reg b_buf_en,

//     output reg mac_precision,
//     output reg vsq_en,
//     output reg busy, 
//     output reg operation_done,
// );

//     localparam IDLE = 3'b000;
//     localparam CONFIGURE = 3'b001;
//     localparam INIT_BUFFER = 3'b010;
//     localparam RUNNING = 3'b011;
//     localparam COMPLETE = 3'b100;

//     reg [2:0] current_state, next_state;
//     reg [7:0] cycle_counter;
//     reg [7:0] a_update_counter;
//     reg [31:0] config_reg;

//     always @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin
//             current_state <= IDLE;
//         end
//         else begin
//             current_state <= next_state;
//         end
//     end

//     always @(*) begin
//         case (current_state)
//             IDLE: begin
//                 if (start) next_state = CONFIGURE;
//                 else next_state = IDLE;
//             end 
//             CONFIGURE: next_state = INIT_BUFFER;
//             INIT_BUFFER: next_state <= RUNNING;
//             RUNNING: begin
//                 if (done) next_state = COMPLETE;
//                 else next_state = RUNNING;
//             COMPLETE: next_state = IDLE;
//             end
//             default: next_state = IDLE;
//         endcase
//     end

//     always @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin
//             a_buf_start <= 0;
//             a_base_addr <= 0;
//             a_x_stride <= 0;
//             a_y_stride <= 0;
//             a_x_dim <= 0;
//             a_y_dim <= 0;
//             a_buf_en <= 0;

//             b_buf_start <= 0;
//             b_base_addr <= 0;
//             b_x_stride <= 0;
//             b_y_stride <= 0;
//             b_x_dim <= 0;
//             b_y_dim <= 0;
//             b_buf_en <= 0;

//             mac_precision <= 0;
//             vsq_en <= 0;
//             busy <= 0;
//             operation_done <= 0;

//         end
//         else begin
//             case (current_state)
//                 IDLE: begin
//                     a_buf_start <= 0;
//                     b_buf_start <= 0;
//                     a_buf_en <= 0;
//                     b_buf_en <= 0;
//                     busy <= 0;
//                     operation_done <= 0;
//                     cycle_counter <= 0;
//                     a_update_counter <= 0;

//                     if (start) config_reg <= config_in;
//                 end 

//                 CONFIGURE: begin
//                     busy <= 1;
//                     a_base_addr <= config_reg[11:0];
//                     a_stride_x <= config_reg[19:12];
//                     a_stride_y <= config_reg[27:20];
//                     a_dim_x <= config_reg[7:0];                  
//                     a_dim_y <= config_reg[15:8];                 
                    
//                     b_base_addr <= config_reg[11:0];             
//                     b_stride_x <= config_reg[19:12];             
//                     b_stride_y <= config_reg[27:20];             
//                     b_dim_x <= config_reg[7:0];                  
//                     b_dim_y <= config_reg[15:8];                 
                    
//                     mac_precision <= config_reg[29:28];          
//                     vsq_enable <= config_reg[30];                
//                     mac_mode <= config_reg[27:24];               
//                 end

//                 default: 
//             endcase
//         end
//     end

// endmodule

// module a_sram #(
//     parameter ADDR_WIDTH = 7,
//     parameter DATA_WIDTH = 264
// )(
//     input wire clk,
//     input wire rst_n,
//     input wire write_en,
//     input wire [6:0] addr,
//     input wire [DATA_WIDTH - 1:0] data_in,
//     output reg [DATA_WIDTH - 1:0] data_out
// );

//     reg [DATA_WIDTH - 1:0] mem [0:(1 << ADDR_WIDTH) - 1];
//     integer i;

//     always @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin
//             for (i = 0; i < 1 << ADDR_WIDTH; i = i + 1) begin
//                 mem[i] <= 0;
//             end
//             data_out <= 0;
//         end
//         else if (write_en) begin
//             mem[addr] <= data_in;
//         end
//         else begin
//             data_out <= mem[addr];
//         end
//     end

// endmodule