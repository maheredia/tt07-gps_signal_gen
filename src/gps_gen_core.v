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
  output          sin_out             ,
  output          cos_out              
);

//Local parameters:
localparam NCO_FREQ_CTRL_WORD_LEN = 14;
localparam NCO_PHASE_ACC_BITS     = 15;
localparam NCO_TRUNCATED_BITS     = 2 ;
localparam NCO_DATA_BITS_OUT      = 1 ;
localparam NB_NOISE_GEN           = 5 ;

//Internal signals:
wire                              navigation_msg   ;
reg  [15:0]                       gc_phase_cntr    ;
wire                              gc_ena           ;
wire                              gc               ;
wire [NCO_FREQ_CTRL_WORD_LEN-1:0] nco_phi          ;
wire                              nco_sin          ;
wire                              nco_cos          ;
wire                              cos_clean        ;
wire                              sin_clean        ;
wire [NB_NOISE_GEN-1:0]           noise            ;
wire [NB_NOISE_GEN:0]             output_adder     ;

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
assign nco_phi = 14'd8000 + doppler_in;
nco
#(
  .FREQ_CTRL_WORD_LEN ( NCO_FREQ_CTRL_WORD_LEN),
  .PHASE_ACC_BITS     ( NCO_PHASE_ACC_BITS    ),
  .TRUNCATED_BITS     ( NCO_TRUNCATED_BITS    ), 
  .DATA_BITS_OUT      ( NCO_DATA_BITS_OUT     ) 
)
nco
(
  .delta_phi ( nco_phi   ),
  .clk       ( clk_in    ), 
  .ena       ( ena_in    ), 
  .rst       ( ~rst_in_n ), 
  .sin       ( nco_sin   ),
  .cos       ( nco_cos   ) 
);

//Message selector:
//TODO: define message preset
assign navigation_msg = msg_in;

//Clean signals:
assign sin_clean = (signal_off_in == 1'b1) ? (1'b0) : (navigation_msg^gc^nco_sin);
assign cos_clean = (signal_off_in == 1'b1) ? (1'b0) : (navigation_msg^gc^nco_cos);

//Noise generator:
//TODO
assign noise = 0;

//Output adder:
//TODO:
assign output_adder = 0;
//Outputs:
assign code_phase_done_out = (gc_phase_cntr >= ca_phase_in);
assign sin_out   =  sin_clean; //TODO
assign cos_out   =  cos_clean; //TODO
assign start_out = 1'b0; //TODO 
endmodule