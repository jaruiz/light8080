--------------------------------------------------------------------------------
-- mcu80_tb.vhdl -- Minimal test bench for mcu80 (light8080 CPU wrapper).
--
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;
use std.textio.all;


-- Package with utility functions for handling SoC object code.
use work.mcu80_pkg.all;
-- Package that contains the program object code in VHDL constant format.
use work.obj_code_pkg.all;
-- Package with TB support stuff.
use work.light8080_tb_pkg.all;


entity mcu80_tb is
end entity mcu80_tb;

architecture behavior of mcu80_tb is

--------------------------------------------------------------------------------
-- Simulation parameters

-- T: simulated clock period
constant T : time := 100 ns;

-- MAX_SIM_LENGTH: maximum simulation time
constant MAX_SIM_LENGTH : time := T*70000; -- enough for most purposes


--------------------------------------------------------------------------------

signal clk :                std_logic := '0';
signal reset :              std_logic := '1';
signal done :               std_logic := '0';
signal pass :               std_logic := '0';
signal interrupts :         std_logic_vector(3 downto 0);
signal iop1 :               std_logic_vector(7 downto 0);
signal iop2 :               std_logic_vector(7 downto 0);
signal txd :                std_logic;
signal rxd :                std_logic;

-- Log file
file log_file: TEXT open write_mode is "hw_sim_log.txt";


begin

    -- Instantiate the Unit Under Test.
    uut: entity work.mcu80 
    generic map (
        OBJ_CODE => work.obj_code_pkg.object_code,
        UART_HARDWIRED => false,    -- UART baud rate NOT run-time programmable.
        UART_IRQ_LINE => 3,         -- UART uses IRQ3 line of irq controller.
        SIMULATION => True
    )  
    port map (
        clk =>              clk,
        reset =>            reset,

        p1_i =>             iop1,
        p2_o =>             iop2,

        extint_i =>         "0000",
        
        rxd_i =>            txd, -- Plain UART loopback.
        txd_o =>            txd
    );


    -- clock: Run clock until test is done.
    clock:
    process(done, clk)
    begin
        if done = '0' then
        clk <= not clk after T/2;
        end if;
    end process clock;


    -- main_test: Drive test stimulus, basically let CPU run after reset.
    main_test:
    process
    begin
        -- Assert reset for at least one full clk period
        reset <= '1';
        wait until clk = '1';
        wait for T/2;
        reset <= '0';

        -- Remember to 'cut away' the preceding 3 clk semiperiods from 
        -- the wait statement...
        wait until done='1' for (MAX_SIM_LENGTH - T*1.5);

        -- If we get here with done = '0', the test timed out.   
        assert (done = '1') 
        report "Test timed out."
        severity failure;

        -- Report failure if we didn't catch the pass condition...
        assert (pass = '1')
        report "Test FAILED."
        severity failure;
        -- ...and report a pass note otherwise.
        report "Test PASSED."
        severity note;
    
        wait;
    end process main_test;
  
    -- pass_fail_condition_check: Watch MCP port P2 for a pass/fail signature.
    pass_fail_condition_check:
    process
    begin
        loop
            wait on iop2;
            if iop2 = X"55" then 
                done <= '1';
                pass <= '1';
            elsif iop2 = X"AA" then
                done <= '1';
                pass <= '0';
            end if;
        end loop;
    end process pass_fail_condition_check;

    -- Logging process: launch logger functions --------------------------------


    log_execution:
    process
    begin
        -- Log cpu activity until done='1'.
        mon_cpu_trace(clk, reset, done, log_file);

        wait;
    end process log_execution;

end;
