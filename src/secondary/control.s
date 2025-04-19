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
ZP_PHASE_MASK = $02         ; Stepper motor phase mask for drive
ZP_PHASE_STEP = $03         ; Stepper motor phase increment value for drive

; Zero page locations used for temporary storage by stepper control
ZP_PHASE_CURRENT  = $05   ; Current stepper phase bits
ZP_NON_STEP_BITS  = $06   ; Non-stepper bits to preserve

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

; Byte 0 = Drive 0, Byte 1 = Drive 1.  Drve 0 uses bits 2-3, drive 1 0-1.
PHASE_MASK:
    .byte $0C, $03

PHASE_STEP:
    .byte $04, $01

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
    CMP #CMD_FWD
    BEQ @fwd
    CMP #CMD_REV
    BEQ @rev
    CMP #CMD_BUMP
    BEQ @bump
    
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
    LDA PHASE_MASK, X       ; Load the appropriate phase mask
    STA ZP_PHASE_MASK       ; Store it in the zero page
    LDA PHASE_STEP, X       ; Load the appropriate phase step
    STA ZP_PHASE_STEP       ; Store it in the zero page
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

@fwd:
    STA CMD_RESULT_CMD      ; Set the command result to the command before
                            ; we lose it

    ; Set the direction to forward
    LDA #$00
    BEQ @move
@rev:
    STA CMD_RESULT_CMD      ; Set the command result to the command before
                            ; we lose it

    ; Set the direction to reverse - A is already non-zero so no need
    .assert CMD_REV <> 0, error, "CMD_REV must not be 0"

    ; Fall through to move
@move:
    JSR half_step           ; Call the stepper control routine
    JMP @main_loop_ok

@bump:
    STA CMD_RESULT_CMD      ; Set the command result to the command before
                            ; we lose it

    LDX #$46                ; 0x46 = 70 = 35 full steps
@bump_loop:
    JSR half_step           ; Retains/restores X
    DEX
    BNE @bump_loop          ; Loop until X = 0
    JMP @main_loop_ok       ; Not close enough to BEQ

@reset:
    LDA #STATUS_6504_RESETTING   ; Set status to resetting
    STA STATUS_6504
    JMP (RESET)

; Half track stepper motor control routine
;
; This routine moves the disk drive head exactly 1/2 track in either direction.
; It handles proper phase sequencing and includes appropriate timing delays.
;
; INPUTS:
;   A register: Direction:
;       0 = forwards/inward/toward higher tracks
;       non-zero = reverse/outward/toward track 0
;   ZP_PHASE_MASK: Phase mask for the selected drive
;   ZP_PHASE_STEP: Phase increment value for the selected drive
;
; OUTPUTS:
;   None. Head position is changed by 1/2 track.
;
; REGISTERS AFFECTED:
;   X restored, A and Y modified
;
; MEMORY LOCATIONS USED:
;   VIA_PBD ($40) - VIA Port B for stepper control
;
half_step:
    PHA                     ; Save original A value for direction check

    ; Isolate current phase bits for this drive
    LDA VIA_PBD             ; Get current port value
    AND ZP_PHASE_MASK       ; Isolate just the phase bits for this drive
    STA ZP_PHASE_CURRENT    ; Store current phase in zero page

    ; Get non-stepper bits to preserve them
    LDA VIA_PBD          
    EOR ZP_PHASE_CURRENT    ; Clear out just the phase bits, preserve others
    STA ZP_NON_STEP_BITS    ; Store non-stepper bits in zero page

    ; Determine direction and calculate new phase
    PLA                     ; Restore direction value to A
    
    ; If A=0, move forwards (increment phase)
    ; If A!=0, move backwards (decrement phase)
    BEQ @forwards

; Backwards    
    ; Move toward track 0 (backwards/lower tracks)
    LDA ZP_PHASE_CURRENT    ; Get current phase from zero page
    SEC                     ; Set carry for subtraction
    SBC ZP_PHASE_STEP       ; Subtract phase increment
    AND ZP_PHASE_MASK       ; Ensure result stays within valid range
    JMP @update_phase
    
@forwards:
    ; Move toward higher track numbers (forwards)
    LDA ZP_PHASE_CURRENT    ; Get current phase from zero page
    CLC                     ; Clear carry for addition
    ADC ZP_PHASE_STEP       ; Add phase increment
    AND ZP_PHASE_MASK       ; Ensure result stays within valid range

@update_phase:
    ; Update the stepper motor phase bits
    ORA ZP_NON_STEP_BITS    ; Combine with preserved non-stepper bits
    STA VIA_PBD             ; Update hardware register
    
    ; Wait for stepper to stabilize
    JSR step_delay
    
    RTS

; Delay Subroutine - provides approximately 7.7ms delay for stepper 
; stabilization time
;
; Cycle timing at 1MHz (1 cycle = 1μs):
; - Inner loop: DEY (2 cycles) + BNE (3/2 cycles)
;   * 254 iterations with branch taken: 254 × (2+3) = 1270 cycles
;   * 1 final iteration with branch not taken: 1 × (2+2) = 4 cycles
;   * Total inner loop: 1274 cycles ≈ 1.27ms
; - Outer loop (6 iterations): 
;   * LDX initial: 2 cycles
;   * LDY (2) + inner loop (1274) + DEX (2) + BNE (3/2) = 1281/1280 cycles per
;     iteration
;   * Final RTS: 6 cycles
;   * Total: 7693 cycles ≈ 7.7ms
; 
; Restores X register
step_delay:
    TXA
    PHA

    LDX #$06            ; Outer loop counter (6 iterations) - 2 cycles

@outer:
    LDY #$FF            ; Inner loop counter (255 iterations) - 2 cycles

@inner:
    DEY                 ; Decrement inner counter - 2 cycles
    BNE @inner          ; Loop until inner counter = 0 - 3 cycles (2 on last iteration)

    DEX                 ; Decrement outer counter - 2 cycles
    BNE @outer          ; Loop until outer counter = 0 - 3 cycles (2 on last iteration)

; End of delay loop
    PLA
    TAX

    RTS                 ; Return from subroutine - 6 cycles
