#!/usr/bin/env python
"""
build_rom.py: Create VHDL package with ROM initialization constant from 
Intel-HEX object code file.
Please use with --help to get some brief usage instructions.
"""

import sys
import os
import argparse

TAG_BOTTOM_ADDR = "@bottom_addr@"
TAG_TOP_ADDR = "@top_addr@"
TAG_PKGNAME = "@obj_pkg_name@"
TAG_CODEBYTES = "@obj_bytes@"
TAG_PROJNAME = "@project_name@"


DEFAULT_VHDL_OUTPUT_NAME = "obj_code_pkg.vhdl"
DEFAULT_VERILOG_OUTPUT_NAME = "obj_code.inc.v"

FORMAT_VERILOG = 'verilog'
FORMAT_VHDL = 'vhdl'
FORMAT_CHOICES = [FORMAT_VHDL, FORMAT_VERILOG]

def _build_vhdl_package(data_array, bottom, top, opts):
    """ """

    # Open template file and read it into a list of lines.
    script_dir = os.path.dirname(__file__)
    template_filename = os.path.join(script_dir, "..","templates", "template.vhdl")
    try:
        fin = open(template_filename, "r")
        lines = fin.readlines()
        fin.close()
    except IOError as e:
        print e 
        sys.exit(e.errno)

    code_bytes = ""
    code_line = " "*4
    i = 0
    print "Range: %d to %d" %(bottom, top)
    for addr in range(bottom, top+1):
        b = data_array[addr]
        if addr < top:
            code_line += "X\"%02x\", " % b
        else:
            code_line += "X\"%02x\"  " % b
        if (i % 8) == 7:
            code_bytes += code_line + " -- %04xh : %04xh\n" % (addr-7, addr)
            code_line = " "*4
            i = 0
        else:
            i = i + 1
    if len(code_line.strip()) > 0:
      code_bytes += " "*4 + "%-56s -- %04xh : %04xh\n" % (code_line.strip(), addr-i+1, addr)

    vhdl = ""
    for line in lines:
        line = line.replace(TAG_BOTTOM_ADDR, "%d" % bottom)
        line = line.replace(TAG_TOP_ADDR, "%d" % top)
        line = line.replace(TAG_PKGNAME, "obj_code_pkg")
        line = line.replace(TAG_PROJNAME, opts.project)
        line = line.replace(TAG_CODEBYTES, code_bytes)
        vhdl += line

    return vhdl


def _build_verilog_include(data_array, bottom, top, opts):
    pass

def _parse_hex_line(line):
    """Parse code line in HEX object file."""
    line = line.strip()
    slen = int(line[1:3],16)
    sloc = int(line[3:7],16)
    stype = line[7:9]
    sdata = line[9:len(line)-2]
    schk = int(line[len(line)-2:],16)
        
    csum = slen + int(sloc / 256) + (sloc % 256) + int(stype,16)
    bytes = [0, ] * slen
    for i in range(slen):
        sbyte = int(sdata[i*2:i*2+2],16)
        bytes[i] = sbyte;
        csum = csum + sbyte
    
    csum = ~csum
    csum = csum + 1
    csum = csum % 256
    if csum != schk:
        return (None, None)
        
    return (sloc, bytes)

    
def _read_ihex_file(ihex_filename, quiet=False, fill=0):
    """
    Read Intel HEX file into a 64KB array.
    The file is assumed not to have any object code outside the range [0:64K-1].
    Return the 64K array plus the size and bounds of the read data.
    Array locations not initialized by hex file are filled with supplied value.
    """
    
    # CODE array, initialized to 64K of zeros...
    xcode = [fill, ] * 65536
    # ...and code boundaries, initialized out of range.
    bottom = 100000
    top = -1
    (xcode, top, bottom)

    # Read the whole file to a list of lines...
    try:
        fin = open(ihex_filename, "r")
        ihex_lines = fin.readlines()
        fin.close()
    except IOError as e:
        print e 
        sys.exit(e.errno)

    # ...and parse the lines one by one.
    total_bytes = 0
    for line in ihex_lines:
        (address, bytes) = _parse_hex_line(line)
        if address == None:
            print >> sys.stderr, "Checksum error in object file!"
            sys.exit(1)
        total_bytes = total_bytes + len(bytes)
        for i in range(len(bytes)):
            xcode[address + i] = bytes[i]
        
        if address < bottom:
            bottom = address
    
        if (address + len(bytes)) > top:
            top = (address + len(bytes))
    
    if not quiet:
        print >> sys.stdout, "Read %d bytes from file '%s'" % (total_bytes, ihex_filename)
        print >> sys.stdout, "Code range %04xh to %04xh" % (bottom, top)
    return (xcode, total_bytes, bottom, top)

def _parse_cmdline(argv):

    parser = argparse.ArgumentParser(
        description='Produce ROM initialization data in VHDL/Verilog format.')
    
    parser.add_argument(
            'object', 
            type=str,
            help='Object code file in Intel HEX format.')
    parser.add_argument(
            '--project', 
            type=str,
            default="(unknown)",
            help='Name of SW project. To be used in comments only.')
    parser.add_argument(
            '--format',  
            choices=FORMAT_CHOICES,
            default='vhdl',
            help="Output format (one of %s)." % ",".join(FORMAT_CHOICES))
    parser.add_argument(
            '--output', 
            type=str,
            default=None,
            help='Output file path. Defaults to same as object file with suitable extension vhdl/v.')
    parser.add_argument(
            '--memsize', 
            type=int,
            default=4*1024,
            help='Size of target memory block in bytes. Defaults to 4KB.')
    parser.add_argument(
            '--membase', 
            type=int,
            default=0,
            help='Base address of target memory block. Defaults to 0.')
    parser.add_argument(
            '--quiet', 
            action='store_true',
            default=False,
            help='Supress all chatter form console output.')
    parser.add_argument(
            'parameters', 
            type=str,
            metavar='+define+NAME=VALUE',
            nargs='*',
            default=0,
            help='Parameter definition.')


    opts = parser.parse_args()

    # Set output file name if none is given.
    if not opts.output:
        if opts.format == FORMAT_VHDL:
            opts.output = DEFAULT_VHDL_OUTPUT_NAME
        elif opts.format == FORMAT_VERILOG:
            opts.output = DEFAULT_VERILOG_OUTPUT_NAME
        else:
            # Should not happen but...
            print >> sys.stderr, "Invalid output format '%s'." % opts.format
            sys.exit(2)


    return opts

def _main(argv):

    opts = _parse_cmdline(argv)

    (objcode, total_bytes, bottom, top) = _read_ihex_file(opts.object, opts.quiet)

    if opts.format == 'vhdl':
        rtl = _build_vhdl_package(objcode, bottom, top, opts)
    elif opts.format == 'verilog':
        rtl = _build_verilog_include(objcode, bottom, top, opts)
    else:
        print >> sys.stderr, "Invalid output format '%s'." % opts.format
        sys.exit(2)


    # Done. Write to output file and quit.
    try:
        fo = open(opts.output, "w")
        print >> fo, rtl
        #fo.close()
    except IOError as e:
        print e 
        sys.exit(e.errno)


    
if __name__ == "__main__":
    _main(sys.argv[1:])
    sys.exit(0)

 