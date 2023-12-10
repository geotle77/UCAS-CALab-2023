`include "BUS_LEN.vh"
module mycpu_top (
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_req,
    output wire        inst_sram_wr,
    output wire [ 1:0] inst_sram_size,
    output wire [ 3:0] inst_sram_wstrb,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    input  wire        inst_sram_addr_ok,
    input  wire        inst_sram_data_ok,
    // data sram interface
    output wire        data_sram_req,
    output wire        data_sram_wr,
    output wire [ 3:0] data_sram_wstrb,
    output wire [ 1:0] data_sram_size,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    input  wire        data_sram_addr_ok,
    input  wire        data_sram_data_ok,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

reg         reset;
always @(posedge clk) reset <= ~resetn;


//wire fs_allowin;
wire ds_allowin;
wire es_allowin;
wire ms_allowin;
wire ws_allowin;
wire fs2ds_valid;
wire ds2es_valid;
wire es2ms_valid;
wire ms2ws_valid;

wire [`FORWARD_BUS_LEN-1:0] exe_forward_zip;
wire [`FORWARD_BUS_LEN-1:0] mem_forward_zip;
wire [`BR_BUS-1:0] br_zip;
wire [`WB_RF_BUS-1:0] rf_zip;

wire es_block;
wire es_mem_block;
wire ms_mem_block;
wire mul_block;

wire [`FS2DS_BUS_LEN-1:0]   fs2ds_bus;
wire [`DS2ES_BUS_LEN-1:0]   ds2es_bus;
wire [`ES2MS_BUS_LEN-1:0]   es2ms_bus;
wire [`MS2WS_BUS_LEN-1:0]   ms2ws_bus;
wire [`WS2CSR_BUS_LEN-1 : 0] ws2csr_bus;

wire [67:0] mul_result;

wire [31:0] csr_ex_entry;
wire [31:0] csr_ertn_entry;
wire [31:0]csr_rvalue;
wire        ertn_flush;
wire        ms_ex;
wire        wb_ex;

wire ms_csr_re;
wire es_csr_re;
wire ds_has_int;
wire ws_reflush;
wire ms_ex_to_es;
wire csr_has_int;
IFstage my_if (
  .clk              (clk),
  .resetn           (resetn),
  
  .inst_sram_en     (inst_sram_req    ),
  .inst_sram_wr     (inst_sram_wr     ),
  .inst_sram_we     (inst_sram_wstrb  ),
  .inst_sram_size   (inst_sram_size   ),
  .inst_sram_addr   (inst_sram_addr   ),
  .inst_sram_wdata  (inst_sram_wdata  ),
  .inst_sram_rdata  (inst_sram_rdata  ),
  .inst_sram_addr_ok(inst_sram_addr_ok),
  .inst_sram_data_ok(inst_sram_data_ok),
  
  .br_zip           (br_zip),
  .fs2ds_bus        (fs2ds_bus),
  .ds_allowin       (ds_allowin),
  .fs2ds_valid      (fs2ds_valid),
  
  .csr_ex_entry     (csr_ex_entry  ),
  .csr_ertn_entry   (csr_ertn_entry),
  .ertn_flush       (ertn_flush),
  .wb_ex            (wb_ex     ),

  .fs_reflush       (ws_reflush)
);

IDstage my_id (
  .clk              (clk),
  .reset            (reset),
  
  .es_allowin       (es_allowin),
  .ds_allowin       (ds_allowin),
  .fs2ds_valid      (fs2ds_valid),
  .ds2es_valid      (ds2es_valid),

  .br_zip           (br_zip),
  .ds2es_bus        (ds2es_bus),
  .fs2ds_bus        (fs2ds_bus),

  .mem_forward_zip  (mem_forward_zip),
  .exe_forward_zip  (exe_forward_zip),
  .rf_zip           (rf_zip),

  .es_block         (es_block),
  .es_mem_block     (es_mem_block),
  .ms_mem_block     (ms_mem_block),
  .mul_block            (mul_block),

  .ms_csr_re        (ms_csr_re),
  .es_csr_re        (es_csr_re),
  .ds_has_int       (csr_has_int),
  .ds_reflush       (ws_reflush)
);

EXEstage my_exe (
  .clk              (clk),
  .resetn           (resetn),
  .reset            (reset),
  
  .ms_allowin       (ms_allowin),
  .es_allowin       (es_allowin),
  .ds2es_valid      (ds2es_valid),
  .es2ms_valid      (es2ms_valid),
  
  .ds2es_bus        (ds2es_bus),
  .es2ms_bus        (es2ms_bus),

  .data_sram_en     (data_sram_req    ),
  .data_sram_wr     (data_sram_wr     ),
  .data_sram_we     (data_sram_wstrb  ),     
  .data_sram_size   (data_sram_size   ),
  .data_sram_addr   (data_sram_addr   ),
  .data_sram_wdata  (data_sram_wdata  ),
  .data_sram_addr_ok(data_sram_addr_ok),

  .exe_forward_zip  (exe_forward_zip),

  .es_block         (es_block),
  .es_mem_block     (es_mem_block),
  .mul_block            (mul_block),

  .mul_result       (mul_result),

  .ms_ex_to_es      (ms_ex_to_es),
  .es_csr_re        (es_csr_re),
  .es_reflush       (ws_reflush)
);

MEMstage my_mem (
  .clk              (clk),
  .resetn           (resetn),
  .reset            (reset),

  .data_sram_rdata (data_sram_rdata ),
  .data_sram_data_ok(data_sram_data_ok),
  
  .ws_allowin       (ws_allowin),
  .ms_allowin       (ms_allowin),
  .es2ms_valid      (es2ms_valid),
  .ms2ws_valid      (ms2ws_valid),
  
  .es2ms_bus        (es2ms_bus),
  .ms2ws_bus        (ms2ws_bus),
  .mem_forward_zip  (mem_forward_zip),

  .mul_result       (mul_result),
  .ms_mem_block     (ms_mem_block),
  .ms_ex_to_es      (ms_ex_to_es),
  .ms_reflush       (ws_reflush),
  .ms_csr_re        (ms_csr_re)
);

WBstage my_wb (
  .clk              (clk),
  .resetn           (resetn),
  .reset            (reset),
  
  .ws_allowin       (ws_allowin),
  .ms2ws_valid      (ms2ws_valid),
  
  .ms2ws_bus        (ms2ws_bus),
  .rf_zip           (rf_zip),

  .debug_wb_pc      (debug_wb_pc),
  .debug_wb_rf_we   (debug_wb_rf_we),
  .debug_wb_rf_wnum (debug_wb_rf_wnum),
  .debug_wb_rf_wdata(debug_wb_rf_wdata),

  .csr_rvalue       (csr_rvalue),
  .ws_ertn_flush       (ertn_flush),
  .ws_reflush       (ws_reflush),
  .ws_ex            (wb_ex),
  .ws2csr_bus       (ws2csr_bus)
);

  csr u_csr(
    .clk            (clk       ),
    .reset          (reset   ),
    .csr_rvalue     (csr_rvalue),
    .ex_entry       (csr_ex_entry  ),
    .ertn_entry     (csr_ertn_entry),
    .ertn_flush     (ertn_flush),
    .wb_ex          (wb_ex     ),
    .ws2csr_bus     (ws2csr_bus),
    .has_int        (csr_has_int) 
    );

endmodule