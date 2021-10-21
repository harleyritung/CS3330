# -*-sh-*- # this line enables partial syntax highlighting in emacs

######### The PC #############
register fF { pc:64 = 0; }


########## Fetch #############
pc = F_pc;

f_icode = i10bytes[4..8];
f_ifun = i10bytes[0..4];

f_rA = [
    f_icode in {MRMOVQ, RMMOVQ} : i10bytes[12..16];
    1: REG_NONE;
];

f_rB = [
    f_icode in {MRMOVQ, RMMOVQ} :i10bytes[8..12];
    1: REG_NONE;
];

f_valC = [
    f_icode in { JXX } : i10bytes[8..72];
    1 : i10bytes[16..80];
];

f_pc = [
    f_stat != STAT_AOK : pc; 
    1 : f_valP; 
];

f_valP = [
	f_icode in {MRMOVQ, IRMOVQ, RMMOVQ}: pc + 10;
	f_icode in {RRMOVQ, OPQ} : pc + 2;
	1 : pc + 1;
];

f_stat = [
	f_icode == HALT : STAT_HLT;
	f_icode in {NOP, RRMOVQ, IRMOVQ, RMMOVQ, MRMOVQ, OPQ, JXX, CALL, RET, PUSHQ, POPQ} : STAT_AOK;
	1 : STAT_INS;
];

########## Decode #############

register fD {
	ifun:4 = 0;
	stat:3 = STAT_AOK; 
	valC:64 = 0; 
	rA:4 = REG_NONE;
	rB:4 = REG_NONE;
	icode:4 = NOP;
	valP:64 = 0;
}


reg_srcA = [
	D_icode == RMMOVQ : D_rA;
	1 : REG_NONE;
];

reg_srcB = [
	D_icode in {RMMOVQ, MRMOVQ} : D_rB;
	1 : REG_NONE;
];


########## Execute #############

register dE {
	stat:3 = STAT_AOK;
	valC:64 = 0;
	valA:64 = 0;
	valB:64 = 0;
	dstE:4 = REG_NONE;
	icode:4 = NOP;
}

d_valC = D_valC;
d_stat = D_stat;
d_icode = D_icode;


d_dstE = [
	D_icode in {MRMOVQ} : D_rA;
	1: REG_NONE;
];

d_valA = [
	reg_srcA == REG_NONE : 0;
	reg_srcA == e_dstE : e_valE;
	reg_srcA == m_dstE : m_valE;
	reg_srcA == W_dstE : W_valE; 
	1 : reg_outputA; 
];

d_valB = [
	reg_srcB == REG_NONE: 0;
	reg_srcB == e_dstE : e_valE; 
	reg_srcB == m_dstE : m_valE; 
	reg_srcB == W_dstE : W_valE; 
	1 : reg_outputB; 
];

########## Memory #############

register eM {
	stat:3 = STAT_BUB;
	valA:64 = 0;
	valE:64 = 0;
	dstE:4 = REG_NONE;
	icode:4 = 0;
}

e_stat = E_stat;
e_valA = E_valA;
e_icode = E_icode;
e_dstE = E_dstE;

e_valE = [
	E_icode in { RMMOVQ, MRMOVQ } : E_valC + E_valB;
	1 : 0;
];


########## Writeback #############

register mW {
	dstE:4 = REG_NONE;
	icode:4 = NOP;
	stat:3 = STAT_AOK;
	valE:64 = 0;
}

m_dstE = M_dstE;
m_icode = M_icode;
m_stat = M_stat;

m_valE = mem_output; 

mem_addr = [
	M_icode in { MRMOVQ, RMMOVQ } : M_valE;
    1: 0xBADBADBAD;
];
mem_readbit = M_icode in { MRMOVQ };
mem_writebit = M_icode in { RMMOVQ };
mem_input = [
	M_icode in { RMMOVQ } : M_valA;
    1: 0xBADBADBAD;
];

reg_dstE = W_dstE;
reg_inputE = W_valE;


Stat = W_stat;


wire loadUse:1;

loadUse = (E_icode in {MRMOVQ}) && (E_dstE in {reg_srcA, reg_srcB}); 

stall_F = loadUse;

stall_D = loadUse;

bubble_E = loadUse;


