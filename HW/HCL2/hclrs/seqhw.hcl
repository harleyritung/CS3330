register pP {
    # our own internal register. P_pc is its output, p_pc is its input.
        pc:64 = 0; # 64-bits wide; 0 is its default value.

        # we could add other registers to the P register bank
        # register bank should be a lower-case letter and an upper-case letter, in that order.

        # there are also two other signals we can optionally use:
        # "bubble_P = true" resets every register in P to its default value
        # "stall_P = true" causes P_pc not to change, ignoring p_pc's value
}

# "pc" is a pre-defined input to the instruction memory and is the
# address to fetch 6 bytes from (into pre-defined output "i10bytes").
pc = P_pc;

# we can define our own input/output "wires" of any number of 0<bits<=80
wire opcode:8, icode:4, ifun:4;

# the x[i..j] means "just the bits between i and j".  x[0..1] is the
# low-order bit, similar to what the c code "x&1" does; "x&7" is x[0..3]
opcode = i10bytes[0..8];   # first byte read from instruction memory
icode = opcode[4..8];      # top nibble of that byte
ifun = opcode[0..4];

/* we could also have done i10bytes[4..8] directly, but I wanted to
 * demonstrate more bit slicing... and all 3 kinds of comments      */
// this is the third kind of comment

# named constants can help make code readable
const TOO_BIG = 0xC; # the first unused icode in Y86-64

# some named constants are built-in: the icodes, ifuns, STAT_??? and REG_???


# Stat is a built-in output; STAT_HLT means "stop", STAT_AOK means
# "continue".  The following uses the mux syntax described in the
# textbook
Stat = [
        icode == HALT : STAT_HLT;
        icode > 11    : STAT_INS;
        1             : STAT_AOK;
];

wire rB:4, rA:4;
rB = i10bytes[8..12];
rA = i10bytes[12..16];
reg_srcA = rA;
reg_srcB = [
	 icode in {PUSHQ, POPQ, CALL, RET} : REG_RSP;
	 1     	  	  	      	   : rB;
];
wire valA:64, valB:64, valC:64, valE:64;
valA = reg_outputA;
valB = reg_outputB;

# initialize CCs
wire c_SF: 1, c_ZF: 1;
register cC {
	 SF:1 = 0;
	 ZF:1 = 1;
 }

# only sets CCs if icode == OPQ
stall_C = (icode != OPQ);

# setting conditions for conditional movs and jXX
wire conditionsMet:1;
conditionsMet = [
	 ifun == ALWAYS : 1;
	 ifun == LE : C_SF || C_ZF;
	 ifun == LT : C_SF;
	 ifun == EQ : C_ZF;
	 ifun == NE : !C_ZF;
	 ifun == GE : !C_SF || C_ZF;
	 ifun == GT : !C_SF && !C_ZF;
	 1    	    : 0;
];

# Extracting memory location for jumps and values for movs
valC = [
     icode in {JXX, CALL} : i10bytes[8..72];
     1 	      	  	  : i10bytes[16..80];
];

# ALU calculations for OPQ and RMMOVQ instructions
valE = [
     icode in {RMMOVQ, MRMOVQ}	  : valC + valB;
     icode in {POPQ, RET}     	  : valB + 8;
     icode in {PUSHQ, CALL}	  : valB - 8;
     icode == OPQ && ifun == ADDQ : valA + valB;
     icode == OPQ && ifun == SUBQ : valB - valA;
     icode == OPQ && ifun == ANDQ : valA & valB;
     icode == OPQ && ifun == XORQ : valA ^ valB;
     1 	      	     	     	  : 0;
];

# CC setting
c_ZF = (valE == 0);
c_SF = (valE >= 0x8000000000000000);

# setting data input for writeback
reg_inputE = [
       icode == IRMOVQ				: valC;
       icode == RRMOVQ 	       	   	 	: valA;
       icode in {PUSHQ, OPQ, CALL, POPQ, RET} 	: valE;
       icode in {MRMOVQ}	   	 	: mem_output;
       1     		       	   	 	: 0;
];

reg_inputM = [
#	icode == POPQ : valE;
	icode == POPQ : mem_output;
	1     	      : 0;
];

# setting destinations for writeback
reg_dstE = [
       !conditionsMet && icode == CMOVXX	   : REG_NONE;
       icode in {RRMOVQ, IRMOVQ, OPQ} 	   	   : rB;
       icode in {PUSHQ, POPQ, CALL, RET} 	   : REG_RSP;
       icode in {MRMOVQ}	     	     	   : rA;
       1     	       			     	   : REG_NONE;
];

reg_dstM = [
	icode == POPQ : rA;
	1     	      : REG_NONE;
];

# updating mem
mem_addr = [
	icode in {POPQ, RET} : valB;
	1     	      	     : valE;
];
mem_input = [
	icode == CALL : p_pc - 2;
	1     	      : valA;
];
mem_readbit = [
	icode in {MRMOVQ, POPQ, RET} : 1;
	1     	 	  	     : 0;
];
mem_writebit = [
	icode in {RMMOVQ, PUSHQ, CALL} : 1;
	1     	 	  	       : 0;
];

# to make progress, we have to update the PC
p_pc = [
        icode in {HALT, NOP}		    : P_pc + 1;
        icode in {RRMOVQ, OPQ, PUSHQ, POPQ} : P_pc + 2;
        icode == CALL	       	      	    : valC;
	icode == RET			    : mem_output;
        icode in {IRMOVQ, RMMOVQ, MRMOVQ}   : P_pc + 10;
	icode == JXX && conditionsMet	    : valC;
	icode == JXX 			    : P_pc + 9;
        1     	     			    : P_pc;
];