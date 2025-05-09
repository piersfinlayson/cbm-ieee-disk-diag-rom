; Diagnostics ROM for the Commodore 2040, 3040 and 4040 disk drives.
;
; See [README.md] for build and usage instructions.

; Copyright (c) 2025 Piers Finlayson <piers@piers.rocks>
;
; Licensed under the MIT License.  See [LICENSE] for details.

; Exports
.export start, with_stack_main
.export nmi_handler, irq_handler

; Imports
.import secondary_start, SECONDARY_CODE_LEN
.import build_invalid_channel_str
.import talk_str_table
.import TALK_STR_TABLE_ENTRY_LEN, TALK_STR_TABLE_LEN
.import RamTest0, RamTest1, RamTests, RamTestMask
.import RamTestLedPattern, RamTestBytePattern
.import SharedRamOffsets, SharedRamInitValues

; Includes
.include "include/version.inc"
.include "include/shared.inc"
.include "include/macros.inc"
.include "include/primary/zeropage.inc"
.include "include/primary/constants.inc"

.segment "CODE"

start:
; CPU initialization.  The stock ROM also sets up the stack at this point.
; That seems premature when we haven't tested zero page - as zero page is used
; for the stack, as $100-$1FF shadows the zero page.
    CLD             ; Clear decimal mode
    SEI             ; Disable interrupts

; Set the LEDs - we do this very early, and turn off ERR LED as part of this,
; in order to indicate that the CPU has actually booted.  The stock ROM doesn't
; do this until after the zero page test.
;
; The stock ROM also sets up the IEEE-488 pins at this point.  We won't do that
; until later.
    LDA #DR01_LEDS  ; Turn DR0 and DR1 on
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
; This is also our $D000 ROM entry point, JMPed to by $D005 (where the stock
; ROM will call into the diagnostics ROM if present), as when we are launched
; as a diagnostics ROM, the main $F000/$E000 ROMs have already tested zero page
; and set up the stack.
with_stack_main:
    JSR between_tests

    JSR get_device_id

    JSR between_tests

    ; First RAM test
    LDA #$00
    JSR ram_test

    JSR between_tests

    ; Check the 6504 booted sucessfully
    JSR check_6504_booted

    JSR between_tests

    LDA RESULT_6504_BOOT    ; Check the result of the 6504 boot test
    BNE @6504_failed        ; If not, skip to next test

    ; 6504 boot test worked - so attempt to takeover the 6504
    JSR control_6504

    JSR between_tests

@6504_failed:
    LDA #$01
    JSR ram_test

    JSR between_tests

    ; Initialize the IEEE stack
    JSR ieee_init

    ; Fall through to our main flash_loop reporting errors via LED

; Our diagnostics routine is now done, so we go through and report:
; - any errors
; - the device ID
;
; We do this in a loop, forever.
flash_loop:
    JSR between_reports ; Pause
    JSR report_zp       ; Report zero page errors, if any
    JSR report_ram      ; Report RAM errors, if any
    JSR report_6504     ; Report 6504 errors, if any
    JSR report_drives   ; Report drive test errors, if any
    JSR report_dev_id   ; Report the device ID, if we have it
    JMP flash_loop      ; Go around again

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

; Check whether RAM test passed for $1000-13FF.  If not, we can't continue, and
; will immediately jump to the finished routine.
check_ram_result:
    LDA RESULT_RAM_TEST ; Load RAM test result
    AND #$11            ; Check whether RAM test passed for $1000-$13FF
    BNE flash_loop      ; Branch if it failed for that range, straight to
                        ; the flash_loop routine, skipping IEEE stack
                        ; initialization as that requires the first bank of
                        ; static RAM to be functional.
    RTS                 ; It passed as much as we need it to

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
    AND #(TEST_RAM0 | TEST_RAM1)    ; Check if either RAM test 1 or 2 took place
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
; Uses RESULT_6504 (set by the 6504 tests)
;
; Destroys A, X and Y
report_6504:
    LDA TESTS_6502          ; See if boot test was performed
    AND #TEST_6504_BOOT     ; Check if 6504 test was performed
    BEQ @done               ; Done - as takeover won't have happened either

    ; 6504 boot test was performed - check if it succeeded
    LDA RESULT_6504_BOOT    ; Load the result of the 6504 test
    BEQ @report_takeover    ; It succeeded - no error to report

    ; 6504 boot test failed - report it by flashing both LEDs 1 time
    LDA #$01            ; Flash 1 time for 6504 control takeover failure
    LDY #DR01_LEDS      ; Set both DR0 and DR1 LEDs to show 6504 error
    LDX #$40            ; Set flash delay to 1/4 second
    JSR flash_led_error
    JSR between_reports ; pause for 1s with all LEDs off

@report_takeover:
    LDA TESTS_6502      ; Check if takeover test was performed
    AND #TEST_6504_TO   ; Check if 6504 test was performed
    BEQ @done           ; If not, done

    LDA RESULT_6504_TO  ; Load the takeover result
    BEQ @done           ; It succeeded

    ; 6504 takeover test failed - report it by flashing both LEDs 2 times
    LDA #$02            ; Flash 2 times for 6504 control takeover failure
    LDY #DR01_LEDS      ; Set both DR0 and DR1 LEDs to show 6504 error
    LDX #$40            ; Set flash delay to 1/4 second
    JSR flash_led_error ; Flash the LED the number of times indicated by the
                        ; result
    JSR between_reports ; pause for 1s with all LEDs off

@done:
    RTS

; Report any drive error(s) - no-op for now
;
; Will uses RESULT_DRIVE0 and RESULT_DRIVE1 (set by the drive tests)
report_drives:
    RTS

; Report the device ID
;
; Destroys A, X and Y
report_dev_id:
    LDA TESTS_6502      ; Load the tests performed to A
    AND #TEST_DEV_ID    ; Check if device ID test was performed
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

; Run one of the static RAM tests
;
; A = which RAM test to perform - 0 or 1
;
; If A = 1 will reset_shared_ram afterwards
ram_test:
    PHA                     ; Preserve A on stack
    
    ; Calculate the offset in the RamTests table
    ASL A                   ; Multiply by 2 (for word-sized entries)
    TAY                     ; Use Y as index

    ; Load the address of the RAM test table
    LDA RamTests,Y          ; Load low byte of the address
    TAX                     ; Transfer to X for test_ram_table
    LDA RamTests+1,Y        ; Load high byte of the address
    TAY                     ; Transfer to Y for test_ram_table

    JSR test_ram_table      ; Call routine to test the RAM
    
    PLA                     ; Pull original A value from stack
    TAX                     ; Transfer to X for indexing

    ; Set the appropriate test flag
    LDA RamTestMask,X       ; Load the appropriate test mask
    ORA TESTS_6502          ; OR it with the current test flags
    STA TESTS_6502          ; Store result in zero page
    
    JSR check_ram_result    ; Check we can continue - won't return if not
    
    ; If doing second RAM test (A=1), reset shared RAM
    CPX #1
    BNE done
    JSR reset_shared_ram    ; Reset shared RAM if X = 1
done:
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


; Check that the 6504 booted successfully.
;
; We use shared memory locations to check this using the values in
; - SharedRamOffsets
; - SharedRamInitValues
;
; If any of these values are not set appropriately, it is likely 6504 has not
; booted.  It is possible that the shared RAM has failed, but we check most
; of the chips providing these locations prior to calling this, so should be
; OK.
;
; Returns A set to 0 on success, non-zero (bits set indicating which values
; were incorrect, starting as LSB) on failure.
check_6504_booted:
    ; Initialize variables
    LDY #$00                    ; Use Y as index into shared RAM offsets/values
    STY BLI                     ; Set last byte MSB to 0
    LDA #$01                    ; Set A as bit index into RESULT_6504
    STA BRBI                    ; Temporarily store off result bit index

@loop:
    LDX SharedRamOffsets,Y      ; Load then next shared RAM offset into A
    BPL @not_last               ; If positive, don't mark off as last bye
    LDA #$80                    ; Set last byte bool to true and store it
    STA BLI
    TXA                         ; Clear MSB from offset
    AND #$7F
    TAX

@not_last:
    LDA SHARED_RAM_START,X      ; Load the shared RAM value
    CMP SharedRamInitValues,Y   ; Compare with the expected value
    BEQ @check_last             ; Skip error handling if equal

    ; Error handling
    LDA BRBI
    ORA RESULT_6504_BOOT        ; Update the result
    STA RESULT_6504_BOOT        ; Store it

@check_last:
    LDA BLI                     ; Check if this was the last byte
    BMI @done                   ; If MSB set, that was the final byte
    INY                         ; Increment Y
    ASL BRBI                    ; Shift bit index left
    BCC @loop                   ; If not zero, continue - cheaper than JMP and
                                ; we can rely on clear bit being clear if we
                                ; have max 8 bytes to check
    ; No need to alternative path - should never fall through.

@done:
    LDA #TEST_6504_BOOT         ; Mark this test as done
    ORA TESTS_6502
    STA TESTS_6502

    LDA RESULT_6504_BOOT        ; Load the result into accumulator
    RTS

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
    JSR takeover_6504

    ; Check if the 6504 has paused - takeover returns A = $00 if it has, $01 if
    ; it hasn't.  The last thing takeover_6504 does is LDA with the value, so
    ; we don't need to test it - test the Z flag directly instead.
    BEQ @success

    ; Failure - mark it as such
    LDA #RESULT_6504_TO_ERR
    STA RESULT_6504_TO

@success:
    LDA #TEST_6504_TO   ; Mark this test as having been performed
    ORA TESTS_6502
    STA TESTS_6502

    ; Done
    RTS

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
    CMP #$00            ; Check if we have a count
    BEQ @return         ; If not, return

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
@return:
    RTS                 ; Return

; Routine to pause for 0.5s, flash all drive LEDs briefly, then pause again for
; 0.5s, to mark the transition from one test to the next.
;
; Destroys A, X and Y
between_tests:
    LDX #$80            ; Off for 0.5s 
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
    STX DX          ; Save X register
    STY DY          ;  Save Y register
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
    LDX DX          ; Restore X register
    LDY DY          ; Restore Y register
    RTS             ; 6 cycles

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
; Note that the max length of a code block is 255 bytes.
;
; Will overwrite A, X and Y
copy_6504_cmd:
    ; Set up the source address for the 6504 code we want to copy
    LDA #<secondary_start   ; Store the low byte of stored 6504 code
    .assert <secondary_start = $00, error, "6504 code not at $00"
    STA CP1
    LDA #>secondary_start   ; Store the high byte of stored 6504 code
    STA CP1+1

    ; Set up destination addresses for 6504 code we want to copy
    LDA #$00                ; Set destination to $1100
    STA CP2                 ; Store in destination address
    LDA #$11
    STA CP2+1               ; Store in destination address

    ; Do the copy, byte by byte.
    LDY #$00                ; Set Y to 0 as an index for the copy
    .assert SECONDARY_CODE_LEN <= $FF, error, "6504 code too long"
    LDX #<SECONDARY_CODE_LEN      ; Get the length of the 6504 code
    BEQ @copy_done          ; If length is 0, we're done
@copy_loop:
    LDA (CP1),Y             ; Load the byte from the source address
    STA (CP2),Y             ; Store it in the destination address
    INY                     ; Increment Y
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
    STX WSB             ; Store the status byte to check for
    LDY #$00            ; Set Y to 0 (256) for total number of times to check

@check:
    LDA STATUS_6504     ; Read the status byte
    CMP WSB             ; Check if the 6504 is in desired state
    BEQ @success

    ; It isn't - pause for ~1/256th second
    LDX #$01            ; Set delay to 1/256th second
    JSR delay           ; Call delay routine

    DEY                 ; Decrement Y
    BNE @check          ; Still going
    BEQ @failure        ; If we timed out, fail

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

; Returns A=0 if the 6504 takeover succeeded
;
; If A != 0 it skips whether it is in running state
check_takeover:
    STA CTA                 ; Store argument

    ; Check if test was attempted - TEST_6502 has 1 if it was
    LDA TESTS_6502
    AND #TEST_6504_TO
    BEQ @failed             ; It wasn't attempted
    
    ; Check if it succeeded - RESULT_6504_TO has 0 if it did
    LDA RESULT_6504_TO
    .assert RESULT_6504_TO_OK = 0, error, "RESULT_6504_TO_OK != 0"
    BNE @failed             ; It failed 

    ; Check if the 6504 is in the running state
    LDA CTA
    BNE @success            ; If A is non-zero we skip this test
    LDA #STATUS_6504_RUNNING
    CMP STATUS_6504
    BNE @failed             ; It's not running

@success:
    LDA #$00                ; May be non-zero if branched here
    RTS

@failed:
    LDA #$01
    RTS

; Reset the shared RAM, used by the 6504 routine, after the $1000-$10FF RAM
; test
;
; Only bothers doing this if the 6504 takeover worked
reset_shared_ram:
    LDA #$01                ; Don't check the shared RAM as part of checking if
                            ; takeover suceeeded
    JSR check_takeover
    BNE @done               ; Takeover failed - don't bother resetting

    ; Reset the 6504 shared RAM (it was left as $00 by the last RAM test, so
    ; only need to reset non-zero values)
    LDA #CMD_RESULT_NONE
    STA CMD_RESULT
    LDA #STATUS_6504_RUNNING
    STA STATUS_6504

@done:
    RTS

; Test the drive mechanisms, if the 6504 takeover worked
test_drives:
    LDA #$00                ; Check shared RAM as part of checking if the
                            ; takeover succeeded
    JSR check_takeover  
    BNE @done

    ; Test drive 0
    LDA #$00
    JSR test_drive
    JSR between_tests
    
    ; Then drive 1
    LDA #$01
    JSR test_drive

    ; Mark this test as attempted
    LDA #TEST_DRIVES
    ORA TESTS_6502
    STA TESTS_6502

@done:
    RTS

; Test one of the disk drive mechanisms
;
; A = 0 for drive 0, A = 1 for drive 1
;
; Returns A = 0 success, non-zero otherwise indicating the test step which
; failed.
test_drive:
    TXA
    LDA #$01            ; Mark as failed for now
    STA RESULT_DRIVE0,X 
    RTS

; Clears the 6504 command result data
;
; Typically done before running a command.
;
; Destroys X
clear_6504_result:
    LDX #CMD_RESULT_NONE    ; Clear command result
    STX CMD_RESULT

    LDX #CMD_NONE           ; Clear result command      
    STX CMD_RESULT_CMD

    RTS

; Initialise the IEEE-488 ports and computes device ID
;
; Destroys A
ieee_init:
    ; Initialize drive status to 73 (just booted)
    LDA #DEVICE_STATUS_BOOTED
    STA DEVICE_STATUS

    ; Initialize ports

    ; Start with the DIO lines
    ; No need to set input ports to inputs, as they are by default
    LDA #$FF
    STA IEEE_DATA_OUT_PORT  ; Set output data lines high (zeros)
    STA IEEE_DATA_OUT_DIR   ; Set output data line directions to outputs

    ; Set the control and interface management lines
    LDA #$1C
    STA IEEE_CONTROL        ; Set output NRFD, EOI, DAV high (de-asserted) 
    LDA #$1F
    STA IEEE_CONTROL_DIR    ; Set lines 0-4 to outputs, 5-7 to inputs

    ; Compute device ID - we will retrieve from hardware again, as cheaper
    LDA RIOT_UE1_PBD
    AND #$07                ; Mask off the bits we don't want
    ORA #$48                ; Create talk address adding 8 and ORing with $40
    STA OUR_TALK_ADDR
    EOR #$60                ; Create listen address - which should be $2X.
                            ; This unflips the Talk bit and sets the listen one
                            ; instead
    STA OUR_LISTEN_ADDR

    ; Enable ATN interrupts
    ; RIOT_UE1_ATNPE is the ATN interrupt enable register positive edge - we
    ; use positive edge as the IEEE-488 ATN line is inverted before it reaches
    ; UE1 (hence it actually triggers on ATN going low on the bus).
    ; I don't understand why $0A 1010 is used here, but is the value from the
    ; original ROM
    LDA #$0A
    STA RIOT_UE1_ATNPE

    ; Set interrupt handler and enable interrupts
    LDX #<ieee_irq_handler
    LDY #>ieee_irq_handler
    JSR set_irq_handler
    RTS

; IEEE-488 ATN interrupt handler
ieee_irq_handler:
    ; Save registers and LED state.  We will restore all of this before
    ; returning from the interrupt. 
    PHA
    TXA
    PHA
    TYA
    PHA
    LDA RIOT_UE1_PBD        ; Retrieve LED state
    AND #$38                ; Just store off LED pin state
    PHA
    
    ; Clear interrupt flag - 6532 datasheet says "The PA7 [ATN] flag is
    ; cleared when the Interrupt Flag Register is read."
    LDA RIOT_UE1_ATNPE

    ; Turn on DR0 and DR1 LEDs to show we're in the interrupt handler
    LDA #DR01_LEDS
    STA RIOT_UE1_PBD
    
    ; Prepare control lines
    LDA #$18                ; DAVO + EOIO - set to high
    ORA IEEE_CONTROL
    STA IEEE_CONTROL
    
    LDA #$FF                ; Clear data lines
    STA IEEE_DATA_OUT_PORT
    
@atn_wait:
    ; ATN sequence - wait for commands
    LDA #$07                ; ~DACO, RFDO, ATNA all high
                            ; As DACO is inverted, NDAC low
                            ; NRFD high
                            ; So, waiting for a byte from the controller
    ORA IEEE_CONTROL
    STA IEEE_CONTROL

@dav_wait:
    BIT IEEE_CONTROL
    BVC @atn_get_cmd        ; DAV low - command ready
    BMI @dav_wait           ; ATN still low
    BPL @atn_end            ; ATN went high - end of command sequence

@atn_get_cmd:
    ; Following sequence reads a byte from the data bus
    LDA #$FB                ; Set RFDO low - sets NRFD low
    AND IEEE_CONTROL
    STA IEEE_CONTROL
    
    AND #$20                ; Save EOI input state
    STA IEEE_EOI_FLAG
    
    LDA IEEE_DATA_IN_PORT   ; Get data from bus
    EOR #$FF                ; Invert (IEEE is negative logic)
    STA IEEE_DATA_BYTE      ; Save command byte
    
    LDA #$FD                ; Set ~DACO low, sets NDAC high
    AND IEEE_CONTROL
    STA IEEE_CONTROL
    
    ; Process command byte
    LDY #$00                ; Store 0 in Y for later use
    LDA IEEE_DATA_BYTE      ; Get our data byte 
    AND #$60                ; Check command type by checking TALK/LISTEN bits
    CMP #$40                ; Check if TALK command
    BEQ @handle_talk
    CMP #$20                ; Check if LISTEN command
    BEQ @handle_listen
    CMP #$60                ; Check if SECONDARY command
    BEQ @handle_secondary
    JMP @atn_next           ; OTHER command

; Now ATN has been raised, see if we have any work to do.
@atn_end:
    ; ATN is now high - check if we were addressed
    LDA IEEE_LISTEN_ACTIVE
    BEQ @check_talk         ; Not listener - branch to see if we're talker
    
    ; We're listener - prepare for data transfer
    LDA #$FA                ; Set ATNA and NRFD low
    AND IEEE_CONTROL
    STA IEEE_CONTROL
    
    ; Call listen handler
    JSR listen_handler

    ; Drop through to @check_talk to save a JMP and three 3 bytes.  It'll branch
    ; to @atn_exit anyway if IEEE_TALK_ACTIVE is not set.

@check_talk:
    LDA IEEE_TALK_ACTIVE
    BEQ @atn_exit           ; Not talker
    
    ; We're talker - prepare for data transfer  
    LDA #$FC                ; Set ATNA and ~DAC low, so relinquish control of
                            ; NDAC line?
    AND IEEE_CONTROL
    STA IEEE_CONTROL
    
    ; Call talk handler
    JSR talk_handler

@atn_exit:
    ; Reset control lines to idle state before leaving
    LDA #$1C
    STA IEEE_CONTROL

    ; Process the command byte if there's one.  We have to do this after
    ; the previous code to set NDAC and NRFD high again, otherwise stuff will
    ; hang the next time ATN gets pulled low.  It's possible
    ; int_process_listen_byte will not return - if it may reset the stack and
    ; cause another routine to get called.
    JSR int_process_command_byte

    ; Restore registers
    PLA
    STA RIOT_UE1_PBD        ; Restore LED state
    PLA
    TAY
    PLA
    TAX
    PLA

    ; Return
    RTI

@handle_listen:
    LDA IEEE_DATA_BYTE
    CMP OUR_LISTEN_ADDR
    BEQ @our_listen         ; Liasten is for our listen address
    CMP #$3F                ; Was this an UNLISTEN?
    BNE @not_addressed      ; Branch if not - it wasn't for us
    STY IEEE_LISTEN_ACTIVE  ; Clear listen active - Y set to 0 before this
    BEQ @not_addressed      ; Branch always - as we set Y to 0 before this
    
@our_listen:
    STA IEEE_LISTEN_ACTIVE  ; Set listen active
    STY IEEE_TALK_ACTIVE    ; Clear talk active
    LDA #$20
    STA IEEE_SEC_ADDR       ; Default secondary address
    STA IEEE_ADDRESSED      ; Mark as addressed
    BNE @atn_next           ; Branch always, as A non-zero

@handle_talk:
    STY IEEE_TALK_ACTIVE    ; Clear talk active (Y is set to zero before this)
                            ; This will also clear TALK if an UNTALK comes in
                            ; as it won't get reset before due to not matching
                            ; our address.
    LDA IEEE_DATA_BYTE      ; Get our data byte
    CMP OUR_TALK_ADDR           ; Compare with our TALK address
    BNE @not_addressed
    STA IEEE_TALK_ACTIVE    ; Set talk active
    STY IEEE_LISTEN_ACTIVE  ; Clear listen active
    LDA #$20
    STA IEEE_SEC_ADDR       ; Default secondary address
    STA IEEE_ADDRESSED      ; Mark as addressed
    BEQ @atn_next           ; Branch always (always Z=1 here)

@handle_secondary:
    LDA IEEE_ADDRESSED
    BEQ @atn_next           ; Not addressed, ignore
    LDA IEEE_DATA_BYTE
    AND #$0F                ; Just store off secondary address bits 0-3
    STA IEEE_SEC_ADDR       ; Channels 16-31 will appear to us as 0-15
    JMP @atn_next
    
@not_addressed:
    STY IEEE_ADDRESSED      ; Clear addressed flag - also handles untalk case

@atn_next:
    BIT IEEE_CONTROL        ; Wait for DAV high
    BVC @atn_next
    JMP @atn_wait           ; Get next command byte

; Handle incoming data as listener
listen_handler:
    LDA IEEE_SEC_ADDR       ; Check which channel
    CMP #$0F                ; Command channel?
    BEQ @cmd_listen         ; Handle command channel
    ; Other channels not implemented - just ignore the data
    RTS

@cmd_listen:
    ; Receive command into buffer.  We will only store 1 byte.  It will be the
    ; last one sent as part of this listen command.
@cmd_receive_loop:
    JSR receive_byte        ; Get a byte from IEEE bus
    BIT IEEE_CONTROL        ; Check ATN and unwind if pulled high
    BMI @done               ; unwind
    STA IEEE_CMD_BUF        ; Store in command buffer
    LDA IEEE_EOI_FLAG       ; Check if EOI was set
    BEQ @cmd_receive_loop   ; If not, get more bytes.  We keep the last one
                            ; and know if there's one waiting to process by it
                            ; being non-zero.  (Yes, we could get sent a zero
                            ; byte, but we don't do anything if so)
@done:
    RTS

; Handle outgoing data as talker  
talk_handler:
    LDA IEEE_SEC_ADDR       ; Check which channel.  Earlier code restricts to
                            ; 0-15 so we don't need to check

@cmd_talk:
    ; Get the channel
    LDA #$00                ; Initialize index into talk_str_table

@lookup:
    TAX                     ; Store index in X
    LDA IEEE_SEC_ADDR       ; Load the channel
    CMP talk_str_table,X
    BEQ @valid_chan         ; Found a channel

    TXA                     ; Move index back to A for maths
    CLC
    ADC #<TALK_STR_TABLE_ENTRY_LEN   ; Move onto the next entry
    CMP #<TALK_STR_TABLE_LEN ; Check if we're over the end of the table
    BCC @lookup             ; Nope, go around end

    ; We failed to find an entry - build a None string instead
    JSR build_invalid_channel_str
    JMP @transmit

@valid_chan:
    ; Get pointer to routine to build the appropriate string (at bytes 3/4)
    ; from the channel number index.
    ; As 6502 doesn't support indirect JSR, we dynamically build a JMP
    ; instruction which jumps to the routine we want.  We build it at a fixed
    ; location.  We can then JSR to it, returning us into the place we want.
    LDA talk_str_table+3,X
    STA IEEE_JMP_ADDR
    LDA talk_str_table+4,X
    STA IEEE_JMP_ADDR+1
    JSR indirect_jsr
@transmit:
    ; Send the string from STRING_BUF
    LDX #$00
@cmd_send_loop:
    LDA STRING_BUF,X        ; Load from diags message
    BMI @last_byte          ; Last byte has MSB set
    JSR send_byte           ; Send the byte
    BIT IEEE_CONTROL        ; Check ATN and unwind if pulled high
    BMI @done               ; unwind

    INX
    BNE @cmd_send_loop

@last_byte:
    JSR send_byte

@done:
    RTS

; Receive a byte from the IEEE bus
receive_byte:
    ; Signal not ready for data (NRFD high)
    LDA #$04                ; NRFD high bit
    ORA IEEE_CONTROL
    STA IEEE_CONTROL

    ; Wait for DAV low
@wait_dav_low:
    BIT IEEE_CONTROL
    BMI @done               ; Unwind if ATN pulled high
    BVS @wait_dav_low

    ; Signal ready for data (NRFD low)
    LDA #$FB                ; Mask for ~NRFD (NRFD low)
    AND IEEE_CONTROL
    STA IEEE_CONTROL

    ; Get EOI status from control port (after setting NRFD low)
    AND #$20                ; Get EOI
    STA IEEE_EOI_FLAG       ; Save EOI state
    
    ; Read data
    LDA IEEE_DATA_IN_PORT
    EOR #$FF                ; Invert it
    PHA                     ; Save data byte
    
    ; Signal data accepted (NDAC low)
    LDA #$FD                ; Mask for ~NDAC (NDAC low)
    AND IEEE_CONTROL
    STA IEEE_CONTROL
    
    ; Wait for DAV high
@wait_dav_high:
    BIT IEEE_CONTROL
    BMI @done_pla           ; Unwind if ATN pulled high
    BVC @wait_dav_high      ; Loop until DAV high (bit 6 = 1)
    
    ; Signal data not accepted (NDAC high)
    LDA #$02                ; NDAC high bit
    ORA IEEE_CONTROL  
    STA IEEE_CONTROL
    
@done_pla:
    ; Retrieve and return data byte
    PLA
@done:
    RTS

; Send a byte over the IEEE bus - it's in A
send_byte:
    ; Wait for NRFD high
@wait_nrfd_high:
    BIT IEEE_CONTROL        ; Check for ~ATN going high (asserted)
    BMI @done
    BIT RIOT_UE1_PBD        ; Check NRFD
    BPL @wait_nrfd_high
    
    ; Put data on the bus
    PHA                     ; Keep a copy for EOI check
    AND #$7F                ; Clear top bit if set
    EOR #$FF                ; Invert for IEEE bus
    STA IEEE_DATA_OUT_PORT
    
    ; Check if last byte
    PLA
    BMI @with_eoi

    ; Regular byte - set EOIO high, DAVO low
    LDA IEEE_CONTROL
    AND #$EF                ; Pull DAVO (bit 4) low - to signal byte available
    STA IEEE_CONTROL
    JMP @wait_ack
    
@with_eoi:
    ; Last byte - set EOIO low (EOI asserted), DAVO low
    LDA IEEE_CONTROL
    AND #$F7                ; Clear EOIO first
    STA IEEE_CONTROL
    AND #$E7                ; Now clear and DAVO (bit 4)
    STA IEEE_CONTROL

@wait_ack:
    ; Wait for NDAC high (DACI - note this is Port B)
    BIT IEEE_CONTROL        ; Check for ~ATN going high (asserted)
    BMI @done
    BIT RIOT_UE1_PBD        ; Check DACI
    BVC @wait_ack

@done:
    ; Release data lines
    LDA #$18                ; Set EOIO (bit 3) and DAVO (bit 4) high
    ORA IEEE_CONTROL
    STA IEEE_CONTROL
    RTS

; Called at the end of the ATN interrupt routine, before replacing the stack
; and returning from the interrupt.
;
; If the byte was a:
; - A - enter command mode
; - X - exit command mode (back to flash mode)
; - Z - reboot the drive
; 
; Otherwise leave for the non-interrupt command_loop: to process (assuming it
; has been entered).
;
; If A or X was received, the stack is reset and the appropriate new non-
; interrupt routine address is pushed onto the stack, followed by a new CPU
; register byte.  RTI is then called, which causes he CPU to:
; - reload the CPU registers from the stack
; - jump to the new address on the stack.
int_process_command_byte:
    ; Only process a command byte when not in talk and not in listen
    LDA IEEE_LISTEN_ACTIVE
    BEQ @continue_check_talk    ; No listen active, continue
    RTS                 ; Listen active
@continue_check_talk:
    LDA IEEE_TALK_ACTIVE
    BEQ @continue       ; No talk active, continue
    RTS                 ; Talk active
@continue:
    LDA #ERR_LED        ; Set just the ERR LED, while processing
    STA RIOT_UE1_PBD    ; Set ERR LED

    ; Turn command into upper-case ascii
    LDA IEEE_CMD_BUF
    AND #$DF

    ; Check again commands we want to handle here
    CMP #'A'
    BEQ @enter_cmd_mode
    CMP #'X'
    BEQ @enter_flash_mode
    CMP #'Z'
    BEQ @reboot_drive

    ; No command to handle, return.
    RTS
@enter_cmd_mode:
    LDX #$FF            ; Reset the stack
    TXS
    LDA #>command_loop  ; Put address of command loop onto stack.  This will
    PHA                 ; Cause the CPU to call it on RTI.  High byte first.
    LDA #<command_loop
    PHA
    ; Note strictly this assert could happen - in which case we'd have to JMP
    ; rather than branch - 1/256 chance which the compiler will catch
    .assert command_loop <> 0, error, "command_loop = 0"
    BNE @clear_reg
@enter_flash_mode:
    LDX #$FF            ; Reset the stack
    TXS
    LDA #>flash_loop    ; Put address of flash loop onto stack.  This will
    PHA                 ; Cause the CPU to call it on RTI.  High byte first.
    LDA #<flash_loop
    PHA
@clear_reg:
    LDA #$00            ; Reset the CPU registers.  CPU reloads these from
    PHA                 ; the stack efore calling function pointer on stack.
    STA IEEE_CMD_BUF    ; Reset the command buffer as well.
    BEQ @done_clear     ; A is zero, always branches
@reboot_drive:
    ; CMD_RESET is defined to be Z so we don't need to load something else and
    ; cost ourselves and instruction here
    .assert CMD_RESET = 'Z', error, "CMD_RESET != 'Z'"
    STA CMD2            ; Store command in shared RAM - secondary processor
    STA CMD1            ; Pick this up and reset
@wait_secondary:
    LDX #STATUS_6504_RESETTING  ; Check it has acknowledged
    JSR wait_6504_status        ; Wait for up to 1 second.  If it resets faster
                                ; than this, the 6504 processor responded.

    ; No need to reset command buffer in this case as the zero page test will
    ; clear the whole zero page down

    JMP (RESET)         ; Reset the primary processor
@done_clear:
    LDX #$00            ; Clear command before leaving the interrupt handler
    STX IEEE_CMD_BUF
    RTI

; Main command loop, not running in interrupt handler.  Handles any outstanding
; commands in IEEE_CMD_BUF.
command_loop:
    ; Immediately execute the drive 0 command.  This sets the drive LEDs up and
    ; sets the secondary processor routine to drive 0.  Otherwise, if you enter
    ; command mode, select drive 1, and then exit command mode and re-enter,
    ; the secondary processor will still be set to drive 1, but we will be
    ; drive 0.
    LDA #CMD_DR0 
    STA IEEE_CMD_BUF       
@loop:
    LDA IEEE_CMD_BUF    ; Load the command buffer to see if there's a command to
                        ; execute

    ; Check for digit commands before we convert the command to upper-case
    CMP #CMD_DR0
    .assert CMD_DR0 >= '0' && CMD_DR0 <= '9', error, "CMD_DR0 not a digit"
    BEQ @drive0
    CMP #CMD_DR1
    .assert CMD_DR1 >= '0' && CMD_DR1 <= '9', error, "CMD_DR0 not a digit"
    BEQ @drive1

    ; Now check for letter commands.  Convert to upper-case ASCII first.  This
    ; means the secondary processor's routine will ever get upper-case, hence
    ; we don't need to change the case there so we can save 2 bytes there.
    AND #$DF            ; Convert to upper-case ASCII

    CMP #CMD_MOTOR_ON
    .assert CMD_MOTOR_ON >= 'A' && CMD_MOTOR_ON <= 'Z', error, "CMD_MOTOR_ON not an upper-case letter"
    BEQ @send_cmd

    CMP #CMD_MOTOR_OFF
    .assert CMD_MOTOR_OFF >= 'A' && CMD_MOTOR_OFF <= 'Z', error, "CMD_MOTOR_ON not an upper-case letter"
    BEQ @send_cmd

    CMP #CMD_FWD
    .assert CMD_FWD >= 'A' && CMD_FWD <= 'Z', error, "CMD_FWD not an upper-case letter"
    BEQ @send_cmd

    CMP #CMD_REV
    .assert CMD_REV >= 'A' && CMD_REV <= 'Z', error, "CMD_REV not an upper-case letter"
    BEQ @send_cmd

    CMP #CMD_BUMP
    .assert CMD_BUMP >= 'A' && CMD_BUMP <= 'Z', error, "CMD_BUMP not an upper-case letter"
    BEQ @send_cmd

    CMP #CMD_MOVE_TO_END
    .assert CMD_MOVE_TO_END >= 'A' && CMD_MOVE_TO_END <= 'Z', error, "CMD_MOVE_TO_END not an upper-case letter"
    BEQ @send_cmd

    ; No recognised command to handle
    BNE @loop           ; If we got here we know Z = 0, so will always loop

@drive0:
    LDX #DR0_LED        ; Set LED pattern to drive 0 LED
    STX RIOT_UE1_PBD
    JMP @send_cmd
@drive1:
    LDX #DR1_LED        ; Set LED pattern to drive 1 LED
    STX RIOT_UE1_PBD
@send_cmd:
    ; Reset results of last command sent to secondary processor
    LDX #$00
    STX CMD_RESULT
    STX CMD_RESULT_CMD

    ; Send the new command (still in A)
    STA CMD2
    STA CMD1

    ; Reset this command before we loop back - X is stil 0
    .assert CMD_NONE = 0, error, "CMD_NONE != 0"
    STX IEEE_CMD_BUF

    ; Loop back and check for a new command
    JMP @loop

; "Routine" which jumps to an indirect address.  This is in place of being
; to JSR to an indirect address, which the 6502 doesn't support.  Only actual
; routines must be jumped to here, or they won't return to the point that did
; JSR indirect_jsr.
indirect_jsr:
    JMP (IEEE_JMP_ADDR)     ; Jump to the routine we pointed to

; Function to set our interrupt handler
;
; X contains low byte, Y high byte
;
; Retains all registers, and returns with interrupts enabled
set_irq_handler:
    SEI
    STX IRQ_HANDLER
    STY IRQ_HANDLER+1
    CLI
    RTS

; Our no-op NMI handler.  NMI is tied high on the drive, so this should never
; be called.  If we wanted to save a byte we could make this the location of
; another RTI call. 
nmi_handler:
    RTI

; Our IRQ handler
;
; We jump to the address configured in zero page (and this must be initialized)
; before interrupts are enabled, or bad things will happen.  This allows us
; to change what gets called on interrupts dynamically.
irq_handler:
    JMP (IRQ_HANDLER)
