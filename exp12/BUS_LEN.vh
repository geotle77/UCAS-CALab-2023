`ifndef BUS_LEN
    `define BUS_LEN

    `define FS2DS_BUS_LEN 64  //fs_pc, inst
    `define FORWARD_BUS_LEN 38
    `define DS2ES_BUS_LEN 244 //es_pc, alu_src1, alu_src2, alu_op,load_op,store_op, rkd_value, gr_we, dest, mem_we,except_zip
    `define ES2MS_BUS_LEN 160//ms_pc, mul_op,mem_gr_we, mem_dest, final_result,except_zip
    `define MS2WS_BUS_LEN 152
    `define WS2CSR_BUS_LEN 127
    
    `define FORWARD_BUS_LEN 38
    
    `define EXCEPT_LEN 82
    `define ALU_OP_LEN 19
    `define WB_RF_BUS 38
    `define BR_BUS 33
    
    
        `define CSR_CRMD   14'h00
    `define CSR_PRMD   14'h01
    `define CSR_EUEN   14'h02
    `define CSR_ECFG   14'h04
    `define CSR_ESTAT  14'h05
    `define CSR_ERA    14'h06
    `define CSR_BADV   14'h07
    `define CSR_EENTRY 14'h0c
    `define CSR_SAVE0  14'h30
    `define CSR_SAVE1  14'h31
    `define CSR_SAVE2  14'h32
    `define CSR_SAVE3  14'h33
    `define CSR_TID    14'h40
    `define CSR_TCFG   14'h41
    `define CSR_TVAL   14'h42
    `define CSR_TICLR  14'h44

    `define CSR_CRMD_PLV    1 :0
    `define CSR_CRMD_IE     2
    `define CSR_PRMD_PPLV   1 :0
    `define CSR_PRMD_PIE    2
    `define CSR_ECFG_LIE    12:0
    `define CSR_ESTAT_IS10  1 :0
    `define CSR_ERA_PC      31:0
    `define CSR_EENTRY_VA   31:6
    `define CSR_SAVE_DATA   31:0
    `define CSR_TID_TID     31:0
`endif