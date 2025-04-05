# ieee-diag-rom

🛠️ A diagnostic ROM for Commodore 2040, 3040, and 4040 disk drives using the IEEE-488 interface.

## Overview

This project provides a diagnostics ROM for early Commodore disk drives (2040, 3040, and 4040). It performs basic memory tests and provides visual feedback through the drive's LEDs.

## Features

- ✅ Zero page and static RAM testing
- 💡 Visual status indication and failed components via drive LEDs
- 🧪 Simple diagnostic functionality
- 📦 Compatible with multiple disk drive models
- 🔄 Can be installed at either $D000 or $F000 ROM locations

## LED Indicators

The ROM uses the drive's LEDs to indicate status:

| LED Pattern | Meaning |
|-------------|---------|
| All LEDs solid on | Diagnostics ROM is unable to run (*) |
| All LEDs blink briefly | Diags ROM has completed a test and is moving onto the next |
| ERR LED solid on | Testing zero page |
| DR0, DR1, ERR leds strobing | Testing static RAM |
| ERR LED off, DR0/DR1 flashing | Al tests passed (**) |
| ERR LED and drive 0 LEDs flashing together | Zero page test failed in UC1 6532 |
| ERR LED and drive 1 LEDs flashing together | Zero page test failed in UE1 6532 (+) |
| ERR LED solid, DR1 light flashing, all lights go off, then restarts | Static RAM check failed (++) |

(*) Most likely 6502 is faulty, this ROM is corrupted, or UE1 6532 is faulty.  First try replacing the 6502 and the UE1 6532.  If the problem remains, you probably have some issue with either
- the main RESET circuit
- corruption on the 6502 address bus, or shared data bus
- a failed 74LS157 (UC3/UD4/UE4/UF4)
- something else that is preventing proper communication between components, on the data or (6502) address buses.

(**) Number of flashes before pause indicates the hardware configured device ID of this drive.

(+) As UE1 is used to drive LEDs, this error may not be signaled via LEDs.

(++) Number of flashes before pause indicates which static RAM chip has failed:
- 1 flash = UC4 or UC5 (or one of the 74L157s may have failed)
- 2 flashes = UD4 or UD5
- 3 flashes = UE4 or UE5
- 4 flashes = UF4 or UF5

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

In particular, this is helpful if you have all three LEDs light on your disk drive when booting with the original ROM.  If they remain lit with this ROM you have a non-ROM issue preventing the ROM code from being executed.  If you see other LED patterns with this ROM, then it one of your stock ROMs is probably faulty.

### $D000 ROM, UJ1

If you believe your $F000 ROM is functional (the three LEDs go out after powering on), install the $D000 version of this ROM at location UJ1.

If your drive has a $D000 ROM already installed it is likely your current ROMs don't not support a diagnostic ROM at $D000, so replace your $F000 with the $F000 version of this ROM instead.  This is typical of the 4040, although 2040 and 3040s may have been upgraded to a three ROM configuration.

## Technical Details

- 💻 Written in 6502 assembly language
- 🧠 Tests the zero page memory ($0000-$00FF), provided by UC1 ($0000-$007F) and UE1 ($0080-$00FF)
- 🧩 Tests the static RAM chips UC4/5 ($1000-$13FF), UD4/5 ($2000-$23FF), UE4/5 ($3000-$33FF), UF4/5 ($4000-$43FF).
- ⚙️ Uses RIOT UE1 chip for lighting LED indicators
- 🔍 Provides visual indication of failed memory test, allowing you to indentify and replace the failed chip
- 💡 Reads the device ID from UE1 PB0-PB2 and indicates it by flashing the LEDs

## License

Licensed under the MIT License.  See [LICENSE](LICENSE).

## Contributing

Contributions are welcome.  Please feel free to submit a Pull Request.
