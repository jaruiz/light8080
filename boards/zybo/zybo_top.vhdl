--
--
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Package that contains the program object code in VHDL constant format.
use work.obj_code_pkg.all;

entity ZYBO_TOP is
  port(
    -- Clock from Ethernet PHY. @note1.
    clk_125MHz_i        : in std_logic;

    -- Pushbuttons.
    buttons_i           : in std_logic_vector(3 downto 0);
    -- Switches.
    switches_i          : in std_logic_vector(3 downto 0);
    -- LEDs.
    leds_o              : out std_logic_vector(3 downto 0);
    -- PMOD E (Std) connector -- PMOD UART (Digilent).
    pmod_e_2_txd_o      : out std_logic;
    pmod_e_3_rxd_i      : in std_logic
  );
end entity ZYBO_TOP;

architecture rtl of ZYBO_TOP is

signal clk :                std_logic;
signal reset :              std_logic;

signal extint :             std_logic_vector(3 downto 0);
signal iop1 :               std_logic_vector(7 downto 0);
signal iop2 :               std_logic_vector(7 downto 0);


begin

  clk <= clk_125MHz_i;
  reset <= buttons_i(3);


  -- Light8080 MCU and glue logic ----------------------------------------------

  mcu: entity work.mcu80 
  generic map (
      OBJ_CODE => work.obj_code_pkg.object_code,
      UART_HARDWIRED => false,    -- UART baud rate NOT run-time programmable.
      UART_IRQ_LINE => 3,         -- UART uses IRQ3 line of irq controller.
      BAUD_RATE => 115200,        -- UART baud rate.
      CLOCK_FREQ => 125E6         -- Clock frequency in Hz.
  )  
  port map (
      clk =>            clk,
      reset =>          reset,

      p1_i =>           iop1,
      p2_o =>           iop2,

      extint_i =>       extint,
      
      txd_o =>          pmod_e_2_txd_o,
      rxd_i =>          pmod_e_3_rxd_i
  );

  extint <= iop2(7 downto 4);
  iop1(3 downto 0) <= switches_i;
  iop1(7 downto 4) <= buttons_i;


  -- Smoke test logic (to be removed when up and running) ----------------------

  process(clk)
  begin
    if clk'event and clk='1' then
      if reset = '1' then
        leds_o <= "1010";
      else 
        leds_o <= iop2(3 downto 0);
      end if;
    end if;
  end process;

end;


-- @note1: Clock active if PHYRSTB is high. PHYRSTB pin unused, pulled high.  
