# ❓Frequently Asked Questions

## 📋 Questions
- [🔍General Questions](#general-questions)
    - [❓What is the purpose of this diagnostic ROM?](#what-is-the-purpose-of-this-diagnostic-rom)
    - [❓What does it test?](#what-does-it-test)
    - [❓How does it differ from Commodore's original diagnostic tools?](#how-does-it-differ-from-commodores-original-diagnostic-tools)
    - [❓Can I damage my drive by using this ROM?](#can-i-damage-my-drive-by-using-this-rom)
- [💾Installation Questions](#installation-questions)
    - [❓Which ROM file should I use for my drive?](#which-rom-file-should-i-use-for-my-drive)
    - [❓Where can I find the ROM images?](#where-can-i-find-the-rom-images)
    - [❓Do I need special equipment to install the ROM?](#do-i-need-special-equipment-to-install-the-rom)
    - [❓How do I physically install the ROM?](#how-do-i-physically-install-the-rom)
    - [❓Do I need to remove the other ROM chips?](#do-i-need-to-remove-the-other-rom-chips)
- [🔌Hardware Compatibility](#hardware-compatibility)
    - [❓Which drive models are supported?](#which-drive-models-are-supported)
    - [❓Is it compatible with dual/IEEE-488 drives only?](#is-it-compatible-with-dual-ieee-488-drives-only)
    - [❓Will it work with modified drives?](#will-it-work-with-modified-drives)
- [🛠️Troubleshooting](#️troubleshooting)
    - [❓All LEDs stay on after powering up with the ROM installed. What's wrong?](#all-leds-stay-on-after-powering-up-with-the-rom-installed-whats-wrong)
    - [❓How can I tell if my issue is with the 6502 or RAM?](#how-can-i-tell-if-my-issue-is-with-the-6502-or-ram)
    - [❓Why does the diagnostics report RAM errors on all banks?](#why-does-the-diagnostics-report-ram-errors-on-all-banks)
    - [❓How do I know if the ROM is installed correctly?](#how-do-i-know-if-the-rom-is-installed-correctly)
- [⚙️Building From Source](#️building-from-source)
    - [❓Can I build this on Windows?](#can-i-build-this-on-windows)
    - [❓Are there any dependencies for macOS?](#are-there-any-dependencies-for-macos)
    - [❓Can I modify the ROM for my specific needs?](#can-i-modify-the-rom-for-my-specific-needs)
- [🧪Advanced Usage](#advanced-usage)
    - [❓Can I use this ROM to help repair other issues than memory?](#can-i-use-this-rom-to-help-repair-other-issues-than-memory)
    - [❓Is there a way to get more detailed diagnostics output?](#is-there-a-way-to-get-more-detailed-diagnostics-output)
    - [❓Can I contribute to this project?](#can-i-contribute-to-this-project)

## 🔍General Questions

### ❓What is the purpose of this diagnostic ROM?

The diagnostic ROM helps identify hardware issues in Commodore 2040/3040/4040 disk drives by performing memory and other tests and providing visual feedback through the drive's LEDs.

### ❓What does it test?

This diagnostic ROM directly tests:
- the primary 6502 CPU (UN1)
- the secondary 6504 CPU (UH3)
- the 2114 static RAM chips (UC4/UC5/UD4/UD5/UE4/UE5/UF4/UF5)
- the 6532 RIOT chips (UC1/UE1)
- the error, drive 0 and drive 1 LEDs

And also, indirectly:
- the 6530 RRIOT chip (6530UK3)
- the bus multiplexors (74LS157s at UC3/UD3/UE3/UF3)
- the CPU address line decoders (74LS42s at UA3 and UA1)
- the reset circuit
- various other logic chips, including:
    - 74LS04 UA1 (not populated on the 2040, cleans up clock signals)
    - 74LS04 UL2 (part of reset cicuit)
    - 7406 UN2 (inverts LED outputs and part of reset circuit)
    - 74S04 UA6 (part of the circuit producing clock signals from oscillator)
    - 74LS193 UB6 (part of the circuit producing clock signals from oscillator)
    - 7414 UA4 (part of reset circuit)

### ❓How does it differ from Commodore's original diagnostic tools?

If you have a copy of the official Commodore diagnostics ROM, please [share it](mailto:piers@piers.rocks)!

This project:
- Provides detailed feedback about specific failed components
- Works with both DOS 1 and DOS 2 systems
- Can be installed in multiple ROM locations
- Features comprehensive static RAM testing

### ❓Can I damage my drive by using this ROM?

Per the [LICENSE](./LICENSE), this ROM is provided "as is" without warranty. However, the ROM itself is designed to be non-destructive and should not cause any permanent damage to your drive.

To avoid damage to your drive follow these precautions:
- Always wear a grounded anti-static wrist strap when handling the drive or any components, whether it's powered on or not.
- Ensure the drive is powered off and unplugged before installing or removing any components.
- Avoid shorting any pins or traces on the PCB.
- Be careful when inserting or removing ROMs or other components to avoid bending pins or damaging the socket.
- If desoldering components, never apply excessive heat to the PCB or components. Use a desoldering pump or wick to remove solder without damaging the PCB and use as low temperatures as possible.
- Ensure the (E)EPROM you use for the diagnostics ROM is compatible with the drive's stock ROM pinout (2332) and supports/provides the required voltage (5V).

## 💾Installation Questions

### ❓Which ROM file should I use for my drive?

By default, use `ieee_diag_f000.bin` in socket UH1.

- `ieee_diag_f000.bin`, socket UH1 - for testing DOS 2 drives and those  where you suspect one or more of the stock ROMs are faulty

- `ieee_diag_d000.bin`, socket UJ1 - for drives with 2 working DOS 1 ROMS

### ❓Where can I find the ROM images?

See the [project release page](https://github.com/piersfinlayson/cbm-ieee-disk-diag-rom/releases) for pre-built ROMs.

You can also [build your own](./README.md#building-from-source).

### ❓Do I need special equipment to install the ROM?

You'll need:
- An (E)EPROM programmer to burn the ROM image
- Compatible EPROM (2732, 2732, etc.) or EEPROM.
- Basic electronics tools for safely removing/installing chips
- Anti-static wrist strap (recommended)

### ❓How do I physically install the ROM?

1. Power off and unplug the drive
2. Identify the correct socket (UH1 or UJ1)
3. Carefully remove the existing ROM (if present)
4. Ensure proper orientation (notch aligned correctly)
5. Insert the programmed (E)EPROM

### ❓Do I need to remove the other ROM chips?

No, the diagnostic ROM can be installed alongside the existing ROMs. The diagnostics will run from the installed ROM and will not interfere with the other ROMs.

However, if your other ROMs are faulty to the extent that they are causing address or data bus conflicts, they can prevent the diagnostics ROM from running.

## 🔌Hardware Compatibility

### ❓Which drive models are supported?

This diagnostic ROM supports Commodore IEEE-488 drives:
- 2040 (DOS 1 & DOS 2)
- 3040 (DOS 1 & DOS 2)
- 4040 (DOS 2)

It may be that the 8050 and 8250 drives are also compatible, as the digital architecture is very similar, but this has not been tested.

### ❓Is it compatible with dual/IEEE-488 drives only?

Yes, this ROM is designed specifically for the dual-drive IEEE-488 models.

It may be possible to extend the ROM to support single IEEE-488 drives, such as the 2030/2031/SFD-1001.  However, the ROM is unlikely to work in these drives out of the box, as they have a simplified architecture (single processor and less RAM). 

It is not compatible with IEC (serial) drives like the 1541, again beause of the different digital architecture.

### ❓Will it work with modified drives?

Generally yes, as long as the core digital architecture remains unchanged.

The ROM will detect and report the hardware configured device ID.

## 🛠️Troubleshooting

### ❓All LEDs stay on after powering up with the ROM installed. What's wrong?

This typically indicates one of three issues:
- The ROM is not properly seated in the socket
- The ROM was not programmed correctly
- There's a hardware issue preventing the ROM from executing

See [❌Diagnostics ROM failed to run](./README.md#diagnostics-rom-failed-to-run) for more information.

### ❓How can I tell if my issue is with the 6502 or RAM?

- If all LEDs remain lit: Most likely a 6502, address bus, or UE1 issue
- If specific [RAM failure codes](./README.md#️static-ram-check-failed) are displayed: Specific RAM chips are faulty
- If the ROM runs but reports [6504 issues](./README.md#️failed-to-pause-6504): The secondary CPU or its support chips

### ❓Why does the diagnostics report RAM errors on all banks?

Rather than all of your static RAM chips being faulty or not present, this usually indicates a problem with the shared address bus multiplexers (74LS157s at UC3/UD3/UE3/UF3) rather than all RAM chips being faulty simultaneously.  As each of these address bus multiplexers handle some of the address lines for all of the RAM chips, if one of them is faulty, it can cause all of the RAM chips to appear faulty.

### ❓How do I know if the ROM is installed correctly?

If the three LEDs go out shortly (1-2s) after power on, and then other LEDs light, the ROM is likely installed correctly and running.

See [LED Indicators](./README.md#led-indicators) for more information on what the LEDs indicate.

## ⚙️Building From Source

### ❓Can I build this on Windows?

Yes, although this is untested.

You'll need:
1. Install cc65 suite (available at https://cc65.github.io/)
2. Install Make for Windows (via MinGW, Cygwin, or WSL)
3. Follow the build instructions in the main README

### ❓Are there any dependencies for macOS?

This is untested.

For macOS:

```bash
brew install cc65
```
Then follow the standard build instructions.

### ❓Can I modify the ROM for my specific needs?

Yes.  The source code is extensively commented and modular. Common modifications include:
- Changing test sequences (for example to remove un-needed tests)
- Adding additional diagnostics
- Modifying LED patterns

## 🧪Advanced Usage

### ❓Can I use this ROM to help repair other issues than memory?

Yes. As well as memory testing, the diagnostics can help identify:

- Bus conflicts
- Chip select issues
- Timing problems
- Intermittent failures (by running tests repeatedly)

This ROM also allows your disk drive to be used as a generic testbed for testing:

- 6502/6504 CPUs
- 2114 and compatible static RAM chips
- 6532 RIOT chips

### ❓Is there a way to get more detailed diagnostics output?

Currently, detailed output is limited to LED patterns. Future enhancements may include:

- IEEE-488 communication of detailed results
- Serial monitoring options
- Extended diagnostic codes

### ❓Can I contribute to this project?

Absolutely! Contributions are welcome via:

- [Pull requests](https://github.com/piersfinlayson/cbm-ieee-disk-diag-rom/pulls)
- [Issue reporting](https://github.com/piersfinlayson/cbm-ieee-disk-diag-rom/issues)
- Documentation improvements
- Testing on different hardware variants

---

*Can't find an answer to your question? Open an issue on the GitHub repository!*