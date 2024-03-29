module MEMstage (
  input wire clk,
  input wire resetn,
  input wire reset,
  input wire [31:0] data_sram_rdata,
  
  input wire ws_allowin,
  output wire ms_allowin,
  input wire es2ms_valid,
  output wire ms2ws_valid,
  
  input wire [`ES2MS_BUS_LEN-1:0] es2ms_bus,
  output wire [`MS2WS_BUS_LEN-1:0] ms2ws_bus,

  output wire mem_rf_we,
  output reg [4:0] mem_dest,
  output wire [31:0] final_result,
  
  input wire exe_res_from_mul,
  input [67:0] mul_result
);


//////////zip//////////
wire [31:0] es_pc;
wire [18:0]es_alu_op;
wire [31:0] alu_result;
wire exe_res_from_mem;
wire [4:0] exe_dest;
wire exe_gr_we;
assign {es_pc,es_alu_op, alu_result, exe_res_from_mem, exe_dest, exe_gr_we} = es2ms_bus;

reg [31:0] ms_pc;
reg mem_gr_we;
assign ms2ws_bus = {ms_pc, mem_gr_we, mem_dest, final_result};


//////////declaration//////////

reg [18:0] mem_alu_op;
reg [31:0] mem_alu_result;
reg mem_res_from_mem;
wire [31:0]mem_result;
wire [31:0]mem_mul_result;

reg ms_valid;

reg res_from_mul_reg;

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
    mem_alu_op<=es_alu_op;
    mem_alu_result <= alu_result;
    mem_res_from_mem <= exe_res_from_mem;
    mem_dest <= exe_dest;
    mem_gr_we <= exe_gr_we;
    res_from_mul_reg <= exe_res_from_mul;
  end
end


assign mem_rf_we = ms_valid && mem_gr_we;

assign mem_result = data_sram_rdata;
assign mem_mul_result =   ({32{mem_alu_op[12]           }} & mul_result[31:0])
                    | ({32{mem_alu_op[13]|mem_alu_op[14]}} & mul_result[63:32]);
assign final_result = mem_res_from_mem ? mem_result : 
                      res_from_mul_reg?  mem_mul_result :
                                         mem_alu_result ;
                      

endmodule
