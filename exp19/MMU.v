`include "CSR.vh"
`include "BUS_LEN.vh"
module MMU(
    input wire  [1:0]                 flag,//10:inst;01:data
    input wire  [31:0]                csr_crmd_rvalue,
    input wire  [31:0]                csr_asid_rvalue,
    input wire  [31:0]                csr_dmw0_rvalue,
    input wire  [31:0]                csr_dmw1_rvalue,

    // from tlb
    input  wire                       s_found,
    input  wire [ 3:0]                s_index,
    input  wire [19:0]                s_ppn,
    input  wire [ 5:0]                s_ps,
    input  wire [ 1:0]                s_plv,
    input  wire [ 1:0]                s_mat,
    input  wire                       s_d,
    input  wire                       s_v, 

    //interface 
    input wire [31:0]                va,
    output wire [5:0]                exc_ecode,
    output wire                      dmw_hit,
    output wire [ 1:0]               plv,//10:adef,01:adem
    output wire [31:0]               pa,
    output wire [ 9:0]               s_asid
);



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
assign dmw_hit0 = csr_dmw0_rvalue[csr_crmd_plv] && (csr_dmw0_rvalue[31:29] == va[31:29]); // csr_dmw_rvalue[31:29] = csr_dmw_vseg
assign dmw_hit1 = csr_dmw1_rvalue[csr_crmd_plv] && (csr_dmw1_rvalue[31:29] == va[31:29]);
/*
When a virtual address hits a valid direct-mapped configuration window, 
its physical address is directly equal to the [28:0] bits of the virtual address spliced onto the mapped window's
Configured Physical Address High Bit
*/
assign dmw_paddr0 = {csr_dmw0_rvalue[`CSR_DMW_PSEG], va[28:0]}; 
assign dmw_paddr1 = {csr_dmw1_rvalue[`CSR_DMW_PSEG], va[28:0]}; 
/*
Translating addresses addresses will be prioritized to see if 
they can be translated according to the direct mapping model, 
and then translated according to the page table mapping model after that.
*/
assign tlb_trans = ~dmw_hit0 & ~dmw_hit1 & ~direct;

assign ecode_pif = tlb_trans & ~s_v;
assign ecode_ppi = tlb_trans & ((csr_crmd_plv > s_plv));//
assign ecode_tlbr = tlb_trans & ~s_found;
assign ecode_pil = 1'b0;
assign ecode_pis = 1'b0;
assign ecode_pme = 1'b0;


//TODO:if it is direct ,it should also consider the error inst!
assign exc_ecode = direct ? 6'b0 : {ecode_pil, ecode_pis, ecode_pif, ecode_pme, ecode_ppi, ecode_tlbr};
assign tlb_paddr = (s_ps == 6'd12) ? {s_ppn[19:0], va[11:0]} : {s_ppn[19:10], va[21:0]};

//paddr
assign pa =       ({32{direct}} & va) | 
                  ({32{~direct & dmw_hit0}} & dmw_paddr0) | 
                  ({32{~direct & ~dmw_hit0 & dmw_hit1}} & dmw_paddr1) | 
                  ({32{~direct & ~dmw_hit0 & ~dmw_hit1}} & tlb_paddr);
                  
assign s_asid = csr_asid_asid;
assign dmw_hit = dmw_hit0 | dmw_hit1;
assign plv = csr_crmd_plv;

endmodule
