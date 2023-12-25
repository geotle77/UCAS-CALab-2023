`include "BUS_LEN.vh"
module MEMstage (
    input wire                          clk,
    input wire                          resetn,
    input wire                          reset,

    // interface with SRAM
    input  wire [31:0]                  data_sram_rdata,
    input  wire                         data_sram_data_ok,
    
    // interface between EXE and MEM
    output wire                         ms_allowin,
    input  wire                         es2ms_valid,
    input  wire [`ES2MS_BUS_LEN-1:0]    es2ms_bus,
    input  wire [67:0]                  mul_result,

    // interface between MEM and WB
    input  wire                         ws_allowin,
    output wire                         ms2ws_valid,
    output wire [`MS2WS_BUS_LEN-1:0]    ms2ws_bus,

    // forward data
    output wire [`FORWARD_BUS_LEN-1:0]  mem_forward_zip,
    

    output wire                         ms_mem_block, // load/store or CSRwrite/read in MEM

    output wire                         ms_ex_to_es,  // to EXE
    input  wire                         ms_reflush,   // syscall in WB
    output wire                         ms_csr_re,    // to ID

    output wire                         ms_csr_tlbrd  // to EXE
);


//--------------------declaration--------------------



wire          ms_refetch_flg;
wire          ms_inst_tlbsrch;
wire          ms_inst_tlbrd;
wire          ms_inst_tlbwr;
wire          ms_inst_tlbfill;
// TLB search result
wire          ms_tlbsrch_hit;
wire [ 3:0]   ms_tlbsrch_hit_index;
wire [ 5:0]   ms_exc_ecode; 
wire          ms_adem;

wire          mem_we;
wire          ms_res_from_mem;
wire [31:0]   ms_pc;
wire          mem_res_from_mul;
wire [2:0]    mem_mul_op;
wire [31:0]   mem_alu_result;
wire [4:0]    mem_load_op;
wire [4:0]    mem_dest;
wire          mem_gr_we;
wire [31:0]   mem_rkd_value;
wire [`MS_EXC_DATA_WD-1 : 0] mem_exc_data;
reg[`ES2MS_BUS_LEN-1:0] es2ms_bus_reg;
assign {ms_adem,
        ms_exc_ecode,
        ms_refetch_flg_inst,
        ms_inst_tlbsrch,
        ms_inst_tlbrd,
        ms_inst_tlbwr,
        ms_inst_tlbfill,
        ms_tlbsrch_hit,
        ms_tlbsrch_hit_index,
        mem_we,
        ms_res_from_mem,
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
wire ms_refetch_flg_inst;
assign ms_refetch_flg = ms_refetch_flg_inst && ms_valid;

wire        mem_rf_we;
wire [31:0] mem_final_result;
assign mem_forward_zip = {mem_rf_we, 
                          mem_dest, 
                          mem_final_result
                          };

assign ms2ws_bus = {
                    ms_exc_ecode,
                    ms_refetch_flg,
                    ms_inst_tlbsrch,
                    ms_inst_tlbrd,
                    ms_inst_tlbwr,
                    ms_inst_tlbfill,
                    ms_tlbsrch_hit,
                    ms_tlbsrch_hit_index,
                    ms_pc, 
                    mem_gr_we, 
                    mem_dest, 
                    mem_final_result, 
                    mem_rkd_value,
                    mem_exc_data};


wire [31:0]mem_result;
wire [31:0]mem_mul_result;






//--------------------pipeline control--------------------


wire ms_need_mem;
assign ms_need_mem = ms_valid && (ms_res_from_mem || mem_we);


wire ms_ready_go;
assign ms_ready_go = ms_need_mem && (data_sram_data_ok ||(|ms_exc_ecode) || ms_adem) ||  ~ms_need_mem;
assign ms_allowin = ~ms_valid || ms_ready_go && ws_allowin;
assign ms2ws_valid = ms_valid && ms_ready_go;

reg ms_valid;
always @(posedge clk) begin
  if (reset) begin
    ms_valid <= 1'b0;
  end 
  if (ms_reflush || ms_refetch_flg) begin
    ms_valid <= 1'b0;
  end
  else if (ms_allowin) begin
    ms_valid <= es2ms_valid;
  end
 
  if(es2ms_valid && ms_allowin)begin
    es2ms_bus_reg <= es2ms_bus;
  end
end









//assign ms_tlbsrch_hit = s1_found;
//assign ms_tlbsrch_hit_index = s1_index;

assign ms_csr_tlbrd = ( ( mem_csr_num == `CSR_ASID || mem_csr_num == `CSR_TLBEHI) && (mem_csr_we)
                     || ms_inst_tlbrd) && ms_valid;

// exception

assign ms_csr_re = mem_exc_data[0];

assign ms_ex_to_es = (mem_ertn_flush | mem_ex | ms_refetch_flg) & ms_valid;


wire mem_csr_re;
wire mem_csr_we;
wire [ 3:0] mem_csr_op;
wire [31:0] mem_wrong_addr;
wire [13:0] mem_csr_num   ;
wire [31:0] mem_csr_wmask ;
wire        mem_ertn_flush;
wire        mem_ex        ;
wire [ 8:0] mem_esubcode  ;
wire [ 5:0] mem_ecode     ;

assign {mem_csr_op,
        mem_wrong_addr,    
        mem_csr_we,
        mem_csr_wmask,        
        mem_csr_num,       
        mem_ertn_flush,    
        mem_ex,            
        mem_esubcode,      
        mem_ecode,
        mem_csr_re         
      } = mem_exc_data;


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
                    
assign mem_final_result  = {32{ms_res_from_mem}} & ld_data | 
                        {32{mem_res_from_mul}} & mem_mul_result |
                        {32{~ms_res_from_mem &~mem_res_from_mul}}&mem_alu_result ;
//
assign ms_mem_block = ( ms_res_from_mem || (mem_csr_re|mem_csr_we)) && ms_valid;     


endmodule
