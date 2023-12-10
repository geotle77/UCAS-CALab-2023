`include "BUS_LEN.vh"
module MEMstage (
  input wire clk,
  input wire resetn,
  input wire reset,

  input  wire [31:0] data_sram_rdata,
  input  wire data_sram_data_ok,
  
  input wire ws_allowin,
  output wire ms_allowin,
  input wire es2ms_valid,
  output wire ms2ws_valid,
  
  input wire [`ES2MS_BUS_LEN-1:0] es2ms_bus,
  output wire [`MS2WS_BUS_LEN-1:0] ms2ws_bus,
  output wire [`FORWARD_BUS_LEN-1:0] mem_forward_zip,
  
  input [67:0] mul_result,

  output wire ms_ex_to_es,
  output wire ms_mem_block,
  input wire ms_reflush,
  output wire ms_csr_re
);


//////////zip//////////
wire [31:0] ms_pc;
wire [31:0] mem_alu_result;
wire [4:0]  mem_dest;
wire [4:0]  mem_load_op;
wire [2:0]  mem_mul_op;
wire mem_gr_we;
wire mem_we;
wire mem_res_from_mem;
wire [31:0] mem_rkd_value;
wire [`ES_EXC_DATA_WD-1 : 0] mem_exc_data;
wire mem_res_from_mul;
reg[`ES2MS_BUS_LEN-1:0] es2ms_bus_reg;
assign {mem_we,
        mem_res_from_mem,
        ms_pc,
        mem_res_from_mul,
        mem_mul_op, 
        mem_alu_result, 
        mem_load_op, 
        mem_dest, 
        mem_gr_we,
        mem_rkd_value,
        mem_exc_data
        } = es2ms_bus_reg;

wire mem_rf_we;
wire [31:0] mem_final_result;
assign mem_forward_zip = {mem_rf_we, 
                          mem_dest, 
                          mem_final_result
                          };

assign ms2ws_bus = {ms_pc, 
                    mem_gr_we, 
                    mem_dest, 
                    mem_final_result, 
                    mem_rkd_value,
                    mem_exc_data};
//////////declaration//////////

wire [31:0]mem_result;
wire [31:0]mem_mul_result;

reg ms_valid;

//////////pipeline//////////
wire ms_ready_go;
wire ms_need_mem;
assign ms_need_mem = ms_valid && (mem_res_from_mem || mem_we);
assign ms_ready_go = ms_need_mem && data_sram_data_ok ||  ~ms_need_mem;
assign ms_allowin = ~ms_valid || ms_ready_go && ws_allowin;
assign ms2ws_valid = ms_valid && ms_ready_go;

always @(posedge clk) begin
  if (reset) begin
    ms_valid <= 1'b0;
  end 
  if (ms_reflush) begin
    ms_valid <= 1'b0;
  end
  else if (ms_allowin) begin
    ms_valid <= es2ms_valid;
  end
 
  if(es2ms_valid && ms_allowin)begin
    es2ms_bus_reg <= es2ms_bus;
  end
end


assign ms_csr_re = mem_exc_data[0];

assign ms_ex_to_es = (mem_ertn_flush | mem_ex) & ms_valid;

// exception
wire mem_csr_re;
wire mem_csr_we;
wire [31:0] mem_wrong_addr;
wire [13:0] mem_csr_num   ;
wire [31:0] mem_csr_wmask ;
wire        mem_ertn_flush;
wire        mem_ex        ;
wire [ 8:0] mem_esubcode  ;
wire [ 5:0] mem_ecode     ;

assign {mem_wrong_addr,    
        mem_csr_we,
        mem_csr_wmask,        
        mem_csr_num,       
        mem_ertn_flush,    
        mem_ex,            
        mem_esubcode,      
        mem_ecode,
        mem_csr_re         
      } = mem_exc_data;
assign ms_ex_to_es = (mem_ertn_flush | mem_ex) & ms_valid;


assign mem_rf_we = ms_valid && mem_gr_we;


wire [31:0] ld_data;
wire [3:0]  ld_sel;
wire [31:0] lb_data;
wire [31:0] lh_data;

decoder_2_4 u_dec_ld(.in(mem_alu_result[1:0]), .out(ld_sel));
wire zero_ext;
assign zero_ext = ~(mem_load_op[3] | mem_load_op[4]);
assign lb_data = {32{ld_sel[0]}} & {{24{mem_result[7] & zero_ext}}, mem_result[7:0]}
            | {32{ld_sel[1]}} & {{24{mem_result[15] & zero_ext}}, mem_result[15:8]}
            | {32{ld_sel[2]}} & {{24{mem_result[23] & zero_ext}}, mem_result[23:16]}
            | {32{ld_sel[3]}} & {{24{mem_result[31] & zero_ext}}, mem_result[31:24]};

assign lh_data = {32{ld_sel[0]}} & {{16{mem_result[15] & zero_ext}}, mem_result[15:0]}
               | {32{ld_sel[2]}} & {{16{mem_result[31] & zero_ext}}, mem_result[31:16]};

assign ld_data = {32{mem_load_op[0] | mem_load_op[3]}} & lb_data
               | {32{mem_load_op[1] | mem_load_op[4]}} & lh_data
               | {32{mem_load_op[2]}} & mem_result;
assign mem_result     =   data_sram_rdata;
assign mem_mul_result =   ({32{mem_mul_op[0]               }} & mul_result[31: 0])
                        | ({32{mem_mul_op[1]  | mem_mul_op[2]}} & mul_result[63:32]);
                    
assign mem_final_result  = {32{mem_res_from_mem}} & ld_data | 
                        {32{mem_res_from_mul}} & mem_mul_result |
                        {32{~mem_res_from_mem &~mem_res_from_mul}}&mem_alu_result ;
//
assign ms_mem_block = ( mem_res_from_mem || (mem_csr_re|mem_csr_we)) && ms_valid;     

endmodule
