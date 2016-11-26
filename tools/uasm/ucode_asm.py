#!/usr/bin/env python
################################################################################
# ucode_asm.py : light8080 core microcode assembler
################################################################################
# Usage: ucode_asm.py [options] <microcode file name> <output file name>
# 
# Options:
#
# -l FILE     : Generate listing file. By default none is generated.
# -h, --help  : Show help, quit.
#
################################################################################
# Assembler format (informal definition, source is the ultimate reference!):
#
#<microinstruction line> := 
#    [<label>] | (*1)
#    <operand stage control> ; <ALU stage control> [; [<flag list>]] |
#    JSR <destination address>|TJSR <destination address>
#
#<label> := {':' immediately followed by a common identifier}
#<destination address> := {an identifier defined as label anywhere in the file}
#<operand stage control> :=  <op_reg> = <op_src> | NOP
#<op_reg> := T1 | T2
#<op_src> := <register> | DI | <IR register>
#<IR register> := {s}|{d}|{p}0|{p}1 (*3)
#<register> := _a|_b|_c|_d|_e|_h|_l|_f|_a|_ph|_pl|_x|_y|_z|_w|_sh|_sl|
#<ALU stage control> := <alu_dst> = <alu_op> | <alu_0op> | NOP 
#<alu_dst> := <IR register> | <register> | DO
#<alu_op> := add|adc|sub|sbb|and|orl|not|xrl|rla|rra|rlca|rrca|aaa|
#            t1|rst|daa|psw
#<alu_0op> := cpc|sec
#<flag list> := <flag> [, <flag> ...] 
#<flag> := #decode|#di|#ei|#io|#auxcy|#clrt1|#halt|#end|#ret|#rd|#wr|#setacy 
#          #ld_al|#ld_addr|#fp_c|#fp_r|#fp_rc|#clr_cy_ac  (*2)
#
#  *1 Labels appear alone by themselves in a line
#  *2 There are some restrictions on the flags that can be used together
#  *3 Registers are specified by IR field
#
################################################################################
# ALU operations 
#
#Operation      Encoding    ALU result
#===============================================================================
#ADD            001100      T2 + T1
#ADC            001101      T2 + T1 + CY
#SUB            001110      T2 - T1
#SBB            001111      T2 - T1 - CY
#AND            000100      T1 AND T2
#ORL            000101      T1 OR T2
#NOT            000110      NOT T1 
#XRL            000111      T1 XOR T2
#RLA            000000      8080 RLC
#RRA            000001      8080 RRC
#RLCA           000010      8080 RAL
#RRCA           000011      8080 RAR
#T1             010111      T1
#RST            011111      8*IR(5..3), as per RST instruction
#DAA            101000      DAA T1 (but only after executing 2 in a row)
#CPC            101100      UNDEFINED     (CY complemented)
#SEC            101101      UNDEFINED     (CY set)
################################################################################
# Flags :
# --- Flags from group 1: use only one of these
# #decode :  Load address counter and IR with contents of data input lines,
#            thus starting opcode decoging.
# #ei :      Set interrupt enable register.
# #di :      Reset interrupt enable register.
# #io :      Activate io signal for 1st cycle.
# #auxcy :   Use aux carry instead of regular carry for this operation. 
# #clrt1 :   Clear T1 at the end of 1st cycle.
# #halt :    Jump to microcode address 0x07 without saving return value.
# 
# --- Flags from group 2: use only one of these
# #setacy :  Set aux carry at the start of 1st cycle (used for ++).
# #end :     Jump to microinstruction address 3 after the present m.i.
# #ret :     Jump to address saved by the last JST or TJSR m.i.
# #rd :      Activate rd signal for the 2nd cycle.
# #wr :      Activate wr signal for the 2nd cycle.
# --- Independent flags: no restrictions
# #ld_al :   Load AL register with register bank output as read by operation 1.
#            (used in memory and io access). 
# #ld_addr : Load address register (H byte = register bank output as read by 
#            operation 1, L byte = AL). 
#            Activate vma signal for 1st cycle.
# #clr_acy : Instruction clears CY and AC flags. Use with #fp_rc.
# --- PSW update flags: use only one of these
# #fp_r :    This instruction updates all PSW flags except for C.
# #fp_c :    This instruction updates only the C flag in the PSW.
# #fp_rc :   This instruction updates all the flags in the PSW.
################################################################################
# Read the design notes for a brief reference to the micromachine internal
# behavior, including implicit loads/erases.
################################################################################


import sys
import os
import optparse
import re

UI_WIDTH =        32              # uInstruction width in bits
UF_FLAGS1 =       (31, 3)         # uI field - flags1
UF_FLAGS2 =       (28, 3)         # uI field - flags2
UF_LD_AL =        (24, 1)         # uI field - ld_al
UF_LD_ADDR =      (25, 1)         # uI field - ld_addr
UF_FP    =        ( 9, 2)         # uI field - flag update pattern
UF_CLR_ACY =      (14, 1)         # uI field - clr_acy
UF_LD_T1 =        (23, 1)         # uI field - ld_t1
UF_LD_T2 =        (22, 1)         # uI field - ld_t2
UF_RB_ADDR_SEL =  (20, 2)         # uI field - 
UF_RB_ADDR =      (18, 4)         # uI field - RB RD index from uI
UF_RB_WE =        ( 6, 1)         # uI field - RB WE
UF_RB_WR_ADDR =   (13, 4)         # uI fiels - RB WR index
UF_RB_ADDR_MSB =  (15, 1)         # uI field - LSB of RB ix when accessing pair
UF_MUX_IN =       (21, 1)         # uI field - mux_in
UF_DO_WE =        ( 7, 1)         # uI field - load_do
UF_ALU_OP =       ( 5, 6)         # uI field - alu_op
UF_JUMP_DST_L =   ( 5, 6)         # uI field - jump target, 6 LSB
UF_JUMP_DST_H =   (11, 2)         # uI field - jump target, 2 MSB

PRAGMAS = ['__code', '__asm', '__reset', '__fetch', '__halt']
FLAGS = {
  "#ld_al" :    (UF_LD_AL, "1"),
  "#ld_addr" :  (UF_LD_ADDR, "1"),
  "#fp_r" :     (UF_FP, "10"),
  "#fp_c" :     (UF_FP, "01"),
  "#fp_rc" :    (UF_FP, "11"),
  "#clr_acy" :  (UF_CLR_ACY, "1"),

  "#decode" :   (UF_FLAGS1, "001"),
  "#ei" :       (UF_FLAGS1, "011"),
  "#di" :       (UF_FLAGS1, "010"),
  "#io" :       (UF_FLAGS1, "100"),
  "#auxcy" :    (UF_FLAGS1, "101"),
  "#clrt1" :    (UF_FLAGS1, "110"),
  "#halt" :     (UF_FLAGS1, "111"),
  
  "#end" :      (UF_FLAGS2, "001"),
  # UF_FLAGS2 = "010" -> JSR
  "#ret" :      (UF_FLAGS2, "011"),
  # UF_FLAGS2 = "100" -> TJSR
  "#rd" :       (UF_FLAGS2, "101"),
  "#wr" :       (UF_FLAGS2, "110"),
  "#setacy" :   (UF_FLAGS2, "111"),
}


OPCTRL_DST = ['t1', 't2']
OPCTRL_RB = {
      '_b':"0000",    '_c':"0001",    '_d':"0010",    '_e':"0011", 
      '_h':"0100",    '_l':"0101",    '_a':"0111",    '_f':"0110", 
      '_ph':"1000",   '_pl':"1001",   '_x':"1010",    '_y':"1011", 
      '_z':"1100",    '_w':"1101",    '_sh':"1110",   '_sl':"1111"
      }
OPCTRL_IR = {
      '{s}':  ("01", "0"), 
      '{d}':  ("10", "0"),
      '{p}0': ("11", "0"),
      '{p}1': ("11", "1")
      }

ALUCTRL_ALU_0ARG = {
      'cpc':    '101100',
      'sec':    '101101'
      }

ALUCTRL_ALU_1ARG = {
      'add':    '001100',
      'adc':    '001101',
      'sub':    '001110',
      'sbb':    '001111',  
      
      'and':    '000100',
      'orl':    '000110',
      'not':    '000111',
      'xrl':    '000101',
      
      'rla':    '000000',
      'rra':    '000001',
      'rlca':   '000010',
      'rrca':   '000011',
      
      'aaa':    '111000',
      
      't1':     '010111',
      'rst':    '011111',
      'daa':    '101000',
      'psw':    '110000' 
      }

class SyntaxError(Exception):
  pass

class uCodeROM(object):
  """Microcode ROM.
  Includes uCode assembler and VHDL/Verilog formatter.
  """

  def __init__(self, srcfile):
    self.srcfile = srcfile
    self.source = []                  # List of source lines indexed by lineno
    self.lineno = 0                   # Source line being assembled in pass 1
    self.upc_counter = 0              # uA of nest uI
    self.label_address_dict = {}      # label -> uA
    self.label_lineno_dict = {}       # label -> src line number
    self.code_address_dict = {}       # bin opcode pattern -> uA
    self.code_lineno_dict = {}        # bin opcode pattern -> src line number
    self.opcode_address_dict = {}     # plain bin opcode -> uA (decoding)
    self.lineno_address_dict = {}     # src line number -> uA if any
    self.lineno_label_dict = {}       # src line number -> label if any
    self.instr_address_dict = {}      # CPU instruction -> uA
    self.instr_lineno_dict = {}       # CPU instruction -> src line number
    self.address_instr_dict = {}      # uA -> CPU instruction
    self.jump_src_dst_dict = {}       # Jump instruction uA -> target label
    self.jump_src_lineno_dict = {}    # Jump instruction uA -> src line number
    self.uInstruction_list = []       # uInstruction table, index is uA
    self.uI = ['0']*UI_WIDTH          # uI being assembled in pass 1
    # (uI is stored as list of chars, MSB-first.)

    # Assemble the uCode right now.
    self._assemble()


  def build_vhdl_package(self, vhdl_filename):
    """Return string with microcode table formatted as VHDL package."""

    vhdl =  "-- light8080_ucode_pkg.vhdl -- Microcode table for light8080 CPU core.\n"
    vhdl += "library ieee;\n"
    vhdl += "use ieee.std_logic_1164.all;\n"
    vhdl += "use ieee.numeric_std.all;\n\n"
    vhdl += "package light8080_ucode_pkg is\n\n"
    vhdl += "  type t_rom is array (0 to 511) of std_logic_vector(31 downto 0);\n"
    vhdl += "  constant microcode : t_rom := (\n"

    # TODO check size of uI table

    for i in range(len(self.uInstruction_list)):
      vhdl += "  \"%s\"" % "".join(self.uInstruction_list[i])
      if i < len(self.uInstruction_list)-1:
        vhdl += ","
      else:
        vhdl += " "
      vhdl += " -- %03x" % i
      vhdl += "\n"
    vhdl += "\n);\n"
    vhdl += "end package;\n"

    try:
      f = open(vhdl_filename, 'w')
      print >> f, vhdl
      f.close()
    except IOError as e:
      raise e

  def build_listing(self, lst_filename=None):
    """Print listing to file unless file is None.
    Listing will include uI coming from the source as well as padding uI and 
    uI used in the jump (decoding) table.
    """

    if not lst_filename: return

    listing = ""

    # First, build traditional listing with 1 listing line per source line.
    for i in range(1,self.lineno+1):
      asm = self.source[i-1].rstrip()
      if i in self.lineno_address_dict and not i in self.lineno_label_dict and not asm.startswith("__"):
        # This line generated a uInstruction.
        uA = self.lineno_address_dict[i]
        addr = "%03x:" % uA
        obj = "".join(self.uInstruction_list[uA])
      else:
        # This line is a comment or is blank.
        addr = " "*4
        obj = ""
      listing_line = "%4s  %32s  %s\n" % (addr, obj, asm)
      listing += listing_line

    # Ok, now add the padding uInstructions.
    listing += "\n\n%4s  %32s  %s\n" % ("", "", "// PADDING INSTRUCTIONS INSERTED AUTOMATICALLY.")
    for i in range(uA+1,256):
      obj = "".join(self.uInstruction_list[i])
      listing_line = "%03x:  %32s  %s\n" % (i, obj, "")
      listing += listing_line

    # Finally, add the jump table JSR uInstructions.
    listing += "\n\n%4s  %32s  %s\n" % ("", "", "// DECODING TABLE INSERTED AUTOMATICALLY.")
    for i in range(256,512):
      obj = "".join(self.uInstruction_list[i])
      if (i-0x100) in self.opcode_address_dict: 
        ua = self.opcode_address_dict[i-0x100]
        asm = "// %s" % self.address_instr_dict[ua]
      else:
        asm = "//"
      listing_line = "%03x:  %32s  %s\n" % (i, obj, asm)
      listing += listing_line

    listing += "\n\n%4s  %32s  %s\n" % ("", "", "// END OF LISTING.")

    try:
      f = open(lst_filename, 'w')
      print >> f, listing
      f.close()
    except IOError as e:
      raise e


  def _assemble(self):
    """Read uCode asm source, assemble it fully into a list of uCode binary 
    words.
    """

    # Read the whole file to a list of lines.
    try:
        fin = open(self.srcfile, "r")
        self.source = fin.readlines()
        fin.close()
    except IOError as e:
        print e 
        sys.exit(e.errno)

    try:
      # Assembly pass 1: translate ucode words, leave jumps unresolved.
      self._pass_1()    
      # Assembly pass 2: resolve jump references.
      self._pass_2()
      # Pad to 256 uInstructions with NOPs.
      self._fill_unused_slots()
      # Build decoding (jump) table.
      self._build_decoding_table()
      
    except SyntaxError as e:
      # Error messages have already been output to stderr, just quit.
      sys.exit(22)


  def _pass_1(self):
    """Assemble all individual uInstructions, leave jumps unresolved."""

    # Process all lines in file.
    self.lineno = 0
    for line in self.source:
      self.lineno += 1
      # Trim all whitespace...
      line_bare = line.strip()
      # ...and trim any comments.
      ucode = line_bare.split("//", 1)[0]
      # If line had only whitespace and/or comments, ignore it.
      if len(ucode) == 0: continue
      # Split the actual ucode in up to 3 fields...
      fields = [x.strip() for x in ucode.split(';')]
      # ...reject lines with 4 or more.
      if len(fields) > 3: self._syntax_error("line has more than 3 fields")

      self._assemble_uInstruction(fields)
      

  def _assemble_uInstruction(self, uI_fields):
    """Assemble individual uInstruction."""

    self.uI = ['0']*UI_WIDTH
    
    if uI_fields[0].startswith(":"):
      # Label. Store the address for reference in pass 2.
      self._do_label(uI_fields)

    elif uI_fields[0].startswith("__"):
      # Pragma.
      self._do_pragma(uI_fields)

    elif uI_fields[0].startswith("JSR") or uI_fields[0].startswith("TJSR"):
      # Jump uInstruction.
      self._pass1_jump(uI_fields)

    else:
      # Regular uInstruction that's not a jump.
      self._pass1_instruction(uI_fields)

    self.lineno_address_dict[self.lineno] = self.upc_counter-1


  def _pass1_instruction(self, uI_fields):
    """Process in pass 1 a non-jump instruction."""

    self._pass1_operand_stage(uI_fields[0])
    if len(uI_fields) >= 2:
      self._pass1_alu_stage(uI_fields[1])
    if len(uI_fields) == 3:
      self._pass1_flags(uI_fields[2])
    self._emit()


  def _pass1_operand_stage(self, field):
    """Process in pass 1 the operand control field (#1) of an instruction.""" 
    sides =  [x.strip().lower() for x in field.split('=')]
    if len(sides) == 0:
      pass # Empty field, ignore as NOP.
    elif len(sides)==1 and sides[0]=='nop':
      pass # NOP, ignore.
    elif len(sides)==2:
      # Parse target register...
      if not sides[0] in OPCTRL_DST:
        self._syntax_error("wrong target register in operand control field")
      # ...and set corresponding load flag. # TODO support T1=T2=x? it's free.
      target = [UF_LD_T1, UF_LD_T2][OPCTRL_DST.index(sides[0])]
      self._set_bits(target, "1")
      # ...then parse source.
      if sides[1] in OPCTRL_RB:
        self._set_bits(UF_RB_ADDR_SEL, "00")  # RB RD addr comes from uI
        self._set_bits(UF_RB_ADDR, OPCTRL_RB[sides[1]])
        self._set_bits(UF_MUX_IN, "1")        # Tx load data comes from RB
      elif sides[1] in OPCTRL_IR:
        (mux, msb) = OPCTRL_IR[sides[1]]
        self._set_bits(UF_RB_ADDR_SEL, mux)   # RD RD addr comes from IR...
        self._set_bits(UF_RB_ADDR_MSB, msb)   # ...+1 if top half of 16b pair
        self._set_bits(UF_MUX_IN, "1")        # Tx load data comes from RB
      elif sides[1] == 'di':
        self._set_bits(UF_MUX_IN, "0")        # Tx load data comes from DI
      else:
        self._syntax_error("invalid source in operand control field")
    else:
      self._syntax_error("malformed operand control field")

  def _pass1_alu_stage(self, field):
    """Process in pass 1 the ALU control field (#2) of an instruction.""" 
    sides =  [x.strip().lower() for x in field.split('=')]
    if len(sides) == 0:
      pass # Empty field, ignore as NOP.
    elif len(sides)==1:
      if sides[0]=='nop':
        pass # NOP, ignore.
      elif sides[0] in ALUCTRL_ALU_0ARG:
        # ALU operation that takes no operands (Cy set/complement).
        self._set_bits(UF_ALU_OP, ALUCTRL_ALU_0ARG[sides[0]])
    elif len(sides)==2:
      # Parse target register.
      if sides[0] in OPCTRL_RB:
        # TODO use separate WR index field currently unused.
        #self._set_bits(UF_RB_WR_ADDR, OPCTRL_RB[sides[0]])
        self._set_bits(UF_RB_ADDR, OPCTRL_RB[sides[0]])
        self._set_bits(UF_RB_WE, "1")
      elif sides[0] in OPCTRL_IR:
        (mux, msb) = OPCTRL_IR[sides[0]]
        # TODO check concordance with op stage.
        self._set_bits(UF_RB_ADDR_SEL, mux)   # RD RD addr comes from IR...
        self._set_bits(UF_RB_ADDR_MSB, msb)   # ...+1 if top half of 16b pair
        self._set_bits(UF_RB_WE, "1")
      elif sides[0] == "do":
        self._set_bits(UF_DO_WE, "1")
      else:
        self._syntax_error("wrong target register in operand control field")
      # Ok, now parse ALU operation.
      if sides[1] in ALUCTRL_ALU_1ARG:
        self._set_bits(UF_ALU_OP, ALUCTRL_ALU_1ARG[sides[1]])

    else:
      self._syntax_error("malformed ALU control field")

  def _pass1_flags(self, field):
    """Process in pass 1 the flags field (#3) of an instruction.""" 
    # An empty flags field is just ignored.
    if len(field) == 0: return
    # Otherwise, process each flag in turn.
    flags = [x.strip().lower() for x in field.split(',')]
    for flag in flags:
      if len(flag) == 0:
        # Trailing commas or empty place in comma separated list.
        self._syntax_error("malformed flag list")
      if not flag in FLAGS:
        # Flag not in dictionary.
        self._syntax_error("unknown flag '%s'" % flag)
      else:
        # Okay, raise flag in uInstruction...
        (bitfield, bitval) = FLAGS[flag]
        # ...unless the field is already initialized which means flag clash.
        if self._field_nonzero(bitfield):
          print "".join(self.uI)
          self._syntax_error("flag conflict")
        self._set_bits(bitfield, bitval)

  def _pass1_jump(self, uI_fields):
    """Process in pass 1 a jump uInstruction."""

    # No more than one field in this uInstruction.
    if len(uI_fields) > 1: 
      self._syntax_error("unexpected fields in JSR/TJSR line")
    # ...and it must have two tokens only: {T}JSR <label>.
    # Note only labels are allowed, no expressions, no integer literals.
    tokens = uI_fields[0].split()
    if len(tokens) > 2:
      self._syntax_error("unexpected fields in JSR/TJSR line")
    if not tokens[0] in ['TJSR', 'JSR']:
      self._syntax_error("unknown microinstruction mnemonic '%s'" % tokens[0])
    # Okay, save the jump to be resolved in pass 2...
    label = tokens[1].strip()
    self.jump_src_dst_dict[self.upc_counter] = label
    self.jump_src_lineno_dict[self.upc_counter] = self.lineno
    # ...and emit the actual jump uInstruction with target uA field empty.
    if tokens[0] == 'JSR':
      self._set_bits(UF_FLAGS2, "010")
    else:
      self._set_bits(UF_FLAGS2, "100")
    self._emit()


  def _emit(self):
    """Put uI that's just been assembled in table, update state vars."""
    self.uInstruction_list.append(self.uI)
    self.upc_counter += 1

  def _set_bits(self, field, bits):
    """Set bit field in current uInstruction."""

    (msb, nbits) = field
    for i in range(nbits):
      self.uI[(UI_WIDTH-1)-msb+i] = bits[i]

  def _field_nonzero(self, field):
    """Check whether a uInstruction field is nonzero. Flag conflicts."""
    (msb, nbits) = field
    for i in range(nbits):
      if self.uI[(UI_WIDTH-1)-msb+i] != '0': return True
    return False


  def _do_label(self, uI_fields):
    """Process label."""
    # Make sure it's legit. No other fields on the same line...
    if len(uI_fields) > 1: 
      self._syntax_error("unexpected fields in label line")
    # ...and label must be valid identifier.
    label = uI_fields[0][1:]
    if not re.match("[_A-Za-z][_a-zA-Z0-9]*$", label):
      self._syntax_error("invalid label '%s'" % label)
    # Also labels can't be redefined.
    if label in self.label_address_dict:
      emsg = "label '%s' already defined in line %d" % (label, self.label_lineno_dict[label])
      self._syntax_error(emsg)
    # Label is okay so put it into dictionaries.
    self.label_address_dict[label] = self.upc_counter
    self.label_lineno_dict[label] = self.lineno
    self.lineno_label_dict[self.lineno] = label


  def _do_pragma(self, uI_fields):
    """Process pragma line."""

    # No other fields on the same line.
    if len(uI_fields) > 1: 
      self._syntax_error("unexpected fields in pragma line")
    # Pragma is first identifier, must be one of the known set.
    pragma_fields = uI_fields[0].lower().split(None,1)
    if not pragma_fields[0] in PRAGMAS:
      self._syntax_error("unknown pragma '%s'" % pragma_fields[0])
    # Seems legit. Now process it.
    pragma = pragma_fields[0]
    params = pragma_fields[1].strip() if len(pragma_fields)>1 else ''
    if pragma == '__code':
      # __code: store uA of CPU binary opcode, will be used to build jump table.
      if params in self.code_address_dict:
        emsg = "CPU opcode '%s' already defined at line %d" % (params, self.code_lineno_dict[params])
        self._syntax_error(emsg)
      params = params.replace("\"","")
      self.code_address_dict[params] = self.upc_counter
      self.code_lineno_dict[params] = self.lineno
    if pragma == '__asm':
      # __asm: Store uA of instruction uC, to be used in listings only.
      if params in self.instr_address_dict:
        emsg = "CPU instruction '%s' already defined at line %d" % (params, self.instr_lineno_dict[params])
        self._syntax_error(emsg)
      self.instr_address_dict[params] = self.upc_counter
      self.address_instr_dict[self.upc_counter] = params
      self.instr_lineno_dict[params] = self.lineno
    else:
      # All other pragmas are ignored.
      pass


  def _pass_2(self):
    """Resolve jump references."""
    undefined_label = False
    for jump_src_addr in self.jump_src_dst_dict.keys():
      label = self.jump_src_dst_dict[jump_src_addr]
      if label not in self.label_address_dict:
        lsrc = self.jump_src_lineno_dict[jump_src_addr]
        self._syntax_error("undefined label '%s'" % label, src=lsrc, quit=0)
        undefined_label = True
      else:
        jump_dst_addr = self.label_address_dict[label]
        #print "[%3xh] -> %3xh; %s" % (jump_src_addr, jump_dst_addr, label) 
        target_bin = self._int_to_bin(jump_dst_addr, 8)
        self.uI = self.uInstruction_list[jump_src_addr]
        self._set_bits(UF_JUMP_DST_L, target_bin[2:])
        self._set_bits(UF_JUMP_DST_H, target_bin[0:2])
        self.uInstruction_list[jump_src_addr] = self.uI

    if undefined_label:
      self._quit("quitting due to previous label error(s)")


  def _fill_unused_slots(self):
    """Fill any unused uI slots up to 0xff with 'NOP;NOP;#end's."""

    # We'll fill the slots with 'NOP;NOP;#end'
    self.uI = ["0"] * 32
    self._set_bits(UF_FLAGS2, "001")

    while self.upc_counter < 256:
      self._emit()

  def _build_decoding_table(self):
    """Build 256-entry decoding table. 
    One jump uI per opcode, starting at uA 0x100."""

    jump_table = [None] * 256
    for opcode in range(256):
      op_bin = self._int_to_bin(opcode, 8)
      match_len = 1000
      match_pattern = None
      for pattern in self.code_address_dict.keys():
        pat_len = self._match_pattern(pattern, op_bin)
        if (pat_len != None) and (pat_len < match_len):
          match_len = pat_len
          match_pattern = pattern
      if match_pattern != None:
        #print op_bin, match_pattern, match_len
        jump_table[opcode] = self.code_address_dict[match_pattern]
        self.opcode_address_dict[opcode] = self.code_address_dict[match_pattern]

    # Ok, we have the table of target addresses. Now emit one JSR uI per entry.
    for i in range(len(jump_table)):
      if jump_table[i] != None:
        self.uI = ["0"]*32
        self._set_bits(UF_FLAGS2, "010")
        target_bin = self._int_to_bin(jump_table[i], 8)
        self._set_bits(UF_JUMP_DST_L, target_bin[2:])
        self._set_bits(UF_JUMP_DST_H, target_bin[0:2])
        
      else:
        self.uI = "00001000000000000000000000000000"
      self._emit()

  def _match_pattern(self, pat1, pat2):
    """ """

    ctr = 0
    for i in range(8):
      if pat1[i]=='1' and pat2[i] == '1':
        pass
      elif pat1[i]=='0' and pat2[i] == '0':
        pass
      elif (pat1[i] not in ['0','1']):
        ctr += 1
      else:
        return None

    return ctr


  def _int_to_bin(self, value, width):
    """Convert in value into binary string, MSB left as usual."""

    if value < 0: self._syntax_error("BUG! invalid binary value conversion")

    original = value
    bin = ""
    mask = 1
    for i in range(width):
      if (mask & value) != 0:
        bin = "1"+bin
        value = value & ~(mask)
      else:
        bin = "0"+bin
      mask = mask << 1

    if value != 0:
      self._syntax_error("BUG! binary conversion out of range")

    return bin


  def _syntax_error(self, msg, src=None, quit=True):
    """Print error message to stdout and optionally quit."""
    if src == None: src = self.lineno
    print >> sys.stderr, self.source[src-1].rstrip()
    emsg = "%s:%d:error:%s." % (self.srcfile, src, msg)
    print >> sys.stderr, emsg

    if quit: raise SyntaxError(emsg)

  def _quit(self, msg):
    """Raise syntax error exception, print raw message to stderr."""
    print >> sys.stderr, msg
    raise SyntaxError(msg)


def _parse_command_line():
  """Get cmd line params."""
  parser = optparse.OptionParser(usage='%prog [options] <source file> <output file>')
  parser.add_option("-l", dest="listing", default=None,
                  help="write listing to FILE.", metavar="FILE")
  parser.add_option("-f",
                  dest="format", default="VHDL", choices=["VHDL","Verilog"],
                  help="microcode table format. VHDL or Verilog.")

  (options, args) = parser.parse_args()
  if len(args) < 2:
    print >> sys.stderr, "error: missing input and/or output file name(s)"
    parser.print_help()
    sys.exit(1)
  return (options, args)


def _main():
    
    (options, filenames) = _parse_command_line()

    srcfile = filenames[0]
    rom = uCodeROM(srcfile)
    rom.build_vhdl_package(filenames[1])
    rom.build_listing(options.listing)


if __name__ == "__main__":
    _main()
    sys.exit(0)
