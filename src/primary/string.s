; String handling routines for the diagnostics ROM.

; Copyright (c) 2025 Piers Finlayson <piers@piers.rocks>
;
; Licensed under the MIT License.  See [LICENSE] for details.

; Exports
.export build_channel_listing_str
.export build_summary_str
.export build_test_results_str
.export build_rom_info_str
.export build_status_str
.export build_invalid_channel_str

; Imports
.import ROM_INFO_STR_TABLE_LEN
.import rom_info_str_table
.import talk_str_table
.import TALK_STR_TABLE_LEN, TALK_STR_TABLE_ENTRY_LEN
.import StrStatusBooted, StrStatusOk, StrStatusInternalError, StrTestDelim
.import StrZeroPage, StrRam, Str6504Space, StrBoot, StrTakeover
.import StrFailed, StrPassed, StrNotAttempted, StrSpaceDashSpace
.import StrTestsFailed, StrTestsPassed, StrInvalidChannel
.import StrChannel, StrStatus

; Includes
.include "include/version.inc"
.include "include/shared.inc"
.include "include/macros.inc"
.include "include/primary/zeropage.inc"
.include "include/primary/constants.inc"

.segment "CODE"

;
; "Inlines" as these are only called once, saving 4 bytes.  If you need to call
; from elsewhere, turn into a routine and JSR it.
;

.macro AddZeroPage
    LDA #<StrZeroPage
    STA STR_PTR
    LDA #>StrZeroPage
    STA STR_PTR+1
    JSR add_string_no_nl
.endmacro

.macro AddRam
    LDA #<StrRam
    STA STR_PTR
    LDA #>StrRam
    STA STR_PTR+1
    JSR add_string_no_nl
.endmacro

.macro Add6504Boot
    JSR add_6504
    BEQ @add_6504_boot_done ; Exit if buffer full

    LDA #<StrBoot
    STA STR_PTR
    LDA #>StrBoot
    STA STR_PTR+1
    JSR add_string_no_nl

@add_6504_boot_done:
.endmacro

.macro Add6504Takeover
    JSR add_6504
    BEQ @add_6504_takeover_done ; Exit if buffer full

    LDA #<StrTakeover
    STA STR_PTR
    LDA #>StrTakeover
    STA STR_PTR+1
    JSR add_string_no_nl

@add_6504_takeover_done:
.endmacro

; Add a string with no-newline
;
; Simple helper routine, wrapping add_string
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

    JSR add_string_no_nl    ; Don't check Z bit as we've finished now anyway
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
    ; Although adding 2 chars is cheaper the add_char way, this way is cheaper
    ; here as we reuse the JSR for all approaches, and it's more obvious. 
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

;
; Routines to add specific strings.  Called from multiple places so cheaper to
; have them as separate routines.
;

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

; Adds "6504 "
add_6504:
    LDA #<Str6504Space
    STA STR_PTR
    LDA #>Str6504Space
    STA STR_PTR+1
    JSR add_string_no_nl
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

; Adds " - " to the string - 12 bytes, plus 3 for string
add_space_dash_space:
    LDA #<StrSpaceDashSpace
    STA STR_PTR
    LDA #>StrSpaceDashSpace
    STA STR_PTR+1
    JSR add_string_no_nl

@done:
    RTS

; Add ", " - 13 bytes, would be 14 bytes including string if we used the
; add_string_no_nl approach.  (It takes fewer bytes to do 2 chars this way,
; but is cheaper to do 3 and more chars the other way.)
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
    JSR add_space_dash_space
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
    JSR add_space_dash_space
    BEQ @done               ; Exit if buffer full

    ; Now log any failed RAM chips
    ; We do this by processing RESULT_RAM_TEST.  A '1' in a bit indicates a
    ; failed chip.
    ; - Bit 0 - UC5
    ; - Bit 1 - UD5
    ; - Bit 2 - UE5
    ; - Bit 3 - UF5
    ; - Bit 4 - UC4
    ; - Bit 5 - UD4
    ; - Bit 6 - UE4
    ; - Bit 7 - UF4

    LDA RESULT_RAM_TEST         ; Load the RAM test result
    STA NRTR                    ; Store for processing
    LDX #$00                    ; X will be our bit counter (0-7)
    STX NROC                    ; Store whether we've output any chips yet

@chip_loop:
    LSR NRTR                ; Shift right to check current bit
    BCC @next_bit           ; Skip if this bit is not set (no failure)

    ; This chip failed - output its name
    LDA NROC                ; Check if we've output any chips yet
    BEQ @skip_comma         ; Skip comma for first chip

    JSR add_comma_space
    BEQ @done               ; Exit if buffer full

@skip_comma:
    INC NROC                ; Mark that we've output at least one chip

    ; Output the 'U' at the beginning of the name
    LDA #$55                ; 'U' character
    JSR add_char
    BEQ @done               ; Exit if buffer full

    ; Calculate and output second character (C, D, E, or F)
    TXA                     ; Get bit number
    AND #$03                ; Mask to get 0-3 (for both groups)
    CLC
    ADC #$43                ; Add ASCII 'C' to the bit nummber 0-3 mask to get
                            ; C, D, E or F
    JSR add_char
    BEQ @done               ; Exit if buffer full
    
    ; Calculate and output third character (4 or 5 - 5 for lower nibble, 4 for
    ; upper)
    TXA                     ; Get bit number (index) again
    AND #$04                ; Check if bit is in upper half (bits 4-7)
    BNE @output_five        ; If 0, output '5'
    LDA #$34                ; ASCII '4'
    BNE @output_digit       ; A is non zero so always branches
@output_five:
    LDA #$35                ; ASCII '5'
@output_digit:
    JSR add_char
    BEQ @done               ; Exit if buffer full

@next_bit:
    INX                     ; Move to next bit
    CPX #$08                ; Check if we've done all 8 bits
    BCC @chip_loop          ; Continue if X < 8

    LDA #$01                ; Set A to 1 to show buffer not full

    ; Fall through to RTS
@done:
    RTS

; Add RAM test result
add_ram_result:
    AddRam
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
    Add6504Boot
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
    Add6504Takeover
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
    ADC #<TALK_STR_TABLE_ENTRY_LEN   ; Move to next entry
    TAX
    CPX #<TALK_STR_TABLE_LEN         ; Check if we've reached the end
    BCC @channel_loop       ; If not, continue loop
    
@done:
    JSR mark_last_byte_str
    RTS

; Create initial message to be sent when put into TALK mode via IEEE-488
build_rom_info_str:
    JSR setup_string_buf

    LDX #$00                ; String table index
@string_loop:
    STX STI                 ; Save current string table index in zero page

    ; Load string address (as a word)
    LDA rom_info_str_table,X   ; Get low byte
    STA STR_PTR
    LDA rom_info_str_table+1,X ; Get high byte
    STA STR_PTR+1
    
    LDA rom_info_str_table+2,X ; Get flags/action code
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
    CPX #<ROM_INFO_STR_TABLE_LEN ; Check if we've reached the end
    BCC @string_loop        ; Continue if not at end
    ; Otherwise fall through to done

@done:
    JSR mark_last_byte_str
    RTS

@do_version:
    JSR add_version_number
    BEQ @done
    JSR add_newline
    BNE @next_string
    BEQ @done

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

; Add version number
add_version_number:
    ; Assert version numbers are in valid range for this routine to work
    .assert MAJOR_VERSION <= 99, error, "MAJOR_VERSION > 99"
    .assert MINOR_VERSION <= 99, error, "MINOR_VERSION > 99"
    .assert PATCH_VERSION <= 99, error, "PATCH_VERSION > 99"

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
    CPX #$00            ; Test if we want leading zeros
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
    LDX #$00        ; X will hold the tens digit
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


; Don't inline - while only called once, the complicated RTS logic would be
; expensive to inline (would equire JMPs/branches), hence no savings.
add_zero_page_result:
    AddZeroPage
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

; Add underline characters based on the length of the last string
;
; Don't inline due to overlal complexity    
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
