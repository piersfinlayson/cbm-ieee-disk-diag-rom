; This file contains constants for the primary processor.

; Copyright (c) 2025 Piers Finlayson <piers@piers.rocks>
;
; Licensed under the MIT License.  See [LICENSE] for details.

.if .not .defined(PRIMARY_CPU)
    .error "This file is only used by the 6502"
.endif

; RIOT chip addresses
RIOT_UC1_PAD = $0200
RIOT_UC1_PADD = $0201
RIOT_UC1_PBD = $0202
RIOT_UC1_PBDD = $0203
RIOT_UE1_PAD = $0280
RIOT_UE1_PADD = $0281
RIOT_UE1_PBD = $0282
RIOT_UE1_PBDD = $0283
RIOT_UE1_ATNPE = $0287

IEEE_DATA_IN_PORT = RIOT_UC1_PAD
IEEE_DATA_IN_DIR = RIOT_UC1_PADD
IEEE_DATA_OUT_PORT = RIOT_UC1_PBD
IEEE_DATA_OUT_DIR = RIOT_UC1_PBDD
IEEE_CONTROL = RIOT_UE1_PAD
IEEE_CONTROL_DIR = RIOT_UE1_PADD

; LED bit masks
; - DR1_LED is PB3
; - DR0_LED is PB4
; - ERR_LED is PB5
ERR_LED = $20
DR0_LED = $10
DR1_LED = $08
ALL_LEDS = ERR_LED | DR0_LED | DR1_LED
ERR_AND_0_LED = ERR_LED | DR0_LED
ERR_AND_1_LED = ERR_LED | DR1_LED
DR01_LEDS = DR0_LED | DR1_LED

; Bit masks for TESTS_6502 zero page variable.  The bits are in this order, as
; this is the order finished: goes through them reporting any errors and other
; results.
TEST_ZP = $01
TEST_RAM0 = $02
TEST_RAM1 = $04
TEST_6504_BOOT = $08
TEST_6504_TO = $10
TEST_DRIVES = $20
TEST_DEV_ID = $40

; Bit masks for RESULT_ZP.
ZP_UC1 = $01
ZP_UE1 = $02

; Values for RESULT_6504_TO
RESULT_6504_TO_OK = $00
RESULT_6504_TO_ERR = $01

; Drive test states
TEST_DRIVE_CHECK = $01
TEST_DRIVE_STARTING = $02
TEST_DRIVE_TESTING = $03
TEST_DRIVE_TESTED_OK = $04
TEST_DRIVE_TESTED_ERR = TEST_DRIVE_TESTED_OK+1
TEST_DRIVE_WAIT_TIME = $1E  ; 30 seconds

; Last byte to be sent after the diagnostic status
IEEE_DIAG_TERM = $00

; Device status codes, returned on channel 15 like a stock drive
DEVICE_STATUS_BOOTED = 73
DEVICE_STATUS_OK = 0
DEVICE_STATUS_INTERNAL_ERROR = 99
