module gc_gen
(
  input         rst_in_n   ,
  input         clk_in     ,
  input         ena_in     ,
  input  [4:0]  sat_sel_in ,
  output reg    gc_out      
);

wire       gc        ;
wire       g1_o      ;
wire       g2_o      ;
reg        g2_xor_a  ;
reg        g2_xor_b  ;
reg  [9:0] g1        ;
reg  [9:0] g2        ;
wire       g1_next   ;
wire       g2_next   ;

//Output
always @ (posedge clk_in, negedge rst_in_n)
begin
    if(rst_in_n==1'b0)
      gc_out <= 1'b0;
    else
      gc_out <= gc;
end

//Combo logic:
assign g1_o     = g1[9];
assign g2_o     = g2_xor_a ^ g2_xor_b;
assign gc       = g1_o ^ g2_o;
assign g1_next  = g1[2] ^ g1[9];
assign g2_next  = g2[1] ^ g2[2] ^ g2[5] ^ g2[7] ^ g2[8] ^ g2[9];

always @ (*)
begin
  case(sat_sel_in)
    5'd0:
    begin
      g2_xor_a = g2[2-1];
      g2_xor_b = g2[6-1];
    end
    5'd1:
    begin
      g2_xor_a = g2[3-1];
      g2_xor_b = g2[7-1];
    end
    5'd2:
    begin
      g2_xor_a = g2[4-1];
      g2_xor_b = g2[8-1];
    end
    5'd3:
    begin
      g2_xor_a = g2[5-1];
      g2_xor_b = g2[9-1];
    end
    5'd4:
    begin
      g2_xor_a = g2[1-1];
      g2_xor_b = g2[9-1];
    end
    5'd5:
    begin
      g2_xor_a = g2[2-1];
      g2_xor_b = g2[10-1];
    end
    5'd6:
    begin
      g2_xor_a = g2[1-1];
      g2_xor_b = g2[8-1];
    end
    5'd7:
    begin
      g2_xor_a = g2[2-1];
      g2_xor_b = g2[9-1];
    end
    5'd8:
    begin
      g2_xor_a = g2[3-1];
      g2_xor_b = g2[10-1];
    end
    5'd9:
    begin
      g2_xor_a = g2[2-1];
      g2_xor_b = g2[3-1];
    end
    5'd10:
    begin
      g2_xor_a = g2[3-1];
      g2_xor_b = g2[4-1];
    end
    5'd11:
    begin
      g2_xor_a = g2[5-1];
      g2_xor_b = g2[6-1];
    end
    5'd12:
    begin
      g2_xor_a = g2[6-1];
      g2_xor_b = g2[7-1];
    end
    5'd13:
    begin
      g2_xor_a = g2[7-1];
      g2_xor_b = g2[8-1];
    end
    5'd14:
    begin
      g2_xor_a = g2[8-1];
      g2_xor_b = g2[9-1];
    end
    5'd15:
    begin
      g2_xor_a = g2[9-1];
      g2_xor_b = g2[10-1];
    end
    5'd16:
    begin
      g2_xor_a = g2[1-1];
      g2_xor_b = g2[4-1];
    end
    5'd17:
    begin
      g2_xor_a = g2[2-1];
      g2_xor_b = g2[5-1];
    end
    5'd18:
    begin
      g2_xor_a = g2[3-1];
      g2_xor_b = g2[6-1];
    end
    5'd19:
    begin
      g2_xor_a = g2[4-1];
      g2_xor_b = g2[7-1];
    end
    5'd20:
    begin
      g2_xor_a = g2[5-1];
      g2_xor_b = g2[8-1];
    end
    5'd21:
    begin
      g2_xor_a = g2[6-1];
      g2_xor_b = g2[9-1];
    end
    5'd22:
    begin
      g2_xor_a = g2[1-1];
      g2_xor_b = g2[3-1];
    end
    5'd23:
    begin
      g2_xor_a = g2[4-1];
      g2_xor_b = g2[6-1];
    end
    5'd24:
    begin
      g2_xor_a = g2[5-1];
      g2_xor_b = g2[7-1];
    end
    5'd25:
    begin
      g2_xor_a = g2[6-1];
      g2_xor_b = g2[8-1];
    end
    5'd26:
    begin
      g2_xor_a = g2[7-1];
      g2_xor_b = g2[9-1];
    end
    5'd27:
    begin
      g2_xor_a = g2[8-1];
      g2_xor_b = g2[10-1];
    end
    5'd28:
    begin
      g2_xor_a = g2[1-1];
      g2_xor_b = g2[6-1];
    end
    5'd29:
    begin
      g2_xor_a = g2[2-1];
      g2_xor_b = g2[7-1];
    end
    5'd30:
    begin
      g2_xor_a = g2[3-1];
      g2_xor_b = g2[8-1];
    end
    5'd31:
    begin
      g2_xor_a = g2[4-1];
      g2_xor_b = g2[9-1];
    end
  endcase
end

//Sequential logic:
always @ (posedge clk_in, negedge rst_in_n)
begin
  if(rst_in_n==1'b0)
  begin
    g1 <= {10{1'b1}};
    g2 <= {10{1'b1}};
  end
  else if(ena_in==1'b1)
  begin
    g1 <= {g1[8:0],g1_next};
    g2 <= {g2[8:0],g2_next};
  end
end
endmodule
