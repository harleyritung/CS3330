########## Fetch #############
register fF { predpc:64 = 0; }

pc = F_predpc;

f_predpc = [
    f_stat != STAT_AOK : pc; 
    1 : f_valP; 
];

f_valP = [
	f_icode in {MRMOVQ, IRMOVQ, RMMOVQ}: pc + 10;
	f_icode in {RRMOVQ, OPQ} : pc + 2;
	f_icode == JXX : f_valC;
	1 : pc + 1;
];

f_stat = [
	f_icode == HALT : STAT_HLT;
	f_icode in {NOP, RRMOVQ, IRMOVQ, RMMOVQ, MRMOVQ, OPQ, JXX, CALL, RET, PUSHQ, POPQ} : STAT_AOK;
	1 : STAT_INS;
];

f_icode = i10bytes[4..8];
f_ifun = i10bytes[0..4]; 


f_rA = [
	f_icode in {RRMOVQ, IRMOVQ, MRMOVQ, RMMOVQ, OPQ}: i10bytes[12..16];
	1	   	    	    	    	    	: REG_NONE;
];

f_rB = [
	f_icode in {RRMOVQ, IRMOVQ, MRMOVQ, RMMOVQ, OPQ}: i10bytes[8..12];
	1	   	    	    	    	    	: REG_NONE;
];

f_valC = [
	f_icode in {IRMOVQ, MRMOVQ, RMMOVQ} : i10bytes[16..80];
	1 : 0;
];

########## Decode #############

register fD {
	stat: 3 = STAT_AOK; 
	icode:4 = NOP; 
	ifun: 4 = 0; 
	rA: 4 = REG_NONE;
	rB: 4 = REG_NONE;
	valC: 64 = 0; 
}

bubble_D = [
	mispredicted : 1;
	1	     : 0;
];

d_stat = D_stat;
d_icode = D_icode;
d_ifun = D_ifun;
d_valC = D_valC;

reg_srcA = [
	D_icode in {RRMOVQ, RMMOVQ, OPQ} : D_rA;
	1 	   	    	 : REG_NONE;
];

reg_srcB = [
	D_icode in {RMMOVQ, MRMOVQ, OPQ} : D_rB;
	1 	   	 : REG_NONE;
];

d_dstE = [
	D_icode in {RRMOVQ, IRMOVQ, OPQ} : D_rB;
	D_icode == MRMOVQ : D_rA;
	1 	   	    	    	 : REG_NONE; 
];

d_valA = [
	reg_srcA == REG_NONE : 0;
	reg_srcA == e_dstE   : e_valE;
	reg_srcA == m_dstE   : m_valE;
	reg_srcA == W_dstE   : W_valE; 
	1 	    	     : reg_outputA;
];

d_valB = [
	reg_srcB == REG_NONE : 0;
	reg_srcB == e_dstE   : e_valE; 
	reg_srcB == m_dstE   : m_valE;
	reg_srcB == W_dstE   : W_valE; 
	1 	    	     : reg_outputB; 
];

########## Execute #############
register dE {
	stat:3 = STAT_AOK;
	icode:4 = NOP;
	ifun:4 = 0;
	valC:64 = 0;
	valA:64 = 0;
	valB:64 = 0;
	dstE:4 = REG_NONE;
	valC: 64 = 0;
}

bubble_E = [
	mispredicted : 1;
	1	     : 0;
];

e_stat = E_stat;
e_icode = E_icode;
e_valA = E_valA;
e_valC = E_valC;

e_dstE = [
	E_icode == CMOVXX && !e_conditionsMet : REG_NONE;
	1 : E_dstE;
];

e_valE = [
	E_icode == RRMOVQ : E_valA;
	E_icode == IRMOVQ : E_valC;
	E_icode in {RMMOVQ, MRMOVQ} : E_valC + E_valB;
	E_icode == OPQ && E_ifun == ADDQ : E_valB + E_valA;
	E_icode == OPQ && E_ifun == SUBQ : E_valB - E_valA;
	E_icode == OPQ && E_ifun == XORQ : E_valB ^ E_valA;
	E_icode == OPQ && E_ifun == ANDQ : E_valB & E_valA;
	1 : 0;
];

register cC {
	SF:1 = 0;
	ZF:1 = 1;
}

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

wire mispredicted: 1;
mispredicted = [
	E_icode == JXX && !e_conditionsMet : 1;
	1 	       	  		   : 0;
];

########## Memory #############

register eM {
	stat:3 = STAT_BUB;
	icode:4 = NOP;
	conditionsMet:1 = false;
	valE:64 = 0;
	valA:64 = 0;
	dstE:4 = REG_NONE;
}


m_dstE = M_dstE;
m_valE = mem_output;
m_icode = M_icode;
m_stat = M_stat;

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


########## Writeback #############

register mW {
	stat:3 = STAT_AOK;
	icode:4 = NOP;
	valE:64 = 0;
	dstE:4 = REG_NONE;
}

reg_inputE = W_valE;
reg_dstE = W_dstE;

#reg_inputE = [
#	W_icode == RRMOVQ : W_rvalA;
#	W_icode in {IRMOVQ} : W_valC;
#        1: 0xBADBADBAD;
#];

Stat = W_stat;

wire loadUse:1;

loadUse = (E_icode in {MRMOVQ}) && (E_dstE in {reg_srcA, reg_srcB}); 

stall_F = loadUse;

stall_D = loadUse;

bubble_E = loadUse;