`include "BUS_LEN.vh"
module mycpu_core (
    input  wire                         clk,
    input  wire                         resetn,

    // inst sram interf                 ace
    output wire                         inst_sram_req,
    output wire                         inst_sram_wr,
    output wire [ 1:0]                  inst_sram_size,
    output wire [ 3:0]                  inst_sram_wstrb,
    output wire [31:0]                  inst_sram_addr,
    output wire [31:0]                  inst_sram_wdata,
    input  wire [31:0]                  inst_sram_rdata,
    input  wire                         inst_sram_addr_ok,
    input  wire                         inst_sram_data_ok,

    // data sram interf                 ace
    output wire                         data_sram_req,
    output wire                         data_sram_wr,
    output wire [ 3:0]                  data_sram_wstrb,
    output wire [ 1:0]                  data_sram_size,
    output wire [31:0]                  data_sram_addr,
    output wire [31:0]                  data_sram_wdata,
    input  wire [31:0]                  data_sram_rdata,
    input  wire                         data_sram_addr_ok,
    input  wire                         data_sram_data_ok,

    // trace debug inte                 rface
    output wire [31:0]                  debug_wb_pc,
    output wire [ 3:0]                  debug_wb_rf_we,
    output wire [ 4:0]                  debug_wb_rf_wnum,
    output wire [31:0]                  debug_wb_rf_wdata
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
wire [`BR_BUS-1:0]          br_zip;
wire [`WB_RF_BUS-1:0]       rf_zip;

wire  es_block;
wire  es_mem_block;
wire  ms_mem_block;
wire  mul_block;

wire [`FS2DS_BUS_LEN -1:0]     fs2ds_bus;
wire [`DS2ES_BUS_LEN -1:0]     ds2es_bus;
wire [`ES2MS_BUS_LEN -1:0]     es2ms_bus;
wire [`MS2WS_BUS_LEN -1:0]     ms2ws_bus;
wire [`WS2CSR_BUS_LEN-1:0]    ws2csr_bus;

wire [67:0] mul_result;

wire [31:0] csr_ex_entry;
wire [31:0] csr_ertn_entry;
wire [31:0] csr_rvalue;
wire        ertn_flush;
wire        ms_ex;
wire        wb_ex;

wire ms_csr_re;
wire es_csr_re;
wire ds_has_int;
wire ws_reflush;
wire ms_ex_to_es;
wire csr_has_int;



wire [ 9:0] csr_asid_asid;
wire [18:0] csr_tlbehi_vppn;
wire [ 3:0] csr_tlbidx_index;

wire        ms_csr_tlbrd;
wire        ws_csr_tlbrd;

wire        tlbrd_we;
wire        tlbsrch_we;
wire        tlbsrch_hit;
wire [ 3:0] tlbsrch_hit_index;

// TLB ports
wire [18:0] s0_vppn;
wire        s0_va_bit12;
wire [ 9:0] s0_asid;
wire        s0_found;
wire [ 3:0] s0_index;
wire [19:0] s0_ppn;
wire [ 5:0] s0_ps;
wire [ 1:0] s0_plv;
wire [ 1:0] s0_mat;
wire        s0_d;
wire        s0_v;
wire [18:0] s1_vppn;
wire        s1_va_bit12;
wire [ 9:0] s1_asid;
wire        s1_found;
wire [ 3:0] s1_index;
wire [19:0] s1_ppn;
wire [ 5:0] s1_ps;
wire [ 1:0] s1_plv;
wire [ 1:0] s1_mat;
wire        s1_d;
wire        s1_v;
wire [ 4:0] invtlb_op;
wire        invtlb_valid;
wire        we;
wire [ 3:0] w_index;
wire        w_e;
wire [18:0] w_vppn;
wire [ 5:0] w_ps;
wire [ 9:0] w_asid;
wire        w_g;
wire [19:0] w_ppn0;
wire [ 1:0] w_plv0;
wire [ 1:0] w_mat0;
wire        w_d0;
wire        w_v0;
wire [19:0] w_ppn1;
wire [ 1:0] w_plv1;
wire [ 1:0] w_mat1;
wire        w_d1;
wire        w_v1;
wire [ 3:0] r_index;
wire        r_e;
wire [18:0] r_vppn;
wire [ 5:0] r_ps;
wire [ 9:0] r_asid;
wire        r_g;
wire [19:0] r_ppn0;
wire [ 1:0] r_plv0;
wire [ 1:0] r_mat0;
wire        r_d0;
wire        r_v0;
wire [19:0] r_ppn1;
wire [ 1:0] r_plv1;
wire [ 1:0] r_mat1;
wire        r_d1;
wire        r_v1;

wire [19:0] s0_va_highbits;
wire [ 9:0] s0_asid;

//exp 19
wire [31:0] csr_crmd_rvalue;
wire [31:0] csr_asid_rvalue;
wire [31:0] csr_dmw0_rvalue;
wire [31:0] csr_dmw1_rvalue;

wire[31:0] fs_va;
wire[31:0] fs_pa;
wire[9 :0] fs_asid;
wire[5 :0] fs_exc_ecode;
wire[5 :0] es_exc_ecode;

wire[1 :0] fs_plv;
wire       fs_dmwhit;
wire[31:0] es_va;
wire[31:0] es_pa;
wire[1 :0] es_plv;
wire       es_dmwhit;
wire[1 :0] es_mmu_en;

IFstage my_if (
    .clk                    (clk),
    .resetn                 (resetn),

    .inst_sram_en           (inst_sram_req    ),
    .inst_sram_wr           (inst_sram_wr     ),
    .inst_sram_we           (inst_sram_wstrb  ),
    .inst_sram_size         (inst_sram_size   ),
    .inst_sram_addr         (inst_sram_addr   ),
    .inst_sram_wdata        (inst_sram_wdata  ),
    .inst_sram_rdata        (inst_sram_rdata  ),
    .inst_sram_addr_ok      (inst_sram_addr_ok),
    .inst_sram_data_ok      (inst_sram_data_ok),

    .br_zip                 (br_zip),
    .fs2ds_bus              (fs2ds_bus),
    .ds_allowin             (ds_allowin),
    .fs2ds_valid            (fs2ds_valid),

    .csr_ex_entry           (csr_ex_entry  ),
    .csr_ertn_entry         (csr_ertn_entry),
    .ertn_flush             (ertn_flush),
    .wb_ex                  (wb_ex     ),
    .fs_reflush             (ws_reflush),

    .s0_va_highbits         ({s0_vppn, s0_va_bit12}),/*TODO:Note that these two lines should have been placed in the MMU module as well, 
                                            to ensure that the tlb and pipeline stages are completely isolated, i.e., IF decoding is handled entirely by the MMU, 
                                            but the EXE address translation reuses a bit of the tlb instruction datapath, 
                                            so it's not good for compatibility, and so for now, it's still placed here.EXE is same.*/
    .s0_asid                (s0_asid), 

    //mmu module
    .va                     (fs_va),
    .pa                     (fs_pa),
    .plv                    (fs_plv),
    .dmw_hit                (fs_dmwhit),
    .mmu_asid               (fs_asid),
    .fs_exc_ecode           (fs_exc_ecode)
);

MMU IF_mmu(
  .flag(2'b10),
  
  .csr_crmd_rvalue          (csr_crmd_rvalue),
  .csr_asid_rvalue          (csr_asid_rvalue),
  .csr_dmw0_rvalue          (csr_dmw0_rvalue),
  .csr_dmw1_rvalue          (csr_dmw1_rvalue),

  .s_found                  (s0_found),
  .s_index                  (s0_index),
  .s_ppn                    (s0_ppn),
  .s_ps                     (s0_ps),
  .s_plv                    (s0_plv),
  .s_mat                    (s0_mat),
  .s_d                      (s0_d),
  .s_v                      (s0_v),
  
    //mmu module
  .dmw_hit                  (fs_dmwhit),
  .plv                      (fs_plv),
  .va                       (fs_va),
  .exc_ecode                (fs_exc_ecode),
  .s_asid                   (fs_asid),
  .pa                       (fs_pa)
);

IDstage my_id (
    .clk                    (clk),
    .reset                  (reset),

    .es_allowin             (es_allowin),
    .ds_allowin             (ds_allowin),
    .fs2ds_valid            (fs2ds_valid),
    .ds2es_valid            (ds2es_valid),

    .br_zip                 (br_zip),
    .ds2es_bus              (ds2es_bus),
    .fs2ds_bus              (fs2ds_bus),

    .mem_forward_zip        (mem_forward_zip),
    .exe_forward_zip        (exe_forward_zip),
    .rf_zip                 (rf_zip),

    .es_block               (es_block),
    .es_mem_block           (es_mem_block),
    .ms_mem_block           (ms_mem_block),
    .mul_block                  (mul_block),

    .ms_csr_re              (ms_csr_re),
    .es_csr_re              (es_csr_re),
    .ds_has_int             (csr_has_int),
    .ds_reflush             (ws_reflush)
);


EXEstage my_exe (
    .clk                    (clk),
    .resetn                 (resetn),
    .reset                  (reset),

    .ms_allowin             (ms_allowin),
    .es_allowin             (es_allowin),
    .ds2es_valid            (ds2es_valid),
    .es2ms_valid            (es2ms_valid),

    .ds2es_bus              (ds2es_bus),
    .es2ms_bus              (es2ms_bus),

    .data_sram_en           (data_sram_req    ),
    .data_sram_wr           (data_sram_wr     ),
    .data_sram_we           (data_sram_wstrb  ),     
    .data_sram_size         (data_sram_size   ),
    .data_sram_addr         (data_sram_addr   ),
    .data_sram_wdata        (data_sram_wdata  ),
    .data_sram_addr_ok      (data_sram_addr_ok),

    .exe_forward_zip        (exe_forward_zip),

    .es_block               (es_block),
    .es_mem_block           (es_mem_block),
    .mul_block              (mul_block),

    .mul_result             (mul_result),

    .ms_ex_to_es            (ms_ex_to_es),
    .es_csr_re              (es_csr_re),
    .es_reflush             (ws_reflush),

    // exp 18       
    .s1_va_highbits         ({s1_vppn, s1_va_bit12}),
    .s1_asid                (s1_asid),
    .invtlb_valid           (invtlb_valid),
    .invtlb_op              (invtlb_op),
    .s1_found               (s1_found),
    .s1_index               (s1_index),
    .csr_asid_asid          (csr_asid_asid),
    .csr_tlbehi_vppn        (csr_tlbehi_vppn),
    .ms_csr_tlbrd           (ms_csr_tlbrd),
    .ws_csr_tlbrd           (ws_csr_tlbrd),
    // exp 19
    .es_exc_ecode           (es_exc_ecode),
    .dmw_hit                (es_dmwhit),
    .plv                    (es_plv),
    .va                     (es_va),
    .pa                     (es_pa),
    .mmu_en                 (es_mmu_en)
);

MMU EXE_mmu(
    .flag                   (es_mmu_en),
    .csr_crmd_rvalue        (csr_crmd_rvalue),
    .csr_asid_rvalue        (csr_asid_rvalue),
    .csr_dmw0_rvalue        (csr_dmw0_rvalue),
    .csr_dmw1_rvalue        (csr_dmw1_rvalue),
    
    .s_found                (s1_found),
    .s_index                (s1_index),
    .s_ppn                  (s1_ppn),
    .s_ps                   (s1_ps),
    .s_plv                  (s1_plv),
    .s_mat                  (s1_mat),
    .s_d                    (s1_d),
    .s_v                    (s1_v),
    
    .va                     (es_va),
    .exc_ecode              (es_exc_ecode),
    .dmw_hit                (es_dmwhit),
    .plv                    (es_plv),
    .pa                     (es_pa)
);

MEMstage my_mem (
    .clk                    (clk),
    .resetn                 (resetn),
    .reset                  (reset),

    .data_sram_rdata        (data_sram_rdata ),
    .data_sram_data_ok      (data_sram_data_ok),
    
    .ws_allowin             (ws_allowin),
    .ms_allowin             (ms_allowin),
    .es2ms_valid            (es2ms_valid),
    .ms2ws_valid            (ms2ws_valid),

    .es2ms_bus              (es2ms_bus),
    .ms2ws_bus              (ms2ws_bus),
    .mem_forward_zip        (mem_forward_zip),

    .mul_result             (mul_result),
    .ms_mem_block           (ms_mem_block),
    .ms_ex_to_es            (ms_ex_to_es),
    .ms_reflush             (ws_reflush),
    .ms_csr_re              (ms_csr_re),

    .ms_csr_tlbrd           (ms_csr_tlbrd)
);


WBstage my_wb (
    .clk                    (clk),
    .resetn                 (resetn),
    .reset                  (reset),

    .ws_allowin             (ws_allowin),
    .ms2ws_valid            (ms2ws_valid),

    .ms2ws_bus              (ms2ws_bus),
    .rf_zip                 (rf_zip),

    .debug_wb_pc            (debug_wb_pc),
    .debug_wb_rf_we         (debug_wb_rf_we),
    .debug_wb_rf_wnum       (debug_wb_rf_wnum),
    .debug_wb_rf_wdata      (debug_wb_rf_wdata),

    .csr_rvalue             (csr_rvalue),
    .ws_ertn_flush          (ertn_flush),
    .ws_reflush             (ws_reflush),
    .ws_ex                  (wb_ex),
    .ws2csr_bus             (ws2csr_bus),
    
    .ws_csr_tlbrd           (ws_csr_tlbrd)

);


csr u_csr(
    .clk                    (clk       ),
    .reset                  (reset   ),
    .csr_rvalue             (csr_rvalue),
    .ex_entry               (csr_ex_entry  ),
    .ertn_entry             (csr_ertn_entry),
    .ertn_flush             (ertn_flush),
    .wb_ex                  (wb_ex     ),
    .ws2csr_bus             (ws2csr_bus),
    .has_int                (csr_has_int),

    // exp 18
    .csr_asid_asid          (csr_asid_asid),
    .csr_tlbehi_vppn        (csr_tlbehi_vppn),

    .w_index                (w_index),
    .we                     (we),
    .r_index                (r_index),

    .r_tlb_e                (r_e),
    .r_tlb_ps               (r_ps),
    .r_tlb_vppn             (r_vppn),
    .r_tlb_asid             (r_asid),
    .r_tlb_g                (r_g),
    .r_tlb_ppn0             (r_ppn0),
    .r_tlb_plv0             (r_plv0),
    .r_tlb_mat0             (r_mat0),
    .r_tlb_d0               (r_d0),
    .r_tlb_v0               (r_v0),
    .r_tlb_ppn1             (r_ppn1),
    .r_tlb_plv1             (r_plv1),
    .r_tlb_mat1             (r_mat1),
    .r_tlb_d1               (r_d1),
    .r_tlb_v1               (r_v1),

    .w_tlb_e                (w_e),
    .w_tlb_ps               (w_ps),
    .w_tlb_vppn             (w_vppn),
    .w_tlb_asid             (w_asid),
    .w_tlb_g                (w_g),
    .w_tlb_ppn0             (w_ppn0),
    .w_tlb_plv0             (w_plv0),
    .w_tlb_mat0             (w_mat0),
    .w_tlb_d0               (w_d0),
    .w_tlb_v0               (w_v0),
    .w_tlb_ppn1             (w_ppn1),
    .w_tlb_plv1             (w_plv1),
    .w_tlb_mat1             (w_mat1),
    .w_tlb_d1               (w_d1),
    .w_tlb_v1               (w_v1),

    .csr_crmd_rvalue        (csr_crmd_rvalue),
    .csr_asid_rvalue        (csr_asid_rvalue),
    .csr_dmw0_rvalue        (csr_dmw0_rvalue),
    .csr_dmw1_rvalue        (csr_dmw1_rvalue)
);


tlb #(.TLBNUM(16)) u_tlb(
    .clk                    (clk),

    .s0_vppn                (s0_vppn),
    .s0_va_bit12            (s0_va_bit12),
    .s0_asid                (s0_asid),
    .s0_found               (s0_found),
    .s0_index               (s0_index),
    .s0_ppn                 (s0_ppn),
    .s0_ps                  (s0_ps),
    .s0_plv                 (s0_plv),
    .s0_mat                 (s0_mat),
    .s0_d                   (s0_d),
    .s0_v                   (s0_v),

    .s1_vppn                (s1_vppn),
    .s1_va_bit12            (s1_va_bit12),
    .s1_asid                (s1_asid),
    .s1_found               (s1_found),
    .s1_index               (s1_index),
    .s1_ppn                 (s1_ppn),
    .s1_ps                  (s1_ps),
    .s1_plv                 (s1_plv),
    .s1_mat                 (s1_mat),
    .s1_d                   (s1_d),
    .s1_v                   (s1_v),

    .invtlb_op              (invtlb_op),
    .invtlb_valid           (invtlb_valid),
    
    .we                     (we),
    .w_index                (w_index),
    .w_e                    (w_e),
    .w_vppn                 (w_vppn),
    .w_ps                   (w_ps),
    .w_asid                 (w_asid),
    .w_g                    (w_g),
            
    .w_ppn0                 (w_ppn0),
    .w_plv0                 (w_plv0),
    .w_mat0                 (w_mat0),
    .w_d0                   (w_d0),
    .w_v0                   (w_v0),
            
    .w_ppn1                 (w_ppn1),
    .w_plv1                 (w_plv1),
    .w_mat1                 (w_mat1),
    .w_d1                   (w_d1),
    .w_v1                   (w_v1),
            
    .r_index                (r_index),
    .r_e                    (r_e),
    .r_vppn                 (r_vppn),
    .r_ps                   (r_ps),
    .r_asid                 (r_asid),
    .r_g                    (r_g),
            
    .r_ppn0                 (r_ppn0),
    .r_plv0                 (r_plv0),
    .r_mat0                 (r_mat0),
    .r_d0                   (r_d0),
    .r_v0                   (r_v0),
            
    .r_ppn1                 (r_ppn1),
    .r_plv1                 (r_plv1),
    .r_mat1                 (r_mat1),
    .r_d1                   (r_d1),
    .r_v1                   (r_v1)
);

endmodule