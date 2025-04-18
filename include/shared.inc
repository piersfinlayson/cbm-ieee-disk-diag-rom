; This file contains constants shared between the primary and secondary
; processors implementations.

; Copyright (c) 2025 Piers Finlayson <piers@piers.rocks>
;
; Licensed under the MIT License.  See [LICENSE] for details.

.if .not .defined(PRIMARY_CPU)
    .if .not .defined(SECONDARY_CPU)
        .error "Must define either PRIMARY_CPU or SECONDARY_CPU"
    .endif
.endif

SHARED_RAM_6502_START = $1000
SHARED_RAM_6504_START = $400
.ifdef PRIMARY_CPU
SHARED_RAM_START = SHARED_RAM_6502_START
.else
SHARED_RAM_START = SHARED_RAM_6504_START
.endif

; Address for the JOB 0 slot.  This is $0403 on the 6504 and comes
; from the Commodore 6504 ROM, located in the 6530 RRIOT chip at UK3, part
; number 901466.
JOB_0_SLOT = SHARED_RAM_START + $03

; Value the 1st bank of static RAM is mapped to on the 6504 relative to the
; 6504.
.ifdef SECONDARY_CPU
RAM_BANK_1_OFFSET = ($1000 - $400)
.endif

; There are two command locations, as the 6504 will only perform an operation
; if it written to both bytes.  This is to stop is accidently causing the 6504
; to perform an operation when we are testing the shared RAM.  We shouldn't do
; this while it is listening at that location, but belts and braces.
CMD1 = SHARED_RAM_START + $F0
CMD2 = SHARED_RAM_START + $F1

; Location for any variables for commands.  Used by the TEST_DRIVE command
CMD_VAR = SHARED_RAM_START + $F2

; Location the 6504 control routine we caue it to execute uses to store its
; status.
STATUS_6504 = SHARED_RAM_START + $F3

; Location the 6504 control routine uses to store the result of the command
CMD_RESULT = SHARED_RAM_START + $F4

; Command this result refers to.
CMD_RESULT_CMD = SHARED_RAM_START + $F5


.ifdef PRIMARY_CPU
; Used for string to send.
; Again, we chose $1300 as in the first bank of RAM.
STRING_BUF = $1300
.endif


CMD_RESULT_NONE = $80
CMD_RESULT_OK = $00
CMD_RESULT_ERR = $01

; Commands used to control the 6504 via the 6502's control routine.  As above,
; these must be written to both CMD locations to cause the 6504 control
; routine to execute them.  They must match the values in that file.

; Value indicating no command has been issued. 
CMD_NONE = $00        ; Must be zero as that's how static RAM is left

; Test drives
CMD_TEST_DRIVE = $01

; These commands instruct the 6504 control routine to reset the 6504 - this
; jumps to the reset vector.
CMD_RESET = 'Z'

; These are the supported status values the 6504 routine may return.
STATUS_6504_NONE = $00
STATUS_6504_RUNNING = $01
STATUS_6504_TESTING_DRIVE = $02
STATUS_6504_RESETTING = $FF

.ifdef PRIMARY_CPU
; 6502/6504 shared job of type execute.  Must be ORed with $80 to indicate to
; the 6504, running stock ROM code, that it should execute our code.  This
; comes from the 6504 ROM (901466).
JOB_EXEC = $60
JOB_BUMP = $40
.endif

.ifdef PRIMARY_CPU
; Constants indicating where the code to be copied to the shared RAM to control
; the 6504 is located in this ROM.
.ifdef F000_BUILD
  SECONDARY_CODE_START = $FF00
.else
  SECONDARY_CODE_START = $DF00
.endif
.endif

; Constants indicating shared RAM locations (as offsets from the start) used by
; the stock 6504 ROM
TICK_OFFSET = $00
DELAY_OFFSET = $01
CUTMT_OFFSET = $02

; Constants indicating expected values of shared RAM locations used by the
; stock 6504 ROM.
TICK_INIT = $0F
DELAY_INIT = $32
CUTMT_INIT = $FF

; Location of RESET vector (some for both processors, although contents will
; differ).
RESET = $FFFC