.ONESHELL:
SHELL := /bin/bash

ROOT := $(shell pwd)
CONTAINER_DIR := $(ROOT)/containerfiles
SCRIPT_BUILD := $(CONTAINER_DIR)/build_container.sh

TOOL ?= exampletool
VER  ?= 0.1.0
CTX_DIR := $(CONTAINER_DIR)/$(TOOL)/$(VER)
DEF     := $(CTX_DIR)/$(TOOL)_$(VER).def

print-vars:
	@echo ROOT=$(ROOT)
	@echo CONTAINER_DIR=$(CONTAINER_DIR)
	@echo SCRIPT_BUILD=$(SCRIPT_BUILD)

TMPDIR ?= /tmp
FAKEROOT_FLAG :=

# Check if /tmp is writable
ifeq ($(shell test -w /tmp && echo yes),yes)
    $(info /tmp is writable. Building normally without fakeroot.)
else
    $(info /tmp is not writable. Using $$(HOME)/tmp and enabling fakeroot.)
    TMPDIR := $(HOME)/tmp
    FAKEROOT_FLAG := --fakeroot
endif

.PHONY: new sif tree

new:
	mkdir -p "$(CTX_DIR)"
	if [ ! -f "$(DEF)" ]; then \
		echo "Creating $(DEF)"; \
		cat > "$(DEF)" << 'EOF' 
		Bootstrap: docker
		From: debian:bookworm-slim

		%post
			apt-get update && apt-get install -y wget bzip2 && rm -rf /var/lib/apt/lists/*

			# install Miniforge3
			wget --no-check-certificate https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
			bash Miniforge3-Linux-x86_64.sh -b -p /opt/miniforge3
			rm Miniforge3-Linux-x86_64.sh
			export PATH=/opt/miniforge3/bin:$$PATH

			# install $(TOOL)
			conda install -y -c conda-forge -c bioconda python=3.10.1 $(TOOL)==$(VER)
			conda clean -a -y

		%environment
			export PATH=/opt/miniforge3/bin:$$PATH

		%runscript
			exec $(TOOL) "$$@"
		EOF
			else \
				echo "$(DEF) already exists"; \
			fi
			echo "Scaffold ready at $(CTX_DIR)"

sif:
	@chmod +x "$(SCRIPT_BUILD)"
	@"$(SCRIPT_BUILD)" \
	  $(if $(filter 1,$(FORCE)),--force,) \
	  $(foreach A,$(APPTAINER_ARGS),--apptainer '$(A)') \
	  "$(TOOL)/$(VER)"
	@echo "Checking that $(TOOL) runs..."
	@echo "Using SIF: $(CONTAINER_DIR)/$(TOOL)/$(VER)/$(TOOL)_$(VER).sif"
	@singularity exec "$(CONTAINER_DIR)/$(TOOL)/$(VER)/$(TOOL)_$(VER).sif" $(TOOL) --help || \
	 (echo "ERROR: $(TOOL) did not run inside container" && exit 1)

tree:
	find "$(CONTAINER_DIR)" -maxdepth 3 -type d 2>/dev/null | sort
