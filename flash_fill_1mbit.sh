#!/bin/bash

# Fills a 1Mbit (128KB) file with copies of the F000 image.  Useful for
# flashing the F000 image to a 1Mbit flash chip.

# Input and output files
INPUT_FILE="diag_x040_f000.bin"
OUTPUT_FILE="f000_1mbit.bin"

# Size of 1Mbit in bytes (1,048,576 bits = 131,072 bytes)
MBIT_SIZE=$((1024 * 1024 / 8))

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file $INPUT_FILE not found."
    exit 1
fi

# Get the size of the input file in bytes
INPUT_SIZE=$(stat -c %s "$INPUT_FILE")

echo "Input file size: $INPUT_SIZE bytes"
echo "Target size (1Mbit): $MBIT_SIZE bytes"

# Check if input file is larger than the target
if [ $INPUT_SIZE -gt $MBIT_SIZE ]; then
    echo "Error: Input file is larger than the target 1Mbit size."
    exit 1
fi

# Calculate how many copies we need
COPIES=$((MBIT_SIZE / INPUT_SIZE))
REMAINDER=$((MBIT_SIZE % INPUT_SIZE))

echo "Creating $OUTPUT_FILE with $COPIES complete copies and $REMAINDER additional bytes..."

# Create/truncate output file
> "$OUTPUT_FILE"

# Add complete copies
for ((i=0; i<COPIES; i++)); do
    cat "$INPUT_FILE" >> "$OUTPUT_FILE"
done

# Add remainder if needed
if [ $REMAINDER -gt 0 ]; then
    dd if="$INPUT_FILE" of="$OUTPUT_FILE" bs=1 count=$REMAINDER oflag=append conv=notrunc status=none
fi

# Verify final size
FINAL_SIZE=$(stat -c %s "$OUTPUT_FILE")
echo "Done. Created $OUTPUT_FILE with size $FINAL_SIZE bytes"