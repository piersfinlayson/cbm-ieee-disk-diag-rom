# Source Code Structure

This directory contains the 6502 assembly source code for the Diagnostics ROM implementation. The codebase is organized into two main modules: `primary` and `secondary`.

## Directory Organization

```
src/
├── primary/         # Primary CPU firmware
│   ├── data.s       # Data tables and constants
│   ├── header.s     # ROM header information and initialization vectors
│   └── main.s       # Main program logic and entry point
|   └── secondary.s  # Scondary CPU firmware embedded in the primary firmware
│   ├── string.s     # String handling routines
└── secondary/       # Secondary CPU firmware
    └── control.s    # Control logic for secondary processor
```

## Module Descriptions

### Primary Module (`src/primary/`)

The primary module contains code that runs on the main 6502 processor.  This code is responsible for the main diagnosics ROM implementation, including tests, reporting and controlling the secondary processor.

* **main.s** - Contains the main entry point and core logic for the diagnostics ROM. This file is built in two configurations (D000 and F000) to accommodate being deloyed either alongside DOS 1 ROMs (D000) or standalone (F000).
* **string.s** - Implements string handling routines, including test result reporting.
* **data.s** - Contains data tables, messages, and other constant data used by the firmware.
* **header.s** - Defines the ROM header information and initialization vectors.
* **secondary.s** - Contains the secondary processor code, which is embedded in the primary firmware. This code is used to control the secondary processor and perform diagnostics.  Created from [`secondary/control.s`](secondary/control.s) during the build process.

### Secondary Module (`src/secondary/`)

The secondary module contains code for the secondary processor:
- a 6504 on the 2040/3040/4040
- a second 6502 on the 8050/8250.

This processor interfaces directory to the disk drive mechanisms.

* **control.s** - Implements the control routine for the secondary processor, used to control it from the primary processor.

## Build Configuration

The source code can be compiled into different memory configurations:

* **Primary D000** - Primary firmware configured to load at $D000 memory address - to be deployed alongside DOS 1 ROMs
* **Primary F000** - Primary firmware configured to load at $F000 memory address - standalone version
* **Secondary** - Secondary processor code with fixed memory mapping - built into the primary ROM, not expected to be used standalone

Configuration files for these builds are located in the `/config` directory. The appropriate build target can be selected using the Makefile.

## Related Documentation

For more detailed information about the system architecture and technical specifications:

* See [`/docs/technical/`](/docs/technical/) for system architecture details
* See [`/docs/schematics/`](/docs/schematics/) for disk drive schematics
* See [`/docs/specs/`](/docs/specs/) for diagnostics ROM implementation details (primarily forward looking, may be out of date)
* See [`/docs/original_roms/`](/docs/original_roms/) for the original ROM implementations

## Development Notes

Constants and memory addresses are defined in the `/include` directory to facilitate maintenance.

Code is heavily commented to help with the obscurity of 6502 assembly.  The code is also structured to be as readable as possible, with clear labels and logical flow.
