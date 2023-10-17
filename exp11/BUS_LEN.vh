`ifndef BUS_LEN
    `define BUS_LEN

    `define FS2DS_BUS_LEN 64
    `define DS2ES_BUS_LEN 163 //pc, alu_src1, alu_src2, alu_op,load_op,store_op, rkd_value, gr_we, dest, mem_we
    `define ES2MS_BUS_LEN 94//
    `define MS2WS_BUS_LEN 70
    
    `define ALU_OP_LEN 19
    `define WB_RF_BUS 38
`endif