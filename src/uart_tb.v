`timescale 1ns/10ps 
`include "uart_tx.v"
`include "uart_rx.v"
 
module uart_tb();
//Testbench clock: 16.368 MHz
//UART: 115200 bauds
//(16368000 / 115200) ~= 142
localparam CLKS_PER_BIT  = 142    ;
localparam CLK_PER       = 61.095 ;
localparam BIT_PER       = 8600   ;
localparam TEST_LENGTH   = 1000   ;
//Test signals:
reg           test_clk_in = 0    ;
reg           test_rst_n         ;
reg           test_tx_dv_in      ;
reg  [7:0]    test_tx_data_in    ;
wire          test_tx_active_out ;
wire          test_tx_out        ;
wire          test_tx_done_out   ;
reg           test_rx_in = 1     ;
wire [7:0]    test_rx_data_out   ;
wire          test_rx_dv_out     ;
integer       i                  ;
integer       error_count     = 0;
integer       test_data          ;

//Task to send data, NOT USED HERE
task UART_SEND;
input [7:0] data;
integer     ii;
begin
  //Start bit
  test_rx_in <= 1'b0;
  #(BIT_PER);
  #1000;     
  //Data
  for (ii=0; ii<8; ii=ii+1)
  begin
    test_rx_in <= data[ii];
    #(BIT_PER);
  end
  //Stop bit
  test_rx_in <= 1'b1;
  #(BIT_PER);
end
endtask

//DUTs:
uart_rx 
#(.CLKS_PER_BIT(CLKS_PER_BIT)) 
rx_dut
( 
  .clk_in       (test_clk_in      ),
  .rst_in_n     (test_rst_n       ),
  .rx_in        (test_tx_out      ),
  .rx_dv_out    (test_rx_dv_out   ),
  .rx_data_out  (test_rx_data_out )
);
   
uart_tx 
#(.CLKS_PER_BIT(CLKS_PER_BIT))
tx_dut
(
  .clk_in        (test_clk_in        ),
  .rst_in_n      (test_rst_n         ),
  .tx_dv_in      (test_tx_dv_in      ),
  .tx_data_in    (test_tx_data_in    ),
  .tx_active_out (test_tx_active_out ),
  .tx_out        (test_tx_out        ),
  .tx_done_out   (test_tx_done_out   )
);

//Do clock:
always #(CLK_PER/2) test_clk_in <= !test_clk_in;
   
//Do test:
initial
begin
  $dumpfile("test.vcd");
  $dumpvars(0,uart_tb);

  $display("TEST BEGINS");
  test_rst_n      = 1'b0;
  test_tx_dv_in   = 0   ;
  test_tx_data_in = 0   ;
  #(10*CLK_PER);
  test_rst_n = 1'b1;
  
  @(posedge test_clk_in);
  @(posedge test_clk_in);

  for(i=0; i<TEST_LENGTH; i=i+1)
  begin
    @(posedge test_clk_in);
    #(10*CLK_PER);
    test_data       = $urandom%256;
    test_tx_dv_in   = 1'b1;
    test_tx_data_in = test_data;
    #(CLK_PER);
    test_tx_dv_in   = 1'b0;
    @(posedge test_rx_dv_out);
    if(test_rx_data_out != test_data)
    begin
      $error("ERROR: i = %d, expected = %d, received = %d, error_count = %d\n",i,test_data,test_rx_data_out,error_count);
      error_count = error_count + 1;
    end
    wait(test_tx_active_out==1'b0);
  end
   
  if(error_count==0)
    $display("TEST PASS");
  else
    $error("TEST FAIL");
  $finish;
end
endmodule