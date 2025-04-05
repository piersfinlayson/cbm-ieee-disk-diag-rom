# 💾cbm-ieee-disk-diag-rom

🛠️ A diagnostic ROM for Commodore 2040, 3040, and 4040 disk drives which use the IEEE-488 interface.

## 📖Overview

This project provides a diagnostics ROM for early Commodore disk drives (2040, 3040, and 4040). It performs basic memory tests and provides visual feedback through the drive's LEDs.

## ✨Features

- ✅ Zero page and static RAM testing
- 💡 Visual status indication and failed components via drive LEDs
- 🧪 Simple diagnostic functionality
- 📦 Compatible with multiple disk drive models
- 🔄 Can be installed at either $F000 or $D000 (DOS 1 only) ROM locations
- 🔍 Detects and reports the configured hardware device ID (8, 9, etc)

## 🔨Building From Source

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

1. 🔥 Burn the appropriate ROM image to an EPROM/EEPROM:
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

In particular, this is helpful if you have all three LEDs light on your disk drive when booting with the original ROM.  If they remain lit with this ROM (assuming you correctly built, flashed and installed it) you have a non-ROM issue preventing the ROM code from being executed.  If you had all three LEDs solidly lit with the stock ROM and see other LED patterns with this ROM, then one of your stock ROMs is probably faulty.

For a first test, you are best off removing the $E000 ROM (UL1) before running this diagnostics ROM at $F000, in case $E000/UL1 is faulty and causes address or data bus issues. 

### $D000 ROM, UJ1

If you believe your stock $F000 and $E000 ROMs are functional (the three LEDs go out after powering on), and your UJ1 socket is free, you can install the $D000 version of this ROM at location UJ1.  You need both $F000 and $E000 to boot far enough to load the ROM installed at $D000.  If you suspect either ROM of being faulty, start with the $F000 replacement method, above.

If your drive has a $D000 ROM already installed then your current ROMs likely don't not support a diagnostic ROM at $D000, so replace your $F000 with the $F000 version of this ROM instead.  This is typical of the 4040, although 2040 and 3040s may have been upgraded to a three ROM configuration.

DOS 1 firmware version 901468/06/07 come as a 2 ROM set and support at $D000 UJ1 diagnostics ROM being installed. 

DOS 2 firmware versions 901468-11/12/13 and 14/15/16 come as a 3 ROM set.

When running as the $D000 ROM the zero page test is skipped - as the stock ROM has already done this test.

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
- a failed 74LS157 (UC3/UD3/UE3/UF3)
- something else that is preventing proper communication between components, on the data or (6502) address buses.

(**) Number of flashes before pause indicates the hardware configured device ID of this drive.

(+) As UE1 is used to drive LEDs, this error may not be signaled via LEDs.

(++) Number of flashes before pause indicates which static RAM chip has failed:
- 1 flash = UC4 or UC5 (or one of the 74L157s UC3/UD3/UE3/UF3 may have failed)
- 2 flashes = UD4 or UD5
- 3 flashes = UE4 or UE5
- 4 flashes = UF4 or UF5

## Technical Details

- 💻 Written in 6502 assembly language
- 🧠 Tests the zero page memory ($0000-$00FF), provided by UC1 ($0000-$007F) and UE1 ($0080-$00FF)
- 🧩 Tests the static RAM chips UC4/5 ($1000-$13FF), UD4/5 ($2000-$23FF), UE4/5 ($3000-$33FF), UF4/5 ($4000-$43FF).
- ⚙️ Uses 6532 (RIOT) UE1 chip for lighting LED indicators
- 🔍 Provides visual indication of failed memory test, allowing you to indentify and replace the failed chip
- 💡 Reads the device ID from UE1 PB0-PB2 and indicates it by flashing the LEDs that number of times

### 🔎 Fun Fact 1 - Official Commodore Diagnostic ROM 

It appears, from the fact that the stock DOS 1 ROMs support a $D000 diagnostics ROM, that there was an official Commodore diagnostics ROM which could be installed alongside the main DOS 1 ROMs to aid with problem diagnosis.  I've not been able to find a copy of that ROM, hence building my own to help me fix 2040, 3040 and 4040 drives.

### 📚 Fun Fact 2 - Upgrading 2040 to DOS 2

In "Programming the PET/CBM", author Raeto states that the 2040 is difficult to upgrade as the PCB needs to be changed - the implication being to upgrade the ROMs.  I've not seen evidence of this - my 2040 and 3040 DOS 1 drives are very similar (the only hardware difference appears to be the addition of a double NOT gate on some of the clock lines presumably to clear up the signal), so I believe it would be perfectly possible to upgrade my 2040 to DOS 2 just by upgrading the ROMs.  It is possible there were earlier 2040s with a different PCB, although mine dates from 1978-9.


## License

Licensed under the MIT License.  See [LICENSE](LICENSE).

## Contributing

Contributions are welcome.  Please feel free to submit a Pull Request.
