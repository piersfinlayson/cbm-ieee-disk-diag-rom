; This file contains routines that will be dynamically loaded to the 6504
; processor at runtime.  The compiled binary is included in the primary main
; diagnostics assembly file.

; Copyright (c) 2025 Piers Finlayson <piers@piers.rocks>
;
; Licensed under the MIT License.  See [LICENSE] for details.

; Includes
.include "include/shared.inc"

; Locations of registers
VIA_PBD = $40
VIA_PBDD = $42
VIA_ACR = $4B
VIA_PCR = $4C
VIA_IER = $4E
RRIOT_PBDDR = $83

.segment "CODE"
control:
    CLD                     ; Clear decimal mode
    SEI                     ; Disable interrupts
    LDX #$3F                ; Set up stack
    TXS

    LDA #$FF
    STA VIA_PBDD    ; Set VIA port B pins to outputs
    LDA #$FC                
    STA VIA_PBD     ; Set VIA port B pins to high (motors off)
    STA VIA_PCR     ; Initialize peripheral control register
    LDA #$7F
    STA VIA_IER     ; Disable VIA interrupts
    LDA #$00
    STA VIA_ACR     ; Disable auxiliary control register features
    LDA #$07
    STA RRIOT_PBDDR ; Set RRIOT port B pins 0 -2 (DRV_SEL, DR0, DR1) tooutputs

    ; Set status to running.  We cannot change this in the loop because we
    ; might change the shared RAM under the feet of the RAM test.
    LDA #STATUS_6504_RUNNING ; Set status to running
    STA STATUS_6504

; Main loop, which checks whether to run a command
@main_loop:

    ; Check whether CMD1 is set to a valid command
    LDA CMD1
    .assert CMD_NONE = 0, error, "CMD_NONE must be 0 for branching to work correctly"
    BEQ @main_loop          ; Loop around again

    ; CMD1 isn't CMD_NONE.  Now check it matches CMD2
    CMP CMD2
    AND #$DF                ; Force to uppercase
    BNE @main_loop          ; If not, loop back and check CMD1 again

    ; CMD1 and CMD2 match.  Now check if it's a valid command
    AND #$DF                ; Force to uppercase
    CMP #CMD_RESET
    BEQ @reset

@reset:
    LDA #STATUS_6504_RESETTING   ; Set status to resetting
    STA STATUS_6504
    JMP (RESET)
