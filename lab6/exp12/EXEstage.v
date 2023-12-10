`include "BUS_LEN.vh"
module EXEstage (
  input wire clk,
  input wire resetn,
  input wire reset,
  
  input wire ms_allowin,
  output wire es_allowin,
  input wire ds2es_valid,
  output wire es2ms_valid,
  
  input wire [`DS2ES_BUS_LEN-1:0] ds2es_bus,
  output wire [`ES2MS_BUS_LEN-1:0] es2ms_bus,
  output wire [`FORWARD_BUS_LEN-1:0]   exe_forward_zip,
  
  output wire data_sram_en,
  output wire [3:0] data_sram_we,
  output wire [31:0] data_sram_addr,
  output wire [31:0] data_sram_wdata,

  output reg es_block,
  input wire block,
  
  input wire res_from_mul,
  output reg exe_res_from_mul,
  output [67:0] mul_result,

  input wire ms_ex,
  input wire wb_ex,
  output wire es_csr_re
);


//////////zip//////////
wire [4:0]  load_op;
wire [2:0]  store_op;
wire [31:0] ds_pc;
wire [31:0] alu_src1;
wire [31:0] alu_src2;
wire [15:0] alu_op;
wire [2:0]  mul_op;
wire [31:0] rkd_value;
wire gr_we;
wire [4:0] dest;
wire [`EXCEPT_LEN-1 : 0] except_zip;
assign {ds_pc, alu_src1, alu_src2, alu_op, mul_op,  load_op, store_op, rkd_value, gr_we, dest, except_zip} = ds2es_bus;
reg [4:0] exe_dest;
wire [31:0] alu_result;
wire exe_rf_we;
assign exe_forward_zip={exe_rf_we, exe_dest, alu_result};
reg [31:0] es_pc;
wire [4:0] exe_load_op;
reg [15:0] alu_op_reg;
reg [2:0]  mul_op_reg;
reg exe_gr_we;
reg [`EXCEPT_LEN-1 : 0] exe_except_zip;
assign es2ms_bus = {es_pc, mul_op_reg, alu_result, exe_load_op, exe_dest, exe_gr_we,exe_except_zip};
//////////declaration////////

reg es_valid;

wire        mem_we;
reg [31:0] alu_src1_reg;
reg [31:0] alu_src2_reg;

reg [4:0]  load_op_reg;
reg [2:0]  store_op_reg;
reg [31:0] rkd_value_reg;

wire alu_flag;

//////////pipeline////////
wire es_ready_go;

assign es_ready_go = alu_flag;
assign es_allowin = ~es_valid || es_ready_go && ms_allowin;
assign es2ms_valid = es_valid && es_ready_go;


always @(posedge clk) begin
  if (reset) begin
    es_valid <= 1'b0;
  end 
  else if(wb_ex) begin
    es_valid <= 1'b0;
  end else if (es_allowin) begin
    es_valid <= ds2es_valid;
  end
  
  if(ds2es_valid && es_allowin)begin
    es_pc <= ds_pc;
    alu_src1_reg <= alu_src1;
    alu_src2_reg <= alu_src2;
    alu_op_reg   <= alu_op;
    mul_op_reg  <=mul_op;
    load_op_reg <= load_op;
    store_op_reg <= store_op;
    rkd_value_reg <= rkd_value;
    exe_gr_we     <= gr_we;
    exe_dest          <= dest;
    exe_res_from_mul <= res_from_mul;
    exe_except_zip <= except_zip;
  end
end

always @(posedge clk)begin
    if(ds2es_valid && es_allowin)begin
        if(block)begin
            es_block <= 1'b1;
        end
        else begin
            es_block <= 1'b0;
        end
    end
end
//////////assign//////////


assign es_csr_re = exe_except_zip[1];



alu u_alu(
    .clk        (clk        ),
    .resetn     (resetn     ),
    .alu_op     (alu_op_reg    ),
    .alu_src1   (alu_src1_reg  ),
    .alu_src2   (alu_src2_reg  ),
    .alu_flag   (alu_flag),
    .alu_result (alu_result)
    );
    
wire [31:0] st_data;
wire [3:0] st_strb;
wire [3:0] st_sel;

decoder_2_4 u_dec_st(.in(alu_result[1:0]), .out(st_sel));

assign st_strb = {4{store_op_reg[0]}} &  st_sel
               | {4{store_op_reg[1]}} & (st_sel[0] ? 4'b0011 : 4'b1100)
               | {4{store_op_reg[2]}} &  4'b1111;

assign st_data = {32{store_op_reg[0]}} & {4{rkd_value_reg[7:0]}}
               | {32{store_op_reg[1]}} & {2{rkd_value_reg[15:0]}}
               | {32{store_op_reg[2]}} & rkd_value_reg;
assign mem_we=(|store_op_reg);

assign exe_rf_we = es_valid && exe_gr_we;
assign exe_load_op =load_op_reg;
assign data_sram_en    =  ((|exe_load_op)|mem_we) & es_valid;//1'b1;
assign data_sram_we    =  {4{es_valid & ~wb_ex & ~ms_ex}} & mem_we ? st_strb : 4'b0;
assign data_sram_addr  =  alu_result;
assign data_sram_wdata =  st_data;
//mul_src
wire  [33:0]  mul_src1;
wire  [33:0]  mul_src2;
assign mul_src1 = {{2{alu_src1_reg[31] & ~mul_op_reg[2]}}, alu_src1_reg[31:0]};
assign mul_src2 = {{2{alu_src2_reg[31] & ~mul_op_reg[2]}}, alu_src2_reg[31:0]};

booth_multiplier u_mul(
  .clk(clk),
  .x(mul_src1),
  .y(mul_src2),
  .z(mul_result)
);
endmodule