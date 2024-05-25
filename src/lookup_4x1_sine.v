module lookup_4x1_sine
(
	input  wire [1:0] address_in, // 00 01 10 11
	output reg          data_out
);

always @(*) begin
  case (address_in)
    2'b00: data_out =  1'b1 ; 
    2'b01: data_out =  1'b1 ;
    2'b10: data_out =  1'b0 ;
    2'b11: data_out =  1'b0 ;
  endcase
end

endmodule