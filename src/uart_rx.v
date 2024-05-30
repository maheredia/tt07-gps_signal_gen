// START BIT + 8 DATA BITS + STOP BITS (no parity)
// CLKS_PER_BIT = (Frequency of clk_in)/(Frequency of UART)
// Example: 16.368 MHz Clock, 115200 baud UART
// (16368000 / 115200) ~= 142
//TODO: CHECK WHOLE ARCHITECTURE AND TEST!
module uart_rx 
#(
  parameter CLKS_PER_BIT = 142
)
(
  input        clk_in      ,
  input        rst_in_n    ,
  input        rx_in       ,
  output       rx_dv_out   ,
  output [7:0] rx_data_out  
);

//Local parameters:
localparam IDLE           = 3'b000;
localparam START_BIT      = 3'b001;
localparam GET_DATA       = 3'b010;
localparam STOP_BIT       = 3'b011;
localparam DONE           = 3'b100;
localparam NB_CNTR        = $clog2(CLKS_PER_BIT);
localparam CNTR_LIMIT_LO  = (CLKS_PER_BIT-1)/2;
localparam CNTR_LIMIT_HI  = CLKS_PER_BIT-1;

//Internal signals:
reg  [1:0]            rx_meta_reg   ;
wire                  rx_data_sync  ;
reg  [2:0]            current_state ;
reg  [2:0]            next_state    ;

wire [NB_CNTR-1:0]    cntr_limit    ;
reg                   cntr_limit_sel;
reg  [NB_CNTR-1:0]    cntr          ;
reg                   cntr_tc       ;

reg                   rx_shift_ena  ;
reg                   rx_shift_done ;
reg  [2:0]            rx_bit_cntr   ;
reg  [7:0]            rx_data       ;
reg                   rx_dv         ;

reg                   clear_all     ;

/*----------------------------------LOGIC BEGINS------------------------------------------------------*/

// Input 2ff synchronizer to reduce metastability issues
always @(posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
    rx_meta_reg <= 2'b11;
  else
  begin
    rx_meta_reg[0] <= rx_in;
    rx_meta_reg[1] <= rx_meta_reg[0];
  end
end

assign rx_data_sync = rx_meta_reg[1];

//Main cntr:
assign cntr_limit = (cntr_limit_sel == 1'b1) ? (CNTR_LIMIT_HI) : (CNTR_LIMIT_LO);
always @ (posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
  begin
    cntr    <= {NB_CNTR{1'b0}};
    cntr_tc <= 1'b0;
  end
  else
  begin
    if(clear_all==1'b1)
    begin
      cntr    <= {NB_CNTR{1'b0}};
      cntr_tc <= 1'b0;
    end
    else if(cntr < cntr_limit)
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

//Rx bit cntr:
always @ (posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
  begin
    rx_bit_cntr   <= 3'b000;
    rx_shift_done <= 1'b0;
  end
  else if(clear_all==1'b1)
  begin
    rx_bit_cntr   <= 3'b000;
    rx_shift_done <= 1'b0;
  end
  else if(rx_shift_ena==1'b1 && cntr_tc==1'b1)
  begin
    if(rx_bit_cntr < 3'b111)
    begin
      rx_bit_cntr   <= rx_bit_cntr + 1'b1;
      rx_shift_done <= 1'b0;
    end
    else
    begin
      rx_bit_cntr   <= 3'b000;
      rx_shift_done <= 1'b1;
    end
  end
end

//Rx shift reg:
always @ (posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
    rx_data <= 8'h00;
  else if(rx_shift_ena==1'b1 && cntr_tc==1'b1)
    rx_data <= {rx_data_sync, rx_data[7:1]};
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
    cntr_limit_sel = 1'b0;
    rx_shift_ena   = 1'b0;
    rx_dv          = 1'b0;
    clear_all      = 1'b1;
    if (rx_data_sync == 1'b0)
      next_state = START_BIT;
    else
      next_state = IDLE;
  end
   
  //Find middle of start bit and check that it is still low
  START_BIT:
  begin
    cntr_limit_sel = 1'b0;
    rx_shift_ena   = 1'b0;
    rx_dv          = 1'b0;
    clear_all      = 1'b0;
    if(cntr_tc==1'b1)
    begin
      if(rx_data_sync == 1'b0)
        next_state = GET_DATA;
      else
        next_state = IDLE;
    end
    else
      next_state  = START_BIT;
  end
   
  //Sample serial data every CLKS_PER_BIT-1 clock cycles.
  GET_DATA:
  begin
    cntr_limit_sel = 1'b1;
    rx_shift_ena   = 1'b1;
    rx_dv          = 1'b0;
    clear_all      = 1'b0;
    if(rx_shift_done==1'b1)
      next_state = STOP_BIT;
    else
      next_state = GET_DATA;
  end

  STOP_BIT:
  begin
    cntr_limit_sel = 1'b1;
    rx_shift_ena   = 1'b0;
    rx_dv          = 1'b0;
    clear_all      = 1'b0;
    //Just wait
    if(cntr_tc==1'b1)
      next_state = DONE;
    else
      next_state = STOP_BIT;
  end

  DONE:
  begin
    cntr_limit_sel = 1'b0;
    rx_shift_ena   = 1'b0;
    rx_dv          = 1'b1;
    clear_all      = 1'b1;
    next_state = IDLE;
  end
   
  default:
  begin
    cntr_limit_sel = 1'b0;
    rx_shift_ena   = 1'b0;
    rx_dv          = 1'b0;
    clear_all      = 1'b1;
    next_state = IDLE;
  end
endcase
end   

//Outputs:
assign rx_dv_out   = rx_dv;
assign rx_data_out = rx_data;
   
endmodule
