module reg_bank
#(
  parameter CLKS_PER_BIT = 142 // (CLK_FREQ) / (115200) -> (16368000 / 115200) ~= 142
)
(
  input                 clk_in              ,
  input                 rst_in_n            ,
  input                 code_phase_done     ,
  //TODO: define more inputs for STATUS_ADDR reg
  input                 rx_in               ,
  output                tx_out              ,
  output                enable_out          ,
  output [4:0]          n_sat_out           ,
  output                use_preset_out      ,
  output                use_msg_preset_out  ,
  output                noise_off_out       ,
  output                signal_off_out      ,
  output                ca_phase_start_out  ,
  output [15:0]         ca_phase_out        ,
  output [7:0]          doppler_out         ,
  output [7:0]          snr_out               //TODO: check width
);

//Local parameters:
localparam CTRL_ADDR          = 3'b000;
localparam STATUS_ADDR        = 3'b001;
localparam SAT_ID_ADDR        = 3'b010;
localparam DOPPLER_ADDR       = 3'b011;
localparam CA_PHASE_LO_ADDR   = 3'b100;
localparam CA_PHASE_HI_ADDR   = 3'b101;
localparam SNR_ADDR           = 3'b110;

localparam IDLE          = 2'b00;
localparam DECODE        = 2'b01;
localparam READ          = 2'b10;
localparam WRITE         = 2'b11;

//Internal signals:
//uart_rx:
wire        rx_data_valid;
wire [7:0]  rx_data      ;

//uart_tx:
wire        tx_done             ;
wire        tx_active           ;
reg         tx_data_valid       ;
reg         tx_data_valid_reg   ;
reg  [7:0]  tx_data             ;

//Registers:
reg [7:0]   ctrl_reg        ; //RW
reg [7:0]   status_reg      ; //RO
reg [7:0]   sat_id_reg      ; //RW
reg [7:0]   doppler_reg     ; //RW
reg [7:0]   ca_phase_lo_reg ; //RW
reg [7:0]   ca_phase_hi_reg ; //RW
reg [7:0]   snr_reg         ; //RW
reg [2:0]   addr            ;

//FSM:
reg  [1:0]  next_state      ;
reg  [1:0]  current_state   ;
reg         addr_ena        ;
reg         we              ;

/*------------------------LOGIC BEGINS----------------------------------*/

//UART RX:
uart_rx 
#(.CLKS_PER_BIT(CLKS_PER_BIT))
u_rx
(
  .clk_in      ( clk_in        ),
  .rst_in_n    ( rst_in_n      ),
  .rx_in       ( rx_in         ),
  .rx_dv_out   ( rx_data_valid ),
  .rx_data_out ( rx_data       )
);

//UART TX:
always @ (posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
    tx_data_valid_reg <= 1'b0;
  else
    tx_data_valid_reg <= tx_data_valid;
end
uart_tx 
#(.CLKS_PER_BIT(CLKS_PER_BIT))
u_tx
(
  .clk_in        ( clk_in        ),
  .rst_in_n      ( rst_in_n      ),
  .tx_dv_in      ( ~tx_data_valid_reg & tx_data_valid ),
  .tx_data_in    ( tx_data       ), 
  .tx_active_out ( tx_active     ),
  .tx_out        ( tx_out        ),
  .tx_done_out   ( tx_done       ) 
);

//Registers:
always @(posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
  begin
    ctrl_reg        <= 8'h06;
    sat_id_reg      <= 8'h00;
    doppler_reg     <= 8'h00; //TODO: check default values
    ca_phase_lo_reg <= 8'h00;
    ca_phase_hi_reg <= 8'h00;
    snr_reg         <= 8'h00; //TODO: check default values
  end
  else if(we==1'b1 && rx_data_valid==1'b1)
  begin
    case(addr)
      CTRL_ADDR        : ctrl_reg        <= rx_data;
      SAT_ID_ADDR      : sat_id_reg      <= rx_data;
      DOPPLER_ADDR     : doppler_reg     <= rx_data;
      CA_PHASE_LO_ADDR : ca_phase_lo_reg <= rx_data;
      CA_PHASE_HI_ADDR : ca_phase_hi_reg <= rx_data;
      SNR_ADDR         : snr_reg         <= rx_data;
    endcase
  end
end
//STATUS_ADDR reg:
always @(posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
    status_reg <= 8'h00;
  else
    status_reg <= {7'd0, code_phase_done};// TODO: define STATUS_ADDR signals
end

//Address register:
always @(posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
    addr <= 3'b000;
  else if(addr_ena==1'b1)
    addr <= rx_data[2:0];
end

always @(*)
begin
  case(addr)
    CTRL_ADDR        : tx_data  = ctrl_reg        ;
    STATUS_ADDR      : tx_data  = status_reg      ;
    SAT_ID_ADDR      : tx_data  = sat_id_reg      ;
    DOPPLER_ADDR     : tx_data  = doppler_reg     ;
    CA_PHASE_LO_ADDR : tx_data  = ca_phase_lo_reg ;
    CA_PHASE_HI_ADDR : tx_data  = ca_phase_hi_reg ;
    SNR_ADDR         : tx_data  = snr_reg         ;
    default          : tx_data  = 8'hBA           ;
  endcase
end

//Outputs:
assign enable_out         = ctrl_reg[0]       ;
assign n_sat_out          = sat_id_reg[4:0]   ;
assign use_preset_out     = ctrl_reg[1]       ;
assign use_msg_preset_out = ctrl_reg[2]       ;
assign noise_off_out      = ctrl_reg[4]       ;
assign signal_off_out     = ctrl_reg[5]       ;
assign ca_phase_start_out = ctrl_reg[3]       ;
assign ca_phase_out       = {ca_phase_hi_reg, ca_phase_lo_reg};
assign doppler_out        = doppler_reg       ;
assign snr_out            = snr_reg           ; //TODO: CHECK WIDTH

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
    IDLE:
    begin
      addr_ena      = 1'b0;
      we            = 1'b0;
      tx_data_valid = 1'b0;
      if(rx_data_valid == 1'b1)
        next_state = DECODE;
      else
        next_state = IDLE;
    end

    DECODE:
    begin
      addr_ena      = 1'b1;
      we            = 1'b0;
      tx_data_valid = 1'b0;
      if(rx_data[7] == 1'b1)
        next_state = READ;
      else
        next_state = WRITE;
    end

    READ:
    begin
      addr_ena      = 1'b0;
      we            = 1'b0;
      tx_data_valid = 1'b1;
      if(tx_done == 1'b1)
        next_state = IDLE;
      else
        next_state = READ;
    end

    WRITE:
    begin
      addr_ena      = 1'b0;
      we            = 1'b1;
      tx_data_valid = 1'b0;
      if(rx_data_valid == 1'b1)
        next_state = IDLE;
      else
        next_state = WRITE;
    end

    default:
    begin
      addr_ena      = 1'b0;
      we            = 1'b0;
      tx_data_valid = 1'b0;
      next_state    = IDLE;
    end
  endcase
end
endmodule