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

MOTOR_PORTS = VIA_PBD

ZP_MOTOR_MASK_OFF = $00
ZP_MOTOR_MASK_ON = $01

; Byte 0 = Drive 0, Byte 1 = Drive 1.  1 off, 0 on
MOTOR_MASK:
    .byte $20, $10

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
    .assert STATUS_6504_RUNNING <> 0, error, "STATUS_6504_RUNNING must not be 0"
    BNE @main_loop

; Main loop, which checks whether to run a command
@main_loop_ok:
    LDX #$00
    STX CMD1                ; Reset both command bytes
    STX CMD2
    STX CMD_RESULT          ; Store result of command
@main_loop:
    ; Check whether CMD1 is set to a valid command
    LDA CMD1
    .assert CMD_NONE = 0, error, "CMD_NONE must be 0 for branching to work correctly"
    BEQ @main_loop          ; Loop around again

    ; CMD1 isn't CMD_NONE.  Now check it matches CMD2
    CMP CMD2
    BNE @main_loop          ; If not, loop back and check CMD1 again

    ; CMD1 and CMD2 match.  Now check if it's a valid command
    AND #$DF                ; Force to uppercase
    CMP #CMD_RESET
    BEQ @reset
    CMP #CMD_DR0
    BEQ @drive0
    CMP #CMD_DR1
    BEQ @drive1
    CMP #CMD_MOTOR_ON
    BEQ @motor_on
    CMP #CMD_MOTOR_OFF
    BEQ @motor_off
    BNE @main_loop          ; If not, loop back and check CMD1 again

@drive0:
    LDX #$00
    BEQ @drive_common
@drive1:
    LDX #$01
@drive_common:
    STA CMD_RESULT_CMD      ; Set the command result to the command before
                            ; we lose it
    LDA MOTOR_MASK, X       ; Load the appropriate motor mask
    STA ZP_MOTOR_MASK_OFF   ; Store it in the zero page
    EOR #$FF                ; Invert the mask
    STA ZP_MOTOR_MASK_ON    ; Store it in the zero page
    BNE @main_loop_ok       ; We're done - A is not 0

@motor_on:
    STA CMD_RESULT_CMD      ; Set the command result to the command before
                            ; we lose it
    LDA MOTOR_PORTS         ; Load current value of motor ports
    AND ZP_MOTOR_MASK_ON    ; Mask out the motors that should be on (0 is on)
    JMP @motor_common
@motor_off:
    STA CMD_RESULT_CMD      ; Set the command result to the command before
                            ; we lose it
    LDA MOTOR_PORTS         ; Load current value of motor ports
    ORA ZP_MOTOR_MASK_OFF   ; Set the motors that should be off (1 is off)
@motor_common:
    STA MOTOR_PORTS         ; Store it back
    JMP @main_loop_ok       ; We're done - A may or may not be 0

@reset:
    LDA #STATUS_6504_RESETTING   ; Set status to resetting
    STA STATUS_6504
    JMP (RESET)
