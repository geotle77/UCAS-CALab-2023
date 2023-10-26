`include "BUS_LEN.vh"
module mycpu_top (
  input  wire        clk,
  input  wire        resetn,
  // inst sram interface
  output wire        inst_sram_en,
  output wire [3:0] inst_sram_we,
  output wire [31:0] inst_sram_addr,
  output wire [31:0] inst_sram_wdata,
  input  wire [31:0] inst_sram_rdata,
  // data sram interface
  output wire        data_sram_en,
  output wire [3:0]  data_sram_we,
  output wire [31:0] data_sram_addr,
  output wire [31:0] data_sram_wdata,
  input  wire [31:0] data_sram_rdata,
  // trace debug interface
  output wire [31:0] debug_wb_pc,
  output wire [3:0]  debug_wb_rf_we,
  output wire [4:0]  debug_wb_rf_wnum,
  output wire [31:0] debug_wb_rf_wdata
);

// reg         reset;
reg         reset;
always @(posedge clk) reset <= ~resetn;

//reg         valid;
//always @(posedge clk) begin
//    if (~resetn) begin
//        valid <= 1'b0;
//    end
//    else begin
//        valid <= 1'b1;
//    end
//end


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


wire res_from_mul;
wire exe_res_from_mul;
wire es_block;
wire block;

wire [`BR_BUS-1:0] br_zip;
wire [`WB_RF_BUS-1:0] rf_zip;

wire [`FS2DS_BUS_LEN-1:0]   fs2ds_bus;
wire [`DS2ES_BUS_LEN-1:0]   ds2es_bus;
wire [`ES2MS_BUS_LEN-1:0]   es2ms_bus;
wire [`MS2WS_BUS_LEN-1:0]   ms2ws_bus;
wire [`WS2CSR_BUS_LEN-1 : 0] ws2csr_bus;

wire [67:0] mul_result;

wire [31:0] csr_rvalue;
wire [31:0] ex_entry;
wire [31:0] ertn_entry;
wire        ertn_flush;
wire        ms_ex;
wire        wb_ex;

wire ms_csr_re;
wire es_csr_re;

IFstage my_if (
  .clk              (clk),
  .resetn           (resetn),
  
  .ds_allowin       (ds_allowin),
  .fs2ds_valid      (fs2ds_valid),
  
  .inst_sram_en     (inst_sram_en),
  .inst_sram_we     (inst_sram_we),
  .inst_sram_addr   (inst_sram_addr),
  .inst_sram_wdata  (inst_sram_wdata),
  .inst_sram_rdata  (inst_sram_rdata),
  
  .br_zip           (br_zip),
  .fs2ds_bus        (fs2ds_bus),

  .ex_entry         (ex_entry  ),
  .ertn_entry       (ertn_entry),
  .ertn_flush       (ertn_flush),
  .wb_ex            (wb_ex     )
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
  .rf_zip           (rf_zip),
  .fs2ds_bus        (fs2ds_bus),

  .mem_forward_zip  (mem_forward_zip),
  .exe_forward_zip  (exe_forward_zip),
  
  .res_from_mul     (res_from_mul),
  .es_block         (es_block),
  .block            (block),

  .ms_ex            (ms_ex),
  .wb_ex            (wb_ex | ertn_flush),
  .ms_csr_re        (ms_csr_re),
  .es_csr_re        (es_csr_re)
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

  .data_sram_en     (data_sram_en),
  .data_sram_we     (data_sram_we),
  .data_sram_addr   (data_sram_addr),
  .data_sram_wdata  (data_sram_wdata),

  .exe_forward_zip  (exe_forward_zip),

  .res_from_mul     (res_from_mul),
  .exe_res_from_mul (exe_res_from_mul),
  .es_block         (es_block),
  .block            (block),
  .mul_result       (mul_result),

  .ms_ex            (ms_ex),
  .wb_ex            (wb_ex | ertn_flush),
  .es_csr_re        (es_csr_re)
);

MEMstage my_mem (
  .clk              (clk),
  .resetn           (resetn),
  .reset            (reset),
  .data_sram_rdata  (data_sram_rdata),
  
  .ws_allowin       (ws_allowin),
  .ms_allowin       (ms_allowin),
  .es2ms_valid      (es2ms_valid),
  .ms2ws_valid      (ms2ws_valid),
  
  .es2ms_bus        (es2ms_bus),
  .ms2ws_bus        (ms2ws_bus),
  
  .exe_res_from_mul (exe_res_from_mul),
  .mem_forward_zip  (mem_forward_zip),
  .mul_result       (mul_result),

  .ms_ex            (ms_ex),
  .wb_ex            (wb_ex | ertn_flush),
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
  .ertn_flush       (ertn_flush),
  .wb_ex            (wb_ex),
  .ws2csr_bus       (ws2csr_bus)
);

  csr u_csr(
    .clk            (clk       ),
    .reset          (reset   ),
    .csr_rvalue     (csr_rvalue),
    .ex_entry       (ex_entry  ),
    .ertn_entry     (ertn_entry),
    .ertn_flush     (ertn_flush),
    .wb_ex          (wb_ex     ),
    .ws2csr_bus     (ws2csr_bus)
    );

endmodule