// ============================================================================
//        __
//   \\__/ o\    (C) 2012-2016  Robert Finch, Stratford
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
#include "stdafx.h"

/*
 *	68000 C compiler
 *
 *	Copyright 1984, 1985, 1986 Matthew Brandt.
 *  all commercial rights reserved.
 *
 *	This compiler is intended as an instructive tool for personal use. Any
 *	use for profit without the written consent of the author is prohibited.
 *
 *	This compiler may be distributed freely for non-commercial use as long
 *	as this notice stays intact. Please forward any enhancements or questions
 *	to:
 *
 *		Matthew Brandt
 *		Box 920337
 *		Norcross, Ga 30092
 */

extern TABLE tagtable;
extern TYP *head;
extern TYP stdconst;
extern int bit_next;
extern int bit_offset;
extern int bit_width;
extern int parsingParameterList;
extern int funcdecl;
extern int isStructDecl;

int16_t typeno = bt_last;

static void ParseStructMembers(SYM *sym, TYP *tp, int ztype);

int ParseStructDeclaration(int ztype)
{
    SYM     *sp;
    TYP     *tp;
	int gblflag;
	int ret;
	int psd;
	ENODE nd;
	ENODE *pnd = &nd;

	psd = isStructDecl;
	isStructDecl++;
	ret = 0;
	bit_offset = 0;
	bit_next = 0;
	bit_width = -1;
    if(lastst == id) {
        if((sp = search(lastid,&tagtable)) == NULL) {
			// If we encounted an unknown struct in a parameter list, we want
			// it to go into the global memory pool, not a local one.
			if (parsingParameterList) {
				gblflag = global_flag;
				global_flag++;
	            sp = allocSYM();
				sp->name = litlate(lastid);
				global_flag = gblflag;
			}
			else {
	            sp = allocSYM();
				sp->name = litlate(lastid);
			}
            sp->tp = allocTYP();
            sp->tp->type = (e_bt)ztype;
			sp->tp->typeno = typeno++;
            sp->tp->lst.head = 0;
            sp->storage_class = sc_type;
            sp->tp->sname = sp->name;
            sp->tp->alignment = 0;
            NextToken();

			if (lastst == kw_align) {
                NextToken();
                sp->tp->alignment = GetIntegerExpression(&pnd);
            }

			// Could be a forward structure declaration like:
			// struct buf;
			if (lastst==semicolon) {
				ret = 1;
                insert(sp,&tagtable);
                NextToken();
			}
			// Defining a pointer to an unknown struct ?
			else if (lastst == star) {
                insert(sp,&tagtable);
			}
            else if(lastst != begin)
                error(ERR_INCOMPLETE);
            else    {
                insert(sp,&tagtable);
                NextToken();
                ParseStructMembers(sp, sp->tp,ztype);
                }
        }
		else {
            NextToken();
            if (lastst==kw_align) {
	            NextToken();
                sp->tp->alignment = GetIntegerExpression(&pnd);
            }
			if (lastst==begin) {
	            NextToken();
                ParseStructMembers(sp,sp->tp,ztype);
			}
		}
        head = sp->tp;
    }
    else {
        tp = allocTYP();
        tp->type = (e_bt)ztype;
        tp->sname = 0;
        tp->lst.head = 0;

        if (lastst==kw_align) {
            NextToken();
            tp->alignment = GetIntegerExpression(&pnd);
        }

        if( lastst != begin)
            error(ERR_INCOMPLETE);
        else {
			NextToken();
			ParseStructMembers(sp,tp,ztype);
        }
        head = tp;
    }
	isStructDecl = psd;
	return ret;
}

static void ParseStructMembers(SYM * sym, TYP *tp, int ztype)
{
	int slc;

    slc = 0;
    tp->val_flag = 1;
//	tp->val_flag = FALSE;
    while( lastst != end) {
        if(ztype == bt_struct || ztype==bt_class)
            slc += declare(sym,&(tp->lst),sc_member,slc,ztype);
        else
            slc = imax(slc,declare(sym,&tp->lst,sc_member,0,ztype));
    }
	bit_offset = 0;
	bit_next = 0;
	bit_width = -1;
    tp->size = tp->alignment ? tp->alignment : slc;
    NextToken();
}

