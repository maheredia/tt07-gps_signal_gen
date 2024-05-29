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
  input [15:0]    ca_phase_in         ,
  input [7:0]     doppler_in          ,
  input [7:0]     snr_in              ,
  output reg      start_out           ,
  output reg      noise_start_out     ,
  output          sin_out             ,
  output          cos_out              
);

//Local parameters:
localparam NCO_FREQ_CTRL_WORD_LEN = 14;
localparam NCO_PHASE_ACC_BITS     = 15;
localparam NCO_TRUNCATED_BITS     = 2 ;
localparam NCO_DATA_BITS_OUT      = 1 ;
localparam NB_NOISE_GEN           = 5 ;
localparam N_NOISE_GENERATORS     = 5 ;
localparam NB_NOISE_FULL          = NB_NOISE_GEN + $clog2(N_NOISE_GENERATORS);
localparam NB_SIG_FULL            = NB_NOISE_FULL ;
localparam GC_OVERSAMPLED_LENGTH  = 1023*16;
localparam MSG_BIT_LENGTH         = 20*GC_OVERSAMPLED_LENGTH ;
localparam NB_MSG_CNTR            = $clog2(MSG_BIT_LENGTH)   ;
localparam MSG_PRESET             = 32'hFEEDCAFE             ;

//Internal signals:
wire                              nav_msg          ;
reg  [31:0]                       nav_msg_prst_reg ;
reg  [NB_MSG_CNTR-1:0]            nav_msg_cntr     ;
reg  [15:0]                       gc_phase_cntr    ;
wire                              gc_ena           ;
reg  [3:0]                        gc_prescaler     ;
wire                              gc               ;
wire [NCO_FREQ_CTRL_WORD_LEN-1:0] nco_phi          ;
wire                              nco_sin          ;
wire                              nco_cos          ;
reg                               nco_sin_reg      ;
reg                               nco_cos_reg      ;
wire                              cos_clean        ;
wire                              sin_clean        ;
wire signed [NB_SIG_FULL-1:0]     sin_full         ;
wire signed [NB_SIG_FULL-1:0]     sin_shft         ;
wire signed [NB_NOISE_GEN-1:0]    noise[N_NOISE_GENERATORS-1:0] ;
reg  signed [NB_NOISE_FULL-1:0]   noise_full       ;
wire [N_NOISE_GENERATORS-1:0]     noise_start      ;
wire signed [NB_SIG_FULL:0]       output_adder     ;
integer                           i_n              ;

/*------------------------LOGIC BEGINS----------------------------------*/

//Gold codes generator:
always @ (posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
  begin
    gc_phase_cntr <= 16'd0;
    gc_prescaler  <= 4'b0000;
  end
  else if(ena_in==1'b1)
  begin
    gc_prescaler <= gc_prescaler + 1'b1;
    if(gc_phase_cntr < GC_OVERSAMPLED_LENGTH-1)
      gc_phase_cntr <= gc_phase_cntr + 1'b1;
    else
      gc_phase_cntr <= 16'd0;
  end
end
assign gc_ena = ena_in & &gc_prescaler;
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
always @ (posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
  begin
    nco_sin_reg <= 1'b0;
    nco_cos_reg <= 1'b0;
  end
  else
  begin
    nco_sin_reg <= nco_sin;
    nco_cos_reg <= nco_cos;
  end
end

//Message selector:
always @ (posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
  begin
    nav_msg_cntr     <= {(NB_MSG_CNTR){1'b0}};
    nav_msg_prst_reg <= MSG_PRESET;
  end
  else if(ena_in==1'b1)
  begin
    if(nav_msg_cntr<MSG_BIT_LENGTH-1)
    begin
      nav_msg_cntr     <= nav_msg_cntr + 1'b1;
      nav_msg_prst_reg <= nav_msg_prst_reg;
    end
    else
    begin
      nav_msg_cntr     <= {(NB_MSG_CNTR){1'b0}};
      nav_msg_prst_reg <= {nav_msg_prst_reg[0], nav_msg_prst_reg[31:1]};
    end
  end
end
assign nav_msg = (use_msg_preset_in==1'b1) ? (nav_msg_prst_reg[0]) : (msg_in);

//Clean signals:
assign sin_clean = (signal_off_in == 1'b1) ? (1'b0) : (nav_msg^gc^nco_sin_reg);
assign cos_clean = (signal_off_in == 1'b1) ? (1'b0) : (nav_msg^gc^nco_cos_reg);

//Noise generators:
genvar ii;
generate
  for(ii=0; ii<N_NOISE_GENERATORS; ii=ii+1)
  begin: prng_gen
    prng
    #(
      .OUT_BITS(NB_NOISE_GEN),
      .INITIAL_STATE_SHIFT(16+2*ii)
    )
    prng
    (
      .clk_in    ( clk_in                     ),
      .rst_in_n  ( rst_in_n & ~noise_off_in   ),
      .ena_in    ( 1'b1                       ),
      .start_out ( noise_start[ii]            ),
      .lfsr_out  ( noise[ii]                  ) 
    );
  end
endgenerate

always @(*)
begin
  noise_full = {(NB_NOISE_FULL){1'b0}};
  for(i_n=0; i_n<N_NOISE_GENERATORS; i_n=i_n+1)
  begin
    noise_full = noise_full + noise[i_n];
  end
end

//Output adder:
//sin_full takes 0x7F or 0x80 values:
assign sin_full = (sin_clean==1'b1) ? ({1'b1, {(NB_SIG_FULL-1){1'b0}}}) : ({1'b0, {(NB_SIG_FULL-1){1'b1}}});
assign sin_shft = (sin_full >>> snr_in);
assign output_adder = noise_full + sin_shft;

//Outputs:
assign sin_out   =  output_adder[NB_SIG_FULL];
assign cos_out   =  cos_clean; //TODO
always @ (posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
  begin
    start_out       <= 1'b0;
    noise_start_out <= 1'b0;
  end
  else
  begin
    start_out       <= ena_in & (gc_phase_cntr == ca_phase_in);
    noise_start_out <= ~noise_off_in & noise_start[0];
  end
end
endmodule
