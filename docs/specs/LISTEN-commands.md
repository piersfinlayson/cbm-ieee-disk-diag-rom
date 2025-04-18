# IEEE-488 LISTEN commands to drive testing

## ⚠️WARNING

It may be possible to damage the drive or any inserted disk through use of the commands listed in this document.  In particular:
- it may be possible to cause the head stepper motor to attempt to step too far, beyond its usual ROM allowed range
- moving the head without the motor spinning may cause physical damage to the disk, or cause the head to become dirty with disk debris.

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

Proposed command set:

| Command | Description |
|---------|-------------|
| A      | Enter command mode |
| 0      | Select drive 0 (default) |
| 1      | Select drive 1 |
| B      | Bump selected drive |
| E      | Move to track 35 |
| M      | Motor on |
| N      | Motor off |
| H      | Set half track increment |
| W      | Set whole track increment |
| F      | Move forward by current increment |
| R      | Move reverse by current increment |
| Z      | Reboot entire drive |
| X      | Exit to flash code loop |

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
