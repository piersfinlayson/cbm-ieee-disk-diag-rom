; Diagnostics ROM for the Commodore 2040, 3040 and 4040 disk drives.
;
; Copyright (c) 2025 Piers Finlayson <piers@piers.rocks>
;
; Licensed under the MIT License.  See [LICENSE] for details.
;
; See [README.md] for build and usage instructions.

; Version numbers
MAJOR_VERSION = $00
MINOR_VERSION = $01
PATCH_VERSION = $00
RESERVED = $00

; Constants

; Zero page constants
ZP = $00
TEST_PTR = $00
TEST_LOW_BYTE = $00
TEST_HIGH_BYTE = $01
RAM_BYTE_TEST = $02             ; Can be re-used after RAM test subroutine
RAM_ERROR_CHIP_NUM = $03        ; Can be re-used after RAM error subroutine
RAM_ERROR_FLASH_COUNT = $04     ; Can be re-used once RAM error subroutine
DELAY_TEMP_X = $05              ; Can be re-used when delay subroutine not
                                ; being used
DELAY_TEMP_Y = $06              ; Can be re-used when delay subroutine not
                                ; being used
DEVICE_ID = $07                 ; Do not re-use

; RIOT chip addresses
RIOT_UE1_PBD = $0282
RIOT_UE1_PBDD = $0283

; LED bit masks
ERR_LED = $20
DR0_LED = $10
DR1_LED = $08
ALL_LEDS = ERR_LED | DR0_LED | DR1_LED

; Macros

; Helper macro for Commodore-style strings, which are terminated with the last
; byte having the high bit set.  Saves us a byte and is slightly easier to
; test when the string terminates.
.macro CbmString str
    .repeat .strlen(str)-1, i
        .byte .strat(str, i)
    .endrepeat
    .byte .strat(str, .strlen(str)-1) | $80
.endmacro

; Set first byte to $55 to indicate that this is a valid diagnostics ROM, if
; located at $D000.
;
; Follow that by the version number, which is 3 bytes long.
; We want the diagnostics ROM entry point to be at $D005, so we pad with
; another byte and then jump to the start of the zero-page tested and stack
; enabled part of our code.
.segment "DIAGS"
.byte $55
.byte MAJOR_VERSION
.byte MINOR_VERSION
.byte PATCH_VERSION
.byte RESERVED
    JMP d000_rom_start  ; Jump to the start of the code - we ship the zero page
                        ; test, and setting up the stack, as the main ROM has
                        ; already done that when we're the dignostics ROM.  No
                        ; point in JSR and RTS here, as the main ROM JMPs to us.

.segment "DATA"
AuthorString: CbmString "piers.rocks"

.segment "CODE"
start:
    CLD             ; Clear decimal mode
    SEI             ; Disable interrupts
    LDA #ERR_LED    ; Turn on ERR LED.  We deliberately only turn on the ERR
                    ; LED, as all three LEDs are lit before we do this - it
                    ; shows we are alive
    STA RIOT_UE1_PBD
    LDA #ALL_LEDS   ; Set LED pins to outputs
    STA RIOT_UE1_PBDD

; Test the zero page.  This is a very similar routine to that used in the
; stock DOS 1.2 ROM, 901468-06/07.
zp_test:
    LDX #$00    ; Initialize X to 0 (start point for zero page RAM test)
    LDY #$55    ; Load Y with $55 (01010101 - test pattern)
@fill:
    STY ZP,X    ; Store test pattern in zero page location X
    DEX         ; Decrement X (note: wraps from 0 to 255)
    BNE @fill   ; Loop until all zero page locations are filled with test
                ; pattern
@test:
    LDA #$AA        ; Load A with $AA (10101010 - complement of test pattern)
    ASL ZP,X        ; Shift left memory at ZP+X (turns $55 into $AA)
    EOR ZP,X        ; XOR with memory (should be 0 if memory working)
    STA ZP,X        ; Store result in memory
    BNE @error      ; If not zero, memory failed - jump to bad zero page
                    ; handler
    DEX             ; Decrement X
    BNE @test       ; Loop until all zero page locations are verified
    JMP setup_stack ; All zero page locations are verified, so jump to
                    ; setup_stack
@error:
    JMP zp_error    ; Jump to zero page error handler

; Setup the stack, which shadows the zero page - hence there's no need to
; test the stack memory.  We do this after testing the zero page.
setup_stack:
    LDX #$FF    ; Set up stack pointer
    TXS         ; Set up stack pointer to $1FF

; Betwen tests - had to wait til stack was setup before calling
d000_rom_start:
    JSR between_tests

; Run the RAM test
;
; RAM is located at $1000-$13FF, $2000-$23FF, $3000-$33FF and $4000-$43FF.
ram_test:
    LDX #$10    ; Initialize X to $10 (high byte for RAM test)
    LDY #$00    ; Initialize Y to $00 (low byte for RAM test)
@led_pattern:
    ; This creates a pattern with the LEDs to indicate which page is being
    ; tested.  DR1 LED is on for $1xxx.  DR0 LED is on for $2xxx.  DR1 and
    ; DR2 are on for $3xxx. The ERR LED is on for $4xxx.
    ; high byte location is $x0, and the lower most LED bit is PB3, we need to
    ; shift the high byte right by 1 bit after getting rid of the low nibble.
    TXA                 ; Load page number
    AND #$70            ; Isolate the bits we're interested in
    LSR A               ; Shift right by 1 bit to get the value to write to
                        ; the 6532
    STA RIOT_UE1_PBD    ; Store to the LED register
@y_loop:
    ; Test with various patterns
    LDA #$55
    JSR ram_byte_test
    LDA #$AA
    JSR ram_byte_test
    LDA #$A5
    JSR ram_byte_test
    LDA #$5A
    JSR ram_byte_test
    LDA #$24
    JSR ram_byte_test
    LDA #$42
    JSR ram_byte_test
    LDA #$00
    JSR ram_byte_test
    LDA #$FF
    JSR ram_byte_test
    ; Check if we should continue testing this page
    INY         ; Increment Y
    BNE @y_loop ; Loop until all bytes in the page are filled with test
                ; pattern
    ; See if we are done with the current RAM chip - we test up to $x3FF
    INX         ; Once that's done, increment X (page number)
    TXA         ; Copy X to A
    AND #$03    ; Isolate the first 2 bits
    BNE @led_pattern    ; If X is not a multiple of 4, loop back to test
                        ; next page
    ; We are done with the current RAM chip.  Increment the page number by
    ; $10, to move to the next RAM chip
    TXA         ; Reload the upper byte of the address
    AND #$F0    ; Isolate the upper nibble (the page number)
    CLC         ; Clear carry bit to avoid affecting the add - although it
                ; probably wasn't set
    ADC #$10    ; Add $10 to the page number (moves from $1000 to $2000,
                ; $2000 to $3000, etc)
    TAX         ; Store the new page number in X
    CPX #$50    ; Check if we are done with the RAM test
    BNE @led_pattern    ; Starting testing the next chip

; Betwen tests
    JSR between_tests

; Get the hardware configured device ID from the drive.
; Lines PB0, PB1 and PB2 are used to select this.  If they are low, they are
; 0.  PB0 is the least significant bit, PB2 is the most significant bit.
get_device_id:
    LDA #$00            ; Clear A
    STA RIOT_UE1_PBD    ; Set all LEDs off
    LDA RIOT_UE1_PBD    ; Read port B status from the RIOT chip
    AND #$07            ; Just select the 3 least significant bits
    ORA #$08            ; Add 8 to get the device ID.
    STA DEVICE_ID       ; Store the device ID in zero page

; Betwen tests
    JSR between_tests

; Our diagnostics routine is now done, so we turn off the ERR LED and flash
; flash the DR0 and DR1 LEDs a number of times to co-incide with our device ID.
; Then pause for 1 second and start again.
finished:
    LDA #$00                    ; Initialize the flash count to 0
    ; Pause before starting
    LDX #$B0                    ; Set X to $B0 (0.75 second delay, added to
                                ; 0.25s delay at end of last flash = 1s)
    JSR delay                   ; Call delay routine
    LDX #$40                    ; Set X to 64 (~0.25s delay)
@flash_loop:
    CMP DEVICE_ID               ; Compare the flash count with the device ID
    BEQ finished                ; If equal, we are done flashing the LEDs this
                                ; time around
    LDY #(DR0_LED | DR1_LED)    ; Set DR0 and DR1 LEDs on
    STY RIOT_UE1_PBD
    JSR delay                   ; Call delay routine
    LDY #$00                    ; Turn off all LEDs
    STY RIOT_UE1_PBD
    JSR delay                   ; Call delay routine
    CLC                         ; Clear carry bit before adding just in case
    ADC #$01                    ; Increment the flash count
    JMP @flash_loop             ; Loop back to flash the LEDs again

; ram_byte_test
;
; Test pattern is provided in the accumulator.
; High byte of the address is in the X register, and the low byte is in
; the Y register.  The test pattern is in the accumulator.
; The address to be tested is stored to the TEST_PTR zero page location,
; high byte and low byte.
; Stores it in the RAM location to be tested, which is pointed to by the
; TEST_PTR zero page location.
; Stores an interverted test pattern in RAM_BYTE_TEST zero page location.
; Reads back the byte from the RAM location, and XORs it with the inverted
; test pattern.  If the result is not zero, the RAM test has failed.
; JSRs to ram_error subroutine, in case I want that routine to return and
; continue running in the future.
ram_byte_test:
    STX TEST_HIGH_BYTE  ; Store page number in zero page
    STY TEST_LOW_BYTE   ; Store byte in zero page
    LDY #$00            ; Clear Y register
    STA (TEST_PTR),Y    ; Store test pattern in the appropriate RAM address
    EOR #$FF            ; Invert the test pattern
    STA RAM_BYTE_TEST   ; Store inverted test pattern in zero page
    LDA (TEST_PTR),Y    ; Read back the byte from RAM
    EOR RAM_BYTE_TEST   ; XOR with the inverted test pattern
    EOR #$FF            ; Check the result was all 1s but EORing with $FF
    BEQ @return         ; If zero, test succeeded, so return
    JSR ram_error       ; If not zero, test failed, so report error
@return:
    LDY TEST_LOW_BYTE   ; Reload Y register (no need to reload X, we didn't
                        ; change it)
    RTS                 ; Return from subroutine

; Zero page test failed.  Flash all ERR LED and specific drive LED, with 0.5s
; delay between flashes.  X indicates which byte failed.  We start at byte 0,
; then go down (255, 254 ... 1).  So If UC1 is dead, that failure will be
; detected first ($00), then UE1 ($FF).
; As we have no zero page, we also have no stack, so we have to inline the
; delay routine here.
zp_error:
    LDA #(ERR_LED | DR1_LED)    ; Set ERR LED and DR1 LED on to show error in
                                ; left hand 6532, UE1 - guess at this stage
    CPX #128                    ; Compare X with 128
    BCS @toggle_leds            ; If X >= 128, jump to toggle_leds - as we were
                                ; right about which 6532 has failed
    LDA #(ERR_LED | DR0_LED)    ; Set ERR LED and DR0 LED on to show error in
                                ; right hand 6532, UC1
@toggle_leds:
    EOR #$01    ; Toggle bit 0 of the LED pattern, which indicates whether the
                ; LEDs should be on or off
    ; Figure out if we should turn the LEDs on or off
    TAY                 ; Save full value in Y
    AND #$01            ; Isolate bit 0
    BEQ @leds_off       ; If bit 0 is 0, LEDs should be off
    ; Turn LEDs on
    TYA                 ; Restore our LED pattern
    AND #ALL_LEDS       ; Isolate the LED bits - remove bit 0 before writing
                        ; to the register
    STA RIOT_UE1_PBD    ; Store to LED register
    EOR #$01            ; Now restore bit 0
    JMP @delay          ; Continue to delay
@leds_off:
    LDA #$00            ; Turn all LEDs off
    STA RIOT_UE1_PBD    ; Store to LED register
    TYA                 ; Restore our LED pattern, with bit 0 unset
@delay:
    LDX #$80    ; Set X to 128 (~0.5s delay)
@x_loop:
    LDY #$00    ; Y will count from 0 (256 iterations)
@y_loop:
    NOP         ; 2 cycles
    NOP         ; 2 cycles 
    NOP         ; 2 cycles
    NOP         ; 2 cycles
    NOP         ; 2 cycles
    DEY         ; 2 cycles - if Y is 0, it will wrap to 255 before the branch
    BNE @y_loop ; 3/2 cycles
    DEX         ; 2 cycles - if X is 0, it will wrap to 255 before the branch
    BNE @x_loop ; 3/2 cycles
    JMP @toggle_leds    ; We're done - jump back to toggle LEDs


; RAM test failed.
;
; Zero page contains the address of the failed RAM location.  The upper byte
; will be $10, $20, $30 or $40.  We will use the upper nibble to decide how
; many flashes to do - 1 for $1000, 2 for $2000, 3 for $3000 and 4
; for $4000.  $1000 is, UC5/UC4, $2000 is UD5/UD4, $3000 is UE5/UE4 and
; $4000 is UF5/UF4.
;
; We will set ERR LED solid, and flash the drive 1 LED (DR1) to identify the
; failed RAM chip.  Once done with our flashes, we will turn off the ERR LED
; for 1s and then start again.
ram_error:
    LDA TEST_HIGH_BYTE  ; Load A with the upper byte of the failed address
    LSR A               ; Shift right 4 times to get the failed chip number
    LSR A
    LSR A
    LSR A
    STA RAM_ERROR_CHIP_NUM  ; Store the chip number in zero page
@begin:
    LDA #$00    ; Load A with 0 - counter for the number of flashes done so far
    LDX #$40    ; Set flash delay to 1/4 second
    CLC         ; Clear carry bit before adding, below
@flash_loop:
    LDY #ERR_LED | DR1_LED  ; Set ERR LED and DR1 LED on to show error
    STY RIOT_UE1_PBD
    JSR delay               ; Call delay routine
    ; Test if we are done flashing the LED this time around
    ADC #$01                ; Increment flash count
    CMP RAM_ERROR_CHIP_NUM  ; Compare with the number of flashes to do
    BEQ @pause_flashing     ; If done flashing finish up
    ; Turn off the DR1 LED, leaving ERR on
    LDY #ERR_LED            ; Turn off DR1 LED, leave ERR on
    STY RIOT_UE1_PBD
    JSR delay               ; Call delay routine with same delay as before
    JMP @flash_loop         ; Loop back to flash the LED again
@pause_flashing:
    ; We have flashed the right number of times - so now turn both LEDs off
    ; and pause for 1 second
    LDY #$00            ; Turn off all LEDs
    STY RIOT_UE1_PBD
    LDX #$00            ; Set delay to 1s
    JSR delay           ; Call delay routine
    JMP @begin ; Loop back to start flashing the LEDs

; Routine to pause for 1s, flash all LEDs briefly, then pause again for 1s, to
; mark the transition from one test to the next.
between_tests:
    LDX #$00            ; Set X to 0 (1s delay)
    STX RIOT_UE1_PBD    ; Turn off all LEDs
    JSR delay           ; Call delay routine

    LDX #$40            ; Set X to 64 (0.25s delay)
    LDA #ALL_LEDS       ; Set all LEDs on
    STA RIOT_UE1_PBD
    JSR delay

    LDX #$00            ; Set X to 0 (1s delay)
    STX RIOT_UE1_PBD    ; Turn off all LEDs
    JSR delay           ; Call delay routine

    RTS                 ; Return

; Configurable delay routine.
;
; Can only be used once we have a tested zero page, and have set up the stack.
;
; Input: X register = number of 1/256th second units to delay.
; Uses the Y register and but restores it afterwards.
;
; The timing of this routine is rough - it delays slightly under the requested
; time.
delay:
    STX DELAY_TEMP_X    ; Save X register
    STY DELAY_TEMP_Y    ;  Save Y register
@x_loop:
    LDY #$00            ; Y will count from 0 (256 iterations)
@y_loop:
    NOP                 ; 2 cycles
    NOP                 ; 2 cycles 
    NOP                 ; 2 cycles
    NOP                 ; 2 cycles
    NOP                 ; 2 cycles
    DEY                 ; 2 cycles
    BNE @y_loop         ; 3/2 cycles
    DEX                 ; 2 cycles
    BNE @x_loop         ; 3/2 cycles
    LDX DELAY_TEMP_X    ; Restore X register
    LDY DELAY_TEMP_Y    ; Restore Y register
    RTS                 ; 6 cycles

; Our no-op interrupt handler
empty_handler:
    RTI

; If we're installed as the $F000 ROM, we need to provide a jump vector to
; START.
.segment "VECTORS"
.addr empty_handler ; NMI handler
.addr start
.addr empty_handler ; IRQ handler