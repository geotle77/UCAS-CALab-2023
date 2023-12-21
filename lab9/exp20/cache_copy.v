`include "cache.vh"
module cache(
    input  clk,
    input  resetn,

    // cpu interface
    input           valid,
    input           op,
    input  [ 7:0]   index,
    input  [19:0]   tag,
    input  [ 3:0]   offset,
    input  [ 3:0]   wstrb,
    input  [31:0]   wdata,
    output          addr_ok,
    output          data_ok,
    output [31:0]   rdata,

    // axi interface
    output          rd_req,
    output [ 2:0]   rd_type,
    output [31:0]   rd_addr,
    input           rd_rdy,
    input           ret_valid,
    input           ret_last,
    input  [31:0]   ret_data,
    output          wr_req,
    output [  2:0]  wr_type,
    output [ 31:0]  wr_addr,
    output [  3:0]  wr_wstrb,
    output [127:0]  wr_data,
    input           wr_rdy
);

    wire rst = ~resetn;

    // main state machine
    localparam  IDLE    = 5'b00001,
                LOOKUP  = 5'b00010,
                MISS    = 5'b00100,
                REPLACE = 5'b01000,
                REFILL  = 5'b10000;
    reg  [ 4:0] cur_state;
    reg  [ 4:0] nxt_state;

    reg  [68:0] req_buf;
    wire        op_reg;
    wire [ 3:0] wstrb_reg;
    wire [31:0] wdata_reg;
    wire [ 7:0] index_reg;
    wire [19:0] tag_reg;
    wire [ 3:0] offset_reg;

    reg         wr_req_r;

    // write buffer state machine
    localparam  WRBUF_IDLE  = 2'b01,
                WRBUF_WRITE = 2'b10;
    reg  [ 1:0] wrbuf_cur_state;
    reg  [ 1:0] wrbuf_nxt_state;
    
    reg  [48:0] wr_buf;
    wire        wrbuf_way;
    wire [ 7:0] wrbuf_index;
    wire [ 3:0] wrbuf_offset;
    wire [ 3:0] wrbuf_wstrb;
    wire [31:0] wrbuf_wdata;

    // ports to tag ram (way0 and way1)
    wire        tagv_we    [1:0];
    wire [ 7:0] tagv_addr  [1:0];
    wire [20:0] tagv_wdata [1:0];
    wire [20:0] tagv_rdata [1:0];
    // ports to data bank ram (way0 and way1)
    wire [ 3:0] data_bank_we    [1:0][3:0];
    wire [ 7:0] data_bank_addr  [1:0][3:0];
    wire [31:0] data_bank_wdata [1:0][3:0];
    wire [31:0] data_bank_rdata [1:0][3:0];

    // valid bit
    reg  [255:0] v_table [1:0];
    // dirty bit
    reg  [255:0] d_table [1:0];

    wire         way0_hit, way1_hit;
    wire         cache_hit;
    wire         hit_write;
    wire         hit_write_hazard;

    wire [31:0] load_res;
    reg  [15:0] lfsr;
    reg         replace_way;
    reg  [ 1:0] ret_cnt;

    // main state machine
    always @ (posedge clk) begin
        if (rst) begin
            cur_state <= IDLE;
        end else begin
            cur_state <= nxt_state;
        end
    end

    always @ (*) begin
        case (cur_state)
            IDLE:
                if (valid & ~hit_write_hazard) begin
                    nxt_state = LOOKUP;
                end else begin
                    nxt_state = IDLE;
                end
            LOOKUP:
                if (cache_hit & (~valid | hit_write_hazard)) begin
                    nxt_state = IDLE;
                end else if (cache_hit & valid) begin
                    nxt_state = LOOKUP;
                end else begin
                    nxt_state = MISS;
                end
            MISS:
                if (wr_rdy) begin
                    nxt_state = REPLACE;
                end else begin
                    nxt_state = MISS;
                end
            REPLACE:
                if (rd_rdy) begin
                    nxt_state = REFILL;
                end else begin
                    nxt_state = REPLACE;
                end
            REFILL:
                if (ret_valid & ret_last) begin
                    nxt_state = IDLE;
                end else begin
                    nxt_state = REFILL;
                end
            default:nxt_state = IDLE;
        endcase
    end

    // IDLE & LOOKUP
    assign {op_reg, wstrb_reg, wdata_reg, index_reg, tag_reg, offset_reg} = req_buf;
    always @ (posedge clk) begin
        if (rst) begin
            req_buf <= 69'b0;
        end else if (valid && addr_ok) begin
            req_buf <= {op, wstrb, wdata, index, tag, offset};
        end
    end

    assign tagv_addr[1] = cur_state[`IDLE] || cur_state[`LOOKUP] ? index : index_reg;
    assign tagv_addr[0] = cur_state[`IDLE] || cur_state[`LOOKUP] ? index : index_reg;

    genvar i, j;
    generate for (i = 0; i < 2; i = i+1) begin
        for (j = 0; j < 4; j = j+1) begin
            assign data_bank_addr[i][j] = cur_state[`IDLE] || cur_state[`LOOKUP] ? index : index_reg;
        end
    end
    endgenerate

    assign way0_hit = tagv_rdata[0][20] && (tagv_rdata[0][19:0] == tag_reg);
    assign way1_hit = tagv_rdata[1][20] && (tagv_rdata[1][19:0] == tag_reg);
    assign cache_hit = way0_hit || way1_hit;
    assign hit_write = cache_hit & op_reg & cur_state[`LOOKUP];
    assign hit_write_hazard = cur_state[`LOOKUP] && hit_write && valid && ~op && {index, offset} == {index_reg, offset_reg}
                            || wrbuf_cur_state[`WRBUF_WRITE] && valid && ~op && offset[3:2] == offset_reg[3:2];

    assign load_res = data_bank_rdata[way1_hit][offset_reg[3:2]];

    // replace & refill
    always @ (posedge clk) begin
        if (rst) begin
            lfsr <= 16'b1100_1001_1010_0101;
        end else begin
            lfsr <= {lfsr[14:0],lfsr[12]^lfsr[2]};
        end
    end

    // miss buffer
    always @ (posedge clk) begin
        if (rst) begin
            replace_way <= 1'b0;
        end
        else if (cur_state[`LOOKUP] & ~hit_write) begin
            replace_way <= lfsr[0]; //pseudo random
        end
    end
    always @ (posedge clk) begin
        if (rst | ret_last & ret_valid) begin
            ret_cnt <= 2'b0;
        end else if (ret_valid) begin
            ret_cnt <= ret_cnt + 2'b1;
        end
    end

    // write buffer state machine
    always @ (posedge clk) begin
        if (rst) begin
            wrbuf_cur_state <= WRBUF_IDLE;
        end else begin
            wrbuf_cur_state <= wrbuf_nxt_state;
        end
    end

    always @ (*) begin
        case (wrbuf_cur_state)
            WRBUF_IDLE:
                if (hit_write) begin
                    wrbuf_nxt_state = WRBUF_WRITE;
                end else begin
                    wrbuf_nxt_state = WRBUF_IDLE;
                end
            WRBUF_WRITE:
                if (hit_write) begin
                    wrbuf_nxt_state = WRBUF_WRITE;
                end else begin
                    wrbuf_nxt_state = WRBUF_IDLE;
                end
            default:wrbuf_nxt_state = WRBUF_IDLE;
        endcase
    end

    // write buffer
    always @ (posedge clk) begin
        if (rst) begin
            wr_buf <= 49'b0;
        end else if (hit_write) begin
            wr_buf <= {way1_hit, index_reg, offset_reg, wstrb_reg, wdata_reg};
        end
    end
    
    assign {wrbuf_way, wrbuf_index, wrbuf_offset, wrbuf_wstrb, wrbuf_wdata} = wr_buf;
    
    // valid table
    always @ (posedge clk) begin
        if (rst) begin
            v_table[0] <= 256'b0;
            v_table[1] <= 256'b0;
        end else if (ret_valid & ret_last) begin
            v_table[replace_way][index_reg] <= 1'b1;
        end
    end

    // dirty table
    always @ (posedge clk) begin
        if (rst) begin
            d_table[0] <= 256'b0;
            d_table[1] <= 256'b0;
        end else if (wrbuf_cur_state[`WRBUF_WRITE]) begin
            d_table[wrbuf_way][wrbuf_index] <= 1'b1;
        end else if (ret_valid & ret_last) begin
            d_table[replace_way][index_reg] <= op_reg;
        end
    end

    // tag
    assign tagv_we[0] = ret_valid & ret_last & ~replace_way;
    assign tagv_we[1] = ret_valid & ret_last &  replace_way;
    assign tagv_wdata[0] = {1'b1, tag_reg};
    assign tagv_wdata[1] = {1'b1, tag_reg};

    generate for (i = 0; i < 2; i = i+1) begin
        tagv_ram tag_rami(
            .clka (clk),
            .wea  (tagv_we[i]),
            .addra(tagv_addr[i]),
            .dina (tagv_wdata[i]),
            .douta(tagv_rdata[i])
        );
    end
    endgenerate

    // data bank
    generate for (i = 0; i < 4; i = i+1) begin
        assign data_bank_we[0][i] = {4{wrbuf_cur_state[`WRBUF_WRITE] & wrbuf_offset[3:2] == i & ~wrbuf_way}} & wrbuf_wstrb
                                  | {4{ret_valid & ret_cnt == i & ~replace_way}} & 4'hf;
        assign data_bank_we[1][i] = {4{wrbuf_cur_state[`WRBUF_WRITE] & wrbuf_offset[3:2] == i &  wrbuf_way}} & wrbuf_wstrb
                                  | {4{ret_valid & ret_cnt == i &  replace_way}} & 4'hf;
        assign data_bank_wdata[0][i] = wrbuf_cur_state[`WRBUF_WRITE] ? wrbuf_wdata :
                                       offset_reg[3:2] != i || ~op_reg ? ret_data  :
                                      {wstrb_reg[3] ? wdata_reg[31:24] : ret_data[31:24],
                                       wstrb_reg[2] ? wdata_reg[23:16] : ret_data[23:16],
                                       wstrb_reg[1] ? wdata_reg[15: 8] : ret_data[15: 8],
                                       wstrb_reg[0] ? wdata_reg[ 7: 0] : ret_data[ 7: 0]};
        assign data_bank_wdata[1][i] = wrbuf_cur_state[`WRBUF_WRITE] ? wrbuf_wdata :
                                       offset_reg[3:2] != i || ~op_reg ? ret_data  :
                                      {wstrb_reg[3] ? wdata_reg[31:24] : ret_data[31:24],
                                       wstrb_reg[2] ? wdata_reg[23:16] : ret_data[23:16],
                                       wstrb_reg[1] ? wdata_reg[15: 8] : ret_data[15: 8],
                                       wstrb_reg[0] ? wdata_reg[ 7: 0] : ret_data[ 7: 0]};
        end
    endgenerate

    generate for (i = 0; i < 2; i = i+1) begin
        for (j = 0; j < 4; j = j+1) begin
            data_bank_ram db_rami(
                .clka (clk),
                .wea  (data_bank_we[i][j]),
                .addra(data_bank_addr[i][j]),
                .dina (data_bank_wdata[i][j]),
                .douta(data_bank_rdata[i][j])
            );
        end
    end
    endgenerate

    // cpu interface
    assign addr_ok = cur_state[`IDLE]
                   | cur_state[`LOOKUP] & valid &  op & cache_hit
                   | cur_state[`LOOKUP] & valid & ~op & cache_hit & ~hit_write_hazard;
    assign data_ok = cur_state[`LOOKUP] & cache_hit
                   | cur_state[`LOOKUP] & op_reg
                   | cur_state[`REFILL] & ret_valid & ~op_reg & ret_cnt == offset_reg[3:2];
    assign rdata = ret_valid ? ret_data : load_res;

    // axi interface
    assign rd_req  = cur_state[`REPLACE];
    assign rd_type = 3'b100;
    assign rd_addr = {tag_reg, index_reg, offset_reg};

    assign wr_req = wr_req_r;
    always @ (posedge clk) begin
        if (rst) begin
            wr_req_r <= 1'b0;
        end else if (cur_state[`MISS] & wr_rdy & d_table[replace_way][index_reg]) begin
            wr_req_r <= 1'b1;
        end else begin
            wr_req_r <= 1'b0;
        end
    end
    assign wr_type  = 3'b100;
    assign wr_addr  = {tagv_rdata[replace_way][19:0], index_reg, offset_reg};
    assign wr_wstrb = 4'hf;
    assign wr_data  = {data_bank_rdata[replace_way][3],
                       data_bank_rdata[replace_way][2],
                       data_bank_rdata[replace_way][1],
                       data_bank_rdata[replace_way][0]};
endmodule
