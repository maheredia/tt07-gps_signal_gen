class NCO():
    
    def __init__(self, N_bits:int=9, M_bits:int=10, f_in:float=4092.0, oversampling:int=1):
        self.deltaPhi = 1
        self.M_bits = M_bits
        self.N_bits = N_bits
        self.f_in = f_in
        self.oversampling = oversampling
        
    def set_M_N_bits(self,M,N):
        self.M_bits = M
        self.N_bits = N
        
    def get_M_N_bits(self):
        return (self.M_bits, self.N_bits)
    
    def set_delta_phi(self,deltaPhi:int):
        if(deltaPhi > 2**(self.N_bits)-1 or deltaPhi < 0):
            print("Error: deltaPhi = {:d} out of range: 0 <= deltaPhi < {:d}".format(deltaPhi, 2**(self.N_bits)-1))
            return -1
        else:
            self.deltaPhi = int(deltaPhi)
        return 0
    
    def get_delta_phi(self):
        return self.deltaPhi
    
    def set_f_in(self,f_in:float):
        self.f_in = f_in
        return 0
    
    def get_f_in(self):
        return self.f_in
    
    def set_oversampling(self,oversampling:int):
        self.oversampling = oversampling
        return 0
    
    def get_oversampling(self):
        return self.oversampling
    
    def get_resolution(self):
        return (self.oversampling*self.f_in) / (2**self.M_bits)
    
    def get_f_out(self):
        return (self.deltaPhi*self.oversampling*self.f_in) / (2**self.M_bits)
    
    def get_phi_from_fout(self,fout:float):
        phi = int(fout*(2**self.M_bits) / (self.oversampling*self.f_in))
        candidates = [phi-1, phi, phi+1]
        error=[]
        for p in candidates:
            f_calc = (p*self.oversampling*self.f_in) / (2**self.M_bits)
            error.append(abs(fout-f_calc))
        return candidates[error.index(min(error))]
    
    def show_range(self):
        res = self.get_resolution()
        f_low = res
        f_high = res*(2**self.N_bits -1)
        print("NCO range:\n\tf_low = {:e} Hz\n\tf_high = {:e} Hz\n\tresolution = {:e} Hz".format(f_low, f_high, res))
    
    def _accum(self, n_points:int=4096):
        accum = [0]
        accum_max = 2**(self.M_bits)
        for i in range(1,n_points):
            accum.append((accum[i-1]+self.deltaPhi) % accum_max)
        return accum
    
    def _truncate(self, data_in:list):
        n_bits_out = 2
        shift = (self.M_bits-n_bits_out)
        out = []
        for element in data_in:
            out.append(element >> shift)
        return out
    
    def _lut(self,data_in:list):
        sin = []
        cos = []
        for element in data_in:
            sin.extend((1 if element < 2 else 0) for j in range(self.oversampling))
            cos.extend((1 if element==0 or element==3 else 0) for j in range(self.oversampling))
        return (sin,cos)
    
    def get_output(self, n_points:int=4096):
        n_samples = n_points // self.oversampling
        rem = n_points%self.oversampling
        if(rem==0):
            acc = self._accum(n_samples)
        else:
            acc = self._accum(n_samples+1)
        lut_in = self._truncate(acc)
        (sin, cos) = self._lut(lut_in)
        if(rem==0):
            return (sin,cos)
        else:
            return (sin[:-(self.oversampling-rem)], cos[:-(self.oversampling-rem)])