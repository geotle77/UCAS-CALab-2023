module IFstage (
  input wire clk,
  input wire resetn,
  input wire reset,
  
  input wire ds_allowin,
  output wire fs2ds_valid,
  
  input wire [32:0] br_zip,
  output wire [63:0] fs2ds_bus,
  
  output wire inst_sram_en,
  output wire [3:0] inst_sram_we,
  output wire [31:0] inst_sram_addr,
  output wire [31:0] inst_sram_wdata,
  input wire [31:0] inst_sram_rdata

);


//////////declaration//////////
reg fs_valid;
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

assign fs_ready_go = 1'b1;
assign fs_allowin = ~fs_valid || fs_ready_go && ds_allowin;
assign fs2ds_valid = fs_valid && fs_ready_go;

assign fs_pc = pc;

always @(posedge clk) begin
  if (~resetn) begin
    fs_valid <= 1'b0;
  end else if (fs_allowin) begin
    fs_valid <= resetn;
  end
  
  if (~resetn) begin
    pc <= 32'h1bfffffc; // trick: to make nextpc be 0x1c000000 during reset
  end else if (resetn && fs_allowin)begin
    pc <= nextpc;
  end
end

//////////assign//////////

assign seq_pc = pc + 3'h4;
assign nextpc = br_taken ? br_target : seq_pc;

assign inst_sram_en = resetn && fs_allowin; // 1'b1;
assign inst_sram_we = 4'b0;
assign inst_sram_addr = nextpc;
assign inst_sram_wdata = 32'b0;
assign inst = inst_sram_rdata;

endmodule
