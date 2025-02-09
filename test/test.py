# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer
import sys
import os
sys.path.append(os.getcwd()+'/models/')
from search_tt import Search_tt
from gps_gen import GPSgen
import random
from datetime import date

CLK_PERIOD = 61.094
BIT_PERIOD = 8600
TIME_UNIT = "ns"
OUTPUT_DIR='./test_outputs/'

DUT_RX_IN_POS     = 3
DUT_RX_IN_MASK    = 0xF7
DUT_MSG_IN_POS    = 0
DUT_MSG_IN_MASK   = 0xFE

CTRL_ADDR        = 0
SAT_ID_ADDR      = 2
DOPPLER_ADDR     = 3
CA_PHASE_LO_ADDR = 4
CA_PHASE_HI_ADDR = 5
SNR_ADDR         = 6

#Doppler table:
#i = 0  ---> phi = 8176 ---> f_out = 4084007.812500 ---> doppler = -7992.187500
#i = 1  ---> phi = 8177 ---> f_out = 4084507.324219 ---> doppler = -7492.675781
#i = 2  ---> phi = 8178 ---> f_out = 4085006.835938 ---> doppler = -6993.164062
#i = 3  ---> phi = 8179 ---> f_out = 4085506.347656 ---> doppler = -6493.652344
#i = 4  ---> phi = 8180 ---> f_out = 4086005.859375 ---> doppler = -5994.140625
#i = 5  ---> phi = 8181 ---> f_out = 4086505.371094 ---> doppler = -5494.628906
#i = 6  ---> phi = 8182 ---> f_out = 4087004.882812 ---> doppler = -4995.117188
#i = 7  ---> phi = 8183 ---> f_out = 4087504.394531 ---> doppler = -4495.605469
#i = 8  ---> phi = 8184 ---> f_out = 4088003.906250 ---> doppler = -3996.093750
#i = 9  ---> phi = 8185 ---> f_out = 4088503.417969 ---> doppler = -3496.582031
#i = 10 ---> phi = 8186 ---> f_out = 4089002.929688 ---> doppler = -2997.070312
#i = 11 ---> phi = 8187 ---> f_out = 4089502.441406 ---> doppler = -2497.558594
#i = 12 ---> phi = 8188 ---> f_out = 4090001.953125 ---> doppler = -1998.046875
#i = 13 ---> phi = 8189 ---> f_out = 4090501.464844 ---> doppler = -1498.535156
#i = 14 ---> phi = 8190 ---> f_out = 4091000.976562 ---> doppler = -999.023438
#i = 15 ---> phi = 8191 ---> f_out = 4091500.488281 ---> doppler = -499.511719
#i = 16 ---> phi = 8192 ---> f_out = 4092000.000000 ---> doppler = 0.000000
#i = 17 ---> phi = 8193 ---> f_out = 4092499.511719 ---> doppler = 499.511719
#i = 18 ---> phi = 8194 ---> f_out = 4092999.023438 ---> doppler = 999.023438
#i = 19 ---> phi = 8195 ---> f_out = 4093498.535156 ---> doppler = 1498.535156
#i = 20 ---> phi = 8196 ---> f_out = 4093998.046875 ---> doppler = 1998.046875
#i = 21 ---> phi = 8197 ---> f_out = 4094497.558594 ---> doppler = 2497.558594
#i = 22 ---> phi = 8198 ---> f_out = 4094997.070312 ---> doppler = 2997.070312
#i = 23 ---> phi = 8199 ---> f_out = 4095496.582031 ---> doppler = 3496.582031
#i = 24 ---> phi = 8200 ---> f_out = 4095996.093750 ---> doppler = 3996.093750
#i = 25 ---> phi = 8201 ---> f_out = 4096495.605469 ---> doppler = 4495.605469
#i = 26 ---> phi = 8202 ---> f_out = 4096995.117188 ---> doppler = 4995.117188
#i = 27 ---> phi = 8203 ---> f_out = 4097494.628906 ---> doppler = 5494.628906
#i = 28 ---> phi = 8204 ---> f_out = 4097994.140625 ---> doppler = 5994.140625
#i = 29 ---> phi = 8205 ---> f_out = 4098493.652344 ---> doppler = 6493.652344
#i = 30 ---> phi = 8206 ---> f_out = 4098993.164062 ---> doppler = 6993.164062
#i = 31 ---> phi = 8207 ---> f_out = 4099492.675781 ---> doppler = 7492.675781

async def uart_send(dut,data,wait_at_stop=True):
    #Start bit:
    dut.ui_in.value = (dut.ui_in.value & DUT_RX_IN_MASK) | (0 << DUT_RX_IN_POS)
    await Timer(BIT_PERIOD, units=TIME_UNIT)
    await Timer(1000, units=TIME_UNIT)
    #Data:
    for i in range(8):
        #send least significant bit of data using: data%2. Shift data to the right after each iteration.
        dut.ui_in.value = (dut.ui_in.value & DUT_RX_IN_MASK) | (data%2 << DUT_RX_IN_POS)
        await Timer(BIT_PERIOD, units=TIME_UNIT)
        data = data >> 1
    #Stop bit:
    dut.ui_in.value = (dut.ui_in.value & DUT_RX_IN_MASK) | (1 << DUT_RX_IN_POS)
    if(wait_at_stop):
        await Timer(BIT_PERIOD, units=TIME_UNIT)
    
async def initialize_module(dut):
    dut._log.info("Initialize module")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

@cocotb.test()
async def test_gps_gen_match(dut):
    dut._log.info("Start")
    # Set the clock period to get a working frequency of 16.368MHz
    clock = Clock(dut.clk, CLK_PERIOD, units=TIME_UNIT)
    cocotb.start_soon(clock.start())
    # Initialize module:
    await initialize_module(dut)
    # Set the input values:
    dut.ui_in.value = 1
    dut.uio_in.value = 0
    #Set test objects and variables:
    error_count = 0
    gen = GPSgen()
    N_ITERATIONS = 5
    N_SAMPLES = 1023*16
    d = date.today()
    test_date = f'{d.year}-{d.month}-{d.day}'
    
    #Test:
    for test_i in range(N_ITERATIONS):
        await initialize_module(dut)
        
        dut._log.info(f'Iteration: {test_i}')
        
        test_sat = random.randint(1,32)
        dut._log.info(f'Test satellite set to: {test_sat}')
        
        test_doppler = 176+random.randint(0,31)
        test_fd_real = -8000.0 + 500.0*(test_doppler-176)
        dut._log.info(f'Test doppler set to: {test_fd_real} ({test_doppler})')
        
        test_ca_phase = random.randint(0,(1023*16)-1)
        test_ca_phase_lo = test_ca_phase & 0xff
        test_ca_phase_hi = test_ca_phase >> 8
        dut._log.info(f'Test code phase set to: {test_ca_phase}')
        
        test_snr = 0
        dut._log.info(f'Test SNR set to: {test_snr}')
        
        #Set sat_id to test_sat:
        await uart_send(dut,SAT_ID_ADDR)
        await uart_send(dut,test_sat-1)
        #Set CA phase:
        await uart_send(dut,CA_PHASE_LO_ADDR)
        await uart_send(dut,0)#test_ca_phase_lo)
        await uart_send(dut,CA_PHASE_HI_ADDR)
        await uart_send(dut,0)#test_ca_phase_hi)
        #Set doppler:
        await uart_send(dut,DOPPLER_ADDR)
        await uart_send(dut,test_doppler)
        #Set SNR shift:
        await uart_send(dut,SNR_ADDR)
        await uart_send(dut,test_snr)
        #General enable and noise disabled:
        await uart_send(dut,CTRL_ADDR)
        await uart_send(dut,0x11,wait_at_stop=False)
        
        #Wait for start::
        while((dut.uo_out.value >> 3)%2 != 1):
            await ClockCycles(dut.clk, 1)
        
        #Log the outputs:
        sin_out = []
        cos_out = []
        for i in range(N_SAMPLES):
            sin_out.append(dut.uo_out.value%2)
            cos_out.append((dut.uo_out.value>>1)%2)
            await ClockCycles(dut.clk, 1)
        #In this case, phase is evaluated in first period of gold code only.
        #This is done setting phase to 0 in dut and shifting the output array in testbench:
        # The reason for that is that the model generates only the first period of gold code
        # and then shifts the output vector depending on the initial phase configured.
        if(test_ca_phase!=0):
            sin_out = sin_out[test_ca_phase:]+sin_out[:test_ca_phase]
            cos_out = cos_out[test_ca_phase:]+cos_out[:test_ca_phase]
        print(f'Output length from DUT = {len(sin_out)}')
        
        (sin_model, cos_model) = gen.get_output(\
            n_sat=test_sat,\
            freq=4092000.0+test_fd_real, \
            init_phase=test_ca_phase, \
            n_samples=N_SAMPLES//16)
        
        with open(OUTPUT_DIR+test_date+'_'+f'{test_sat}_{test_doppler}_{test_ca_phase}_sin_rtl.txt','w') as f_sig:
            for s in sin_out:
                f_sig.write(f'{s}\n')
        
        with open(OUTPUT_DIR+test_date+'_'+f'{test_sat}_{test_doppler}_{test_ca_phase}_sin_mod.txt','w') as f_mod:
            for s in sin_model:
                f_mod.write(f'{s}\n')
        
        with open(OUTPUT_DIR+test_date+'_'+f'{test_sat}_{test_doppler}_{test_ca_phase}_cos_rtl.txt','w') as f_sig:
            for s in cos_out:
                f_sig.write(f'{s}\n')
        
        with open(OUTPUT_DIR+test_date+'_'+f'{test_sat}_{test_doppler}_{test_ca_phase}_cos_mod.txt','w') as f_mod:
            for s in cos_model:
                f_mod.write(f'{s}\n')
        
        print(f'Output length from model = {len(sin_model)}')
        
        for i in range(N_SAMPLES):
            if(sin_out[i]!=sin_model[i]):
                #print(f'ERROR: sin - rtl={sin_out[i]} - model={sin_model[i]} - sample:{i} - iteration{test_i}')
                error_count = error_count+1
            if(cos_out[i]!=cos_model[i]):
                #print(f'ERROR: cos - rtl={cos_out[i]} - model={cos_model[i]} - sample:{i} - iteration{test_i}')
                error_count = error_count+1
    assert (error_count==0)

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")
    # Set the clock period to get a working frequency of 16.368MHz
    clock = Clock(dut.clk, CLK_PERIOD, units=TIME_UNIT)
    cocotb.start_soon(clock.start())
    # Initialize module:
    await initialize_module(dut)
    # Set the input values:
    dut.ui_in.value = 1
    dut.uio_in.value = 0
    #Set test objects and variables:
    n_error_count = 0
    fd_error_count = 0
    sm = Search_tt()
    N_ITERATIONS = 3
    N_SEARCH_SIZE = 70
    d = date.today()
    test_date = f'{d.year}-{d.month}-{d.day}'
    
    #Test:
    for test_i in range(N_ITERATIONS):
        await initialize_module(dut)
        
        dut._log.info(f'Iteration: {test_i}')
        
        test_sat = random.randint(1,32)
        dut._log.info(f'Test satellite set to: {test_sat}')
        
        test_doppler = 176+random.randint(0,31)
        test_fd_real = -8000.0 + 500.0*(test_doppler-176)
        dut._log.info(f'Test doppler set to: {test_fd_real} ({test_doppler})')
        
        test_ca_phase = random.randint(0,(1023*16)-1)
        test_ca_phase_lo = test_ca_phase & 0xff
        test_ca_phase_hi = test_ca_phase >> 8
        dut._log.info(f'Test code phase set to: {test_ca_phase}')
        
        test_snr = random.randint(0,5)
        dut._log.info(f'Test SNR set to: {test_snr}')
        
        #Set sat_id to test_sat:
        await uart_send(dut,SAT_ID_ADDR)
        await uart_send(dut,test_sat-1)
        #Set CA phase:
        await uart_send(dut,CA_PHASE_LO_ADDR)
        await uart_send(dut,0)#test_ca_phase_lo)
        await uart_send(dut,CA_PHASE_HI_ADDR)
        await uart_send(dut,0)#test_ca_phase_hi)
        #Set doppler:
        await uart_send(dut,DOPPLER_ADDR)
        await uart_send(dut,test_doppler)
        #Set SNR shift:
        await uart_send(dut,SNR_ADDR)
        await uart_send(dut,test_snr)
        #General enable:
        await uart_send(dut,CTRL_ADDR)
        await uart_send(dut,0x1,wait_at_stop=False)
        
        #Wait for start::
        while((dut.uo_out.value >> 3)%2 != 1):
            await ClockCycles(dut.clk, 1)
        
        #Log the outputs:
        sin_out = []
        cos_out = []
        for i in range(1023*16):
            sin_out.append(dut.uo_out.value%2)
            cos_out.append((dut.uo_out.value>>1)%2)
            await ClockCycles(dut.clk, 1)
        #In this case, phase is evaluated in first period of gold code only.
        #This is done setting phase to 0 in dut and shifting the output array in testbench:
        #The reason for that is that the model generates only the first period of gold code
        #and then shifts the output vector depending on the initial phase configured.
        if(test_ca_phase!=0):
            sin_out = sin_out[test_ca_phase:]+sin_out[:test_ca_phase]
            cos_out = cos_out[test_ca_phase:]+cos_out[:test_ca_phase]
        print(f'Output length = {len(sin_out)}')
        
        sm.set_n_sat(test_sat)
        
        n_search = []
        for n in range(N_SEARCH_SIZE):
            n_search.append((test_ca_phase + n -(N_SEARCH_SIZE//2))%(1023*16))
        
        f_search = []
        for i_f in range(33):
            f_search.append((i_f-16)*500.0)
        
        (n0, fd, m, n0_res, fd_res, search_res) = sm.correlate_range(data_in=sin_out, n_range=n_search, fd_range=f_search, verbose=False)
        print(f'n0={n0}, fd={fd}, m={m}')
        
        r_string = 'PASS'
        if(n0 != test_ca_phase):
            n_error_count += 1
            r_string = 'FAIL'
            print(f'\n\nERROR: expected: n0={test_ca_phase} but got n0={n0}\n')
        if(fd != test_fd_real):
            fd_error_count +=1
            r_string = 'FAIL'
            print(f'\n\nERROR: expected: fd={test_fd_real} but got fd={fd}\n')
        
        with open(OUTPUT_DIR+test_date+f'_sig_{test_sat}_{test_doppler}_{test_ca_phase}_{test_snr}.txt','w') as f_sig:
            for s in sin_out:
                f_sig.write(f'{s}\n')
        
        with open(OUTPUT_DIR+test_date+'_'+r_string+f'_result_{test_sat}_{test_doppler}_{test_ca_phase}_{test_snr}.txt','w') as f_res:
            for i_res in range(len(n0_res)):
                f_res.write(f'{n0_res[i_res]},{fd_res[i_res]},{search_res[i_res]}\n')
    
    assert (n_error_count==0) and (fd_error_count==0)