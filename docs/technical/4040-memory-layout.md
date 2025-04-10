# 🗺️2040/3040/4040 Memory Layout

## Contents

- [🗺️Memory Map](#️memory-map)
    - [6502](#6502)
    - [6504](#6504)
    - [Address Shadowing](#address-shadowing)
- [🧩Components](#components)
    - [0️⃣Zero Page](#0️⃣zero-page)
        - [6502 Zero Page](#6502-zero-page)
        - [6504 Zero Page](#6504-zero-page)
    - [📚Stack](#stack)
        - [6502 Stack](#6502-stack)
        - [6504 Stack](#6504-stack)
    - [🔌RIOT chip registers](#riot-chip-registers)
    - [🔌VIA chip registers](#via-chip-registers)
    - [🔌RRIOT chip registers](#rriot-chip-registers)
    - [🧠RAM](#ram)
    - [🔐ROM](#rom)
        - [6502 ROM](#6502-rom)
        - [6504 ROM](#6504-rom)
        - [GCR Encoding/Decoding ROM](#gcr-encodingdecoding-rom)

## 🗺️Memory Map

### 6502

The 6502 is the disk drive's main processor, controlled by the primary ROMs, and which drives the LEDs and the IEEE-488 bus.  It controls the [6504 processor](#6504), sending it jobs through the main [static RAM](#ram), all of which is shared between the two processors.  The [Zero Page](#0️⃣zero-page) is __not__ shared between the processors.

| Address Range | Contents |
|---------------|----------|
| $0000-$007F | [Zero Page UC1](#6504-zero-page) |
| $0080-$00FF | [Zero Page UE1](#6504-zero-page) |
| $0100-$0100 | [Stack UC1/UE1](#6502-stack) |
| $0200-$021F | [RIOT UC1 Registers](#riot-chip-registers) |
| $0280-$029F | [RIOT UE1 Registers](#riot-chip-registers) |
| $0300-$03FF | [Shadows](#address-shadowing) [$0200-$02FF](#riot-chip-registers) |
| $0400-$0FFF | [Shadows](#address-shadowing) $0000-$03FF |
| $1000-$13FF | [RAM UC4/UC5](#ram) |
| $1400-$1FFF | [Shadows](#address-shadowing) $1000-$13FF [RAM](#ram) x 3 |
| $2000-$23FF | [RAM UD4/UD5](#ram) |
| $2400-$2FFF | [Shadows](#address-shadowing) $2000-$23FF [RAM](#ram) x 3|
| $3000-$33FF | [RAM UE4/UE5](#ram) |
| $3400-$3FFF | [Shadows](#address-shadowing) $3000-$33FF [RAM](#ram) x 3 |
| $4000-$43FF | [RAM UF4/UF5](#ram) |
| $4400-$4FFF | [Shadows](#address-shadowing) $4000-$43FF [RAM](#ram) x 3|
| $5000-$7FFF | [Shadows](#address-shadowing) $D000-$FFFF [ROMs](#rom) |
| $8000-$8FFF | [Shadows](#address-shadowing) $0000-$0FFF RIOT UC1/UE1|
| $9000-$CFFF | [Shadows](#address-shadowing) $1000-$4FFF [RAM](#ram) | 
| $D000-$DFFF | [ROM UJ1](#rom) |
| $E000-$EFFF | [ROM UL1](#rom) |
| $F000-$FFFF | [ROM UH1](#rom)  |

### 6504

The 6504 processor controls the two disk drive units, via its 6522 VIA chip (UM3) and RRIOT 6530 (UK3).  While it runs autonomously, it runs jobs provided by the [6502](#6502), via the [shared RAM](#ram).

The 6504 has 3 fewer address pins than the 6502, so strictly it can only address $0000-$1FFF.  However, as the 6504 is actually just a 6502 under the covers, it can "access" the full $0000-$FFFF address space via code, and in fact, the 6504's ROM's code is written using #FC00-$FFFF addresses.

Therefore while this memory layout table shows just the $0000-$1FFF space, this is [shadowed](#address-shadowing) 7 more times to fill the 16KB address space.

| Address Range | Contents |
|---------------|----------|
| $0000-$003F | [Zero Page](#6504-zero-page) and [Stack](#6504-stack) |
| $0040-$004F | [6522 Registers](#via-chip-registers) |
| $0050-$007F | [Shadows](#address-shadowing) $0000-$004F [6522 Registers](#via-chip-registers) |
| $0080-$008F | [RRIOT Registers](#rriot-chip-registers) |
| $0090-$00BF | [Shadows](#address-shadowing) $0080-$008F [RRIOT Registers](#rriot-chip-registers) |
| $00C0-$00FF | [Shadows](#address-shadowing) $0040-$007F [6522 Registers](#via-chip-registers) |
| $0100-$03FF | [Shadows](#address-shadowing) $0000-$00FF x 3 |
| $0400-$07FF | [RAM UC4/UC5](#ram) |
| $0800-$0BFF | [RAM UD4/UD5](#ram) |
| $0C00-$0FFF | [RAM UE4/UE5](#ram) |
| $1000-$13FF | [RAM UF4/UF5](#ram) |
| $1400-$1BFF | unconnected |
| $1C00-$1FFF | [6530 ROM](#6504-rom) |
| $2000-$FFFF | [Shadows](#address-shadowing) $0000-$1FFF x 7 |

### 🎭Address Shadowing

Various addresses map to other addresses - so when address A is accessed, B is actually accessed via the hardware.  This happens because some address lines are not connected, or because certain combinations of address lines are not handled by hardware.

In at least one case this shadowing is actually used by the stock ROM firmware (and the diagnostics ROM) - the [Stack RAM](#stack) at $0100-$1FF shadows the [Zero Page](#0️⃣zero-page-ram).

Apart from the stack RAM, the author has not seen other examples of deliberate use of shadowed RAM.

## 🧩Components

### 0️⃣Zero Page

#### 6502 Zero Page

- First 128 bytes ($00-$7F) is RAM from the 6532 RIOT chip UC1
- Second 128 bytes ($80-$FF) is RAM from the 6532 RIOT chip UE1

#### 6504 Zero Page

- 64 bytes ($00-$3F) from the 6530 RRIOT chip UK3

### 📚Stack

#### 6502 Stack

There is no separate stack RAM made available to the 6502 processor.  Instead the zero page is [shadowed](#address-shadowing), so when the processor accesses address $01XX, it actually accesses $00XX.

As the 6502 stack grows "upwards" (backwards) and is generally configured to start at $1FF, and assuming only the upper portions of the zero page are used to store non-stack data, this works.  This assumes the stack doesn't grow too large, and not too many of the zero page locations are used for data.

#### 6504 Stack

Like the [6502](#6502-stack), there is no separate stack RAM available to the 6504.  Instead the zero page is [shadowed](#address-shadowing), so when the processor accesses address $01XX, it actually accesses $00XX.

In the 6504 case, as it only has 64 bytes of zero page RAM, this means that the stack is initialized to $3F ($013F).

### 🔌RIOT Chip Registers

Accessed via the [6502](#6502).

The registers from the RIOT chips (the 6532s which also provide the zero page RAM) are mapped into the 6502's address space.

These registers expose IO pins and timer functionality.

RIOT stands for
- RAM
- I/O
- Timer

### 🔌VIA Chip Registers 

Accessed via the [6504](#6504).

The registers from the VIA chip (UM3) are mapped into the 6504's address space.

These registers expose IO pins and other functionality.

### 🔌RRIOT Chip Registers 

Accessed via the [6504](#6504).

The registers from the RRIOT chip (UK3) are mapped into the 6504's address space.

These registers expose IO pins and timer functionality.

RRIOT stands for
- ROM
- RAM
- I/O
- Timer

### 🧠RAM

Static RAM is provided by 8 x 1K 4-bit 2114 (and other compatible models) chips, provided a total of 4KB.

Provided by UC4/UC5/UD4/UD5/UE4/UE5/UF4/UF5.  The U_4 chips provide bits 4-7 and U_5 chips provide bits 0-3.

All of this RAM is shared between the [6502](#6502) and [6504](#6504), although each processor accesses the RAM via different addresses.

| Chips | [6502](#6502) Range | [6504](#6504) Range |
|-------|---------------------|---------------------|
| UC4/UC5 | $1000-$13FF | $0400-$0700 |
| UD4/UD5 | $2000-$23FF | $0800-$0B00 |
| UE4/UE5 | $3000-$33FF | $0C00-$0F00 |
| UF4/UF5 | $4000-$43FF | $1000-$1300 |

### 🔐ROM

#### 6502 ROM

The firmware for the [6502](#6502) is provided by 2 (DOS 1) or 3 (DOS 2) 4KB 2332 chips located.

- $F000 ROM is UH1, located on the right, furthest from the 6502.

- $E000 ROM is UL1, located on the left, closest to the 6502.

- (On the later 3 ROM DOS 2 drives,) UJ1, between the other ROMs, is populated with another 2332.

The stock DOS 1 ROMs immediately jump from the $F000 ROM where the reset vector is located ($FFFC) to the $E000 ROM, which runs the initial zero page test and then initializes the drive.  This means that both ROMs are required for any ROM code to execute.

#### 6504 ROM

The [6504](#6504)'s ROM is provided by the RRIOT 6530 chip (UK3), which is a 1K ROM.  It is located at $FCCC-$FFFF, although [shadowed](#address-shadowing) to other locations as well.

#### GCR Encoding/Decoding ROM

There is an additional 2316 2KB ROM installed on the drive in location UK6.  This handles encoding and decoding GCR data read from and written to the disk.  (GCR is essentially how Commodore drives encoding the 1s and 0s of data, an alternative to MFM which is used by PC drives.)

It is not addressed or accessed by either processor directly, but instead is addressed by the RRIOT 6530 chip (UK3) and the data bus is accessed by the VIA chip (UM3). 