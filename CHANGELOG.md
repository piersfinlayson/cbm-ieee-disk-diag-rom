# Changelog

## 0.1.6

Haven't tested longer listens
Haven't added support for other commands (ones that go to 6504)

Have drive selection and motor turning on and off working

- Support global commands in response to single bytes in LISTEN mode on channel 15.
    - A - Enter drive unit command mode
    - X - Exit drive unit command mode, re-enter flash code mode
    - Z - Reboot the drive (both primary and secondary processors)
- Support drive unit commands in response to single bytes in LISTEN mode on channl 15.
    - 0 - Select drive 0
    - 1 - Select drive 1
    - M - Motor on
    - N - Motor off
    - F - Move head forward (to a higher track) by a half track
    - R - Move head reverse (to a lower track) by a half track
    - B - Bump the selected drive head against track 0 (issue 70 half-track steps backwards)
- Commands are case-insensitive
- Improved IEEE-488 LISTEN handling.
- Trimmed down IEEE-488 stack to save some bytes.
- Increase robustness of IEEE-488 stack

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
