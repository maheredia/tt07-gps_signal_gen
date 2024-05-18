module reg_bank
#(
  parameter CLKS_PER_BIT = 142 // (CLK_FREQ) / (115200) -> (16368000 / 115200) ~= 142
)
(
  input                 clk_in              ,
  input                 rst_in_n            ,
  input                 rx_in               ,
  output                tx_out              ,
  output                enable_out          ,
  output [4:0]          n_sat_out           ,
  output                use_preset_out      ,
  output                use_msg_preset_out  ,
  output                noise_off_out       ,
  output                signal_off_out      ,
  output [9:0]          ca_phase_out        , //TODO: check width
  output [4:0]          doppler_out         , //TODO: check width
  output [7:0]          snr_out               //TODO: check width
);

//Local parameters:
localparam CTRL          = 3'b000;
localparam STATUS        = 3'b001;
localparam SAT_ID        = 3'b010;
localparam DOPPLER       = 3'b011;
localparam CA_PHASE_LO   = 3'b100;
localparam CA_PHASE_HI   = 3'b101;
localparam SNR           = 3'b110;

localparam IDLE          = 2'b00;
localparam DECODE        = 2'b01;
localparam READ          = 2'b10;
localparam WRITE         = 2'b11;

//Internal signals:
//uart_rx:
wire        rx_data_valid;
wire [7:0]  rx_data      ;

//uart_tx:
wire        tx_done       ;
wire        tx_active     ;
reg         tx_data_valid ;
reg  [7:0]  tx_data       ;

//Registers:
reg [7:0]   ctrl_reg        ; //RW
reg [7:0]   status_reg      ; //RO
reg [7:0]   sat_id_reg      ; //RW
reg [7:0]   doppler_reg     ; //RW
reg [7:0]   ca_phase_lo_reg ; //RW
reg [7:0]   ca_phase_hi_reg ; //RW
reg [7:0]   snr_reg         ; //RW

//FSM:
wire [1:0]  next_state      ;
reg  [1:0]  current_state   ;
reg  [2:0]  addr            ;
reg         we              ;

/*------------------------LOGIC BEGINS----------------------------------*/

//UART RX: //TODO: IMPLEMENT CUSTOM UART WITH RESET!!
uart_rx 
#(.CLKS_PER_BIT(CLKS_PER_BIT))
u_rx
(
  .clk_in      ( clk_in        ),
  .rst_in_n    ( rst_in_n      ),
  .rx_in       ( rx_in         ),
  .rx_dv_out   ( rx_data_valid ),
  .o_Rx_Byte   ( rx_data       )
);

//UART TX: //TODO: IMPLEMENT CUSTOM UART WITH RESET!!
uart_tx 
#(.CLKS_PER_BIT(CLKS_PER_BIT))
u_tx
(
  .i_Clock      ( clk_in        ),
  .rst_in_n     ( rst_in_n      ),
  .i_Tx_DV      ( tx_data_valid ),
  .i_Tx_Byte    ( tx_data       ), 
  .o_Tx_Active  ( tx_active     ),
  .o_Tx_Serial  ( tx_out        ),
  .o_Tx_Done    ( tx_done       ) 
);

//Registers:
always @ posedge(clk_in, rst_in_n)
begin
  if(!rst_in_n)
  begin
    ctrl_reg        <= 8'h06;
    status_reg      <= 8'h00;
    sat_id_reg      <= 8'h00;
    doppler_reg     <= 8'h00; //TODO: check default values
    ca_phase_lo_reg <= 8'h00; //TODO: check default values
    ca_phase_hi_reg <= 8'h00; //TODO: check default values
    snr_reg         <= 8'h00; //TODO: check default values
  end
  else if(we==1'b1 && rx_data_valid==1'b1)
  begin
    case(addr)
    begin
      CTRL        : ctrl_reg        <= rx_data;
      //STATUS      : TODO: define status signals
      SAT_ID      : sat_id_reg      <= rx_data;
      DOPPLER     : doppler_reg     <= rx_data;
      CA_PHASE_LO : ca_phase_lo_reg <= rx_data;
      CA_PHASE_HI : ca_phase_hi_reg <= rx_data;
      SNR         : snr_reg         <= rx_data;
    end
    endcase
  end
end

always @(*)
begin
  case(addr)
  begin
    CTRL        : tx_data  = ctrl_reg        ;
    STATUS      : tx_data  = status_reg      ;
    SAT_ID      : tx_data  = sat_id_reg      ;
    DOPPLER     : tx_data  = doppler_reg     ;
    CA_PHASE_LO : tx_data  = ca_phase_lo_reg ;
    CA_PHASE_HI : tx_data  = ca_phase_hi_reg ;
    SNR         : tx_data  = snr_reg         ;
    default     : tx_data  = 8'hBA           ;
  end
  endcase
end

//Outputs:
assign enable_out         = ctrl_reg[0]       ;
assign n_sat_out          = sat_id_reg[4:0]   ;
assign use_preset_out     = ctrl_reg[1]       ;
assign use_msg_preset_out = ctrl_reg[2]       ;
assign noise_off_out      = ctrl_reg[4]       ;
assign signal_off_out     = ctrl_reg[5]       ;
assign ca_phase_out       = {ca_phase_hi_reg[1:0], ca_phase_lo_reg}; //TODO: CHECK WIDTH
assign doppler_out        = doppler_reg[4:0]  ;
assign snr_out            = snr_reg; //TODO: CHECK WIDTH

//FSM: sequential logic
always @ (posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
    current_state <= IDLE;
  else
    current_state <= next_state;
end

//FSM: next_state logic
always @ (*)
begin
  case(current_state)
  begin
    IDLE:
    begin
      if(rx_data_valid == 1'b1)
        next_state = DECODE;
      else
        next_state = IDLE;
    end

    DECODE:
    begin
      if(rx_data[7] == 1'b1)
        next_state = READ;
      else
        next_state = WRITE;
    end

    READ:
    begin
      if(tx_done == 1'b1)
        next_state = IDLE;
      else
        next_state = READ;
    end

    WRITE:
    begin
      if(rx_data_valid == 1'b1)
        next_state = IDLE;
      else
        next_state = WRITE;
    end

    default:
    begin
      next_state = IDLE;
    end
  end
  endcase
end
endmodule