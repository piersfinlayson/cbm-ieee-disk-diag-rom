; This file contains routines that will be dynamically loaded to the 6504
; processor at runtime.  The compiled binary is included in the main
; diagnostics assembly file.
;
; Copyright (c) 2025 Piers Finlayson <piers@piers.rocks>
;
; Licensed under the MIT License.  See [LICENSE] for details.
;
; See [README.md] for build and usage instructions.

CPU_6504 = 1
.include "shared.inc"

; Reset vector in 6504 $FC00 ROM
RESET = $FFFC

.segment "CODE"
start:
    ; Start off with a table of routine pointers and lengths.  The 6502 code
    ; will use this table to figure out how to copy the routine to shared 
    ; RAM.
    .addr control - start  ; Address of control routine
    .assert (control_end - control) <= 255, error, "Routine too large for byte"
    .byte control_end - control ; Length of control routine

control:
    SEI ; Disable interrupts
    LDA #STATUS_6504_RUNNING ; Set status to running
    STA STATUS_6504
@main_loop:
    ; Check whether CMD1 is set to a valid command
    LDA CMD1
    CMP #CMD_RESET
    BEQ @reset_test
    JMP @main_loop           ; If not, loop back and check again

@reset_test:
    ; check if CMD2 also set to run
    LDA CMD2
    CMP #CMD_RESET
    BNE @main_loop           ; If not, loop back and check again
@reset:
    ; If we got here, we've been told to reset by both CMD bytes - so reset
    LDA #STATUS_6504_RESETTING   ; Set status to resetting
    STA STATUS_6504
    JMP (RESET)
control_end:
