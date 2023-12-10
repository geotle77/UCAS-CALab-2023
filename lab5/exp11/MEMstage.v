module MEMstage (
  input wire clk,
  input wire resetn,
  input wire reset,
  input wire [31:0] data_sram_rdata,
  
  input wire ws_allowin,
  output wire ms_allowin,
  input wire es2ms_valid,
  output wire ms2ws_valid,
  
  input wire [`ES2MS_BUS_LEN-1:0] es2ms_bus,
  output wire [`MS2WS_BUS_LEN-1:0] ms2ws_bus,

  output wire [`FORWARD_BUS_LEN-1:0] mem_forward_zip,
  input wire exe_res_from_mul,
  input [67:0] mul_result
);


//////////zip//////////
wire [31:0] es_pc;
wire [31:0] alu_result;
wire [4:0] exe_dest;
wire [4:0]load_op;
wire [2:0]mul_op;
wire exe_gr_we;
assign {es_pc, mul_op, alu_result, load_op, exe_dest, exe_gr_we} = es2ms_bus;

reg [31:0] ms_pc;
reg mem_gr_we;
assign ms2ws_bus = {ms_pc, mem_gr_we, mem_dest, final_result};

wire mem_rf_we;
reg [4:0] mem_dest_reg;
wire[4:0] mem_dest;
wire [31:0] final_result;
assign mem_dest=mem_dest_reg;
assign mem_forward_zip = {mem_rf_we, mem_dest, final_result};
//////////declaration//////////

reg [18:0] mem_alu_op;
reg [31:0] mem_alu_result;
reg [ 4:0] mem_load_op;
reg [ 2:0] mem_mul_op;
wire mem_res_from_mem;
wire [31:0]mem_result;
wire [31:0]mem_mul_result;
wire res_from_mul;

reg ms_valid;

reg res_from_mul_reg;

//////////pipeline//////////
wire ms_ready_go;

assign ms_ready_go = 1'b1;
assign ms_allowin = ~ms_valid || ms_ready_go && ws_allowin;
assign ms2ws_valid = ms_valid && ms_ready_go;

always @(posedge clk) begin
  if (reset) begin
    ms_valid <= 1'b0;
  end else if (ms_allowin) begin
    ms_valid <= es2ms_valid;
  end
 
  if(es2ms_valid && ms_allowin)begin
    ms_pc <= es_pc;
    mem_alu_result <= alu_result;
    mem_load_op <= load_op;
    mem_mul_op  <= mul_op;
    mem_dest_reg <= exe_dest;
    mem_gr_we <= exe_gr_we;
    res_from_mul_reg <= exe_res_from_mul;
  end
end


assign mem_rf_we = ms_valid && mem_gr_we;
assign mem_res_from_mem = (|mem_load_op);

wire [31:0] ld_data;
wire [3:0]  ld_sel;
wire [31:0] lb_data;
wire [31:0] lh_data;

decoder_2_4 u_dec_ld(.in(mem_alu_result[1:0]), .out(ld_sel));
wire zero_ext;
assign zero_ext = ~(mem_load_op[3] | mem_load_op[4]);
assign lb_data = {32{ld_sel[0]}} & {{24{mem_result[7] & zero_ext}}, mem_result[7:0]}
            | {32{ld_sel[1]}} & {{24{mem_result[15] & zero_ext}}, mem_result[15:8]}
            | {32{ld_sel[2]}} & {{24{mem_result[23] & zero_ext}}, mem_result[23:16]}
            | {32{ld_sel[3]}} & {{24{mem_result[31] & zero_ext}}, mem_result[31:24]};

assign lh_data = {32{ld_sel[0]}} & {{16{mem_result[15] & zero_ext}}, mem_result[15:0]}
               | {32{ld_sel[2]}} & {{16{mem_result[31] & zero_ext}}, mem_result[31:16]};

assign ld_data = {32{mem_load_op[0] | mem_load_op[3]}} & lb_data
               | {32{mem_load_op[1] | mem_load_op[4]}} & lh_data
               | {32{mem_load_op[2]}} & mem_result;

assign mem_result     =   data_sram_rdata;
assign mem_mul_result =   ({32{mem_mul_op[0]               }} & mul_result[31: 0])
                        | ({32{mem_mul_op[1]  | mem_mul_op[2]}} & mul_result[63:32]);
assign res_from_mul=res_from_mul_reg;
                    
assign final_result   = {32{mem_res_from_mem}} & ld_data | 
                        {32{res_from_mul}} & mem_mul_result |
                        {32{~mem_res_from_mem &~res_from_mul}}&mem_alu_result ;
endmodule
