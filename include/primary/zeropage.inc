; This file contains zero page address allocations for the primary processor. 

; Copyright (c) 2025 Piers Finlayson <piers@piers.rocks>
;
; Licensed under the MIT License.  See [LICENSE] for details.

.if .not .defined(PRIMARY_CPU)
    .error "This file is only used by the 6502"
.endif

; Zero page constants - start of the 6502's zero page.
; - $00-$7F is provided by the 6532 RIOT chip (UC1)
; - $80-$FF is provided by the 6530 RRIOT chip (UE1)
ZP = $00

; Offset to our zero page variables.  We set this to $80 in order to only use
; the UE1's zero page.  We need some zero page, and we rely on UE1's because
; that chip also controls the LEDs.  We test but don't rely on UC1's zero page.
ZP_OFFSET = $80

; Stack pointer.  Again, we use the UE1's zero page for this.
STACK_PTR = $7F + ZP_OFFSET

; General purpose temporary storage.  When using, care must be taken not to
; call other routines that will overwrite these locations.
TEMP_A = $00 + ZP_OFFSET
TEMP_B = $01 + ZP_OFFSET
TEMP_C = $02 + ZP_OFFSET
TEMP_X = $03 + ZP_OFFSET
TEMP_Y = $04 + ZP_OFFSET
TEMP_Z = $05 + ZP_OFFSET
TEMP_RTN_A = $06 + ZP_OFFSET
TEMP_RTN_B = $07 + ZP_OFFSET

; General purpose temporary pointer storage - each of which reserves 2 bytes
TEMP_PTR1 = $08 + ZP_OFFSET  ; $09 also required
TEMP_PTR2 = $0A + ZP_OFFSET  ; $0B also required

; Other routines use the above zero page locations.  However, they must be
; assigned uniquely at the top-level (at the level of routines called directly
; from with_stack_main), to avoid risk of writing over other routines' usage.

; Used by RAM routines - which use the general purpose temporary storage
RPY = TEMP_A            ; test_ram_page - Y storage
RPI = TEMP_B            ; test_ram_page pattern - index
REX = TEMP_C            ; get_error_shift_count - X storage
RBPI = TEMP_X           ; test_ram_byte - pattern index
RBPY = TEMP_Y           ; test_ram_byte_pattern - Y storage
RBPN = TEMP_Z           ; test_ram_byte_pattern - nibble storage
RBPT = TEMP_RTN_A       ; test_ram_byte - temporary pattern storage
RESC_RTN = TEMP_RTN_B   ; get_error_shift_count - how much to shift error
                        ; value for chip/nibble under test
RP1 = TEMP_PTR1         ; test_ram_page - pointer to ram test table 
RP2 = TEMP_PTR2         ; test_ram_byte(_pattern) - pointer to byte under test

; Used by routines to check 6504 booted
BRBI = TEMP_A           ; check_6504_booted - result bit index
BLI = TEMP_B            ; check_6504_booted - last byte indicator

; Used by routines to control 6504
CP1 = TEMP_PTR1         ; copy_6504_cmd - pointer to code source
CP2 = TEMP_PTR2         ; copy_6504_cmd - pointer to code destination
CP_TEMP1 = TEMP_Y       ; copy_6504_cmd
CP_TEMP2 = TEMP_Z       ; copy_6504_cmd

; Used by notification routines
NFTC = TEMP_A           ; flash_led_error - notification flash target count
NFLP = TEMP_B           ; flash_led_error - notification flash LED pattern
NFLPO = TEMP_C          ; flash_led_error - notification flash LED pattern original
NRZP = TEMP_X           ; finished - temporary ZP result value
NRCC = TEMP_X           ; finished - temporary RAM chip count value
NRNCN = TEMP_Y          ; finished - temporary RAM nibble chip number value
NRCR = TEMP_Z           ; finished - temporary RAM chip result value

; Used by drive test routine
TS = TEMP_A             ; test_drive - drive test state
TWT = TEMP_B            ; test_drive - wait time
TD = TEMP_C             ; test_drive - drive number  

; Uniquely assigned temporary storage locations.  These are uniquely assigned
; to specific routines, as these routines use is widespread.

; Used by delay routine
DX = $0C + ZP_OFFSET
DY = $0D + ZP_OFFSET

; Used by blink routine
BX = $0E + ZP_OFFSET
BY = $0F + ZP_OFFSET

; Used by wait_6504_status
WSB = $10 + ZP_OFFSET   ; wait_6504_status byte

; Used by check_takover
CTA = $11 + ZP_OFFSET   ; check_takover - temporary A

; String routines
STI = $12 + ZP_OFFSET   ; string handling - temporary value
BUF_INDEX = $13 + ZP_OFFSET ; string handling - temporary value
STR_INDEX = $14 + ZP_OFFSET ; string handling - temporary value
STR_LEN = $15 + ZP_OFFSET   ; string handling - temporary value
STJ = $16 + ZP_OFFSET   ; string handling - temporary value

; Zero page values used by routines adding test results strings.
; They are used by
; - add_failed_ram_chips
; - add_failed_zp_chips
NROC = TEMP_A               ; whether we've output any chips
NRTR = TEMP_B               ; ram test result for processing

BUF_PTR = TEMP_PTR1
STR_PTR = TEMP_PTR2

; Reserved for future temporary use: $16-$1F

; Used to track which tests have been performed by the 6502 code.  See the
; TEST_* values in constant_6502.inc for the tests that are performed for the
; bit assignments.  A 1 indicats that test has been performed.
TESTS_6502 = $20 + ZP_OFFSET

; Zero page result.  A 1 indicates the test failed.
RESULT_ZP = $21 + ZP_OFFSET

; Stores device ID (8-15).  If 0, the device ID has not been read.
DEVICE_ID = $22 + ZP_OFFSET

; Bits 0-3 cover the lower nibble of the page number ($1x-$4x)
; Bits 4-7 cover the upper nibble of the page number ($1x-$4x)
RESULT_RAM_TEST = $23 + ZP_OFFSET

; Used to store test results from check_6504_booted.
; - Bit 0 contains 0 if successful, 1 if failure - see TESTS_6502
;   for whether this has been attempted (and hence this bit is valid)
RESULT_6504_BOOT = $24 + ZP_OFFSET

; Used to store test results from control_6504.
RESULT_6504_TO = $25 + ZP_OFFSET

; Used to store test results from test_drive.
RESULT_DRIVE0 = $26 + ZP_OFFSET
RESULT_DRIVE1 = $27 + ZP_OFFSET

; Used to store last operation status from the device, similar to how a stock
; Commodore disk drive does.  This is transmitted when channel 15 is put into
; talk.
DEVICE_STATUS = $28 + ZP_OFFSET

; Reserved for future use: $29-$2D

; Used to dynamically change the interrupt handler - must be set before
; enabling interrupts
IRQ_HANDLER = $2E + ZP_OFFSET   ; And $2F

; Used by IEEE-488 routines

OUR_TALK_ADDR = $30 + ZP_OFFSET
OUR_LISTEN_ADDR = $31 + ZP_OFFSET
IEEE_DATA_BYTE = $32 + ZP_OFFSET
IEEE_EOI_FLAG = $33 + ZP_OFFSET
IEEE_LISTEN_ACTIVE = $34 + ZP_OFFSET
IEEE_TALK_ACTIVE = $35 + ZP_OFFSET
IEEE_ADDRESSED = $36 + ZP_OFFSET
IEEE_SEC_ADDR = $37 + ZP_OFFSET
IEEE_CMD_BUF = $38 + ZP_OFFSET
IEEE_CHAN_TEST = $39 + ZP_OFFSET
IEEE_JMP_ADDR = $3A + ZP_OFFSET
; Also $3B

CMD_LOOP_LED = $3C + ZP_OFFSET