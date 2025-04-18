; Includes the secondary CPU's binary and embeds it within the primary ROM
; image.
;
; See [README.md] for build and usage instructions.

; Copyright (c) 2025 Piers Finlayson <piers@piers.rocks>
;
; Licensed under the MIT License.  See [LICENSE] for details.

.export secondary_start, SECONDARY_CODE_LEN

; Include the secondary CPU's binary, which is pre-built by the Makefile.
; This allows us to copy the routine(s) we want from this binary to the shared
; RAM and then have the ssecondary processor execute it.
.segment "SECONDARY"

secondary_start:
.incbin "build/secondary_control.bin"
SECONDARY_END:
SECONDARY_CODE_LEN = SECONDARY_END - secondary_start
