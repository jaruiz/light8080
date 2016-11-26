--##############################################################################
-- light8080 : Intel 8080 binary compatible core
--##############################################################################
-- v1.4    (01 dec 2016) Moved to GitHub, uC extracted to separate package.
-- v1.3    (12 feb 2012) Fix: General solution to AND, OR, XOR clearing CY,ACY.
-- v1.2    (08 jul 2010) Fix: XOR operations were not clearing CY,ACY.
-- v1.1    (20 sep 2008) Microcode bug in INR fixed.
-- v1.0    (05 nov 2007) First release. Jose A. Ruiz.
--
-- This file and all the light8080 project files are freeware (See COPYING.TXT)
--##############################################################################
-- (See timing diagrams at bottom of file. More comprehensive explainations can 
-- be found in the design notes)
--##############################################################################

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

use work.light8080_ucode_pkg.all;

--##############################################################################
-- vma :      enable a memory or io r/w access.
-- io :       access in progress is io (and not memory) 
-- rd :       read memory or io 
-- wr :       write memory or io
-- data_out : data output
-- addr_out : memory and io address
-- data_in :  data input
-- halt :     halt status (1 when in halt state)
-- inte :     interrupt status (1 when enabled)
-- intr :     interrupt request
-- inta :     interrupt acknowledge
-- reset :    synchronous reset
-- clk :      clock
--
-- (see timing diagrams at bottom of file)
--##############################################################################
entity light8080 is
    generic (
        -- uCode ROM implementation: BRAM or LUT {"block"|"distributed"}. 
        UCODE_ROM_STYLE : string := "distributed"
    );
    port (  
        addr_out :  out std_logic_vector(15 downto 0);
          
        inta :      out std_logic;
        inte :      out std_logic;
        halt :      out std_logic;                
        intr :      in std_logic;
        
        vma :       out std_logic;
        io :        out std_logic;
        rd :        out std_logic;
        wr :        out std_logic;
        fetch :     out std_logic;
        data_in :   in std_logic_vector(7 downto 0);  
        data_out :  out std_logic_vector(7 downto 0);

        clk :       in std_logic;
        reset :     in std_logic
    );
end light8080;

--##############################################################################
-- All memory and io accesses are synchronous (rising clock edge). Signal vma 
-- works as the master memory and io synchronous enable. More specifically:
--
--    * All memory/io control signals (io,rd,wr) are valid only when vma is 
--      high. They never activate when vma is inactive. 
--    * Signals data_out and address are only valid when vma='1'. The high 
--      address byte is 0x00 for all io accesses.
--    * Signal data_in should be valid by the end of the cycle after vma='1', 
--      data is clocked in by the rising clock edge.
--
-- All signals are assumed to be synchronous to the master clock. Prevention of
-- metastability, if necessary, is up to you.
-- 
-- Signal reset needs to be active for just 1 clock cycle (it is sampled on a 
-- positive clock edge and is subject to setup and hold times).
-- Once reset is deasserted, the first fetch at address 0x0000 will happen 4
-- cycles later.
--
-- Signal intr is sampled on all positive clock edges. If asserted when inte is
-- high, interrupts will be disabled, inta will be asserted high and a fetch 
-- cycle will occur immediately after the current instruction ends execution,
-- except if intr was asserted at the last cycle of an instruction. In that case
-- it will be honored after the next instruction ends.
-- The fetched instruction will be executed normally, except that PC will not 
-- be valid in any subsequent fetch cycles of the same instruction, 
-- and will not be incremented (In practice, the same as the original 8080).
-- inta will remain high for the duration of the fetched instruction, including
-- fetch and execution time (in the original 8080 it was high only for the 
-- opcode fetch cycle). 
-- PC will not be autoincremented while inta is high, but it can be explicitly 
-- modified (e.g. RST, CALL, etc.). Again, the same as the original.
-- Interrupts will be disabled upon assertion of inta, and remain disabled 
-- until explicitly enabled by the program (as in the original).
-- If intr is asserted when inte is low, the interrupt will not be attended but
-- it will be registered in an int_pending flag, so it will be honored when 
-- interrupts are enabled.
-- 
--
-- The above means that any instruction can be supplied in an inta cycle, 
-- either single byte or multibyte. See the design notes.
--##############################################################################

architecture microcoded of light8080 is

-- addr_low: low byte of address
signal addr_low :     std_logic_vector(7 downto 0);
-- IR: instruction register. some bits left unused.  
signal IR :           std_logic_vector(7 downto 0);
-- s_field: IR field, sss source reg code
signal s_field :      std_logic_vector(2 downto 0);
-- d_field: IR field, ddd destination reg code
signal d_field :      std_logic_vector(2 downto 0);
-- p_field: IR field, pp 16-bit reg pair code
signal p_field :      std_logic_vector(1 downto 0);
-- rbh: 1 when p_field=11, used in reg bank addressing for 'special' regs
signal rbh :          std_logic; -- 1 when P=11 (special case)  
-- alu_op: uinst field, ALU operation code 
signal alu_op :       std_logic_vector(3 downto 0);
-- DI: data input to ALU block from data_in, unregistered
signal DI :           std_logic_vector(7 downto 0);
-- uc_addr: microcode (ucode) address 
signal uc_addr :      unsigned(7 downto 0);
-- next_uc_addr: computed next microcode address (uaddr++/jump/ret/fetch)
signal next_uc_addr : unsigned(8 downto 0);
-- uc_jmp_addr: uinst field, absolute ucode jump address
signal uc_jmp_addr :  std_logic_vector(7 downto 0);
-- uc_ret_address: ucode return address saved in previous jump
signal uc_ret_addr :  std_logic_vector(7 downto 0);  
-- addr_plus_1: uaddr + 1
signal addr_plus_1 :  std_logic_vector(7 downto 0);  
-- do_reset: reset, delayed 1 cycle -- used to reset the microcode sequencer
signal do_reset :     std_logic;  

-- uc_flags1: uinst field, encoded flag of group 1 (see ucode file)
signal uc_flags1 :    std_logic_vector(2 downto 0);
-- uc_flags2: uinst field, encoded flag of group 2 (see ucode file)
signal uc_flags2 :    std_logic_vector(2 downto 0);  
-- uc_addr_sel: selection of next uc_addr, composition of 4 flags
signal uc_addr_sel :  std_logic_vector(3 downto 0);
-- NOTE: see microcode file for information on flags
signal uc_jsr :       std_logic;  -- uinst field, decoded 'jsr' flag
signal uc_tjsr :      std_logic;  -- uinst field, decoded 'tjsr' flag
signal uc_decode :    std_logic;  -- uinst field, decoded 'decode' flag
signal uc_end :       std_logic;  -- uinst field, decoded 'end' flag
signal condition_reg :std_logic;  -- registered tjst condition
-- condition: tjsr condition (computed ccc condition from '80 instructions)
signal condition :    std_logic;
-- condition_sel: IR field, ccc condition code
signal condition_sel :std_logic_vector(2 downto 0);
signal uc_do_jmp :    std_logic;  -- uinst jump (jsr/tjsr) flag, pipelined
signal uc_do_ret :    std_logic;  -- ret flag, pipelined
signal uc_halt_flag : std_logic;  -- uinst field, decoded 'halt' flag
signal uc_halt :      std_logic;  -- halt command
signal halt_reg :     std_logic;  -- halt status reg, output as 'halt' signal
signal uc_ei :        std_logic;  -- uinst field, decoded 'ei' flag
signal uc_di :        std_logic;  -- uinst field, decoded 'di' flag
signal inte_reg :     std_logic;  -- inte status reg, output as 'inte' signal
signal int_pending :  std_logic;  -- intr requested, inta not active yet
signal inta_reg :     std_logic;  -- inta status reg, output as 'inta'
signal clr_t1 :       std_logic;  -- uinst field, explicitly erase T1
signal do_clr_t1 :    std_logic;  -- clr_t1 pipelined
signal clr_t2 :       std_logic;  -- uinst field, explicitly erase T2
signal do_clr_t2 :    std_logic;  -- clr_t2 pipelined
signal ucode :        std_logic_vector(31 downto 0); -- microcode word
signal ucode_field2 : std_logic_vector(24 downto 0); -- pipelined microcode

-- used to delay interrup enable for one entire instruction after EI
signal delayed_ei :   std_logic;

-- microcode ROM : see design notes and microcode source file 
signal rom : t_rom := microcode;

-- Xilinx attribute for BRAM-vs-LUT implementation choice.
attribute rom_style : string;
attribute rom_style of rom : signal is UCODE_ROM_STYLE;


signal load_al :      std_logic; -- uinst field, load AL reg from rbank
signal load_addr :    std_logic; -- uinst field, enable external addr reg load
signal load_t1 :      std_logic; -- uinst field, load reg T1 
signal load_t2 :      std_logic; -- uinst field, load reg T2
signal mux_in :       std_logic; -- uinst field, T1/T2 input data selection
signal load_do :      std_logic; -- uinst field, pipelined, load DO reg
-- rb_addr_sel: uinst field, rbank address selection: (sss,ddd,pp,ra_field)
signal rb_addr_sel :  std_logic_vector(1 downto 0);
-- ra_field: uinst field, explicit reg bank address
signal ra_field :     std_logic_vector(3 downto 0);
-- rb_wr_index: uinst field, explicit reg bank wr address
--signal rb_wr_index :  std_logic_vector(3 downto 0);
signal rbank_data :   std_logic_vector(7 downto 0); -- rbank output
signal alu_output :   std_logic_vector(7 downto 0); -- ALU output
-- data_output: datapath output: ALU output vs. F reg 
signal data_output :  std_logic_vector(7 downto 0); 
signal T1 :           std_logic_vector(7 downto 0); -- T1 reg (ALU operand)
signal T2 :           std_logic_vector(7 downto 0); -- T2 reg (ALU operand)
-- alu_input: data loaded into T1, T2: rbank data vs. DI
signal alu_input :    std_logic_vector(7 downto 0);
signal we_rb :        std_logic; -- uinst field, commands a write to the rbank
signal inhibit_pc_increment : std_logic; -- avoid PC changes (during INTA)
signal rbank_rd_addr: std_logic_vector(3 downto 0); -- rbank rd addr
signal rbank_wr_addr: std_logic_vector(3 downto 0); -- rbank wr addr
signal DO :           std_logic_vector(7 downto 0); -- data output reg
    
-- Register bank as an array of 16 bytes.
-- This will be implemented as asynchronous LUT RAM in those devices where this
-- feature is available (Xilinx) and as multiplexed registers where it isn't
-- (Altera).
type t_reg_bank is array(0 to 15) of std_logic_vector(7 downto 0);
-- Register bank : BC, DE, HL, AF, [PC, XY, ZW, SP]
signal rbank :        t_reg_bank;

signal flag_reg :     std_logic_vector(7 downto 0); -- F register
-- flag_pattern: uinst field, F update pattern: which flags are updated
signal flag_pattern : std_logic_vector(1 downto 0);
signal flag_s :       std_logic; -- new computed S flag  
signal flag_z :       std_logic; -- new computed Z flag
signal flag_p :       std_logic; -- new computed P flag
signal flag_cy :      std_logic; -- new computed C flag
signal flag_cy_1 :    std_logic; -- C flag computed from arith/logic operation
signal flag_cy_2 :    std_logic; -- C flag computed from CPC circuit
signal do_cy_op :     std_logic; -- ALU explicit CY operation (CPC, etc.)
signal do_cy_op_d :   std_logic; -- do_cy_op, pipelined
signal do_cpc :       std_logic; -- ALU operation is CPC
signal do_cpc_d :     std_logic; -- do_cpc, pipelined
signal do_daa :       std_logic; -- ALU operation is DAA
signal clear_cy :     std_logic; -- Instruction unconditionally clears CY
signal clear_ac :     std_logic; -- Instruction unconditionally clears AC
signal set_ac :       std_logic; -- Instruction unconditionally sets AC
signal flag_ac :      std_logic; -- New computed half carry (AC) flag
signal flag_ac_daa :  std_logic; -- AC flag computed in the special case of DAA
signal flag_ac_and :  std_logic; -- AC flag computed in the special case of AN*
-- flag_aux_cy: new computed half carry flag (used in 16-bit ops)
signal flag_aux_cy :  std_logic;
signal load_psw :     std_logic; -- load F register

-- aux carry computation and control signals
signal use_aux :      std_logic; -- decoded from flags in 1st phase
signal use_aux_cy :   std_logic; -- 2nd phase signal
signal reg_aux_cy :   std_logic;
signal aux_cy_in :    std_logic;
signal set_aux_cy :   std_logic;
signal set_aux  :     std_logic;

-- ALU control signals -- together they select ALU operation
signal alu_fn :       std_logic_vector(1 downto 0);
signal use_logic :    std_logic; -- logic/arith mux control 
signal mux_fn :       std_logic_vector(1 downto 0); 
signal use_psw :      std_logic; -- ALU/F mux control

-- ALU arithmetic operands and result
signal arith_op1 :    signed(8 downto 0);
signal arith_op2 :    signed(8 downto 0);  
signal arith_op2_sgn: signed(8 downto 0);
signal arith_res :    signed(8 downto 0);
signal arith_res8 :   signed(7 downto 0);  

-- ALU DAA intermediate signals (DAA has fully dedicated logic)
signal daa_res9 :     signed(8 downto 0);    
signal daa_test1 :    std_logic;  
signal daa_test1a :   std_logic;  
signal daa_test2 :    std_logic;  
signal daa_test2a :   std_logic;  
signal arith_daa_res :std_logic_vector(7 downto 0);     
signal cy_daa :       std_logic;
signal acc_low_gt9 :  std_logic;
signal acc_high_gt9 : std_logic;
signal acc_high_ge9 : std_logic;
signal daa_adjust :   std_logic_vector(8 downto 0);     
    
-- ALU CY flag intermediate signals
signal cy_in_sgn :    std_logic;
signal cy_in :        std_logic;
signal cy_in_gated :  std_logic;
signal cy_adder :     std_logic;
signal cy_arith :     std_logic;
signal cy_shifter :   std_logic;

-- ALU intermediate results
signal logic_res :    std_logic_vector(7 downto 0);  
signal shift_res :    std_logic_vector(7 downto 0);    
signal alu_mux1 :     std_logic_vector(7 downto 0);
    
    
begin

DI <= data_in;

process(clk)    -- IR register, load when uc_decode flag activates
begin
  if clk'event and clk='1' then
    if uc_decode = '1' then
      IR <= DI;
    end if;
  end if;
end process;

s_field <= IR(2 downto 0); -- IR field extraction : sss reg code
d_field <= IR(5 downto 3); -- ddd reg code
p_field <= IR(5 downto 4); -- pp 16-bit reg pair code   


--##############################################################################
-- Microcode sequencer

process(clk)    -- do_reset is reset delayed 1 cycle
begin
  if clk'event and clk='1' then
    do_reset <= reset;
  end if;
end process;

uc_flags1 <= ucode(31 downto 29);
uc_flags2 <= ucode(28 downto 26);

-- microcode address control flags are gated by do_reset (reset has priority)
uc_do_ret <= '1' when uc_flags2 = "011" and do_reset = '0' else '0';
uc_jsr    <= '1' when uc_flags2 = "010" and do_reset = '0' else '0';  
uc_tjsr   <= '1' when uc_flags2 = "100" and do_reset = '0' else '0';    
uc_decode <= '1' when uc_flags1 = "001" and do_reset = '0' else '0';  
uc_end    <= '1' when (uc_flags2 = "001" or (uc_tjsr='1' and condition_reg='0'))
                  and do_reset = '0' else '0';  

-- other microinstruction flags are decoded
uc_halt_flag  <= '1' when uc_flags1 = "111" else '0';
uc_halt   <= '1' when uc_halt_flag='1' and inta_reg='0' else '0';  
uc_ei     <= '1' when uc_flags1 = "011" else '0';  
uc_di     <= '1' when uc_flags1 = "010" or inta_reg='1' else '0'; 
-- clr_t1/2 clears T1/T2 when explicitly commanded; T2 and T1 clear implicitly 
-- at the end of each instruction (by uc_decode)
clr_t2    <= '1' when uc_flags2 = "001" else '0';
clr_t1    <= '1' when uc_flags1 = "110" else '0';
use_aux   <= '1' when uc_flags1 = "101" else '0';  
set_aux   <= '1' when uc_flags2 = "111" else '0';

load_al <= ucode(24);
load_addr <= ucode(25);

do_cy_op_d <= '1' when ucode(5 downto 2)="1011" else '0'; -- decode CY ALU op
do_cpc_d <= ucode(0); -- decode CPC ALU op; valid only when do_cy_op_d='1'

-- uinst jump command, either unconditional or on a given condition
uc_do_jmp <= uc_jsr or (uc_tjsr and condition_reg);

vma <= load_addr;  -- addr is valid, either for memmory or io

-- assume the only uinst that does memory access in the range 0..f is 'fetch'
fetch <= '1' when uc_addr(7 downto 4)=X"0" and load_addr='1' else '0';

-- external bus interface control signals
io <= '1' when uc_flags1="100" else '0'; -- IO access (vs. memory)
rd <= '1' when uc_flags2="101" else '0'; -- RD access
wr <= '1' when uc_flags2="110" else '0'; -- WR access  

uc_jmp_addr <= ucode(11 downto 10) & ucode(5 downto 0);

uc_addr_sel <= uc_do_ret & uc_do_jmp & uc_decode & uc_end;

addr_plus_1 <= std_logic_vector(uc_addr + 1);

-- TODO simplify this!!

-- NOTE: when end='1' we jump either to the FETCH ucode ot to the HALT ucode
-- depending on the value of the halt signal.
-- We use the unregistered uc_halt instead of halt_reg because otherwise #end
-- should be on the cycle following #halt, wasting a cycle.
-- This means that the flag #halt has to be used with #end or will be ignored. 

with uc_addr_sel select next_uc_addr <= 
    unsigned('0'&uc_ret_addr)           when "1000", -- ret
    unsigned('0'&uc_jmp_addr)           when "0100", -- jsr/tjsr
    unsigned('0'&addr_plus_1)           when "0000", -- uaddr++
    unsigned'("000000"&uc_halt&"11")    when "0001", -- end: go to fetch/halt
    unsigned('1'&DI)                    when others; -- decode fetched address 

-- Note how we used DI (containing instruction opcode) as a microcode address

-- read microcode rom 
process (clk)
begin
  if clk'event and clk='1' then
    ucode <= rom(to_integer(next_uc_addr));
  end if;
end process;

-- microcode address register
process (clk)
begin
  if clk'event and clk='1' then
    if reset = '1' then
      uc_addr <= X"00";
    else
      uc_addr <= next_uc_addr(7 downto 0);  
    end if;
  end if;
end process;

-- ucode address 1-level 'return stack'
process (clk)
begin
  if clk'event and clk='1' then
    if reset = '1' then
      uc_ret_addr <= X"00";
    elsif uc_do_jmp='1' then
      uc_ret_addr <= addr_plus_1;
    end if;  
  end if;
end process;    


alu_op <= ucode(3 downto 0); 

-- pipeline uinst field2 for 1-cycle delayed execution.
-- note the same rbank addr field is used in cycles 1 and 2; this enforces
-- some constraints on uinst programming but simplifies the system.
process(clk)
begin
  if clk'event and clk='1' then
    ucode_field2 <= do_cy_op_d & do_cpc_d & clr_t2 & clr_t1 & 
                    --set_aux & use_aux & rb_wr_index & 
                    set_aux & use_aux & rbank_rd_addr & 
                    ucode(14 downto 4) & alu_op;
  end if;
end process;

--#### HALT logic
process(clk)
begin
  if clk'event and clk='1' then
    if reset = '1' or int_pending = '1' then --inta_reg
      halt_reg <= '0';
    else 
      if uc_halt = '1' then
        halt_reg <= '1';
      end if;
    end if;
  end if;
end process;

halt <= halt_reg;

--#### INTE logic -- inte_reg = '1' means interrupts ENABLED
process(clk)
begin
  if clk'event and clk='1' then
    if reset = '1' then
      inte_reg <= '0';
      delayed_ei <= '0';
    else 
      if (uc_di='1' or uc_ei='1') and uc_end='1' then
        --inte_reg <= uc_ei;
        delayed_ei <= uc_ei; -- FIXME DI must not be delayed
      end if;
      if uc_end = '1' then -- at the last cycle of every instruction...
        if uc_di='1' then  -- ...disable interrupts if the instruction is DI...
          inte_reg <= '0';
        else
          -- ...of enable interrupts after the instruction following EI
          inte_reg <= delayed_ei;
        end if;
      end if;
    end if;
  end if;
end process;

inte <= inte_reg;

-- interrupts are ignored when inte='0' but they are registered and will be
-- honored when interrupts are enabled
process(clk)
begin
  if clk'event and clk='1' then
    if reset = '1' then
      int_pending <= '0';
    else 
      -- intr will raise int_pending only if inta has not been asserted. 
      -- Otherwise, if intr overlapped inta, we'd enter a microcode endless 
      -- loop, executing the interrupt vector again and again.
      if intr='1' and inte_reg='1' and int_pending='0' and inta_reg='0' then
        int_pending <= '1';
      else 
        -- int_pending is cleared when we're about to service the interrupt, 
        -- that is when interrupts are enabled and the current instruction ends.
        if inte_reg = '1' and uc_end='1' then
          int_pending <= '0';
        end if;
      end if;
    end if;
  end if;
end process;


--#### INTA logic
-- INTA goes high from END to END, that is for the entire time the instruction
-- takes to fetch and execute; in the original 8080 it was asserted only for 
-- the M1 cycle.
-- All instructions can be used in an inta cycle, including XTHL which was
-- forbidden in the original 8080. 
-- It's up to you figuring out which cycle is which in multibyte instructions.
process(clk)
begin
  if clk'event and clk='1' then
    if reset = '1' then
      inta_reg <= '0';
    else 
      if int_pending = '1' and uc_end='1' then
        -- enter INTA state
        inta_reg <= '1';
      else  
        -- exit INTA state
        -- NOTE: don't reset inta when exiting halt state (uc_halt_flag='1').
        -- If we omit this condition, when intr happens on halt state, inta
        -- will only last for 1 cycle, because in halt state uc_end is 
        -- always asserted.
        if uc_end = '1' and uc_halt_flag='0' then
          inta_reg <= '0';
        end if;
      end if;
    end if;
  end if;
end process;    
  
inta <= inta_reg;


--##############################################################################
-- Datapath

-- extract pipelined microcode fields
ra_field <= ucode(18 downto 15);
--rb_wr_index <= ucode(13 downto 10);
load_t1 <= ucode(23);  
load_t2 <= ucode(22);  
mux_in <= ucode(21);
rb_addr_sel <= ucode(20 downto 19);  
load_do <= ucode_field2(7);
set_aux_cy <= ucode_field2(20); 
do_clr_t1 <= ucode_field2(21); 
do_clr_t2 <= ucode_field2(22); 


-- T1 register 
process (clk)
begin
  if clk'event and clk='1' then
    if reset = '1' or uc_decode = '1' or do_clr_t1='1' then 
      T1 <= X"00";
    else
      if load_t1 = '1' then
        T1 <= alu_input;
      end if;
    end if;    
  end if;
end process;

-- T2 register
process (clk)
begin
  if clk'event and clk='1' then
    if reset = '1' or uc_decode = '1' or do_clr_t2='1' then 
      T2 <= X"00";
    else
      if load_t2 = '1' then
        T2 <= alu_input;
      end if;
    end if;    
  end if;
end process;

-- T1/T2 input data mux
alu_input <= rbank_data when mux_in = '1' else DI;

-- register bank address mux logic

rbh <= '1' when p_field = "11" else '0';

with rb_addr_sel select 
  rbank_rd_addr <=  ra_field    when "00",
                    "0"&s_field when "01",
                    "0"&d_field when "10",
                    rbh&p_field&ra_field(0) when others;   

-- RBank writes are inhibited in INTA state, but only for PC increments.
inhibit_pc_increment <= '1' when inta_reg='1' and use_aux_cy='1' 
                                 and rbank_wr_addr(3 downto 1) = "100" 
                                 else '0';
we_rb <= ucode_field2(6) and not inhibit_pc_increment;

-- Register bank logic
-- NOTE: read is asynchronous, while write is synchronous; but note also
-- that write phase for a given uinst happens the cycle after the read phase.
-- This way we give the ALU time to do its job.
rbank_wr_addr <= ucode_field2(18 downto 15);
process(clk)
begin
  if clk'event and clk='1' then
    if we_rb = '1' then
      rbank( to_integer(unsigned(rbank_wr_addr))) <= alu_output;
    end if;
  end if;
end process;
rbank_data <= rbank( to_integer(unsigned(rbank_rd_addr)));

-- should we read F register or ALU output?
use_psw <= '1' when ucode_field2(5 downto 4)="11" else '0';
data_output <= flag_reg when use_psw = '1' else alu_output;

     
process (clk)
begin
  if clk'event and clk='1' then
    if load_do = '1' then
        DO <= data_output;
    end if;
  end if;
end process;

--##############################################################################
-- ALU 

alu_fn <= ucode_field2(1 downto 0);
use_logic <= ucode_field2(2);
mux_fn <= ucode_field2(4 downto 3);
--#### make sure this is "00" in the microcode when no F updates should happen!
flag_pattern <=  ucode_field2(9 downto 8);
use_aux_cy <= ucode_field2(19);
do_cpc <= ucode_field2(23);
do_cy_op <= ucode_field2(24);
do_daa <= '1' when ucode_field2(5 downto 2) = "1010" else '0';

-- ucode_field2(14) will be set for those instructions that modify CY and AC
-- without following the standard rules -- AND, OR and XOR instructions.

-- Some instructions will unconditionally clear CY (AND, OR, XOR)
clear_cy <= ucode_field2(14);

-- Some instructions will unconditionally clear AC (OR, XOR)...
clear_ac <= '1' when ucode_field2(14) = '1' and 
                   ucode_field2(5 downto 0) /= "000100" 
          else '0';
-- ...and some others unconditionally SET AC (AND)
set_ac <= '1' when ucode_field2(14) = '1' and 
                   ucode_field2(5 downto 0) = "000100" 
          else '0';   
  
aux_cy_in <= reg_aux_cy when set_aux_cy = '0' else '1';

-- carry input selection: normal or aux (for 16 bit increments)?
cy_in <= flag_reg(0) when use_aux_cy = '0' else aux_cy_in;

-- carry is not used (0) in add/sub operations
cy_in_gated <= cy_in and alu_fn(0);

--##### Adder/substractor

-- zero extend adder operands to 9 bits to ease CY output synthesis
-- use zero extension because we're only interested in cy from 7 to 8
arith_op1 <= signed('0' & T2);
arith_op2 <= signed('0' & T1);

-- The adder/substractor is done in 2 stages to help XSL synth it properly
-- Other codings result in 1 adder + a substractor + 1 mux

-- do 2nd op 2's complement if substracting...
arith_op2_sgn <=  arith_op2 when alu_fn(1) = '0' else not arith_op2;
-- ...and complement cy input too
cy_in_sgn <= cy_in_gated when alu_fn(1) = '0' else not cy_in_gated;

-- once 2nd operand has been negated (or not) add operands normally
arith_res <= arith_op1 + arith_op2_sgn + signed(std_logic_vector'("00000000"&cy_in_sgn));

-- take only 8 bits; 9th bit of adder is cy output
arith_res8 <= arith_res(7 downto 0);
cy_adder <= arith_res(8);

--##### DAA dedicated logic
-- Intel documentation does not cover many details of this instruction.
-- It has been experimentally determined that the following is the algorithm 
-- employed in the actual original silicon:
--
-- 1.- If ACC(3..0) > 9 OR AC=1 then add 06h to ACC.
-- 2.- If (ACC(7..4) > 9 OR AC=1) OR (ACC(7..4)==9 AND (CY=1 OR ACC(3..0) > 9))
--     then add 60h to ACC.
-- Steps 1 and 2 are performed in parallel.
-- AC = 1 iif ACC(3..0) >= 10
-- CY = 1 if CY was already 1 OR 
--           (ACC(7..4)>=9 AND ACC(3..0)>=10) OR
--           ACC(7..4)>=10
--        else CY is zero.

-- Note a DAA takes 2 cycles to complete; the adjutment addition is registered 
-- so that it does not become the speed bottleneck. The DAA microcode will 
-- execute two ALU DAA operations in a row before taking the ALU result.

-- '1' when ACC(3..0) > 9
acc_low_gt9 <= '1' when 
  to_integer(unsigned(arith_op2(3 downto 0))) > 9
  --arith_op2(3 downto 2)="11" or arith_op2(3 downto 1)="101"
  else '0';

-- '1' when ACC(7..4) > 9  
acc_high_gt9 <= '1' when 
  to_integer(unsigned(arith_op2(7 downto 4))) > 9
  --arith_op2(7 downto 6)="11" or arith_op2(7 downto 5)="101"
  else '0';

-- '1' when ACC(7..4) >= 9
acc_high_ge9 <= '1' when 
   to_integer(unsigned(arith_op2(7 downto 4))) >= 9
  else '0';

-- Condition for adding 6 to the low nibble
daa_test1 <= '1' when 
  acc_low_gt9='1' or    -- A(3..0) > 9
  flag_reg(4)='1'       -- AC set
  else '0';

-- condition for adding 6 to the high nibble
daa_test2 <= '1' when
  (acc_high_gt9='1' or  -- A(7..4) > 9
  flag_reg(0)='1') or   -- CY set 
  (daa_test2a = '1')    -- condition below
  else '0';

-- A(7..4)==9 && (CY or ACC(3..0)>9)
daa_test2a <= '1' when
  arith_op2(7 downto 4)="1001" and (flag_reg(0)='1' or acc_low_gt9='1')
  else '0';
 
-- daa_adjust is what we will add to ACC in order to adjust it to BCD 
daa_adjust(3 downto 0) <= "0110" when daa_test1='1' else "0000";  
daa_adjust(7 downto 4) <= "0110" when daa_test2='1' else "0000"; 
daa_adjust(8) <= '0';

-- The adder is registered so as to improve the clock rate. This takes the DAA
-- logic out of the critical speed path at the cost of an extra cycle for DAA,
-- which is a good compromise.
daa_adjutment_adder:
process(clk)
begin
  if clk'event and clk='1' then
    daa_res9 <= arith_op2 + signed(daa_adjust);
  end if;
end process daa_adjutment_adder;

-- AC flag raised if the low nibble was > 9, cleared otherwise.
flag_ac_daa <= acc_low_gt9;

-- CY flag raised if the condition above holds, otherwise keeps current value.
cy_daa <= '1' when
  flag_reg(0)='1' or  -- If CY is already 1, keep value 
  ( (acc_high_ge9='1' and acc_low_gt9='1') or (acc_low_gt9='1')  )
  else '0';

-- DAA vs. adder mux
with do_daa select arith_daa_res <= 
    std_logic_vector(daa_res9(7 downto 0))  when '1',
    std_logic_vector(arith_res8)            when others;  

-- DAA vs. adder CY mux
cy_arith <= cy_daa when do_daa='1' else cy_adder;

--##### Logic operations block
logic_res <=  T1 and T2 when alu_fn = "00" else
              T1 xor T2 when alu_fn = "01" else
              T1 or  T2 when alu_fn = "10" else
              not T1;

--##### Shifter
shifter:
for i in 1 to 6 generate
begin
  shift_res(i) <= T1(i-1) when alu_fn(0) = '0' else T1(i+1); 
end generate;
shift_res(0) <= T1(7) when alu_fn = "00" else -- rot left 
                cy_in when alu_fn = "10" else -- rot left through carry
                T1(1); -- rot right
shift_res(7) <= T1(0) when alu_fn = "01" else -- rot right
                cy_in when alu_fn = "11" else -- rot right through carry
                T1(6); -- rot left

cy_shifter   <= T1(7) when alu_fn(0) = '0' else -- left
                T1(0);                          -- right

alu_mux1 <= logic_res when use_logic = '1' else shift_res;


with mux_fn select
  alu_output <= alu_mux1      when "00",
                arith_daa_res when "01",
                not alu_mux1  when "10",
                "00"&d_field&"000" when others; -- RST  

--###### flag computation 

flag_s <= alu_output(7);
flag_p <= not(alu_output(7) xor alu_output(6) xor alu_output(5) xor alu_output(4) xor
         alu_output(3) xor alu_output(2) xor alu_output(1) xor alu_output(0));
flag_z <= '1' when alu_output=X"00" else '0';

-- AC is either the CY from bit 4 OR 0 if the instruction clears it implicitly
flag_ac <= flag_ac_and when set_ac = '1' and do_daa='0' else
           '0' when clear_ac = '1' else
           flag_ac_daa when do_daa = '1' else
            (arith_op1(4) xor arith_op2_sgn(4) xor alu_output(4));
            
-- AN* instructions deal with AC flag a bit differently
flag_ac_and <= T1(3) or T2(3);            
            
-- CY comes from the adder or the shifter, or is 0 if the instruction 
-- implicitly clears it.
flag_cy_1 <=  '0'       when clear_cy = '1' else
              cy_arith  when use_logic = '1' and clear_cy = '0' else
              cy_shifter;
-- CY can also be explicitly set or complemented by STC and CMC
flag_cy_2 <= not flag_reg(0) when do_cpc='0' else '1'; -- cmc, stc
-- No do the actual CY update
flag_cy <= flag_cy_1 when do_cy_op='0' else flag_cy_2;
  
flag_aux_cy <= cy_adder;

-- auxiliary carry reg
process(clk)
begin
  if clk'event and clk='1' then
    if reset='1' or uc_decode = '1' then
      reg_aux_cy <= '1'; -- inits to 0 every instruction
    else
      reg_aux_cy <= flag_aux_cy;
    end if;
  end if;
end process;              

-- load PSW from ALU (i.e. POP AF) or from flag signals
load_psw <= '1' when we_rb='1' and rbank_wr_addr="0110" else '0';

-- The F register has been split in two separate groupt that always update
-- together (C and all others).

-- F register, flags S,Z,AC,P
process(clk)
begin
  if clk'event and clk='1' then
    if reset='1' then
      flag_reg(7) <= '0';
      flag_reg(6) <= '0';
      flag_reg(4) <= '0';
      flag_reg(2) <= '0';
    elsif flag_pattern(1) = '1' then
      if load_psw = '1' then
        flag_reg(7) <= alu_output(7);
        flag_reg(6) <= alu_output(6);
        flag_reg(4) <= alu_output(4);
        flag_reg(2) <= alu_output(2);      
      else
        flag_reg(7) <= flag_s;
        flag_reg(6) <= flag_z;
        flag_reg(4) <= flag_ac;
        flag_reg(2) <= flag_p;      
      end if;
    end if;
  end if;
end procesS;

-- F register, flag C
process(clk)
begin
  if clk'event and clk='1' then
    if reset = '1' then
      flag_reg(0) <= '0';
    elsif flag_pattern(0) = '1' then
      if load_psw = '1' then
        flag_reg(0) <= alu_output(0);  
      else
        flag_reg(0) <= flag_cy;
      end if;
    end if;
  end if;
end procesS;

flag_reg(5) <= '0'; -- constant flag
flag_reg(3) <= '0'; -- constant flag
flag_reg(1) <= '1'; -- constant flag

--##### Condition computation

condition_sel <= d_field(2 downto 0);
with condition_sel select 
  condition <=  
            not flag_reg(6) when "000", -- NZ
                flag_reg(6) when "001", -- Z
            not flag_reg(0) when "010", -- NC
                flag_reg(0) when "011", -- C
            not flag_reg(2) when "100", -- PO
                flag_reg(2) when "101", -- PE  
            not flag_reg(7) when "110", -- P  
                flag_reg(7) when others;-- M                  

                
-- condition is registered to shorten the delay path; the extra 1-cycle
-- delay is not relevant because conditions are tested in the next instruction
-- at the earliest, and there's at least the fetch uinsts intervening.                
process(clk)
begin
  if clk'event and clk='1' then
    if reset = '1' then 
      condition_reg <= '0';
    else
      condition_reg <= condition;
    end if;
  end if;
end process;                            

-- low byte address register
process(clk)
begin
  if clk'event and clk='1' then
    if reset = '1' then
      addr_low <= X"00";
    elsif load_al = '1' then
      addr_low <= rbank_data;
    end if;
  end if;
end process;

-- note external address registers (high byte) are loaded directly from rbank
addr_out <= rbank_data & addr_low;

data_out <= DO;

end microcoded;

--------------------------------------------------------------------------------
-- Timing diagram 1: RD and WR cycles
--------------------------------------------------------------------------------
--            1     2     3     4     5     6     7     8     
--             __    __    __    __    __    __    __    __   
-- clk      __/  \__/  \__/  \__/  \__/  \__/  \__/  \__/  \__
--
--          ==|=====|=====|=====|=====|=====|=====|=====|=====|
--
-- addr_o   xxxxxxxxxxxxxx< ADR >xxxxxxxxxxx< ADR >xxxxxxxxxxx
--
-- data_i   xxxxxxxxxxxxxxxxxxxx< Din >xxxxxxxxxxxxxxxxxxxxxxx
--
-- data_o   xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx< Dout>xxxxxxxxxxx
--                         _____             _____
-- vma_o    ______________/     \___________/     \___________
--                         _____
-- rd_o     ______________/     \_____________________________
--                                           _____
-- wr_o     ________________________________/     \___________
--
-- (functional diagram, actual time delays not shown)
--------------------------------------------------------------------------------
-- This diagram shows a read cycle and a write cycle back to back.
-- In clock edges (4) and (7), the address is loaded into the external 
-- synchronous RAM address register. 
-- In clock edge (5), read data is loaded into the CPU.
-- In clock edge (7), write data is loaded into the external synchronous RAM.
-- In actual operation, the CPU does about 1 rd/wr cycle for each 5 clock 
-- cycles, which is a waste of RAM bandwidth.
--
