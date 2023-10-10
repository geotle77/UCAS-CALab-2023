module MEMstage (
  input wire clk,
  input wire resetn,
  input wire reset,
  
  input wire es_valid,
  output reg ms_valid,
  input wire ws_allowin,
  output wire ms_allowin,
  input wire es2ms_valid,
  output wire ms2ws_valid,
  
  input wire [101:0] es2ms_bus,
//  input wire [31:0] es_pc,
//  input wire [31:0] alu_result,
//  input wire [31:0] exe_res_from_mem,
//  input wire [4:0] exe_dest,
//  input wire exe_gr_we,
  

  
  output wire [165:0] ms2ws_bus,
//  output reg [31:0] ms_pc,
//  output reg mem_gr_we,
//  output reg [4:0] mem_dest,
//  output reg [31:0] mem_alu_result,
//  output reg [31:0] mem_res_from_mem,
//  output wire [31:0] final_result,
//  output wire [31:0] data_sram_rdata,
  


  
  output [38:0] mem_forward
  
  
  //output wire [31:0] mem_result
);

//////////zip//////////
wire [31:0] es_pc;
wire [31:0] alu_result;
wire [31:0] exe_res_from_mem;
wire [4:0] exe_dest;
wire exe_gr_we;


reg [31:0] ms_pc;
wire [31:0] final_result;
wire [31:0] data_sram_rdata;






//////////declaration//////////

reg [31:0] mem_alu_result;
reg [31:0] mem_res_from_mem;
reg [4:0]  mem_dest;
reg        mem_gr_we;
wire [31:0] mem_result;

//////////pipeline//////////
wire ms_ready_go;

assign ms_ready_go = 1'b1;
assign ms_allowin = ~ms_valid || ms_ready_go && ws_allowin;
assign ms2ws_valid = ms_valid && ms_ready_go;

always @(posedge clk) begin
  if (reset) begin
    ms_valid <= 1'b0;
  end else if (ms_allowin) begin
    ms_valid <= es2ms_valid;
  end
  
  if(es2ms_valid && ms_allowin)begin
    ms_pc <= es_pc;
    mem_alu_result <= alu_result;
    mem_res_from_mem <= exe_res_from_mem;
    mem_dest <= exe_dest;
    mem_gr_we <= exe_gr_we;
  end
end




assign mem_result = data_sram_rdata;
assign final_result = mem_res_from_mem ? mem_result : mem_alu_result;



///////////////
assign {es_pc, alu_result, exe_res_from_mem, exe_dest,exe_gr_we} = es2ms_bus;
assign ms2ws_bus = {ms_pc, mem_gr_we, mem_dest, mem_alu_result, mem_res_from_mem, final_result, data_sram_rdata};
assign mem_forward = {ms_valid, mem_gr_we, mem_dest, final_result};






endmodule


//////////others//////////

