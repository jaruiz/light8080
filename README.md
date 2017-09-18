# light8080
Synthesizable i8080-compatible CPU core.

(This project lived in [OpenCores](https://opencores.org/project,light8080) until late '16, and a copy will remain there as long as OpenCores is up. See below.)

## Description

This is a simple, small microprogrammed Intel 8080 CPU binary compatible core. 

There are already at least two other 8080-compatible cores in Opencores, both of them well proven. This one is different because it emphasizes area instead of cycle-count compatibility or speed. 

I have tried to minimize logic size and complexity as much as possible, at the expense of speed. At about the same size as a Picoblaze on a Spartan 3 (204 LUTs + 1 BRAM), this is perhaps amongst the smallest 8-bit CPU cores available. On the other hand, it is rather slow in clock frequency and particularly in cycles per instruction (25 to 50% more clocks per instruction than the original, which is an awful lot! -- see the design notes). Besides, the 2 KBytes of dedicated fpga ram it does use may in some designs be more valuable than a large number of logic blocks. 

The source is quite simple: a single RTL file with some 970 lines of straightforward, moderately commented VHDL code; plus a microcode package file ~530 lines long with the microcode ROM data. However, the simplicity may be deceptive; it can be argued that the complexity of the system has been moved from the RTL to the microcode... 

A description of the circuit and its microcode is included in the design notes and the respective source files. The microcode assembler (a Python script) is included too, as well as the microcode source from which the VHDL uCode ROM table was built, though it is not necessary if you just want to use the core and not modify it. 

This is just a fun project I created back in 2007 to learn vhdl; my design goal was to get the simplest possible 8080-compatible core, at the smallest possible size, at any reasonable speed. And above all, at a minimum cost in development time -- so I could get something worthy done in the very limited time available.
Though I think I accomplished my goal, the resulting core is probably of little practical use: it is certainly no match for a picoblaze in its application niche, and it is not small enough to compensate for its lack of features (the smallest Nios II is only 2 or 3 times larger). And there are better 8080 cores around, as I said. 

I am in debt with Scott A. Moore for [his cpu8080 core](http://opencores.org/project,cpu8080). Though I have not used his code in this project, I studied it and did use much of the research and test material that he made available. 



## Features

- Microcoded design, very simple circuit.
- Microcode source and assembler included, though the vhdl microcode table can be edited directly.
- Slower than original in clocks per instructions (about 25 to 50%, comparative table included in the design notes).
- 100% binary compatible to original 8080.
- Synchronized to positive clock edges only.
- Signal interface very simplified. Not all original status info available (no M1, for instance).
- Synchronous memory and i/o interface, with NO WAIT STATE ability.
- INTA procedure similar to original 8080, except it can use any instruction as int vector.
- Undefined/unused opcodes are NOPs.



### Performance (standalone CPU, synthesis only): 

1. Xilinx XST on Spartan 3 (-5 grade):
 * 204 LUTs plus 1 BRAM @ 80 MHz (optimized for area)
 * 228 LUTs plus 1 BRAM @ 100 MHz (optimized for speed)
 * 618 LUTs @ 53 MHz (optimized for area, no block ram)

2. Altera Quartus on Cyclone 2:
 * 369 LEs plus 4 M4Ks @ 67 MHz (balanced optimization)
 
3. Xilinx Vivado on Zynq-7000 (XC7Z010-1CLG400C):
 * 334 LUTs (no BRAMs) @ 125 MHz (clock constrained to 125MHz, 0.45 ns slack)

_(Note that the Zynq build uses no BRAM for the microcode, thanks to the 6 input LUTs mostly.)_


## Status 

The core has already executed some quite large pieces of original code in hardware, including the Microsoft Altair 4K Basic.
Interrupt response has been simulated and tested in real hardware (but test
sources not yet moved to this repo!).
The project includes a minimal MCU system built around the CPU core that can be useful as an usage example or as the starting point for a real application.

Besides, thanks to Moti Litochevski the project is now available in both Verilog and VHDL versions (but only on the OpenCores site, Verilog port not moved to GitHub yet!).


Compatibility to the original Intel 8080 has not yet been achieved at 100% -- the CY flag undocumented behavior for some logic instructions is slightly incompatible. This is an issue that can't be fixed without a lot of testing with original 8080 chips, or with very accurate simulators.


Please note that the documented behavior of the CPU is 100% compatible to the original; it's only the *undocumented* behavior of the original silicon that has not yet been fully replicated -- only almost. 
We have set up some demos to showcase the core. 



## Portage to GitHub

This core used to be at [OpenCores](https://opencores.org/project,light8080). I moved it here in late '16 and slightly refactored it. 
These are the differences: 

* Project used to rely on DOS Batch files, now it uses Makefiles and is Linux-centric.
* Simulations used to rely on Modelsim. Now I've included makefiles and updated RTL to use GHDL...
 * ...although of course you can use whatever simulator you want.
* Verilog version made by Moti Litochevski not moved yet to GitHub...
 * ...and this includes some other goodies Moti added to the project, including a free Small C compiler port.
* Demos, including Altair 4K Basic, not moved yet to GitHub.
* Project used to be tested on Xilinx ISE. Now it includes synthesis scripts for Vivado only...
 * ...because I no longer have a functional install of ISE.
* Microcode ROM data extracted to a separate VHDL package.
* Microcode assembler rewritten from scratch in Python.



This list is mostly a reminder to myself of things that remain to be done on this project. The project as it stands here in GitHub should be usable (inasmuch as an 8080 core is usable).


