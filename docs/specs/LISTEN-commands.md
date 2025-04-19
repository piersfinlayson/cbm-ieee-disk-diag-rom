# IEEE-488 LISTEN commands to drive testing

## ⚠️WARNING

It may be possible to damage the drive or any inserted disk through use of the commands listed in this document.  In particular:
- it may be possible to cause the head stepper motor to attempt to step too far, beyond its usual ROM allowed range
- moving the head without the motor spinning may cause physical damage to the disk, or cause the head to become dirty with disk debris.

Be particularly careful with the `E` command, which moves the head forward 70 half-tracks, to end-up track 35.  If the head starts above track 0, this will cause a reverse head-bang, which may not be good for the drive.

Proceed at your own risk, and take note of the [warranty](/LICENSE.md) (none!) that comes with this software.

## Overview

Allows commands to be sent to the drive via the IEEE-488 bus, in order to manually test the operation of the two drive units 0 and 1.  The operator assesses the actual drive behaviour through observation in response to these commands.

In addition to the drive unit commands, the operator can also reboot the drive using one of these commands.

In order to be able to use these commands, all of the following conditions must be met:
- The Diagnostics ROM's standard tests must have completed and the drive be in its [flash code reporting loop](/README.md#detailed-result-information).
- The IEEE-488 port must be functional and connected to a controller which can issue the commands.  This can be a Commodore computer, or a PC with an IEEE-488 interface such as the xum1541/ZoomFloppy (IEEE-488 variant).

In order to test whether the drive's IEEE-488 bus is operational, connect to the drive and query channel 15 for the drive's status using one of:
- a DOS Wedge `@` command
- the `BASIC` Program at [📟Last Operation Status](/README.md#last-operation-status)
- [OpenCbm's](https://github.com/OpenCBM/OpenCBM) `cbmcrl status <device id>` command
- [xum1541's](https://github.com/piersfinlayson/xum1541) `cargo run --example talk` command

## Command set

All commands are 1 character LISTEN commands, received on channel 15.

Any multi character commands, those received on other channels, or those (other than `A`) received whil in flash code mode are ignored.  In command-mode the error is reported by lighting the ERR LED solidly.  In either command mode or flash code mode, the status queryable via channel 15 is updated to reflect the error.

Proposed command set:

| Command | Description | Notes | Implemented? |
|---------|-------------|-------|--------------|
| A      | Enter command mode || yes |
| 0      | Select drive 0 (default) || yes |
| 1      | Select drive 1 || yes |
| B      | Bump selected drive head against track 0 | Attemps 140 half steps in reverse | yes |
| E      | Move to end | Attampts 70 half steps forward | Will reach track 35 if starts from 0 | yes |
| M      | Motor on || yes |
| N      | Motor off || yes |
| H      | Set half track increment | Default - not explicitly implemented | no |
| W      | Set whole track increment | Decided not to implement | no |
| F      | Move head forward (to a higher track) by current increment |Moves 1/2 track| yes |
| R      | Move head reverse (to a lower track) by current increment |Moves 1/2 track| yes |
| Z      | [Reboot entire drive](#reboot) || yes |
| X      | Exit to command mode to flash code loop || yes |

The diagnostics ROM pauses handling IEEE-488 commands until the previous command has been executed.

### Reboot

This works by reseting both the secondary (6504) processor and primary processors by jumping to their ROM reset vectors, stored at $FFFC-$FFFD.  Programmatically is the same as booting the drive from power on, although timing and RAM and other state may differ from either a cold power on or reset via the IEEE-488 IFC line.

## Status Reporting

Any command which causes an error is reported through lighting the ERR LED solid.  The drive status, available via TALK on channel 15, is updated to reflect the error in line with standard Commodore drive status codes.

When a command is received and accepted, the appropriate drive LED briefly flashes (de-illuminate and then re-light) to indicate that the command has been accepted.

## LED Status

When in command mode, one or both of the drive is lit solidly.

- Drive 0 LED lit solid - drive 0 selected (default after entering command mode)
- Drive 1 LED lit solid - drive 1 selected

If an error occurs, the ERR LED is lit solidly until the error is queried via [TALK on channel 15]((../../README.md#last-operation-status)).

## Implementation Notes

### Entering/Exiting command mode

Entering the command mode is done by the interrupt handler reseting the stack, and then pushing the command mode routine's address onto the stack, followed by the CPU's register state (bit 5 is set high - so `$20`).  When the interrupt handler returns, using `RTI`, the CPU will jump to the command mode routine.

Similarly to exit command mode, the interrupt resets the stack with the `finished` routine's address, and the CPU's register state is again set to `$20`.

### Rebooting

Reboot is handled as above by jumping to the ROM's reset vector.  The 6504 is instructed to reset prior to the 6502 resetting.  This means that the 6504 resets prior to the 6502.  Care is taken within the 6502 code not to touch the shared RAM once the 6504 has been instructed to reset, as doing so might overwrite initial state written by the newly booted 6504.   