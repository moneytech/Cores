// ============================================================================
//        __
//   \\__/ o\    (C) 2019-2020  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
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
// Types
`ifndef TYPES_H
`define TYPES_H		1
//`include ".\Gambit-config.sv"

typedef struct packed
{
logic [1:0] fl;
logic [5:0] opcode;
logic [3:0] tgt;
logic [3:0] src1;
logic [3:0] src2;
logic [3:0] cnst;
} MicroOp;

typedef logic [7:0] MicroOpPtr;

typedef logic [`ABITS] Address;
typedef logic [7:0] ASID;
typedef logic [51:0] Data;
typedef logic [`QBITS] Qid;			// Issue queue id
typedef logic [`RBITS] Rid;			// Reorder buffer id
typedef logic [6:0] RegTag;			// Register tag
typedef logic [7:0] ExcCode;		// Exception code
typedef logic [`SNBITS] Seqnum;	// Sequence number
// Rather than having a number represent a register like the RegTag type, this
// type represents a register with a bit position in a vector.
typedef logic [`AREGS-1:0] RegTagBitmap;

typedef struct packed
{
	ASID asid;
	Address adr;
} AddressWithASID;

typedef enum bit[2:0] {
	BC_NULL,
	BC_ICACHE,
	BC_WRITEBUF,
	BC_DCACHE0,
	BC_DCACHE1,
	BC_UNCDATA
} BusChannel;

// Different Instruction Formats

typedef struct packed
{
	logic [44:0] payload;
	logic [6:0] opcode;
} Gen_Instruction;

typedef struct packed
{
	logic [25:0] pad;
	logic one;
	logic [7:0] imm8;
	logic [4:0] Ra;
	logic [4:0] Rt;
	logic [6:0] opcode;
} RI8_Instruction;

typedef struct packed
{
	logic [25:0] pad;
	logic zero;
	logic [2:0] padr;
	logic [4:0] Rb;
	logic [4:0] Ra;
	logic [4:0] Rt;
	logic [6:0] opcode;
} RR_Instruction;

typedef struct packed
{
	logic [12:0] pad13;
	logic [21:0] imm22;
	logic [4:0] Ra;
	logic [4:0] Rt;
	logic [6:0] opcode;
} RI22_Instruction;

typedef struct packed
{
	logic [34:0] imm35;
	logic [4:0] Ra;
	logic [4:0] Rt;
	logic [6:0] opcode;
} RI35_Instruction;

typedef struct packed
{
	logic [4:0] pad5;
	logic [29:0] imm30;
	logic [4:0] Ra;
	logic [4:0] Rt;
	logic [6:0] opcode;
} RIS_Instruction;

typedef struct packed
{
	logic [25:0] pad25;
	logic [11:0] disp;
	logic [2:0] cr;
	logic [1:0] pred;
	logic [1:0] exop;
	logic [6:0] opcode;
} Branch_Instruction;

typedef struct packed
{ 
	logic [12:0] pad13;
	logic [2:0] op;
	logic [2:0] ol;
	logic [3:0] pad4;
	logic [11:0] regno;
	logic [4:0] Ra;
	logic [4:0] Rt;
	logic [6:0] opcode;
} CSR_Instruction;

typedef struct packed
{
	logic [42:0] addr;
	logic [1:0] lk;
	logic [6:0] opcode;
} Jal_Instruction;

typedef struct packed
{
	logic [38:0] pad39;
	logic [3:0] Ra;
	logic [1:0] lk;
	logic [6:0] opcode;
} Jalrn_Instruction;

typedef struct packed
{
	logic [38:0] pad39;
	logic [1:0] pad2;
	logic [1:0] lk;
	logic [1:0] exop;
	logic [6:0] opcode;
} Ret_Instruction;

typedef struct packed
{
	logic [38:0] pad39;
	logic [3:0] sigmsk;
	logic [1:0] exop;
	logic [6:0] opcode;
} Wai_Instruction;

typedef struct packed
{
	logic [38:0] pad39;
	logic [3:0] cnst;
	logic [1:0] exop;
	logic [6:0] opcode;
} Stp_Instruction;

typedef struct packed
{
	logic [12:0] pad13;
	logic [5:0] pad6;
	logic [3:0] imask;
	logic [2:0] tgt;
	logic [12:0] pl;
	logic pad1;
	logic [4:0] Ra;
	logic [6:0] opcode;
} Rex_Instruction;

typedef struct packed
{
	logic [25:0] pad26;
	logic zero;
	logic [2:0] pad3;
	logic [2:0] dcmd;
	logic [1:0] icmd;
	logic [4:0] Ra;
	logic [4:0] Rt;
	logic [6:0] opcode;
} Cache_Instruction;

typedef struct packed
{
	logic [51:0] bits;
} RAW_Instruction;

typedef union packed
{
	logic [51:0] raw;
	Gen_Instruction gen;
	RR_Instruction rr;
	RI8_Instruction ri8;
	RI22_Instruction ri22;
	RI35_Instruction ri35;
	RIS_Instruction ris;
	Branch_Instruction br;
	Jal_Instruction jal;
	Jalrn_Instruction jalrn;
	Ret_Instruction ret;
	Wai_Instruction wai;
	Stp_Instruction stp;
	Rex_Instruction rex;
	CSR_Instruction csr;
	Cache_Instruction cache;
} Instruction;

typedef struct packed
{
	logic [`IQ_ENTRIES-1:0] v;
	logic [`IQ_ENTRIES-1:0] queued;
	logic [`IQ_ENTRIES-1:0] out;
	logic [`IQ_ENTRIES-1:0] agen;
	logic [`IQ_ENTRIES-1:0] mem;
	logic [`IQ_ENTRIES-1:0] done;
	logic [`IQ_ENTRIES-1:0] cmt;
} IQState;

typedef struct packed
{
	IQState iqs;
	Address [`IQ_ENTRIES-1:0 ] predicted_pc;
} IQ;

// Re-order buffer entry
typedef struct packed
{
	Qid id;			// Link to issue queue
	Address pc;
	Instruction instr;
	ExcCode exc;
	Address ma;
	Data res;
	RegTag tgt;
	logic rfw;
	Data argA;
} RobEntry;

typedef struct packed
{
	logic [`RENTRIES-1:0] v;
	logic [`RENTRIES-1:0] cmt;
} RobState;

typedef struct packed
{
	RobEntry [`RENTRIES-1:0] robEntries;
	RobState rs;
} Rob;

/*
class Rob;
	integer n, i;
	RobEntry robEntries [0:`RENTRIES-1];

	task reset;
	begin
    for (n = 0; n < `RENTRIES; n = n + 1) begin
    	robEntries[n].state <= RS_INVALID;
    	robEntries[n].pc <= 1'd0;
//    	rob_instr[n] <= `UO_NOP;
    	robEntries[n].ma <= 1'd0;
    	robEntries[n].res <= 1'd0;
    	robEntries[n].tgt <= 1'd0;
    end
  end
 	endtask

	function [`RENTRIES-1:0] GetV;
		for (n = 0; n < `RENTRIES; n = n + 1)
			GetV[n] = robEntries[n].state != RS_INVALID;
	endfunction
	function RobQState [0:`RENTRIES-1] GetState;
		for (n = 0; n < `RENTRIES; n = n + 1)
			GetState[n] = robEntries[n].state;
	endfunction


	task displayEntry;
	input integer i;
	input Rid head;
	input Rid tail;
	begin
		$display("%c%c %d(%d): %c %h %d %h #",
		 (i[`RBITS]==head)?"C":".",
		 (i[`RBITS]==tail)?"Q":".",
		  i[`RBITS],
		  robEntries[i].id,
		  robEntries[i].state==RS_INVALID ? "-" :
		  robEntries[i].state==RS_ASSIGNED ? "A"  :
		  robEntries[i].state==RS_CMT ? "C"  : "D",
		  robEntries[i].exc,
		  robEntries[i].tgt,
		  robEntries[i].res
		);
	end
	endtask

	task display;
	input Rid head;
	input Rid tail;
	begin
		$display ("------------- Reorder Buffer ------------");
		for (i = 0; i < `RENTRIES; i = i + 1)
			displayEntry(i, head, tail);
	end
	endtask

endclass
*/
`endif
