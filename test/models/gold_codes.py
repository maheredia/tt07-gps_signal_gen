class GC:
    
    def __init__(self, fs:float=1023000.0):
        self.fs = fs
        self.ca_code_freq = 1023000.0
        self.sat_dict = {
            '1':(2,6),
            '2':(3,7),
            '3':(4,8),
            '4':(5,9),
            '5':(1,9),
            '6':(2,10),
            '7':(1,8),
            '8':(2,9),
            '9':(3,10),
            '10':(2,3),
            '11':(3,4),
            '12':(5,6),
            '13':(6,7),
            '14':(7,8),
            '15':(8,9),
            '16':(9,10),
            '17':(1,4),
            '18':(2,5),
            '19':(3,6),
            '20':(4,7),
            '21':(5,8),
            '22':(6,9),
            '23':(1,3),
            '24':(4,6),
            '25':(5,7),
            '26':(6,8),
            '27':(7,9),
            '28':(8,10),
            '29':(1,6),
            '30':(2,7),
            '31':(3,8),
            '32':(4,9)
        }
        
    def get_fs(self):
        return self.fs
    
    def set_fs(self,fs):
        self.fs = fs
        
    def get_size_resampled(self, n_samples):
        return int(n_samples*(self.fs/self.ca_code_freq))
            
    def _xor(self, bits):
        n_ones = 0
        for b in bits:
            if b==1:
                n_ones=n_ones+1
            elif b==0:
                n_ones=n_ones
            else:
                print("Error, must use 1 or 0 only")
                return -1
        if(n_ones%2 == 0):
            return 0
        else:
            return 1
        
    def get_gold_code(self, n_sat=1, n_samples=1023):
        if n_sat<0 or n_sat>32:
            print("Satellite ID must be between 0 and 32")
            return -1
        
        g2_a = self.sat_dict[str(n_sat)][0]
        g2_b = self.sat_dict[str(n_sat)][1]
    
        #G1 and G2 init:
        g1 = [1,1,1,1,1,1,1,1,1,1]
        g2 = [1,1,1,1,1,1,1,1,1,1]
    
        ca_out = []
        for i in range(n_samples):
            ca_out.append(self._xor([g1[-1],self._xor([g2[g2_a-1],g2[g2_b-1]])]))
            next_g1 = self._xor([g1[2], g1[9]])
            next_g2 = self._xor([g2[1], g2[2], g2[5], g2[7], g2[8], g2[9]])
            for j in range(10):
                if j==9:
                    g1[10-1-j] = next_g1
                    g2[10-1-j] = next_g2
                else:
                    g1[10-1-j] = g1[10-1-j-1]
                    g2[10-1-j] = g2[10-1-j-1]
        #Adjust to requested sampling frequency:
        i=0
        j=0
        Ts = 1/(self.ca_code_freq)
        Ts_new = 1/(self.fs)
        ca_resampled = []
        while(i<len(ca_out)):
            low_bound = i*Ts
            hi_bound = (i+1)*Ts
            while(low_bound <= j*Ts_new and j*Ts_new < hi_bound):
                ca_resampled.append(ca_out[i])
                j=j+1
            i=i+1
        return ca_resampled[:int(n_samples*(Ts/Ts_new))]