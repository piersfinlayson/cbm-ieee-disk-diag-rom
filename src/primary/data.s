; Data for the diagnostics ROM.
;
; Contains strings, tables and other data used by the diagnostics ROM.

; Copyright (c) 2025 Piers Finlayson <piers@piers.rocks>
;
; Licensed under the MIT License.  See [LICENSE] for details.

; String exports
.export StrStatusBooted, StrStatusOk, StrStatusInternalError, StrTestDelim
.export StrZeroPage, StrRam, Str6504Space, StrBoot, StrTakeover
.export StrFailed, StrPassed, StrNotAttempted, StrSpaceDashSpace
.export StrTestsFailed, StrTestsPassed, StrInvalidChannel
.export StrDriveType
.export StrChannel, StrStatus

; Table exports
.export drive_type_table, talk_str_table, rom_info_str_table
.export TALK_STR_TABLE_ENTRY_LEN, TALK_STR_TABLE_LEN, ROM_INFO_STR_TABLE_LEN
.export RamTest0, RamTest1, RamTests, RamTestMask
.export RamTestLedPattern, RamTestBytePattern
.export SharedRamOffsets, SharedRamInitValues

; Import string routines to put in the tables
.import build_channel_listing_str
.import build_summary_str
.import build_test_results_str
.import build_drive_type_str
.import build_rom_info_str
.import build_status_str
.import build_drive_type_str

; Includes
.include "include/macros.inc"
.include "include/primary/constants.inc"
.include "include/shared.inc"

.segment "DATA"

;
; Strings
;

; All strings are encoded with CbmString in order to set the MSB high in the
; final byte.  This saves a byte vs null terminating, and allows us to test
; the minus bit (BMI/BPL) more cheaply than processing another byte.

; ROM information strings
CbmString StrRomName, "commodore ieee disk drive diagnostics rom"
CbmString StrVersion, "version: "
CbmString StrCopyright, "(c) 2025 piers finlayson"
CbmString StrRepo, "https://piers.rocks/u/ieeedr"

; Boot string, provided alongside status code 73.  Our equivalent of:
; "CBM DOS V2.6 1541"
;
; We use a max length of 22 bytes, in order to give us 8 bytes for the version
; number, and still hit 39 bytes for the entire status string including
; preceeding error code and command, and succeeding commas and track/sector
; numbers
;
; Version number of the format major.minor.patch immediatey follows v...
CbmString StrStatusBooted, "piers.rocks diag rom v"
END_STR_BOOT:
.assert (END_STR_BOOT - StrStatusBooted) <= 22, error, "StrStatusBooted too long"

; Strings used in test status reporting
CbmString StrStatusOk, "ok"
CbmString StrStatusInternalError, "internal error"
CbmString StrTestDelim, " test: "
CbmString StrZeroPage, "xero Page"
CbmString StrRam, "ram"
CbmString Str6504Space, "6504 "
CbmString StrBoot, "boot"
CbmString StrTakeover, "takeover"
CbmString StrFailed, "failed"
CbmString StrPassed, "passed"
CbmString StrNotAttempted, "not attempted"
CbmString StrSpaceDashSpace, " - "
CbmString StrNotImplemented, "not implemented"
CbmString StrTestsFailed, "test(s) failed"
CbmString StrTestsPassed, "all tests passed"
CbmString StrInvalidChannel, "invalid channel"
CbmString Str4040Dos1, "2040/3040 DOS1"
CbmString Str4040Dos2, "4040"
CbmString Str8050, "8050"
CbmString Str8250, "8250"
CbmString StrUnknown, "unknown"

; Channel string
CbmString StrChannel, "channel "

; Channel names
CbmString StrChannelListing, "channel list"
CbmString StrRomInfo, "rom info"
CbmString StrTestResults, "test results"
CbmString StrTestSummary, "test summary"
CbmString StrDriveType, "drive type"
CbmString StrStatus, "drive status"

;
; Tables
;

; Drive type table
drive_type_table:
    .byte DRIVE_TYPE_DD_DOS1
    .word Str4040Dos1
    .byte DRIVE_TYPE_DD_DOS2
    .word Str4040Dos2
    .byte DRIVE_TYPE_QD_SS
    .word Str8050
    .byte DRIVE_TYPE_QD_DS
    .word Str8250
drive_type_unknown:
    .byte $FF
    .word StrUnknown

; Table containing list of channels which are supported, and their mappings to
; - The string describing it (used in the channel - channel listing)
; - The string method to call to create the string
;
; Each entry contains 5 bytes:
; - Byte 0: Channel number (0-15)
; - Bytes 1/2: Word containing pointer to channel's name/purpose
; - Bytes 3/4: Word containing pointer to string method to call to create
;
; Embedded below is TALK_STR_TABLE_ENTRY_LEN, which is used to jump through the
; table testing for the channel number - we dynamically create this at compile
; time for safety.
;
; Also embedded below is TALK_STR_TABLE_LEN, used when iterating through the
; table to avoid over-shooting.
talk_str_table:
    .byte 0                         ; Channel num
    .word StrChannelListing
    .word build_channel_listing_str
END_TALK_STR_TABLE_FIRST_ENTRY:
TALK_STR_TABLE_ENTRY_LEN = (END_TALK_STR_TABLE_FIRST_ENTRY - talk_str_table)
.assert TALK_STR_TABLE_ENTRY_LEN < 256, error, "TALK_STR_TABLE_ENTRY_LEN too large"
    .byte 1                         ; Channel num
    .word StrTestSummary
    .word build_summary_str
    .byte 2                         ; Channel num
    .word StrTestResults
    .word build_test_results_str
    .byte 3                         ; Channel num
    .word StrDriveType
    .word build_drive_type_str
    .byte 14                        ; Channel num
    .word StrRomInfo
    .word build_rom_info_str
    .byte 15                        ; Channel num
    .word StrStatus
    .word build_status_str
TALK_STR_TABLE_END:
TALK_STR_TABLE_LEN = (TALK_STR_TABLE_END - talk_str_table)
.assert TALK_STR_TABLE_LEN < 256, error, "TALK_STR_TABLE_LEN too large"

; Table of intro strings, used by build_rom_info_str.
;
; Contains low byte, high byte, action code
;
; Action code:
;   Bit 0: CR flag (0=add newline, 1=don't add NL)
;   Bits 1-7: Action type (0=none, 1=add version, 2=underline)
;
; Strings will be added to create the intro message in the order shown
rom_info_str_table:
    .word StrRomName
    .byte %00000101         ; Add NL, underline

    .word StrVersion
    .byte %00000011         ; Don't add NL, action 1: add version number
 
    .word StrCopyright
    .byte %00000000         ; Add NL, no special action
    
    .word StrRepo
    .byte %00000000         ; Add NL, no special action
    
ROM_INFO_STR_TABLE_END:
ROM_INFO_STR_TABLE_LEN = (ROM_INFO_STR_TABLE_END - rom_info_str_table)
.assert ROM_INFO_STR_TABLE_LEN < 256, error, "ROM_INFO_STR_TABLE_LEN too large"

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

; Offsets from start of shared RAM that we check for 6504 aliveness on the
; 2040, 3040 and 4040 drives.
;
; We set the MSB for the last value.
;
; Only 8 offsets/byte tests are supported by check_6504_booted.
;
; We check:
; - $1000 ($400 on the secondary) - TICK, initialized to $0F
; - $1001 ($401 on the secondary) - DELAY, initialized to $32
; - $1002 ($402 on the secondary) - CUTMT, initialized to $FF
;
; These values are the same for both 901466-02 and 901466-04 (both DOS 1 and
; DOS 2 versions of the secondary processor's firmware).  Note that while TICK
; is actually initialized to $3F on the DOS 2 version, it is quickly changed
; to $0F.  As it takes us a while to check the secondary is alive, this should
; be fine.
SharedRamOffsets:
    .byte TICK_OFFSET, DELAY_OFFSET, CUTMT_OFFSET | $80
.assert SharedRamInitValues - SharedRamOffsets <= 8, error, "Too many shared RAM locations to check"

; Values we expect shared RAM locations to have, in order to show the 6504 is
; alive.
SharedRamInitValues:
    .byte TICK_INIT, DELAY_INIT, CUTMT_INIT
