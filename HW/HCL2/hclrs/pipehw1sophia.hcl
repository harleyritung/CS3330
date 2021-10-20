
#sophia walton, srw9rx
#pipehw1.hcl
#a five stage pipeline that implements halt, irmovq, rrmovq, nop, opq, and cmovxx
#condition codes
register cC {
	SF:1 = 0;
	ZF:1 = 1;
}

#fetch
register fF {
	pc:64 = 0; #program counter based on fetch
}

#program counter
pc = F_pc;
f_pc = [
	f_stat != STAT_AOK : pc; #doesn't add if it is a halt
	1 : f_valP; #otherwise, it does add to the program counter
];
#valP - the value of the program counter to be added
f_valP = [
	f_icode in {IRMOVQ}: pc + 10;
	f_icode in {RRMOVQ, OPQ} : pc + 2;
	1 : pc + 1;
];

#calculate if we should keep going
f_stat = [
	f_icode == HALT : STAT_HLT;
	f_icode in {NOP, RRMOVQ, IRMOVQ, RMMOVQ, MRMOVQ, OPQ, JXX, CALL, RET, PUSHQ, POPQ} : STAT_AOK;
	1 : STAT_INS;
];

#begin fD items

f_icode = i10bytes[4..8]; #icode
f_ifun = i10bytes[0..4]; #opcode

#register A (copied from last week's hw)
f_rA = [
	f_icode in {RRMOVQ, IRMOVQ, MRMOVQ, RMMOVQ, OPQ, PUSHQ, POPQ}: i10bytes[12..16];
	1: REG_NONE;
];

#register B (copied from last week's hw but got rid of push and pop)
f_rB = [
	f_icode in {RRMOVQ, IRMOVQ, MRMOVQ, RMMOVQ, OPQ, PUSHQ, POPQ}: i10bytes[8..12];
	1: REG_NONE;
];

#valC - the value of the immediate. Only used when we need an immediate (copied from last week)
f_valC = [
	f_icode in {IRMOVQ, MRMOVQ, RMMOVQ} : i10bytes[16..80];
	1 : 0;
];



#fetch decode reg
register fD {
	stat:3 = STAT_BUB; #should all be bubble to assume a nop
	icode:4 = NOP; #assume nop
	ifun:4 = 0; #assume nothing
	rA:4 = REG_NONE; #default no register
	rB:4 = REG_NONE; #default no register
	valC:64 = 0; #the value of the immediate
	valP:64 = 0; #the value of the pc
}


#begin dE actions

#copy things that don't need to change
d_stat = D_stat;
d_icode = D_icode;
d_ifun = D_ifun;
d_valC = D_valC;

#based on decode, read registers
reg_srcA = [
	D_icode in {RRMOVQ, OPQ} : D_rA; #reads rA
	1 : REG_NONE; #reads nothing
];
#only need other register in opq
reg_srcB = [
	D_icode in {OPQ} : D_rB;
	1 : REG_NONE;
];

#the register we want to write to
d_dstE = [
	D_icode in {RRMOVQ, IRMOVQ, OPQ} : D_rB;
	1 : REG_NONE; 
];

#decide whether we want to forward items
d_valA = [
	reg_srcA == REG_NONE: 0;
	reg_srcA == e_dstE : e_valE; # execute
	reg_srcA == m_dstE : m_valE; # memory
	reg_srcA == W_dstE : W_valE; # writeback
	1 : reg_outputA; #no forwarding
];
d_valB = [
	reg_srcB == REG_NONE: 0;
	reg_srcB == e_dstE : e_valE; #execute
	reg_srcB == m_dstE : m_valE; #memory
	reg_srcB == W_dstE : W_valE; #writeback
	1 : reg_outputB; #no forwarding
];



#decode execute reg
register dE {
	stat:3 = STAT_BUB;
	icode:4 = NOP;
	ifun:4 = 0;
	valC:64 = 0;
	valA:64 = 0;
	valB:64 = 0;
	dstE:4 = REG_NONE;
}

#copy what can be reused
e_stat = E_stat;
e_icode = E_icode;
e_valA = E_valA;

e_dstE = [
	E_icode == CMOVXX && !e_conditionsMet : REG_NONE; #check the conditional move here
	1 : E_dstE;
];

#set the value that is written to register (from last week)
e_valE = [
	E_icode in { RRMOVQ } : E_valA; #value from rA
	E_icode in { IRMOVQ } : E_valC; #immediate
	#values of the operations
	E_icode == OPQ && E_ifun == ADDQ : E_valB + E_valA;
	E_icode == OPQ && E_ifun == SUBQ : E_valB - E_valA;
	E_icode == OPQ && E_ifun == XORQ : E_valB ^ E_valA;
	E_icode == OPQ && E_ifun == ANDQ : E_valB & E_valA;
	1 : 0;
];

#condition codes (from last week)
c_ZF = e_valE == 0;
c_SF = e_valE != 0 && e_valE >= 0x8000000000000000; 
stall_C = E_icode != OPQ; #stall the value if the icode is not an op because we need to calculate flags

#condition codes (copied from last week)
e_conditionsMet = [
	E_ifun == 0 : true;
	E_ifun == LE : C_ZF || C_SF;
	E_ifun == LT : C_SF;
	E_ifun == EQ : C_ZF;
	E_ifun == NE : !C_ZF;
	E_ifun == GE : !C_SF;
	E_ifun == GT : !C_ZF && !C_SF;
	1 : false;
];

#begin memory edits (don't have to do anything yet)

#execute memory reg
register eM {
	stat:3 = STAT_BUB;
	icode:4 = NOP;
	conditionsMet:1 = false;
	valE:64 = 0;
	valA:64 = 0;
	dstE:4 = REG_NONE;
}

#save what doesn't have to change
m_dstE = M_dstE;
m_valE = M_valE;
m_icode = M_icode;
m_stat = M_stat;

#begin writeback edits - just return what we want to the register file
#memory writeback reg
register mW {
	stat:3 = STAT_BUB;
	icode:4 = NOP;
	valE:64 = 0;
	dstE:4 = REG_NONE;
}

reg_inputE = W_valE; #send valE to dstE
reg_dstE = W_dstE; #set dstE


Stat = W_stat; # output; halts execution and reports errors


