# ❓Frequently Asked Questions

## 📋 Questions
- [🔍General Questions](#general-questions)
    - [❓What is the purpose of this diagnostic ROM?](#what-is-the-purpose-of-this-diagnostic-rom)
    - [❓What does it test?](#what-does-it-test)
    - [❓How does it differ from Commodore's original diagnostic tools?](#how-does-it-differ-from-commodores-original-diagnostic-tools)
    - [❓Can I damage my drive by using this ROM?](#can-i-damage-my-drive-by-using-this-rom)
    = [❓Can I damage myself by using this ROM?](#can-i-damage-muself-by-using-this-rom)
- [💾Installation Questions](#installation-questions)
    - [❓Which ROM file should I use for my drive?](#which-rom-file-should-i-use-for-my-drive)
    - [❓Where can I find the ROM images?](#where-can-i-find-the-rom-images)
    - [❓Do I need special equipment to install the ROM?](#do-i-need-special-equipment-to-install-the-rom)
    - [❓How do I physically install the ROM?](#how-do-i-physically-install-the-rom)
    - [❓Do I need to remove the other ROM chips?](#do-i-need-to-remove-the-other-rom-chips)
    - [❓What happens if I put the ROM in the wrong socket?](#what-happens-if-i-put-the-rom-in-the-wrong-socket)
- [🔌Hardware Compatibility](#hardware-compatibility)
    - [❓Which drive models are supported?](#which-drive-models-are-supported)
    - [❓Is it compatible with dual/IEEE-488 drives only?](#is-it-compatible-with-dual-ieee-488-drives-only)
    - [❓Will it work with modified drives?](#will-it-work-with-modified-drives)
- [🛠️Troubleshooting](#️troubleshooting)
    - [❓All LEDs stay on after powering up with the ROM installed. What's wrong?](#all-leds-stay-on-after-powering-up-with-the-rom-installed-whats-wrong)
    - [❓What do the flash codes mean?](#what-do-the-flash-codes-mean)
    - [❓How can I tell if my issue is with the 6502 or RAM?](#how-can-i-tell-if-my-issue-is-with-the-6502-or-ram)
    - [❓Why does the diagnostics report RAM errors on all banks?](#why-does-the-diagnostics-report-ram-errors-on-all-banks)
    - [❓How do I know if the ROM is installed correctly?](#how-do-i-know-if-the-rom-is-installed-correctly)
- [🪛Fixing](#fixing)
    - [❓How do I find replacement ICs?](#how-do-i-find-replacement-ics)
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

The author originally created it because their DOS 1 3040 disk drive was not providing any indication of booting (with all three LEDs lit) and he wanted to see if that's because the stock ROM's zero page was failing, or something else.  It then ballooned into a full diagnostic suite.

### ❓What does it test?

This diagnostic ROM directly and automatically tests the following logic components:
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

The diagnostics ROM also exposes commands to allow you to manually test:
- both drive unit's stepper motors (which move the read/write heads forward and backwards to read/write different tracks on disks)
- both drive unit's spindle motors (which spin the disks).

### ❓How does it differ from Commodore's original diagnostic tools?

If you have a copy of the official Commodore diagnostics ROM, please [🤝share it](mailto:piers@piers.rocks)!

This project:
- Provides detailed feedback about specific failed components
- Features comprehensive zero-page and static RAM testing
- Allows stepper (head) and spindle motor testing
- Works with both DOS 1 and DOS 2 systems
- Can be installed in multiple ROM locations
= Includes a support program which can be run on a PET to assist with diagnosing issues with the drive

### ❓Can I damage my drive by using this ROM?

Per the [📜LICENSE](./LICENSE), this ROM is provided "as is" without warranty. However, the ROM itself is designed to be non-destructive and not cause any permanent damage to your drive so long as you use it carefully.

To avoid damage to your drive follow these precautions:
- Always wear a grounded anti-static wrist strap when handling the drive or any components, whether it's powered on or not.
- Ensure the drive is powered off and unplugged before installing or removing any components.
- Avoid shorting any pins or traces on the PCB.
- Be careful when inserting or removing ROMs or other components to avoid bending pins or damaging the socket.
- If desoldering components, do not apply excessive heat to the PCB or components.  Use a desoldering pump or wick to remove solder without damaging the PCB and use as low temperatures as possible.
- Ensure the (E)EPROM you use for the diagnostics ROM is compatible with the drive's stock ROM pinout (2332) and supports/provides the required voltage (5V).
- Remove and replace components as infrequently as possible to avoid wear and tear on the PCB and components.

The automated tests cause one moving part to energise - drive 0's spindle motor may spin briefly (for about a second) durig the automated test.  This is normal.  However, it is possible, if there is some physical damage to the drive that this could cause further damage.  If you are concerned about this, you may wish to disconnect drive 0's motor connections (using the larger connector which goes to drive 0) before running the tests.  This will prevent the spindle motor from being energised.

It may be possible to damage your drive using the manual tests which perform spindle and stepper motor tests.  You are strongly recommended to read the [⚠️documentation, and warnings](./README.md#motor-controls-via-ieee-488), for these tests before using them.

### ❓Can I damage myself by using this ROM?

There is a risk of electric shock or other injury if you do not follow proper safety precautions when working with your drive.  In particular, when open, the drive exposes mains voltages (120V or 240V depending on your country).  While these are reasonably well shielded by the drive's design, you should take care to avoid touching any exposed metal parts or wires and only work on the drive if you are competent to do so.

It is recommended that before powering on the drive, you check that the drive's case is connected to the power cable's ground/earth pin, and that when first powering on you do so connected to an RCD/RCBO/GFCI circuit or outlet in case there is a live-earth or neutral-earth short present.  You may choose to work on the drive with it powered via an isolation transformer for additional safety.

Your disk drive includes moving parts (the disk drive mechanism) and these could potentially trap your fingers (or any other appendages you insert into the drive mechanisms...).  As your drive may be faulty, or the ROM may activate drive motors, the mechanisms may move unexpectedly or at unexpected times.

## 💾Installation Questions

### ❓Which ROM file should I use for my drive?

By default, use `ieee_diag_f000.bin` in socket UH1.

- `ieee_diag_f000.bin`, socket UH1 - for testing DOS 2 drives and those  where you suspect one or more of the stock ROMs are faulty

- `ieee_diag_d000.bin`, socket UJ1 - for drives with 2 working DOS 1 ROMS

### ❓Where can I find the ROM images?

See the [📦project release page](https://github.com/piersfinlayson/cbm-ieee-disk-diag-rom/releases) for pre-built ROMs.

You can also [🔨build your own](./README.md#building-from-source).

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

### ❓What happens if I put the ROM in the wrong socket?

It depends what ROM you put where, but in general, the system will likely not boot and all three LEDs will be lit.

- Inserting the D000 ROM into the UH1 (F000) socket will cause the system not to boot.
- Installing any other ROM into socket UL1 (E000), with an F000 diagnostics ROM in UH1 (F000), should not cause any issues.
- If you insert the F000 ROM into the UJ1 (D000) socket on a DOS 1 drive, the system will ignore it and should boot normally.

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

### ❓What do the flash codes mean?

See the [💡LED Indicators](./README.md#led-indicators) and [🚦Summary of Flash Codes](./README.md#summary-of-flash-codes) sections for a detailed explanation of the LED flash codes.

### ❓How can I tell if my issue is with the 6502 or RAM?

- If all LEDs remain lit: Most likely a 6502, address bus, or UE1 issue
- If specific [⚠️RAM failure codes](./README.md#️static-ram-check-failed) are displayed: Specific RAM chips are faulty
- If the ROM runs but reports [⚠️6504 issues](./README.md#️6504-failed-to-boot): The secondary CPU or its support chips

### ❓Why does the diagnostics report RAM errors on all banks?

Rather than all of your static RAM chips being faulty or not present, this usually indicates a problem with the shared address bus multiplexers (74LS157s at UC3/UD3/UE3/UF3) rather than all RAM chips being faulty simultaneously.  As each of these address bus multiplexers handle some of the address lines for all of the RAM chips, if one of them is faulty, it can cause all of the RAM chips to appear faulty.

### ❓How do I know if the ROM is installed correctly?

If the three LEDs go out shortly (1-2s) after power on, and then other LEDs light, the ROM is likely installed correctly and running.

See [💡LED Indicators](./README.md#led-indicators) for more information on what the LEDs indicate.

## 🪛Fixing

### ❓How do I find replacement ICs?

Most ICs can be replaced with parts sourced from eBay or AliExpress.  This includes:
- 74 series logic
- 555 timer
- 6502 CPU
- 6522 VIA
- 6532 RIOT
- 2114 static RAM (6114s tend to be drop in replacements)
- MC3446 IEEE-488 bus transceivers

Many of these parts, especially those sourced from AliExpress, tend to be pulls from old hardware, and may have been relabelled or rebranded.  It can be helpful to have a working drive to install replacement parts into to check they work, before using them to repair a faulty drive.

To deal with failed ROMs, the stock ROM images are available from various sources including [zimmers.net](http://www.zimmers.net/anonftp/pub/cbm/firmware/drives/old/index.html).  You can burn these onto new EPROMs or EEPROMs, although you will likely need an adapter board to convert to the 2332 pinout required by the drive.

Some parts may be harder to find, including:
- 6504 CPU - It is possible to use a 6502 CPU in place of the 6504, but you will need an adapter board.  See [
🎥this video](https://youtu.be/fkwoDQRJFnA) for details.
- 6532 RRIOT - This is a custom chip, with a mask ROM and other mask options configured at the factory.  It is possible to build a replacement using discrete components, although this is not a trivial task.

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

- [📥Pull requests](https://github.com/piersfinlayson/cbm-ieee-disk-diag-rom/pulls)
- [❗Issue reporting](https://github.com/piersfinlayson/cbm-ieee-disk-diag-rom/issues)
- Documentation improvements
- Testing on different hardware variants

---

*Can't find an answer to your question? Open an issue on the GitHub repository!*