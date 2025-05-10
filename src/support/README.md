# Commodore IEEE Disk Diagnostics ROM Support Program

This directory contains the source code for the Commodore IEEE Disk Diagnostics ROM Support Program, a program designed to work alongside the Diagnostics ROM to help test and fix Commodore IEEE-488 drives.

There are two versions:

1. One written in PET BASIC and is designed to run on a 40/80 column PET/CBM computer.
2. One written in Rust and intended to run on a Linux PC, driving the IEEE-488 bus using a ZoomFloppy or xum1541.

## Building the Program

### TL;DR

```bash
make support
```

### PET

You can create a PRG file and D64 of the support program usine the Makefile.  This requires the VICE emulator to be installed on your system:

```bash
sudo apt update && sudo apt -y install vice
```

Then, from the repository root, run:

```bash
make pet_support
```

This creates:

```bash
build/support/ieee-support.prg
build/support/ieee-support.d64
```

### PC

Install Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Then, from the repository root, run:

```bash
make pc_support
```

This creates:

```bash
build/support/pc-support
```

## Using the Program

Install the diagnostics ROM into your IEEE-488 drive, connect to your PET and power them both on.  Once the diagnostics tests have finished running, which has happened when the drive starts [flashing the device ID](/README.md#reporting-device-id), you can load and run the program.

Obviously you will need to use some other mechanism to load the problem other than your drive under test - for example an [SD2PET](https://www.tfw8b.com/product/sd2pet-commodore-pet/).

### PET

Load and run the program:

```basic
LOAD "IEEE-SUPPORT",8,1
RUN
```

Enter the device ID of the drive under test when prompted, or hit `RETURN` if your drive is device ID 8.

![Enter Device ID](/docs/images/support/enter-device-id.png "Enter Device ID")

You will then see the main screen where you can [run commands]() on the drive and query status information from the diagnostics ROM, including test output.

![Main Screen](/docs/images/support/main-screen.png "Main Screen")

There is a help sreen if you want some more assistance:

![Help](/docs/images/support/help.png "Help")

### PC

The PC version of the program is a command line program.  You can run it with:

```bash
./build/support/pc-support
```

There is a `--help` option.
