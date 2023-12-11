`include "BUS_LEN.vh"
module preIFstage(
    input wire                          clk,
    input wire                          resetn,
    input wire                          reset,

    // interface with SRAM
    output wire                         inst_sram_en,
    output wire                         inst_sram_wr,
    output wire [ 3:0]                  inst_sram_we,
    output wire [ 1:0]                  inst_sram_size,
    output wire [31:0]                  inst_sram_addr,
    output wire [31:0]                  inst_sram_wdata,
    input  wire [31:0]                  inst_sram_rdata,
    input  wire                         inst_sram_addr_ok,

    // interface between preIF to IF
    input wire                          fs_allowin,
    input wire [`BR_BUS-1:0]            br_zip,
    input wire [`BR_BUS-1:0]            fs_br_zip,
    input wire                          fs_reflush;
    output wire                         to_fs_valid,
    output wire                         pfs_ready_go,

    // interface with CSR
    input wire [31: 0]                  csr_ex_entry,
    input wire [31: 0]                  csr_ertn_entry,

    input wire                          wb_ex,          // exception in WB
    input wire                          ertn_flush,     // ertn in WB
    input wire                          fs_reflush,     // syscall in WB
    input wire [IF2PFS_CSR_BUS-1:0]     fs2pfs_bus, 
)
reg pfs_valid;
wire to_fs_valid;
wire pfs_ready_go;
wire [31:0] nextpc;

wire br_stall;//
wire br_taken;
wire [31:0] br_target;
wire fs_br_stall;
wire fs_br_taken;
wire [31:0] fs_br_target;
assign {br_stall, br_taken, br_target} = br_zip;
assign {fs_br_stall, fs_br_taken, fs_br_target} = fs_br_zip;
always @(posedge clk) begin
  if (~resetn  ) begin
    pfs_valid <= 1'b0;
  end
  else begin
    pfs_valid <= 1'b1;
  end
end

assign to_fs_valid = pfs_valid & pfs_ready_go;
//TODO
assign pfs_ready_go = inst_sram_en && inst_sram_addr_ok&~(pfs_reflush | fs_reflush | br_taken &~br_stall | br_stall);

assign inst_sram_en = fs_allowin & pfs_valid & ~pfs_reflush ;
assign inst_sram_wr = 1'b0;
assign inst_sram_wr       = 1'b0;
assign inst_sram_we       = 4'b0;
assign inst_sram_size     = 2'b10;
assign inst_sram_wstrb    = 4'b0;
assign inst_sram_wdata    = 32'b0;
assign inst_sram_addr     = nextpc;

reg pfs_reflush;
always @(posedge clk) begin
    if(~resetn)
        pfs_reflush <= 1'b0;
    else if(inst_sram_en && (fs_reflush | br_taken &~ br_stall | (br_stall | fs_br_stall)&inst_sram_addr_ok))
        pfs_reflush <= 1'b1;
    else if(inst_sram_data_ok)
        pfs_reflush <= 1'b0;
end

wire[31:0] seq_pc;
assign nextpc  =  wb_ex? csr_ex_entry:   //the nextpc is updated in these cases
                  fs_ex_valid? fs_ex_entry:
                  fs_ertn_valid? fs_ertn_entry:
                  ertn_flush? csr_ertn_entry:
                  fs_br_taken? fs_br_target:
                  br_taken & ~br_stall ? br_target : seq_pc;


endmodule