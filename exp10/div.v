module DIV(
    input wire clk,
    input wire resetn,
    input wire         sign,    //1为有符号，0为无符号
    input wire         div_en,
    input wire  [31:0] divisor, //
    input wire  [31:0] dividend,
    output wire [63:0] result,
    output wire        flag
    );

    //除数和被除数的绝对值
    wire [31:0] X_abs;
    wire [31:0] Y_abs;
    reg  [5:0]  counter;//计数器，33拍算出结果

    wire X_signed=divisor[31]&sign;
    wire Y_signed=dividend[31]&sign;

    wire        sign_s;
    wire        sign_r;

    assign sign_s = (divisor[31]^dividend[31]) & sign;
    assign sign_r = divisor[31] & sign;

    wire complete;
    assign complete =counter[5]&counter[0]&(~|counter[4:1]);
    assign flag=complete;
    always @(posedge clk )begin
        if(!resetn)begin
            counter <= 6'd0;
            //flag <= 1'b0;
        end
        else if(div_en)begin
            if(complete)
                counter <= 6'd0;
            else
                counter <= counter + 6'd1;
        end
    end

    
    wire [63:0] result_temp;
    wire [32:0] Y_pad;

    assign X_abs =(32{X_signed}^divisor) + X_signed;
    assign Y_abs =(32{Y_signed}^dividend) + Y_signed;
    

    //初始化除数和被除数
    always @(posedge clk)begin
        if(!resetn)begin
            {result_temp,Y_pad}<= {64'b0,33'b0};
            end
        else if(div_en)begin
            if(counter==6'b0)begin
                {result_temp,Y_pad}<= {32'b0,X_abs,1'b0,Y_abs};
                end
            end

    wire [32:0] pre_remainder;
    wire [32:0] cover_remainder;
    wire [31:0] sum_remainder;
    wire [32:0] current_remainder;

    assign pre_remainder   = current_remainder-Y_pad;
    assign cover_remainder = pre_remainder[32] ? current_remainder:pre_remainder;//恢复余数法
    always @(posedge clk)begin
        if(!resetn)begin
            sum_remainder <= 32'b0;
        end
        else if(div_en& ~complete & counter!=6'b0 )begin
            sum_remainder[32-counter] <= ~pre_remainder[32];
        end
    end

    always @(posedge clk)begin
        if(!resetn)begin
            current_remainder <= 33'b0;
        end
        if(div_en& ~complete)begin
            if(~|counter)begin
            current_remainder <= {32'b0,X_abs[31]};
            end
            else begin
            current_remainder <= (&counter[4:0]) ? cover_remainder:{cover_remainder,result_temp[31-counter]};
            end
        end
    end

    assign result[31:0]= sign & sign_s ? (~result_temp + 1) : result_temp;
    assign result[63:32] = sign & sign_r ? (~current_remainder + 1) : current_remainder;
endmodule

