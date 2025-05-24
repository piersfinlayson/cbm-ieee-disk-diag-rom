# 🔐Original ROMs

This directory contains some of the original ROM code, disassembled with comments.

The binaries themselves are located in [./roms](./roms). They can also be found at:

- [2040/3040/4040](http://www.zimmers.net/anonftp/pub/cbm/firmware/drives/old/4040/index.html)

- [8050/8250](http://www.zimmers.net/anonftp/pub/cbm/firmware/drives/old/8050/index.html)

## 🔐ROMs

### 1️⃣DOS1 - 2040/3040


| Processor | Location | Part Number | Address | Size | Purpose | Source | Notes |
|-----------|----------|-------------|---------|------|---------|--------|-------|
| Primary | 2332 UL1 & UH1 | 901468-06/07 | $E000-$FFFF | 8KB | 6502 firmware | [6502 ROM](./901468-06-07.a65) | |
| Secondary | 6530 UK3 | 901466-02 | $FC00-$FFFF | 1KB | 6504 firmware | [6504 Boot ROM](./901466-02.a65) | |
| Secondary | UL1 | n/a | $0500-$0640 | 321 bytes | Format routine | [6504 Format Routine](./901468-06-07-format-routine.a65) | Supplied by 6502 at runtime|

The code in the primary ROM indicates that an optional $D000 ROM was available.  The author has not been able to locate it, or find any reference to it beyond that in the primary ROM's code.

### 1️⃣DOS2 - 4040 (and upgraded 2040/3040s)

| Processor | Location | Part Number | Address | Size | Purpose | Source | Notes |
|-----------|----------|-------------|---------|------|---------|--------|-------|
| Primary | 2332 UL1, UJ1 & UH1 | 901468-11/12/13 | $D000-$FFFF | 12KB | 6502 firmware |  | DOS 2 |
| Primary | 2332 UL1, UJ1 & UH1 | 901468-14/15/16 | $D000-$FFFF | 12KB | 6502 firmware |  | DOS 2 Rev 2 |
| Secondary | 6530 UK3 | 901466-04 | $FC00-$FFFF | 1KB | 6504 firmware | [6504 Boot ROM](./901466-04.a65) | |

## © Copyright

All code in this directory is Copyright © Commodore Business Machines.

The disassemblies and original comments of some of the DOS 1 ROM came from [André's 8-bit pages](http://www.6502.org/users/andre/petindex/drives/roms/).

All other comments are Copryright © 2025 Piers Finlayson.
