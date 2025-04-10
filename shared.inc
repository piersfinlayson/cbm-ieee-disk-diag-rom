; This file contains constants shared between the 6504 and 6502 code
;
; Copyright (c) 2025 Piers Finlayson <piers@piers.rocks>
;
; Licensed under the MIT License.  See [LICENSE] for details.

.if .not .defined(CPU_6502)
    .if .not .defined(CPU_6504)
        .error "Must define either CPU_6502 or CPU_6504"
    .endif
.endif

.ifdef CPU_6502
; Address for the JOB 0 slot.  This is $0403 on the 6504 and comes
; from the Commodore 6504 ROM, located in the 6530 RRIOT chip at UK3, part
; number 901466.
JOB_0_SLOT = $1003
.endif

; Value the 1st bank of static RAM is mapped to on the 6504 relative to the
; 6504.
.ifdef CPU_6504
RAM_BANK_1_OFFSET = ($1000 - $400)
.endif

; There are two command locations, as the 6504 will only perform an operation
; if it written to both bytes.  This is to stop is accidently causing the 6504
; to perform an operation when we are testing the shared RAM.  We shouldn't do
; this while it is listening at that location, but belts and braces.
.ifdef CPU_6502
CMD1 = $10F0
CMD2 = $10F1
.else
CMD1 = $10F0 - RAM_BANK_1_OFFSET
CMD2 = $10F1 - RAM_BANK_1_OFFSET
.endif

; Location the 6504 control routine we caue it to execute uses to store its
; status.
.ifdef CPU_6502
STATUS_6504 = $10F2
.else
STATUS_6504 = $10F2 - RAM_BANK_1_OFFSET
.endif

; Commands used to control the 6504 via the 6502's control routine.  As above,
; these must be written to both CMD locations to cause the 6504 control
; routine to execute them.  They must match the values in that file.

; Value indicating no command has been issued. 
CMD_NONE = $0

; These commands instruct the 6504 control routine to reset the 6504 - this
; jumps to the reset vector.
CMD_RESET = $FF

; These are the supported status values the 6504 routine may return.
STATUS_6504_NONE = $00
STATUS_6504_RUNNING = $01
STATUS_6504_RESETTING = $02

.ifdef CPU_6502
; 6502/6504 shared job of type execute.  Must be ORed with $80 to indicate to
; the 6504, running stock ROM code, that it should execute our code.  This
; comes from the 6504 ROM (901466).
JOB_EXEC = $60
JOB_BUMP = $40
.endif

.ifdef CPU_6502
; Constants indicating where the code to be copied to the shared RAM to control
; the 6504 is located in this ROM.
.ifdef F000_BUILD
  CODE_6504_START = $FF00
.else
  CODE_6504_START = $DF00
.endif
CODE_6504_CMD_PTR = CODE_6504_START + 0
CODE_6504_CMD_LEN = CODE_6504_START + 2
.endif