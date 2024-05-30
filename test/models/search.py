from gps_gen import GPSgen
import numpy as np

class SearchModule:
    def __init__(self, N_bits:int=14, M_bits:int=15, sys_clk_freq:float=16368000.0):
        self.sys_clk_freq = sys_clk_freq
        self.gps_gen = GPSgen(N_bits=N_bits, M_bits=M_bits, sys_clk_freq=sys_clk_freq)
        self.freq = 4092000.0
        self.n_sat = 1
        self.ca_phase = 0
        
    def generate_synthetic(self,f_i=4092000.0, sat_id=[1], ca_shift=[0], f_d=[0.0], carrier_shift=[0.0], snr=-20.0, n_samples=1023, output_file=None):
        #Set parameters:
        Ts = 1.0/(self.sys_clk_freq)
        #Generate gold codes:
        gps_sum = np.zeros(self.gps_gen.gc.get_size_resampled(n_samples))
        for i in range(len(sat_id)):
            gc = np.roll(np.array(self.gps_gen.gc.get_gold_code(sat_id[i],n_samples)), -1*ca_shift[i])
            #Multiply gold code by cosine signal:
            gps_signal_clean = []
            for j in range(len(gc)):
                gps_signal_clean.append(((-2.0)*gc[j]+1.0)*np.cos((2.0*np.pi*(f_i+f_d[i])*Ts*j) + carrier_shift[i]))
            #Add gps signals:
            gps_sum = gps_sum + np.asarray(gps_signal_clean)
        #Add noise:
        sig_watts = gps_sum**2
        sig_avg_watts = np.mean(sig_watts)
        sig_avg_db = 10 * np.log10(sig_avg_watts)
        target_snr_db = snr
        noise_avg_db = sig_avg_db - target_snr_db
        noise_avg_watts = 10 ** (noise_avg_db / 10)
        mean_noise = 0
        noise = np.random.normal(mean_noise, np.sqrt(noise_avg_watts), len(sig_watts))
        gpsSignal = (gps_sum + noise)/2
        #Truncate to 1 bit:
        gpsSignal_trunc = []
        for s in gpsSignal:
            if s >= 0:
                gpsSignal_trunc.append(0)
            else:
                gpsSignal_trunc.append(1)
        #Generate output file if requested:
        if(output_file != None):
            total_samples = len(gpsSignal_trunc)
            n_bytes = total_samples//8 + (1 if (total_samples%8 != 0) else 0)
            padding = (8 - total_samples%8) if (total_samples%8 != 0) else 0
            gpsSignal_trunc.extend(0 for i in range(padding))
            with open(output_file, 'wb') as o_file:
                for i in range(n_bytes):
                    val=0
                    for j in range(8):
                        val = val + gpsSignal_trunc[i*8+j]*2**(j)
                    o_file.write(bytes([val]))
        return gpsSignal_trunc
    
    def set_freq(self, freq:float):
        self.freq = freq
        return
    
    def get_freq(self):
        return self.freq
    
    def set_n_sat(self, n_sat:int):
        self.n_sat = n_sat
        return
    
    def get_n_sat(self):
        return self.n_sat
    
    def set_ca_phase(self, ca_phase:int):
        self.ca_phase = ca_phase
        return
    
    def get_ca_phase(self):
        return self.ca_phase
    
    def correlate_single(self, data_in):
        (sin_local, cos_local) = self.gps_gen.get_output(\
            n_sat=self.n_sat,\
            freq=self.freq, \
            init_phase=self.ca_phase, \
            n_samples=int(len(data_in)/self.gps_gen.gc_oversampling)+1)
        sinAccum=0
        cosAccum=0
        for i in range(len(data_in)):
            sinAccum = sinAccum + int(-2*self.gps_gen.gc._xor([data_in[i], sin_local[i]]) +1)
            cosAccum = cosAccum + int(-2*self.gps_gen.gc._xor([data_in[i], cos_local[i]]) +1)
        return (sinAccum,cosAccum)
    
    def correlate_range(self, data_in, f_in=4092000.0, shift_max=20, fd_max=4000.0, fd_step=1000.0, n_range=[], fd_range=[], verbose=False):
        if(len(n_range) != 0 and len(fd_range) != 0):
            n_search  = n_range
            fd_search = fd_range
        else:
            n_search  = np.linspace(-1*shift_max, shift_max, 2*shift_max +1, dtype=int)
            fd_search = np.arange(-1.0*fd_max, fd_max+fd_step, fd_step, dtype=float)
        print("Search size = {:d}x{:d} = {:d}".format(len(n_search),len(fd_search),len(n_search)*len(fd_search)))
        print(f'n0_search = {n_search}\nfd_search = {fd_search}')
        #Do search:
        search_results = []
        n_results = []
        fd_results = []
        for n0 in n_search:
            for fd in fd_search:
                self.set_freq(f_in+fd)
                self.set_ca_phase(n0)
                #Do single correlation:
                (c_sin, c_cos) = self.correlate_single(data_in)
                c = np.square(c_sin) + np.square(c_cos)
                search_results.append(c)
                n_results.append(n0)
                fd_results.append(fd)
                if(verbose):
                    print(f'n0 = {n0}, f0 = {f_in+fd}, C = {c}')
            #end fd for
        #end n for
        m = max(search_results)
        i = search_results.index(m)
        return (n_results[i], fd_results[i], m)
    
    def correlate_coarse(self):
        return (0.0,0.0)
    
    def correlate_fine(self):
        return (0.0,0.0)