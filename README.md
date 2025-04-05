# ieee-diag-rom

🛠️ A diagnostic ROM for Commodore 2040, 3040, and 4040 disk drives using the IEEE-488 interface.

## Overview

This project provides a simple diagnostics ROM for early Commodore disk drives (2040, 3040, and 4040). It performs basic memory tests and provides visual feedback through the drive's LEDs.

## Features

- ✅ Zero page memory testing
- 💡 Visual status indication via drive LEDs
- 🧪 Simple diagnostic functionality
- 📦 Compatible with multiple disk drive models
- 🔄 Can be installed at either $D000 or $F000 ROM locations

## LED Indicators

The ROM uses the drive's LEDs to indicate status:

| LED Pattern | Meaning |
|-------------|---------|
| All LEDs solid on | (*) 6502 is faulty, this ROM is corrupted, or UE1 6532 is faulty |
| ERR LED solid on | Testing zero page |
| ERR LED off, DR0/DR1 flashing | Normal operation - Zero page test passed |
| ERR LED and drive 0 LEDs flashing together | Zero page test failed in UC1 6532 |
| ERR LED and drive 1 LEDs flashing together | (+) Zero page test failed in UE1 6532 |

(*) There are other issues that can cause all LEDs to be stuck on.  First try replacing the 6502 and the UE1 6532.  If the problem remains, you likely have some issue with the main RESET circuit, or corruption on the 6502 address bus, or shared data bus, that is preventing proper communication between components.

(+) As UE1 is used to drive LEDs, this error may not be signaled via LEDs.

## Building From Source

### Requirements

- `ca65` assembler (part of the cc65 suite)
- `make` (for building using the Makefile)

Install them both on linux like so:

```bash
sudo apt-get install cc65 make
```

### Compilation

```bash
# Compile for both possible ROM locations
make

# Or manually:
ca65 diag_x040.s -o diag_x040.o
ld65 -C diag_x040_f000.cfg -o diag_x040_f000.bin diag_x040.o
ld65 -C diag_x040_d000.cfg -o diag_x040_d000.bin diag_x040.o
```

This produces two ROM images:
- `diag_x040_f000.bin` - For installation at $F000
- `diag_x040_d000.bin` - For installation at $D000

## Installation

1. 🔥 Burn the appropriate ROM image to an EPROM
   - Use `diag_x040_f000.bin` for installation at $F000
   - Use `diag_x040_d000.bin` for installation at $D000

2. 🔌 Install the EPROM in the appropriate socket in your disk drive
   - $F000 - UH1
   - $D000 - UJ1

If you want to fill a larger EEPROM with this ROM image, see [`flash_fill_1mbit.sh`](flash_fill_1mbit.sh).  You may need to modify the script for your EEPROM size.

## Usage

After installing the ROM:

1. Power on the disk drive
2. The diagnostics will run automatically
3. Observe the LED pattern to determine the status - see [LED Indicators](#led-indicators)

To choose which ROM to install:

### $F000 ROM replacement, UH1

If you are unsure whether your upper, $F000, ROM, located at UH1 is functional, replace it with the $F000 version of this diagnostics ROM.

In particular, this is helpful if you have all three LEDs light on your disk drive.  If they remain lit with this ROM you have a non-ROM issue.  If you see other LED patterns with this ROM, then it is likely one of your stock ROMs is faulty.

### $D000 ROM, UJ1

If you believe your $F000 ROM is functional, install the $D000 version of this ROM at UJ1.

Note if your drive has a $D000 ROM already installed it is likely your current ROMs don't not support a diagnostic ROM at $D000, so replace your $F000 with the $F000 version of this ROM instead.  This is typical of the 4040, although 2040 and 3040s may have been upgraded to three ROM operation.


## Technical Details

- 💻 Written in 6502 assembly language
- 🧠 Tests the zero page memory ($0000-$00FF), provided by UC1 ($0000-$007F) and UE1 ($0080-$00FF)
- ⚙️ Uses RIOT UE1 chip for lighting LED indicators
- 🔍 Provides visual indication of memory test results

## License

Licensed under the MIT License.  See [LICENSE](LICENSE).

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
