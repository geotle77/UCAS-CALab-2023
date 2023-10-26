module WBstage (
  input wire clk,
  input wire resetn,
  input wire reset,
  
  input wire ms_allowin,
  output wire ws_allowin,
  input wire es2ms_valid,
  output wire ms2ws_valid,
  
  input wire [`MS2WS_BUS_LEN-1:0] ms2ws_bus,  
  output wire [`MS2WS_BUS_LEN-1:0] rf_zip,

  output wire [31:0] debug_wb_pc,
  output wire [3:0] debug_wb_rf_we,
  output wire [4:0] debug_wb_rf_wnum,
  output wire [31:0] debug_wb_rf_wdata,

  output reg ws_valid,
  output wire csr_re,
  output wire [13:0] csr_num,
  input  wire [31:0] csr_rvalue,
  output wire csr_we,
  output wire [31:0] csr_wmask,
  output wire [31:0] csr_wvalue,
  output wire ertn_flush,
  output wire wb_ex,
  output reg  [31:0] ws_pc,
  output wire [ 5:0] wb_ecode,
  output wire [ 8:0] wb_esubcode
);

//////////zip//////////
wire rf_we;
wire [4:0] rf_waddr;
wire [31:0] rf_wdata;
assign rf_zip = {rf_we, rf_waddr, rf_wdata};

wire [31:0] ms_pc;
wire mem_gr_we;
wire [4:0] mem_dest;
reg  [4:0] dest_reg;
wire [31:0] final_result;
wire [`EXCEPT_LEN-1 : 0] except_zip;
assign {ms_pc, mem_gr_we, mem_dest, final_result, except_zip} = ms2ws_bus;

//////////declaration////////
reg [31:0] ws_pc;
reg [31:0] final_result_reg;
reg gr_we_reg;
reg [`EXCEPT_LEN-1 : 0] wb_except_zip;
//////////pipeline//////////
wire ws_ready_go;


assign ws_ready_go = 1'b1;
assign ws_allowin = ~ws_valid || ws_ready_go;

always @(posedge clk) begin
  if (reset) begin
    ws_valid <= 1'b0;
  end 
  else if (wb_ex | ertn_flush) begin
    ws_valid <= 1'b0;
  end
  else if (ws_allowin) begin
    ws_valid <= ms2ws_valid;
  end
  
  if(ms2ws_valid && ws_allowin)begin
    ws_pc <= ms_pc;
    gr_we_reg <= mem_gr_we;
    dest_reg <= mem_dest;
    final_result_reg <= final_result;
    wb_except_zip <= except_zip;
  end
end

assign {csr_num, csr_wmask, csr_wvalue, wb_ex, ertn_flush, csr_re, csr_we} = wb_except_zip & {82{ws_valid}};    // wb_ex=inst_syscall, ertn_flush=inst_ertn
assign wb_ecode = {6{wb_ex}} & 6'hb;
assign wb_esubcode = 9'b0;
//////////assign//////////
assign rf_we = gr_we_reg && ws_valid;
assign rf_waddr = dest_reg;
assign rf_wdata = csr_re ? csr_rvalue : final_result_reg;

assign debug_wb_pc = ws_pc;
assign debug_wb_rf_we = {4{rf_we}};
assign debug_wb_rf_wnum = dest_reg;
assign debug_wb_rf_wdata = csr_re ? csr_rvalue : final_result_reg;

endmodule
