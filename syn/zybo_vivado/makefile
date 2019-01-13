# Generic makefile to build small FPGA project using Vivado toolchain.
#

#~~~~ Common variables ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# If we run a shell from any of the goals we want it to be Bash.
SHELL := /bin/bash

# Put some color in that wall of text.
# Just leave blank if you'd rather get the raw output.
# This does not affect the log files, only the console output.
GREP_HIGHLIGHT = \
  | GREP_COLOR="1;37" grep --color -E '^|ERROR|CRITICAL WARNING|WARNING'


#~~~~ Project config ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# The project configuration is done entirely in script `build.tcl`.
# (It's only a short list of source and constraint files along with
# some target parameters.)

# All we need to set up here is the root dir to be passed to the build script.
PROJECT_ROOT = $(realpath ../..)


#~~~~ Goals ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.PHONY: help
help:
	@echo 'Build light8080 demo core for Zybo board using Vivado toolchain.'
	@echo 'Goals:'
	@echo
	@echo 'build            - Build project bitstream (in ./output)'
	@echo
	@echo 'all              - Build bitstream and display error/warning summary'
	@echo
	@echo 'clean            - Delete all files created by build'
	@echo
	@echo

.default: help


# We expect XILINX_VIVADO pointing at the local Vivado install.
# This variable is set by one of Xilinx's setup scripts. 
check-vivado-variable:
ifndef XILINX_VIVADO
  $(error XILINX_VIVADO is undefined -- maybe run '/opt/Xilinx/Vivado/*/settings64.sh')
endif

# All output goes into this directory.
output:
	mkdir -p output

# Build bitstream.
.PHONY: build
build: check-vivado-variable output
	@echo -e "\e[1;33mRunning Vivado Synth+Impl non-project flow.\e[0m"
	cd output; \
	vivado -mode batch -source ../build.tcl -tclargs $(PROJECT_ROOT) $(GREP_HIGHLIGHT)

# Build bitstream and display a summary of error and warning messages.
.PHONY: all
all: build quickreport


# Display a quick summary of errors and warnings by parsing log files.
.PHONY: quickreport
quickreport:
	@NUMERR=$(cat output/vivado.log | grep -E "ERROR" | wc -l); \
	echo -e "\e[1;36mError messages:   $$NUMERR\e[0m"; \
	cat output/vivado.log | grep --color -E "ERROR" || true
	@NUMWARN=$(cat output/vivado.log | grep -E "WARNING|CRITICAL WARNING" | wc -l); \
	echo -e "\e[1;36mWarning messages: $$NUMWARN\e[0m"; \
	cat output/vivado.log | grep --color -E "WARNING|CRITICAL WARNING" || true


.PHONY: clean
clean:
	@echo -e "\e[1;33mDeleting Vivado project and log files.\e[0m"
	rm -rf output
