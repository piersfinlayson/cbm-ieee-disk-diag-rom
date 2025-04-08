; This file contains zero page address allocations for the 6502 
;
; Copyright (c) 2025 Piers Finlayson <piers@piers.rocks>
;
; Licensed under the MIT License.  See [LICENSE] for details.

.if .not .defined(CPU_6502)
    .error "This file is only used by the 6502"
.endif

; Zero page constants
ZP = $00

; General purpose temporary storage.  When using, care must be taken not to
; call other routines that will overwrite these locations.
TEMP_A = $00
TEMP_B = $01
TEMP_C = $02
TEMP_X = $03
TEMP_Y = $04
TEMP_Z = $05
TEMP_RTN_A = $06
TEMP_RTN_B = $07

; General purpose temporary pointer storage - each of which reserves 2 bytes
TEMP_PTR1 = $08              ; $09 also required
TEMP_PTR2 = $0A              ; $0B also required

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
RESC_RTN = TEMP_RTN_A
RP1 = TEMP_PTR1         ; test_ram_page - pointer to ram test table 
RP2 = TEMP_PTR2         ; test_ram_byte(_pattern) - pointer to byte under test

; Used by routines to control 6504
CWS = TEMP_A            ; wait_6504_status - status to wait for
C_RTN = TEMP_RTN_A      ; control_6504 return - value (internal only)
CP1 = TEMP_PTR1         ; copy_6504_cmd - pointer to code source
CP2 = TEMP_PTR2         ; copy_6504_cmd - pointer to code destination

; Used by notification routines
NFTC = TEMP_A           ; flash_led_error - notification flash target count
NFLP = TEMP_B           ; flash_led_error - notification flash LED pattern

; Uniquely assigned temporary storage locations.  These are uniquely assigned
; to specific routines, as these routines use is widespread.

; Used by delay routine
DX = $0C
DY = $0D

; Used by blink routine
BX = $0E
BY = $0F

; Reserved for future temporary use: $10-$1F

; Stores device ID (8-15).  If 0, the device ID has not been read.
DEVICE_ID = $20

; Bits 1/0 cover upper/lower nibble of $1000-$13FF - 0 success, 1 failure
; Bits 3/2 cover $2000-$23FF - 0 success, 1 failure
; Bits 5/4 cover $3000-$33FF - 0 success, 1 failure
; Bits 7/6 cover $4000-$43FF - 0 success, 1 failure
RESULT_RAM_TEST = $21

; Used to store test results from the 6504.
; - Bits 0/1 contain control information:
;   - 0 if control takeover not attempted
;   - 1 if control takeover suceeded
;   - 2 if control takeover failed
RESULT_6504 = $22
