module prng
#(
  parameter                   OUT_BITS      = 4 ,
  parameter                   N_BITS_REGS   = 31,
  parameter [63:0]            POLY          = 31'b1001000000000000000000000000000,
  parameter [N_BITS_REGS-1:0] INITIAL_STATE = (1<<(N_BITS_REGS-1))
)
(
  input                           clk_in    ,
  input                           rst_in_n  ,
  input                           ena_in    ,
  output                          start_out ,
  output  signed [OUT_BITS-1:0]   lfsr_out    
);

//Internal signals:
reg  [N_BITS_REGS-1:0]    lfsr_reg    ;
reg  [N_BITS_REGS-1:0]    lfsr_next   ;
reg  [OUT_BITS-1:0]       lfsr_output ;
integer                   ff          ;

//PRBS:

always @(*)
begin
  for(ff=0; ff<N_BITS_REGS; ff=ff+1)
  begin
    if(ff<OUT_BITS)
      lfsr_next[ff] = ^(lfsr_reg & (POLY[N_BITS_REGS-1:0] >> (OUT_BITS - 1 - ff)));
    else
      lfsr_next[ff] = lfsr_reg[ff-OUT_BITS];
  end
end

always @ (posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
    lfsr_reg <= INITIAL_STATE;
  else if(ena_in==1'b1)
    lfsr_reg <= lfsr_next;
end

//Outputs:
assign lfsr_out  = lfsr_reg[OUT_BITS-1:0];
assign start_out = ena_in & (lfsr_reg==INITIAL_STATE);
endmodule
