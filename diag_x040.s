; Diagnostics ROM for the Commodore 2040, 3040 and 4040 disk drives.
;
; Copyright (c) 2025 Piers Finlayson <piers@piers.rocks>
;
; Licensed under the MIT License.  See [LICENSE] for details.
;
; See [README.md] for build and usage instructions.

CPU_6502 = 1
.include "shared.inc"
.include "macros.inc"

; Version numbers
MAJOR_VERSION = $00
MINOR_VERSION = $01
PATCH_VERSION = $05
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
CbmString StrRomName, "Commodore IEEE Disk Drive Diagnostics ROM by piers.rocks"
CbmString StrVersion, "ROM Version: "
CbmString StrCopyright, "(c) 2025 Piers Finlayson"
CbmString StrRepo, "https://github.com/piersfinlayson/cbm-ieee-disk-diag-rom"

; Table of intro strings: low byte, high byte, action code
; Action code:
;   Bit 0: CR flag (0=add newline, 1=don't add NL)
;   Bits 1-7: Action type (0=none, 1=add version, 2=underline)
;
; Strings will be added to create the intro message in the order shown
intro_str_table:
    .word StrRomName
    .byte %00000101         ; Add NL, underline

    .word StrVersion
    .byte %00000011         ; Don't add NL, action 1: add version number
 
    .word StrCopyright
    .byte %00000000         ; Add NL, no special action
    
    .word StrRepo
    .byte %00000000         ; Add NL, no special action
    
INTO_STR_TABLE_END:
INTRO_STR_TABLE_LEN = (INTO_STR_TABLE_END - intro_str_table)

; Maps TALK channels to string methods to call to create a string buffer to
; send.
;
; Each entry contains 5 bytes:
; - Byte 0: Channel number (0-15)
; - Bytes 1/2: Word containing pointer to channel's name/purpose
; - Bytes 3/4: Word containing pointer to string method to call to create
;
; Strings are created and stored in STRING_BUF, which is stored in RAM.

; Channel names
CbmString StrChannelListing, "Channel list"
CbmString StrRomInfo, "ROM info"
CbmString StrTestResults, "Test results"
CbmString StrTestSummary, "Test summary"
CbmString StrStatus, "Drive status"

; Channel string
CbmString StrChannel, "Channel "

; Table
talk_str_table:
    .byte 0                         ; Channel num
    .word StrChannelListing
    .word build_channel_listing_str
END_TALK_STR_TABLE_FIRST_ENTRY:
TALK_STR_TABLE_ENTRY_LEN = (END_TALK_STR_TABLE_FIRST_ENTRY - talk_str_table)
    .byte 1                         ; Channel num
    .word StrTestSummary
    .word build_summary_str
    .byte 2                         ; Channel num
    .word StrRomInfo
    .word build_rom_info_str
    .byte 3                         ; Channel num
    .word StrTestResults
    .word build_test_results_str
    .byte 15                        ; Channel num
    .word StrStatus
    .word build_status_str
TALK_STR_TABLE_END:
TALK_STR_TABLE_LEN = (TALK_STR_TABLE_END - talk_str_table)
CbmString StrInvalidChannel, "Invalid channel"

; String to use in status response indicating failed tests
CbmString StrTestsFailed, "Tests(s) failed"
END_STR_TESTS_FAILED:
.assert (END_STR_TESTS_FAILED - StrTestsFailed) <= 29, error, "StrTestsFailed too long"
; String to use in status response indicating passed tests
CbmString StrTestsPassed, "All tests passed"
END_STR_TESTS_PASSED:
.assert (END_STR_TESTS_PASSED - StrTestsPassed) <= 29, error, "StrTestsPassed too long"

CbmString StrNotImplemented, "Not implemented"

; Boot string, provided alongside status code 73.  Our equivalent of:
; "CBM DOS V2.6 1541"
;
; We use a max length of 22 bytes, in order to give us 8 bytes for the version
; number, and still hit 39 bytes for the entire status string including
; preceeding error code and command, and succeeding commas and track/sector
; numbers
CbmString StrStatusBooted, "piers.rocks diag rom v"
END_STR_BOOT:
.assert (END_STR_BOOT - StrStatusBooted) <= 22, error, "StrBoot too long"

CbmString StrStatusOk, "ok"

CbmString StrStatusInternalError, "internal error"

CbmString StrTestDelim, " Test: "
CbmString StrZeroPage, "Zero Page"
CbmString StrRam, "RAM"
CbmString Str6504Space, "6504 "
CbmString StrBoot, "Boot"
CbmString StrTakeover, "Takeover"
CbmString StrFailed, "Failed"
CbmString StrPassed, "Passed"
CbmString StrNotAttempted, "Not Attempted"

; Names of the various RAM chips.
; 'U' isn't included to simplify handling code
; Ordered from LSB and RESULT_RAM_TEST upwards
RamChipNames:
    .byte 'C', '5'
    .byte 'D', '5'
    .byte 'E', '5'
    .byte 'F', '5'
    .byte 'C', '4'
    .byte 'D', '4'
    .byte 'E', '4'
    .byte 'F', '4'

; Pages to test in our first RAM test
RamTest0:
    .byte $11, $12, $13
    .byte $20, $21, $22, $23
    .byte $30, $31, $32, $33
    .byte $40, $41, $42, ($43 | $80)

; Pages to test in our second RAM test
RamTest1:
    .byte ($10 | $80)

; Pointers to the pages to test for each test
RamTests:
    .word RamTest0, RamTest1

; Mask to TESTS_6502 for the RAM tests
RamTestMask:
    .byte TEST_RAM0, TEST_RAM1

; Map low nibble of page number to LEDs to light
RamTestLedPattern:
    .byte DR0_LED, DR1_LED, DR0_LED, DR1_LED

; Byte patterns used to test RAM.  Finish with 0 to leave the RAM in that
; state.
RamTestBytePattern:
    .byte $FF, $55, $AA, $A5, $5A, $24, $42, $00

; Offsets from start of shared RAM that we check for 6504 aliveness.
; We set the MSB for the last value.
;
; Only 8 offsets/byte tests are supported by check_6504_booted.
;
; We check:
; - $1000 ($400 on the 6504) - TICK, initialized to $0F
; - $1001 ($401 on the 6504) - DELAY, initialized to $32
; - $1002 ($402 on the 6504) - CUTMT, initialized to $FF
SharedRamOffsets:
    .byte TICK_OFFSET, DELAY_OFFSET, CUTMT_OFFSET | $80
.assert SharedRamInitValues - SharedRamOffsets <= 8, error, "Too many shared RAM locations to check"

; Values we expect shared RAM locations to have, in order to show the 6504 is
; alive.
SharedRamInitValues:
    .byte TICK_INIT, DELAY_INIT, CUTMT_INIT

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
    JSR report_drives   ; Report drive test errors, if any
    JSR report_dev_id   ; Report the device ID, if we have it
    JMP finished        ; Go around again

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

    ; 6504 boot test failed - report it by flashing both LEDs 6 times
    LDA #$06            ; Flash 6 times for 6504 control takeover failure
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

    ; 6504 takeover test failed - report it by flashing both LEDs 7 times
    LDA #$07            ; Flash 7 times for 6504 control takeover failure
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
    BEQ @done

@failed:
    LDA #RESULT_6504_TO_ERR
    STA RESULT_6504_TO  ; Mark takeover as failed

@done:
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
    LDA #<code_6504_start   ; Store the low byte of stored 6504 code
    .assert <code_6504_start = $00, error, "6504 code not at $00"
    STA CP1
    LDA #>code_6504_start   ; Store the high byte of stored 6504 code
    STA CP1+1

    ; Set up destination addresses for 6504 code we want to copy
    LDA #$00                ; Set destination to $1100
    STA CP2                 ; Store in destination address
    LDA #$11
    STA CP2+1               ; Store in destination address

    ; Do the copy, byte by byte.
    LDY #$00                ; Set Y to 0 as an index for the copy
    .assert CODE_6504_LEN <= $FF, error, "6504 code too long"
    LDX #CODE_6504_LEN      ; Get the length of the 6504 code
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

add_string_no_nl:
    LDX #$01                ; Initialize string index
    JSR add_string
    RTS

; Add a string to the provided buffer
;
; X = zero if need to add newline, non-zero if we don't
; Y = index to buffer - will be updated and returned
; BUF_PTR = buffer address
; STR_PTR = string address
;
; Z will be set if the buffer is full, otherwise it won't be
add_string:
    TXA                     ; Store X on the stack for now
    PHA
    STY BUF_INDEX           ; Store Y in zero page
    LDX #$00                ; Initialize string index
    STX STR_INDEX
    STX STR_LEN             ; Initialize string length to 0
@next_byte:
    LDY STR_INDEX           ; Get the string index
    LDA (STR_PTR),Y         ; Get next byte
    PHA                     ; Store it with high bit
    AND #$7F                ; Mask off high bit
    LDY BUF_INDEX           ; Get the buffer index
    STA (BUF_PTR),Y         ; Store char in the buffer
    INC STR_LEN             ; Track string length
    PLA                     ; Retrieve with high bit
    BMI @finished_str       ; If negative, we're done
    INC STR_INDEX           ; Increment string index - don't need to test as
                            ; will be <= Y
    INC BUF_INDEX           ; Increment buffer index
    BNE @next_byte          ; Continue if Y still non-zero
    BEQ @done
@finished_str:
    INC BUF_INDEX           ; Skipped this due to branch above
    PLA                     ; Retrieve what used to be X (now A)
    TAX                     ; Put it back as X in case caller wants it
    BNE @done               ; If not zero, we're done
    LDY BUF_INDEX           ; Get the buffer index
    JSR add_newline         ; Y is updated, so no need to load before RTS
    RTS

@done:
    LDY BUF_INDEX           ; Get the buffer index
    RTS

; Add a newline to the provided buffer
;
; Y = index to buffer - will be updated and returned
; BUF_PTR = buffer address
;
; Z will be set if the buffer is full, otherwise it won't be
add_newline:
    LDA #$0A                ; \n
    STA (BUF_PTR),Y         ; Store it in the buffer   
    INY                     ; Increment Y
    RTS

; Sets up string buffer to write strings into
setup_string_buf:
    LDY #$00
    LDA #<STRING_BUF
    STA BUF_PTR
    LDA #>STRING_BUF
    STA BUF_PTR+1
    RTS

; Builds the invalid channel string to transmit when put into TALK mode on a
; channel which has no data to send.
build_invalid_channel_str:
    JSR setup_string_buf

    LDA #<StrInvalidChannel
    STA STR_PTR
    LDA #>StrInvalidChannel
    STA STR_PTR+1

    JSR add_string_no_nl
    JSR mark_last_byte_str
    RTS

; Figures out if any of the tests failed, by comparing the various zero page
; addresses that store test resuls with 0 (success).
; 
; Returns Z = 1 if all tests passed, Z = 0 otherwise
test_failed_any:
    LDA #$00
    CMP RESULT_ZP
    BNE @failed
    CMP DEVICE_ID
    BNE @failed
    CMP RESULT_RAM_TEST
    BNE @failed
    CMP RESULT_6504_BOOT
    BNE @failed
    CMP RESULT_6504_TO
    BNE @failed
    RTS                 ; Z = 1

@failed:
    RTS                 ; Z = 0

add_char:
    STA (BUF_PTR),Y
    INY
    RTS

; Build a test summary string.  Simply says whether all tests passed or some
; some test(s) failed.
build_summary_str:
    JSR setup_string_buf
    JSR test_failed_any
    BEQ @ok

    ; Test(s) failed case
    LDA #<StrTestsFailed
    STA STR_PTR
    LDA #>StrTestsFailed
    STA STR_PTR+1
    BNE @add_string         ; BNE as we know #>StrTestsFailed != 0

@ok:
    ; All tests passed
    LDA #<StrTestsPassed
    STA STR_PTR
    LDA #>StrTestsPassed
    STA STR_PTR+1

@add_string:
    JSR add_string_no_nl
    JSR mark_last_byte_str
    RTS

; Build a status string.  This is what we transmit when instructed to talk on
; channel 15.  And provides the result of the last operation we performed in
; response to a requested action by the user.
;
; We output a string in the same format as a standard Commodore disk drive
; would:
;
;   <status code>,<status string>,<track number>,<sector number>
;
; Max of 39 bytes long for compatibility with stock disk drives.
;
; When reporting booted status (73) track number contains device ID (8-15).
build_status_str:
    JSR setup_string_buf

    LDA DEVICE_STATUS       ; Get the status code
    PHA                     ; Store it on the stack for later
    LDX #$01                ; We want leading zeros on the number
    JSR output_decimal_byte ; Output it

    LDA #$2C            ; Comma
    JSR add_char
    BEQ @done           ; Exit if buffer full

    PLA                 ; Get status code back

    LDX #$00            ; Store 00 as track number
    STX STI

    CMP #DEVICE_STATUS_OK
    BEQ @status_ok

    CMP #DEVICE_STATUS_BOOTED
    BEQ @status_booted

    ; Internal error
    TAX                 ; Store status code in X (track number)
    STX STI
    LDA #<StrStatusInternalError
    STA STR_PTR
    LDA #>StrStatusInternalError
    STA STR_PTR+1
    .assert >StrStatusInternalError > 0, error, "StrStatusInternalError is 0 - branch won't work"
    BNE @add_status_string  ; We know #>StrStatusInternalError is not 0, so BNE

@status_ok:
    LDA #<StrStatusOk
    STA STR_PTR
    LDA #>StrStatusOk
    STA STR_PTR+1
    .assert >StrStatusOk > 0, error, "StrStatusOk is 0 - branch won't work"
    BNE @add_status_string  ; We know #>StrStatusOk is not 0, so BNE

@status_booted:
    LDA #<StrStatusBooted
    STA STR_PTR
    LDA #>StrStatusBooted
    STA STR_PTR+1
    JSR add_string_no_nl    ; Add it now
    BEQ @done               ; Exit if buffer full

    JSR add_version_number  ; Add version number as part of booted string
    BEQ @done               ; Exit if buffer full

    LDX DEVICE_ID           ; Set track number to device number
    STX STI                 ; Store it in the track number

    LDA #$00                ; Now reset device status to 00 (from 73) as we've
                            ; reported the 73 from boot.
    STA DEVICE_STATUS
    BEQ @add_suffix         ; We can use BEQ as A contains 0

@add_status_string:
    JSR add_string_no_nl
    BEQ @done               ; Exit if buffer full

@add_suffix:
    LDA #$2C                ; Comma
    JSR add_char
    BEQ @done               ; Exit if buffer full

    LDA STI                 ; Reload track number
    LDX #$01                ; We want leading zeros on the number
    JSR output_decimal_byte ; Output it
    BCS @done               ; Exit if buffer full

    LDA #$2C                ; Comma
    JSR add_char
    BEQ @done               ; Exit if buffer full

    LDA #$00                ; Sector number
    LDX #$01                ; We want leading zeros on the number
    JSR output_decimal_byte ; Output it

@done:
    JSR mark_last_byte_str
    RTS

; Add "Passed" string
add_passed:
    LDA #<StrPassed
    STA STR_PTR
    LDA #>StrPassed
    STA STR_PTR+1
    JSR add_string_no_nl
    RTS

; Add "Failed" string
add_failed:
    LDA #<StrFailed
    STA STR_PTR
    LDA #>StrFailed
    STA STR_PTR+1
    JSR add_string_no_nl
    RTS

; Add "Not Attempted" string
add_not_attempted:
    LDA #<StrNotAttempted
    STA STR_PTR
    LDA #>StrNotAttempted
    STA STR_PTR+1
    JSR add_string_no_nl
    RTS

; Add zero page string
add_zero_page:
    LDA #<StrZeroPage
    STA STR_PTR
    LDA #>StrZeroPage
    STA STR_PTR+1
    JSR add_string_no_nl
    RTS

add_ram:
    LDA #<StrRam
    STA STR_PTR
    LDA #>StrRam
    STA STR_PTR+1
    JSR add_string_no_nl
    RTS

add_6504:
    LDA #<Str6504Space
    STA STR_PTR
    LDA #>Str6504Space
    STA STR_PTR+1
    JSR add_string_no_nl

@done:
    RTS

add_6504_boot:
    JSR add_6504
    BEQ @done               ; Exit if buffer full

    LDA #<StrBoot
    STA STR_PTR
    LDA #>StrBoot
    STA STR_PTR+1
    JSR add_string_no_nl

@done:
    RTS

add_6504_takeover:
    JSR add_6504
    BEQ @done               ; Exit if buffer full

    LDA #<StrTakeover
    STA STR_PTR
    LDA #>StrTakeover
    STA STR_PTR+1
    JSR add_string_no_nl

@done:
    RTS

; Add " Test: " to the string, for example to follow "Zero Page"
add_test_suffix:
    LDA #<StrTestDelim
    STA STR_PTR
    LDA #>StrTestDelim
    STA STR_PTR+1
    JSR add_string_no_nl

@done:
    RTS

add_zero_page_result:
    JSR add_zero_page
    BEQ @done               ; Exit if buffer full

    JSR add_test_suffix
    BEQ @done               ; Exit if buffer full

    ; See if the zero page test was attempted
    LDA #TEST_ZP
    AND TESTS_6502
    BEQ @zp_not_attempted

    ; Attempted - see if it passed or failed
    LDA RESULT_ZP
    BNE @zp_failed

    ; Passed
    JSR add_passed
@done:
    RTS

@zp_failed:
    JSR add_failed

    ; Now we add which zero page locations failed.
    JSR add_failed_zp_chips
    RTS

@zp_not_attempted:
    JSR add_not_attempted
    RTS

; Adds " - " to the string
add_dash_and_spaces:
    LDA #$20                ; space
    JSR add_char
    BEQ @done               ; Exit if buffer full

    LDA #$2D                ; dash
    JSR add_char
    BEQ @done               ; Exit if buffer full

    LDA #$20                ; space
    JSR add_char

@done:
    RTS

add_comma_space:
    LDA #$2C                ; Comma
    JSR add_char
    BEQ @done               ; Exit if buffer full

    LDA #$20                ; Space
    JSR add_char

@done:
    RTS

; Output failed chips from ZP test
;
; Strictly some of the code here is moot - we'll never get here if UE1 failed.
; But we'll do it by the book, anyway.
;
; RESULT_ZP contains 1 in bit 0 for UE1 and a 1 in bit 1 for UC1.
add_failed_zp_chips:
    JSR add_dash_and_spaces
    BEQ @done               ; Exit if buffer full

    LDA RESULT_ZP           ; Load the zero page test result
    STA NRTR                ; Store for processing
    LDX #$00                ; X will be our bit counter (0-1)
    TXA                     ; A will track if we've output any chips yet
    STA NROC                ; Store in zero page

@chip_loop:
    LSR NRTR                ; Shift right to check current bit
    BCC @next_bit           ; Skip if this bit is not set (no failure)

    ; This chip failed - output its name
    LDA NROC                ; Check if we've output any chips yet
    BEQ @first_chip         ; Skip comma for first chip

    JSR add_comma_space
    BEQ @done               ; Exit if buffer full

@first_chip:
    INC NROC                    ; Mark that we've output at least one chip

    ; Output the 'U' at the beginning of the name
    LDA #$55                    ; 'U' character
    JSR add_char
    BEQ @done                   ; Exit if buffer full

    CPX #$00                    ; Check if this is the first result bit
    BNE @uc1                    ; If not, skip to UC1

    LDA #$45                    ; 'E' character
    BNE @continue               ; A is non zero so always branches

@uc1:
    LDA #$43                    ; 'C' character

@continue:
    JSR add_char
    BEQ @done                   ; Exit if buffer full

    LDA #$31                    ; '1' character
    JSR add_char
    BEQ @done                   ; Exit if buffer full

@next_bit:
    INX                         ; Move to next bit
    CPX #$02                    ; Check if we've done all 2 bits
    BCC @chip_loop              ; Continue if X < 2

    LDA #$01                    ; Set A to 1 to show buffer not full

@done:
    RTS

; Add which RAM chips failed during the test to the output string
add_failed_ram_chips:
    JSR add_dash_and_spaces
    BEQ @done               ; Exit if buffer full

    ; Now log any failed RAM chips
    ; We do this by processing RESULT_RAM_TEST.  A '1' in a bit indicates a
    ; failed chip.  We use (2 x bit number) to access RamChipNames
    LDA RESULT_RAM_TEST         ; Load the RAM test result
    STA NRTR                    ; Store for processing
    LDX #$00                    ; X will be our bit counter (0-7)
    TXA                         ; A will track if we've output any chips yet
    STA NROC                    ; Store in zero page

@chip_loop:
    LSR NRTR                    ; Shift right to check current bit
    BCC @next_bit               ; Skip if this bit is not set (no failure)

    ; This chip failed - output its name
    LDA NROC                    ; Check if we've output any chips yet
    BEQ @first_chip             ; Skip comma for first chip

    JSR add_comma_space
    BEQ @done                   ; Exit if buffer full

@first_chip:
    INC NROC                    ; Mark that we've output at least one chip

    ; Output the 'U' at the beginning of the name
    LDA #$55                    ; 'U' character
    JSR add_char
    BEQ @done                   ; Exit if buffer full

    ; Get the chip name from RamChipNames
    TXA                         ; Put bit number in A
    ASL A                       ; Multiply by 2 for RamChipNames indexing
    TAY                         ; Use as index
    
    ; Output first character of chip name
    LDA RamChipNames,Y          ; Get the letter (C, D, E, F)
    JSR add_char
    BEQ @done                   ; Exit if buffer full
    
    ; Output second character of chip name
    LDA RamChipNames+1,Y        ; Get the number (4 or 5)
    JSR add_char
    BEQ @done                   ; Exit if buffer full

@next_bit:
    INX                         ; Move to next bit
    CPX #$08                    ; Check if we've done all 8 bits
    BCC @chip_loop              ; Continue if X < 8

    LDA #$01                    ; Set A to 1 to show buffer not full

@done:
    RTS

; Add RAM test result
add_ram_result:
    JSR add_ram
    BEQ @done               ; Exit if buffer full

    JSR add_test_suffix
    BEQ @done               ; Exit if buffer full

    ; See if the RAM test was attempted
    LDA #(TEST_RAM0 | TEST_RAM1)
    AND TESTS_6502
    BEQ @ram_not_attempted

    ; Attempted - see if it passed or failed
    LDA RESULT_RAM_TEST
    BNE @ram_failed

    ; Passed
    JSR add_passed
@done:
    RTS

@ram_failed:
    JSR add_failed
    BEQ @done               ; Exit if buffer full

    JSR add_failed_ram_chips
    RTS

@ram_not_attempted:
    JSR add_not_attempted
    RTS

; Add results from 6504 tests
add_6504_results:
    JSR add_6504_boot
    BEQ @full               ; Exit if buffer full

    JSR add_test_suffix
    BEQ @full               ; Exit if buffer full

    ; See if the 6504 boot test was attempted
    LDA #TEST_6504_BOOT
    AND TESTS_6502
    BNE @boot_attempted

    JSR add_not_attempted
    BEQ @full               ; Exit if buffer full
    BNE @check_takeover

    ; Attempted - see if it passed or failed
@boot_attempted:
    LDA RESULT_6504_BOOT
    BNE @boot_failed

    ; Passed
    JSR add_passed
    BEQ @full               ; Exit if buffer full
    BNE @check_takeover

@boot_failed:
    JSR add_failed
    BEQ @full               ; Exit if buffer full

@check_takeover:
    ; Newline
    JSR add_newline
    BEQ @full               ; Exit if buffer full

    ; Add 6504 Takeover string
    JSR add_6504_takeover
    BEQ @full               ; Exit if buffer full

    JSR add_test_suffix
    BEQ @full               ; Exit if buffer full

    ; Now check the takeover test
    LDA #TEST_6504_TO
    AND TESTS_6502
    BEQ @takeover_not_attempted

    ; Attempted - see if it passed or failed
    LDA RESULT_6504_TO
    BNE @takeover_failed

    ; Passed
    JSR add_passed
    BEQ @full               ; Exit if buffer full

    ; Fall through to @complete
@complete:
    JSR add_newline
    RTS

@takeover_failed:
    JSR add_failed
    BEQ @full               ; Exit if buffer full
    BNE @complete

@takeover_not_attempted:
    JSR add_not_attempted
    BEQ @full               ; Exit if buffer full
    BNE @complete

@full:
    RTS

; Routine to build detailed test results string
;
; Contains:
; - Zero page results
; - RAM test results (combined across both tests)
; - 6504 results (both boot and takeover)
;
; For each set of results, it indicates either that the test wasn't attempted,
; or the results of the test.
build_test_results_str:
    JSR setup_string_buf

    JSR add_zero_page_result
    BEQ @done               ; Exit if buffer full

    JSR add_newline
    BEQ @done               ; Exit if buffer full

    JSR add_ram_result
    BEQ @done               ; Exit if buffer full

    JSR add_newline
    BEQ @done               ; Exit if buffer full

    JSR add_6504_results
@done:
    JSR mark_last_byte_str
    RTS

; Build a string listing all available channels and their purposes.
; Format: "Channel X: Description" for each channel
build_channel_listing_str:
    JSR setup_string_buf    ; Initialize the buffer
    
    LDX #$00                ; Initialize index into talk_str_table
@channel_loop:
    ; Add "Channel " text
    LDA #<StrChannel
    STA STR_PTR
    LDA #>StrChannel
    STA STR_PTR+1
    
    STX STI                 ; Store X in STI zero page location
    JSR add_string_no_nl
    BEQ @done               ; Buffer full check
    LDX STI                 ; Restore X
    
    ; Add channel number
    LDA talk_str_table,X    ; Get channel number from table
    LDX #$00                ; We don't want leading zeros on the number
    JSR output_decimal_byte
    BCS @done               ; Exit if buffer full (carry set)
    
    ; Add ": " text
    LDA #$3A                ; Colon character
    JSR add_char
    BEQ @done
    LDA #$20                ; Space character
    JSR add_char
    BEQ @done
    
    ; Add channel description
    LDX STI                 ; Restore X
    LDA talk_str_table+1,X  ; Get low byte of string pointer
    STA STR_PTR
    LDA talk_str_table+2,X  ; Get high byte of string pointer
    STA STR_PTR+1
    
    LDX #$00                ; Add newline after this string
    JSR add_string
    BEQ @done               ; Buffer full check
    LDX STI                 ; Restore X
    
    ; Move to next entry
    TXA
    CLC
    ADC #TALK_STR_TABLE_ENTRY_LEN   ; Move to next entry
    TAX
    CPX #TALK_STR_TABLE_LEN         ; Check if we've reached the end
    BCC @channel_loop       ; If not, continue loop
    
@done:
    JSR mark_last_byte_str
    RTS

; Create initial message to be sent when put into TALK mode via IEEE-488
build_rom_info_str:
    JSR setup_string_buf

    LDX #0                  ; String table index
@string_loop:
    STX STI                 ; Save current string table index in zero page

    ; Load string address (as a word)
    LDA intro_str_table,X   ; Get low byte
    STA STR_PTR
    LDA intro_str_table+1,X ; Get high byte
    STA STR_PTR+1
    
    LDA intro_str_table+2,X ; Get flags/action code
    PHA                     ; Save action code for later

    AND #$01                ; Isolate CR flag (bit 0)
    TAX                     ; X=0 add CR, X!=0 don't add CR
    JSR add_string
    BEQ @done               ; Buffer full
    
    PLA                     ; Restore action code
    LSR A                   ; Shift right to get action type (bits 1-7)
    BEQ @next_string        ; If 0, no special action
    
    CMP #1
    BEQ @do_version         ; Action 1: add version number

    CMP #2
    BEQ @do_underline       ; Action 2: underline previous line

    ; No other actions supported at this point
@next_string:
    LDX STI                 ; Restore string table index
    INX                     ; Increment 3 times for next string
    INX
    INX
    CPX #INTRO_STR_TABLE_LEN
    BCC @string_loop        ; Continue if not at end
    ; Otherwise fall through to done

@done:
    JSR mark_last_byte_str
    RTS

@do_version:
    JSR add_version_number
    BEQ @done
    ; Fall through into do_underline - we need this after adding version
    ; number

@do_underline:
    JSR add_underline       ; Add underline characters
    BEQ @done
    BNE @next_string

mark_last_byte_str:
    DEY              
    LDA (BUF_PTR),Y         ; Get the last byte
    ORA #$80                ; Set the high bit
    STA (BUF_PTR),Y         ; Store it in the buffer
    INY                     ; Increment Y again.  Although no-one will be
                            ; writing to this string again, it's important
                            ; that Z = 1 if the buffer is full.  INY does this
                            ; because if Y was 0 when calling, it will be now,
                            ; hence Z is set to 1.
    RTS

; Add underline characters based on the length of the last string
add_underline:
    JSR add_newline         ; Add a CR first
    BEQ @done               ; Buffer full
    
    LDX STR_LEN             ; Get the length of the previous string
    BEQ @success            ; If zero, nothing to underline
    
@underline_loop:
    LDA #$2D                ; "-" character
    STA (BUF_PTR),Y         ; Store in buffer
    INY
    BNE @continue           ; If Y didn't wrap, continue
    RTS                     ; Buffer full, return with Z=1 (failure)

@continue:
    DEX                     ; Decrement counter
    BNE @underline_loop     ; Continue until we've added enough "-"

@success:
    JSR add_newline         ; Add a CR after the underline
@done:
    RTS

; Assert version numbers are in valid range
.assert MAJOR_VERSION <= 99, error, "MAJOR_VERSION > 99"
.assert MINOR_VERSION <= 99, error, "MINOR_VERSION > 99"
.assert PATCH_VERSION <= 99, error, "PATCH_VERSION > 99"

; Add version number
add_version_number:
    ; Handle MAJOR_VERSION
    LDA #MAJOR_VERSION      ; Load the immediate value
    LDX #$00                ; No leading zeros
    JSR output_decimal_byte
    BCS @done               ; Exit if buffer full
    
    ; Add period
    LDA #'.'
    STA (BUF_PTR),Y
    INY
    BEQ @done
    
    ; Handle MINOR_VERSION  
    LDA #MINOR_VERSION      ; Load the immediate value
    LDX #$00                ; No leading zeros
    JSR output_decimal_byte
    BCS @done               ; Exit if buffer full
    
    ; Add period
    LDA #'.'
    STA (BUF_PTR),Y
    INY
    BEQ @done
    
    ; Handle PATCH_VERSION
    LDA #PATCH_VERSION      ; Load the immediate value
    LDX #$00                ; No leading zeros
    JSR output_decimal_byte
    
@done:
    RTS

; Convert byte in A (0-99) to decimal ASCII and store at (BUF_PTR),Y
; X determines if values 0-9 should have leading zeros (0=no, non-zero=yes)
; Advances Y for each digit output
; Returns with carry set if buffer full (Y wrapped to 0)
output_decimal_byte:
    STA STJ

    ; Check if value >= 10
    CMP #10
    BCS @two_digits     ; If >= 10, handle two digits

    ; It's a single digit (0-9)
    CPX #0              ; Test if we want leading zeros
    BEQ @single_digit   ; If X=0, no leading zero needed
    
    ; Output leading zero for single-digit numbers
    LDA #$30            ; ASCII '0'
    STA (BUF_PTR),Y
    INY
    BEQ @buffer_full
    
@single_digit:
    LDA STJ
    JMP @output_digit
    
@two_digits:
    ; Divide by 10 using repeated subtraction
    LDX #0          ; X will hold the tens digit
@div_loop:
    SEC
    SBC #10
    INX
    CMP #10
    BCS @div_loop   ; If >= 10, continue loop
    
    ; X now has tens digit, A has ones digit
    PHA             ; Save ones digit
    
    ; Output tens digit
    TXA
    CLC
    ADC #$30        ; Convert to ASCII
    STA (BUF_PTR),Y
    PLA             ; Get ones digit back to clean up stack
    INY
    BEQ @buffer_full
    
@output_digit:
    CLC
    ADC #$30        ; Convert to ASCII
    STA (BUF_PTR),Y
    INY
    BEQ @buffer_full
    LDA STJ         ; Restore original A
    CLC             ; Clear carry to indicate success
    RTS
    
@buffer_full:
    LDA STJ         ; Restore original A
    SEC             ; Set carry to indicate buffer is full
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
    STA TALK_ADDR
    EOR #$68                ; Create listen address same way
    STA LISTEN_ADDR

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

    BIT IEEE_CONTROL
    BVC @atn_get_cmd        ; DAV low - command ready
    BMI @atn_wait           ; ATN still low
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
    JMP @atn_exit

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

    LDA #DR01_LEDS
    STA RIOT_UE1_PBD        ; Set drive 0/1 LEDs on


    ; Reset control lines to idle state after talk_handler
    LDA #$07                ; ~DACO, RFDO, ATNA all high
    ORA IEEE_CONTROL
    STA IEEE_CONTROL

@atn_exit:
    ; Restore registers
    PLA
    STA RIOT_UE1_PBD        ; Restore LED state
    PLA
    TAY
    PLA
    TAX
    PLA

    BIT IEEE_CONTROL        ; Finally check whether ~ATN has been pulled high
                            ; (again).  If so, we need to go around this
                            ; interrupt handler aghain.
    BMI @again
    RTI

@again:
    JMP ieee_irq_handler

@handle_listen:
    LDA IEEE_DATA_BYTE
    CMP LISTEN_ADDR
    BEQ @our_listen         ; Liasten is for our listen address
    CMP #$3F                ; Was this an UNLISTEN?
    BNE @not_addressed      ; Branch if not - it wasn't for us
    STY IEEE_LISTEN_ACTIVE  ; Clear listen active
    BEQ @not_addressed      ; Branch always - as we set Y to 0 before this
    
@our_listen:
    STA IEEE_LISTEN_ACTIVE  ; Set listen active
    STY IEEE_TALK_ACTIVE    ; Clear talk active
    LDA #$20
    STA IEEE_SEC_ADDR       ; Default secondary address
    STA IEEE_ORIG_SEC_ADDR
    STA IEEE_ADDRESSED      ; Mark as addressed
    BNE @atn_next           ; Branch always, as A non-zero

@handle_talk:
    STY IEEE_TALK_ACTIVE    ; Clear talk active (Y is set to zero before this)

    LDA IEEE_DATA_BYTE      ; Get our data byte
    CMP TALK_ADDR           ; Compare with our TALK address
    BNE @not_addressed
    STA IEEE_TALK_ACTIVE    ; Set talk active
    STY IEEE_LISTEN_ACTIVE  ; Clear listen active
    LDA #$20
    STA IEEE_SEC_ADDR       ; Default secondary address
    STA IEEE_ORIG_SEC_ADDR
    STA IEEE_ADDRESSED      ; Mark as addressed
    BEQ @atn_next           ; Branch always (always Z=1 here)

@handle_secondary:
    LDA IEEE_ADDRESSED
    BEQ @atn_next           ; Not addressed, ignore
    LDA IEEE_DATA_BYTE
    STA IEEE_ORIG_SEC_ADDR  ; Store original SA
    PHA
    AND #$0F
    STA IEEE_SEC_ADDR       ; Extract SA bits 0-3
    PLA
    AND #$F0                ; Check for close command
    CMP #$E0                ; Is it close?
    BNE @atn_next
    JSR close_channel       ; Handle close command
    
@not_addressed:
    STY IEEE_ADDRESSED      ; Clear addressed flag - also handles untalk

@atn_next:
    BIT IEEE_CONTROL        ; Wait for DAV high
    BVC @atn_next
    JMP @atn_wait           ; Get next command byte

; Close channel implementation
close_channel:
    ; Close the channel specified in IEEE_SEC_ADDR
    ; For diagnostics, you may just clear channel status
    LDA IEEE_SEC_ADDR
    CMP #$0F               ; Command channel?
    BNE @normal_close

    ; Handle command channel close
    ; For diagnostics you might want to reset command buffer
    LDA #$00
    STA IEEE_CMD_BUF_LEN
    RTS

    ; Handle command channel close
@normal_close:
    RTS

; Handle incoming data as listener
listen_handler:
    LDA IEEE_SEC_ADDR       ; Check which channel
    CMP #$0F                ; Command channel?
    BEQ @cmd_listen         ; Handle command channel
    ; Other channels not implemented
    RTS

@cmd_listen:
    ; Receive command into buffer
    LDX #$00
@cmd_receive_loop:
    JSR receive_byte        ; Get a byte from IEEE bus
    STA IEEE_CMD_BUF,X      ; Store in command buffer
    INX
    LDA IEEE_EOI_FLAG       ; Check if EOI was set
    BEQ @cmd_receive_loop   ; If not, get more bytes
    
    STX IEEE_CMD_BUF_LEN    ; Store length
    LDA #$01
    STA IEEE_CMD_WAITING    ; Set command waiting flag
    RTS

; Handle outgoing data as talker  
talk_handler:
    LDA IEEE_SEC_ADDR       ; Check which channel
    CMP #$10                ; Channels 0-15?
    BCC @cmd_talk           ; Handle command channel
    ; Channels > 15 not supported
    RTS

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
    ADC #TALK_STR_TABLE_ENTRY_LEN   ; Move onto the next entry
    CMP #TALK_STR_TABLE_LEN ; Check if we're over the end of the table
    BCC @lookup             ; Nope, go around end

    ; We failed to find an entry - build a None string instead
    JSR build_invalid_channel_str
    JMP @transmit

@valid_chan:
    LDA #DR0_LED
    STA RIOT_UE1_PBD        ; Set drive 0 LED on

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

    LDA #DR1_LED
    STA RIOT_UE1_PBD        ; Set drive 1 LED on

@transmit:
    ; Send the string from STRING_BUF
    LDX #$00
@cmd_send_loop:
    LDA STRING_BUF,X        ; Load from diags message
    BMI @last_byte          ; Last byte has MSB set
    JSR send_byte           ; Send the byte
    BIT IEEE_CONTROL        ; Check ATN
    BMI @done               ; unwind

    INX
    BNE @cmd_send_loop

@last_byte:
    JSR send_byte

@done:
    RTS

; Receive a byte from the IEEE bus
receive_byte:
    ; Wait for DAV low
@wait_dav_low:
    BIT IEEE_CONTROL
    BVS @wait_dav_low
    
    ; Read data
    LDA IEEE_DATA_IN_PORT
    EOR #$FF                ; Invert it
    PHA                     ; Save data byte
    
    ; Acknowledge with NDAC low (high as inverted)
    LDA #$02                ; Set NDAC high
    ORA IEEE_CONTROL
    STA IEEE_CONTROL
    
    ; Signal ready for next byte with NRFD high
    LDA #$04                ; NRFD high
    ORA IEEE_CONTROL  
    STA IEEE_CONTROL
    
    ; Wait for DAV high
@wait_dav_high:
    BIT IEEE_CONTROL
    BVC @wait_dav_high
    
    ; Retrieve and return data byte
    PLA
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

; Our no-op NMI handler
nmi_handler:
    RTI

; Our IRQ handler
;
; We jump to the address configured in zero page (and this must be initialized)
; before interrupts are enabled, or bad things will happen.  This allows us
; to change what gets called on interrupts dynamically.
irq_handler:
    JMP (IRQ_HANDLER)

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

; "Routine" which jumps to an indirect address.  This is in place of being
; to JSR to an indirect address, which the 6502 doesn't support.  Only actual
; routines must be jumped to here, or they won't return to the point that did
; JSR indirect_jsr.
indirect_jsr:
    JMP (IEEE_JMP_ADDR)     ; Jump to the routine we pointed to

; Include the 6504 binary, which is pre-built by the Makefile.  This allows us
; to copy the routine(s) we want from this binary to the shared RAM and then
; have the 6504 execute it.
.segment "CODE_6504"
code_6504_start:
.incbin "diag_x040_6504.bin"
code_6504_end:

CODE_6504_LEN = code_6504_end - code_6504_start

; If we're installed as the $F000 ROM, we need to provide a jump vector to
; START.
.segment "VECTORS"
.addr nmi_handler   ; NMI handler
.addr start
.addr irq_handler   ; IRQ handler
