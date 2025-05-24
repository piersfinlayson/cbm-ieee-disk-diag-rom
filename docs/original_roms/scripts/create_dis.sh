#!/bin/bash

ROM_NAME=$1

if [ -z "$ROM_NAME" ]; then
    echo "Usage: $0 <rom_name>"
    exit 1
fi

ROM_INFO_FILE="info/${ROM_NAME}.da65"
ROM_EXTRA_FILE="info/${ROM_NAME}_extra.a65"
ROM_INPUT_FILE="roms/${ROM_NAME}.bin"
ROM_OUTPUT_FILE="${ROM_NAME}.a65"

da65 -i ${ROM_INFO_FILE} -o /tmp/${ROM_OUTPUT_FILE} ${ROM_INPUT_FILE}
cat ${ROM_EXTRA_FILE} > ${ROM_OUTPUT_FILE}
echo "" >> ${ROM_OUTPUT_FILE}
cat /tmp/${ROM_OUTPUT_FILE} >> ${ROM_OUTPUT_FILE}
