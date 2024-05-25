module reg_bank_reduced
#(
  parameter CLKS_PER_BIT = 142 // (CLK_FREQ) / (115200) -> (16368000 / 115200) ~= 142
)
(
  input                 clk_in              ,
  input                 rst_in_n            ,
  input                 code_phase_done     ,
  input                 rx_in               ,
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

localparam IDLE          = 2'b001;
localparam DECODE        = 2'b010;
localparam WRITE         = 2'b100;

//Internal signals:
//uart_rx:
wire        rx_data_valid;
wire [7:0]  rx_data      ;

//Registers:
reg [7:0]   ctrl_reg        ; //WO
reg [7:0]   sat_id_reg      ; //WO
reg [7:0]   doppler_reg     ; //WO
reg [7:0]   ca_phase_lo_reg ; //WO
reg [7:0]   ca_phase_hi_reg ; //WO
reg [7:0]   snr_reg         ; //WO
reg [2:0]   addr            ;

//FSM:
reg  [2:0]  next_state      ;
reg  [2:0]  current_state   ;
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

//Address register:
always @(posedge clk_in, negedge rst_in_n)
begin
  if(!rst_in_n)
    addr <= 3'b000;
  else if(addr_ena==1'b1)
    addr <= rx_data[2:0];
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
      if(rx_data_valid == 1'b1)
        next_state = DECODE;
      else
        next_state = IDLE;
    end

    DECODE:
    begin
      addr_ena      = 1'b1;
      we            = 1'b0;
      next_state = WRITE;
    end

    WRITE:
    begin
      addr_ena      = 1'b0;
      we            = 1'b1;
      if(rx_data_valid == 1'b1)
        next_state = IDLE;
      else
        next_state = WRITE;
    end

    default:
    begin
      addr_ena      = 1'b0;
      we            = 1'b0;
      next_state    = IDLE;
    end
  endcase
end
endmodule