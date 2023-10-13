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


wire fs_allowin;
wire ds_allowin;
wire es_allowin;
wire ms_allowin;
wire ws_allowin;
wire fs2ds_valid;
wire ds2es_valid;
wire es2ms_valid;
wire ms2ws_valid;


wire mem_rf_we;
wire [4:0] mem_dest;
wire exe_rf_we;
wire [4:0] exe_dest;
wire [4:0] dest_reg;
wire [31:0] alu_result;
wire [31:0] final_result;

wire es_inst_is_ld_w;
wire inst_ld_w;

wire [32:0] br_zip;
wire [37:0] rf_zip;

wire [63:0] fs2ds_bus;
wire [147:0] ds2es_bus;
wire [70:0] es2ms_bus;
wire [69:0] ms2ws_bus;



IFstage my_if (
  .clk(clk),
  .resetn(resetn),
  .reset(reset),
  
  .ds_allowin(ds_allowin),
  .fs2ds_valid(fs2ds_valid),
  
  .inst_sram_en(inst_sram_en),
  .inst_sram_we(inst_sram_we),
  .inst_sram_addr(inst_sram_addr),
  .inst_sram_wdata(inst_sram_wdata),
  .inst_sram_rdata(inst_sram_rdata),
  
  .br_zip(br_zip),
  .fs2ds_bus(fs2ds_bus)
);

IDstage my_id (
  .clk(clk),
  .resetn(resetn),
  .reset(reset),
  
  .es_allowin(es_allowin),
  .ds_allowin(ds_allowin),
  .fs2ds_valid(fs2ds_valid),
  .ds2es_valid(ds2es_valid),

  .br_zip(br_zip),
  .ds2es_bus(ds2es_bus),
  .rf_zip(rf_zip),
  .fs2ds_bus(fs2ds_bus),


  .exe_rf_we(exe_rf_we),
  .mem_rf_we(mem_rf_we),
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
  
  .ms_allowin(ms_allowin),
  .es_allowin(es_allowin),
  .ds2es_valid(ds2es_valid),
  .es2ms_valid(es2ms_valid),
  
  .ds2es_bus(ds2es_bus),
  .es2ms_bus(es2ms_bus),

  .data_sram_en(data_sram_en),
  .data_sram_we(data_sram_we),
  .data_sram_addr(data_sram_addr),
  .data_sram_wdata(data_sram_wdata),

  .exe_rf_we(exe_rf_we),
  .exe_dest(exe_dest),
  .alu_result(alu_result),

  .es_inst_is_ld_w(es_inst_is_ld_w),
  .inst_ld_w(inst_ld_w)
);

MEMstage my_mem (
  .clk(clk),
  .resetn(resetn),
  .reset(reset),
  .data_sram_rdata(data_sram_rdata),
  
  .ws_allowin(ws_allowin),
  .ms_allowin(ms_allowin),
  .es2ms_valid(es2ms_valid),
  .ms2ws_valid(ms2ws_valid),
  
  .es2ms_bus(es2ms_bus),
  .ms2ws_bus(ms2ws_bus),
  
  .mem_rf_we(mem_rf_we),
  .mem_dest(mem_dest),
  .final_result(final_result)
);

WBstage my_wb (
  .clk(clk),
  .resetn(resetn),
  .reset(reset),
  
  .ms_allowin(ms_allowin),
  .ws_allowin(ws_allowin),
  .es2ms_valid(es2ms_valid),
  .ms2ws_valid(ms2ws_valid),
  
  .ms2ws_bus(ms2ws_bus),
  .rf_zip(rf_zip),

  .debug_wb_pc(debug_wb_pc),
  .debug_wb_rf_we(debug_wb_rf_we),
  .debug_wb_rf_wnum(debug_wb_rf_wnum),
  .debug_wb_rf_wdata(debug_wb_rf_wdata),

  .ws_valid(ws_valid),
  .dest_reg(dest_reg)
);

endmodule
