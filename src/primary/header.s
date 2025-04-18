; Header for the diagnostics ROM.
;
; This header allows the ROM to be able to operate at $D000, being dynamically
; instantiated by the main ROM.  It can be also be used at $F000, although this
; header is not necessary in that case.

; Copyright (c) 2025 Piers Finlayson <piers@piers.rocks>
;
; Licensed under the MIT License.  See [LICENSE] for details.

.include "include/version.inc"

.import with_stack_main

; Magic byte at the start of the diagnostics ROM (located at $D000), which is
; tested by the stock ROMs, to see if the diagnostics ROM is present.
DIAG_START_BYTE = $55
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
.segment "HEADER"
.byte DIAG_START_BYTE
.byte MAJOR_VERSION
.byte MINOR_VERSION
.byte PATCH_VERSION
.byte RESERVED
    JMP with_stack_main ; Jump to the start of the code - we skip the zero page
                        ; test, and setting up the stack, as the main ROM has
                        ; already done that when we're the dignostics ROM.  No
                        ; point in JSR and RTS here, as the main ROM JMPs to
                        ; us.
