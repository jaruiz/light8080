Build makefile -- light8080 demo on Digilent's ZYBO board using Vivado.

This script will build the project bit stream file using Vivado's non-project 
flow mode. The only step not covered in the script is loading the bit stream on 
the target board itself.

The script is meant to be used through the makefile.

Script `build.tcl` has been mostly copied from the example in page 11 of the
Vivado Tcl scripting guide (ug894, 'Using Tcl Scripting'). 

Output files, including the bit stream, can be found in `./output/zybo_demo`.


USAGE
-----

make help       will display a short list of goals.
make all        will launch the synthesis flow. 
make clean      will clean the directory.


XILINX ENVIRONMENT VARIABLES
----------------------------

You need to set up the Xilinx variables before invoking the makefile.
In a regular Linux install this can be done by running this script:

    /opt/Xilinx/Vivado/*/settings64.sh

Regular users of Vivado won't need this information and casual users need more
than I can supply here. But that hint should get you on the right path.


FILES
-----

build.tcl           -- Run synth and implementation, create bitstream file.
makefile            -- Interface to the build script.
README.txt          -- This file.


TARGET
------

Script build.tcl contains a list of source files and constraint file(s).
All the target HW dependencies (ZYBO board) are contained in the constraints
file.
This script is meant to be generic apart form the file lists and arguments
defined at the beginning. It's just a stock Xilinx script.


BUILD 8080 CODE BEFORE SYNTHESIS
--------------------------------

The build needs a vhdl package to initialize the 8080 code memory. Script 
build.tcl defines a variable `OBJ_CODE_DIR` that should point to a directory 
containing such a package.
The scripts uses the diagnostic SW sample by default; you need to edit the 
script manually to use any other piece of 8080 software, provided you built the
package for it.
The SW samples in this project can be used as examples.


COMPATIBILITY
-------------

This has been tested with Vivado 2015.4 and 2017.4 running on a Linux machine.

It should be possible to run this mini-flow unmodified on Windows but I can't
verify that myself.
