# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer
import sys
import os
sys.path.append(os.getcwd()+'/models/')
from search import SearchModule

CLK_PERIOD = 61.094
BIT_PERIOD = 8600
TIME_UNIT = "ns"

DUT_RX_IN_POS     = 0
DUT_RX_IN_MASK    = 0xFE
DUT_MSG_IN_POS    = 1
DUT_MSG_IN_MASK   = 0xFD
DUT_PRST_SEL_POS  = 2
DUT_PRST_SEL_MASK = 0xF3

CTRL_ADDR        = 0
SAT_ID_ADDR      = 2
DOPPLER_ADDR     = 3
CA_PHASE_LO_ADDR = 4
CA_PHASE_HI_ADDR = 5
SNR_ADDR         = 6

async def uart_send(dut,data):
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
    await Timer(BIT_PERIOD, units=TIME_UNIT)

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to get a working frequency of 16.368MHz
    clock = Clock(dut.clk, CLK_PERIOD, units=TIME_UNIT)
    cocotb.start_soon(clock.start())

    # Reset
    test_sat = 7
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")

    # Set the input values you want to test
    dut.ui_in.value = 1
    dut.uio_in.value = 0
    
    #Set sat_id to test_sat:
    await uart_send(dut,SAT_ID_ADDR)
    await uart_send(dut,test_sat-1)
    
    #Set CA phase:
    await uart_send(dut,CA_PHASE_LO_ADDR)
    await uart_send(dut,8)
    
    #Set doppler:
    await uart_send(dut,DOPPLER_ADDR)
    await uart_send(dut,185)
    
    #Disable noise:
    await uart_send(dut,CTRL_ADDR)
    await uart_send(dut,0x10)
    
    #Enable:
    await uart_send(dut,CTRL_ADDR)
    await uart_send(dut,0x11)
    
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
    print(f'Output length = {len(sin_out)}')
    first_n = 10
    print('Beginning of sine output:')
    print(sin_out[:first_n])
    print('Beginning of cosine output:')
    print(cos_out[:first_n])
    
    # Dummy assert, this should be improved with a real PASS/FAIL criterium: TODO
    sm = SearchModule()
    sm.set_n_sat(test_sat)
    n_search = []
    for n in range(10):
        n_search.append(n)
    f_search = []
    for i_f in range(33):
        f_search.append((i_f-16)*500.0)
    print(f'CA phase search: {n_search}')
    print(f'Doppler search: {f_search}')
    (n0, fd, m) = sm.correlate_range(data_in=sin_out, n_range=n_search, fd_range=f_search, verbose=False)
    
    print(f'n0={n0}, fd={fd}, m={m}')
    assert n0 == 8
    assert fd == -3500.0