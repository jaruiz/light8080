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

-- Maximum line size of for console output log. Lines longer than this will be
-- truncated.
constant CONSOLE_LOG_LINE_SIZE : integer := 1024*4;

-- Console log line buffer --------------------------------------
signal con_line_buf :   string(1 to CONSOLE_LOG_LINE_SIZE);
signal con_line_ix :    integer;


-- Hex representation of std_logic_vector. 
function hstr(slv: unsigned) return string;

-- Every fetch cycle, log the fetch address to file.
-- Loops until done =1. 
procedure mon_cpu_trace (
                signal clk :    in std_logic;
                signal reset :  in std_logic;
                signal done :   inout std_logic;
                signal con_line_buf : inout string(1 to CONSOLE_LOG_LINE_SIZE);
                signal con_line_ix : inout integer;
                file con_file : TEXT;
                file log_file : TEXT);
                
end package;


package body light8080_tb_pkg is

function hstr(slv: unsigned) return string is
begin
    return hstr(std_logic_vector(slv));
end function hstr;

procedure mon_cpu_trace (
                signal clk :    in std_logic;
                signal reset :  in std_logic;
                signal done :   inout std_logic;
                signal con_line_buf : inout string(1 to CONSOLE_LOG_LINE_SIZE);
                signal con_line_ix : inout integer;
                file con_file : TEXT;
                file log_file : TEXT) is
begin
    
    while done = '0' loop
        wait until clk'event and clk='1';
        -- For the time being the log only contains fetch addresses.
        if mon_fetch = '1' then
             print(log_file, ""& hstr(mon_addr)& ": ");
        end if;


        -- Console logging ------------------------------------------------
        if mon_uart_ce = '1' and mon_we = '1' and 
           mon_addr(1 downto 0) = "00" then
            -- UART TX data goes to output after a bit of line-buffering
            -- and editing
            if mon_wdata = X"0A" then
                -- CR received: print output string and clear it
                print(con_file, con_line_buf(1 to con_line_ix));
                print(con_line_buf(1 to con_line_ix));
                con_line_ix <= 1;
                con_line_buf <= (others => ' ');
            elsif mon_wdata = X"0D" then
                -- ignore LF. I should be doing the opposite...
            elsif mon_wdata = X"04" then
                -- EOT terminates simulation.
                print("Execution terminated by SW -- EOT written to UART_DATA.");
                done <= '1';
            else
                -- append char to output string
                if con_line_ix < con_line_buf'high then
                    con_line_buf(con_line_ix) <= 
                            character'val(to_integer(unsigned(mon_wdata)));
                    con_line_ix <= con_line_ix + 1;
                end if;
            end if;
        end if;  





    end loop;

end procedure mon_cpu_trace;

end package body;
