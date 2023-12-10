module div32(
        input clk,rst_n,
        input div_en,
        input [31:0] a, 
        input [31:0] b,
        output complete,
        output [31:0] s,
        output [31:0] r
        ); 
reg[63:0] temp_a;
reg[63:0] temp_b;
reg[5:0] counter;
reg done_r;
//------------------------------------------------
always @(posedge clk )begin
    if(!rst_n) counter <= 6'd0;
    else if(div_en && counter < 6'd33) counter <= counter+1'b1; 
    else counter <= 6'd0;
end
//------------------------------------------------
always @(posedge clk )
    if(!rst_n) done_r <= 1'b0;
    else if(counter == 6'd32) done_r <= 1'b1;        
    else if(counter == 6'd33) done_r <= 1'b0;        
assign complete = done_r;
//------------------------------------------------
always @ (posedge clk )begin
    if(!rst_n) begin
        temp_a <= 64'h0;
        temp_b <= 64'h0;
    end
    else if(div_en) begin
        if(counter == 6'd0) begin
            temp_a = {32'h00000000,tempa};
            temp_b = {tempb,32'h00000000}; 
        end
        else begin
            temp_a = temp_a << 1;
      if(temp_a >= temp_b) temp_a = temp_a - temp_b + 1'b1;
      else temp_a = temp_a;
        end
     end
end
 
assign s = temp_a[31:0];
assign r = temp_a[63:32];
endmodule