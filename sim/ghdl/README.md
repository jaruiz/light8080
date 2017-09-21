## Getting Started

This makefile will let you run a test on the light8080 core. 

All tests are simple programs that run on a common RTL test bench.
The TB instantiates entity mcu80, which is a simple MCU built around the barebones CPU core. 
The MCU includes an UART, a couple of basic I/O ports and a chunk of BRAM of configurable size.
The BRAM is writeable and it is initialized with the object code of the test in question. 
Please read the source and the makefile to see how to configure this basic test scheme for other tests.

This is how you launch a test:

```shell
make sim TEST=<test name>
```

That target will build the test SW, generating a VHDL package with the object code in the shape of a byte array literal, 
which the TB entity will then use to initialize a block of RAM. 

It will also build the CPU microcode if necessary, putting the microcode in another vhdl package. 
This should only ever happen once, or really not even once because the project includes the pregenerated vhdl package ready made. 
So if you want to tinker with the microcode you can do so but there is no need to do so at all.

You can find the tests in directory ```../../src/sw``` relative to this one. 
As you can see, there's not much to choose from right now:)
By default test ```disgnostic``` will be run -- it's a classic 8080/8085 CPU tester that I have slightly adapted for this project. 
There should be a README file there with a useful description.

None of the tests have any console output. I somehow lost that capability when I ported the tests from Modelsim to GHDL. 
It should be easy to bring it back (?). Anyway, you will see no output from the CPU in any of the tests, including test ```hello```.


Also, this test scheme does not have a golden model or anything like that. The CPU is left to its own devices and has to test
itself like hard silicon CPUs did in the bad old days -- by running self checking code. 
Test ```diagnostic``` is actually a classic example of such code and the TB displays the test outcome, which is written by the diagnostic 
program on an I/O port.

So if you see a 'pass' message then the CPU works as far as the diagnostic program is concerned.

The OpenCores version of this project has a few more tests, including one for interrupts. 
I guess some day I'll get around to porting them to this repo.

### Requirements

In order to play with this TB with no modifications you will need ghdl and also ASL, an assembler for the 8080. 
The makefile within the ```tools``` directory in this project has a target for the automatic installation of ASL which will only need git and gcc on your machine, no root privileges or anything -- it's only ever been tested on Linux, though. It is meant to install the program for you transparently; at at the very least it should be a good starting point if you have to install it yourself...
Al other necessary utility scripts are included with the project.




