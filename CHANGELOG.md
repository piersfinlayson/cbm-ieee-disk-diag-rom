# Changelog

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
