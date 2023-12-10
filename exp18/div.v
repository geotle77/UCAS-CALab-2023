module DIV(
    input  wire    clk,
    input  wire    resetn,
    input  wire    div_en,
    input  wire    sign,
    input  wire [31:0] divisor,   
    input  wire [31:0] dividend,  
    output wire [63:0] result,
    output wire    complete 
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
    reg  [32:0] remainder_reg;    
    reg  [ 5:0] counter;

    assign sign_s = (divisor[31]^dividend[31]) & sign;
    assign sign_r = divisor[31] & sign;
    assign divisor_abs  = (sign & divisor[31]) ? (~divisor+1'b1): divisor;
    assign dividend_y  = (sign & dividend[31]) ? (~dividend+1'b1): dividend;

    assign complete = counter[5]&counter[0]&(~|counter[4:1]);
    
    always @(posedge clk) begin
        if(~resetn) begin
            counter <= 6'b0;
        end
        else if(div_en) begin
            if(complete)
                counter <= counter;
            else
                counter <= counter + 1'b1;
            end
        else begin
                 counter <= 6'b0;            
            end
    end

    always @(posedge clk) begin
        if(~resetn)
            {divisor_pad, dividend_pad} <= {64'b0, 33'b0};
        else if(div_en) begin
            if(~|counter)
                {divisor_pad, dividend_pad} <= {32'b0, divisor_abs, 1'b0, dividend_y};
        end
    end

    assign pre_r =  remainder_reg - dividend_pad;                  
    assign recover_r = pre_r[32] ? remainder_reg : pre_r;    
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
            if(~|counter)   
                remainder_reg <= {32'b0, divisor_abs[31]};
            else
                remainder_reg <=  (counter[5]&(~|counter[4:0])) ? recover_r : {recover_r, divisor_pad[31 - counter]};
        end
    end
    
    assign quotient = sign & sign_s ? (~quotient_reg+1'b1) : quotient_reg;
    assign remainder = sign & sign_r ? (~remainder_reg+1'b1) : remainder_reg;
    
    assign result = (|divisor) ? {quotient,remainder} :{32'b0,remainder }; 
endmodule