# ==============================================================================
# Installation of tools required to build the test SW in project light8080.
# This makefile will pull & build whatever is required to build our test SW:
#
# ASL assembler (https://github.com/begoon/asl.git)
#
# This makefile can be considered as sort of 'executable instructions' for you 
# to reproduce my setup so you can use the light8080 makefiles unmodified if
# you don't want to tinker with them.
# You'll need git, gcc, etc. and resolving those dependencies is up to you.
#
# TARGETS:
# =========
# install    - Install & build whatever.
# uninstall  - Remove anything that was installed, leave dir in reset state.
#
# ==============================================================================

.PHONY: clean install uninstall pull_assembler install_assembler \
				check_dependencies

# Github path for ASL assembler project.
ASL_REPO_PATH = https://github.com/begoon/asl.git
# Will be nonempty if git command is available.
GIT_INSTALLED := $(shell command -v git 2> /dev/null)


check_dependencies:
ifndef GIT_INSTALLED
	$(error "git is not available, please install it.")
endif


asl/install/bin/asl: install_assembler
	@echo -e "\e[1;33mOk, asl assembler installed at $(CURDIR)/asl/install/bin\e[0m"

pull_assembler:
ifeq ("$(wildcard asl/INSTALL)","")
	@echo -e "\e[1;33mPulling asl assembler sources from Github...\e[0m"
	git clone $(ASL_REPO_PATH)
endif

install_assembler: pull_assembler
	@echo -e "\e[1;33mBuilding and installing asl assembler...\e[0m"
	@cp Makefile.asl.def asl/Makefile.def 
	make -C asl
	make -C asl install

install: check_dependencies asl/install/bin/asl

all: install

clean:
	@make -C asl clean

uninstall: clean
	rm -rf asl
