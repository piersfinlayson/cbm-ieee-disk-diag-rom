# Makefile for the Diagnostics ROM.

# Copyright (c) 2025 Piers Finlayson <piers@piers.rocks>
#
# Licensed under the MIT License.  See [LICENSE] for details.

# Build directories
BUILD_DIR = build
CONFIG_DIR = config
SRC_DIR = src

# Common compiler options
CA65_OPTS = -W1 -I .
CA65_OPTS_PRI = $(CA65_OPTS) -D PRIMARY_CPU=1
CA65_OPTS_SEC = $(CA65_OPTS) -D SECONDARY_CPU=1

# Primary CPU source files
PRI_SRC_DIR = $(SRC_DIR)/primary
PRI_SRCS = header.s data.s string.s secondary.s
PRI_MAIN = main.s
PRI_OBJS = $(patsubst %.s,$(BUILD_DIR)/pri_%.o,$(PRI_SRCS))

# Primary ROM variants
VARIANTS = f000 d000
ROM_BINS = $(patsubst %,$(BUILD_DIR)/ieee_diag_%.bin,$(VARIANTS))

# Secondary CPU source files
SEC_SRC_DIR = $(SRC_DIR)/secondary
SEC_CONTROL_SRC = $(SEC_SRC_DIR)/control.s
SEC_CONTROL_OBJ = $(BUILD_DIR)/secondary_control.o
SEC_CONTROL_BIN = $(BUILD_DIR)/secondary_control.bin

# Default target
all: $(ROM_BINS)

# Secondary CPU compilation
$(SEC_CONTROL_OBJ): $(SEC_CONTROL_SRC)
	ca65 $(CA65_OPTS_SEC) $< -o $@

$(SEC_CONTROL_BIN): $(SEC_CONTROL_OBJ)
	ld65 -t none -o $@ $(SEC_CONTROL_OBJ)

# Explicit pattern for pri_secondary, to ensure it is built with the secondary CPU bin file
$(BUILD_DIR)/pri_secondary.o: $(PRI_SRC_DIR)/secondary.s $(SEC_CONTROL_BIN)
	ca65 $(CA65_OPTS_PRI) $< -o $@

# Pattern rule for primary CPU components
$(BUILD_DIR)/pri_%.o: $(PRI_SRC_DIR)/%.s
	ca65 $(CA65_OPTS_PRI) $< -o $@

# Primary main.s for each variant
$(BUILD_DIR)/pri_main_%.o: $(PRI_SRC_DIR)/$(PRI_MAIN) $(SEC_CONTROL_BIN)
	ca65 $(CA65_OPTS_PRI) $< -o $@ -D $(shell echo $* | tr a-z A-Z)_BUILD

# Linking rules for each variant
$(BUILD_DIR)/ieee_diag_%.bin: $(BUILD_DIR)/pri_main_%.o $(PRI_OBJS) $(CONFIG_DIR)/primary_%.cfg
	ld65 -C $(CONFIG_DIR)/primary_$*.cfg -o $@ $< $(PRI_OBJS)

clean:
	rm -f $(BUILD_DIR)/*

# Include phony targets
.PHONY: all clean

# Mark object files as precious to prevent automatic deletion
.PRECIOUS: $(BUILD_DIR)/pri_main_%.o $(BUILD_DIR)/pri_%.o

# Individual variant targets for convenience
f000: $(BUILD_DIR)/ieee_diag_f000.bin
d000: $(BUILD_DIR)/ieee_diag_d000.bin