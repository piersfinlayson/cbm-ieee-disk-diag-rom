# 💾cbm-ieee-disk-diag-rom

🛠️ A diagnostic ROM for Commodore 2040, 3040, and 4040 disk drives which use the IEEE-488 interface.

## 📖Overview

This project provides a diagnostics ROM for early Commodore disk drives (2040, 3040, and 4040). It performs basic memory tests and provides visual feedback through the drive's LEDs.

## ✨Features

- ✅ Zero page and static RAM testing
- 🔍 Identifies precisely which SRAM chip which failed
- 💡 Visual status indication and failed components via drive LEDs
- 📦 Compatible with multiple disk drive models
- 🔄 Can be installed at either $F000 or $D000 (DOS 1 only) ROM locations
- 🏷️ Detects and reports the configured hardware device ID (8, 9, etc)

## 📥Installation

Either [Build From Source](#building-from-source) or download the ROMs from the [releases page](https://github.com/piersfinlayson/cbm-ieee-disk-diag-rom/releases/).

1. 🔥 Burn the appropriate ROM image to an EPROM/EEPROM:
   - Use `diag_x040_f000.bin` for installation at $F000
   - Use `diag_x040_d000.bin` for installation at $D000

2. 🔌 Install the EPROM in the appropriate socket in your disk drive
   - $F000 - UH1
   - $D000 - UJ1

If you want to fill a larger EEPROM with this ROM image, see [`flash_fill_1mbit.sh`](flash_fill_1mbit.sh).  You may need to modify the script for your EEPROM size.

## 🚀Usage

After installing the ROM:

1. Power on the disk drive
2. The diagnostics will run automatically
3. Observe the LED pattern to determine the status - see [LED Indicators](#led-indicators)

To choose which ROM to install:

### 🔄$F000 ROM replacement, UH1

If you are unsure whether your upper, $F000, ROM, located at UH1 is functional, replace it with the $F000 version of this diagnostics ROM.

In particular, this is helpful if you have all three LEDs light on your disk drive when booting with the original ROM.  If they remain lit with this ROM (assuming you correctly built, flashed and installed it) you have a non-ROM issue preventing the ROM code from being executed.  If you had all three LEDs solidly lit with the stock ROM and see other LED patterns with this ROM, then one of your stock ROMs is probably faulty.

For a first test, you are best off removing the $E000 ROM (UL1) before running this diagnostics ROM at $F000, in case $E000/UL1 is faulty and causes address or data bus issues. 

### 🔄$D000 ROM, UJ1

If you believe your stock $F000 and $E000 ROMs are functional (the three LEDs go out after powering on), and your UJ1 socket is free, you can install the $D000 version of this ROM at location UJ1.  You need both $F000 and $E000 to boot far enough to load the ROM installed at $D000.  If you suspect either ROM of being faulty, start with the $F000 replacement method, above.

If your drive has a $D000 ROM already installed then your current ROMs likely don't not support a diagnostic ROM at $D000, so replace your $F000 with the $F000 version of this ROM instead.  This is typical of the 4040, although 2040 and 3040s may have been upgraded to a three ROM configuration.

DOS 1 firmware version 901468/06/07 come as a 2 ROM set and support at $D000 UJ1 diagnostics ROM being installed. 

DOS 2 firmware versions 901468-11/12/13 and 14/15/16 come as a 3 ROM set.

When running as the $D000 ROM the zero page test is skipped - as the stock ROM has already done this test.

## 💡LED Indicators

The ROM uses the drive's LEDs to indicate status:

| LED Pattern | Meaning |
|-------------|---------|
| ERR LED off, DR0/DR1 flashing | [All tests passed](#all-tests-passed) |
| All LEDs solid on | [Diagnostics ROM failed to run](#diagnostics-rom-failed-to-run) |
| All LEDs blink briefly | [Moving to next test](#moving-to-next-test) |
| ERR LED solid on | [Testing zero page](#testing-zero-page) |
| DR0, DR1, ERR leds strobing | [Testing static RAM](#testing-static-ram) |
| ERR LED and drive 0 LEDs flashing together | [Zero page test failed in UC1 6532](#zero-page-ram-uc1-failed) |
| ERR LED and drive 1 LEDs flashing together | [Zero page test failed in UE1 6532](#zero-page-ram-ue1-failed) |
| ERR LED solid, DR1 or DR0 light flashing, ERR goes out, sequence restarts | [Static RAM check failed](#static-ram-check-failed) |

### All tests passed

With the ERR LED off and the DR0/DR1 LEDs flashing rapidly all tests have passed.

The number of flashes, before pausing, indicates the hardware configured device ID of this drive.

### Diagnostics ROM failed to run

In this scenario, all three LEDs will be lit.

Most likely 6502 is faulty, this ROM is corrupted, or UE1 6532 is faulty.

First try replacing the 6502 and the UE1 6532 (you could try swapping UE1 and UC1 around).

If the problem remains, you probably have an issue with either
- the main RESET circuit
- corruption on either the 6502 address bus or shared data bus
- a failed 74LS157 (UC3/UD3/UE3/UF3)
- something else that is preventing proper communication between components, on the data or (6502) address buses.

Sadly, as this diagnostics ROM requires address and data bus communication between the 6502, this ROM and the UE1 6532, corruption of these buses can cause issues this ROM cannot diagnose.  However, understanding this is useful to track the problem down.

### Moving to next test

A brief blink of all three LEDs indicates that a test has been completed, and the ROM is moving onto the next test.

### Testing Zero Page

The ERR LED is solidly lit while testing the zero page.  However, as this test is so brief, it may look like a very quick flash.  As the zero-page is tested immediately after boot, it will happening very soon after power on, after all three LEDs go out.

### Testing Static RAM

All three LEDs are used to indicate the static RAM test.  You should see a sequence as follows:
- Testing bank $1000-$13FF (UC4/5) - DR1 illuminates
- Testing bank $2000-$23FF (UD4/5) - DR1 goes out and DR0 illuminates
- Testing bank $3000-$33FF (UE4/5) - DR1 and DR0 illuminate together
- Testing bank $4000-£43FF (UF4/5) - DR1 and DR0 go out and ERR LED illuminates

### Zero Page RAM UC1 failed 

The ERR and DR0 LEDs flashing together signify a failed zero page test in the CE1 6532.

### Zero Page RAM UE1 failed 

The ERR and DR1 LEDs flashing together signify a failed zero page test in the UE1 6532.

However, as UE1 is used to drive LEDs, if the entire chip has failed, this error will not be signaled via LEDs.  Instead you would just see [Diagnostics ROM failed to run](#-diagnostics-rom-failed-to-run).

### Static RAM check failed

In this scenario the ERR LED is lit while either the DR1 or DR0 LED flashes.  All LEDs go out after the flashing, and then the sequence starts again.

DR0 flashing signifies a high nibble RAM chip (UC4, UD4, UE4 or UF4) has failed.

DR1 flashing signifies a low nibble RAM chip (UC5, UD5, UE5, UF5) has failed.

The Number of Drive LED flashes indicates which bank has failed:
- 1 flash = UC4 or UC5
- 2 flashes = UD4 or UD5
- 3 flashes = UE4 or UE5
- 4 flashes = UF4 or UF5

Together this information allows the precie failed static RAM chip to be identified.

However, if UC4 is indicated as failed, it may, instead be one (or more) of the 74LS157s UC3/UD3/UE3/UF3 that has failed, or some other bus error preventing communucation with any of the RAM.  If replacing (or swapping around UC4) doesn't help, try removing the 6504 (UH3), 6530 (UK3) and 6522 (UM3) from the board and re-running the test.  This isolates those chip as potentially conflicting with the shared data bus. 

## 🔨Building From Source

### 📋Requirements

- `ca65` assembler (part of the cc65 suite)
- `make` (for building using the Makefile)

Install them both on linux like so:

```bash
sudo apt-get install cc65 make
```

### 🧰Compilation

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

## ⚙️Technical Details

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

## 📜License

Licensed under the MIT License.  See [LICENSE](LICENSE).

## 🤝Contributing

Contributions are welcome.  Please feel free to submit a Pull Request.
