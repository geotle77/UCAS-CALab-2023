module MEMstage (
  input wire clk,
  input wire resetn,
  input wire reset,
  input wire [31:0] data_sram_rdata,
  
  input wire ws_allowin,
  output wire ms_allowin,
  input wire es2ms_valid,
  output wire ms2ws_valid,
  
  input wire [70:0] es2ms_bus,
  output wire [69:0] ms2ws_bus,

  output wire mem_rf_we,
  output reg [4:0] mem_dest,
  output wire [31:0] final_result,
  
  input wire exe_res_from_mul
);


//////////zip//////////
wire [31:0] es_pc;
wire [31:0] alu_result;
wire exe_res_from_mem;
wire [4:0] exe_dest;
wire exe_gr_we;
assign {es_pc, alu_result, exe_res_from_mem, exe_dest, exe_gr_we} = es2ms_bus;


reg [31:0] ms_pc;
assign ms2ws_bus = {ms_pc, mem_gr_we, mem_dest, final_result};


//////////declaration//////////


reg [31:0] mem_alu_result;
reg mem_res_from_mem;
wire [31:0] mem_result;

wire mem_rf_we;

reg ms_valid;
reg mem_gr_we;

reg res_from_mul_reg;

wire [31:0] mul_result;

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
    res_from_mul_reg <= exe_res_from_mul;
  end
end


assign mem_rf_we = ms_valid && mem_gr_we;

assign mem_result = data_sram_rdata;
assign mul_result = alu_result;
assign final_result = mem_res_from_mem ? mem_result : 
                      res_from_mul_reg? alu_result :
                                        mem_alu_result ;
                      


endmodule


//////////others//////////

