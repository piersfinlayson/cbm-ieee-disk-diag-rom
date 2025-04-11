; Diagnostics ROM for the Commodore 2040, 3040 and 4040 disk drives.
;
; Copyright (c) 2025 Piers Finlayson <piers@piers.rocks>
;
; Licensed under the MIT License.  See [LICENSE] for details.
;
; See [README.md] for build and usage instructions.

CPU_6502 = 1
.include "shared.inc"

; Version numbers
MAJOR_VERSION = $00
MINOR_VERSION = $01
PATCH_VERSION = $03
RESERVED = $00

; Constants
.include "zero_page_6502.inc"
.include "constants_6502.inc"

; Set first byte to $55 to indicate that this is a valid diagnostics ROM, if
; located at $D000.
;
; Follow that by the version number, which is 3 bytes long.
;
; We want the diagnostics ROM entry point to be at $D005, so we pad with
; another byte and then jump to the start of the zero-page tested and stack
; enabled part of our code.
.segment "DIAGS"
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

.segment "DATA"
CopyrightString: .asciiz "(c) 2025 Piers Finlayson"
RepoString: .asciiz "https://github.com/piersfinlayson/cbm-ieee-disk-diag-rom"

; Pages to test in our first RAM test
RamTest1:
    .byte $11, $12, $13
    .byte $20, $21, $22, $23
    .byte $30, $31, $32, $33
    .byte $40, $41, $42, ($43 | $80)

; Pages to test in our second RAM test
RamTest2:
    .byte ($10 | $80)

; Map low nibble of page number to LEDs to light
RamTestLedPattern:
    .byte DR0_LED, DR1_LED, DR0_LED, DR1_LED

; Byte patterns used to test RAM.  Finish with 0 to leave the RAM in that
; state.
RamTestBytePattern:
    .byte $FF, $55, $AA, $A5, $5A, $24, $42, $00

.segment "CODE"
start:
    CLD             ; Clear decimal mode
    SEI             ; Disable interrupts
    LDA #DR01_LEDS  ; Turn on DR0 and DR1 LEDs for the zero page test.
                    ; We deliberately don't turn on the ERR LED, as there is
                    ; no error to report yet, and so this differentiates
                    ; between the CPU not booted (all LEDs lit) and now 
    STA RIOT_UE1_PBD
    LDA #ALL_LEDS   ; Set LED pins to outputs
    STA RIOT_UE1_PBDD

; Test the zero page.  This is a very similar routine to that used in the
; stock DOS 1.2 ROM, 901468-06/07.
;
; We don't have zero page, stack or static RAM at this point as it's all
; untested.  Therefore we only have A, X and Y registers to work with.  We
; could also use S (via TXS and TSX).
;
; If this routine complete successfully, it has zeroed the entire zero page.
zp_test:
    LDX #$00        ; Initialize X to $00 (will wrap, so we start at $FF)
    LDY #$55        ; Load Y with $55 (01010101 - test pattern)
@fill:
    DEX             ; Decrement X (note: wraps from 0 to 255 first time)
    STY ZP,X        ; Store test pattern in zero page location X
    BNE @fill       ; Loop until all zero page locations are filled with test
                    ; pattern
@test:
    DEX             ; Decrement X (note: wraps from 0 to 255 first time)
    LDA #$AA        ; Load A with $AA (10101010 - complement of test pattern)
    ASL ZP,X        ; Shift left memory at ZP+X (turns $55 into $AA)
    EOR ZP,X        ; XOR with memory (should be 0 if memory working)
    STA ZP,X        ; Store result in memory
    BNE @error      ; If not zero, memory failed - jump to bad zero page
                    ; handler
    LDA #$00        ; Initialize tested location to 0
    STA ZP,X
    CPX #$00        ; Check if we've done all zero page locations
    BNE @test       ; Loop until all zero page locations are verified
    BEQ @done       ; We're done
@error:
    CPX #$80         ; Test if the upper zero page (UE1 failed)
    BCS zp_error    ; It did, jump to final error handler - we won't do any
                    ; further testing, as a broken UE1 is fatal.

    ; No, failure was in UC1.  This means the UE1 zero page is OK - as we
    ; test that first.  Hence we can set the result, and then move on to the
    ; next test.
    LDX #ZP_UC1     ; Set the ZP result
    STX RESULT_ZP
@done:
    LDA #TEST_ZP    ; Mark this test has having been performed
    STA TESTS_6502  ; Store result in zero page

; Setup the stack, which shadows the zero page - hence there's no need to
; test the stack memory.  We do this after testing the zero page.
setup_stack:    
    LDX #STACK_PTR
    TXS

; From this point onwards we have a stack, so can start calling subroutines.
; Each test is executed with a call to between_tests between them.  This blinks
; the drive LEDs to indicate a test completed and the next one will be run.
;
; This is also our $D000 ROM entry point, JMPed to by $D005, as when we are
; launched as a diagnostics ROM, the main $F000/$E000 ROMs have already tested
; zero page and set up the stack.
with_stack_main:
    JSR between_tests

    JSR get_device_id

    JSR between_tests

    ; Run first RAM test - this tests all static RAM expect that which the
    ; 6504 might be accessing ($1000-$10FF).
    LDX #<RamTest1          ; Load low byte of test table address
    LDY #>RamTest1          ; Load high byte of test table address
    JSR test_ram_table      ; Call routine to test the RAM
    LDA #TEST_RAM1          ; Mark this test as having been performed
    ORA TESTS_6502
    STA TESTS_6502          ; Store result in zero page
    JSR check_ram_result    ; Check we can continue

    JSR between_tests

    ; Take control of the 6504
    JSR control_6504

    JSR between_tests

    ; Run the second RAM test - this tests $1000-$10FF now we've attempted to
    ; take control of the 6504.  (If we failed it's likely the 6504 isn't
    ; running anyway.)
    LDX #<RamTest2          ; Load low byte of test table address
    LDY #>RamTest2          ; Load high byte of test table address
    JSR test_ram_table      ; Call routine to test the RAM
    LDA #TEST_RAM2          ; Mark this test as having been performed
    ORA TESTS_6502
    STA TESTS_6502          ; Store result in zero page
    JSR check_ram_result    ; Check we can continue

    JSR between_tests

    JMP finished
with_stack_main_end:
; End of main test routine

; Get the hardware configured device ID from the drive.
; Lines PB0, PB1 and PB2 are used to select this.  If they are low, they are
; 0.  PB0 is the least significant bit, PB2 is the most significant bit.
; Device IDs are generally expected to be between 8-15, so we have to add 8 to
; the result.
get_device_id:
    LDA RIOT_UE1_PBD    ; Read port B status from the RIOT chip
    AND #$07            ; Just select the 3 least significant bits
    ORA #$08            ; Add 8 to get the device ID.
    STA DEVICE_ID       ; Store the device ID in zero page
    LDA #TEST_DEV_ID    ; Mark this test as having been performed
    ORA TESTS_6502
    STA TESTS_6502      ; Store result in zero page
    RTS

; Zero page test failed.  Flash all ERR LED and specific drive LED, with 0.5s
; delay between flashes.  X indicates which byte failed.  We start at byte 0,
; then go down (255, 254 ... 1).  So If UC1 is dead, that failure will be
; detected first ($00), then UE1 ($FF).
;
; As we have no zero page, we also have no stack, so we have to inline
; everything.
zp_error:
    LDA #ERR_AND_1_LED      ; Set ERR LED and DR1 LED on to show error in left
                            ; hand 6532, UE1 - guess at this stage
    CPX #$80                ; Compare X with 128
    BCS @toggle_leds        ; If X >= 128, jump to toggle_leds - as we were
                            ; right about which 6532 has failed
    LDA #(ERR_AND_0_LED)    ; Set ERR LED and DR0 LED on to show error in right
                            ; hand 6532, UC1
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
    BEQ @toggle_leds    ; We're done - jump back to toggle LEDs

; Our diagnostics routine is now done, so we go through and report:
; - any errors
; - the device ID
;
; We do this in a loop, forever.
finished:
    JSR between_reports ; Pause
    JSR report_zp       ; Report zero page errors, if any
    JSR report_ram      ; Report RAM errors, if any
    JSR report_6504     ; Report 6504 errors, if any
    JSR report_dev_id   ; Report the device ID, if we have it
    JMP finished        ; Restart sequence

; Report any zero page error(s)
;
; Uses RESULT_ZP (set by the zero page test)
;
; Destroys A, X and Y
report_zp:
    ; Don't bother checking whether we did the zero page test - we know we
    ; did if we get here.

    ; Handle ZP error notifications
    LDA RESULT_ZP       ; Load the result of the zero page test
    .assert ZP_UC1 = $01, error, "ZP_UC1 is not first bit"
    .assert ZP_UE1 = $02, error, "ZP_UE1 is not second bit"
    LSR A               ; Shift right to see if UC1 zero page test failed
    STA NRZP            ; Store off zp test result variable
    BCC @ue1_check      ; If not, skip to next ZP check

    ; UC1 zero page test failed - report it
    LDA #$05            ; Flash 5 times for zero page error
    LDY #DR0_LED        ; Set DR0 LED on to show error in right hand 6532, UC1
    LDX #$40            ; Set flash delay to 1/4 second
    JSR flash_led_error
    JSR between_reports ; pause for 1s with all LEDs off

@ue1_check:
    LDA NRZP            ; Reload zp test result variable
    LSR A               ; Shift right to see if UE1 zero page test failed
    BCC @done           ; If not, skip to next check

    ; UC1 zero page test failed - report it
    LDA #$05            ; Flash 5 times for zero page error
    LDY #DR1_LED        ; Set DR0 LED on to show error in right hand 6532, UC1
    LDX #$40            ; Set flash delay to 1/4 second
    JSR flash_led_error
    JSR between_reports ; pause for 1s with all LEDs off

@done:
    RTS

; Report any RAM error(s)
;
; Uses RESULT_RAM_TEST (set by the RAM test)
;
; Destroys A, X and Y
report_ram:
    LDA TESTS_6502      ; Load the tests performed to A
    ORA #(TEST_RAM1 | TEST_RAM2)    ; Check if either RAM test 1 or 2 took place
    BEQ @done           ; If not, skip to next check

    ; One or both of the RAM tests happened - use RESULT_RAM_TEST to report
    ; failed chips
    LDA RESULT_RAM_TEST ; Load the result of the RAM test
    LDX #$08            ; Set counter to 8, to track each chip as we check it
    LDY #$01            ; Start with first chip on this nibble

@check_chip:
    LSR A               ; Shift right to see if this chip failed
    BCC @next_chip      ; If not, skip to next chip

    ; This chip failed - report it
    STA NRCR            ; Store the shifted chip result, so next time we check
                        ; the next bit (chip)
    STX NRCC            ; Store off chip counter variable
    STY NRNCN           ; Store nibble chip number

    ; Decide which LED to flash
    CPX #5              ; Check if we're doing the lower nibble (counts 8-5,
                        ; so bits 0-3)
    BCC @lower_nibble
    ; upper nibble
    LDY #DR0_LED        ; Set DR0 LED on to show error in upper nibble bank
                        ; ("lower" row of chips - U_4)
    JMP @chip_continue
@lower_nibble:
    LDY #DR1_LED        ; Set DR1 LED on to show error in lower nibble bank
                        ; ("upper" row of chips - U_5)
@chip_continue:
    ; Set up other flash_led_error parameters
    LDA NRNCN           ; Flash the LED the chip number of times
    LDX #$40            ; Set flash delay to 1/4 second
    JSR flash_led_error
    JSR between_reports ; pause for 1s with all LEDs off

    LDY NRNCN           ; Reload chip number
    LDX NRCC            ; Reload test result variable
    LDA NRCR            ; Reload the chip result
@next_chip:
    INY                 ; Increment nibble chip number
    CPY #5              ; Check if we've done all 4 chips in this nibble
    BCC @skip_y_reset   ; If not, loop back to check next chip
    LDY #$01            ; Reset Y to 1 for the first chip on the next nibble

@skip_y_reset:
    DEX                 ; Decrement chip counter
    BNE @check_chip     ; If not done, loop back to check next chip

@done:
    RTS

; Report any 6504 error(s)
;
; Uses RESULT_6504 (set by the 6504 test)
;
; Destroys A, X and Y
report_6504:
    LDA TESTS_6502      ; Load the tests performed to A
    ORA #TEST_6504_TO   ; Check if 6504 test was performed
    BEQ @done           ; If not, skip to next check
    
    LDA RESULT_6504     ; Load the result of the 6504 test
    LSR A               ; Shift right to see if the takeover failed
    BCC @done   ; If not, skip to next check

    ; 6504 test failed - report it
    LDA #$06            ; Flash 6 times for 6504 control takeover failure
    LDY #DR01_LEDS      ; Set both DR0 and DR1 LEDs to show 6504 error
    LDX #$40            ; Set flash delay to 1/4 second
    JSR flash_led_error
    JSR between_reports ; pause for 1s with all LEDs off

@done:
    RTS

; Report the device ID
;
; Destroys A, X and Y
report_dev_id:
    LDA TESTS_6502      ; Load the tests performed to A
@dev_id_check:
    ORA #TEST_DEV_ID    ; Check if device ID test was performed
    BEQ @done           ; If not, skip to next check

    LDY DEVICE_ID       ; Initialize Y to the device ID
    LDX #$40            ; Set X to 64 (~0.25s delay)
@dev_flash_loop:
    LDA #DR01_LEDS      ; Set DR0 and DR1 LEDs on
    STA RIOT_UE1_PBD
    JSR delay           ; Call delay routine
    LDA #$00            ; Turn off all LEDs
    STA RIOT_UE1_PBD
    JSR delay           ; Call delay routine
    DEY                 ; Decrement the device ID
    BNE @dev_flash_loop ; Loop back to flash the LEDs again

@done:
    JSR between_reports ; pause for 1s with all LEDs off
    RTS

; Routine to tests a table of RAM pages.
;
; Input: X,Y = Address of page table (X=low byte, Y=high byte)
; The last entry in the page table must have the high bit set.
; This routine can only test a page table up to 256 entires long
;
; Calls test_ram_page subroutine for each page in the table
; The page number is passed in the accumulator (A)
; We assume test_ram_page preserves Y
;
; Destroys A, X and Y
;
; There is an inefficiency here.  If the test for a page fails on both upper
; and lower nibbles, we stop testing that page immediately, but continue
; testing the other pages on the chip.  It's not likely to be substantial -
; it's likely the tests for the other pages will fail very early on, so we
; won't waste much time.  This is a tradeoff to keep the code simple.
test_ram_table:
    STX RP1             ; Store low byte of table address
    STY RP1+1           ; Store high byte of table address
    LDY #$00            ; Initialize index into page table
@loop:
    LDA (RP1),Y         ; Load page number to test from table
    BMI @last_page      ; If high bit is set, this is the last page
    JSR test_ram_page   ; Test this page
    INY                 ; Move to next entry in table
    BNE @loop           ; Continue
    RTS                 ; Return if we somehow exceed 256 entries
@last_page:
    AND #$7F            ; Mask off high bit to get actual page number
    JSR test_ram_page   ; Test the last page
    RTS                 ; Return

; Routine to test a specific RAM page
;
; Input: A = Page to test
;
; Restores Y when complete.  Destroys X and A.
test_ram_page:
    STY RPY                 ; Store off Y so we can restore it later
    TAX                     ; Store page number to test in X

    ; Set LED pattern to show which RAM bank (UC/UD/UE/UF) is being tested
    AND #$03                ; Isolate the bits we're interested in
    TAY                     ; Move the result to Y to index the lookup table
    LDA RamTestLedPattern,Y ; Get the LED pattern for this page
    STA RIOT_UE1_PBD        ; Store to the LED register

    ; Get the error shift count for this page, in case we need it later to
    ; properly handle any errors.  This will fill in a zero page address with
    ; it - RESC_RTN.
    JSR get_error_shift_count

    ; Initialize Y, which is used as the byte to test within the page.
    LDY #$00                ; Initialize Y to 0
; Test each byte in turn
@loop:
    ; Test the byte - X is the page number, Y is the byte number
    JSR test_ram_byte

    ; Check whether test succeeded or failed - A holds result, which is 0 for
    ; success, or $10 for lower nibble failed, $01 for upper nibble failed.
    ; Both may be set.
    CMP #$00
    BNE @error
; Carry on testing the next byte
@resume:
    INY                     ; Increment Y
    BNE @loop               ; Next byte unless we've done 256 bytes
@done:
    LDY RPY                 ; Restore Y register
    RTS
@error:
    ; In a failure case we have to:
    ; - Fill in RESULT_RAM_TEST to indicate which RAM chip failed (based on
    ;   the page number and upper/lower nibble result).
    ; - Resume testing if only lower or upper nibble has failed so far (so we
    ;   will properly test and report status if one nibble is working the other
    ;   not).
    ; - Stop testing if both nibbles in this page are duff.
    STY RPI                 ; Store index off temporarily
    LDY RESC_RTN            ; Get the error shift count
    BEQ @error_shift_done   ; No shifting required as Y is 0 - skip it
; Shift the result left by the right amount to store
@error_shift_loop:
    ASL A                   ; Shift A (the result) left
    DEY
    BNE @error_shift_loop
; A now contains the correctly shifted value so can be ORed with the stored
; results
@error_shift_done:
    ORA RESULT_RAM_TEST     ; Update test result
    STA RESULT_RAM_TEST     ; Store the new test result

    ; Continue.  We don't bother to check if both nibbles for this page has
    ; failed because it doesn't speed things up much.  (In fact, if a RAM test
    ; fails on the first pattern for each byte, it stops check that byte, so
    ; it's already much faster.)
    LDY RPI                 ; Restore index before might branch
    JMP @resume             ; No, continue

; Get the required shift count to store errors associated with a test for a
; specific RAM page/chip.
;
; The RAM test itself returns 10001 if both nibbles fail, so we shift the
; entire thing left 0-3 bit based on the page number.
;
; We store the error code in the RESULT_RAM_TEST zero page location.
; Bits 0-3 cover the lower nibble of the page number ($1x-$4x)
; Bits 4-7 cover the upper nibble of the page number ($10-$43)
;
; The shift count is therefore:
; (page number upper nibble - 1)
;
; Inputs:
; - X = page number
;
; Y is untouched and A and X restored before returning
;
; Returns error in RESC_RTN
get_error_shift_count:
    STX REX         ; Store X
    PHA             ; Store A

    ; Get upper nibble of page number
    TXA             ; Transfer page number to A
    LSR A           ; Shift right 4 times to get upper nibble
    LSR A
    LSR A
    LSR A

    ; Subtract 1 from it
    SEC             ; Set carry for subtraction
    SBC #$01        ; Take one from the page number upper nibble

    ; Store it for later use
    STA RESC_RTN  ; Store the shift count

    ; Continue processing
    PLA             ; Restore A
    LDX REX         ; Restore X
    RTS

; Tests one byte of RAM with all the desired patterns.
;
; Inputs:
; X = page number
; Y = byte number
;
; Destroys A.  Restores X and Y.
;
; Returns A as 0 if successful, otherwise 
;
; Returns A zero if successful, otherwise bit A shows which bank/nibble(s)
; failed
test_ram_byte:
    STX RP2+1                   ; Store page number
    STY RP2                     ; Store byte number
    LDY #$00                    ; Initialize Y to 0 to use as table index
@loop:
    LDA RamTestBytePattern,Y    ; Load the test pattern from the table
    STA RBPT                    ; Store the test pattern
    STY RBPI                    ; Store pattern index
    JSR test_ram_byte_pattern   ; Test this pattern

    ; Check result of the test in A.
    CMP #$00                    ; Check if the test passed
    BNE @done                   ; If not, done

    ; Test succeeeded - continue processing
    LDY RBPT                    ; Load the test pattern
    BEQ @done                   ; If we have pattern 0, that's the last one
    LDY RBPI                    ; Reload the index
    INY                         ; Increment Y to get the next pattern
    JMP @loop                   ; Go around again
@done:
    LDY RP2                     ; Restore Y register
    LDX RP2+1                   ; Restore X register
    RTS

; test_ram_byte_pattern
;
; Test pattern is provided in the accumulator.
; Address to be tested is stored in RP2.
;
; Stores it in the RAM location to be tested, which is pointed to by the
; RAM_TEST_PTR zero page location.
; Stores an interverted test pattern in RAM_BYTE_TEST zero page location.
; Reads back the byte from the RAM location, and XORs it with the inverted
; test pattern.  If the result is not zero, the RAM test has failed.
; JSRs to ram_error subroutine, in case I want that routine to return and
; continue running in the future.
;
; Destroys X, Y and A.
;
; Returns A zero if successful, otherwise bit A shows which bank/nibble(s)
; failed
test_ram_byte_pattern:
    TAX                 ; Stored test pattern in X for comparisons later
    LDY #$00            ; Clear Y register
    STY RBPY            ; Clear temporary result
    STA (RP2),Y         ; Store test pattern in the appropriate RAM address
    LDA #$00            ; Clear A with a different value
    LDA $FFFF           ; Read from a completely different address
; Check lower nibble
    LDA (RP2),Y         ; Read back the byte from RAM
    AND #$0F            ; Isolate the lower nibble
    STA RBPN            ; Store off the actual lower nibble
    TXA                 ; Load A with the expected value
    AND #$0F            ; Isolate the lower nibble
    CMP RBPN            ; Compare with the actual value
    BEQ @check_upper    ; Lower nibble good - check upper nibble
    ; Lower nibble was wrong
    LDA #$10            ; Set the error nibble value to $10 to indicate the lower
    STA RBPY            ; Store and continue
@check_upper:
    LDA (RP2),Y         ; Read back the byte from RAM (again)
    AND #$F0            ; Isolate the upper nibble
    STA RBPN            ; Store the actual upper nibble
    TXA                 ; Load A with the expected value
    AND #$F0            ; Isolate the upper nibble
    CMP RBPN            ; Compare with the actual value
    BEQ @upper_success  ; If equal, test succeeded, so return
    ; Upper nibble was wrong
    LDA RBPY            ; Load the error nibble value
    ORA #$01            ; Set the error nibble value to $01 to indicate the
                        ; upper nibble test failed
    JMP @done           ; Return
@upper_success:
    LDA RBPY            ; Reload the error value from lower
@done:
    RTS                 ; Return from subroutine

; Check whether RAM test passed for $1000-13FF.  If not, we can't continue, and
; will immediately jump to the finished routine.
check_ram_result:
    LDA RESULT_RAM_TEST ; Load RAM test result
    AND #$11            ; Check whether RAM test passed for $1000-$13FF
    BNE @error          ; Branch if it failed for that range
    RTS                 ; It passed as much as we need it to
@error:
    JMP finished        ; It failed - we can't continue, jump immediately to
                        ; the finished routine

; Attempt to take control of the 6504 processor.
;
; This is done by copying a routine to the 6504 processor to take control
; of it.  It then sits in a loop checking 2 specific bytes of shared RAM.
; Later, we will write additional command bytes, to instruct it to test
; various aspects of the 6504 and associated IC function.
;  
; We haven't actually tested the static RAM at $400-$4FF yet, which is used
; to signal to the 6504 to execute our job.  However, this can't be helped.
; We have at least checked the rest of the static RAM chips at $400-$7FF, so
; there's a decent change it'll work.  And it's not safe to test $400-$4FF
; without taking control of the 6504, as it may be trying to access the RAM
; we're testing (writing random values to).
;
; In fact, we can't guarantee the 6504 is running (or even present).  So this
; is a good test of that - we time out if we don't get a response indicating
; our takeover has succeeded.
control_6504:
    ; First of all, blink both DR1 and DR0 LEDs twice in quick succession
    ; to indicate that we are about to pause the 6504.
    LDX #$20            ; Set X to 0.25 second delay
    LDY #$20            ; Set Y to 0.25 second delay
    LDA #DR01_LEDS      ; Set LED pattern to DR0 and DR1 LEDs
    JSR blink           ; Blink twice
    JSR blink

    ; Next, try to talk to the 6504.  This will send it a bump job, which should
    ; spin the motor on one of the drive units up.  This in turn should make the
    ; 6504 allow us to execute some code on it, which will will use to take it
    ; over.
    LDA #$00            ; Try to bump drive 0
    JSR init_6504
    BEQ @takeover       ; Success - now try to take the 6504 over

    ; Takeover using drive 0 failed.  Try drive 1

    ; Let's temporarily flash the drive LED to indicate the 6504 error from
    ; bumping drive 0
    LDY #DR0_LED
    LDX #$20            ; flash delay
    JSR flash_led_error
    LDX #$00
    JSR delay

    ; Bump drive 1
    LDA #$01            ; Try to bump drive 1
    JSR init_6504
    BEQ @takeover1      ; Success - now try to take the 6504 over using drive 1

    ; Failed with drive 1 as well
    BNE @failed         ; BNE uses 1 fewer byte than JMP 

@takeover1:
    LDA #$01            ; Takeover using drive 1
@takeover:
    ; A is now set to 0 (if drive 0 worked), or 1 (if drive 1 worked)
    JSR takeover_6504

    ; Check if the 6504 has paused - takeover returns A = $00 if it has, $01 if
    ; it hasn't.  The last thing takeover_6504 does is LDA with the value, so
    ; we don't need to test it - test the Z flag directly instead.
    BEQ @done

@failed:
; Didn't succeed in taking over 6504 - so update the result bit (which should
; be zero due to zero page test leaving zero page zeroed out)

    ; Let's temporarily flash the both drive LEDs to indicate the 6504 error
    LDY #DR01_LEDS
    LDX #$20            ; flash delay
    JSR flash_led_error
    LDX #$00
    JSR delay

    ORA RESULT_6504     ; Mark takeover as failed
    STA RESULT_6504

@done:
    LDA #TEST_6504_TO   ; Mark this test as having been performed
    ORA TESTS_6502
    STA TESTS_6502      ; Store result in zero page

    ; Done
    RTS

.ifdef dont_build
; RAM test failed.
;
; We flash DR0 for the lower nibble, and DR1 for the upper nibble. 
; We flash the number of times of the upper byte top nibble (1, 2, 3 or 4).
; Together this allows the user to identify precisely which RAM chip has
; failed.
;
; Upon calling, the zero page RESULT_RAM_TEST location contains the result of
; the RAM test, with bit 1/0 being upper/lower nibble of $1X (1 being failure)
; bit 3/2 being $2X, etc.
ram_error:
    ; Figure out which DR LED to flash - accumulator contains $01 for lower
    ; nibble test failed, $02 for upper nibble.
    ASL A                   ; Shift left 3 times to set the DR LED to light
    ASL A 
    ASL A
    TAY                     ; Store the DR LED pattern in Y
    ; Figure out how many times to flash the DR LED
    LDA TEST_HIGH_BYTE      ; Load A with the upper byte of the failed address
    LSR A                   ; Shift right 4 times to get the failed chip number
    LSR A
    LSR A
    LSR A
@loop:
    ; Flash the DR LED, with ERR on, to identify the failed RAM bank
    LDX #$40                ; Set flash delay to 1/4 second
    JSR flash_led_error     ; Flash the required number of times
    ; Pause with all LEDs off for 1 second
    LDX #$00                ; Turn off all LEDs and set delay to 1s
    STX RIOT_UE1_PBD        ; Turn off all LEDs
    JSR delay               ; Call delay routine
    ; Loop back to start flashing the LEDs
    JMP @loop
.endif

; Subroutine to flash an LED pattern a specified number of times
; Input: A = number of times to flash
;        Y = LED bitmask to flash (doesn't need to include ERR_LED)
;        X = delay value
;
; A, X and Y are restored before returning.
;
; Leaves ERR LED on in case the caller wants to immediately flash more LEDs
; without the ERR LED going out.
flash_led_error:
    STA NFTC            ; Store target count
    STY NFLPO           ; Store passed in LED pattern to restore later
    TYA                 ; Save LED pattern in A
    ORA #ERR_LED        ; Set ERR LED on
    STA NFLP            ; Actual pattern to display
    LDA #$00            ; Initialize counter
    CLC                 ; Clear carry
@loop:
    ; Turn on appropriate LED, along with ERR LED
    LDY NFLP            ; Turn on LEDs
    STY RIOT_UE1_PBD
    JSR delay           ; Pause
    ; See if we're done flashing
    ADC #$01            ; Increment counter
    CMP NFTC            ; Compare with target
    BEQ @done   
    ; We're not done flashing, turn off all but ERR LED
    LDY #ERR_LED        ; Just ERR LED on
    STY RIOT_UE1_PBD
    JSR delay           ; Pause
    ; Go around the loop again
    JMP @loop
@done:
    ; Restore registers - X is never modified.
    LDY NFLPO           ; Reload Y
    LDA NFTC            ; Reload A
    RTS                 ; Return

; Routine to pause for 1s, flash all drive LEDs briefly, then pause again for
; 1s, to mark the transition from one test to the next.
;
; Destroys A, X and Y
between_tests:
    LDX #$00            ; Off for 1s 
    LDY #$40            ; On for 0.25s
    LDA #DR01_LEDS      ; Set LED pattern to both drive LEDs
    JSR blink           ; Blink
    RTS                 ; Done

; Routine to pause for 1s, between each report.
;
; Destroys X
between_reports:
    LDX #$00
    STX RIOT_UE1_PBD    ; Turn off all LEDs
    JSR delay           ; 1s delay
    RTS

; Blink LEDs.
;
; Input: X - length of delay before and after blink in 1/256th second units
;        Y - length of delay while LEDs on in 1/256th second units
;        A - LED pattern to blink
;
; A, X and Y are restored before returning.
blink:
    STX BX              ; Store X
    STY BY              ; Store Y

    LDX #$00            ; Set LEDs off
    STX RIOT_UE1_PBD
    LDX BX              ; Pause
    JSR delay

    STA RIOT_UE1_PBD    ; Turn LEDs on using pattern in A
    LDX BY              ; Pause for on time
    JSR delay

    LDX #$00            ; Set LEDs off
    STX RIOT_UE1_PBD
    LDX BX              ; Pause (also returns X to original value)
    JSR delay

    LDY BY              ; Restore Y
    RTS

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
    STX DX      ; Save X register
    STY DY      ;  Save Y register
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
    LDX DX      ; Restore X register
    LDY DY      ; Restore Y register
    RTS             ; 6 cycles

; Our no-op interrupt handler
empty_handler:
    RTI

; Attempts to takeover the 6504 processor.
;
; No inputs
;
; Will overwrite X and Y
;
; Returns with A = $00 if the 6504 has paused, $01 if it has not responded.
; Also returns Z flag set if the 6504 has paused.
takeover_6504:
    JSR copy_6504_cmd           ; Copy the 6504 control routine to shared RAM
    JSR exec_6504_job           ; Trigger the 6504 to execute this routine
    RTS

; Copy the 6504 cmd to the shared RAM, at $1100, which is job 0.
;
; Note that the max length of a code block is 256 bytes.
;
; Will overwrite A, X and Y
copy_6504_cmd:
    ; Read the offset from the binary header
    LDA CODE_6504_START     ; Get low byte of offset
    STA CP_TEMP1            ; Store in temp pointer
    LDA CODE_6504_START+1   ; Get high byte of offset
    STA CP_TEMP2            ; Store in temp pointer

    ; Calculate actual source address (CODE_6504_START + offset)
    CLC                     ; Clear carry before addition
    LDA CP_TEMP1            ; Load the low byte of the offset value
    ADC #<CODE_6504_START   ; Add the low byte of CODE_6504_START
    STA CP1                 ; Store result as low byte of source pointer
    LDA CP_TEMP2            ; Load the high byte of the offset
    ADC #>CODE_6504_START   ; Add the high byte of CODE_6504_START ($FF or
                            ; $DF) plus any carry
    STA CP1+1               ; Store result as high byte of source pointer

    ; Set up destination addresses for 6504 code we want to copy
    LDA #$00                ; Set destination to $1100
    STA CP2                 ; Store in destination address
    LDA #$11
    STA CP2+1               ; Store in destination address

    ; Do the copy, byte by byte.
    LDY #$00                ; Set Y to 0 as an index for the copy
    LDX CODE_6504_CMD_LEN   ; Get the length of the command
    BEQ @copy_done          ; If length is 0, we're done
@copy_loop:
    LDA (CP1),Y             ; Load the byte from the source address
    STA (CP2),Y             ; Store it in the destination address
    INY                     ; Increment Y
    BNE @not_wrap           ; Check if we crossed a page
    INC CP1+1               ; If so, increment high bytes
    INC CP2+1
@not_wrap:
    DEX                     ; Decrement counter
    BNE @copy_loop          ; Continue until all bytes copied
@copy_done:
    RTS                     ; Return from subroutine 

; Wait up to ~1s for the 6504 to report a certain status
;
; X contains status byte to wait for
;
; Overwrites X and Y
;
; Returns with A = $00 if the 6504 reached the state, $01 if it is not.
; This also sets the Z flag in the success case.
wait_6504_status:
    STX CWS             ; Store the status byte to check for
    LDY #$00            ; Set Y to 0 (256) for total number of times to check
@check:
    DEY                 ; Decrement Y
    BEQ @failure        ; If Y reached 0, 6504 didn't start reach desired state
    LDA STATUS_6504     ; Read the status byte
    CMP CWS             ; Check if the 6504 is in desired state
    BEQ @success
    ; It didn't - pause for ~1/256th second
    LDX #$01            ; Set delay to 1/256th second
    JSR delay           ; Call delay routine
    JMP @check          ; Loop back to check again
@success:
    LDA #$00            ; Success
    RTS                 ; Return
@failure:
    ; Must be last thing that sets the Z bit in this routine.
    LDA #$01            ; Failure
    RTS                 ; Return

; init_6504
;
; Initializes communications with the 6504 but bumping drive 0
;
; Input A = 0 bump drive 0, A = 1 bump drive 1
;
; Destroys X and Y
;
; Returns A = 0 on success, 1 on timeout, 2 and above on some other failure
init_6504:
    ORA #(JOB_BUMP | $80)   ; Bump command, or with desired drive
    STA JOB_0_SLOT          ; Store it in slot 0
    LDY #$00                ; Set Y to 0, to loop around 256 times
@loop:
    LDX #$01                ; Set delay to 1/256th second
    JSR delay               ; Pause
    LDX JOB_0_SLOT          ; Read the status byte

    ; If the job was executed, the 6504 changes the contents of the job
    ; slot, and sets 1 on success, or $02-$0B otherwise.  All of them clear
    ; the MSB - hence testing for positive.
    BPL @state_change       ; Check if the 6504 is in the desired state
    
    ; No change in job state
    DEY                     ; Decrement Y
    BNE @loop               ; Still going
    BEQ @timeout            ; If we timed out, fail
@state_change:
    CPX #01                 ; Check if the 6504 is in the desired state
    BEQ @success            ; $01 is a successful response from bump
    TXA                     ; Failure codes are 2 and above - return it
    RTS
@timeout:
    LDA #$01                ; Failure
    RTS
@success:
    LDA #$00                ; Success
    RTS

; Starts the 6504 job to execute code, using job 0, and assumes code is already
; loaded to appropriate address, 6502:$1100, 6504:$500.
;
; Overwrites X and Y.
;
; Returns A = $00 if successfully executed the job $01 otherwise.
exec_6504_job:
    ; Set shared status location state, and clear shared command locations
    LDX #STATUS_6504_NONE
    STX STATUS_6504             ; Set the status to none
    .assert CMD_NONE = STATUS_6504_NONE, error, "CMD_NONE != STATUS_NONE"
    STX CMD1              ; Set both commands to none
    STX CMD2

    ; Send the execute command 
    LDA #(JOB_EXEC | $80)   ; Send execute command
    STA JOB_0_SLOT          ; Store in job slot 0

    LDX #STATUS_6504_RUNNING
    JSR wait_6504_status
    RTS                         ; Return

; Include the 6504 binary, which is pre-built by the Makefile.  This allows us
; to copy the routine(s) we want from this binary to the shared RAM and then
; have the 6504 execute it.
.segment "CODE_6504"
.incbin "diag_x040_6504.bin"

; If we're installed as the $F000 ROM, we need to provide a jump vector to
; START.
.segment "VECTORS"
.addr empty_handler ; NMI handler
.addr start
.addr empty_handler ; IRQ handler
