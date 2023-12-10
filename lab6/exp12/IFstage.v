`include "BUS_LEN.vh"
module IFstage (
  input  wire clk,
  input  wire resetn,
  //the interface with the SRAM
  output wire inst_sram_en,
  output wire [3:0] inst_sram_we,
  output wire [31:0] inst_sram_addr,
  output wire [31:0] inst_sram_wdata,
  input  wire [31:0] inst_sram_rdata,
  //the interface between the IFstage and the IDstage  
  input  wire [`BR_BUS-1:0] br_zip,
  output wire [`FS2DS_BUS_LEN-1:0] fs2ds_bus,
  input  wire ds_allowin,
  output wire fs2ds_valid,

  input wire wb_ex,
  input wire ertn_flush,
  input wire [31:0] ex_entry,
  input wire [31:0] ertn_entry
);


//////////declaration//////////
wire [31:0] seq_pc;
wire [31:0] nextpc;
reg [31:0] pc;

wire br_taken;
wire [31:0] br_target;

wire [31:0] fs_pc;
wire [31:0] inst;


//////////zip//////////
assign {br_taken, br_target} = br_zip;
assign fs2ds_bus = {fs_pc, inst};


//////////pipeline////////
wire fs_ready_go; 
wire fs_allowin; 
reg fs_valid;

assign fs_ready_go = 1'b1;
assign fs_allowin = ~fs_valid || fs_ready_go && ds_allowin || ertn_flush || wb_ex;
assign fs2ds_valid = fs_valid && fs_ready_go;

assign fs_pc = pc;

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

//////////assign//////////

assign seq_pc = pc + 3'h4;
assign nextpc  =  wb_ex? ex_entry:
                  ertn_flush? ertn_entry:
                  br_taken ? br_target : seq_pc;

assign inst_sram_en = resetn && fs_allowin;
assign inst_sram_we = 4'b0;
assign inst_sram_addr = nextpc;
assign inst_sram_wdata = 32'b0;
assign inst = inst_sram_rdata;

endmodule
