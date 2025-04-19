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

; Used for the motor control for the selected drive
ZP_MOTOR_MASK_OFF = $00
ZP_MOTOR_MASK_ON = $01

; Zero page locations we're using for temporary storage
ZP_PHASE_CURRENT  = $0007   ; Current stepper phase bits
ZP_NON_STEP_BITS  = $0008   ; Non-stepper bits to preserve
ZP_PHASE_MASK     = $000A   ; Phase mask for the selected drive
ZP_PHASE_STEP     = $000B   ; Phase increment value

; Do NOT put any code/data before the code segment starts, and that needs to
; begin with executable code - as the primary processor will execute from the
; start of the shared RAM segment we load this code into.

; Our entry point must be at $0500
.segment "STARTUP"
    JMP control

; It is OK for data to come before the code segment starts, as the processor
; will be JMPed to control:
.segment "DATA"

; Byte 0 = Drive 0, Byte 1 = Drive 1.  1 off, 0 on
MOTOR_MASK:
    .byte $A0, $50

.segment "CODE"
control:
    ; We are taking over the processor.  If we need to return, we will reboot
    ; it by JMPing to the reset vector.
    CLD                     ; Clear decimal mode
    SEI                     ; Disable interrupts
    LDX #$3F                ; Set up stack
    TXS

    ; Set various hardware registers ready to control the drive units.
    LDA #$FF
    STA VIA_PBDD    ; Set VIA port B pins to outputs
    LDA #$FC                
    STA VIA_PBD     ; Set VIA port B pins to high (motors off)
    STA VIA_PCR     ; Initialize peripheral control register
    LDA #$7F
    STA VIA_IER     ; Disable VIA interrupts
    LDX #$00        ; Use X so its zero
    STX VIA_ACR     ; Disable auxiliary control register features
    LDA #$07
    STA RRIOT_PBDDR ; Set RRIOT port B pins 0 -2 (DRV_SEL, DR0, DR1) to outputs

    ; Set status to running.  This signals to the primary processor that this
    ; routine has been loaded and it running.  We can only change this now,
    ; because later the primary will be testing the shared RAM, and we don't
    ; want to be changing the RAM under its feet.
    LDA #STATUS_6504_RUNNING
    STA STATUS_6504
    .assert STATUS_6504_RUNNING <> 0, error, "STATUS_6504_RUNNING must not be 0"

    ; Do not select a drive by default.  command_loop: will set up to drive 0
    ; before doing anything else.

; Main loop, which checks whether to run a command
@main_loop_ok:
    ; As command executed OK, load OK to accumulator
    LDA #CMD_RESULT_OK
@main_loop_result:
    STA CMD_RESULT          ; Store result of command
    LDA #CMD_NONE
    STA CMD1                ; Reset both command bytes
    STA CMD2

@main_loop:
    ; Check whether CMD1 is set to a valid command
    LDA CMD1
    .assert CMD_NONE = 0, error, "CMD_NONE must be 0 for branching to work correctly"
    BEQ @main_loop          ; Loop around again

    ; CMD1 isn't CMD_NONE.  Now check it matches CMD2
    CMP CMD2
    BNE @main_loop          ; If not, loop back and check CMD1 again

    ; CMD1 and CMD2 match.  Now check if it's a valid command.
    ; No need to force upper-case here, command_loop: on the primary processor
    ; did that for us
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
    
    STA CMD_RESULT_CMD      ; Store the failed command
    LDA #CMD_RESULT_ERR     ; Set the result in A
    JMP @main_loop_result   ; If not, loop back and check CMD1 again

@drive0:
    ; Set X input to drive_common to drive number.  A is set to the CMD
    LDX #$00
    BEQ @drive_common
@drive1:
    ; Set X input to drive_common to drive number.  A is set to the CMD
    LDX #$01
@drive_common:
    ; X should be drive number (0 or 1) and A should be the command that
    ; was executed.
    STA CMD_RESULT_CMD      ; Set the command result to the command before
                            ; we lose it
    LDA MOTOR_MASK, X       ; Load the appropriate motor mask
    STA ZP_MOTOR_MASK_OFF   ; Store it in the zero page
    EOR #$FF                ; Invert the mask
    STA ZP_MOTOR_MASK_ON    ; Store it in the zero page
    JMP @main_loop_ok

@motor_on:
    STA CMD_RESULT_CMD      ; Set the command result to the command before
                            ; we lose it
    LDA VIA_PBD             ; Load current value of motor ports
    AND ZP_MOTOR_MASK_ON    ; Mask out the motors that should be on (0 is on)
    JMP @motor_common
@motor_off:
    STA CMD_RESULT_CMD      ; Set the command result to the command before
                            ; we lose it
    LDA VIA_PBD             ; Load current value of motor ports
    ORA ZP_MOTOR_MASK_OFF   ; Set the motors that should be off (1 is off)
@motor_common:
    STA VIA_PBD             ; Store it back
    JMP @main_loop_ok       ; We're done - A may or may not be 0

@reset:
    LDA #STATUS_6504_RESETTING   ; Set status to resetting
    STA STATUS_6504
    JMP (RESET)
