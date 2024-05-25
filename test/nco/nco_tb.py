from gps.modeling.search_module.local_gps_gen.nco.nco import NCO

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, Combine


CLK_FREQUENCY = 16368000
CLK_PERIOD = 61.094
TIME_UNIT = "ns"
N_BITS = 14
M_BITS = 15

#
# Rango de variación de la frecuencia central: [-8000 Hz ; 8000 Hz)
# Paso de frecuencia ~= 500 Hz
# f_central = 4092000 Hz --> delta_phi = 8192 = 2^13
# f_inferior = 4092000 - 8000 Hz = 4092000 - 500*16 Hz --> delta_phi ~= 8176 = 2^13 - 16
# f_superior = 4092000 + 7500 Hz = 4092000 + 500*15 Hz --> delta_phi ~= 8207 = 2^13 + 15
#


#SAMPLING_FREQUENCY = 4092000
DELTA_PHI_CENTRAL = 2**13
DELTA_PHI_L_BOUND = DELTA_PHI_CENTRAL - 16
DELTA_PHI_H_BOUND = DELTA_PHI_CENTRAL + 15

#
# T_central/T_clk = f_clk/f_central = 4
# T_inferior/T_clk = 4.0078
# T_superior/T_clk = 3.9927
#
# En promedio tenemos una muestra de la señal de salida cada 4 ciclos de clk.
# Tomamos como número de samples para hacer la comparación 64
#

SAMPLES = 64

FREQUENCY_STEP = CLK_FREQUENCY/2**M_BITS

# module nco#(
#     parameter FREQ_CTRL_WORD_LEN = 8 ,
#     parameter PHASE_ACC_BITS     = 10,
#     parameter TRUNCATED_BITS     = 2 , 
#     parameter DATA_BITS_OUT      = 8
# )(
#     input  wire [FREQ_CTRL_WORD_LEN-1:0] delta_phi ,
#     input  wire                      clk       , 
#     input  wire                      ena       , 
#     input  wire                      rst       , 
#     output wire  [DATA_BITS_OUT-1:0] sin       ,
#     output wire  [DATA_BITS_OUT-1:0] cos 
# );

async def initialize_module(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD, units=TIME_UNIT).start())
    dut.rst.value = 1
    dut.ena.value = 0
    dut.delta_phi.value = 0
    await Timer(CLK_PERIOD, units=TIME_UNIT)
    dut.rst.value = 0
    dut.ena.value = 1

@cocotb.test()
async def nco_model_output_match_test(dut):
    """Test de comparación directa de salidas entre el módulo en RTL y el modelo de Python
    """
    dut._log.info("Starting nco model output match test")
    
    await initialize_module(dut)
    
    dut._log.info("Input generation: Start")

    #Los resultados del módulo los almaceno en un diccionario
    dut_results = {}
    model_results = {}

    nco = NCO(N_bits=N_BITS, M_bits=M_BITS, f_in=CLK_FREQUENCY)

    #Evaluo del mínimo al máximo valor de delta_phi
    for delta_phi in range(DELTA_PHI_L_BOUND, DELTA_PHI_H_BOUND+1):
        dut_nco_sin = []
        dut_nco_cos = []
        
        dut.delta_phi.value = delta_phi

        for i in range(SAMPLES):
            await Timer(CLK_PERIOD, units=TIME_UNIT)
            dut_nco_sin.append(dut.sin.value)
            dut_nco_cos.append(dut.cos.value)
            #Agrego resultado a diccionario
        dut_results.update({f"{delta_phi}" : (dut_nco_sin, dut_nco_cos)})
        
        nco.set_delta_phi(delta_phi)
        model_results.update({f"{delta_phi}" : nco.get_output(n_points=SAMPLES)})
    dut._log.info("Input generation: Done")

    #Verificación
    for delta_phi in range(DELTA_PHI_L_BOUND, DELTA_PHI_H_BOUND+1):
        assert dut_results[f"{delta_phi}"] == model_results[f"{delta_phi}"], f"Error: Salida del DUT no coincide con el modelo al ingresar delta_phi={delta_phi}"
    dut._log.info("Result OK")

@cocotb.test()
async def nco_model_internal_match_test(dut):
    """Test de comparación directa de variables internas del módulo RTL y el modelo de Python
    """
    dut._log.info("Starting nco model internal match test")
    
    await initialize_module(dut)
    
    dut._log.info("Input generation: Start")

    #Almaceno valores internos en dict
    dut_accum = {}
    dut_trunc = {}
    dut_results = {}
    model_accum = {}
    model_trunc = {}
    model_results = {}

    nco = NCO(N_bits=N_BITS, M_bits=M_BITS, f_in=CLK_FREQUENCY)

    #Evaluo del mínimo al máximo valor de delta_phi
    for delta_phi in range(DELTA_PHI_L_BOUND, DELTA_PHI_H_BOUND+1):
        dut_nco_accum = []
        dut_nco_trunc = []
        dut_nco_sin = []
        dut_nco_cos = []
        
        #Reinicio el NCO por cada delta_phi evaluado
        await initialize_module(dut)

        dut.delta_phi.value = delta_phi

        for i in range(SAMPLES):
            await Timer(CLK_PERIOD, units=TIME_UNIT)
            dut_nco_accum.append(int(dut.acc_out.value))
            dut_nco_trunc.append(int(dut.truncated_acc.value))
            dut_nco_sin.append(dut.sin.value)
            dut_nco_cos.append(dut.cos.value)
            # Almaceno los valores de elementos internos del nco
        dut_accum.update({f"{delta_phi}" : dut_nco_accum})
        dut_trunc.update({f"{delta_phi}" : dut_nco_trunc})
        dut_results.update({f"{delta_phi}" : (dut_nco_sin, dut_nco_cos)})
        
        # Almaceno los valores de elementos internos del modelo y de la salida
        nco.set_delta_phi(delta_phi)
        
        model_accum.update({f"{delta_phi}" : nco._accum(n_points=SAMPLES)})
        model_trunc.update({f"{delta_phi}" : nco._truncate(model_accum[f"{delta_phi}"])})
        model_results.update({f"{delta_phi}" : nco._lut(model_trunc[f"{delta_phi}"])})
    dut._log.info("Input generation: Done")

    #Verificación
    for delta_phi in range(DELTA_PHI_L_BOUND, DELTA_PHI_H_BOUND+1):
        assert dut_accum[f"{delta_phi}"] == model_accum[f"{delta_phi}"], f"Error: Acumulador del DUT no coincide con el modelo al ingresar delta_phi={delta_phi}"
    dut._log.info("Accum OK")
    for delta_phi in range(DELTA_PHI_L_BOUND, DELTA_PHI_H_BOUND+1):
        assert dut_trunc[f"{delta_phi}"] == model_trunc[f"{delta_phi}"], f"Error: Truncamiento del DUT no coincide con el modelo al ingresar delta_phi={delta_phi}"
    dut._log.info("Trunc OK")

@cocotb.test()
async def nco_frequency_measurement_test(dut):
    """Test de medición de frecuencia de salida del módulo RTL usando contador recíproco
    """
    dut._log.info("Starting nco frequency measurement test")

    await initialize_module(dut)
    SAMPLES = 32768
    
    dut._log.info("Input generation: Start")

    dut_frequency = {}

    #Evaluo del mínimo al máximo valor de delta_phi
    for delta_phi in range(DELTA_PHI_L_BOUND, DELTA_PHI_H_BOUND+1):
        
        n_events = 0
        dut.delta_phi.value = delta_phi
        
        await RisingEdge(dut.sin)
        event_flag = False
        # Cuento flancos de subida de la señal de salida hasta que pasen SAMPLES ciclos (SAMPLES*CLK_PERIOD=Tg)
        for i in range(SAMPLES):
            await Timer(CLK_PERIOD, units=TIME_UNIT)
            if (dut.sin.value == 1) and (event_flag == False):
                n_events = n_events + 1
                event_flag = True
            elif (dut.sin.value == 0) and (event_flag == True):
                event_flag = False
        
        #Termina de contar Tg, ahora cuenta deltaTg
        n_extra_pulses = 0
        while(True):
            await Timer(CLK_PERIOD, units=TIME_UNIT)
            n_extra_pulses = n_extra_pulses + 1
            if (dut.sin.value == 0) and (event_flag == True):
                event_flag = False
            elif (dut.sin.value == 1) and (event_flag == False):
                n_events = n_events + 1
                break    
        
        #Agrego frecuencia medida a diccionario
        frequency = n_events/((SAMPLES+n_extra_pulses)*CLK_PERIOD*1e-9)
        dut_frequency.update({f"{delta_phi}" : frequency})
        expected_frequency = delta_phi*CLK_FREQUENCY/(2**15)
        difference = abs(expected_frequency - frequency)
        dut._log.info(f"delta_phi = {delta_phi} | expected frequency = {expected_frequency} | frequency = {frequency} | difference = {difference} | n_events = {n_events} | n_pulses = {SAMPLES+n_extra_pulses}")
    dut._log.info("Input generation: Done")

    #Verificación
    for delta_phi in range(DELTA_PHI_L_BOUND, DELTA_PHI_H_BOUND+1):
        expected_frequency = delta_phi*FREQUENCY_STEP
        assert abs(dut_frequency[f"{delta_phi}"]-expected_frequency) <= 500, f"Error: La diferencia de frecuencia medida y esperada supera la resolución del NCO cuano delta_phi={delta_phi}"
    dut._log.info("Result OK")


    dut._log.info("Input generation: Done")