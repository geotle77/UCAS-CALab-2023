module alu(
  input clk,
  input resetn,
  input  wire [11:0] alu_op,
  input  wire [31:0] alu_src1,
  input  wire [31:0] alu_src2,
  output wire [31:0] alu_result,
  output wire [31:0] alu_flag
);

wire op_add;   //add operation
wire op_sub;   //sub operation
wire op_slt;   //signed compared and set less than
wire op_sltu;  //unsigned compared and set less than
wire op_and;   //bitwise and
wire op_nor;   //bitwise nor
wire op_or;    //bitwise or
wire op_xor;   //bitwise xor
wire op_sll;   //logic left shift
wire op_srl;   //logic right shift
wire op_sra;   //arithmetic right shift
wire op_lui;   //Load Upper Immediate

wire op_mul;   //multiply
wire op_mulh;  //multiply and store high bits
wire op_mulhu; //unsigned multiply and store high bits
wire op_div;   //divide
wire op_divu;  //unsigned divide
wire op_mod;   //mod 
wire op_modu;  //unsigned mod


// control code decomposition
assign op_add  = alu_op[ 0];
assign op_sub  = alu_op[ 1];
assign op_slt  = alu_op[ 2];
assign op_sltu = alu_op[ 3];
assign op_and  = alu_op[ 4];
assign op_nor  = alu_op[ 5];
assign op_or   = alu_op[ 6];
assign op_xor  = alu_op[ 7];
assign op_sll  = alu_op[ 8];
assign op_srl  = alu_op[ 9];
assign op_sra  = alu_op[10];
assign op_lui  = alu_op[11];
assign op_mul  = alu_op[12];
assign op_mulh = alu_op[13];
assign op_mulhu= alu_op[14];
assign op_div  = alu_op[15];
assign op_divu = alu_op[16];
assign op_mod  = alu_op[17];
assign op_modu = alu_op[18];

wire [31:0] add_sub_result;
wire [31:0] slt_result;
wire [31:0] sltu_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] lui_result;
wire [31:0] sll_result;
wire [63:0] sr64_result;
wire [31:0] sr_result;
wire [65:0] mul_result;
wire [63:0] div_result;
wire [63:0] divu_result;

//mul_src
wire  [32:0]  mul_src1;
wire  [32:0]  mul_src2;
assign mul_src1 = {alu_src1[31] & ~op_mulhu, alu_src1[31:0]};
assign mul_src2 = {alu_src2[31] & ~op_mulhu, alu_src2[31:0]};

booth_multiplier u_mul(
  .clk(clk),
  .x(mul_src1),
  .y(mul_src2),
  .z(mul_result)
);


// 32-bit adder
wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [31:0] adder_result;
wire        adder_cout;

assign adder_a   = alu_src1;
assign adder_b   = (op_sub | op_slt | op_sltu) ? ~alu_src2 : alu_src2;  //src1 - src2 rj-rk
assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1      : 1'b0;
assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;

// ADD, SUB result
assign add_sub_result = adder_result;

// SLT result
assign slt_result[31:1] = 31'b0;   //rj < rk 1
assign slt_result[0]    = (alu_src1[31] & ~alu_src2[31])
                        | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31]);

// SLTU result
assign sltu_result[31:1] = 31'b0;
assign sltu_result[0]    = ~adder_cout;

// bitwise operation
assign and_result = alu_src1 & alu_src2;
assign or_result  = alu_src1 | alu_src2;
assign nor_result = ~or_result;
assign xor_result = alu_src1 ^ alu_src2;
assign lui_result = alu_src2;

// SLL result
assign sll_result = alu_src1 << alu_src2[4:0];   //rj << i5

// SRL, SRA result
assign sr64_result = {{32{op_sra & alu_src1[31]}}, alu_src1[31:0]} >> alu_src2[4:0]; //rj >> i5

assign sr_result   = sr64_result[31:0];

//div
reg  div_data_valid;
reg  divu_data_valid;
wire divisor_tready;
wire dividend_tready;
wire u_divisor_tready;
wire u_dividend_tready;
wire div_out_valid;
wire divu_out_valid;
reg  div_block;

wire signed_div = op_div | op_mod;
wire unsigned_div = op_divu| op_modu;

assign div_finish = signed_div & div_out_valid | unsigned_div & divu_out_valid | ~signed_div & ~unsigned_div;

if(resetn) begin
    div_block <= 1'b0;
  end else if(div_out_valid | divu_out_valid) begin
    div_block <= 1'b0;
  end else if(div_data_valid & divisor_tready & dividend_tready | 
              divu_data_valid & u_divisor_tready & u_dividend_data_ready) begin
    div_block <= 1'b1;
  end

always @(posedge clk) begin
  if(div_block) begin
    div_data_valid <= 1'b0;
  end else if(need_div & ~divisor_tready & ~dividend_tready ) begin
    div_data_valid <= 1'b1;
  end else begin
    div_data_valid <= 1'b0;
  end
  
  if(div_block) begin
    div_data_valid <= 1'b0;
  end else if(need_divu & ~u_divisor_tready & ~u_dividend_tready ) begin
    div_data_valid <= 1'b1;
  end else begin
    div_data_valid <= 1'b0;
  end
end

  IP_DIV div(
  .aclk                   (clk),
  .s_axis_divisor_tdata   (alu_src2),
  .s_axis_dividend_tdata  (alu_src1),
  .s_axis_divisor_tready  (divisor_tready),    // ready to accept divisor
  .s_axis_dividend_tready (dividend_tready),   // ready to accept dividend
  .s_axis_divisor_tvalid  (div_data_valid),        // request div
  .s_axis_dividend_tvalid (div_data_valid),        // request div
  .m_axis_dout_tdata      (div_result),
  .m_axis_dout_tvalid     (div_out_valid)
);

IP_DIV_U divu(
  .aclk                   (clk),
  .s_axis_divisor_tdata   (alu_src2),
  .s_axis_dividend_tdata  (alu_src1),
  .s_axis_divisor_tready  (u_divisor_tready),
  .s_axis_dividend_tready (u_dividend_tready),
  .s_axis_divisor_tvalid  (divu_data_valid),
  .s_axis_dividend_tvalid (divu_data_valid),
  .m_axis_dout_tdata      (divu_result),
  .m_axis_dout_tvalid     (divu_out_valid)
);



// final result mux
assign alu_result = ({32{op_add|op_sub   }} & add_sub_result)
                  | ({32{op_slt          }} & slt_result)
                  | ({32{op_sltu         }} & sltu_result)
                  | ({32{op_and          }} & and_result)
                  | ({32{op_nor          }} & nor_result)
                  | ({32{op_or           }} & or_result)
                  | ({32{op_xor          }} & xor_result)
                  | ({32{op_lui          }} & lui_result)
                  | ({32{op_sll          }} & sll_result)
                  | ({32{op_srl|op_sra   }} & sr_result)
                  | ({32{op_mul          }} & mul_result[31:0])
                  | ({32{op_mulh|op_mulhu}} & mul_result[63:32])
                  | ({32{op_div          }} & div_result[63:32])
                  | ({32{op_divu         }} & divu_result[63:32])
                  | ({32{op_mod          }} & div_result[31:0])
                  | ({32{op_modu         }} & divu_result[31:0]);
endmodule
