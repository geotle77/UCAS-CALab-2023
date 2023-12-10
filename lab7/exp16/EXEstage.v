`include "BUS_LEN.vh"
`include "CSR.vh"
module EXEstage (
  input wire clk,
  input wire resetn,
  input wire reset,
  
  input wire ms_allowin,
  output wire es_allowin,
  input wire ds2es_valid,
  output wire es2ms_valid,
  
  input wire [`DS2ES_BUS_LEN-1:0] ds2es_bus,
  output wire [`ES2MS_BUS_LEN-1:0] es2ms_bus,
  output wire [`FORWARD_BUS_LEN-1:0]   exe_forward_zip,
  
  output wire        data_sram_en,
  output wire        data_sram_wr,
  output wire [ 3:0] data_sram_we,
  output wire [ 1:0] data_sram_size,
  output wire [31:0] data_sram_addr,
  output wire [31:0] data_sram_wdata,
  input wire         data_sram_addr_ok,

  output reg es_block,
  output wire es_mem_block,
  input wire mul_block,
  
  output wire [67:0] mul_result,

  input wire ms_ex_to_es,
  input wire es_reflush,
  output wire es_csr_re
);


//////////zip//////////
wire [4:0]  es_load_op;
wire [2:0]  es_store_op;
wire [31:0] es_pc;
wire [31:0] es_alu_src1;
wire [31:0] es_alu_src2;
wire [15:0] es_alu_op;
wire [2:0]  es_mul_op;
wire [31:0] es_rkd_value;
wire es_mem_we;
wire es_gr_we;
wire [4:0]  es_dest;
wire [`DS_EXC_DATA_WD-1 : 0] ds_exc_data;
wire [1:0]  es_time_op;

reg [`DS2ES_BUS_LEN-1 : 0] ds2es_bus_reg;

wire [31:0] es_alu_result;
wire [31:0] es_final_result;
wire es_rf_we;
assign exe_forward_zip={es_rf_we, es_dest,es_final_result};
//////////declaration////////

reg es_valid;

wire        mem_we;
wire alu_flag;

wire        es_adef;
wire [31:0] es_wrong_addr;
wire        es_csr_we;
wire [31:0] es_csr_wmask;
wire [13:0] es_csr_num;
wire        es_ertn_flush;
wire        es_ex;
wire        ds_ex;
wire [ 8:0] es_esubcode;
wire [31:0] ds_wrong_addr  ;
wire [`ES_EXC_DATA_WD-1:0] es_exc_data;


wire        ld_ale         ;
wire        st_ale         ;
wire        es_ale         ;
wire [ 5:0] ds_ecode       ;
wire [ 5:0] es_ecode       ;
wire es_res_from_mul        ;
wire es_res_from_mem        ;
assign {es_pc,
        es_res_from_mul, 
        es_alu_src1, 
        es_alu_src2, 
        es_alu_op, 
        es_mul_op,  
        es_load_op, 
        es_store_op, 
        es_rkd_value, 
        es_gr_we, 
        es_dest, 
        ds_exc_data,
        es_time_op
        } = ds2es_bus_reg;

assign es2ms_bus = {es_mem_we,
                    es_res_from_mem,
                    es_pc,
                    es_res_from_mul,
                    es_mul_op,
                    es_final_result, 
                    es_load_op, 
                    es_dest, 
                    es_gr_we,
                    es_rkd_value,
                    es_exc_data};

assign ld_ale  =  es_load_op[1] &es_alu_result[0]                        // inst_ld_h
                | es_load_op[2] & (es_alu_result[1] |es_alu_result[0])   // inst_ld_w
                | es_load_op[4] & es_alu_result[0] ;                      // inst_ld_hu
assign st_ale  =  es_store_op[1] & es_alu_result[0]                       // inst_st_h
                | es_store_op[2] & (es_alu_result[1] | es_alu_result[0]); // inst_st_w
assign es_ale = ld_ale | st_ale;
// counter read by rdcntvl.w and rdcntvh.w
reg [63:0] counter;
always @(posedge clk) begin
    if (reset)
        counter <= 64'b0;
    else 
        counter <= counter + 1'b1;
end
assign es_final_result  = {32{es_time_op[0]}}                 & counter[31: 0]
                        | {32{es_time_op[1]}}                 & counter[63:32]
                        | {32{~es_time_op[0]&~es_time_op[1]}} & es_alu_result;


assign es_wrong_addr = es_adef ? ds_wrong_addr : es_alu_result;
assign es_ecode   = es_ale ? `ECODE_ALE : ds_ecode;
assign es_ex      = (ds_ex | es_ale) & es_valid;

assign {es_adef,         // 97
        ds_wrong_addr,   // 96:65
        es_csr_re,       // 64
        es_csr_we,       // 63
        es_csr_wmask,    // 62:31
        es_csr_num,      // 30:17
        es_ertn_flush,   // 16
        ds_ex,           // 15
        es_esubcode,     // 14:6
        ds_ecode         // 5:0
        } = ds_exc_data;

assign es_exc_data = {es_wrong_addr, //60:91         
                     es_csr_we,      //59            
                     es_csr_wmask,   //27:58                     
                     es_csr_num,     //13:26             
                     es_ertn_flush,  //12            
                     es_ex,         // 11             
                     es_esubcode ,  // 2:10       
                     es_ecode,      // 6:1
                     es_csr_re      //0           
                    };
//////////pipeline////////
wire es_ready_go;

assign es_ready_go = es_need_mem ? (es_reflush || es_finish || data_sram_en && data_sram_addr_ok)
                                    : (es_reflush || alu_flag && es_valid); 
assign es_allowin = ~es_valid || es_ready_go && ms_allowin;
assign es2ms_valid = es_valid && es_ready_go;


always @(posedge clk) begin
  if (reset) begin
    es_valid <= 1'b0;
  end 
  else if(es_reflush) begin
    es_valid <= 1'b0;
  end else if (es_allowin) begin
    es_valid <= ds2es_valid;
  end
  
  if(ds2es_valid && es_allowin)begin
    ds2es_bus_reg <= ds2es_bus;
  end
end

always @(posedge clk)begin
    if(ds2es_valid && es_allowin)begin
        if(mul_block)begin
            es_block <= 1'b1;
        end
        else begin
            es_block <= 1'b0;
        end
    end
end

assign es_res_from_mem = |es_load_op & ~ms_ex_to_es & ~es_reflush & ~ld_ale;
assign es_mem_block = (es_res_from_mem || (es_csr_re | es_csr_we) )& es_valid;


//--
reg es_finish; 
always @(posedge clk) begin
    if(reset)
        es_finish <= 1'b0;
    else if(data_sram_en & data_sram_addr_ok & ~ms_allowin)
        es_finish <= 1'b1;
    else if(ms_allowin)
        es_finish <= 1'b0;
    
end
//////////assign//////////


alu u_alu(
    .clk        (clk        ),
    .resetn     (resetn     ),
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_flag   (alu_flag),
    .alu_result (es_alu_result)
    );
    
wire [31:0] st_data;
wire [3:0] st_strb;
wire [3:0] st_sel;

decoder_2_4 u_dec_st(.in(es_alu_result[1:0]), .out(st_sel));

assign st_strb = {4{es_store_op[0]}} &  st_sel
               | {4{es_store_op[1]}} & (st_sel[0] ? 4'b0011 : 4'b1100)
               | {4{es_store_op[2]}} &  4'b1111;

assign st_data = {32{es_store_op[0]}} & {4{es_rkd_value[7:0]}}
               | {32{es_store_op[1]}} & {2{es_rkd_value[15:0]}}
               | {32{es_store_op[2]}} & es_rkd_value;

wire es_need_mem;
assign es_need_mem = es_valid && (es_res_from_mem || es_mem_we);
assign mem_we=(|es_store_op);
assign es_mem_we = mem_we & ~es_reflush & ~ms_ex_to_es & ~st_ale;
assign es_rf_we = es_valid && es_gr_we;

assign data_sram_en    =  ~es_finish && es_need_mem && ms_allowin;//1'b1;
assign data_sram_size  = (es_store_op[0] | es_load_op[0] | es_load_op[3]) ? 2'b00   // load b, bu or store b
                       : (es_store_op[1] | es_load_op[1] | es_load_op[4]) ? 2'b01   // load h, hu or store h
                       : 2'b10;
assign data_sram_wr    =  |es_store_op;
assign data_sram_we    =  es_mem_we ? st_strb : 4'b0000;
assign data_sram_addr  =  es_alu_result;
assign data_sram_wdata =  st_data;
//mul_src
wire  [33:0]  mul_src1;
wire  [33:0]  mul_src2;
assign mul_src1 = {{2{es_alu_src1[31] & ~es_mul_op[2]}}, es_alu_src1[31:0]};
assign mul_src2 = {{2{es_alu_src2[31] & ~es_mul_op[2]}}, es_alu_src2[31:0]};

booth_multiplier u_mul(
  .clk(clk),
  .x(mul_src1),
  .y(mul_src2),
  .z(mul_result)
);
endmodule