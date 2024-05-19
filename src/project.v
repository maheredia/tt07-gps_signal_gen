/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
// just a stub to keep the Tiny Tapeout tools happy
module tt_um_maheredia (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.
  assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
  assign uio_out = 0;
  assign uio_oe  = 0;

reg_bank
#(
  .CLKS_PER_BIT(142)
)
reg_bank
(
  .clk_in             (clk          ),
  .rst_in_n           (rst_n        ),
  .code_phase_done    (1'b0         ),
  .rx_in              (ui_in[0]     ),
  .tx_out             (uo_out[0]    ),
  .enable_out         (uo_out[1]  ),
  .n_sat_out          (             ),
  .use_preset_out     (uo_out[2]  ),
  .use_msg_preset_out (uo_out[3]  ),
  .noise_off_out      (uo_out[4]  ),
  .signal_off_out     (             ),
  .ca_phase_out       (             ),
  .doppler_out        (             ),
  .snr_out            (             )  
);

endmodule
