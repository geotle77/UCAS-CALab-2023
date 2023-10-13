module WBstage (
  input wire clk,
  input wire resetn,
  input wire reset,
  
  input wire ms_allowin,
  output wire ws_allowin,
  input wire es2ms_valid,
  output wire ms2ws_valid,
  
  input wire [69:0] ms2ws_bus,  
  output wire [37:0] rf_zip,

  output wire [31:0] debug_wb_pc,
  output wire [3:0] debug_wb_rf_we,
  output wire [4:0] debug_wb_rf_wnum,
  output wire [31:0] debug_wb_rf_wdata,


  output reg ws_valid,
  output reg gr_we_reg,
  output reg [4:0] dest_reg

);



//////////zip//////////
wire rf_we;
wire [4:0] rf_waddr;
wire [31:0] rf_wdata;
assign rf_zip = {rf_we, rf_waddr, rf_wdata};

wire [31:0] ms_pc;
wire mem_gr_we;
wire [4:0] mem_dest;
wire [31:0] final_result;
assign {ms_pc, mem_gr_we, mem_dest, final_result} = ms2ws_bus;

//////////declaration////////


reg [31:0] ws_pc;
reg [31:0] alu_result_reg;
reg [31:0] res_from_mem_reg;
reg [31:0] final_result_reg;

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
    gr_we_reg <= mem_gr_we;
    dest_reg <= mem_dest;
    final_result_reg <= final_result;
  end
end

//////////assign//////////


assign rf_we = gr_we_reg && ws_valid;
assign rf_waddr = dest_reg;
assign rf_wdata = final_result_reg;

assign debug_wb_pc = ws_pc;
assign debug_wb_rf_we = {4{rf_we}};
assign debug_wb_rf_wnum = dest_reg;
assign debug_wb_rf_wdata = final_result_reg;

endmodule
