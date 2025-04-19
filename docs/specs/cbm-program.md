# Commodore IEEE Disk Diagnostics ROM Support Program

## Overview

The Commodore IEEE Disk Diagnostics ROM Support Program (called Support Program) is a program that is designed work alongside the Diagnostics ROM, running on a PET/CBM computer, to help test and fix your Commodore IEEE-488 drive.

## Features

* Designed to interact with the Diagnostics ROM over IEEE-488.
* Supports drives at device IDs 8-15 inclusive.
* On connection to the device, reads the status channel (15) and the channel list (channel 0) and outputs which channels contain diagnostics information.
* Allows all channels from 0-15 to be queried via TALK mode.
* Supports sending commands to the drive via LISTEN mode using channel 15, including:
    * `A` - Enter command mode
    * `0` - Select drive 0 (default)
    * `1` - Select drive 1
    * `B` - Bump selected drive head against track 0
    * `E` - Move to track 35
    * `M` - Motor on
    * `N` - Motor off
    * `F` - Move head forward (to a higher track)
    * `R` - Move head reverse (to a lower track)
    * `X` - Exit to command mode to flash code loop
    * `Z` - Reboot entire drive
* Supports sending the following commands a configured number of times with 50ms delay between each command:
    * `F` - Move head forward (to a higher track)
    * `R` - Move head reverse (to a lower track)

## Implementation Notes

* Written in PET BASIC.
* Prompts the user at startup for th device ID to use.  Should default to 8 (to for example allowing the user to just hit `RETURN` to select).
* If the user requests command `E`, the program asks the user for confirmation before proceeding, due to the potential for a reverse head bump if the drive is not at track 0.
* All information queried via TALK mode is sent by the diagnostics ROM as soon as the drive is instructed to TALK on the appropriate channel.
* Diagnostics ROM only supports receiving commands on channel 15, and only supports receiving 1 byte per LISTEN/UNLISTEN iteration.
* Designed to display nicely on a PET 40 column display.
* Display is designed to be static and not scrolling - rather updating as the user runs operations.
* Handles error gracefully, in particular if the computer cannot communicate with the drive when first connecting.
* If `Z` command is run, program will implicitly disconnect from the drive and reset to the start of the program.
* Code is commented.