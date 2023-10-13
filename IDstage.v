module IDstage (
  input wire clk,
  input wire resetn,
  input wire reset,
  
  input wire es_allowin,
  output wire ds_allowin,
  input wire fs2ds_valid,
  output wire ds2es_valid,
  
  output wire [32:0] br_zip,
  input wire [37:0] rf_zip,
  output wire [147:0] ds2es_bus,
  input wire [63:0] fs2ds_bus,

  input wire es_valid,
  input wire ms_valid,
  input wire ws_valid,
  input wire exe_gr_we,
  input wire mem_gr_we,
  input wire gr_we_reg,
  input wire [4:0] exe_dest,
  input wire [4:0] mem_dest,
  input wire [4:0] dest_reg,
  input wire [31:0] alu_result,
  input wire [31:0] final_result,
  
  input wire es_inst_is_ld_w,
  output wire inst_ld_w
);

//////////zip//////////
wire br_taken;
wire [31:0] br_target;
assign br_zip = {br_taken, br_target};

wire rf_we;
wire [4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we, rf_waddr, rf_wdata} = rf_zip;

wire [31:0] fs_pc;
wire [31:0] inst;
assign {fs_pc, inst} = fs2ds_bus;

reg [31:0] ds_pc;
wire [31:0] alu_src1;
wire [31:0] alu_src2;
wire [11:0] alu_op;
wire [31:0] rkd_value;
wire res_from_mem;
wire gr_we;
wire [4:0] dest;
wire mem_we;
assign ds2es_bus = {ds_pc, alu_src1, alu_src2, alu_op, rkd_value, res_from_mem, gr_we, dest, mem_we};

//////////declaration////////
reg ds_valid;


// wire        br_taken;
// wire [31:0] br_target;

// wire [11:0] alu_op;
wire load_op;
wire src1_is_pc;
wire src2_is_imm;
// wire        res_from_mem;
wire dst_is_r1;
// wire        gr_we;
// wire        mem_we;
wire src_reg_is_rd;
// wire [4: 0] dest;
wire [31:0] rj_value;
// wire [31:0] rkd_value;
wire rj_eq_rd;
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

wire need_ui5;
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



//////////pipeline//////////
wire ds_ready_go;


assign ds_ready_go    =
~(ds_valid && ((es_valid && exe_gr_we && es_inst_is_ld_w && 
        (exe_dest == rf_raddr1 && |rf_raddr1 && ~src1_is_pc || 
        exe_dest == rf_raddr2 && |rf_raddr2 && ~src2_is_imm))));


assign ds_allowin = ~ds_valid || ds_ready_go && es_allowin;
assign ds2es_valid = ds_valid && ds_ready_go;

always @(posedge clk) begin
  if (reset || br_taken) begin
    ds_valid <= 1'b0;
  end else if (ds_allowin) begin
    ds_valid <= fs2ds_valid;
  end
  
  if(fs2ds_valid && ds_allowin)begin
    ds_pc <= fs_pc;
    inst_reg <= inst;
  end
end


//////////assign//////////




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

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                    | inst_jirl | inst_bl;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt;
assign alu_op[ 3] = inst_sltu;
assign alu_op[ 4] = inst_and;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or;
assign alu_op[ 7] = inst_xor;
assign alu_op[ 8] = inst_slli_w;
assign alu_op[ 9] = inst_srli_w;
assign alu_op[10] = inst_srai_w;
assign alu_op[11] = inst_lu12i_w;

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w;
assign need_si16  =  inst_jirl | inst_beq | inst_bne;
assign need_si20  =  inst_lu12i_w;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;

assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
             need_ui5 ? {27'b0, rk}                 :
/*need_si12*/           {{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w;

assign src1_is_pc    = inst_jirl | inst_bl;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     ;

assign res_from_mem  = inst_ld_w;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b;
assign mem_we        = inst_st_w;
assign dest          = dst_is_r1 ? 5'd1 : rd;

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
    (exe_gr_we && es_valid && exe_dest == rf_raddr1)? alu_result :////
    (mem_gr_we && ms_valid && mem_dest == rf_raddr1)? final_result :
    (gr_we_reg && ws_valid  && dest_reg   == rf_raddr1)? rf_wdata   :
    rf_rdata1;
assign rkd_value = 
    (exe_gr_we && es_valid && exe_dest == rf_raddr2)? alu_result :
    (mem_gr_we && ms_valid && mem_dest == rf_raddr2)? final_result :
    (gr_we_reg && ws_valid  && dest_reg   == rf_raddr2)? rf_wdata   :
    rf_rdata2;

assign rj_eq_rd = (rj_value == rkd_value);
assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                  ) && ds_valid && ds_ready_go;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (ds_pc + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);

assign alu_src1 = src1_is_pc  ? ds_pc[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;










endmodule
