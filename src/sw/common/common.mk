# Makefile fragment -- see $(PROJECTDIR)/sim/{ghdl|icarus}/makefile
#-------------------------------------------------------------------------------
# Build some test SW and optionally execute it on the TB for mcu80 using GHDL.
#
# This makefile fragment is meant to be included from the makefile for the SW
# in question. $(CURDIR) is meant to be the SW dir.
# BUT you really should invoke the simulation from $(PROJECTDIR)/sim.
# 
# TARGETS
# ========
# vhdl          - Build SW, put it on ROMable VHDL package constant.
# ghdl 		- Build all then run test SW on mcu80 TB on GHDL.
# clean 	- Clean.
#
# Equivalent targets for the Verilog version of the project, using Icarus, will
# be added eventually.
#-------------------------------------------------------------------------------

.PHONY: clean vhdl verilog ghdl ghdl_rtl ghdl_syntax

#---- Assembler configuration. Adapt to your own setup. ------------------------

# Relative to SW dir.
# FIXME part of pending refactor. Clean up!
PROJECTDIR		:= ../../..


#  Assembler, ASL.
ASM := $(PROJECTDIR)/tools/asl/install/bin/asl
AFLAGS := -L -G
# Object code formatter. ASL does not support linking.
OBJ2HEX := $(PROJECTDIR)/tools/asl/install/bin/p2hex
OFLAGS := -F Intel

# Assembly extension is 'mac' for ASL by convention in light8080.
ASM_EXT := mac
# Object code extension is hardcoded to 'p' in ASL.
OBJ_EXT := p

#---- Simulator configuration. -------------------------------------------------

# GHDL.
GHDLC		:= ghdl
GHDLFLAGS 	:=
GHDLSIMFLAGS 	:= --ieee-asserts=disable
# GtkWave.
WAVE 		:= gtkwave

#---- Utilities. --------------------------------------------------------------- 

# ihex-to-vhdl/verilog object code conversion script -- part of light8080.
ROM_RTL 	:= $(PROJECTDIR)/tools/build_rom/src/build_rom.py
ROM_RTL_FLAGS 	:= --quiet 
# TODO This is an example, it's not used yet.
ROM_RTL_DEFINES := +define+A=45


#---- Defaults. ----------------------------------------------------------------

# Default values for RTL files.
VHDL_PKG_NAME 	?= obj_code_pkg.vhdl
VLOG_INC_NAME 	?= obj_code.inc.v


#---- Vars & rules common to all code samples. ---------------------------------

# SW sources. 
# All assembly files in directory get assembled. Only assembly supported.
ASM_SRC 		:= $(wildcard *.${ASM_EXT})

# Output name is first name of list. 
# This is how asXXXX worked, we do the same for ASL. Doesn't matter. 
OBJ 			:= $(addsuffix .${OBJ_EXT}, $(basename $(word 1, ${ASM_SRC})))
HEX 			:= $(addsuffix .ihx, $(basename $(word 1, ${ASM_SRC})))

# Will be nonempty if ASL assembler is actually there.
ASL_INSTALLED 		:= $(shell command -v ${ASM} 2> /dev/null)

# If ASL is not installed, echo some useful advice.
check_assembler_install:
ifndef ASL_INSTALLED
	@echo -e "\e[1;31mCould not find ASL assembler at the expected path.\e[0m"
	@echo -e "\e[1;37mThere's a makefile at \$$PROJECT/tools that will install a local copy for you.\e[0m"
	@echo -e "\e[1;37m(Contained within this project, no root privileges needed, no mess. You need git & gcc though.)\e[0m"
	@echo -e "\e[1;37mIf you install it manually elsewhere make sure to fix the path in \$$PROJECT/src/sw/common/common.mk.\e[0m"
endif


# Assembler. All files get fed at once.
${OBJ}: check_assembler_install ${ASM_SRC}
ifndef ASL_INSTALLED
	$(error ASL assembler not found at the expected path. Please install it or fix makefile)
endif 
	$(ASM) $(AFLAGS) ${ASM_SRC}

# Linker. 
# ASL does not have a linker as such; this step is a p-to-hex reformatter.
bin: ${OBJ}
	${OBJ2HEX} ${OBJ} ${HEX} ${LFLAGS}

# VHDL package generator.
vhdl: bin
	@echo Building VHDL package \'$(VHDL_PKG_NAME)\'
	@$(ROM_RTL) --project=$(PROJ_NAME) --output=$(VHDL_PKG_NAME) \
		$(ROM_RTL_FLAGS) \
		$(HEX) \
		$(ROM_RTL_DEFINES)

# Verilog include file generator.
# TODO add support for Verilog! 
verilog: bin
	@echo Building Verilog include file \'$(VLOG_INC_NAME)\'

# Build SW, generate ROM files for RTL simulation.
sw: vhdl verilog


clean:
	rm -rf *.lst *.map *.rel *.sym *.p *.ihx *.vhdl *.v
	$(GHDLC) --clean
	rm -rf *.vcd *.ghw *.cf
