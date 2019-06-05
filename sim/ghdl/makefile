#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

# Use bash for shell commands
SHELL := /bin/bash


#---- Project config. ----------------------------------------------------------

HERE            := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
PROJECTDIR      := $(HERE)/../..
SWDIR           := $(PROJECTDIR)/src/sw
UASMDIR         := $(PROJECTDIR)/tools/uasm


#---- Simulator configuration. -------------------------------------------------

# GHDL.
GHDLC         := ghdl
GHDLFLAGS     :=
GHDLSIMFLAGS  := --ieee-asserts=disable


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


.DEFAULT: help
.PHONY: help
help:
	@echo "Build and run light8080 TBs (VHDL version only) using GHDL"
	@echo
	@echo "GOALS:"
	@echo
	@echo "   sim  ................ Build SW test \$$TEST and run it on TB"
	@echo "     sw  ............... Build SW test \$$TEST"
	@echo "     ghdl-elab  ........ Elaborate RTL + TB sources"
	@echo "     ghdl-run  ......... Run elaborated simulation"
	@echo
	@echo "   help  ............... Show this text"
	@echo "   clean  .............. Remove GHDL output files"
	@echo "   clean-sw  ........... Clean SW test \$$TEST"
	@echo "   clean-all  .......... Remove GHDL output files & clean all SW tests"
	@echo 


# Make sure the test SW directory at least exists.
.PHONY: check_test
check_test:
ifeq ($(wildcard $(SWDIR)/$(TEST)/.),)
	$(error ERROR: Could not find test directory '$(SWDIR)/$(TEST)'.)
endif

# Build SW, generate ROM files (obj code vhdl package) for RTL simulation.
.PHONY: sw
sw: check_test
	make -C $(SWDIR)/$(TEST) vhdl

# Just invoke the simulator.
.PHONY: sim
sim: ghdl-elab ghdl-run 

# Generate the microcode RTL source from the microcode assembly file.
$(UCODEFILE):
	$(UASMDIR)/ucode_asm.py -l $(CURDIR)/light8080.m80.lst $(UCODEFILE) $(RTLDIR)/light8080_ucode_pkg.vhdl


# Run SW on VHDL TB on GHDL.
.PHONY: ghdl-run
ghdl-run: sw ghdl-elab  
	$(GHDLC) -r $(TBUNIT) $(GHDLSIMFLAGS) --wave=$(TBUNIT).ghw

# Compile the whole set of sources, packages first.
# Note we insert the SW object code package after the main package sources.
.PHONY: ghdl-elab
ghdl-elab: $(PKGRTL) $(SRCRTL)
	$(GHDLC) -a $(GHDLFLAGS) ${PKGRTL} ${PKGCODE} ${SRCRTL}
	$(GHDLC) -a $(GHDLFLAGS) $(PKGTB) $(SRCTB)
	$(GHDLC) -e $(GHDLFLAGS) $(TBUNIT)


.PHONY: clean
clean: check_test
	rm -f $(TBUNIT)
	rm -rf *.lst *.map *.rel *.sym *.p *.ihx *.vhdl *.v *.lst *.o
	rm -rf *.cf
	$(GHDLC) --clean
	rm -rf *.vcd *.ghw


.PHONY: clean-all
clean-all: clean
	rm -f $(SWDIR)/*/obj_code_pkg.vhdl

.PHONY: clean-sw
clean-sw:
	make -C $(SWDIR)/$(TEST) clean