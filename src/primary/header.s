; Header for the diagnostics ROM.
;
; This header allows the ROM to be able to operate at $D000, being dynamically
; instantiated by the main ROM.  It can be also be used at $F000, although this
; header is not necessary in that case.

; Copyright (c) 2025 Piers Finlayson <piers@piers.rocks>
;
; Licensed under the MIT License.  See [LICENSE] for details.

; Imports
.import start, with_stack_main
.import nmi_handler, irq_handler

.include "include/version.inc"

; Magic byte at the start of the diagnostics ROM (located at $D000), which is
; tested by the stock ROMs, to see if the diagnostics ROM is present.
DIAG_START_BYTE = $55
E000_START_BYTE = $E0
F000_START_BYTE = $F0
RESERVED = $00

; Set first byte to $55 to indicate that this is a valid diagnostics ROM, if
; located at $D000.
;
; Follow that by the version number, which is 3 bytes long.  This is not
; required to be here fo the ROM to be operational at $D000, but is a 
; convenient location to put it. 
;
; We want the diagnostics ROM entry point to be at $D005, so we pad with
; another byte and then jump to the start of the zero-page tested and stack
; enabled part of our code.
;
; If built as the F000 ROM, we set the first byte to $F0 to differentiate it
; from the $D000 ROM.  This will prevent the stock DOS 1 ROMs from trying to
; execute it if it is installed in UJ1.
.segment "HEADER"

.ifdef F000_BUILD
.ifdef XX40_DRIVE
    .byte F000_START_BYTE
.else 
    .error "F000_BUILD only valid for XX40 drives"
.endif
.endif

.ifdef E000_BUILD
.ifdef XX50_DRIVE
    .byte E000_START_BYTE
.else
    .error "E000_BUILD only valid for XX50 drives"
.endif
.endif

.ifdef D000_BUILD
.ifdef XX40_DRIVE
    .byte DIAG_START_BYTE
.else
    .error "D000_BUILD only valid for XX40 drives"
.endif
.endif

.byte MAJOR_VERSION
.byte MINOR_VERSION
.byte PATCH_VERSION
.byte RESERVED
    JMP with_stack_main ; Jump to the start of the code - we skip the zero page
                        ; test, and setting up the stack, as the main ROM has
                        ; already done that when we're the dignostics ROM.  No
                        ; point in JSR and RTS here, as the main ROM JMPs to
                        ; us.

; If we're installed as the $F000 ROM, we need to provide a jump vector to
; START.
.segment "VECTORS"
.addr nmi_handler   ; NMI handler
.addr start
.addr irq_handler   ; IRQ handler
