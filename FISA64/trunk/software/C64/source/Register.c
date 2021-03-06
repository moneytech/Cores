// ============================================================================
//        __
//   \\__/ o\    (C) 2012-2015  Robert Finch, Stratford
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// C64 - Raptor64 'C' derived language compiler
//  - 64 bit CPU
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU Lesser General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or     
// (at your option) any later version.                                      
//                                                                          
// This source file is distributed in the hope that it will be useful,      
// but WITHOUT ANY WARRANTY; without even the implied warranty of           
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            
// GNU General Public License for more details.                             
//                                                                          
// You should have received a copy of the GNU General Public License        
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    
//                                                                          
// ============================================================================
//
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "c.h"
#include "expr.h"
#include "Statement.h"
#include "gen.h"
#include "cglbdec.h"
/*
int tmpregs[] = {3,4,5,6,7,8,9,10};
int regstack[8];
int rsp=7;
int regmask=0;

int tmpbregs[] = {3,4,5,6,7,8};
int bregstack[6];
int brsp=5;
int bregmask = 0;
*/
static short int next_reg;
static short int next_breg;
#define MAX_REG 4			/* max. scratch data	register (D2) */
#define	MAX_REG_STACK	30

// Only registers 5,6,7 and 8 are used for temporaries
static short int reg_in_use[256];	// 0 to 15
static short int breg_in_use[16];	// 0 to 15
static short int save_reg_in_use[256];

static struct {
    enum e_am mode;
    short int reg;
	union {
		char isPushed;	/* flags if pushed or corresponding reg_alloc * number */
		char allocnum;
	} f;
} 
	reg_stack[MAX_REG_STACK + 1],
	reg_alloc[MAX_REG_STACK + 1],
	save_reg_alloc[MAX_REG_STACK + 1],
	stacked_regs[MAX_REG_STACK + 1],
	breg_stack[MAX_REG_STACK + 1],
	breg_alloc[MAX_REG_STACK + 1];

static short int reg_stack_ptr;
static short int reg_alloc_ptr;
static short int save_reg_alloc_ptr;
static short int breg_stack_ptr;
static short int breg_alloc_ptr;

char tmpregs[] = {3,4,5,6,7,8,9,10};
char tmpbregs[] = {5,6,7,8};
char regstack[18];
char bregstack[18];
int rsp=17;
int regmask=0;
int brsp=17;
int bregmask=0;

void initRegStack()
{
	int i;

    if (is816) {
        next_reg = 3*4+128;
        next_breg = 5*4+128;
    }
    else {
        next_reg = 3;
        next_breg = 5;
    }
	//for (rsp=0; rsp < 3; rsp=rsp+1)
	//	regstack[rsp] = tmpregs[rsp];
	//rsp = 0;
	for (i = 0; i <= 255; i++) {
		reg_in_use[i] = -1;
		breg_in_use[i] = -1;
	}
    reg_stack_ptr = 0;
    reg_alloc_ptr = 0;
    breg_stack_ptr = 0;
    breg_alloc_ptr = 0;
//    act_scratch = 0;
    memset(reg_stack,0,sizeof(reg_stack));
    memset(reg_alloc,0,sizeof(reg_alloc));
    memset(breg_stack,0,sizeof(breg_stack));
    memset(breg_alloc,0,sizeof(breg_alloc));
    memset(stacked_regs,0,sizeof(stacked_regs));
    memset(save_reg_alloc,0,sizeof(save_reg_alloc));
}

void GenerateTempRegPush(int reg, int rmode, int number)
{
	AMODE *ap1;
    ap1 = allocAmode();
    ap1->preg = reg;
    ap1->mode = rmode;

	if (isTable888|isFISA64)
		GenerateMonadic(op_push,0,ap1);
	else if (is816) {
        GenerateMonadic(op_sec,0,NULL);
        GenerateMonadic(op_php,0,NULL);
        GenerateMonadic(op_sei,0,NULL);
        GenerateMonadic(op_lda,0,makereg(regSP));
        GenerateMonadic(op_sbc,0,make_immed(4));
        GenerateMonadic(op_sta,0,makereg(regSP));
        GenerateMonadic(op_lda,0,makereg(regSP+2));
        GenerateMonadic(op_sbc,0,make_immed(0));
        GenerateMonadic(op_sta,0,makereg(regSP+2));
        GenerateMonadic(op_plp,0,NULL);
        GenerateMonadic(op_lda,0,makereg(reg));
        GenerateMonadic(op_sta,0,make_indexed(0,regSP));
        GenerateMonadic(op_lda,0,makereg(reg+2));
        GenerateMonadic(op_sta,0,make_indexed(2,regSP));
    }
	else {
		GenerateTriadic(op_subui,0,makereg(regSP),makereg(regSP),make_immed(8));
		GenerateDiadic(op_sw,0,ap1,make_indirect(regSP));
	}
	TRACE(printf("pushing r%d\r\n", reg);)
    reg_stack[reg_stack_ptr].mode = (enum e_am)rmode;
    reg_stack[reg_stack_ptr].reg = reg;
    reg_stack[reg_stack_ptr].f.allocnum = number;
    if (reg_alloc[number].f.isPushed=='T')
		fatal("GenerateTempRegPush(): register already pushed");
    reg_alloc[number].f.isPushed = 'T';
	if (++reg_stack_ptr > MAX_REG_STACK)
		fatal("GenerateTempRegPush(): register stack overflow");
}

void GenerateTempBrRegPush(int reg, int rmode, int number)
{
	AMODE *ap1;
    ap1 = allocAmode();
    ap1->preg = reg;
    ap1->mode = rmode;

	GenerateMonadic(op_push,0,ap1);
    breg_stack[reg_stack_ptr].mode = (enum e_am)rmode;
    breg_stack[reg_stack_ptr].reg = reg;
    breg_stack[reg_stack_ptr].f.allocnum = number;
    if (breg_alloc[number].f.isPushed=='T')
		fatal("GenerateTempRegPush(): branch register already pushed");
    breg_alloc[number].f.isPushed = 'T';
	if (++breg_stack_ptr > MAX_REG_STACK)
		fatal("GenerateTempBRegPush(): branch register stack overflow");
}

void GenerateTempRegPop(int reg, int rmode, int number)
{
	AMODE *ap1;
 
    if (reg_stack_ptr-- == -1)
		fatal("GenerateTempRegPop(): register stack underflow");
    /* check if the desired register really is on stack */
    if (reg_stack[reg_stack_ptr].f.allocnum != number)
		fatal("GenerateTempRegPop()/2");
	if (reg_in_use[reg] >= 0)
		fatal("GenerateTempRegPop():register still in use");
	TRACE(printf("popped r%d\r\n", reg);)
	reg_in_use[reg] = number;
	ap1 = allocAmode();
	ap1->preg = reg;
	ap1->mode = rmode;
	if (isTable888|isFISA64)
		GenerateMonadic(op_pop,0,ap1);
	else {
		GenerateDiadic(op_lw,0,ap1,make_indirect(regSP));
		GenerateTriadic(op_addui,0,makereg(regSP),makereg(regSP),make_immed(8));
	}
    reg_alloc[number].f.isPushed = 'F';
}

void GenerateTempBrRegPop(int reg, int rmode, int number)
{
	AMODE *ap1;
 
    if (breg_stack_ptr-- == -1)
		fatal("GenerateTempRegPop(): branch register stack underflow");
    /* check if the desired register really is on stack */
  //  if (reg_stack[reg_stack_ptr].allocnum != number)
		//fatal("GenerateTempRegPop()/2");
	if (breg_in_use[breg_stack[breg_stack_ptr].reg] >= 0)
		fatal("GenerateTempBRegPop():branch register still in use");
	//reg_in_use[reg] = number;
	breg_in_use[breg_stack[breg_stack_ptr].reg] = breg_stack[breg_stack_ptr].f.allocnum;
	ap1 = allocAmode();
    //ap1->preg = reg;
    //ap1->mode = rmode;
	ap1->preg = breg_stack[breg_stack_ptr].reg;
	ap1->mode = breg_stack[breg_stack_ptr].mode;
	GenerateMonadic(op_pop,0,ap1);
    breg_alloc[breg_stack[breg_stack_ptr].f.allocnum].f.isPushed = 'F';
}

void initstack()
{
	initRegStack();
	initFPRegStack();
}

AMODE *GetTempRegister()
{
	AMODE *ap;
    
	if (reg_in_use[next_reg] >= 0)
		GenerateTempRegPush(next_reg, am_reg, reg_in_use[next_reg]);
	TRACE(printf("GetTempRegister:r%d\r\n", next_reg);)
    reg_in_use[next_reg] = reg_alloc_ptr;
    ap = allocAmode();
    ap->mode = am_reg;
    ap->preg = next_reg;
    ap->deep = reg_alloc_ptr;
    reg_alloc[reg_alloc_ptr].reg = next_reg;
    reg_alloc[reg_alloc_ptr].mode = am_reg;
    reg_alloc[reg_alloc_ptr].f.isPushed = 'F';
    if (is816) {
        if (next_reg++ >= 10*4+128)
    		next_reg = 3*4+128;		/* wrap around */
    }
    else {
        if (next_reg++ >= 10)
    		next_reg = 3;		/* wrap around */
    }
    if (reg_alloc_ptr++ == MAX_REG_STACK)
		fatal("GetTempRegister(): register stack overflow");
	return ap;
}

AMODE *GetTempBrRegister()
{
	AMODE *ap;

	if (breg_in_use[next_breg] >= 0)
		GenerateTempBrRegPush(next_reg, am_reg, breg_in_use[next_breg]);
    breg_in_use[next_breg] = breg_alloc_ptr;
    ap = allocAmode();
    ap->mode = am_breg;
    ap->preg = next_reg;
    ap->deep = reg_alloc_ptr;
    reg_alloc[reg_alloc_ptr].reg = next_reg;
    reg_alloc[reg_alloc_ptr].mode = am_breg;
    reg_alloc[reg_alloc_ptr].f.isPushed = 'F';
    if (next_breg++ >= 8)
		next_breg = 5;		/* wrap around */
    if (breg_alloc_ptr++ == MAX_REG_STACK)
		fatal("GetTempBRegister(): branch register stack overflow");
	return ap;
}

int SaveTempBrRegs()
{
    int i;
	int nn;
	int rm;

	nn = 0; rm = 0;
	//for (i = 5; i <= 8; i++)
	//	if (reg_in_use[i] >= 0)
	//		nn = nn + 1;
	//if (nn > 0) {
	//	nn = 0; 
	//	for (i = 5; i <= 8; i++)
	//		if (reg_in_use[i] >= 0) {
	//			rm = rm | (1 << i);
	//			GenerateMonadic(op_push,0,makereg(i));
	//			reg_stack[reg_stack_ptr].mode = rmode;
	//			reg_stack[reg_stack_ptr].reg = reg;
	//			reg_stack[reg_stack_ptr].allocnum = number;
	//			if (reg_alloc[number].isPushed)
	//				fatal("GenerateTempRegPush()/1");
	//			reg_alloc[number].flag = 1;
	//			/* check on stack overflow */
	//			if (++reg_stack_ptr > MAX_REG_STACK)
	//				fatal("GenerateTempRegPush()/2");
	//			printf("Pushed temp reg.\r\n");
	//			reg_in_use[i] = -1;
	//			nn = nn + 1;
	//		}
	//	printf("Saved temporaries %x\r\n", rm);
	//}
	nn = 0;
    for (i = 0; i < breg_alloc_ptr; i++)
		if (breg_alloc[i].f.isPushed != 'T') {
			nn++;
		}
	if (nn > 0) {
		//GenerateTriadic(op_sub,0,makereg(REG_DSP),makereg(REG_DSP),make_immed(nn));
		for (i = 0; i < breg_alloc_ptr; i++)
			if (breg_alloc[i].f.isPushed != 'T') {
				rm = rm | (1 << breg_alloc[i].reg);
				GenerateTempBrRegPush(breg_alloc[i].reg, breg_alloc[i].mode, i);//, 2);
				/* mark the register void */
				breg_in_use[breg_alloc[i].reg] = -1;
			}
		//printf("Saved temporaries %x\r\n", rm);
	}
	return nn;
}

//void RestoreTempRegs(int rgmask)
//{
//	int nn;
//	int rm;
//	int i;
//
//	nn = 0;
// 
//	for(nn = rgmask; nn > 0; nn--)
//		GenerateTempRegPop(0,0,0);
//	//if (rgmask != 0) {
//	//	for (nn = 1, rm = rgmask; nn <= 15; nn = nn + 1)
//	//		if ((rm>>nn) & 1) {
//	//			GenerateMonadic(op_pop,0,makereg(nn));
//	//			reg_in_use[nn] = 0;
//	//		}
//	//}
//}

//void RestoreTempBrRegs(int brgmask)
//{
//	int nn;
//	int rm;
//	int i;
//
//	nn = 0;
// 
//	for(nn = brgmask; nn > 0; nn--)
//		GenerateTempBrRegPop(0,0,0);
//}

/*
 * this routines checks if all allocated registers were freed
 */
void checkstack()
{
    int i;
    for (i=3; i<= 10; i++)
        if (reg_in_use[i] != -1)
            fatal("checkstack()/1");
	if (next_reg != 3) {
		//printf("Nextreg: %d\r\n", next_reg);
        fatal("checkstack()/3");
	}
    if (reg_stack_ptr != 0)
        fatal("checkstack()/5");
    if (reg_alloc_ptr != 0)
        fatal("checkstack()/6");
}

void checkbrstack()
{
    int i;
    for (i=5; i<= 8; i++)
        if (breg_in_use[i] != -1)
            fatal("checkbstack()/1");
	if (next_breg != 5) {
		//printf("Nextreg: %d\r\n", next_breg);
        fatal("checkbstack()/3");
	}
    if (breg_stack_ptr != 0)
        fatal("checkbstack()/5");
    if (breg_alloc_ptr != 0)
        fatal("checkbstack()/6");
}

/*
 * validate will make sure that if a register within an address mode has been
 * pushed onto the stack that it is popped back at this time.
 */
void validate(AMODE *ap)
{
    switch (ap->mode) {
	case am_reg:
		if ((ap->preg >= 3 && ap->preg <= 10) && reg_alloc[ap->deep].f.isPushed == 'T' ) {
			GenerateTempRegPop(ap->preg, am_reg, (int) ap->deep);
		}
		break;
    case am_indx2:
		if ((ap->preg >= 3 && ap->preg <= 10) && reg_alloc[ap->deep].f.isPushed == 'T') {
			GenerateTempRegPop(ap->preg, am_reg, (int) ap->deep);
		}
		if ((ap->sreg >= 3 && ap->sreg <= 10) && reg_alloc[ap->deep2].f.isPushed  == 'T') {
			GenerateTempRegPop(ap->sreg, am_reg, (int) ap->deep2);
		}
		break;
    case am_indx3:
		if ((ap->sreg >= 3 && ap->sreg <= 10) && reg_alloc[ap->deep2].f.isPushed == 'T') {
			GenerateTempRegPop(ap->sreg, am_reg, (int) ap->deep2);
		}
		goto common;
    case am_ind:
    case am_indx:
    case am_ainc:
    case am_adec:
common:
		if ((ap->preg >= 3 && ap->preg <= 10) && reg_alloc[ap->deep].f.isPushed == 'T') {
			GenerateTempRegPop(ap->preg, am_reg, (int) ap->deep);
		}
		break;
    }
}


/*
 * validate will make sure that if a register within an address mode has been
 * pushed onto the stack that it is popped back at this time.
 */
void validatebr(AMODE *ap)
{
    switch (ap->mode) {
	case am_breg:
		if ((ap->preg >= 5 && ap->preg <= 8) && breg_alloc[ap->deep].f.isPushed == 'T' ) {
			GenerateTempBrRegPop(ap->preg, am_reg, (int) ap->deep);
		}
		break;
    case am_indx2:
		if ((ap->sreg >= 5 && ap->sreg <= 8) && breg_alloc[ap->deep].f.isPushed == 'T') {
			GenerateTempBrRegPop(ap->sreg, am_reg, (int) ap->deep);
		}
		goto common;
    case am_indx3:
		if ((ap->sreg >= 5 && ap->sreg <= 8) && breg_alloc[ap->deep].f.isPushed == 'T') {
			GenerateTempBrRegPop(ap->sreg, am_reg, (int) ap->deep);
		}
		goto common;
    case am_ind:
    case am_indx:
    case am_ainc:
    case am_adec:
common:
		if ((ap->preg >= 5 && ap->preg <= 8) && breg_alloc[ap->deep].f.isPushed == 'T') {
			GenerateTempBrRegPop(ap->preg, am_reg, (int) ap->deep);
		}
		break;
    }
}


/*
 * release any temporary registers used in an addressing mode.
 */
void ReleaseTempRegister(AMODE *ap)
{
    int number;

	TRACE(printf("ReleaseTempRegister:r%d r%d\r\n", ap->preg, ap->sreg);)

	if (ap==NULL) {
		printf("DIAG - NULL pointer in ReleaseTempRegister\r\n");
		return;
	}

	validate(ap);
    switch (ap->mode) {
	case am_ind:
	case am_indx:
	case am_ainc:
	case am_adec:
	case am_reg:
common:
		if (ap->preg >= 3 && ap->preg <= 10) {
			if (reg_in_use[ap->preg]==-1)
				return;
			if (next_reg-- <= 3)
				next_reg = 10;
			number = reg_in_use[ap->preg];
			reg_in_use[ap->preg] = -1;
			break;
		}
		return;
    case am_indx2:
	case am_indx3:
		if (ap->sreg >= 3 && ap->sreg <= 10) {
			if (reg_in_use[ap->sreg]==-1)
				return;
			if (next_reg-- <= 3)
				next_reg = 10;
			number = reg_in_use[ap->sreg];
			reg_in_use[ap->sreg] = -1;
			//break;
		}
		goto common;
    default:
		return;
    }
 //   /* some consistency checks */
	//if (number != ap->deep) {
	//	printf("number %d ap->deep %d\r\n", number, ap->deep);
	//	//fatal("ReleaseTempRegister()/1");
	//}
	if (reg_alloc_ptr-- == 0)
		fatal("ReleaseTempRegister(): no registers are allocated");
  //  if (reg_alloc_ptr != number)
		//fatal("ReleaseTempRegister()/3");
    if (reg_alloc[number].f.isPushed=='T')
		fatal("ReleaseTempRegister(): register on stack");
}

/*
 * release any temporary registers used in an addressing mode.
 */
void ReleaseTempBrRegister(AMODE *ap)
{
    int number;

	if (ap==NULL) {
		printf("DIAG - NULL pointer in ReleaseTempBRegister\r\n");
		return;
	}

	validatebr(ap);
    switch (ap->mode) {
	case am_ind:
	case am_indx:
	case am_ainc:
	case am_adec:
	case am_reg:
	case am_breg:
common:
		if (ap->preg >= 5 && ap->preg <= 8) {
			if (breg_in_use[ap->preg]==-1)
				return;
			if (next_breg-- <= 5)
				next_breg = 8;
			number = breg_in_use[ap->preg];
			breg_in_use[ap->preg] = -1;
			break;
		}
		return;
    case am_indx2:
	case am_indx3:
		if (ap->sreg >= 5 && ap->sreg <= 8) {
			if (breg_in_use[ap->sreg]==-1)
				return;
			if (next_reg-- <= 5)
				next_reg = 8;
			number = breg_in_use[ap->sreg];
			breg_in_use[ap->sreg] = -1;
			break;
		}
		goto common;
    default:
		return;
    }
 //   /* some consistency checks */
	//if (number != ap->deep) {
	//	printf("number %d ap->deep %d\r\n", number, ap->deep);
	//	//fatal("ReleaseTempRegister()/1");
	//}
	if (breg_alloc_ptr-- == 0)
		fatal("ReleaseTempBRegister(): no registers are allocated");
  //  if (reg_alloc_ptr != number)
		//fatal("ReleaseTempRegister()/3");
    if (breg_alloc[number].f.isPushed == 'T')
		fatal("ReleaseTempBRegister(): register on stack");
}

// The following is used to save temporary registers across function calls.
// Save the list of allocated registers and registers in use.
// Go through the allocated register list and generate a push instruction to
// put the register on the stack if it isn't already on the stack.

int TempInvalidate()
{
    int i;
	int sp;

	sp = 0;
	TRACE(printf("TempInvalidate()\r\n");)
	save_reg_alloc_ptr = reg_alloc_ptr;
	memcpy(save_reg_alloc, reg_alloc, sizeof(save_reg_alloc));
	memcpy(save_reg_in_use, reg_in_use, sizeof(save_reg_in_use));
	for (i = 0; i < reg_alloc_ptr; i++) {
        if (reg_in_use[reg_alloc[i].reg] != -1) {
    		if (reg_alloc[i].f.isPushed == 'F') {
    			GenerateTempRegPush(reg_alloc[i].reg, reg_alloc[i].mode, i);
    			stacked_regs[sp].reg = reg_alloc[i].reg;
    			stacked_regs[sp].mode = reg_alloc[i].mode;
    			stacked_regs[sp].f.allocnum = i;
    			sp++;
    			// mark the register void
    			reg_in_use[reg_alloc[i].reg] = -1;
    		}
        }
	}
	return sp;
}

// Pop back any temporary registers that were pushed before the function call.
// Restore the allocated and in use register lists.

void TempRevalidate(int sp)
{
	int nn;

	for (nn = sp-1; nn >= 0; nn--)
		GenerateTempRegPop(stacked_regs[nn].reg, stacked_regs[nn].mode, stacked_regs[nn].f.allocnum);
	reg_alloc_ptr = save_reg_alloc_ptr;
	memcpy(reg_alloc, save_reg_alloc, sizeof(reg_alloc));
	memcpy(reg_in_use, save_reg_in_use, sizeof(reg_in_use));
}

/*
void initRegStack()
{
	for (rsp=0; rsp < 8; rsp=rsp+1)
		regstack[rsp] = tmpregs[rsp];
	for (brsp = 0; brsp < 6; brsp++)
		bregstack[brsp] = tmpbregs[brsp];
	rsp = 0;
	brsp = 0;
}

void ReleaseTempRegister(AMODE *ap)
{
	if (ap==NULL) {
		printf("DIAG - NULL pointer in ReleaseTempRegister\r\n");
		return;
	}
	if( ap->mode == am_immed || ap->mode == am_direct )
        return;         // no registers used
	if (ap->mode == am_breg || ap->mode==am_brind) {
		if (ap->preg < 9 && ap->preg >= 3)
			PushOnBrstk(ap->preg);
		return;
	}
	if(ap->preg < 11 && ap->preg >= 3)
		PushOnRstk(ap->preg);
}
*/
void ReleaseTempReg(AMODE *ap)
{
     if (ap->mode==am_fpreg)
         ReleaseTempFPRegister(ap);
     else
         ReleaseTempRegister(ap);
}

