# Makefile for the Diagnostics ROM.

# Copyright (c) 2025 Piers Finlayson <piers@piers.rocks>
#
# Licensed under the MIT License.  See [LICENSE] for details.

# Build directories
BUILD_DIR = build
CONFIG_DIR = config
SRC_DIR = src
CHECK_DIR = $(BUILD_DIR)/checks

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
SEC_CONTROL_CFG = $(CONFIG_DIR)/secondary.cfg

# Check timestamp files
SEC_CHECK = $(CHECK_DIR)/secondary.checked
PRI_F000_CHECK = $(CHECK_DIR)/primary_f000.checked
PRI_D000_CHECK = $(CHECK_DIR)/primary_d000.checked

# Support program source
SUPPORT_SRC = $(SRC_DIR)/support/support.bas
SUPPORT_BUILD_DIR = $(BUILD_DIR)/support
SUPPORT_PRG = $(SUPPORT_BUILD_DIR)/ieee-support.prg
SUPPORT_D64 = $(SUPPORT_BUILD_DIR)/ieee-support.d64

# Build scripts
CHECK_SCRIPT = ./check_sec_binary.sh

# Default target
all: build check

build: $(ROM_BINS)

# Ensure check directory exists
$(CHECK_DIR):
	@mkdir -p $(CHECK_DIR)

# Make check depend on check timestamps
check: $(SEC_CHECK) $(PRI_F000_CHECK) $(PRI_D000_CHECK)

# Each timestamp depends on its binary
$(SEC_CHECK): $(SEC_CONTROL_BIN) | $(CHECK_DIR)
	@echo "Checking secondary control binary..."
	@$(CHECK_SCRIPT) secondary $(SEC_CONTROL_BIN)
	@touch $@

$(PRI_F000_CHECK): $(BUILD_DIR)/ieee_diag_f000.bin | $(CHECK_DIR)
	@echo "Checking primary f000 ROM..."
	@$(CHECK_SCRIPT) primary $< 0D00
	@touch $@

$(PRI_D000_CHECK): $(BUILD_DIR)/ieee_diag_d000.bin | $(CHECK_DIR)
	@echo "Checking primary d000 ROM..."
	@$(CHECK_SCRIPT) primary $< 0D00
	@touch $@

# For convenience
.PHONY: check_primary
check_primary: $(PRI_F000_CHECK) $(PRI_D000_CHECK)

.PHONY: check_secondary
check_secondary: $(SEC_CHECK)

# Secondary CPU compilation
$(SEC_CONTROL_OBJ): $(SEC_CONTROL_SRC)
	ca65 $(CA65_OPTS_SEC) $< -o $@

$(SEC_CONTROL_BIN): $(SEC_CONTROL_CFG) $(SEC_CONTROL_OBJ)
	ld65 -C $(SEC_CONTROL_CFG) -o $@ $(SEC_CONTROL_OBJ)

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

# Create .prg and .d64 files for the support program
support:
	@mkdir -p $(SUPPORT_BUILD_DIR)
	@petcat -w2 -l 401 -o $(SUPPORT_PRG) -- $(SUPPORT_SRC)
	@c1541 -format "piers.rocks,01" d64 $(SUPPORT_D64) -write $(SUPPORT_PRG) ieee-support > /dev/null
	@echo "Created:"
	@find $(SUPPORT_BUILD_DIR) -type f | xargs ls -ltr 

clean_support:
	@rm -f $(SUPPORT_PRG) $(SUPPORT_D64)
	@rm -fr $(SUPPORT_BUILD_DIR)

clean: clean_support
	@rm -fr $(BUILD_DIR)/*

# Include phony targets
.PHONY: all clean build support clean_support

# Mark object files as precious to prevent automatic deletion
.PRECIOUS: $(BUILD_DIR)/pri_main_%.o $(BUILD_DIR)/pri_%.o

# Individual variant targets
f000: $(BUILD_DIR)/ieee_diag_f000.bin $(PRI_F000_CHECK)
d000: $(BUILD_DIR)/ieee_diag_d000.bin $(PRI_D000_CHECK)