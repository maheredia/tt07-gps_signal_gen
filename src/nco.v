
module nco#(
    parameter FREQ_CTRL_WORD_LEN = 8 ,
    parameter PHASE_ACC_BITS     = 10,
    parameter TRUNCATED_BITS     = 2 , 
    parameter DATA_BITS_OUT      = 1
)(
    input  wire [FREQ_CTRL_WORD_LEN-1:0] delta_phi ,
    input  wire                      clk       , 
    input  wire                      ena       , 
    input  wire                      rst       , 
    output wire  [DATA_BITS_OUT-1:0] sin       ,
    output wire  [DATA_BITS_OUT-1:0] cos 
);

// Registro de entrada
reg [FREQ_CTRL_WORD_LEN-1:0] delta_phi_buf ;
always @( posedge clk, posedge rst ) begin
    if (rst) begin
        delta_phi_buf <= {FREQ_CTRL_WORD_LEN{1'b0}};
    end else if (ena) begin
        delta_phi_buf <= delta_phi; 
    end
end 


// Acumulador de fase. 
reg [PHASE_ACC_BITS-1:0] acc_out ;
always @(posedge clk, posedge rst) begin
    if (rst) begin
        acc_out <= {PHASE_ACC_BITS{1'b0}}  ; 
    end else if (ena) begin
        acc_out <= acc_out + delta_phi ; 
    end
end

// Truncamiento 
wire [ TRUNCATED_BITS-1:0 ] truncated_acc ; 
assign truncated_acc = acc_out[PHASE_ACC_BITS-1 -: TRUNCATED_BITS] ; 

// Lookup tables 
lookup_4x1_sine sin_table (
    .address_in( truncated_acc ), 
    .data_out  ( sin           )
);

lookup_4x1_cos cos_table (
    .address_in( truncated_acc ), 
    .data_out  ( cos           )
);

endmodule