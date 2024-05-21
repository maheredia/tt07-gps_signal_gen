module lookup 
//Se definen las longitudes en bits de cada posicion 
//De memoria y de cada direccion 
#(parameter WORD_LENGTH = 16, ADDR_LENGTH = 8, MEM_NAME = "sin.hex")
(
    input wire clk_in,
    input wire ena_in, 
    input wire [ADDR_LENGTH-1:0] address_in, 
    output reg [WORD_LENGTH-1:0] data_out
);

// Declaramos un array de registros mem.
// La longitud del registro es WORD_LENGTH 
// La longitud del array mem es (2**ADDR_LENGTH)
reg [WORD_LENGTH-1:0] mem [0:(2**ADDR_LENGTH)-1];

//Opcionalmente podemos cargar la memoria. 
initial begin 
    $readmemh(MEM_NAME, mem);
end

// Ahora para el bloque de lectura y escritura sincronica 
// Vamos a utilizar un bloque alwayss 

always @(posedge clk_in) begin
    if (ena_in) begin
        data_out <= mem[address_in] ; 
    end
end

endmodule