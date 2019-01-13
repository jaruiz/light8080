# Generic makefile to build small FPGA project using Quartus-2 toolchain.
#

#~~~~ Common variables ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# If we run a shell from any of the goals we want it to be Bash.
SHELL := /bin/bash

# Replace with your own install.
QUARTUS_ROOTDIR ?= /opt/altera/12.1/quartus/bin


#~~~~ Project config ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# The project configuration is done entirely in script `build.tcl`.
# (It's only a short list of source and constraint files along with
# some target parameters.)

# All we need to set up here is the root dir to be passed to the build script.
PROJECT_ROOT = $(realpath ../..)


#~~~~ Goals ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.PHONY: help
help:
	@echo 'Build light8080 demo core for DE1 board using Quartus-2 toolchain.'
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


# All output goes into this directory.
output:
	mkdir -p output


# One of the flow tools (`TimeQuest Timing Analyzer`) needs the constraints file
# to have the same name as the project, even if we explicitly supply the name.
# We just make two copies of the constraints into the build directory.
copy-constraints:
	cp constraints.sdc output
	cp constraints.sdc output/de1_demo.sdc


# Build bitstream.
.PHONY: build
build: output copy-constraints
	@echo -e "\e[1;33mRunning Quartus-2 Synth+Impl flow.\e[0m"
	cd output; \
	$(QUARTUS_ROOTDIR)/quartus_sh -t ../build.tcl $(PROJECT_ROOT)


# Build bitstream and display a summary of error and bad warning messages.
.PHONY: all
all: build quickreport-critical


# Display a quick summary of errors and warnings by parsing log files.
.PHONY: quickreport
quickreport:
	@NUMERR=$(cat output/*.*.rpt | grep -E "^\s*Error" | wc -l); \
	echo -e "\e[1;36mError messages:   $$NUMERR\e[0m"; \
	cat output/*.*.rpt | grep --color -E "^\s*Error" || true
	@NUMWARN=$(cat output/*.*.rpt | grep -E "^\s*Warning|^\s*Critical Warning" | wc -l); \
	echo -e "\e[1;36mWarning messages: $$NUMWARN\e[0m"; \
	cat output/*.*.rpt | grep --color -E "^\s*Warning|^\s*Critical Warning" || true

.PHONY: quickreport-critical
quickreport-critical:
	@NUMERR=$(cat output/*.*.rpt | grep -E "^\s*Error" | wc -l); \
	echo -e "\e[1;36mError messages:   $$NUMERR\e[0m"; \
	cat output/*.*.rpt | grep --color -E "^\s*Error" || true
	@NUMWARN=$(cat output/*.*.rpt | grep -E "^\s*Critical Warning" | wc -l); \
	echo -e "\e[1;36mWarning messages: $$NUMWARN\e[0m"; \
	cat output/*.*.rpt | grep --color -E "^\s*Critical Warning" || true

.PHONY: clean
clean:
	@echo -e "\e[1;33mDeleting Quartus-2 project and log files.\e[0m"
	rm -rf output
