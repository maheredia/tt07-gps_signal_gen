`include "reg_bank.v" 
`include "uart_tx.v"
`include "uart_rx.v"

module fpga_top
(
  input           clk_in   ,
  input           rst_in_n ,
  input           rx_in    ,
  output          tx_out   ,
  output [3:0]    leds_out  
);

reg_bank
#(
  .CLKS_PER_BIT(142)
)
reg_bank
(
  .clk_in             (clk_in       ),
  .rst_in_n           (rst_in_n     ),
  .code_phase_done    (1'b0         ),
  .rx_in              (rx_in        ),
  .tx_out             (tx_out       ),
  .enable_out         (leds_out[0]  ),
  .n_sat_out          (             ),
  .use_preset_out     (leds_out[1]  ),
  .use_msg_preset_out (leds_out[2]  ),
  .noise_off_out      (leds_out[3]  ),
  .signal_off_out     (             ),
  .ca_phase_out       (             ),
  .doppler_out        (             ),
  .snr_out            (             )  
);

endmodule