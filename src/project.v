/*
 * Copyright (c) 2024 Grupo de Aplicaciones en Sistemas Embebidos - UTN FRH
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

//All output pins must be assigned. If not used, assign to 0.
assign uo_out  = {4'd0, start_out, noise_start_out, cos_out, sin_out};
assign uio_out = 0;
assign uio_oe  = 0;

//Internal signals:
wire             sin_out         ;
wire             cos_out         ;
wire             start_out       ;
wire             noise_start_out ;
wire             general_enable  ;
wire [4:0]       n_sat           ;
wire             use_preset      ;
wire             use_msg_preset  ;
wire             noise_off       ;
wire             signal_off      ;
wire [15:0]      ca_phase        ;
wire [7:0]       doppler         ;
wire [7:0]       snr             ;

//Register bank:
reg_bank_reduced
#(
  .CLKS_PER_BIT(142)
)
reg_bank
(
  .clk_in             ( clk                ),
  .rst_in_n           ( rst_n              ),
  .rx_in              ( ui_in[0]           ),
  .enable_out         ( general_enable     ),
  .n_sat_out          ( n_sat              ),
  .use_msg_preset_out ( use_msg_preset     ),
  .noise_off_out      ( noise_off          ),
  .signal_off_out     ( signal_off         ),
  .ca_phase_start_out (      ),//TODO:remove
  .ca_phase_out       ( ca_phase           ),
  .doppler_out        ( doppler            ),
  .snr_out            ( snr                )  
);

//Core:
gps_gen_core core
(
  .clk_in              ( clk             ),
  .rst_in_n            ( rst_n           ),
  .ena_in              ( general_enable  ),
  .msg_in              ( ui_in[1]        ),
  .n_sat_in            ( n_sat           ),
  .use_preset_in       ( 1'b0            ),
  .preset_sel_in       ( ui_in[3:2]      ),
  .use_msg_preset_in   ( use_msg_preset  ),
  .noise_off_in        ( noise_off       ),
  .signal_off_in       ( signal_off      ),
  .ca_phase_in         ( ca_phase        ),
  .doppler_in          ( doppler         ),
  .snr_in              ( snr             ),
  .start_out           ( start_out       ),
  .noise_start_out     ( noise_start_out ),
  .sin_out             ( sin_out         ),
  .cos_out             ( cos_out         ) 
);

endmodule
