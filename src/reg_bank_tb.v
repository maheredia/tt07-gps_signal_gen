`timescale 1ns/10ps
`include "reg_bank.v" 
`include "uart_tx.v"
`include "uart_rx.v"

module reg_bank_tb();

//Local parameters:
localparam CLKS_PER_BIT  = 142    ;
localparam CLK_PER       = 61.095 ;
localparam BIT_PER       = 8600   ;
localparam TEST_LENGTH   = 100    ;

//Test signals:
reg                 test_clk_in              ;
reg                 test_rst_in_n            ;
reg                 test_code_phase_done     ;
reg                 test_rx_in               ;
wire                test_tx_out              ;
wire                test_enable_out          ;
wire [4:0]          test_n_sat_out           ;
wire                test_use_preset_out      ;
wire                test_use_msg_preset_out  ;
wire                test_noise_off_out       ;
wire                test_signal_off_out      ;
wire                test_ca_phase_start_out  ;
wire [15:0]         test_ca_phase_out        ;
wire [7:0]          test_doppler_out         ;
wire [7:0]          test_snr_out             ;

integer             i                        ;
integer             error_count           =0 ;
integer             test_addr                ;
integer             expected_data            ;
integer             received_data            ;

//Task to send data:
task UART_SEND;
input [7:0] data;
integer     ii;
begin
  //Start bit
  test_rx_in = 1'b0;
  #(BIT_PER);
  #1000;     
  //Data
  for (ii=0; ii<8; ii=ii+1)
  begin
    test_rx_in = data[ii];
    #(BIT_PER);
  end
  //Stop bit
  test_rx_in = 1'b1;
  #(BIT_PER);
end
endtask

//Task to receive data:
task UART_RECEIVE;
output [7:0] data;
integer     ii;
begin
  data=0;
  //Start bit
  wait(test_tx_out==1'b0);
  #(BIT_PER/2);
  if(test_tx_out==1'b0)
  begin
    #(BIT_PER);
    //Data
    for(ii=0; ii<8; ii=ii+1)
    begin
      data[ii] = test_tx_out;
      #(BIT_PER);
    end
    //Stop bit
    #(BIT_PER);
  end
end
endtask

//DUT:
reg_bank
#(
  .CLKS_PER_BIT(CLKS_PER_BIT)
)
dut
(
  .clk_in             (test_clk_in            ),
  .rst_in_n           (test_rst_in_n          ),
  .code_phase_done    (test_code_phase_done   ),
  .rx_in              (test_rx_in             ),
  .tx_out             (test_tx_out            ),
  .enable_out         (test_enable_out        ),
  .n_sat_out          (test_n_sat_out         ),
  .use_preset_out     (test_use_preset_out    ),
  .use_msg_preset_out (test_use_msg_preset_out),
  .noise_off_out      (test_noise_off_out     ),
  .signal_off_out     (test_signal_off_out    ),
  .ca_phase_start_out (test_ca_phase_start_out),
  .ca_phase_out       (test_ca_phase_out      ),
  .doppler_out        (test_doppler_out       ),
  .snr_out            (test_snr_out           )  
);

//Do clock:
always
begin
  test_clk_in = 0;
  #(CLK_PER/2);
  test_clk_in = 1;
  #(CLK_PER/2);
end

//Do test:
initial
begin
  $dumpfile("test_reg_bank.vcd");
  $dumpvars(0,reg_bank_tb);

  $display("TEST BEGINS");
  test_rst_in_n        = 1'b0;
  test_code_phase_done = 1'b0;
  test_rx_in           = 1'b1;
  #(10*CLK_PER);
  test_rst_in_n = 1'b1;

  @(posedge test_clk_in);

  for(i=0; i<TEST_LENGTH; i=i+1)
  begin
    @(posedge test_clk_in);
    #(2*CLK_PER);
    test_addr = $urandom%8  ; // 3 bits address
    expected_data = $urandom%256; // 8 bits data
    
    //WRITE:
    UART_SEND(test_addr);
    UART_SEND(expected_data);

    //READ:
    if(test_addr==1)
      expected_data = 0; //status reg, not tested TODO
    else if(test_addr==7)
      expected_data = 8'hBA; //default value
    UART_SEND({1'b1,test_addr[6:0]});
    UART_RECEIVE(received_data);
    if(received_data != expected_data)
    begin
      error_count = error_count+1;
      $error("ERROR: i = %d, expected = %d, received = %d, error_count = %d\m",i,expected_data,received_data,error_count);
    end  
  end

  if(error_count==0)
    $display("TEST PASS");
  else
    $error("TEST FAIL");
  $finish;
end
endmodule