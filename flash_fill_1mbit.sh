#!/bin/bash
# Fills a 1Mbit (128KB) file with copies of the F000 or D000 image.
# Usage: ./script_name.sh [f000|d000]
# Default is f000 if no argument provided

# Function to display help information
show_help() {
    echo "Usage: $0 [OPTION]"
    echo "Fills a 1Mbit (128KB) file with copies of the F000 or D000 image."
    echo
    echo "Options:"
    echo "  f000        Use F000 image (default if no option specified)"
    echo "  d000        Use D000 image"
    echo "  -h, -?, --help  Display this help and exit"
    echo
    echo "Example:"
    echo "  $0          # Uses F000 image by default"
    echo "  $0 d000     # Uses D000 image"
    echo "  $0 --help   # Displays this help message"
    exit 0
}

# Process command line argument
IMAGE_TYPE="f000"  # Default value
if [ $# -gt 0 ]; then
    case "$1" in
        "f000"|"d000")
            IMAGE_TYPE="$1"
            ;;
        "-h"|"-?"|"--help")
            show_help
            ;;
        *)
            echo "Error: Unrecognized option '$1'"
            echo "Use '$0 --help' for more information."
            exit 1
            ;;
    esac
fi

# Input and output files based on the image type
INPUT_FILE="diag_x040_${IMAGE_TYPE}.bin"
OUTPUT_FILE="${IMAGE_TYPE}_1mbit.bin"

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
