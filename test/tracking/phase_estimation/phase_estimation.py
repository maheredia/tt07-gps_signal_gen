# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer
import math

CLK_PERIOD = 61.094
BIT_PERIOD = 8600
TIME_UNIT = "ns"

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
    dut.rx_in.value = 0
    await Timer(BIT_PERIOD, units=TIME_UNIT)
    await Timer(1000, units=TIME_UNIT)
    #Data:
    for i in range(8):
        #send least significant bit of data using: data%2. Shift data to the right after each iteration.
        dut.rx_in.value = data%2
        await Timer(BIT_PERIOD, units=TIME_UNIT)
        data = data >> 1
    #Stop bit:
    dut.rx_in.value = 1
    if(wait_at_stop):
        await Timer(BIT_PERIOD, units=TIME_UNIT)
    
async def initialize_module(dut):
    dut._log.info("Initialize module")
    dut.msg_in.value = 0
    dut.btns_in.value = 0
    dut.rx_in.value = 0
    dut.rst_in_n.value = 0
    await ClockCycles(dut.clk_in, 10)
    dut.rst_in_n.value = 1

async def shift_nco_up(dut, n_times):
    for i in range(n_times):
        dut.btns_in.value = 1
        await Timer(1000, units=TIME_UNIT)
        dut.btns_in.value = 0
        await Timer(1000, units=TIME_UNIT)

async def shift_nco_down(dut, n_times):
    for i in range(n_times):
        dut.btns_in.value = 2
        await Timer(1000, units=TIME_UNIT)
        dut.btns_in.value = 0
        await Timer(1000, units=TIME_UNIT)

def measure_phase(dut):
    I = dut.accum_I_last.value.signed_integer
    Q = dut.accum_Q_last.value.signed_integer
    phase = 180.0*math.atan(Q/I)/math.pi
    if(I < 0 and Q < 0):
        phase = phase + 180.0
    return phase

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")
    # Set the clock period to get a working frequency of 16.368MHz
    clock = Clock(dut.clk_in, CLK_PERIOD, units=TIME_UNIT)
    cocotb.start_soon(clock.start())
    # Initialize module:
    await initialize_module(dut)
    #General enable and noise disabled:
    await uart_send(dut,CTRL_ADDR)
    await uart_send(dut,0x11,wait_at_stop=False)
    await ClockCycles(dut.clk_in, 100000)

    #Start shifting the bench NCO and reading phase estimation:
    #First, no phase shift, output phase should be 0°
    phase = measure_phase(dut)
    print(f'PHASE ESTIMATION #0 = {phase} °')

    #Shift and measure:
    for i in range(4):
        await shift_nco_up(dut, 1)
        await ClockCycles(dut.clk_in, 50000)
        phase = measure_phase(dut)
        print(f'PHASE ESTIMATION #{i+1} = {phase} °')
    