#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

.PHONY: clean sim ghdl ghdl_rtl ghdl_syntax

.DEFAULT: sim

#---- Project config. ----------------------------------------------------------

PROJECTDIR	 	:= ../..
SWDIR 				:= $(PROJECTDIR)/src/sw
UASMDIR 			:= $(PROJECTDIR)/tools/uasm


#---- Simulator configuration. -------------------------------------------------

# GHDL.
GHDLC		:= ghdl
GHDLFLAGS 	:=
GHDLSIMFLAGS 	:= --ieee-asserts=disable
# GtkWave.
WAVE 		:= gtkwave


#---- Defaults. ----------------------------------------------------------------

# By omission the SW test we'll run is the CPU diagnostic.
TEST ?= diagnostic

#---- Sources. -----------------------------------------------------------------

# Synthesizable RTL sources.
RTLDIR 			:= $(PROJECTDIR)/src/vhdl/rtl
PKGRTL			:= $(RTLDIR)/mcu/mcu80_pkg.vhdl 
SRCRTL 			:= $(filter-out $(PKGRTL), $(wildcard $(RTLDIR)/*.vhdl))
SRCRTL 			+= $(filter-out $(PKGRTL), $(wildcard $(RTLDIR)/mcu/*.vhdl)) 
 
# VHDL package that contains the SW code.
# FIXME dependency with SW makefile here! 
PKGCODE 		:= ${SWDIR}/${TEST}/obj_code_pkg.vhdl

# RTL TB sources.
TBDIR  			:= $(PROJECTDIR)/src/vhdl/testbench
PKGTB  			:= 
#$(TBDIR)/txt_util.vhdl
SRCTB 			:= $(filter-out $(PKGTB), $(wildcard $(TBDIR)/*.vhdl))
TBUNIT			:= mcu80_tb

# CPU microcode sources.
UCODEDIR		:= $(PROJECTDIR)/src/ucode
UCODEFILE		:= $(UCODEDIR)/light8080.m80


#---- Rules. -------------------------------------------------------------------

# Make sure the test SW directory at least exists.
check_test:
ifeq ($(wildcard $(SWDIR)/$(TEST)/.),)
	$(error ERROR: Could not find test directory '$(SWDIR)/$(TEST)'.)
endif

# Build SW, generate ROM files (obj code vhdl package) for RTL simulation.
sw: check_test
	make -C $(SWDIR)/$(TEST) vhdl

# Just invoke the simulator.
sim: ghdl 

# Generate the microcode package from the microcode assembly file.
ucode: $(UCODEFILE)
	$(UASMDIR)/ucode_asm.py -l $(CURDIR)/light8080.m80.lst $(UCODEFILE) $(RTLDIR)/light8080_ucode_pkg.vhdl


# Run SW on VHDL TB on GHDL. 
ghdl: sw ucode ghdl_rtl 
	$(GHDLC) -a $(GHDLFLAGS) $(PKGTB) $(SRCTB)
	$(GHDLC) -m $(GHDLFLAGS) $(TBUNIT)
	./$(TBUNIT) $(GHDLSIMFLAGS) --wave=$(TBUNIT).ghw

# Compile the whole set of sources, packages first.
# Note we insert the SW object code package after the main package sources.
ghdl_rtl: $(PKGRTL) $(SRCRTL)
	$(GHDLC) -a $(GHDLFLAGS) ${PKGRTL} ${PKGCODE} ${SRCRTL}

# Invoke ghdl to check source syntax.
ghdl_syntax:
	$(GHDLC) -s $(PKGTB) $(SRCTB)

# Invoke the wave viewer, assume there are waves to view at all.
ghdl_view : ghdl
	$(WAVE) $(TBUNIT).ghw

clean: check_test
	rm -rf *.lst *.map *.rel *.sym *.p *.ihx *.vhdl *.v *.lst
	$(GHDLC) --clean
	rm -rf *.vcd *.ghw *.cf
	make -C $(SWDIR)/$(TEST) clean
