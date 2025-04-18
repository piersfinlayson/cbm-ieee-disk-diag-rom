; This file contains macros used by the project. 

; Copyright (c) 2025 Piers Finlayson <piers@piers.rocks>
;
; Licensed under the MIT License.  See [LICENSE] for details.

; Helper macro for Commodore-style strings, which are terminated with the last
; byte having the high bit set.  Saves us a byte and is slightly easier to
; test when the string terminates.
.macro CbmString label, str
    label:
    .repeat .strlen(str)-1, i
        .byte .strat(str, i)
    .endrepeat
    .byte .strat(str, .strlen(str)-1) | $80
.endmacro