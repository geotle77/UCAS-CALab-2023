module DIV(
    input  wire    clk,
    input  wire    resetn,
    input  wire    div_en,
    input  wire    div_signed,
    input  wire [31:0] divisor,   //������
    input  wire [31:0] dividend,   //����
    output wire [63:0] result,
    output wire    complete //��������ź�
);

    wire [31:0] quotient;
    wire [31:0] remainder;
    wire        sign_s;
    wire        sign_r;
    wire [31:0] divisor_abs;
    wire [31:0] dividend_y;
    wire [32:0] pre_r;
    wire [32:0] recover_r;
    reg  [63:0] divisor_pad;
    reg  [32:0] dividend_pad;
    reg  [31:0] quotient_reg;
    reg  [32:0] remainder_reg;    // ��ǰ������
    reg  [ 5:0] counter;

// 1.ȷ������λ
    assign sign_s = (divisor[31]^dividend[31]) & div_signed;
    assign sign_r = divisor[31] & div_signed;
    assign divisor_abs  = (div_signed & divisor[31]) ? (~divisor+1'b1): divisor;
    assign dividend_y  = (div_signed & dividend[31]) ? (~dividend+1'b1): dividend;
// 2.ѭ�������õ��̺���������ֵ
    assign complete = counter[5]&counter[0]&|counter[4:1];
    //��ʼ��������
    always @(posedge clk) begin
        if(~resetn) begin
            counter <= 6'b0;
        end
        else if(div_en) begin
            if(complete)
                counter <= 6'b0;
            else
                counter <= counter + 1'b1;
        end
    end
    //׼��������,counter=0
    always @(posedge clk) begin
        if(~resetn)
            {divisor_pad, dividend_pad} <= {64'b0, 33'b0};
        else if(div_en) begin
            if(~|counter)
                {divisor_pad, dividend_pad} <= {32'b0, divisor_abs, 1'b0, dividend_y};
        end
    end

    //��⵱ǰ�����ļ������
    assign pre_r = remainder_reg - dividend_pad;                     //δ�ָ������Ľ��
    assign recover_r = pre_r[32] ? remainder_reg : pre_r;     //�ָ������Ľ��
    always @(posedge clk) begin
        if(~resetn) 
            quotient_reg <= 32'b0;
        else if(div_en & ~complete & |counter) begin
            quotient_reg[32-counter] <= ~pre_r[32];
        end
    end
    always @(posedge clk) begin
        if(~resetn)
            remainder_reg <= 33'b0;
        if(div_en & ~complete) begin
            if(~|counter)   //������ʼ��
                remainder_reg <= {32'b0, divisor_abs[31]};
            else
                remainder_reg <=  (~counter[5]&(&counter)) ? recover_r : {recover_r, divisor_pad[31 - counter]};
        end
    end
// 3.���������̺�����
    assign quotient = div_signed & sign_s ? (~quotient_reg+1'b1) : quotient_reg;
    assign remainder = div_signed & sign_r ? (~remainder_reg+1'b1) : remainder_reg;
    assign result ={quotient,remainder};
endmodule