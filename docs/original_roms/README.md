# 🔐Original ROMs

This directory contains some of the original ROM code, disassembled with comments.

## 🔐ROMs

### 1️⃣DOS1


| Processor | Location | Address | Size | Purpose | Source | Notes |
|-----------|----------|---------|------|---------|--------|-------|
| 6504 | 6530 UK3 | $FC00-$FFFF | 1KB | 6504 Boot ROM | [6504 Boot ROM](./dos1_6504_primary_fc00_ffff.a65) | |
| 6504 | UL1 | $0500-$0640 | 321 bytes | Format routine | [6504 Format Routine](./dos1_6504_format_0500.a65) | Supplied by 6502 at runtime|
| 6502 | 2332 UL1 & UH1 | $E000-$FFFF | 8KB | 6502 ROM | [6502 ROM](./dos1_6502_e000_ffff.a65) | |

## © Copyright

All code in this directory is Copyright © Commodore Business Machines.

The disassemblies and original comments of the DOS 1 ROM came from [André's 8-bit pages](http://www.6502.org/users/andre/petindex/drives/roms/).
