module MEMstage (
  input wire clk,
  input wire resetn,
  input wire reset,
  input wire [31:0] alu_result,
  input wire [31:0] exe_res_from_mem,
  input wire [4:0] exe_dest,
  input wire exe_gr_we,
  
  output wire [31:0] data_sram_rdata,
  output reg mem_gr_we,
  output reg [4:0] mem_dest,
  output reg [31:0] mem_alu_result,
  output reg [31:0] mem_res_from_mem,
  
  input wire [31:0] es_pc,
  input wire es_valid,
  output reg [31:0] ms_pc,
  output reg ms_valid,
  
  
  input wire ws_allowin,
  output wire ms_allowin,
  input wire es2ms_valid,
  output wire ms2ws_valid,
  
  output wire [31:0] final_result
  //output wire [31:0] mem_result
);


//////////declaration//////////

//reg [31:0] mem_alu_result;
//reg [31:0] mem_res_from_mem;
//reg [4:0]  mem_dest;
//reg        mem_gr_we;
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


endmodule


//////////others//////////

