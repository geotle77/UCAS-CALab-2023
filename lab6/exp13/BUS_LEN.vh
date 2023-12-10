`ifndef BUS_LEN

    `define BR_BUS        33
    `define FS2DS_BUS_LEN 97  //fs_exc_data, fs_pc, inst
    `define DS2ES_BUS_LEN 262 //es_pc, alu_src1, alu_src2, alu_op,load_op,store_op, rkd_value, gr_we, dest, mem_we,ds_exc_data, time_op
    `define ES2MS_BUS_LEN 208  //ms_pc, mul_op,mem_gr_we, mem_dest, final_result,es_rl_value, es_exc_date
    `define MS2WS_BUS_LEN 199
    
    `define FORWARD_BUS_LEN 38
    `define WS_TO_FS_CSR_DATA_LEN 200
    `define FS_EXC_DATA_WD  33
    `define DS_EXC_DATA_WD  98
    `define ES_EXC_DATA_WD  97
    `define MS_EXC_DATA_WD  97

`endif