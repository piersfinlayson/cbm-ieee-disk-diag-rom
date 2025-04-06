; This file contains routines that will be dynamically loaded to the 6504
; processor at runtime.  The compiled binary is included in the main
; diagnostics assembly file.
;
; Copyright (c) 2025 Piers Finlayson <piers@piers.rocks>
;
; Licensed under the MIT License.  See [LICENSE] for details.
;
; See [README.md] for build and usage instructions.

; Reset point in 6504 $FC00 ROM
RESET = $FC00

; Status and command bytes are stored in the last bytes of the first block of
; shared 6502/6504 RAM.  Here (on the 6504) this bank is $400-$7FF.  On the
; 6502 this is $1000-$13FF.
STATUS = $7FD
CMD1 = $7FE
CMD2 = $7FF

; Every command is two bytes long.  This is to avoid accidently receiving a
; command when testing the shared RAM, which the 6502 does only 1 byte at a
; time.
CMD_RESET_1 = $FF
CMD_RESET_2 = $FF

STATUS_RUNNING = $01
STATUS_RESETTING = $02

.segment "CODE"
start:
    ; Start off with a table of routine pointers and lengths.  The 6502 code
    ; will use this table to figure out how to copy the routine to the shared
    ; RAM.
    .addr cmd - start   ; Address of command routine
    .byte cmd_end - cmd ; Length of command routine

cmd:
    SEI ; Disable interrupts
    LDA #STATUS_RUNNING ; Set status to running
    STA STATUS
@cmd_loop:
    ; Check if CMD1 set to run
    LDA CMD1
    CMP #CMD_RESET_1
    BNE @cmd_loop
    ; check if CMD2 also set to run
    LDA CMD2
    CMP #CMD_RESET_2
    BNE @cmd_loop
    ; If we got here, we've been told to reset by both CMD bytes - so reset
    LDA #STATUS_RESETTING   ; Set status to resetting
    STA STATUS
    JMP RESET
cmd_end:
