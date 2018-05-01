# RC2018/04 Project : Game for use with a NES Zapper to PC/Tandy 1000 adapter

## Overview

This repository contains the source code for the mini-game RainZapper I produced
to go with the NES Zapper to Tandy 1000 adapter I built, in the context of the
April 2018 edition of the RetroChallenge.

For the complete write-up and adapter schematics/wiring tables, see below:

* [Project page (english)](http://www.raphnet.net/divers/retro_challenge_2018_04/index_en.php)
* [Project page (french)](http://www.raphnet.net/divers/retro_challenge_2018_04/index.php)

## Compilation

Simply type 'make' in the top directory. This will compile the tools (PNG image conversion, data compression,
LUT and font generation, etc), generate the binary resources for inclusion by the ASM sources and nasm will
run last to assemble the executables.

Under Debian Linux, at least the following packages are required:

* liblz4-dev
* libpng-dev
* nasm
* make
* gcc

If all goes well, the following files will be generated:

### Tandy only

* rain.com - The RainZapper mini-game
* zapdemo1.com - A simple test program with a shootable square and non-shootable square. (See April 9 update in project page)
* zapdemo2.com - A demo for measuring the Y position the Zapper is pointing at using timing. Also has colors and lines of varying thicknesses for testing the performance of the Zapper.

### VGA only

* rainvga.com - VGA Version of the RainZapper mini-game (as of now, still a work in progress)

## Development

### A Very quick guide to the source

While the code is split between several .asm file, this project does not use a linker. The required
parts are included using the %include nasm directive. The drawback of this technique is that there
is a lot of dead code (i.e. Even unused routines are compiled and take space in the executable).

Top level files (each once is the "main" for a .com output file):
* rain.asm : The RainZapper mini-game. The source is shared between different versions.
* zapdemo1.asm : Top level file for zapdemo1.com
* zapdemo2.asm : Top level file for zapdemo2.com

Middle layer code:
* gameloop.asm : A concept of a very simple gameloop with callbacks, with zapper support.
* lang.asm : Macros and helpers to retreive strings in the current language
* lz4.asm : LZ4 decompression routine, slightly modified from Jim Leonard's LZ4_8088 routine
* mobj.asm : MovingOBJect. Macros and routines to manipulate the struc/object concept I experimented for raindrops.
* mouse.asm : Simple wrapper around the int 33h mouse interface.
* random.asm : A pseudo random number generator
* score.asm : Score keeping code (uses expanded BCD fast display)
* sin.asm : Crude sine function based on a lookup table
* sugar.asm : A collection of macros supposed to increase readability. YMMV.
* zapper.asm : The code for working with a Zapper on a joystick port. Also accesses the video registers to poll for vertical retrace. Also supports mice.

Video library stuff:
* cgalib.asm : Code for CGA 320x200 4 color mode
* tgalib.asm : Code for Tandy 320x200 16 color mode
* vga16lib.asm : Code for VGA 640x480 16 color
* videolib_common.asm : Code common to all versions of the library

### Coding style

No consistent style, and some parts of the project (the CGA/TGA video libraries) are not very
well written and do rather inefficient things. My excuse is that they date back to 2016 when I
started working on [RATillery](http://www.raphnet.net/programmation/ratillery/index_en.php), my
first game written in assembly. (That said, even new code could be criticized...)

### Testing in DOSBox

The makefile contains targets to easily and quickly start the compiled programs or game inside DOSBox.

For instance, the following starts the Tandy version of the RainZapper mini-game:
```
make runrain
```

Available targets are:
* runrain : Starts rain.com in DOSBox
* runrainvga : Starts rainvga.com in DOSBox
* run : Starts zapdemo1.com in DOSBox
* run2 : Starts zapdemo2.com in DOSBox

Other targets may exist for work in progress items such as the VGA or CGA versions.

## Authors
* **Raphael Assenat**

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.


## Acknowledgments

* **Jim Leonard** - For the [8088 LZ4 decompression code](http://www.oldskool.org/pc/lz4_8088)
