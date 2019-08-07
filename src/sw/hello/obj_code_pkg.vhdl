--------------------------------------------------------------------------------
-- obj_code_pkg.vhdl -- Application object code in vhdl constant string format.
--------------------------------------------------------------------------------
-- Written by build_rom.py for project 'hello'.
--------------------------------------------------------------------------------
--                                                              
-- This source file may be used and distributed without         
-- restriction provided that this copyright statement is not    
-- removed from the file and that any derivative work contains  
-- the original copyright notice and the associated disclaimer. 
--                                                              
-- This source file is free software; you can redistribute it   
-- and/or modify it under the terms of the GNU Lesser General   
-- Public License as published by the Free Software Foundation; 
-- either version 2.1 of the License, or (at your option) any   
-- later version.                                               
--                                                              
-- This source is distributed in the hope that it will be       
-- useful, but WITHOUT ANY WARRANTY; without even the implied   
-- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      
-- PURPOSE.  See the GNU Lesser General Public License for more 
-- details.                                                     
--                                                              
-- You should have received a copy of the GNU Lesser General    
-- Public License along with this source; if not, download it   
-- from http://www.opencores.org/lgpl.shtml
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Package with utility functions for handling SoC object code.
use work.mcu80_pkg.all;

package obj_code_pkg is

-- Object code initialization constant.
constant object_code : obj_code_t(0 to 248) := (
    X"c3", X"60", X"00", X"00", X"00", X"00", X"00", X"00",  -- 0000h : 0007h
    X"c9", X"00", X"00", X"00", X"00", X"00", X"00", X"00",  -- 0008h : 000fh
    X"c9", X"00", X"00", X"00", X"00", X"00", X"00", X"00",  -- 0010h : 0017h
    X"c9", X"00", X"00", X"00", X"00", X"00", X"00", X"00",  -- 0018h : 001fh
    X"c9", X"00", X"00", X"00", X"00", X"00", X"00", X"00",  -- 0020h : 0027h
    X"c9", X"00", X"00", X"00", X"00", X"00", X"00", X"00",  -- 0028h : 002fh
    X"c9", X"00", X"00", X"00", X"00", X"00", X"00", X"00",  -- 0030h : 0037h
    X"c3", X"b0", X"00", X"00", X"00", X"00", X"00", X"00",  -- 0038h : 003fh
    X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00",  -- 0040h : 0047h
    X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00",  -- 0048h : 004fh
    X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00",  -- 0050h : 0057h
    X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00",  -- 0058h : 005fh
    X"31", X"5c", X"01", X"21", X"f7", X"00", X"22", X"f8",  -- 0060h : 0067h
    X"00", X"21", X"fc", X"00", X"22", X"fa", X"00", X"3e",  -- 0068h : 006fh
    X"14", X"d3", X"83", X"3e", X"58", X"d3", X"82", X"3e",  -- 0070h : 0077h
    X"00", X"d3", X"86", X"3e", X"08", X"d3", X"88", X"fb",  -- 0078h : 007fh
    X"21", X"9e", X"00", X"cd", X"e7", X"00", X"3e", X"55",  -- 0080h : 0087h
    X"d3", X"86", X"3e", X"04", X"d3", X"80", X"db", X"84",  -- 0088h : 008fh
    X"4f", X"07", X"07", X"81", X"d3", X"86", X"c3", X"8e",  -- 0090h : 0097h
    X"00", X"f3", X"76", X"c3", X"9b", X"00", X"0a", X"0d",  -- 0098h : 009fh
    X"0a", X"48", X"65", X"6c", X"6c", X"6f", X"20", X"57",  -- 00a0h : 00a7h
    X"6f", X"72", X"6c", X"64", X"21", X"0a", X"24", X"00",  -- 00a8h : 00afh
    X"e5", X"f5", X"db", X"81", X"e6", X"20", X"ca", X"c9",  -- 00b0h : 00b7h
    X"00", X"3e", X"20", X"d3", X"81", X"db", X"80", X"d3",  -- 00b8h : 00bfh
    X"86", X"2a", X"fa", X"00", X"77", X"23", X"22", X"fa",  -- 00c0h : 00c7h
    X"00", X"db", X"81", X"e6", X"10", X"ca", X"e3", X"00",  -- 00c8h : 00cfh
    X"3e", X"10", X"d3", X"81", X"2a", X"f8", X"00", X"7e",  -- 00d0h : 00d7h
    X"fe", X"24", X"ca", X"e3", X"00", X"23", X"22", X"f8",  -- 00d8h : 00dfh
    X"00", X"d3", X"80", X"f1", X"e1", X"fb", X"c9", X"7e",  -- 00e0h : 00e7h
    X"23", X"22", X"f8", X"00", X"fe", X"24", X"ca", X"f6",  -- 00e8h : 00efh
    X"00", X"d3", X"80", X"c3", X"e7", X"00", X"c9", X"24",  -- 00f0h : 00f7h
    X"00"                                                    -- 00f8h : 00f8h

);


end package obj_code_pkg;

