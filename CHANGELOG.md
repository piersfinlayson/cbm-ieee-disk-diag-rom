# Changelog

## 0.2.1

The 💾 8x50 and disk unit controller release 🎉

🆕New in this release:
- 💻PET program to aid with testing the drive.  This can be used to view diagnostics results and executed motor commands on the drive units (see below) if IEEE-488 is working and connected to a controller (such as a PET or PC with xum1541/ZoomFloppy).

    ![Main Screen](/docs/images/support/main-screen.png "Main Screen")

- 💻PC program to aid with testing the drive.  This can be used to send control characters to the diagnostics ROM directly, using IEEE-488 via an attached xum1541 or ZoomFloppy.  See below for the supported commands.

- 🌍Global commands run by sending single bytes to the drive using LISTEN mode on channel 15.
    - A - Enter drive unit command mode
    - X - Exit drive unit command mode, re-enter flash code mode
    - Z - Reboot the drive (both primary and secondary processors)
- 💪Physical drive unit test commands run by sending single bytes to the drive using LISTEN mode on channel 15.
    - 0 - Select drive 0
    - 1 - Select drive 1
    - M - Motor on
    - N - Motor off
    - F - Move head forward (to a higher track) by one step (1/2 track)
    - R - Move head reverse (to a lower track) by one step (1/2 track)
    - B - Bump the selected drive head against track 0 (steps 140 times backwards per stock ROM)
    - E - ⚠️Move to end of the selected drive (steps 70 times forward) - will cause reverse bump if starts from anything other than track 0.  Use with caution!⚠️
- 🔀All commands are case-insensitive.
- 🔌Increase robustness of IEEE-488 stack and reduced its code size.
- 🔢Rearranged the binary to increase contiguous free space for additional primary processor's diagnostics ROM code.
- 🆓Approximately 774 free bytes in the ROM available to the primary processor and 20 free bytes for the secondary processor's command routine.
- Added _untested_ support for a 8050 and 8250 diagnostics ROM, located at $E000.  This replaces the top ROM from these drives (as these drives use 8KB 2364 ROMs).  This ROM is [8x50_ieee_diag_e000.bin](build/8x50_ieee_diag_e000.bin).

Changed:
- The 2040/3040/4040 ROMs are now called (xx40_ieee_diag_d000.bin)[build/xx40_ieee_diag_d000.bin] and (xx40_ieee_diag_f000.bin)[xx40_ieee_diag_f000.bin].
- Unused space in the ROM is now filled with $FF instead of $00.

To dos:
- ❓Haven't tested longer byte listens or listens on other channels.  Behaviour is undefined.
- ❗Error status not yet fully supported.  After querying the boot status (73), the ROM will consistently report 00,OK,00,00.

## 0.1.5

- IEEE-488 stack added.
- Supports providing status and diagnostics information via IEEE-488 when put in TALK mode:
    - 0 - Lists supported channels and what they report
    - 1 - Provides summary of the test status (overall passed/failed)
    - 2 - Provides detailed information about the test status, including any failed chips that were identified
    - 14 - Provides version and other information about the ROM
    - 15 - Provides Commodore-style drive status string of the format EN,EM$,ET,ES
- Substantial source code reorganization

## 0.1.4

- Add check for 6504 booting
- Get taking over the 6504 from the 6502 working

## 0.1.3

- Speed up RAM tests by removing debug delay

## 0.1.2

Substantial rewrite, including:
- Splitting RAM test into two
- Taking control of the 6504 after main RAM test, before before testing key shared RAM used by 6504 ROM routine - also allows detecting of failed 6504 and related components
- Introduced two stage build process in order to separately compile, and then include, the code which will be executed by the 6504.
- Better zero page management
- Moving RAM test patterns to be table driven for better extensibility
- Retrieve device ID early on in processing
- Adding ability to detetct and report multiple errors, and device ID 
- Tidying up main, stack supported, code making it easier to see overall program execution flow - see with_stack_main:

## 0.1.1

- Added failed SRAM nibble detection and reporting

## 0.1.0

- First release
