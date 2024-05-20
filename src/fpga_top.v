`include "reg_bank.v" 
`include "uart_tx.v"
`include "uart_rx.v"

module fpga_top
(
  input           clk_in   ,
  input           rst_in_n ,
  input           msg_in   ,
  input           rx_in    ,
  output          tx_out   ,
  output [3:0]    leds_out  
);

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
  .clk_in              ( clk             ),
  .rst_in_n            ( rst_n           ),
  .ena_in              ( general_enable  ),
  .msg_in              ( msg_in          ),
  .n_sat_in            ( n_sat           ),
  .use_preset_in       ( use_preset      ),
  .preset_sel_in       ( 2'b11           ),
  .use_msg_preset_in   ( use_msg_preset  ),
  .noise_off_in        ( noise_off       ),
  .signal_off_in       ( signal_off      ),
  .ca_phase_start_in   ( ca_phase_start  ),
  .ca_phase_in         ( ca_phase        ),
  .doppler_in          ( doppler         ),
  .snr_in              ( snr             ),
  .code_phase_done_out ( code_phase_done ),
  .start_out           ( leds_out[0]         ),
  .signal_out          ( leds_out[1]         ) 
);
assign leds_out[3:2] = 2'b00;
endmodule