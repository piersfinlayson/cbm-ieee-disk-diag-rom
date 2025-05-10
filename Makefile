# Makefile for the Diagnostics ROM.

# Copyright (c) 2025 Piers Finlayson <piers@piers.rocks>
#
# Licensed under the MIT License.  See [LICENSE] for details.

# Drive families
XX40_PREFIX = xx40
XX50_PREFIX = 8x50

# ROM variants for each family
XX40_VARIANTS = f000 d000
XX50_VARIANTS = e000

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
PRI_SRCS = data.s string.s secondary.s
PRI_MAIN = main.s
PRI_HEADER = header.s 
PRI_OBJS = $(patsubst %.s,$(BUILD_DIR)/pri_%.o,$(PRI_SRCS))

# Primary ROM variants
VARIANTS = $(XX40_VARIANTS) $(XX50_VARIANTS)

# Output binary files
XX40_ROM_BINS = $(patsubst %,$(BUILD_DIR)/$(XX40_PREFIX)_ieee_diag_%.bin,$(XX40_VARIANTS))
XX50_ROM_BINS = $(patsubst %,$(BUILD_DIR)/$(XX50_PREFIX)_ieee_diag_%.bin,$(XX50_VARIANTS))
ROM_BINS = $(XX40_ROM_BINS) $(XX50_ROM_BINS)

# Secondary CPU source files
SEC_SRC_DIR = $(SRC_DIR)/secondary
SEC_CONTROL_SRC = $(SEC_SRC_DIR)/control.s
SEC_CONTROL_OBJ = $(BUILD_DIR)/secondary_control.o
SEC_CONTROL_BIN = $(BUILD_DIR)/secondary_control.bin
SEC_CONTROL_CFG = $(CONFIG_DIR)/secondary.cfg

# Check timestamp files
SEC_CHECK = $(CHECK_DIR)/secondary.checked
XX40_F000_CHECK = $(CHECK_DIR)/$(XX40_PREFIX)_f000.checked
XX40_D000_CHECK = $(CHECK_DIR)/$(XX40_PREFIX)_d000.checked
XX50_E000_CHECK = $(CHECK_DIR)/$(XX50_PREFIX)_e000.checked

# PET Support program source
PET_SUPPORT_SRC = $(SRC_DIR)/support/pet/support.bas
SUPPORT_BUILD_DIR = $(BUILD_DIR)/support
PET_SUPPORT_PRG = $(SUPPORT_BUILD_DIR)/ieee-support.prg
PET_SUPPORT_D64 = $(SUPPORT_BUILD_DIR)/ieee-support.d64

# PC Support program source
PC_SUPPORT_SRC_DIR = $(SRC_DIR)/support/pc
PC_SUPPORT_BIN_FILE = pc-support
PC_SUPPORT_BIN_PATH = $(PC_SUPPORT_SRC_DIR)/target/release/$(PC_SUPPORT_BIN_FILE)

# Build scripts
CHECK_SCRIPT = ./check_sec_binary.sh

# Default target
all: build check

build: $(ROM_BINS)

# Ensure check directory exists
$(CHECK_DIR):
	@mkdir -p $(CHECK_DIR)

# Make check depend on check timestamps
check: $(SEC_CHECK) $(XX40_F000_CHECK) $(XX40_D000_CHECK) $(XX50_E000_CHECK)

# Each timestamp depends on its binary
$(XX40_F000_CHECK): $(BUILD_DIR)/$(XX40_PREFIX)_ieee_diag_f000.bin | $(CHECK_DIR)
	@echo "Checking xx40 f000 ROM..."
	@$(CHECK_SCRIPT) primary $< 0D00
	@touch $@

$(XX40_D000_CHECK): $(BUILD_DIR)/$(XX40_PREFIX)_ieee_diag_d000.bin | $(CHECK_DIR)
	@echo "Checking xx40 d000 ROM..."
	@$(CHECK_SCRIPT) primary $< 0D00
	@touch $@

$(XX50_E000_CHECK): $(BUILD_DIR)/$(XX50_PREFIX)_ieee_diag_e000.bin | $(CHECK_DIR)
	@echo "Checking 8x50 e000 ROM..."
	@$(CHECK_SCRIPT) primary $< 1D00
	@touch $@

# Secondary check
$(SEC_CHECK): $(SEC_CONTROL_BIN) | xxd $(CHECK_DIR)
	@echo "Checking secondary control binary..."
	@$(CHECK_SCRIPT) secondary $(SEC_CONTROL_BIN)
	@touch $@

# For convenience
.PHONY: check_xx40
check_xx40: $(XX40_F000_CHECK) $(XX40_D000_CHECK)

.PHONY: check_8x50
check_8x50: $(XX50_E000_CHECK)

xxd:
	@command -v xxd >/dev/null 2>&1 || { echo "ERROR: xxd not found, please install xxd with\n  sudo apt update && sudo apt -y install xxd"; exit 1; }

# Drive family targets
.PHONY: xx40 8x50
xx40: $(XX40_ROM_BINS) check_xx40
8x50: $(XX50_ROM_BINS) check_8x50

# Secondary CPU compilation
$(SEC_CONTROL_OBJ): $(SEC_CONTROL_SRC)
	ca65 $(CA65_OPTS_SEC) $< -o $@

$(SEC_CONTROL_BIN): $(SEC_CONTROL_CFG) $(SEC_CONTROL_OBJ)
	ld65 -C $(SEC_CONTROL_CFG) -o $@ $(SEC_CONTROL_OBJ)

# Explicit pattern for pri_secondary, to ensure it is built with the secondary CPU bin file
$(BUILD_DIR)/pri_secondary.o: $(PRI_SRC_DIR)/secondary.s $(SEC_CONTROL_BIN)
	ca65 $(CA65_OPTS_PRI) $< -o $@

# Pattern rule for other primary CPU components
$(BUILD_DIR)/pri_%.o: $(PRI_SRC_DIR)/%.s
	ca65 $(CA65_OPTS_PRI) $< -o $@

# Rules for xx40 variants
$(BUILD_DIR)/pri_header_f000.o: $(PRI_SRC_DIR)/$(PRI_HEADER)
	ca65 $(CA65_OPTS_PRI) $< -o $@ -D F000_BUILD -D XX40_DRIVE

$(BUILD_DIR)/pri_main_f000.o: $(PRI_SRC_DIR)/$(PRI_MAIN) $(SEC_CONTROL_BIN)
	ca65 $(CA65_OPTS_PRI) $< -o $@ -D F000_BUILD -D XX40_DRIVE

$(BUILD_DIR)/pri_header_d000.o: $(PRI_SRC_DIR)/$(PRI_HEADER)
	ca65 $(CA65_OPTS_PRI) $< -o $@ -D D000_BUILD -D XX40_DRIVE

$(BUILD_DIR)/pri_main_d000.o: $(PRI_SRC_DIR)/$(PRI_MAIN) $(SEC_CONTROL_BIN)
	ca65 $(CA65_OPTS_PRI) $< -o $@ -D D000_BUILD -D XX40_DRIVE

# Rules for 8x50 variant
$(BUILD_DIR)/pri_header_e000.o: $(PRI_SRC_DIR)/$(PRI_HEADER)
	ca65 $(CA65_OPTS_PRI) $< -o $@ -D E000_BUILD -D XX50_DRIVE

$(BUILD_DIR)/pri_main_e000.o: $(PRI_SRC_DIR)/$(PRI_MAIN) $(SEC_CONTROL_BIN)
	ca65 $(CA65_OPTS_PRI) $< -o $@ -D E000_BUILD -D XX50_DRIVE

# Linking rules for each variant
$(BUILD_DIR)/$(XX40_PREFIX)_ieee_diag_f000.bin: $(BUILD_DIR)/pri_main_f000.o $(BUILD_DIR)/pri_header_f000.o $(PRI_OBJS) $(CONFIG_DIR)/primary_xx40_f000.cfg
	ld65 -C $(CONFIG_DIR)/primary_xx40_f000.cfg -o $@ $(BUILD_DIR)/pri_main_f000.o $(BUILD_DIR)/pri_header_f000.o $(PRI_OBJS)

$(BUILD_DIR)/$(XX40_PREFIX)_ieee_diag_d000.bin: $(BUILD_DIR)/pri_main_d000.o $(BUILD_DIR)/pri_header_d000.o $(PRI_OBJS) $(CONFIG_DIR)/primary_xx40_d000.cfg
	ld65 -C $(CONFIG_DIR)/primary_xx40_d000.cfg -o $@ $(BUILD_DIR)/pri_main_d000.o $(BUILD_DIR)/pri_header_d000.o $(PRI_OBJS)

$(BUILD_DIR)/$(XX50_PREFIX)_ieee_diag_e000.bin: $(BUILD_DIR)/pri_main_e000.o $(BUILD_DIR)/pri_header_e000.o $(PRI_OBJS) $(CONFIG_DIR)/primary_8x50_e000.cfg
	ld65 -C $(CONFIG_DIR)/primary_8x50_e000.cfg -o $@ $(BUILD_DIR)/pri_main_e000.o $(BUILD_DIR)/pri_header_e000.o $(PRI_OBJS)

support: pet_support pc_support
	@echo "Support programs built:"
	@find $(SUPPORT_BUILD_DIR) -type f | xargs ls -ltr

# Create .prg and .d64 files for the support program
pet_support: check_vice support_build
	@petcat -w2 -l 401 -o $(PET_SUPPORT_PRG) -- $(PET_SUPPORT_SRC)
	@c1541 -format "piers.rocks,01" d64 $(PET_SUPPORT_D64) -write $(PET_SUPPORT_PRG) ieee-support > /dev/null
	@echo "Created:"
	@find $(SUPPORT_BUILD_DIR) -type f | xargs ls -ltr 

clean_pet_support:
	@rm -f $(PET_SUPPORT_PRG) $(PET_SUPPORT_D64)
	@rm -fr $(SUPPORT_BUILD_DIR)/*

clean_pc_support:
	@cd $(PC_SUPPORT_SRC_DIR) && cargo clean
	@rm -fr $(SUPPORT_BUILD_DIR)/$(PC_SUPPORT_BIN_FILE)

pc_support: check_rust support_build
	@cd $(PC_SUPPORT_SRC_DIR) && cargo build --release
	@cp $(PC_SUPPORT_BIN_PATH) $(SUPPORT_BUILD_DIR)/

support_build:
	@mkdir -p $(SUPPORT_BUILD_DIR)

clean_support: clean_pet_support clean_pc_support

clean: clean_support
	@rm -fr $(BUILD_DIR)/*

check_vice:
	@command -v petcat >/dev/null 2>&1 || { echo "ERROR: petcat not found, please install VICE emulator with\n  sudo apt update && sudo apt -y install vice"; exit 1; }
	@command -v c1541 >/dev/null 2>&1 || { echo "ERROR: c1541 not found, please install VICE emulator with\n  sudo apt update && sudo apt -y install vice"; exit 1; }

check_rust:
	@command -v cargo >/dev/null 2>&1 || { echo "ERROR: cargo not found, please install Rust toolchain with\n  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"; exit 1; }

# Include phony targets
.PHONY: all clean build support pet_support clean_pc_support pc_support clean_pet_support clean_support support_build check_xx40 check_8x50 check_secondary xx40 8x50 check_rust check_vice

# Mark object files as precious to prevent automatic deletion
.PRECIOUS: $(BUILD_DIR)/pri_main_%.o $(BUILD_DIR)/pri_header_%.o $(BUILD_DIR)/pri_%.o

# Individual variant targets
xx40_f000: $(BUILD_DIR)/$(XX40_PREFIX)_ieee_diag_f000.bin $(XX40_F000_CHECK)
xx40_d000: $(BUILD_DIR)/$(XX40_PREFIX)_ieee_diag_d000.bin $(XX40_D000_CHECK)
8x50_e000: $(BUILD_DIR)/$(XX50_PREFIX)_ieee_diag_e000.bin $(XX50_E000_CHECK)