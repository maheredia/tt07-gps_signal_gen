# Makefile

# define la variable TEST_DIR para evitar escribir paths largos
TEST_DIR := $(PWD)
SRC_DIR = $(PWD)/../../src

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# define la ubicacion del directorio sim_build generado al simular
SIM_BUILD = $(TEST_DIR)/sim_build
# define la ubicacion del archivo de resultados
COCOTB_RESULTS_FILE = $(TEST_DIR)/results.xml

VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,nco.v)
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,lookup_4x1_sine.v)
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,lookup_4x1_cos.v)

TOPLEVEL = nco

MODULE = nco_tb
COMPILE_ARGS += -Pnco.FREQ_CTRL_WORD_LEN=14 -Pnco.PHASE_ACC_BITS=15 \
-Pnco.TRUNCATED_BITS=2 -Pnco.DATA_BITS_OUT=1

ifeq ($(SIM), icarus) # Hack for iverilog (should be before the Makefile include)
	VERILOG_SOURCES += $(TEST_DIR)/iverilog_dump.v
	COMPILE_ARGS += -s iverilog_dump
endif


# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

#Este bloque genera el archivo iverilog_dump.v
ifeq ($(SIM), icarus) # Hack for iverilog (should be after the Makefile include)
$(TEST_DIR)/iverilog_dump.v:
	@echo 'module iverilog_dump();' > $@
	@echo 'initial begin' >> $@
	@echo '    $$dumpfile("$(TEST_DIR)/$(TOPLEVEL).vcd");' >> $@
	@echo '    $$dumpvars(0, $(TOPLEVEL));' >> $@
	@echo 'end' >> $@
	@echo 'endmodule' >> $@
endif


view:
	@echo "Opening waveform viewer..."
	gtkwave $(TEST_DIR)/nco.vcd &

clean::
	@echo "Removing unnecessary files..."
	@rm -fr $(TEST_DIR)/__pycache__ $(TEST_DIR)/*.vcd $(TEST_DIR)/*.xml \
	$(TEST_DIR)/*.o $(TEST_DIR)/plots $(TEST_DIR)/iverilog_dump.v
	@echo "Done"
