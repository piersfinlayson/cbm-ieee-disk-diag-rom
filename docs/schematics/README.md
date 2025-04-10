# 📐Schematics and PCB Layouts

This directory contains schematics for Commodore IEEE-488 disk drives.  For additional schematics and other technical information, see [zimmers.net](http://www.zimmers.net/anonftp/pub/cbm/schematics/drives/old/index.html).

## 💾2040/3040/4040

Digital PCB schematics:
- [4040 6502 "side"](./4040-320806-digital-1.gif)
- [4040 6504 "side"](./4040-320806-digital-2.gif)
- [4040 Drive control](./4040-320806-digital-3.gif)

Digital PCB layout:
- [4040 Digital PCB layout](./4040-320806-digital-layout.png)

Analog PCB schematic:
- [4040 Analog controller](./4040-320816-analog.gif)

Analog PCB layout:
- [4040 Analog controller layout](./4040-320816-analog-layout.gif)

There are some minor differences between early (mostly/entirely 2040?) digital PCBs and later ones such as the 3040 and 4040:

- UA1 is not populated on the 2040.  It appears to have been installed on later boards to clean up some of the clock signals.  See
    - pin 39 of the 6502 (UN1)
    - pin 28 of the 6504 (UH3)

## © Copyright

All schematics in this directory are Copyright © Commodore Business Machines.