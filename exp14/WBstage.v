`include "BUS_LEN.vh"
module WBstage (
  input wire clk,
  input wire resetn,
  input wire reset,
  
  output wire ws_allowin,
  input wire ms2ws_valid,
  
  input wire [`MS2WS_BUS_LEN-1:0] ms2ws_bus,  
  output wire [`WB_RF_BUS-1:0] rf_zip,
  output wire [`WS2CSR_BUS_LEN-1 : 0] ws2csr_bus,

  output wire [31:0] debug_wb_pc,
  output wire [3:0] debug_wb_rf_we,
  output wire [4:0] debug_wb_rf_wnum,
  output wire [31:0] debug_wb_rf_wdata,
  
  output wire ws_ertn_flush,
  output wire ws_ex,
  input  wire [31:0] csr_rvalue,
  output wire ws_reflush
);

//////////zip//////////
wire rf_we;
wire [4:0] rf_waddr;
wire [31:0] rf_wdata;
assign rf_zip = {rf_we, rf_waddr, rf_wdata};

wire [31:0] ws_pc;
wire ws_gr_we;
wire [4:0] ws_dest;
wire [31:0] ws_final_result;
wire [`MS_EXC_DATA_WD -1 : 0] ws_exc_data;

reg  [`MS2WS_BUS_LEN -1 : 0] ms2ws_bus_reg;


wire ws_csr_re;
wire ws_csr_we;
wire [13:0] ws_csr_num;
wire [31:0] ws_csr_wmask;
wire [31:0] ws_csr_wvalue;
wire [ 5:0] ws_ecode;
wire [ 8:0] ws_esubcode;
wire [31: 0]ws_wrong_addr;
wire [31: 0]ws_rkd_value;
// exp13
wire  [ 7:0] ws_hw_int_in  = 8'b0 ;
wire         ws_ipi_int_in = 1'b0 ;
wire  [31:0] ws_coreid_in  = 32'b0;
assign ws2csr_bus = {ws_csr_re, ws_csr_we, ws_csr_num, ws_csr_wmask, ws_csr_wvalue, ws_pc, ws_ecode, ws_esubcode,ws_ipi_int_in,ws_coreid_in,ws_hw_int_in,ws_wrong_addr};
assign {ws_pc, ws_gr_we, ws_dest, ws_final_result,ws_rkd_value, ws_exc_data} = ms2ws_bus_reg;
//////////declaration////////
reg ws_valid;
//////////pipeline//////////
wire ws_ready_go;

assign ws_ready_go = 1'b1;
assign ws_allowin = ~ws_valid || ws_ready_go;

always @(posedge clk) begin
  if (reset) begin
    ws_valid <= 1'b0;
  end 
  else if (ws_ex | ws_ertn_flush) begin
    ws_valid <= 1'b0;
  end
  else if (ws_allowin) begin
    ws_valid <= ms2ws_valid;
  end
  
  if(ms2ws_valid && ws_allowin)begin
    ms2ws_bus_reg <= ms2ws_bus;
  end
end

assign {ws_wrong_addr,    
        ws_csr_we,
        ws_csr_wmask,        
        ws_csr_num,       
        ws_ertn_flush,  
        ws_ex,           
        ws_esubcode,     
        ws_ecode,
        ws_csr_re       
      }  = ws_exc_data & {`MS_EXC_DATA_WD {ws_valid}};    // wb_ex=inst_syscall, ertn_flush=inst_ertn
assign ws_csr_wvalue = ws_rkd_value;


assign ws_reflush = ws_ertn_flush | ws_ex;

//////////assign//////////
assign rf_we = ws_gr_we && ws_valid && ~ws_ex;
assign rf_waddr = ws_dest;
assign rf_wdata = ws_csr_re ? csr_rvalue : ws_final_result;

assign debug_wb_pc = ws_pc;
assign debug_wb_rf_we = {4{rf_we}};
assign debug_wb_rf_wnum = ws_dest;
assign debug_wb_rf_wdata = ws_csr_re ? csr_rvalue : ws_final_result;

endmodule
