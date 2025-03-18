import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer, RisingEdge, Combine
import numpy as np
import matplotlib.pyplot as plt

CLK_PERIOD = 61.094
TIME_UNIT = "ns"
N_SAMPLES = 2*1023*16
N_NOISE_SAMPLES = 10*1023*16

async def initialize_module(dut):
    cocotb.start_soon(Clock(dut.clk_in, CLK_PERIOD, units=TIME_UNIT).start())
    dut.rst_in_n.value         = 0
    dut.ena_in.value           = 0
    dut.msg_in.value           = 0 # input       
    dut.n_sat_in.value         = 0 # input [4:0] 
    dut.noise_off_in.value     = 1 # input       
    dut.signal_off_in.value    = 0 # input       
    dut.ca_phase_in.value      = 0 # input [15:0]
    dut.doppler_in.value       = 192 # input [7:0] 
    dut.snr_in.value           = 0 # input [7:0] 
    await ClockCycles(dut.clk_in, 10)
    dut.rst_in_n.value = 1

@cocotb.test()
async def snr_measurement(dut):
    """
    Meassure the SNR for each value configured.
    """
    dut._log.info("Starting snr_measurement test")
    dut._log.info("Init dut")
    await initialize_module(dut)

    #For each value of SNR between 0 and 7,
    #Capture a set of data with noise generator disabled and
    #after that, reset the DUT and capture a set of data of the same length
    #with noise enabled.
    snr_table = {}
    for i in range(10):
        #Reset the core:
        dut.rst_in_n.value = 0
        dut.ena_in.value = 0
        await ClockCycles(dut.clk_in, 5)
        dut.rst_in_n.value = 1
        #Set SNR:
        dut._log.info(f"Setting snr_in to {i}")
        dut.snr_in.value = i
        #Turn off noise:
        dut.noise_off_in.value = 1
        #Initialize arrays for storing samples
        samples_clean = np.empty(N_SAMPLES)
        samples_noisy = np.empty(N_SAMPLES)
        #Wait and enable:
        await ClockCycles(dut.clk_in, 10)
        dut.ena_in.value = 1

        #Get clean samples:
        for s in range(N_SAMPLES):
            await ClockCycles(dut.clk_in, 1)
            samples_clean[s] = 1 + (-2*dut.sin_out.value)
        
        #Now reset the core and collect samples with noise:
        dut.rst_in_n.value = 0
        dut.ena_in.value = 0
        await ClockCycles(dut.clk_in, 5)
        dut.rst_in_n.value = 1
        #Turn on noise and enable:
        await ClockCycles(dut.clk_in, 10)
        dut.ena_in.value = 1
        dut.noise_off_in.value = 0

        #Get clean samples:
        for s in range(N_SAMPLES):
            await ClockCycles(dut.clk_in, 1)
            samples_noisy[s] = 1 + (-2*dut.sin_out.value)
        #Compute difference in arrays:
        noise = samples_clean-samples_noisy
        #Save data to file:
        filename = f'snr_{i}.csv'
        samples_all = np.column_stack((samples_clean, samples_noisy, noise))
        np.savetxt(fname=filename, X=samples_all, fmt='%d', delimiter=',', header='clean, noisy, diff')
        #Compute power:
        sig_watts = samples_clean**2
        sig_avg_watts = np.mean(sig_watts)
        sig_avg_db = 10 * np.log10(sig_avg_watts)

        noise_watts = noise**2
        noise_avg_watts = np.mean(noise_watts)
        noise_avg_db = 10 * np.log10(noise_avg_watts)

        print(f'-----------> iteration {i}')
        print(f'SIGNAL AVG dB = {sig_avg_db}')
        print(f'NOISE AVG dB = {noise_avg_db}')
        print(f'MEASURED SNR = {sig_avg_db-noise_avg_db}')

        snr_table[str(i)] = sig_avg_db-noise_avg_db

    print("SUMMARY")
    for k in snr_table.keys():
        print(f'snr = {k} ---------> {snr_table[k]} dB')


@cocotb.test()
async def noise_histogram(dut):
    """
    Meassure the output of signal generator to compute the noise histogram.
    """
    dut._log.info("Starting noise_histogram test")
    dut._log.info("Init dut")
    await initialize_module(dut)
    #Turn on noise and enable:
    await ClockCycles(dut.clk_in, 10)
    dut.noise_off_in.value = 0
    dut.ena_in.value = 1
    #Wait for noise start signal:
    start=0
    dut._log.info("Waiting for first start")
    while(start==0):
        start = dut.noise_start_out.value
        await ClockCycles(dut.clk_in, 1)
    #Now, start collecting noise samples:
    samples = np.zeros(0)
    start=0
    i=0
    dut._log.info("Waiting for next start or sample limit")
    while(start==0 and i<N_NOISE_SAMPLES):
        start = dut.noise_start_out.value
        samples = np.append(samples, dut.noise_full.value.signed_integer)
        await ClockCycles(dut.clk_in, 1)
        i=i+1
    filename = f'noise_full.csv'
    np.savetxt(fname=filename, X=np.array(samples), fmt='%d')
    #Make histogram:
    num_bins = 20
    n, bins, _ = plt.hist(samples, num_bins, density=True, color='green', alpha=0.7)
    plt.xlabel('X-Axis')
    plt.ylabel('Y-Axis')
    plt.title('Histogram of noise generator', fontweight='bold')
    plt.savefig('histogram.png')
