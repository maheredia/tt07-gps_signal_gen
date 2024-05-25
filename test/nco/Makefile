# Makefile

# define la variable BASE_DIR para evitar escribir paths largos
BASE_DIR := gps/verif/search_module/local_gps_gen/nco


# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# define la ubicacion del directorio sim_build generado al simular
SIM_BUILD = $(BASE_DIR)/sim_build
# define la ubicacion del archivo de resultados
COCOTB_RESULTS_FILE = $(BASE_DIR)/results.xml


VERILOG_SOURCES += gps/rtl/search_module/local_gps_gen/nco/nco.v
VERILOG_SOURCES += gps/rtl/search_module/local_gps_gen/nco/lookup.v

TOPLEVEL = nco

MODULE = gps.verif.search_module.local_gps_gen.nco.nco_tb
COMPILE_ARGS += -Pnco.FREQ_CTRL_WORD_LEN=14 -Pnco.PHASE_ACC_BITS=15 \
-Pnco.TRUNCATED_BITS=2 -Pnco.DATA_BITS_OUT=1

ifeq ($(SIM), icarus) # Hack for iverilog (should be before the Makefile include)
	VERILOG_SOURCES += $(BASE_DIR)/iverilog_dump.v
	COMPILE_ARGS += -s iverilog_dump
endif


# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

#Este bloque genera el archivo iverilog_dump.v
ifeq ($(SIM), icarus) # Hack for iverilog (should be after the Makefile include)
$(BASE_DIR)/iverilog_dump.v:
	@echo 'module iverilog_dump();' > $@
	@echo 'initial begin' >> $@
	@echo '    $$dumpfile("$(BASE_DIR)/$(TOPLEVEL).vcd");' >> $@
	@echo '    $$dumpvars(0, $(TOPLEVEL));' >> $@
	@echo 'end' >> $@
	@echo 'endmodule' >> $@
endif


view:
	@echo "Opening waveform viewer..."
	gtkwave $(BASE_DIR)/nco.vcd &

clean::
	@echo "Removing unnecessary files..."
	@rm -fr $(BASE_DIR)/__pycache__ $(BASE_DIR)/*.vcd $(BASE_DIR)/*.xml \
	$(BASE_DIR)/*.o $(BASE_DIR)/plots $(BASE_DIR)/iverilog_dump.v
	@echo "Done"
