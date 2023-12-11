`ifndef BUS_LEN

    `define BR_BUS        34
    `define FS2DS_BUS_LEN 103  //fs_exc_ecode,fs_exc_data, fs_pc, inst
    `define DS2ES_BUS_LEN 309 //es_pc, alu_src1, alu_src2, alu_op,load_op,store_op, rkd_value, gr_we, dest, mem_we,ds_exc_data, time_op
    `define ES2MS_BUS_LEN 231  //ms_pc, mul_op,mem_gr_we, mem_dest, final_result,es_rl_value, es_exc_date
    `define MS2WS_BUS_LEN 219  //wms_refetch_flg,ms_inst_tlbsrch,ms_inst_tlbrd,ms_inst_tlbwr,ms_inst_tlbfill,ms_tlbsrch_hit,ms_tlbsrch_hit_index, ms_pc, mem_gr_we, mem_dest,  mem_final_result, mem_rkd_value,mem_exc_data
    
    `define FORWARD_BUS_LEN 38
    `define WS_TO_FS_CSR_DATA_LEN 200
    `define FS_EXC_DATA_WD  33
    `define DS_EXC_DATA_WD  102
    `define ES_EXC_DATA_WD  101
    `define MS_EXC_DATA_WD  101

`endif