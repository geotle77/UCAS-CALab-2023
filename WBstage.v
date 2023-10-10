module WBstage (
  input wire clk,
  input wire resetn,
  input wire reset,
  input wire [31:0] data_sram_rdata,
  input wire mem_gr_we,
  input wire [4:0] mem_dest,
  input wire [31:0] mem_alu_result,
  input wire [31:0] mem_res_from_mem,

  output wire rf_we,
  output wire [4:0] rf_waddr,
  output wire [31:0] rf_wdata,

  output wire [31:0] debug_wb_pc,
  output wire [3:0] debug_wb_rf_we,
  output wire [4:0] debug_wb_rf_wnum,
  output wire [31:0] debug_wb_rf_wdata,

  input wire [31:0] ms_pc,
  input wire ms_valid,
  output reg [31:0] ws_pc,
  output reg ws_valid,
  

  input wire ms_allowin,
  output wire ws_allowin,
  input wire es2ms_valid,
  output wire ms2ws_valid,
  
  output reg gr_we_reg,
  output reg [4:0] dest_reg,
  
  //output wire [31:0] final_result
  
  input wire [31:0] final_result
  //input wire [31:0] mem_result
);


//////////declaration////////

reg [31:0] data_sram_rdata_reg;
//reg gr_we_reg;
//reg [4:0] dest_reg;
reg [31:0] alu_result_reg;
reg [31:0] res_from_mem_reg;


//wire [31:0] mem_result;
// wire [31:0] final_result;
//wire rf_we;
//wire [ 4:0] rf_waddr;
//wire [31:0] rf_wdata;

  reg [31:0] final_result_reg;
  //reg [31:0] mem_result_reg;


//////////pipeline//////////
wire ws_ready_go;


assign ws_ready_go = 1'b1;
assign ws_allowin = ~ws_valid || ws_ready_go;

always @(posedge clk) begin
  if (reset) begin
    ws_valid <= 1'b0;
  end else if (ws_allowin) begin
    ws_valid <= ms2ws_valid;
  end
  
  if(ms2ws_valid && ws_allowin)begin
    ws_pc <= ms_pc;
    data_sram_rdata_reg <= data_sram_rdata;
    gr_we_reg <= mem_gr_we;
    dest_reg <= mem_dest;
    alu_result_reg <= mem_alu_result;
    res_from_mem_reg <= mem_res_from_mem;
    final_result_reg <= final_result;
    //mem_result_reg <= mem_result;
  end
end

//////////assign//////////


//assign mem_result = data_sram_rdata_reg;
//assign final_result = res_from_mem_reg ? mem_result : alu_result_reg;

assign rf_we = gr_we_reg && ws_valid;
assign rf_waddr = dest_reg;
assign rf_wdata = final_result_reg;

assign debug_wb_pc = ws_pc;
assign debug_wb_rf_we = {4{rf_we}};
assign debug_wb_rf_wnum = dest_reg;
assign debug_wb_rf_wdata = final_result_reg;

endmodule
