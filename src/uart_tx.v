// START BIT + 8 DATA BITS + STOP BITS (no parity)
// CLKS_PER_BIT = (Frequency of clk_in)/(Frequency of UART)
// Example: 16.384 MHz Clock, 115200 baud UART
// (16368000 / 115200) ~= 142
//TODO: CHECK WHOLE ARCHITECTURE AND TEST!
module uart_tx 
#(
  parameter CLKS_PER_BIT = 142
)
(
  input        clk_in        ,
  input        rst_in_n      ,
  input        tx_dv_in      ,
  input [7:0]  tx_data_in    , 
  output       tx_active_out ,
  output reg   tx_out        ,
  output       tx_done_out    
);

//Local parameters:
localparam IDLE      = 3'b000;
localparam START_BIT = 3'b001;
localparam SEND_DATA = 3'b010;
localparam STOP_BIT  = 3'b011;
localparam DONE      = 3'b100;
localparam NB_CNTR   = $clog2(CLKS_PER_BIT);
//Internal signals:
reg [2:0]            current_state ;
reg [2:0]            next_state    ;
reg [NB_CNTR-1:0]    cntr          ;
reg                  cntr_ena      ;
reg                  cntr_tc       ;
reg [2:0]            tx_bit_cntr   ;
reg                  tx_shift_ena  ;
reg                  tx_shift_done ;
reg [7:0]            tx_data_reg   ;
reg                  tx_done       ;
reg                  tx_active     ;
reg                  clear_all     ;

/*----------------------------------LOGIC BEGINS------------------------------------------------------*/

//Tx data input register:
always @ (posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
    tx_data_reg <= 8'h00;
  else if(tx_dv_in==1'b1)
    tx_data_reg <= tx_data_in;
end

//Main counter:
always @ (posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
  begin
    cntr    <= {NB_CNTR{1'b0}};
    cntr_tc <= 1'b0;
  end
  else if(clear_all==1'b1)
  begin
    cntr    <= {NB_CNTR{1'b0}};
    cntr_tc <= 1'b0;
  end
  else if(cntr_ena==1'b1)
  begin
    if(cntr<CLKS_PER_BIT-1)
    begin
      cntr    <= cntr + 1'b1;
      cntr_tc <= 1'b0;
    end
    else
    begin
      cntr    <= {NB_CNTR{1'b0}};
      cntr_tc <= 1'b1;    
    end
  end
end

//Tx bit counter:
always @ (posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
  begin
    tx_bit_cntr     <= 3'b000;
      tx_shift_done <= 1'b0;
  end
  else if(clear_all==1'b1)
  begin
    tx_bit_cntr     <= 3'b000;
      tx_shift_done <= 1'b0;
  end
  else if(tx_shift_ena==1'b1 && cntr_tc==1'b1)
  begin
    if(tx_bit_cntr < 3'b111)
    begin
      tx_bit_cntr   <= tx_bit_cntr + 1'b1;
      tx_shift_done <= 1'b0;
    end
    else
    begin
      tx_bit_cntr   <= 3'b000;
      tx_shift_done <= 1'b1;
    end
  end
end

//FSM: sequential logic
always @ (posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
    current_state <= IDLE;
  else
    current_state <= next_state;
end

//FSM: next state logic
always @(*)
begin
  case (current_state)
    IDLE:
    begin
      clear_all    = 1'b1;
      cntr_ena     = 1'b0;
      tx_shift_ena = 1'b0;
      tx_done      = 1'b0;
      tx_active    = 1'b0;
      if(tx_dv_in==1'b1)
        next_state = START_BIT;
      else
        next_state = IDLE;
    end

    START_BIT:
    begin
      clear_all    = 1'b0;
      cntr_ena     = 1'b1;
      tx_shift_ena = 1'b0;
      tx_done      = 1'b0;
      tx_active    = 1'b1;
      if(cntr_tc==1'b1)
        next_state = SEND_DATA;
      else
        next_state = START_BIT;
    end
      
    SEND_DATA:
    begin
      clear_all    = 1'b0;
      cntr_ena     = 1'b1;
      tx_shift_ena = 1'b1;
      tx_done      = 1'b0;
      tx_active    = 1'b1;
      if(tx_shift_done==1'b1)
        next_state = STOP_BIT;
      else
        next_state = SEND_DATA;
    end
     
    // Send out Stop bit.  Stop bit = 1
    STOP_BIT:
    begin
      clear_all    = 1'b0;
      cntr_ena     = 1'b1;
      tx_shift_ena = 1'b0;
      tx_done      = 1'b0;
      tx_active    = 1'b1;
      if(cntr_tc==1'b1)
        next_state = DONE;
      else
        next_state = STOP_BIT;
    end
     
    //Just wait
    DONE:
    begin
      clear_all    = 1'b1;
      cntr_ena     = 1'b0;
      tx_shift_ena = 1'b0;
      tx_done      = 1'b1;
      tx_active    = 1'b0;
      next_state   = IDLE;
    end
     
    default:
    begin
      clear_all    = 1'b1;
      cntr_ena     = 1'b0;
      tx_shift_ena = 1'b0;
      tx_done      = 1'b0;
      tx_active    = 1'b0;
      next_state = IDLE;
    end
     
  endcase
end

//Outputs:
assign tx_active_out = tx_active;
assign tx_done_out   = tx_done;
always @ (posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
    tx_out <= 1'b1;
  else if(current_state==START_BIT)
    tx_out <= 1'b0;
  else if(current_state==SEND_DATA)
    tx_out <= tx_data_reg[tx_bit_cntr];
  else
    tx_out <= 1'b1;
end
   
endmodule