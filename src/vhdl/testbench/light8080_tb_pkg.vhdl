--------------------------------------------------------------------------------
-- light8080_tb_pkg.vhdl -- Support package for Light8080 TBs.
--
-- Contains procedures and functions used to dump CPU traces, etc.
--
-- Please see the LICENSE file in the project root for license matters.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;
use work.txt_util.all;

use work.mcu80_pkg.all;


package light8080_tb_pkg is


-- Hex representation of std_logic_vector. 
function hstr(slv: unsigned) return string;

-- Every fetch cycle, log the fetch address to file.
-- Loops until done =1. 
procedure mon_cpu_trace (
                signal clk :    in std_logic;
                signal reset :  in std_logic;
                signal done :   in std_logic;
                file l_file :   TEXT);
                
end package;


package body light8080_tb_pkg is

function hstr(slv: unsigned) return string is
begin
    return hstr(std_logic_vector(slv));
end function hstr;

procedure mon_cpu_trace (
                signal clk :    in std_logic;
                signal reset :  in std_logic;
                signal done :   in std_logic;
                file l_file :   TEXT) is
begin
    
    while done = '0' loop
        wait until clk'event and clk='1';
        -- For the time being the log only contains fetch addresses.
        if mon_fetch = '1' then
             print(l_file, ""& hstr(mon_addr)& ": ");
        end if;
    end loop;

end procedure mon_cpu_trace;

end package body;
