#sophia walton, srw9rx
#pipelab2.hcl - pipeline with 5 registers that implements rmmovq, mrmovq, and halt
#based on seq_memory.hcl and pipehw1.hcl

######### The PC #############
register fF { pc:64 = 0; } #don't have to modify


########## Fetch #############
#from pipehw1.hcl

#icode
f_icode = i10bytes[4..8];

#ifun (don't need)
f_ifun = i10bytes[0..4];

#only need register for MRMOVQ, RMMOVQ
f_rA = [
f_icode in {MRMOVQ, RMMOVQ} : i10bytes[12..16];
1: REG_NONE;
];
#only need register for MRMOVQ, RMMOVQ
f_rB = [
f_icode in {MRMOVQ, RMMOVQ} :i10bytes[8..12];
1: REG_NONE;
];


#immediate
f_valC = [
	f_icode in { JXX } : i10bytes[8..72];
	1 : i10bytes[16..80];
];

#set pc to the pc from here
pc = F_pc;
#update the fetch pc that we use for pc
f_pc = [
	f_stat != STAT_AOK : pc; #doesn't add if it is a halt
	1 : f_valP; #otherwise, it does add to the program counter
];
#value added to pc
f_valP = [
	f_icode in {MRMOVQ, IRMOVQ, RMMOVQ}: pc + 10;
	f_icode in {RRMOVQ, OPQ} : pc + 2;
	1 : pc + 1;
];

#stat of f - same as previous 
f_stat = [
	f_icode == HALT : STAT_HLT;
	f_icode in {NOP, RRMOVQ, IRMOVQ, RMMOVQ, MRMOVQ, OPQ, JXX, CALL, RET, PUSHQ, POPQ} : STAT_AOK;
	1 : STAT_INS;
];

########## Decode #############

register fD {
	ifun:4 = 0;
	stat:3 = STAT_BUB; #stat defaults to nop
	valC:64 = 0; #value of immediate in mrmovq and rmmovq
	rA:4 = REG_NONE;
	rB:4 = REG_NONE;
	icode:4 = NOP;
	valP:64 = 0;
}

#find the item at rA
reg_srcA = [
	D_icode in {RMMOVQ} : D_rA;
	1 : REG_NONE;
];
#find the item at rB
reg_srcB = [
	D_icode in {RMMOVQ, MRMOVQ} : D_rB;
	1 : REG_NONE;
];




########## Execute #############
register dE {
	stat:3 = STAT_BUB;
	valC:64 = 0;
	valA:64 = 0; #value from register A
	valB:64 = 0; #value from register B
	dstE:4 = REG_NONE;
	icode:4 = NOP;
}
#things that don't change
d_valC = D_valC;
d_stat = D_stat;
d_icode = D_icode;

#we only want to write to registers if MRMOVQ
d_dstE = [
	D_icode in {MRMOVQ} : D_rA;
	1: REG_NONE;
];

#value at register A
#decide whether we want to forward items
d_valA = [
	reg_srcA == REG_NONE : 0;
	reg_srcA == e_dstE : e_valE; # forward post-execute
	reg_srcA == m_dstE : m_valE; # forward post-memory
	reg_srcA == W_dstE : W_valE; # forward pre-writeback ("register file forwarding")
	1 : reg_outputA; # returned by register file based on reg_srcA
];

#value at register B
d_valB = [
	reg_srcB == REG_NONE: 0;
	# forward from another phase
	reg_srcB == e_dstE : e_valE; # forward post-execute
	reg_srcB == m_dstE : m_valE; # forward post-memory
	reg_srcB == W_dstE : W_valE; # forward pre-writeback ("register file forwarding")
	1 : reg_outputB; # returned by register file based on reg_srcB
];





########## Memory #############
register eM {
	stat:3 = STAT_BUB;
	valA:64 = 0;
	valE:64 = 0;
	dstE:4 = REG_NONE;
	icode:4 = 0;
}
#things that don't change
e_stat = E_stat;
e_valA = E_valA;
e_icode = E_icode;
e_dstE = E_dstE;

#set valE to the loc in memory
e_valE = [
	E_icode in { RMMOVQ, MRMOVQ } : E_valC + E_valB;
	1 : 0;
];



########## Writeback #############
register mW {
	dstE:4 = REG_NONE;
	icode:4 = NOP;
	stat:3 = STAT_BUB;
	valE:64 = 0;
}
#things that don't change
m_dstE = M_dstE;
m_icode = M_icode;
m_stat = M_stat;

m_valE = mem_output; #want the value retrieved from memory

#read and write to memory depending on the icode
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

#set the registers to the destinations at writeback
reg_dstE = W_dstE;
reg_inputE = W_valE;


Stat = W_stat;


wire loadUse:1;

loadUse = (E_icode in {MRMOVQ}) && (E_dstE in {reg_srcA, reg_srcB}); 

stall_F = loadUse;

stall_D = loadUse;

bubble_E = loadUse;