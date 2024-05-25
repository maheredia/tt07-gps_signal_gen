# Makefile

# define la variable BASE_DIR para evitar escribir paths largos
BASE_DIR := gps/verif/search_module/local_gps_gen/gc_gen


# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# define la ubicacion del directorio sim_build generado al simular
SIM_BUILD = $(BASE_DIR)/sim_build
# define la ubicacion del archivo de resultados
COCOTB_RESULTS_FILE = $(BASE_DIR)/results.xml

#Tengo que ver como pasarle variables al makefile para no tener que cambiar
#el nombre del módulo siempre, por ej:
# MODULE_NAME ?= nombre_default.v --> si no se asigna un nombre, debería fallar
VERILOG_SOURCES += gps/rtl/search_module/local_gps_gen/gc_gen/gc_gen.v

# Acá también
TOPLEVEL = gc_gen
# MODULE es el nombre del .py, se especifica así porque ejecutamos desde el dir base
MODULE = gps.verif.search_module.local_gps_gen.gc_gen.gc_gen_tb


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
	gtkwave $(BASE_DIR)/gc_gen.vcd &

clean::
	@echo "Removing unnecessary files..."
	@rm -fr $(BASE_DIR)/__pycache__ $(BASE_DIR)/*.vcd $(BASE_DIR)/*.xml $(BASE_DIR)/*.o $(BASE_DIR)/plots $(BASE_DIR)/iverilog_dump.v
	@echo "Done"
