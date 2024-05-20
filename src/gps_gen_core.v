module gps_gen_core
(
  input           clk_in              ,
  input           rst_in_n            ,
  input           ena_in              ,
  input           msg_in              ,
  input [4:0]     n_sat_in            ,
  input           use_preset_in       ,
  input [1:0]     preset_sel_in       ,
  input           use_msg_preset_in   ,
  input           noise_off_in        ,
  input           signal_off_in       ,
  input           ca_phase_start_in   ,
  input [15:0]    ca_phase_in         ,
  input [7:0]     doppler_in          ,
  input [7:0]     snr_in              ,
  output          code_phase_done_out ,
  output          start_out           ,//TODO: define this one
  output          signal_out           
);

//Local parameters:

//Internal signals:
reg  [15:0] gc_phase_cntr    ;
wire        gc_ena           ;
wire        gc               ;

/*------------------------LOGIC BEGINS----------------------------------*/

//Gold codes generator:

//This counter lets the gc_gen advance its internal state until gor a
//number of samples given by ca_phase_in. This will determine the
//initial phase of the gc_gen.
always @ (posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
  begin
    gc_phase_cntr <= 16'd0;
  end
  else if(ena_in==1'b1)
  begin
    gc_phase_cntr <= 16'd0;
  end
  else if((ca_phase_start_in==1'b1) && (gc_phase_cntr < ca_phase_in))
  begin
    gc_phase_cntr <= gc_phase_cntr + 1'b1;
  end
end
assign gc_ena = (ca_phase_start_in & (gc_phase_cntr < ca_phase_in)) | ena_in;
gc_gen gc_gen
(
  .rst_in_n   ( rst_in_n  ),
  .clk_in     ( clk_in    ),
  .ena_in     ( gc_ena    ),
  .sat_sel_in ( n_sat_in  ),
  .gc_out     ( gc        ) 
);

//NCO:

//Message selector:

//Noise generator:

//Output adder:

//Outputs:
assign code_phase_done_out = (gc_phase_cntr >= ca_phase_in);
assign signal_out = gc ; //TODO
assign start_out = 1'b0; //TODO 
endmodule