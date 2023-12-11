`ifndef CSR 
    `define WS2CSR_BUS_LEN 201
    
    `define EXCEPT_LEN 82
    `define ALU_OP_LEN 19
    `define WB_RF_BUS 38
   
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
    `define CSR_TICLR_CLR   0
    // exp13
    
    `define CSR_TCFG_EN     0
    `define CSR_TCFG_PERIOD 1
    `define CSR_TCFG_INITV  31:2
    
    `define ECODE_INT       6'h0
    `define ECODE_ADE       6'h8
    `define ECODE_ALE       6'h9
    `define ECODE_BRK       6'hc
    `define ECODE_INE       6'hd
    `define ESUBCODE_ADEF   9'h0
    `define ECODE_SYS       6'hb




    // exp18
    `define CSR_TLBIDX     14'h010
    `define CSR_TLBEHI     14'h011
    `define CSR_TLBELO0    14'h012
    `define CSR_TLBELO1    14'h013
    `define CSR_ASID       14'h018
    `define CSR_TLBRENTRY  14'h088

    // CRMD
    `define CSR_CRMD_DA     3
    `define CSR_CRMD_PG     4
    `define CSR_CRMD_DATF   6:5
    `define CSR_CRMD_DATM   8:7

    // TLBIDX
    `define CSR_TLBIDX_INDEX    3:0
    `define CSR_TLBIDX_PS       29:24
    `define CSR_TLBIDX_NE       31
    // TLBEHI
    `define CSR_TLBEHI_VPPN     31:13
    // TLBELO0 TLBELO1
    `define CSR_TLBELO_V        0
    `define CSR_TLBELO_D        1
    `define CSR_TLBELO_PLV      3:2
    `define CSR_TLBELO_MAT      5:4
    `define CSR_TLBELO_G        6
    `define CSR_TLBELO_PPN      31:8
    // ASID
    `define CSR_ASID_ASID       9:0
    // TLBRENTRY
    `define CSR_TLBRENTRY_PA    31:6

    //exp19
    `define CSR_DMW0            14'h180
    `define CSR_DMW1            14'h181

    `define CSR_DMW_PLV0        0
    `define CSR_DMW_PLV3        3
    `define CSR_DMW_MAT         5:4
    `define CSR_DMW_PSEG        27:25
    `define CSR_DMW_VSEG        31:29

    `define ECODE_PIL           6'h1
    `define ECODE_PIS           6'h2
    `define ECODE_PIF           6'h3
    `define ECODE_PME           6'h4
    `define ECODE_PPI           6'h7 
    `define ECODE_TLBR          6'h3f
    `define ESUBCODE_ADEM       9'h1
    
`endif