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
