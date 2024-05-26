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
    
    #Set sat_id to 7:
    await uart_send(dut,SAT_ID_ADDR)
    await uart_send(dut,7)
    
    #Set CA phase to 16:
    await uart_send(dut,CA_PHASE_LO_ADDR)
    await uart_send(dut,16)
    
    #Set doppler:
    await uart_send(dut,DOPPLER_ADDR)
    await uart_send(dut,198)
    
    #Start CA phase adjustment:
    await uart_send(dut,CTRL_ADDR)
    await uart_send(dut,1<<3)
    await ClockCycles(dut.clk, 1)
    
    #Wait for CA phase done:
    while((dut.uo_out.value >> 2)%2 != 1):
        await ClockCycles(dut.clk, 1)
    
    #Enable:
    await uart_send(dut,CTRL_ADDR)
    await uart_send(dut,1)
    
    #Wait for some time and log the outputs:
    sin_out = []
    cos_out = []
    for i in range(2046):
        sin_out.append(dut.uo_out.value%2)
        cos_out.append((dut.uo_out.value>>1)%2)
        await ClockCycles(dut.clk, 1)

    # Dummy assert, this should be improved with a real PASS/FAIL criterium: TODO
    assert dut.uo_out.value != 256
