`include "BUS_LEN.vh"
module IDstage (
  input wire clk,
  input wire reset,
  //handshake signals
  input wire es_allowin,
  output wire ds_allowin,
  input wire fs2ds_valid,
  output wire ds2es_valid,
  //branch  control signals
  output wire [32:0] br_zip,
  input wire [`WB_RF_BUS-1:0] rf_zip,
  output wire[`DS2ES_BUS_LEN-1:0] ds2es_bus,
  input wire [`FS2DS_BUS_LEN-1:0] fs2ds_bus,

  input wire [37:0] exe_forward_zip,
  input wire [37:0] mem_forward_zip,
    
  input wire es_block,
  output wire block,
  
  output wire res_from_mul,
  
  input wire ms_ex,
  input wire wb_ex,
  
  input wire es_csr_re,
  input wire ms_csr_re
);

//////////zip//////////
wire br_taken;
wire [31:0] br_target;
assign br_zip = {br_taken, br_target};

wire rf_we;
wire [4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we, rf_waddr, rf_wdata} = rf_zip;

wire exe_rf_we;
wire mem_rf_we;
wire [4:0] exe_dest;
wire [4:0] mem_dest;
wire [31:0] alu_result;
wire [31:0] final_result;

assign {exe_rf_we, exe_dest, alu_result}   = exe_forward_zip;
assign {mem_rf_we, mem_dest, final_result} = mem_forward_zip;

wire [31:0] fs_pc;
wire [31:0] inst;
assign {fs_pc, inst} = fs2ds_bus;

reg  [31:0] ds_pc;
wire [31:0] alu_src1;
wire [31:0] alu_src2;
wire [15:0] alu_op;
wire [2:0] mul_op;
wire [31:0] rkd_value;
//wire res_from_mem;
wire gr_we;
wire [4:0] dest;
wire mem_we;
wire [`EXCEPT_LEN-1 : 0] ds_except_zip;
assign ds2es_bus = {ds_pc, alu_src1, alu_src2, alu_op, mul_op, load_op, store_op, rkd_value, gr_we, dest, ds_except_zip/*82bits*/};

//////////declaration////////
reg ds_valid;


// wire        br_taken;
// wire [31:0] br_target;

// wire [11:0] alu_op;
wire [4:0] load_op;
wire [2:0] store_op;
wire src1_is_pc;
wire src2_is_imm;
wire dst_is_r1;
// wire        gr_we;
// wire        mem_we;
wire src_reg_is_rd;
// wire [4: 0] dest;
wire [31:0] rj_value;
// wire [31:0] rkd_value;
wire rj_eq_rd;
wire rj_lt_rd;
wire rj_ltu_rd;
wire cout;
wire [31:0]cout_test;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;

wire inst_add_w;
wire inst_sub_w;
wire inst_slt;
wire inst_sltu;
wire inst_nor;
wire inst_and;
wire inst_or;
wire inst_xor;
wire inst_slli_w;
wire inst_srli_w;
wire inst_srai_w;
wire inst_addi_w;
//wire inst_ld_w;
wire inst_st_w;
wire inst_jirl;
wire inst_b;
wire inst_bl;
wire inst_beq;
wire inst_bne;
wire inst_lu12i_w;
wire inst_mul_w;
wire inst_mulh_w;
wire inst_mulh_wu;
wire inst_div_w;
wire inst_div_wu;
wire inst_mod_w;
wire inst_mod_wu;

wire inst_sltui;
wire inst_slti;
wire inst_andi;
wire inst_ori;
wire inst_sll_w;
wire inst_srl_w;
wire inst_sra_w;
wire inst_pcaddu12i;

wire inst_blt;
wire inst_bge;
wire inst_bltu;
wire inst_bgeu;
wire inst_ld_b;
wire inst_ld_h;
wire inst_ld_bu;
wire inst_ld_hu;
wire inst_st_b;
wire inst_st_h;

//系统调用异常支持指令
wire inst_csrrd;
wire inst_csrwr;
wire inst_csrxchg;
wire inst_ertn;
wire inst_syscall;


wire need_ui5;
wire need_ui12;
wire need_si12;
wire need_si16;
wire need_si20;
wire need_si26;
wire src2_is_4;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

reg [31:0] inst_reg;

wire csr_re;
wire csr_we;
wire [31:0] csr_wmask;
wire [31:0] csr_wvalue;
wire [13:0] csr_num;


//////////pipeline//////////
wire ds_ready_go;
assign ds_ready_go    =~((((exe_rf_we && (es_block | es_csr_re) && 
                            (exe_dest == rf_raddr1 && |rf_raddr1 && (~src1_is_pc & ~inst_lu12i_w & |alu_op |(|mul_op)) ||  //
                             exe_dest == rf_raddr2 && |rf_raddr2 && ~src2_is_imm & |alu_op|(|mul_op)))))                      ||
                          mem_rf_we && (ms_csr_re) &&
                            (mem_dest == rf_raddr1 && |rf_raddr1 && (~src1_is_pc & ~inst_lu12i_w & |alu_op |(|mul_op)) ||  //
                             mem_dest == rf_raddr2 && |rf_raddr2 && ~src2_is_imm & |alu_op|(|mul_op)
                          ));


assign ds_allowin = ~ds_valid || ds_ready_go && es_allowin;
assign ds2es_valid = ds_valid && ds_ready_go;

always @(posedge clk) begin
  if (reset || br_taken || wb_ex) begin
    ds_valid <= 1'b0;
  end else if (ds_allowin) begin
    ds_valid <= fs2ds_valid;
  end

  if(fs2ds_valid && ds_allowin)begin
    ds_pc <= fs_pc;
    inst_reg <= inst;
  end
end




assign op_31_26  = inst_reg[31:26];
assign op_25_22  = inst_reg[25:22];
assign op_21_20  = inst_reg[21:20];
assign op_19_15  = inst_reg[19:15];

assign rd   = inst_reg[ 4: 0];
assign rj   = inst_reg[ 9: 5];
assign rk   = inst_reg[14:10];

assign i12  = inst_reg[21:10];
assign i20  = inst_reg[24: 5];
assign i16  = inst_reg[25:10];
assign i26  = {inst_reg[ 9: 0], inst_reg[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~inst_reg[25];

//additional instruction!
assign inst_pcaddu12i = op_31_26_d[6'h07] & ~inst[25];

//shift inst
assign inst_sll_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_srl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];

//logic inst
assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hf];

//the mul/div instruction decode!
assign inst_mul_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulh_wu= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
assign inst_div_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_mod_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_div_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mod_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];

assign inst_blt    = op_31_26_d[6'h18];
assign inst_bge    = op_31_26_d[6'h19];
assign inst_bltu   = op_31_26_d[6'h1a];
assign inst_bgeu   = op_31_26_d[6'h1b];
assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];

assign inst_csrrd   = op_31_26_d[6'h01] & (op_25_22[3:2] == 2'b0) & (rj == 5'h00);
assign inst_csrwr   = op_31_26_d[6'h01] & (op_25_22[3:2] == 2'b0) & (rj == 5'h01);
assign inst_csrxchg = op_31_26_d[6'h01] & (op_25_22[3:2] == 2'b0) & ~inst_csrrd & ~inst_csrwr;
assign inst_ertn    = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] 
                    & (rk == 5'h0e) & (~|rj) & (~|rd);
assign inst_syscall = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];

assign load_op[0] = inst_ld_b;
assign load_op[1] = inst_ld_h;
assign load_op[2] = inst_ld_w;
assign load_op[3] = inst_ld_bu;
assign load_op[4] = inst_ld_hu;
assign store_op[0] = inst_st_b;
assign store_op[1] = inst_st_h;
assign store_op[2] = inst_st_w;

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w | (|load_op) | (|store_op)
                    | inst_jirl | inst_bl | inst_pcaddu12i;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt|inst_slti;
assign alu_op[ 3] = inst_sltu|inst_sltui;
assign alu_op[ 4] = inst_and|inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or|inst_ori;
assign alu_op[ 7] = inst_xor|inst_xori;
assign alu_op[ 8] = inst_slli_w|inst_sll_w;
assign alu_op[ 9] = inst_srli_w|inst_srl_w;
assign alu_op[10] = inst_srai_w|inst_sra_w;
assign alu_op[11] = inst_lu12i_w;
assign alu_op[12] = inst_div_w;
assign alu_op[13] = inst_div_wu;
assign alu_op[14] = inst_mod_w;
assign alu_op[15] = inst_mod_wu;

assign mul_op[0] = inst_mul_w;
assign mul_op[1] = inst_mulh_w;
assign mul_op[2] = inst_mulh_wu;

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_ui12  =  inst_andi | inst_ori | inst_xori;
assign need_si12  =  inst_addi_w | (|load_op ) | (|store_op ) | inst_slti | inst_sltui;
assign need_si16  =  inst_jirl | inst_beq | inst_bne;
assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;

assign imm =                  {32{src2_is_4}} & 32'h4                              |
                              {32{need_si20}} & {i20[19:0], 12'b0}                   |
  /*need_ui5 || need_si12*/   {32{(need_ui5 || need_si12)}} &{{20{i12[11]}}, i12[11:0]} |
                              {32{~src2_is_4&~need_si20&~(need_ui5 || need_si12)}}&{20'b0, i12[11:0]};

assign br_offs = {32{need_si26}} & {{ 4{i26[25]}}, i26[25:0], 2'b0} |
                 {32{~need_si26}} &{{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};    

assign src_reg_is_rd = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu | (|store_op );

assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                        (|load_op) |
                        (|store_op)|
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     |
                       inst_pcaddu12i|
                       inst_andi   |
                       inst_ori    |
                       inst_xori   |
                       inst_slti   |
                       inst_sltui;

assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_st_h & ~inst_st_b & ~inst_beq  & 
                       ~inst_bne  & ~inst_b    & ~inst_bge  & ~inst_bgeu & 
                       ~inst_blt  & ~inst_bltu & ~inst_syscall & ~inst_ertn;
assign mem_we        = inst_st_w | inst_st_b | inst_st_h;
assign dest          = dst_is_r1 ? 5'd1 : rd;


assign res_from_mul = inst_mul_w || inst_mulh_w || inst_mulh_wu;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

//assign rj_value  = rf_rdata1;
//assign rkd_value = rf_rdata2;
assign rj_value = 
    (exe_rf_we && exe_dest == rf_raddr1)? alu_result :
    (mem_rf_we && mem_dest == rf_raddr1)? final_result :
    (rf_we  &&    rf_waddr   == rf_raddr1)? rf_wdata   :
    rf_rdata1;
assign rkd_value = 
    (exe_rf_we && exe_dest == rf_raddr2)? alu_result :
    (mem_rf_we && mem_dest == rf_raddr2)? final_result :
    (rf_we     && rf_waddr == rf_raddr2)?  rf_wdata   :
    rf_rdata2;

assign {cout, cout_test} = {1'b0, rj_value} + {1'b0, ~rkd_value} + 1'b1;

assign rj_eq_rd = (rj_value == rkd_value);
assign rj_lt_rd = rj_value[31] ^ ~rkd_value[31] ^ cout;
assign rj_ltu_rd = ~cout;
assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_blt  &&  rj_lt_rd
                   || inst_bge  &&  !rj_lt_rd
                   || inst_bltu &&  rj_ltu_rd
                   || inst_bgeu && !rj_ltu_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                  ) && ds_valid && ds_ready_go; 
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b ||
                    inst_blt || inst_bge || inst_bltu || inst_bgeu) ? (ds_pc + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs) ;

assign alu_src1 = src1_is_pc  ? ds_pc[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

assign block = (|load_op) || res_from_mul;


assign csr_re    = inst_csrrd | inst_csrwr | inst_csrxchg;
assign csr_we    = inst_csrwr | inst_csrxchg;
assign csr_wmask    = {32{inst_csrxchg}} & rj_value | {32{inst_csrwr}};
assign csr_wvalue   = rkd_value;
assign csr_num   = inst_reg[23:10];

assign ds_except_zip  = {csr_num, csr_wmask, csr_wvalue, inst_syscall, inst_ertn, csr_re, csr_we};

endmodule