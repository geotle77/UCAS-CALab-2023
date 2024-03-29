`include "CSR.vh"
module csr(
    input  wire          clk       ,
    input  wire          reset     ,

    output wire [31:0]   csr_rvalue,
    output wire [31:0]   ex_entry  ,
    output wire [31:0]   ertn_entry,

    input  wire          ertn_flush,

    input  wire          wb_ex     ,
    input  wire [`WS2CSR_BUS_LEN-1 : 0] ws2csr_bus,
    //exp13
    output wire          has_int
);
    //ws2csr_bus
    wire csr_re;
    wire csr_we;
    wire [13:0] csr_num;
    wire [31:0] csr_wmask;
    wire [31:0] csr_wvalue;
    wire  [31:0] wb_pc;
    wire [ 5:0] wb_ecode;
    wire [ 8:0] wb_esubcode;
    wire ipi_int_in;
    wire [31:0] coreid_in;
    wire [ 7:0] hw_int_in;
    wire [31:0] wb_vaddr;
    assign {csr_re, csr_we, csr_num, csr_wmask, csr_wvalue, wb_pc, wb_ecode, wb_esubcode, ipi_int_in, coreid_in, hw_int_in, wb_vaddr} = ws2csr_bus;

    // CRMD
    wire [31: 0] csr_crmd_rvalue;
    reg  [ 1: 0] csr_crmd_plv;      //CRMD's PLV domain, current privilege level
    reg          csr_crmd_ie;       //CRMD's global interrupt enable signal
    reg          csr_crmd_da;       //CRMD's direct address translation enable signal
    reg          csr_crmd_pg;
    reg  [ 6: 5] csr_crmd_datf;
    reg  [ 8: 7] csr_crmd_datm;

    // PRMD
    wire [31: 0] csr_prmd_rvalue;
    reg  [ 1: 0] csr_prmd_pplv;     //Old value of CRMD's PLV field
    reg          csr_prmd_pie;      //Old value of CRMD's PIE field

    // ESTAT
    wire [31: 0] csr_estat_rvalue;    
    reg  [12: 0] csr_estat_is;      // Status bits for exception interrupts, 8 hardware interrupts + 1 timer interrupt + 1 inter-core interrupt + 2 software interrupts)
    reg  [ 5: 0] csr_estat_ecode;   // Exception type level-1 code
    reg  [ 8: 0] csr_estat_esubcode;// Exception type level-2 code

    // ERA
    reg  [31: 0] csr_era_data;  
    wire [31: 0] csr_era_rvalue;

    // EENTRY
    wire [31: 0] csr_eentry_rvalue;   
    reg  [25: 0] csr_eentry_va;     // Exception Interrupt Entry High Address
    
    // SAVE0-3
    reg  [31: 0] csr_save0_data;
    reg  [31: 0] csr_save1_data;
    reg  [31: 0] csr_save2_data;
    reg  [31: 0] csr_save3_data;
    wire [31:0] csr_save0_rvalue;
    wire [31:0] csr_save1_rvalue;
    wire [31:0] csr_save2_rvalue;
    wire [31:0] csr_save3_rvalue;

    assign ex_entry = csr_eentry_rvalue;
    assign ertn_entry = csr_era_rvalue;

    // ECFG
    reg [12:0] csr_ecfg_lie;
    wire [31:0] csr_ecfg_rvalue;
    
    // BADV
    wire wb_ex_addr_err;
    reg [31:0] csr_badv_vaddr;
    wire [31:0] csr_badv_rvalue;

    // TID 
    reg [31:0] csr_tid_tid ;
    wire [31:0] csr_tid_rvalue;

    // TCFG
    reg csr_tcfg_en ; 
    reg csr_tcfg_periodic ;
    reg [29:0] csr_tcfg_initval ;
    wire [31:0] csr_tcfg_rvalue ;

    // TVAL
    wire [31:0] tcfg_next_value ;
    reg  [31:0] timer_cnt ;
    wire [31:0] csr_tval_timeval;
    wire [31:0] csr_tval_rvalue ;

    // TICLR
    wire csr_ticlr_clr ;
    wire [31:0] csr_ticlr_rvalue ;


    // CRMD's PLV、IE field
    always @(posedge clk) begin
        if (reset) begin
            csr_crmd_plv <= 2'b0;
            csr_crmd_ie  <= 1'b0;
        end
        else if (wb_ex) begin
            csr_crmd_plv <= 2'b0;
            csr_crmd_ie  <= 1'b0;
        end
        else if (ertn_flush) begin
            csr_crmd_plv <= csr_prmd_pplv;
            csr_crmd_ie  <= csr_prmd_pie;
        end
        else if (csr_we && csr_num == `CSR_CRMD) begin
            csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV]
                          | ~csr_wmask[`CSR_CRMD_PLV] & csr_crmd_plv;
            csr_crmd_ie  <= csr_wmask[`CSR_CRMD_IE ] & csr_wvalue[`CSR_CRMD_IE ]
                          | ~csr_wmask[`CSR_CRMD_IE ] & csr_crmd_ie;
        end
    end

    // DA, PG, DATF, DATM domains of CRMD: consider reset and write
    always @(posedge clk) begin
        if(reset) begin
            csr_crmd_da   <= 1'b1;
            csr_crmd_pg   <= 1'b0;
            csr_crmd_datf <= 2'b0;
            csr_crmd_datm <= 2'b0;
        end
        else if (csr_we && csr_estat_ecode == 6'h3f) begin
            csr_crmd_da   <= 1'b0;
            csr_crmd_pg   <= 1'b1;
            csr_crmd_datf <= 2'b01;
            csr_crmd_datm <= 2'b01;            
        end
    end

    // PPLV, PIE domains for PRMD: considering exceptions and writes
    always @(posedge clk) begin
        if (wb_ex) begin
            csr_prmd_pplv <= csr_crmd_plv;
            csr_prmd_pie  <= csr_crmd_ie;
        end
        else if (csr_we && csr_num==`CSR_PRMD) begin
            csr_prmd_pplv <=  csr_wmask[`CSR_PRMD_PPLV] & csr_wvalue[`CSR_PRMD_PPLV]
                           | ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
            csr_prmd_pie  <=  csr_wmask[`CSR_PRMD_PIE ] & csr_wvalue[`CSR_PRMD_PIE ]
                           | ~csr_wmask[`CSR_PRMD_PIE ] & csr_prmd_pie;
        end
    end

    // The IS domain of ESTAT: considering resets and writes
    always @(posedge clk) begin
        if (reset) begin
            csr_estat_is[1:0] <= 2'b0;
        end
        else if (csr_we && (csr_num == `CSR_ESTAT)) begin
            csr_estat_is[1:0] <= ( csr_wmask[`CSR_ESTAT_IS10] & csr_wvalue[`CSR_ESTAT_IS10])
                               | (~csr_wmask[`CSR_ESTAT_IS10] & csr_estat_is[1:0]          );
        end

        csr_estat_is[9:2] <= 8'b0;
        csr_estat_is[ 10] <= 1'b0;
        //exp13
        if (csr_tcfg_en && timer_cnt[31:0] == 32'b0)
            csr_estat_is[11] <= 1'b1;
        else if (csr_we && csr_num == `CSR_TICLR 
                        && csr_wmask[`CSR_TICLR_CLR] 
                        && csr_wvalue[`CSR_TICLR_CLR]) 
            csr_estat_is[11] <= 1'b0;              
            csr_estat_is[12] <= ipi_int_in;
    end    

    // ESTAT's Ecode and EsubCode domains: considering only the exceptions
    always @(posedge clk) begin
        if (wb_ex) begin
            csr_estat_ecode    <= wb_ecode;
            csr_estat_esubcode <= wb_esubcode;
        end
    end

    // ERA's PC domain: considering exceptions and writes
    always @(posedge clk) begin
        if(wb_ex)
            csr_era_data <= wb_pc;
        else if (csr_we && csr_num == `CSR_ERA) 
            csr_era_data <= csr_wmask[`CSR_ERA_PC] & csr_wvalue[`CSR_ERA_PC]
                        | ~csr_wmask[`CSR_ERA_PC] & csr_era_rvalue;
    end

     // EENTRY
    always @(posedge clk) begin
        if (csr_we && (csr_num == `CSR_EENTRY))
            csr_eentry_va <=   csr_wmask[`CSR_EENTRY_VA] & csr_wvalue[`CSR_EENTRY_VA]
                            | ~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va ;
    end

    // SAVE0~3
    always @(posedge clk) begin
        if (csr_we && csr_num == `CSR_SAVE0) 
            csr_save0_data <=  csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA] & csr_save0_data;
        if (csr_we && (csr_num == `CSR_SAVE1)) 
            csr_save1_data <=  csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA] & csr_save1_data;
        if (csr_we && (csr_num == `CSR_SAVE2)) 
            csr_save2_data <=  csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA] & csr_save2_data;
        if (csr_we && (csr_num == `CSR_SAVE3)) 
            csr_save3_data <=  csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA] & csr_save3_data;
    end

    //exp13
    // ECFG
    always @(posedge clk) begin
        if(reset)
            csr_ecfg_lie <= 13'b0;
        else if(csr_we && csr_num == `CSR_ECFG)
            csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE] & csr_wvalue[`CSR_ECFG_LIE]
                        | ~csr_wmask[`CSR_ECFG_LIE] & csr_ecfg_lie;
    end

    // BADV
    assign wb_ex_addr_err = wb_ecode==`ECODE_ADE || wb_ecode==`ECODE_ALE;
    always @(posedge clk) begin
        if (wb_ex && wb_ex_addr_err)
            csr_badv_vaddr <= (wb_ecode == `ECODE_ADE && 
                               wb_esubcode == `ESUBCODE_ADEF) ? wb_pc : wb_vaddr;
    end

    // TID
    always @(posedge clk) begin
        if (reset)
            csr_tid_tid <= coreid_in;
        else if (csr_we && csr_num==`CSR_TID)
            csr_tid_tid <= csr_wmask[`CSR_TID_TID] & csr_wvalue[`CSR_TID_TID]
                        | ~csr_wmask[`CSR_TID_TID] & csr_tid_tid;
    end

    // TCFG
    always @(posedge clk) begin
        if (reset)
            csr_tcfg_en <= 1'b0;
        else if (csr_we && csr_num==`CSR_TCFG)
            csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN] & csr_wvalue[`CSR_TCFG_EN] 
                        | ~csr_wmask[`CSR_TCFG_EN] & csr_tcfg_en;

        if (csr_we && csr_num==`CSR_TCFG) begin
            csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIOD] & csr_wvalue[`CSR_TCFG_PERIOD]
                              | ~csr_wmask[`CSR_TCFG_PERIOD] & csr_tcfg_periodic;
            csr_tcfg_initval  <= csr_wmask[`CSR_TCFG_INITV] & csr_wvalue[`CSR_TCFG_INITV]
                              | ~csr_wmask[`CSR_TCFG_INITV] & csr_tcfg_initval;
        end
    end

    // TVAL
    assign tcfg_next_value =  csr_wmask[31:0] & csr_wvalue[31:0]
                            | ~csr_wmask[31:0] & {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};

    always @(posedge clk) begin
        if (reset)
            timer_cnt <= 32'hffffffff;
        else if (csr_we && csr_num == `CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
            timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITV], 2'b0};
        else if (csr_tcfg_en && timer_cnt != 32'hffffffff) begin
            if (timer_cnt[31:0] == 32'b0 && csr_tcfg_periodic)
                timer_cnt <= {csr_tcfg_initval, 2'b0};
            else
                timer_cnt <= timer_cnt - 1'b1;
        end
    end
    assign csr_tval_timeval = timer_cnt[31:0];

    // TICLR
    assign csr_ticlr_clr = 1'b0;


    // Readout data for CSR read instructions: re-spliced with fields to complete register contents, read back data selected by register number
    assign csr_crmd_rvalue   = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, 
                                csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
    assign csr_prmd_rvalue   = {29'b0, csr_prmd_pie, csr_prmd_pplv};
    assign csr_estat_rvalue  = {1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};
    assign csr_eentry_rvalue = {csr_eentry_va, 6'b0};
    assign csr_era_rvalue    =  csr_era_data;  
    assign csr_save0_rvalue  =  csr_save0_data;
    assign csr_save1_rvalue  =  csr_save1_data;
    assign csr_save2_rvalue  =  csr_save2_data;
    assign csr_save3_rvalue  =  csr_save3_data;
    
    //exp13
    assign csr_ecfg_rvalue   =  {19'b0, csr_ecfg_lie[12:11],1'b0,csr_ecfg_lie[9:0]};
    assign csr_badv_rvalue   =  csr_badv_vaddr;
    assign csr_tid_rvalue    =  csr_tid_tid ;
    assign csr_tcfg_rvalue   =  {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
    assign csr_tval_rvalue   =  csr_tval_timeval;
    assign csr_ticlr_rvalue  =  {31'b0, csr_ticlr_clr};

    assign csr_rvalue = {32{csr_num == `CSR_CRMD  }} & csr_crmd_rvalue
                      | {32{csr_num == `CSR_PRMD  }} & csr_prmd_rvalue
                      | {32{csr_num == `CSR_ESTAT }} & csr_estat_rvalue
                      | {32{csr_num == `CSR_ERA   }} & csr_era_rvalue
                      | {32{csr_num == `CSR_EENTRY}} & csr_eentry_rvalue
                      | {32{csr_num == `CSR_SAVE0 }} & csr_save0_rvalue
                      | {32{csr_num == `CSR_SAVE1 }} & csr_save1_rvalue
                      | {32{csr_num == `CSR_SAVE2 }} & csr_save2_rvalue
                      | {32{csr_num == `CSR_SAVE3 }} & csr_save3_rvalue
                      | {32{csr_num == `CSR_ECFG  }} & csr_ecfg_rvalue
                      | {32{csr_num == `CSR_BADV  }} & csr_badv_rvalue
                      | {32{csr_num == `CSR_TID   }} & csr_tid_rvalue
                      | {32{csr_num == `CSR_TCFG  }} & csr_tcfg_rvalue
                      | {32{csr_num == `CSR_TVAL  }} & csr_tval_rvalue
                      | {32{csr_num == `CSR_TICLR }} & csr_ticlr_rvalue;
    
    assign has_int = ((csr_estat_is[11:0] & csr_ecfg_lie[11:0]) != 12'b0) && (csr_crmd_ie == 1'b1);
endmodule