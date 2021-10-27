
######### The PC #############
register fF { predPC:64 = 0; } 

register cC {
	SF:1 = 0;
	ZF:1 = 1;
}

########## Fetch #############

f_icode = i10bytes[4..8];

f_ifun = i10bytes[0..4];

f_rA = [
f_icode in {RRMOVQ, IRMOVQ, MRMOVQ, RMMOVQ, OPQ, PUSHQ, POPQ} : i10bytes[12..16];
1: REG_NONE;
];

f_rB = [
f_icode in {PUSHQ, POPQ} : REG_RSP;
f_icode in {RRMOVQ, IRMOVQ, MRMOVQ, RMMOVQ, OPQ, PUSHQ, POPQ} : i10bytes[8..12];
1: REG_NONE;
];

f_valC = [
	f_icode in {JXX, CALL} : i10bytes[8..72]; 
	f_icode in {IRMOVQ, MRMOVQ, RMMOVQ} : i10bytes[16..80]; 
	1 : 0;
];

pc = [
M_icode == JXX && !M_conditionsMet : M_valA; 
W_icode == RET : W_valM; 
1: F_predPC; 
];

f_predPC = [
	f_stat != STAT_AOK : pc; 
	f_icode in {JXX, CALL} : f_valC; 
	1 : f_valP; 
];

f_valP = [
	f_icode in {MRMOVQ, IRMOVQ, RMMOVQ}: pc + 10;
	f_icode in {JXX, CALL} : pc + 9;
	f_icode in {RRMOVQ, OPQ, PUSHQ, POPQ} : pc + 2;
	1 : pc + 1;
];

f_stat = [
	f_icode == HALT : STAT_HLT;
	f_icode in {NOP, RRMOVQ, IRMOVQ, RMMOVQ, MRMOVQ, OPQ, JXX, PUSHQ, POPQ, CALL, RET} : STAT_AOK;
	1 : STAT_INS;
];

########## Decode #############

register fD {
	ifun:4 = 0;
	stat:3 = STAT_BUB; 
	valC:64 = 0; 
	rA:4 = REG_NONE;
	rB:4 = REG_NONE;
	icode:4 = NOP;
	valP:64 = 0;
}

reg_srcA = [
	D_icode in {RMMOVQ, RRMOVQ, OPQ, PUSHQ} : D_rA;
	D_icode in {POPQ, RET} : REG_RSP;
	1 : REG_NONE;
];

reg_srcB = [
	D_icode in {RMMOVQ, MRMOVQ, OPQ} : D_rB;
	D_icode in {PUSHQ, POPQ, CALL, RET} : REG_RSP;
	1 : REG_NONE;
];

########## Execute #############
register dE {
	stat:3 = STAT_BUB;
	valC:64 = 0;
	valA:64 = 0; #value from register A
	valB:64 = 0; #value from register B
	dstM:4 = REG_NONE;
	dstE:4 = REG_NONE;
	icode:4 = NOP;
	ifun:4 = 0;
}

d_ifun = D_ifun;
d_valC = D_valC;
d_stat = D_stat;
d_icode = D_icode;

d_dstM = [
	D_icode in {MRMOVQ, POPQ} : D_rA; 
	1: REG_NONE;
];

d_dstE = [
	D_icode in {RRMOVQ, IRMOVQ, OPQ} : D_rB; 
	D_icode in {PUSHQ, POPQ, CALL, RET} : REG_RSP; 
	1 : REG_NONE; 
];

d_valA = [
	D_icode in {CALL, JXX} : D_valP; 
	reg_srcA == REG_NONE: 0;
	reg_srcA == e_dstE : e_valE; 
	reg_srcA == m_dstM : m_valM; 
	reg_srcA == m_dstE : m_valE; 
	reg_srcA == W_dstM : W_valM; 
	reg_srcA == W_dstE : W_valE; 
	1 : reg_outputA; 
];

d_valB = [
	reg_srcB == REG_NONE: 0;
	reg_srcB == e_dstE : e_valE; 
	reg_srcB == m_dstM : m_valM; 
	reg_srcB == m_dstE : m_valE; 
	reg_srcB == W_dstM : W_valM; 
	reg_srcB == W_dstE : W_valE; 
	1 : reg_outputB; 
];

########## Memory #############
register eM {
	stat:3 = STAT_BUB;
	valA:64 = 0;
	valE:64 = 0;
	dstM:4 = REG_NONE;
	dstE:4 = REG_NONE;
	icode:4 = NOP;
	conditionsMet:1 = false;
	ifun:4 = 0;
}
e_ifun = E_ifun;

c_ZF = e_valE == 0;
c_SF = e_valE != 0 && e_valE >= 0x8000000000000000; 
stall_C = E_icode != OPQ; 

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

e_valA = E_valA;
e_icode = E_icode;
e_dstM = E_dstM;
e_dstE = [
	E_icode == CMOVXX && !e_conditionsMet : REG_NONE; 
	1 : E_dstE;
];

e_stat = [
	E_icode == OPQ && E_ifun > XORQ : STAT_INS; 
	(E_icode == CMOVXX || E_icode == JXX) && (E_ifun > GT) : STAT_INS;
	1 : E_stat;
];

e_valE = [
	E_icode in {PUSHQ, CALL} : E_valB - 8; 
	E_icode in {POPQ, RET} : E_valB + 8; 
	E_icode in { RRMOVQ } : E_valA; 
	E_icode in { IRMOVQ } : E_valC; 
	E_icode == OPQ && E_ifun == ADDQ : E_valB + E_valA;
	E_icode == OPQ && E_ifun == SUBQ : E_valB - E_valA;
	E_icode == OPQ && E_ifun == XORQ : E_valB ^ E_valA;
	E_icode == OPQ && E_ifun == ANDQ : E_valB & E_valA;
	E_icode in { RMMOVQ, MRMOVQ } : E_valC + E_valB; 
	1 : 0;
];

########## Writeback #############
register mW {
	dstM:4 = REG_NONE;
	icode:4 = NOP;
	stat:3 = STAT_BUB;
	valE:64 = 0;
	valM:64 = 0;
	dstE:4 = REG_NONE;
	ifun:4 = 0;
}
m_valE = M_valE;
m_dstM = M_dstM;
m_dstE = M_dstE;
m_icode = M_icode;
m_stat = M_stat;
m_ifun = M_ifun;

m_valM = mem_output; 

mem_addr = [
	M_icode in { MRMOVQ, RMMOVQ, PUSHQ, CALL} : M_valE; 
	M_icode in {POPQ, RET} : M_valA; 
    1: 0xBADBADBAD;
];

mem_readbit = M_icode in {MRMOVQ, POPQ, RET};

mem_writebit = M_icode in {RMMOVQ, PUSHQ, CALL};

mem_input = [
	M_icode in { RMMOVQ, PUSHQ, CALL} : M_valA;
    1: 0xBADBADBAD;
];

reg_dstM = W_dstM;
reg_dstE = W_dstE;
reg_inputE = W_valE;
reg_inputM = W_valM;

Stat = W_stat;

wire loadUse:1;
wire mispredicted:1;
wire rethazard:1;

loadUse = (E_icode in {MRMOVQ, POPQ}) && (E_dstM in {reg_srcA, reg_srcB}); 
rethazard = RET in { D_icode, E_icode, M_icode };
mispredicted = E_icode == JXX && !e_conditionsMet;

bubble_F = false;
stall_F = loadUse || rethazard;

bubble_D = mispredicted || (!loadUse && rethazard);
stall_D = loadUse;

bubble_E = mispredicted || loadUse;
stall_E = false;

bubble_M = false;
stall_M = false;

bubble_W = false;
stall_W = false;