import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer, RisingEdge, Combine


CLK_FREQUENCY = 16368000
CLK_PERIOD = 61.094
TIME_UNIT = "ns"

async def initialize_module(dut):
    cocotb.start_soon(Clock(dut.clk_in, CLK_PERIOD, units=TIME_UNIT).start())
    dut.rst_in_n.value = 0
    dut.ena_in.value = 0
    await ClockCycles(dut.clk_in, 10)
    dut.rst_in_n.value = 1

@cocotb.test()
async def prng_basic(dut):
    """Test the basics of prng module
    """
    min_period = 1023*16*10
    dut._log.info("Starting prng_basic test")
    dut._log.info("Init dut")
    await initialize_module(dut)
    
    dut._log.info("Enable dut")
    await ClockCycles(dut.clk_in, 10)
    dut.ena_in.value = 1
    
    dut._log.info("Wait for start")
    while(dut.start_out.value != 1):
        await ClockCycles(dut.clk_in, 1)
        
    #Now wait for next start and count the cycles. The period should not be less than the minimum:
    dut._log.info("Now wait for a while")
    i=0
    await ClockCycles(dut.clk_in, 1)
    while(dut.start_out.value != 1 and i < min_period):
        i+=1
        await ClockCycles(dut.clk_in, 1)
    dut._log.info(f'Number of cycles = {i}')
    assert i == (min_period)
