from nco import NCO
from gold_codes import GC

class GPSgen():
    def __init__(self, N_bits:int=14, M_bits:int=15, sys_clk_freq:float=16368000.0):
        self.nco = NCO(N_bits=N_bits, M_bits=M_bits, f_in=sys_clk_freq)
        self.gc_oversampling = sys_clk_freq/1023000.0
        self.gc = GC(fs=sys_clk_freq)
        
    def get_output(self, n_sat=1, freq=4092000.0, init_phase=0, n_samples=1023):
        ca_code = self.gc.get_gold_code(n_sat, n_samples)
        phi=self.nco.get_phi_from_fout(freq)
        self.nco.set_delta_phi(phi)
        (sin,cos) = self.nco.get_output(n_points=len(ca_code))
        gpsCos=[]
        gpsSin=[]
        for i in range(len(ca_code)):
            gpsCos.append(self.gc._xor([ca_code[i], cos[i]]))
            gpsSin.append(self.gc._xor([ca_code[i], sin[i]]))
        if(init_phase==0):
            return (gpsSin, gpsCos)
        else:
            return (gpsSin[init_phase:]+gpsSin[:init_phase], gpsCos[init_phase:]+gpsCos[:init_phase])