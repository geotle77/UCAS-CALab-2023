`timescale 1ns / 1ps


//booth乘法器顶层模�?
module booth_multiplier(
    input clk,
    input  [33:0] x, //被乘�?
    input  [33:0] y, //乘数
    output [67:0] z  //乘积
);

//生成部分积（partial product generator, ppg�?
wire [67:0] ppg_p [16:0];
wire [16:0] ppg_c;

genvar i;
generate
    for (i=0; i<17; i=i+1) begin : ppg_loop
        partial_product_generator u_ppg(
            .x({{(34-2*i){x[33]}}, x, {(2*i){1'b0}}}),
            .y({y[2*i+1], y[2*i], i==0?1'b0:y[2*i-1]}),
            .p(ppg_p[i]),
            .c(ppg_c[i])
        );
    end
endgenerate

//华莱士树（wallace tree, wt�?
wire [14:0] wt_cio [68:0];
wire [67:0] wt_c;
wire [67:0] wt_s;

assign wt_cio[0] = ppg_c[14:0];

genvar j;
generate
    for (j=0; j<34; j=j+1) begin : wt_loop_1
        wallace_tree u_wt(
            .n      ({
                        ppg_p[16][j],
                        ppg_p[15][j], ppg_p[14][j], ppg_p[13][j], ppg_p[12][j], 
                        ppg_p[11][j], ppg_p[10][j], ppg_p[ 9][j], ppg_p[ 8][j], 
                        ppg_p[ 7][j], ppg_p[ 6][j], ppg_p[ 5][j], ppg_p[ 4][j], 
                        ppg_p[ 3][j], ppg_p[ 2][j], ppg_p[ 1][j], ppg_p[ 0][j]
                    }),
            .cin    (wt_cio[j]),
            .cout   (wt_cio[j+1]),
            .c      (wt_c[j]),
            .s      (wt_s[j])
        );
        
    end
endgenerate

//////////pipeline_start//////////

reg [14:0] wt_cio_reg [68:0];
reg [67:0] wt_c_reg;
reg [67:0] wt_s_reg;

genvar l;
generate
    for (l=0; l<68; l=l+1) begin : reg_loop
        always @(posedge clk) begin
            wt_cio_reg[l] <= wt_cio[l];
        end
    end
endgenerate
always @(posedge clk) begin
    wt_c_reg <= wt_c;
    wt_s_reg <= wt_s;
end

//////////pipeline_end//////////




genvar k;
generate
    for (k=34; k<68; k=k+1) begin : wt_loop_2
        wallace_tree u_wt(
            .n      ({
                        ppg_p[16][k],
                        ppg_p[15][k], ppg_p[14][k], ppg_p[13][k], ppg_p[12][k], 
                        ppg_p[11][k], ppg_p[10][k], ppg_p[ 9][k], ppg_p[ 8][k], 
                        ppg_p[ 7][k], ppg_p[ 6][k], ppg_p[ 5][k], ppg_p[ 4][k], 
                        ppg_p[ 3][k], ppg_p[ 2][k], ppg_p[ 1][k], ppg_p[ 0][k]
                    }),
            .cin    (wt_cio[k]),
            .cout   (wt_cio[k+1]),
            .c      (wt_c[k]),
            .s      (wt_s[k])
        );
        
    end
endgenerate

//64位加法器
assign z = {wt_c[66:0], ppg_c[15]} + wt_s[67:0] + ppg_c[16];

endmodule


//部分积生成模�?
module partial_product_generator #(
    parameter XWIDTH = 68
)(
    input  [XWIDTH-1:0] x, //被乘�?
    input  [       2:0] y, //y_{i+1}, y_{i}, y_{i-1}
    output [XWIDTH-1:0] p, //部分�?
    output              c  //进位
);

wire sn;
wire sp;
wire sn2;
wire sp2;

assign sn  = ~(~( y[2]& y[1]&~y[0]) & ~( y[2]&~y[1]& y[0]));
assign sp  = ~(~(~y[2]& y[1]&~y[0]) & ~(~y[2]&~y[1]& y[0]));
assign sn2 = ~(~( y[2]&~y[1]&~y[0]));
assign sp2 = ~(~(~y[2]& y[1]& y[0]));

assign p[0] =  ~(~(sn&~x[0]) & ~(sp&x[0]) & ~sn2);
genvar i;
generate
    for (i=1; i<XWIDTH; i=i+1) begin : result_selector_loop
        assign p[i] = ~(~(sn&~x[i]) & ~(sn2&~x[i-1]) & ~(sp&x[i]) & ~(sp2&x[i-1]));
    end
endgenerate

assign c = sn | sn2;

endmodule


//�?比特全加器模�?
module one_bit_adder(
    input  a,   //加数
    input  b,   //被加�?
    input  c,   //进位输入
    output s,   //�?
    output cout //进位输出
);

assign s = ~(~(a&~b&~c) & ~(~a&b&~c) & ~(~a&~b&c) & ~(a&b&c));
assign cout = a&b | a&c | b&c;

endmodule


//华莱士树模块
module wallace_tree(
    input  [16:0] n,    //加数
    input  [14:0] cin,  //进位传�?�输�?
    output [14:0] cout, //进位传�?�输�?
    output        c,    //进位输出
    output        s     //�?
);

wire [15:0] adder_a;
wire [15:0] adder_b;
wire [15:0] adder_c;
wire [15:0] adder_s;
wire [15:0] adder_cout;
genvar i;
generate
    for (i=0; i<16; i=i+1) begin : adder_loop
        one_bit_adder u_adder(
            .a(adder_a[i]),
            .b(adder_b[i]),
            .c(adder_c[i]),
            .s(adder_s[i]),
            .cout(adder_cout[i])
        );
    end
endgenerate

// level 1
wire [11:0] l1;
assign {adder_a[5:0], adder_b[5:0], adder_c[5:0]} = {n[16:0], 1'b0};
assign cout[5:0] = adder_cout[5:0];
assign l1 = {adder_s[5:0], cin[5:0]};

// level 2
wire [7:0] l2;
assign {adder_a[9:6], adder_b[9:6], adder_c[9:6]} = {l1[11:0]};
assign cout[9:6] = adder_cout[9:6];
assign l2 = {adder_s[9:6], cin[9:6]};

// level 3
wire [5:0] l3;
assign {adder_a[11:10], adder_b[11:10], adder_c[11:10]} = l2[5:0];
assign cout[11:10] = adder_cout[11:10];
assign l3 = {adder_s[11:10], l2[7:6], cin[11:10]};

// level 4
wire [3:0] l4;
assign {adder_a[13:12], adder_b[13:12], adder_c[13:12]} = l3[5:0];
assign cout[13:12] = adder_cout[13:12];
assign l4 = {adder_s[13:12], cin[13:12]};

// level 5
wire [2:0] l5;
assign {adder_a[14], adder_b[14], adder_c[14]} = l4[2:0];
assign cout[14] = adder_cout[14];
assign l5 = {adder_s[14], l4[3], cin[14]};

// level 6
assign {adder_a[15], adder_b[15], adder_c[15]} = l5[2:0];
assign c = adder_cout[15];
assign s = adder_s[15];

endmodule