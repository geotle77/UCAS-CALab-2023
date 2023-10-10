module EXEstage (
  input wire clk,
  input wire resetn,
  input wire reset,
  input wire [31:0] alu_src1,
  input wire [31:0] alu_src2,
  input wire [11:0] alu_op,
  input wire [31:0] rkd_value,
  input wire [31:0] res_from_mem,
  input wire gr_we,
  input wire [4:0] dest,
  input wire mem_we,
  
  output wire [31:0] alu_result,
  output reg [31:0] exe_res_from_mem,
  output reg [4:0] exe_dest,
  output reg exe_gr_we,
  
  output wire data_sram_en,
  output wire [3:0] data_sram_we,
  output wire [31:0] data_sram_addr,
  output wire [31:0] data_sram_wdata,
  input wire [31:0] data_sram_rdata,
  
  input wire [31:0] ds_pc,
  input wire ds_valid,
  output reg [31:0] es_pc,
  output reg es_valid,
  
  
  input wire ms_allowin,
  output wire es_allowin,
  input wire ds2es_valid,
  output wire es2ms_valid,
  
  output reg es_inst_is_ld_w,
  input wire inst_ld_w
);


//////////declaration////////

reg        mem_we_reg;
reg [31:0] alu_src1_reg;
reg [31:0] alu_src2_reg;
reg [11:0] alu_op_reg;
reg [31:0] rkd_value_reg;
//reg [31:0] exe_res_from_mem;
//reg        exe_gr_we;
//reg [31:0] exe_dest;


//////////pipeline////////
wire es_ready_go;

assign es_ready_go = 1'b1;
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
    .alu_op     (alu_op_reg    ),
    .alu_src1   (alu_src1_reg  ),
    .alu_src2   (alu_src2_reg  ),
    .alu_result (alu_result)
    );
    
    
assign data_sram_en    = mem_we_reg || exe_res_from_mem;//1'b1;
assign data_sram_we    = {4{mem_we_reg && es_valid}};
assign data_sram_addr  = alu_result;
assign data_sram_wdata = rkd_value_reg;


endmodule
