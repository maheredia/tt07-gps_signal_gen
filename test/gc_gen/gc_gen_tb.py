from gold_codes import GC

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
import random #Para generar entradas aleatorias
import numpy as np #Para usar con matplotlib y generar gráficos




#frecuencia de muestreo del código de Gold: fs = 16.368 MHz
CLK_PERIOD = 61.094
TIME_UNIT = "ns"
GC_CODE_PERIOD = 1023
TOTAL_SATELLITES = 32
MAX_CORRELATION = 512

# module gc_gen
# (
#   input         rst_in_n   ,
#   input         clk_in     ,
#   input  [4:0]  sat_sel_in ,
#   output reg    gc_out      
# );
#   IMPORTANTE: para seleccionar cada satélite se toma su id-1. 
#   Ej, el sat 1 se selecciona como 0

@cocotb.test()
async def gc_gen_test(dut):
    dut._log.info("Starting gc_gen test")
    await initialize_module(dut)
    await generate_inputs(dut) #punto de salida de la corutina gc_gen_test para entrar a la corutina que genera estímulos

async def initialize_module(dut):
    cocotb.start_soon(Clock(dut.clk_in, CLK_PERIOD, units=TIME_UNIT).start())
    dut.rst_in_n.value = 0
    dut.ena_in.value = 1
    dut.sat_sel_in.value = 0
    await Timer(CLK_PERIOD, units=TIME_UNIT)
    dut.rst_in_n.value = 1

async def generate_inputs(dut):
    dut._log.info("Input generation: Start")

    #Los resultados del módulo y el modelo los almaceno en diccionarios
    dut_results = {}
    model_results = {}

    gc = GC()

    for sat_sel in range(TOTAL_SATELLITES):
        satID = sat_sel+1
        
        dut_gc = []
        dut.sat_sel_in.value = sat_sel
        #Genero un período de código del módulo
        for i in range(GC_CODE_PERIOD):
            #Con cada ciclo de reloj se genera un nuevo chip, cuyo valor guardo en
            #una lista
            await Timer(CLK_PERIOD, units=TIME_UNIT)
            dut_gc.append(dut.gc_out.value)

        #Termine de generar un período, lo agrego al diccionario
        dut_results.update({f"sat{satID}" : dut_gc})
        #Genero un período de código del modelo
        model_gc = gc.get_gold_code(n_sat=satID, n_samples=1023)
        model_results.update({f"sat{satID}" : model_gc})
        
    dut._log.info("Input generation: Done")

    #Comparo secuencias revisando cada valor para el período de todas las señales
    
    #Verificación
    for sat_sel in range(TOTAL_SATELLITES):
        satID = sat_sel+1
        assert model_results[f"sat{satID}"] == dut_results[f"sat{satID}"], f"Error: El código no coincide con el modelo del satélite {satID}"