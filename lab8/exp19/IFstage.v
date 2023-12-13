`include "BUS_LEN.vh"
`include "CSR.vh"
module IFstage (
    input  wire                       clk,
    input  wire                       resetn,

    // interface with SRAM
    output wire                       inst_sram_en,
    output wire                       inst_sram_wr,
    output wire [ 3:0]                inst_sram_we,
    output wire [ 1:0]                inst_sram_size,
    output wire [31:0]                inst_sram_addr,
    output wire [31:0]                inst_sram_wdata,
    input  wire [31:0]                inst_sram_rdata,
    input  wire                       inst_sram_addr_ok,
    input  wire                       inst_sram_data_ok,

    // interface between IF and ID
    input  wire                       ds_allowin,
    output wire                       fs2ds_valid,
    input  wire [`BR_BUS-1:0]         br_zip,
    output wire [`FS2DS_BUS_LEN-1:0]  fs2ds_bus,

    // csr data from WB
    input wire                        wb_ex,          // exception in WB
    input wire                        ertn_flush,     // ertn in WB
    input wire                        fs_reflush,     // syscall in WB

    // interface with CSR
    input wire [31: 0]                csr_ex_entry,
    input wire [31: 0]                csr_ertn_entry,
    //exp19
     // from csr
    input wire  [31:0]                csr_crmd_rvalue,
    input wire  [31:0]                csr_asid_rvalue,
    input wire  [31:0]                csr_dmw0_rvalue,
    input wire  [31:0]                csr_dmw1_rvalue,

    // from tlb
    input  wire                       s0_found,
    input  wire [ 3:0]                s0_index,
    input  wire [19:0]                s0_ppn,
    input  wire [ 5:0]                s0_ps,
    input  wire [ 1:0]                s0_plv,
    input  wire [ 1:0]                s0_mat,
    input  wire                       s0_d,
    input  wire                       s0_v, 
    // to tlb
    output wire [19:0]                s0_va_highbits,
    output wire [ 9:0]                s0_asid
);


wire [31:0] seq_pc;
wire [31:0] nextpc;

wire br_stall;//
wire br_taken;
wire [31:0] br_target;

reg [31: 0] fs_pc;
wire [31:0] fs_inst;

wire fs_ready_go; 
wire fs_allowin; 
reg fs_valid;

reg  pfs_valid;
wire pfs_ready_go;
wire to_fs_valid;

assign {br_stall, br_taken, br_target} = br_zip;

//------------------pre-IF stage------------------

always @(posedge clk) begin
  if (~resetn  ) begin
    pfs_valid <= 1'b0;
  end
  else begin
    pfs_valid <= 1'b1;
  end
end

assign to_fs_valid = pfs_valid && pfs_ready_go;
assign pfs_ready_go = inst_sram_en && inst_sram_addr_ok && ~(pfs_reflush | fs_reflush | br_taken &~br_stall | br_stall);//the addr is accepted then enter IF stage//my

assign inst_sram_en       = fs_allowin & pfs_valid & ~pfs_reflush; // consider the case if pfs_valid :1 but fs_allowin :0//my
//simple solution : fs_allowin =1 then inst_sram_en =1 to avoid the pfs_ready_go =1 but fs_allowin =0,which can't keep the inst
//this method is not good, because it arise more delay
assign inst_sram_wr       = 1'b0;
assign inst_sram_we       = 4'b0;
assign inst_sram_size     = 2'b10;
assign inst_sram_wstrb    = 4'b0;
assign inst_sram_wdata    = 32'b0;
//assign inst_sram_addr     = nextpc;

////////// IF to ID inst buf////////
reg [31: 0] fs_inst_buf;
reg         fs_inst_valid;

always @(posedge clk) begin
    if(~resetn)begin
        fs_inst_buf   <= 32'b0;
        fs_inst_valid <= 1'b0;
    end
    else if(inst_sram_data_ok & ~fs_inst_valid & ~ds_allowin & ~fs_inst_cancel)//need to store in the buf if ds_allowin = 0 and fs_inst_cancel = 0
    begin
        fs_inst_buf   <= inst_sram_rdata;
        fs_inst_valid <= 1'b1;
    end
    else if(fs_inst_cancel || ds_allowin) // ds_allowin = 1: inst enters id stage//my
    begin
      fs_inst_buf <= 32'b0;
      fs_inst_valid <= 1'b0;
    end
end



//------------------IF stage------------------

assign fs_allowin = ~fs_valid || fs_ready_go && ds_allowin;

always @(posedge clk) begin
  if (~resetn) begin
    fs_valid <= 1'b0;
  end 
  else if (fs_allowin) begin
    fs_valid <= to_fs_valid & ~fs_reflush;
  end
end

assign fs_ready_go = fs_valid && inst_sram_data_ok || fs_inst_valid && ~fs_inst_cancel;//consider two cases: 1. the inst is from the sram 2. the inst is from the inst_buf
assign fs_inst     = fs_inst_valid ? fs_inst_buf : inst_sram_rdata;//don't need to wait the data_ok signal
assign fs2ds_bus = {fs_exc_ecode,   //102:97
                    fs_exc_data,    //96:64
                    fs_pc,          //63:32
                    fs_inst};       //31:0
assign fs2ds_valid = fs_valid && fs_ready_go && ~fs_inst_cancel ;

//////////excption information////////
//exp13
wire        fs_adef;
wire [31:0] fs_wrong_addr;
wire [`FS_EXC_DATA_WD-1:0] fs_exc_data;
//TODO:why we should check the fs_pc[31]?
/*this is because the fs[31] can be used to distinguish between user space and kernel space, 
and only high privileges can access kernel space  
*/
assign fs_adef = fs_pc[1] | fs_pc[0] |(csr_crmd_plv == 2'd3 & fs_pc[31] & ~(dmw_hit0 | dmw_hit1)); 
assign fs_wrong_addr = fs_pc;
assign fs_exc_data    = {fs_valid & fs_adef, // 32:32
                         fs_wrong_addr       // 31:0
                        };

reg fs_ertn_valid;//delay ertn_flush
reg fs_ex_valid;//delay wb_ex
reg [31: 0]fs_ertn_entry;
reg [31: 0]fs_ex_entry;
reg fs_br_taken;
reg [31: 0] fs_br_target;
reg fs_br_stall;

assign seq_pc = fs_pc + 3'h4;
assign nextpc  =  wb_ex? csr_ex_entry:   //the nextpc is updated in these cases
                  fs_ex_valid? fs_ex_entry:
                  fs_ertn_valid? fs_ertn_entry:
                  ertn_flush? csr_ertn_entry:
                  fs_br_taken? fs_br_target:
                  br_taken & ~br_stall ? br_target : seq_pc;

always @(posedge clk) begin
  if(~resetn||pfs_ready_go && fs_allowin) begin
    fs_ertn_valid <= 1'b0;
    fs_ex_valid <= 1'b0;
    fs_ertn_entry <= 32'b0;
    fs_ex_entry <= 32'b0;
  end
  else if(ertn_flush) begin
    fs_ertn_valid <= ertn_flush;
    fs_ertn_entry <= csr_ertn_entry;
  end
  else if(wb_ex) begin
    fs_ex_valid <= wb_ex;
    fs_ex_entry <= csr_ex_entry;
  end
end

always @(posedge clk) begin
  if(~resetn || pfs_ready_go && fs_allowin) begin
    fs_br_taken <= 1'b0;
    fs_br_target <= 32'b0;
  end
  else if(br_taken & ~br_stall) begin
    fs_br_taken <= br_taken;
    fs_br_target <= br_target;
  end
end


always @(posedge clk) begin
    if (~resetn) begin
        fs_br_stall <= 1'b0;
    end else if (br_stall) begin
        fs_br_stall <= br_stall;
    end 
    else if (inst_sram_addr_ok && ~pfs_reflush && fs_allowin)begin
        fs_br_stall <= 1'b0;
    end
end

always @(posedge clk) begin
    if (~resetn) begin
        fs_pc <= 32'h1bfffffc;
    end
    else if (to_fs_valid & fs_allowin) begin
        fs_pc <= nextpc;
    end
end







//----------add----------
reg pfs_reflush;

always @(posedge clk) begin
    if(~resetn)
        pfs_reflush <= 1'b0;
    else if(inst_sram_en && (fs_reflush | ((br_taken &~ br_stall) | (br_stall | fs_br_stall))&inst_sram_addr_ok))
        pfs_reflush <= 1'b1;
    else if(inst_sram_data_ok)
        pfs_reflush <= 1'b0;
end



reg fs_reflush_reg;

always @(posedge clk) begin
    if(~resetn)
        fs_reflush_reg <= 1'b0;
    else if(fs_reflush)
        fs_reflush_reg <= 1'b1;
    else if(to_fs_valid & fs_allowin)
        fs_reflush_reg <= 1'b0;
end


wire    fs_inst_cancel;
assign  fs_inst_cancel = fs_reflush | fs_reflush_reg | br_taken & ~br_stall | fs_br_taken;


//exp 19 
wire        csr_crmd_da;
wire        csr_crmd_pg;
wire [1:0]  csr_crmd_plv;
wire [9:0]  csr_asid_asid;
/*
The legal combination of the DA bit and the PG bit is 0, 1, or 1, 0.
*/
assign csr_crmd_da = csr_crmd_rvalue[`CSR_CRMD_DA]; //Direct address translation mode enable
assign csr_crmd_pg = csr_crmd_rvalue[`CSR_CRMD_PG]; //Mapped Address Translation Mode Enable
assign csr_crmd_plv = csr_crmd_rvalue[`CSR_CRMD_PLV];//Current privilege level
assign csr_asid_asid = csr_asid_rvalue[`CSR_ASID_ASID];//The address space identifier corresponding to the currently executing program

wire        direct; //direct addr translation
wire        dmw_hit0  ;
wire        dmw_hit1  ;
wire [31:0] dmw_paddr0;
wire [31:0] dmw_paddr1;
wire [31:0] tlb_paddr ;
wire        tlb_trans;
wire        ecode_pil ; //load Action Page Invalid Exception
wire        ecode_pis ; //Store Operation Page Invalid Exception
wire        ecode_pif ;//Invalid Finger Fetching Page Exception
wire        ecode_pme ;//Page modification exceptions
wire        ecode_ppi ;//Page Privilege Level Noncompliance Exception
wire        ecode_tlbr;//TLB Refill Exception

assign direct = csr_crmd_da & ~csr_crmd_pg;//direct addr translation
/*
The highest 3 bits of the virtual address ([31:29] bits) are the same as the [31:29] in the configuration window registers
are equal and the current privilege level is allowed in this configuration window.
*/
assign dmw_hit0 = csr_dmw0_rvalue[csr_crmd_plv] && (csr_dmw0_rvalue[31:29] == nextpc[31:29]); // csr_dmw_rvalue[31:29] = csr_dmw_vseg
assign dmw_hit1 = csr_dmw1_rvalue[csr_crmd_plv] && (csr_dmw1_rvalue[31:29] == nextpc[31:29]);
/*
When a virtual address hits a valid direct-mapped configuration window, 
its physical address is directly equal to the [28:0] bits of the virtual address spliced onto the mapped window's
Configured Physical Address High Bit
*/
assign dmw_paddr0 = {csr_dmw0_rvalue[`CSR_DMW_PSEG], nextpc[28:0]}; 
assign dmw_paddr1 = {csr_dmw1_rvalue[`CSR_DMW_PSEG], nextpc[28:0]}; 
/*
Translating addresses addresses will be prioritized to see if 
they can be translated according to the direct mapping model, 
and then translated according to the page table mapping model after that.
*/
assign tlb_trans = ~dmw_hit0 & ~dmw_hit1 & ~direct;

assign ecode_pif = tlb_trans & ~s0_v;
assign ecode_ppi = tlb_trans & ((csr_crmd_plv > s0_plv));//
assign ecode_tlbr = tlb_trans & ~s0_found;
assign ecode_pil = 1'b0;
assign ecode_pis = 1'b0;
assign ecode_pme = 1'b0;

assign s0_va_highbits = nextpc[31:12];
assign s0_asid = csr_asid_asid;

wire [5:0] fs_exc_ecode;
assign fs_exc_ecode = direct ? 6'b0 : {ecode_pil, ecode_pis, ecode_pif, ecode_pme, ecode_ppi, ecode_tlbr};
assign tlb_paddr = (s0_ps == 6'd12) ? {s0_ppn[19:0], nextpc[11:0]} : {s0_ppn[19:10], nextpc[21:0]};

//paddr
assign inst_sram_addr = direct ? nextpc
                      : dmw_hit0 ? dmw_paddr0
                      : dmw_hit1 ? dmw_paddr1
                      : tlb_paddr;  






endmodule
