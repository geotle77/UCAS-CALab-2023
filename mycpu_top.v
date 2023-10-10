module mycpu_top (
  input  wire        clk,
  input  wire        resetn,
  output reg        reset,
  // inst sram interface
  output wire        inst_sram_en,
  output wire [3:0] inst_sram_we,
  output wire [31:0] inst_sram_addr,
  output wire [31:0] inst_sram_wdata,
  input  wire [31:0] inst_sram_rdata,
  // data sram interface
  output wire        data_sram_en,
  output wire [3:0] data_sram_we,
  output wire [31:0] data_sram_addr,
  output wire [31:0] data_sram_wdata,
  input  wire [31:0] data_sram_rdata,
  // trace debug interface
  output wire [31:0] debug_wb_pc,
  output wire [3:0] debug_wb_rf_we,
  output wire [4:0] debug_wb_rf_wnum,
  output wire [31:0] debug_wb_rf_wdata
);

// reg         reset;
always @(posedge clk) reset <= ~resetn;

reg         valid;
always @(posedge clk) begin
    if (~resetn) begin
        valid <= 1'b0;
    end
    else begin
        valid <= 1'b1;
    end
end

wire br_taken;
wire [31:0] br_target;
wire [31:0] inst;
wire [31:0] fs_pc;
//wire if_valid;

wire [31:0] alu_src1;
wire [31:0] alu_src2;
wire [11:0] alu_op;
wire [31:0] rkd_value;
wire [31:0] res_from_mem;
wire gr_we;
wire [4:0] dest;
wire mem_we;

wire rf_we;
wire [4:0] rf_waddr;
wire [31:0] rf_wdata;

wire [31:0] ds_pc;
//wire id_valid;

wire [31:0] alu_result;
wire [31:0] exe_res_from_mem;
wire [4:0] exe_dest;
wire exe_gr_we;

wire [31:0] es_pc;
//wire exe_valid;

wire mem_gr_we;
wire [4:0] mem_dest;
wire [31:0] mem_alu_result;
wire [31:0] mem_res_from_mem;

wire [31:0] ms_pc;
//wire mem_valid;

wire [31:0] ws_pc;
//wire wb_valid;


wire [4:0] dest_reg;


//wire exe_ready_go;

//wire if_allowin;

// wire [31:0] res_from_mem_reg;

//wire block;
//wire exe_restart;
//wire mem_restart;
//wire wb_restart;
//wire disblock;

//wire exe_restart_exe;



//wire exe_restart_mem;
//wire mem_restart_mem;



  wire fs_allowin;
  wire ds_allowin;
  wire es_allowin;
  wire ms_allowin;
  wire ws_allowin;
  wire fs2ds_valid;
  wire ds2es_valid;
  wire es2ms_valid;
  wire ms2ws_valid;
  
  
    
wire es_valid;
wire ms_valid;
wire ws_valid;


wire gr_we_reg;
//wire [4:0] dest_reg;

//wire [31:0] alu_result;
wire [31:0] final_result;
//wire [31:0] mem_result;


wire es_inst_is_ld_w;
wire inst_ld_w;



IFstage my_if (
  .clk(clk),
  .resetn(resetn),
  .reset(reset),
  .inst_sram_en(inst_sram_en),
  .inst_sram_we(inst_sram_we),
  .inst_sram_addr(inst_sram_addr),
  .inst_sram_wdata(inst_sram_wdata),
  .inst_sram_rdata(inst_sram_rdata),
  .br_taken(br_taken),
  .br_target(br_target),
  .inst(inst),
  .fs_pc(fs_pc),
  .fs_valid(fs_valid),
  //.if_allowin(if_allowin)
//  .block(block)
  .ds_allowin(ds_allowin),
  .fs2ds_valid(fs2ds_valid)
);

IDstage my_id (
  .clk(clk),
  .resetn(resetn),
  .reset(reset),
  .inst(inst),
  .br_taken(br_taken),
  .br_target(br_target),
  .alu_src1(alu_src1),
  .alu_src2(alu_src2),
  .alu_op(alu_op),
  .rkd_value(rkd_value),
  .res_from_mem(res_from_mem),
  .gr_we(gr_we),
  .dest(dest),
  .mem_we(mem_we),
  .rf_we(rf_we),
  .rf_waddr(rf_waddr),
  .rf_wdata(rf_wdata),
  .fs_pc(fs_pc),
  .fs_valid(fs_valid),
  .ds_pc(ds_pc),
  .ds_valid(ds_valid),
  //.exe_gr_we(exe_gr_we),
  //.mem_gr_we(mem_gr_we),
  //.gr_we_reg(gr_we_reg),
  //.exe_dest(exe_dest),
  //.mem_dest(mem_dest),
  //.dest_reg(dest_reg)
//  .exe_ready_go(exe_ready_go),
//  .if_allowin(if_allowin)

//  .block(block),
//  .exe_restart(exe_restart),
//  .mem_restart(mem_restart),
//  .wb_restart(wb_restart),
//  .disblock(disblock)
  .es_allowin(es_allowin),
  .ds_allowin(ds_allowin),
  .fs2ds_valid(fs2ds_valid),
  .ds2es_valid(ds2es_valid),
  .es_valid(es_valid),
  .ms_valid(ms_valid),
  .ws_valid(ws_valid),
  .exe_gr_we(exe_gr_we),
  .mem_gr_we(mem_gr_we),
  .gr_we_reg(gr_we_reg),
  .exe_dest(exe_dest),
  .mem_dest(mem_dest),
  .dest_reg(dest_reg),
  .alu_result(alu_result),
  .final_result(final_result),
  .es_inst_is_ld_w(es_inst_is_ld_w),
  .inst_ld_w(inst_ld_w)

);

EXEstage my_exe (
  .clk(clk),
  .resetn(resetn),
  .reset(reset),
  .alu_src1(alu_src1),
  .alu_src2(alu_src2),
  .alu_op(alu_op),
  .rkd_value(rkd_value),
  .res_from_mem(res_from_mem),
  .gr_we(gr_we),
  .dest(dest),
  .mem_we(mem_we),
  .alu_result(alu_result),
  .exe_res_from_mem(exe_res_from_mem),
  .exe_dest(exe_dest),
  .exe_gr_we(exe_gr_we),
  .data_sram_en(data_sram_en),
  .data_sram_we(data_sram_we),
  .data_sram_addr(data_sram_addr),
  .data_sram_wdata(data_sram_wdata),
  .data_sram_rdata(data_sram_rdata),
  .ds_pc(ds_pc),
  .ds_valid(ds_valid),
  .es_pc(es_pc),
  .es_valid(es_valid),
  //.exe_ready_go(exe_ready_go)
  
//  .block(block),
//  .exe_restart(exe_restart),
//  .exe_restart_exe(exe_restart_exe)
  .ms_allowin(ms_allowin),
  .es_allowin(es_allowin),
  .ds2es_valid(ds2es_valid),
  .es2ms_valid(es2ms_valid),
  .es_inst_is_ld_w(es_inst_is_ld_w),
  .inst_ld_w(inst_ld_w)
);

MEMstage my_mem (
  .clk(clk),
  .resetn(resetn),
  .reset(reset),
  .alu_result(alu_result),
  .exe_res_from_mem(exe_res_from_mem),
  .exe_dest(exe_dest),
  .exe_gr_we(exe_gr_we),
  .data_sram_rdata(data_sram_rdata),
  .mem_gr_we(mem_gr_we),
  .mem_dest(mem_dest),
  .mem_alu_result(mem_alu_result),
  .mem_res_from_mem(mem_res_from_mem),
  .es_pc(es_pc),
  .es_valid(es_valid),
  .ms_pc(ms_pc),
  .ms_valid(ms_valid),
  
//  .block(block),
//  .mem_restart(mem_restart),
//  .exe_restart_exe(exe_restart_exe),
//  .exe_restart_mem(exe_restart_mem),
//  .mem_restart_mem(mem_restart_mem)
  .ws_allowin(ws_allowin),
  .ms_allowin(ms_allowin),
  .es2ms_valid(es2ms_valid),
  .ms2ws_valid(ms2ws_valid),
  .final_result(final_result)
  //.mem_result(mem_result)
);

WBstage my_wb (
  .clk(clk),
  .resetn(resetn),
  .reset(reset),
  .data_sram_rdata(data_sram_rdata),
  .mem_gr_we(mem_gr_we),
  .mem_dest(mem_dest),
  .mem_alu_result(mem_alu_result),
  .mem_res_from_mem(mem_res_from_mem),
  .rf_we(rf_we),
  .rf_waddr(rf_waddr),
  .rf_wdata(rf_wdata),
  .debug_wb_pc(debug_wb_pc),
  .debug_wb_rf_we(debug_wb_rf_we),
  .debug_wb_rf_wnum(debug_wb_rf_wnum),
  .debug_wb_rf_wdata(debug_wb_rf_wdata),
  .ms_pc(ms_pc),
  .ms_valid(ms_valid),
  .ws_pc(ws_pc),
  .ws_valid(ws_valid),

  
//  .block(block),
//  .wb_restart(wb_restart),
//  .exe_restart_mem(exe_restart_mem),
//  .mem_restart_mem(mem_restart_mem),
//  .disblock(disblock)

  .ms_allowin(ms_allowin),
  .ws_allowin(ws_allowin),
  .es2ms_valid(es2ms_valid),
  .ms2ws_valid(ms2ws_valid),
  
  .dest_reg(dest_reg),
  .gr_we_reg(gr_we_reg),
  .final_result(final_result)

  
);

endmodule
