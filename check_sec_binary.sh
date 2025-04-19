#!/bin/bash

# Script to verify correct byte sequences in both primary and secondary
# binaries to ensure the beginning of the secondary processor's binary
# has is correctly executable.

# Usage: 
#   ./check_sec_binary.sh secondary <binary_file>
#   ./check_sec_binary.sh primary <binary_file> [offset_hex]

# Copyright (c) 2025 Piers Finlayson <piers@piers.rocks>
#
# Licensed under the MIT License.  See [LICENSE] for details.

# $4C $03 $05 $D8 $78 (JMP $0503, CLD, SEI)
#
# Checks that the code is correctly located from $0500, and will immediately
# JMP to the start of the control: routine.
EXPECTED_HEX="4c0305d878"  

function show_usage {
    echo "Usage:"
    echo "  $0 secondary <binary_file>              # Check bytes at start of file"
    echo "  $0 primary <binary_file> [offset_hex]   # Check bytes at specified offset (default: 0F00)"
    exit 1
}

# Check arguments
if [ $# -lt 2 ]; then
    show_usage
fi

CHECK_TYPE=$1
BINARY=$2
OFFSET_HEX="0F00"  # Default offset for primary

# Handle offset argument for primary check
if [ "$CHECK_TYPE" = "primary" ] && [ $# -ge 3 ]; then
    OFFSET_HEX=$3
fi

# Check if file exists
if [ ! -f "$BINARY" ]; then
    echo "Error: File '$BINARY' not found"
    exit 1
fi

# Perform the check based on check type
if [ "$CHECK_TYPE" = "secondary" ]; then
    # Extract first 5 bytes and convert to hex
    ACTUAL_HEX=$(head -c 5 "$BINARY" | xxd -p | tr -d '\n')
    LOCATION="start"
    
elif [ "$CHECK_TYPE" = "primary" ]; then
    # Convert hex offset to decimal
    OFFSET_DEC=$((16#$OFFSET_HEX))
    
    # Extract 5 bytes from specified offset and convert to hex
    ACTUAL_HEX=$(dd if="$BINARY" bs=1 skip=$OFFSET_DEC count=5 2>/dev/null | xxd -p | tr -d '\n')
    LOCATION="offset $OFFSET_HEX"
    
else
    echo "Error: Invalid check type '$CHECK_TYPE'"
    show_usage
fi

# Compare actual bytes with expected bytes
if [ "$ACTUAL_HEX" = "$EXPECTED_HEX" ]; then
    echo "    PASS: Binary has the correct bytes at $LOCATION."
    echo "      $ACTUAL_HEX"
    exit 0
else
    echo "    FAIL: Binary does not have the correct bytes at $LOCATION."
    echo "      Expected: $EXPECTED_HEX"
    echo "      Actual:   $ACTUAL_HEX"
    exit 1
fi
