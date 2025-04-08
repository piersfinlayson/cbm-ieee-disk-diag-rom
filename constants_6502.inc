; This file contains constants for the 6502 
;
; Copyright (c) 2025 Piers Finlayson <piers@piers.rocks>
;
; Licensed under the MIT License.  See [LICENSE] for details.

.if .not .defined(CPU_6502)
    .error "This file is only used by the 6502"
.endif

; RIOT chip addresses
RIOT_UE1_PBD = $0282
RIOT_UE1_PBDD = $0283

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

; Magic byte at the start of the diagnostics ROM (located at $D000), which is
; tested by the stock ROMs, to see if the diagnostics ROM is present.
DIAG_START_BYTE = $55

; Bit masks for TESTS_6502 zero page variable.  The bits are in this order, as
; this is the order finished: goes through them reporting any errors and other
; results.
TEST_ZP = $01
TEST_RAM1 = $02
TEST_RAM2 = $04
TEST_6504_TO = $08
TEST_DI = $10

; Bit masks for RESULT_ZP.
ZP_UC1 = $01
ZP_UE1 = $02