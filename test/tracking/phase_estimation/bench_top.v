


module bench_top
(
  input           clk_in   ,
  input           rst_in_n ,
  input           msg_in   ,
  input  [3:0]    btns_in  ,
  input           rx_in    ,
  //output          tx_out   ,
  output [3:0]    leds_out  
);

//Local parameters:
localparam GC_OVERSAMPLED_LENGTH  = 1023*16;

//Internal signals:
wire             general_enable  ;
wire [4:0]       n_sat           ;
wire             use_preset      ;
wire             use_msg_preset  ;
wire             noise_off       ;
wire             signal_off      ;
wire             ca_phase_start  ;
wire [15:0]      ca_phase        ;
wire [7:0]       doppler         ;
wire [7:0]       snr             ;
wire             code_phase_done ;
//Bench gold code removal:
reg  [15:0]      gc_phase_cntr    ;
wire             gc_ena           ;
reg  [3:0]       gc_prescaler     ;
wire             gc_removal       ;
wire             sin_from_core    ;
wire             cos_from_core    ;
wire             sin_gc_removal   ;
wire             cos_gc_removal   ;
//Bench NCO:
wire [14-1:0]    nco_phi          ; //NCO_FREQ_CTRL_WORD_LEN
wire             bench_nco_sin    ;
wire             bench_nco_cos    ;
//Bench shift register for NCO phase selector:
reg  [31:0]      sin_shift_reg    ;
reg  [31:0]      cos_shift_reg    ;
wire             sin_shift_out    ;
wire             cos_shift_out    ;
reg  [4:0]       shift_out_selector;
reg  [1:0]       pulse_detect_up   ;
reg  [1:0]       pulse_detect_down ;
//Bench correlator:
wire              sin_mix          ;
wire              cos_mix          ;
wire              x_i_p            ;
wire              x_q_p            ;
reg signed [15:0] accum_I          ;
reg signed [15:0] accum_Q          ;
reg [15:0]        accum_cntr       ;
reg               accum_done       ;
reg signed [15:0] accum_I_last     ;
reg signed [15:0] accum_Q_last     ;
//Bench PWM to LEDs:
reg [15:0]        pwm_cntr         ;
reg [15:0]        I_pos_ref        ;
reg [15:0]        I_neg_ref        ;
reg [15:0]        Q_pos_ref        ;
reg [15:0]        Q_neg_ref        ;

reg_bank
#(
  .CLKS_PER_BIT(142)
)
reg_bank
(
  .clk_in             ( clk_in              ),
  .rst_in_n           ( rst_in_n            ),
  .code_phase_done    ( code_phase_done     ),
  .rx_in              ( rx_in               ),
  .tx_out             ( tx_out              ),
  .enable_out         ( general_enable      ),
  .n_sat_out          ( n_sat               ),
  .use_preset_out     ( use_preset          ),
  .use_msg_preset_out ( use_msg_preset      ),
  .noise_off_out      ( noise_off           ),
  .signal_off_out     ( signal_off          ),
  .ca_phase_start_out ( ca_phase_start      ),
  .ca_phase_out       ( ca_phase            ),
  .doppler_out        ( doppler             ),
  .snr_out            ( snr                 )  
);

//Core:
gps_gen_core core
(
  .clk_in              ( clk_in          ),
  .rst_in_n            ( rst_in_n        ),
  .ena_in              ( general_enable  ),
  .msg_in              ( msg_in          ),
  .n_sat_in            ( n_sat           ),
  .noise_off_in        ( noise_off       ),
  .signal_off_in       ( signal_off      ),
  .ca_phase_in         ( ca_phase        ),
  .doppler_in          ( doppler         ),
  .snr_in              ( snr             ),
  .start_out           (                 ),
  .sin_out             ( sin_from_core   ),
  .cos_out             ( cos_from_core   )
);

//ca_gen to remove effect of code modulation for this test:
always @ (posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
  begin
    gc_phase_cntr <= 16'd0;
    gc_prescaler  <= 4'b0000;
  end
  else if(general_enable==1'b1)
  begin
    gc_prescaler <= gc_prescaler + 1'b1;
    if(gc_phase_cntr < GC_OVERSAMPLED_LENGTH-1)
      gc_phase_cntr <= gc_phase_cntr + 1'b1;
    else
      gc_phase_cntr <= 16'd0;
  end
end
assign gc_ena = general_enable & &gc_prescaler;

gc_gen gc_gen_removal
(
  .rst_in_n   ( rst_in_n  ),
  .clk_in     ( clk_in    ),
  .ena_in     ( gc_ena    ),
  .sat_sel_in ( n_sat     ),
  .gc_out     ( gc_removal) 
);

assign sin_gc_removal = sin_from_core ^ gc_removal;
assign cos_gc_removal = cos_from_core ^ gc_removal;

//Bench NCO:
assign nco_phi = 14'd8000 + doppler;

nco
#(
  .FREQ_CTRL_WORD_LEN ( 14 ), //NCO_FREQ_CTRL_WORD_LEN
  .PHASE_ACC_BITS     ( 15 ), //NCO_PHASE_ACC_BITS
  .TRUNCATED_BITS     (  2 ), //NCO_TRUNCATED_BITS 
  .DATA_BITS_OUT      (  1 )  //NCO_DATA_BITS_OUT 
)
nco
(
  .delta_phi ( nco_phi         ),
  .clk       ( clk_in          ), 
  .ena       ( general_enable  ), 
  .rst       ( ~rst_in_n       ), 
  .sin       ( bench_nco_sin   ),
  .cos       ( bench_nco_cos   ) 
);

always @ (posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
  begin
    sin_shift_reg      <= 32'd0;
    cos_shift_reg      <= 32'd0;
    pulse_detect_up    <= 2'b00;
    pulse_detect_down  <= 2'b00;
    shift_out_selector <= 5'b00000;
  end
  else
  begin
    pulse_detect_up[0]   <= btns_in[0];
    pulse_detect_up[1]   <= pulse_detect_up[0];
    pulse_detect_down[0] <= btns_in[1];
    pulse_detect_down[1] <= pulse_detect_down[0];
    sin_shift_reg        <= {sin_shift_reg[62:0], bench_nco_sin};
    cos_shift_reg        <= {cos_shift_reg[62:0], bench_nco_cos};
    if(pulse_detect_up[1] == 1'b1 && pulse_detect_up[0] == 1'b0)
    begin
      shift_out_selector <= shift_out_selector + 1'b1;
    end
    else if(pulse_detect_down[1] == 1'b1 && pulse_detect_down[0] == 1'b0)
    begin
      shift_out_selector <= shift_out_selector - 1'b1;
    end
  end
end

assign sin_shift_out = sin_shift_reg[shift_out_selector];
assign cos_shift_out = cos_shift_reg[shift_out_selector];

//Correlator:
assign sin_mix = sin_shift_out ^ sin_gc_removal;
assign cos_mix = cos_shift_out ^ cos_gc_removal;
assign x_i_p   = cos_gc_removal ^ cos_shift_out;
assign x_q_p   = cos_gc_removal ^ sin_shift_out;

always @ (posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
  begin
    accum_I      <= 16'd0 ;
    accum_Q      <= 16'd0 ;
    accum_cntr   <= 16'd0 ;
    accum_done   <= 1'b0  ;
    accum_I_last <= 16'd0 ;
    accum_Q_last <= 16'd0 ;
  end
  else
  begin
    if((accum_cntr < (1023*16)-1) && (general_enable == 1'b1))
    begin
      accum_cntr <= accum_cntr + 1'b1;
      accum_done <= 1'b0;
      if(x_i_p == 1'b0)
        accum_I <= accum_I + 1;
      else
        accum_I <= accum_I - 1;

      if(x_q_p == 1'b0)
        accum_Q <= accum_Q + 1;
      else
        accum_Q <= accum_Q - 1;
    end
    else
    begin
      accum_cntr   <= 16'd0   ;
      accum_done   <= 1'b1    ;
      accum_I      <= 16'd0   ;
      accum_Q      <= 16'd0   ;
      accum_I_last <= accum_I ;
      accum_Q_last <= accum_Q ;
    end
  end
end

//PWM:
always @ (posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
  begin
    I_pos_ref <= 16'd0;
    I_neg_ref <= 16'd0;
    Q_pos_ref <= 16'd0;
    Q_neg_ref <= 16'd0;
    pwm_cntr  <= 16'd0;
  end
  else if(general_enable == 1'b1)
  begin
    if(pwm_cntr < (1023*16)-1)
      pwm_cntr <= pwm_cntr + 1'b1;
    else
      pwm_cntr <= 16'd0;

    if(accum_I_last < 0)
    begin
      I_pos_ref <= 16'd0;
      I_neg_ref <= (~accum_I_last) + 1'b1;
    end
    else
    begin
      I_pos_ref <= accum_I_last;
      I_neg_ref <= 16'd0;
    end

    if(accum_Q_last < 0)
    begin
      Q_pos_ref <= 16'd0;
      Q_neg_ref <= (~accum_Q_last) + 1'b1;
    end
    else
    begin
      Q_pos_ref <= accum_Q_last;
      Q_neg_ref <= 16'd0;
    end
  end
end

//Outputs:
assign leds_out[0] = pwm_cntr < I_pos_ref;
assign leds_out[1] = pwm_cntr < I_neg_ref;
assign leds_out[2] = pwm_cntr < Q_pos_ref;
assign leds_out[3] = pwm_cntr < Q_neg_ref;
endmodule