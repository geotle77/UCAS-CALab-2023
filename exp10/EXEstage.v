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
  
  output wire data_sram_en,
  output wire [3:0] data_sram_we,
  output wire [31:0] data_sram_addr,
  output wire [31:0] data_sram_wdata,


  output reg [4:0] exe_dest,
  output wire [31:0] alu_result,
  
  output wire exe_rf_we,
  output reg es_inst_is_ld_w,
  input wire inst_ld_w,
  
  input wire res_from_mul,
  output reg exe_res_from_mul
);


//////////zip//////////
wire [31:0] ds_pc;
wire [31:0] alu_src1;
wire [31:0] alu_src2;
wire [11:0] alu_op;
wire [31:0] rkd_value;
wire res_from_mem;
wire gr_we;
wire [4:0] dest;
wire mem_we;
assign {ds_pc, alu_src1, alu_src2, alu_op, rkd_value, res_from_mem, gr_we, dest, mem_we} = ds2es_bus;

reg [31:0] es_pc;
reg exe_res_from_mem;
assign es2ms_bus = {es_pc, alu_result, exe_res_from_mem, exe_dest, exe_gr_we};


//////////declaration////////

reg es_valid;
reg exe_gr_we;

reg        mem_we_reg;
reg [31:0] alu_src1_reg;
reg [31:0] alu_src2_reg;
reg [11:0] alu_op_reg;
reg [31:0] rkd_value_reg;


//////////pipeline////////
wire es_ready_go;

assign es_ready_go = alu_flag;
assign es_allowin = ~es_valid || es_ready_go && ms_allowin;
assign es2ms_valid = es_valid && es_ready_go;


always @(posedge clk) begin
  if (reset) begin
    es_valid <= 1'b0;
  end else if (es_allowin) begin
    es_valid <= ds2es_valid;
  end
  
  if(ds2es_valid && es_allowin)begin
    es_pc <= ds_pc;
    alu_src1_reg <= alu_src1;
    alu_src2_reg <= alu_src2;
    alu_op_reg   <= alu_op;
    rkd_value_reg  <= rkd_value;
    exe_res_from_mem  <= res_from_mem;
    exe_gr_we         <= gr_we;
    exe_dest          <= dest;
    mem_we_reg <= mem_we;
    
    exe_res_from_mul <= res_from_mul;
  end
end


always @(posedge clk)begin
    if(ds2es_valid && es_allowin)begin
        if(inst_ld_w)begin
            es_inst_is_ld_w <= 1'b1;
        end
        else begin
            es_inst_is_ld_w <= 1'b0;
        end
    end
end


//////////assign//////////

alu u_alu(
    .clk        (clk        ),
    .resetn     (resetn     ),
    .alu_op     (alu_op_reg    ),
    .alu_src1   (alu_src1_reg  ),
    .alu_src2   (alu_src2_reg  ),
    .alu_flag   (alu_flag),
    .alu_result (alu_result)
    );
    
assign exe_rf_we = es_valid && exe_gr_we;
    
assign data_sram_en    = mem_we_reg || exe_res_from_mem;//1'b1;
assign data_sram_we    = {4{mem_we_reg && es_valid}};
assign data_sram_addr  = alu_result;
assign data_sram_wdata = rkd_value_reg;


endmodule
