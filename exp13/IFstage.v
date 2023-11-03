`include "BUS_LEN.vh"
module IFstage (
  input  wire                       clk,
  input  wire                       resetn,
  //the interface with the SRAM
  output wire                       inst_sram_en,
  output wire [3:0]                 inst_sram_we,
  output wire [31:0]                inst_sram_addr,
  output wire [31:0]                inst_sram_wdata,
  input  wire [31:0]                inst_sram_rdata,
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


//////////declaration//////////
wire [31:0] seq_pc;
wire [31:0] nextpc;
reg [31:0] pc;

wire br_taken;
wire [31:0] br_target;

wire [31:0] fs_pc;
wire [31:0] inst;

//exp13
wire        fs_adef;
wire [31:0] fs_wrong_addr;
wire [`FS_EXC_DATA_WD-1:0] fs_exc_data;
//////////zip//////////
assign {br_taken, br_target} = br_zip;
assign fs2ds_bus = {fs_exc_data,    //95:64
                    fs_pc,          //63:32
                    inst};          //31:0

//////////pipeline////////
wire fs_ready_go; 
wire fs_allowin; 
reg fs_valid;

assign fs_pc = pc;
assign fs_ready_go = 1'b1;
assign fs_allowin = ~fs_valid || fs_ready_go && ds_allowin;
assign fs2ds_valid = fs_valid && fs_ready_go && ~fs_reflush;

always @(posedge clk) begin
  if (~resetn) begin
    fs_valid <= 1'b0;
  end 
  else if (fs_allowin) begin
    fs_valid <= resetn;
  end

  if (~resetn) begin
    pc <= 32'h1bfffffc; // trick: to make nextpc be 0x1c000000 during reset
  end 
  else if (resetn & fs_allowin )begin
    pc <= nextpc;
  end
end

// adef: address error
assign fs_adef = nextpc[1] | nextpc[0];
assign fs_wrong_addr = nextpc;
assign fs_exc_data    = {fs_valid & fs_adef, // 32:32
                         fs_wrong_addr       // 31:0
                        };

//////////assign//////////
assign seq_pc = pc + 3'h4;
assign nextpc  =  wb_ex? csr_ex_entry:
                  ertn_flush? csr_ertn_entry:
                  br_taken ? br_target : seq_pc;

assign inst_sram_en = resetn && fs_allowin;
assign inst_sram_we = 4'b0;
assign inst_sram_addr = nextpc;
assign inst_sram_wdata = 32'b0;
assign inst = inst_sram_rdata;

endmodule
