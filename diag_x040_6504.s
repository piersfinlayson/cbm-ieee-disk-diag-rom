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

; Locations of registers
VIA_PBD = $40
VIA_PBDD = $42
VIA_ACR = $4B
VIA_PCR = $4C
VIA_IER = $4E
RRIOT_PBDDR = $83

; Zero page usage
ZP_DRIVE = $00

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
.ifdef TEST_DRIVE    
    CMP #CMD_TEST_DRIVE
    BEQ @test_drive_check
.endif
    CMP #CMD_RESET
    BEQ @reset_check
    BNE @main_loop          ; If not, loop back and check again

.ifdef TEST_DRIVE    
; Test drive
@test_drive_check:
    ; Check if CMD2 is also set to run
    LDA CMD2
    CMP #CMD_TEST_DRIVE
    BNE @main_loop          ; If not, loop back and check again

    ; Run the drive test
    JSR test_drive          ; Jump to the test drive routine

    ; Done, jump back to main loop
    JMP @main_loop
.endif

; Reset command
@reset_check:
    ; check if CMD2 also set to run
    LDA CMD2
    CMP #CMD_RESET
    BNE @main_loop          ; If not, loop back and check again

    ; Run the reset command
    JMP reset

reset:
    LDA #STATUS_6504_RESETTING   ; Set status to resetting
    STA STATUS_6504
    JMP (RESET)

.ifdef TEST_DRIVE
test_drive:
    ; Load command variable (drive number) before anything else in case it
    ; gets changed by 6502 shortly
    LDY CMD_VAR
    STY ZP_DRIVE

    ; Set status
    LDA #STATUS_6504_TESTING_DRIVE  ; Set status to testing drive
    STA STATUS_6504

    ; Turn on drive motor for this drive - 1 is off, 0 on.  As we turned it
    ; off when starting up, we just need to toggle it now.
    LDA VIA_PBD
    LDY #$01
    EOR motor_bits,Y         ; Toggle it
    STA VIA_PBD
    LDX #$80
    JSR delay

    LDY #$01
    EOR motor_bits,Y         ; Toggle it
    STA VIA_PBD
    LDX #$80
    JSR delay

    LDY #$01
    EOR motor_bits,Y         ; Toggle it
    STA VIA_PBD
    LDX #$80
    JSR delay

    LDY #$01
    EOR motor_bits,Y         ; Toggle it
    STA VIA_PBD
    LDX #$80
    JSR delay

    ; Wait for a second
    LDX #$00
    JSR delay
    LDX #$00
    JSR delay
    LDX #$00
    JSR delay
    LDX #$00
    JSR delay
    LDX #$00
    JSR delay

    ; Note delay overwrites X and Y

    ; Turn off drive motor for this drive
    LDY ZP_DRIVE
    LDA VIA_PBD
    EOR motor_bits,Y         ; Toggle it
    STA VIA_PBD

    ; Finished
    LDA CMD1                ; Store the command we ran
    STA CMD_RESULT_CMD

    LDA #CMD_RESULT_OK      ; Store the result
    STA CMD_RESULT

    LDA #CMD_NONE           ; Clear the last command
    STA CMD2
    STA CMD1

    LDA #STATUS_6504_RUNNING ; Set status to back to running
    STA STATUS_6504

    RTS

; Delay routine - X is the number of times to loop, roughly 1/256 of a second
;
delay:
@x_loop:
    LDY #$00        ; Y will count from 0 (256 iterations)
@y_loop:
    NOP             ; 2 cycles
    NOP             ; 2 cycles 
    NOP             ; 2 cycles
    NOP             ; 2 cycles
    NOP             ; 2 cycles
    DEY             ; 2 cycles
    BNE @y_loop     ; 3/2 cycles
    DEX             ; 2 cycles
    BNE @x_loop     ; 3/2 cycles
    RTS             ; 6 cycles

; VIA_B_OUT bits to control drive motor for drives 0 and 1
motor_bits:
    .byte $A0, $50
.endif
