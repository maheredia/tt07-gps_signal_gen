from search import SearchModule
import numpy as np

#Derived class, customized for this tt submission:
class Search_tt(SearchModule):
    def correlate_single(self, data_in):
        (sin_local, cos_local) = self.gps_gen.get_output(\
            n_sat=self.n_sat,\
            freq=self.freq, \
            init_phase=self.ca_phase, \
            n_samples=int(len(data_in)/self.gps_gen.gc_oversampling))
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
        return (n_results[i], fd_results[i], m, n_results, fd_results, search_results)