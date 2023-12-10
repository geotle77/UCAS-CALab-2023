`include "BUS_LEN.vh"
module IFstage (
  input  wire                       clk,
  input  wire                       resetn,
  //the interface with the SRAM
  //Notice:the SRAM can be only read rather than write
    output wire        inst_sram_en,
    output wire        inst_sram_wr,
    output wire [ 3:0] inst_sram_we,
    output wire [ 1:0] inst_sram_size,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    input  wire        inst_sram_addr_ok,
    input  wire        inst_sram_data_ok,
  //the interface between the IFstage and the IDstage  
  input  wire [`BR_BUS-1:0]         br_zip,
  output wire [`FS2DS_BUS_LEN-1:0]  fs2ds_bus,
  input  wire                       ds_allowin,
  output wire                       fs2ds_valid,
  //ws to fs csr data
  input wire wb_ex,
  input wire ertn_flush,
  input wire [31: 0] csr_ex_entry,
  input wire [31: 0] csr_ertn_entry,

  input wire fs_reflush
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

assign {br_stall, br_taken, br_target} = br_zip;

//------------------pre-IF stage------------------

reg  pfs_valid;
wire pfs_ready_go;
wire to_fs_valid;
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
assign inst_sram_addr     = nextpc;

////////// IF to ID inst buf////////
reg [31: 0] fs_inst_buf;
reg         fs_inst_valid;
//reg         fs_inst_cancel;
//always @(posedge clk) begin
//    if(~resetn)
//        fs_inst_cancel <= 1'b0;
//    else if((fs_reflush | br_taken & ~br_stall) && ~fs_allowin && ~fs_ready_go )//the inst is canceled when the branch is taken or the pipeline is flushed
//        fs_inst_cancel <= 1'b1;
//    else if(inst_sram_data_ok) 
//        fs_inst_cancel <= 1'b0;
//end

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
assign fs2ds_bus = {fs_exc_data,    //95:64
                    fs_pc,          //63:32
                    fs_inst};          //31:0
assign fs2ds_valid = fs_valid && fs_ready_go && ~fs_inst_cancel ;
//////////excption information////////
//exp13
wire        fs_adef;
wire [31:0] fs_wrong_addr;
wire [`FS_EXC_DATA_WD-1:0] fs_exc_data;
assign fs_adef = fs_pc[1] | fs_pc[0];
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
    else if(inst_sram_en && (fs_reflush | br_taken &~ br_stall | (br_stall | fs_br_stall)&inst_sram_addr_ok))
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


wire fs_inst_cancel;
assign fs_inst_cancel = fs_reflush | fs_reflush_reg | br_taken & ~br_stall | fs_br_taken;


endmodule
