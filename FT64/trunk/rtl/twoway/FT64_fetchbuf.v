// ============================================================================
//        __
//   \\__/ o\    (C) 2017-2018  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	FT64_fetchbuf.v
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
`include "FT64_defines.vh"

// FETCH
//
// fetch exactly two instructions from memory into the fetch buffer
// unless either one of the buffers is still full, in which case we
// do nothing (kinda like alpha approach)
// Like to turn this into an independent module at some point.
//
module FT64_fetchbuf(rst, clk,
	regLR,
    insn0, insn1, phit, 
    branchmiss, misspc, predict_taken0, predict_taken1,
    predict_takenA, predict_takenB, predict_takenC, predict_takenD,
    queued1, queued2, queuedNop,
    pc0, pc1, fetchbuf, fetchbufA_v, fetchbufB_v, fetchbufC_v, fetchbufD_v,
    fetchbufA_instr, fetchbufA_pc,
    fetchbufB_instr, fetchbufB_pc,
    fetchbufC_instr, fetchbufC_pc,
    fetchbufD_instr, fetchbufD_pc,
    fetchbuf0_instr, fetchbuf1_instr,
    fetchbuf0_pc, fetchbuf1_pc,
    fetchbuf0_v, fetchbuf1_v,
    codebuf0, codebuf1,
    btgtA, btgtB, btgtC, btgtD,
    nop_fetchbuf,
    take_branch0, take_branch1
);
parameter RSTPC = 32'hFFFC0100;
parameter TRUE = 1'b1;
parameter FALSE = 1'b0;
input rst;
input clk;
input [4:0] regLR;
input [31:0] insn0;
input [31:0] insn1;
input phit;
input branchmiss;
input [31:0] misspc;
output predict_taken0;
output predict_taken1;
input predict_takenA;
input predict_takenB;
input predict_takenC;
input predict_takenD;
input queued1;
input queued2;
input queuedNop;
output reg [31:0] pc0;
output reg [31:0] pc1;
output reg fetchbuf;
output reg fetchbufA_v;
output reg fetchbufB_v;
output reg fetchbufC_v;
output reg fetchbufD_v;
output reg [31:0] fetchbufA_instr;
output reg [31:0] fetchbufB_instr;
output reg [31:0] fetchbufC_instr;
output reg [31:0] fetchbufD_instr;
output reg [31:0] fetchbufA_pc;
output reg [31:0] fetchbufB_pc;
output reg [31:0] fetchbufC_pc;
output reg [31:0] fetchbufD_pc;
output [31:0] fetchbuf0_instr;
output [31:0] fetchbuf1_instr;
output [31:0] fetchbuf0_pc;
output [31:0] fetchbuf1_pc;
output fetchbuf0_v;
output fetchbuf1_v;
input [31:0] codebuf0;
input [31:0] codebuf1;
input [31:0] btgtA;
input [31:0] btgtB;
input [31:0] btgtC;
input [31:0] btgtD;
input [3:0] nop_fetchbuf;
output take_branch0;
output take_branch1;

integer n;

//`include "FT64_decode.vh"

function IsBranch;
input [31:0] isn;
casex(isn[`INSTRUCTION_OP])
`Bcc:   IsBranch = TRUE;
`BccR:  IsBranch = TRUE;
`BBc:   IsBranch = TRUE;
`BEQI:  IsBranch = TRUE;
default: IsBranch = FALSE;
endcase
endfunction

function IsJmp;
input [31:0] isn;
IsJmp = isn[`INSTRUCTION_OP]==`JMP;
endfunction

function IsCall;
input [31:0] isn;
IsCall = isn[`INSTRUCTION_OP]==`CALL;
endfunction

function IsRet;
input [31:0] isn;
IsRet = isn[`INSTRUCTION_OP]==`RET;
endfunction

function IsRTI;
input [31:0] isn;
IsRTI = isn[`INSTRUCTION_OP]==`RR && isn[`INSTRUCTION_S2]==`RTI;
endfunction

reg [31:0] ras [0:15];
reg [3:0] rasp;
wire [31:0] retpc = ras[rasp];

reg did_branchback0;
reg did_branchback1;

assign predict_taken0 = (fetchbuf==1'b0) ? predict_takenA : predict_takenC;
assign predict_taken1 = (fetchbuf==1'b0) ? predict_takenB : predict_takenD;

wire [31:0] branch_pcA = IsRet(fetchbufA_instr) ? retpc :
                         IsJmp(fetchbufA_instr) | IsCall(fetchbufA_instr) ? {fetchbufA_pc[31:28],fetchbufA_instr[31:6],2'b00} :
                         ((IsRTI(fetchbufA_instr) || fetchbufA_instr[`INSTRUCTION_OP]==`BccR || fetchbufA_instr[`INSTRUCTION_OP]==`BRK ||
                         fetchbufA_instr[`INSTRUCTION_OP]==`JAL) ? btgtA : 
                         fetchbufA_pc + {{19{fetchbufA_instr[`INSTRUCTION_SB]}},fetchbufA_instr[31:22],fetchbufA_instr[0],2'b00} + 64'd4);
wire [31:0] branch_pcB = IsRet(fetchbufB_instr) ? retpc :
                         IsJmp(fetchbufB_instr) | IsCall(fetchbufB_instr) ? {fetchbufB_pc[31:28],fetchbufB_instr[31:6],2'b00} :
                         ((IsRTI(fetchbufB_instr) || fetchbufB_instr[`INSTRUCTION_OP]==`BccR || fetchbufB_instr[`INSTRUCTION_OP]==`BRK ||
                         fetchbufB_instr[`INSTRUCTION_OP]==`JAL) ? btgtB : 
                         fetchbufB_pc + {{19{fetchbufB_instr[`INSTRUCTION_SB]}},fetchbufB_instr[31:22],fetchbufB_instr[0],2'b00} + 64'd4);
wire [31:0] branch_pcC = IsRet(fetchbufC_instr) ? retpc :
                         IsJmp(fetchbufC_instr) | IsCall(fetchbufC_instr) ? {fetchbufC_pc[31:28],fetchbufC_instr[31:6],2'b00} :
                         ((IsRTI(fetchbufC_instr) || fetchbufC_instr[`INSTRUCTION_OP]==`BccR || fetchbufC_instr[`INSTRUCTION_OP]==`BRK ||
                         fetchbufC_instr[`INSTRUCTION_OP]==`JAL) ? btgtC : 
                         fetchbufC_pc + {{19{fetchbufC_instr[`INSTRUCTION_SB]}},fetchbufC_instr[31:22],fetchbufC_instr[0],2'b00} + 64'd4);
wire [31:0] branch_pcD = IsRet(fetchbufD_instr) ? retpc :
                         IsJmp(fetchbufD_instr) | IsCall(fetchbufD_instr) ? {fetchbufD_pc[31:28],fetchbufD_instr[31:6],2'b00} : 
                         ((IsRTI(fetchbufD_instr) || fetchbufD_instr[`INSTRUCTION_OP]==`BccR ||fetchbufD_instr[`INSTRUCTION_OP]==`BRK ||
                         fetchbufD_instr[`INSTRUCTION_OP]==`JAL) ? btgtD : 
                         fetchbufD_pc + {{19{fetchbufD_instr[`INSTRUCTION_SB]}},fetchbufD_instr[31:22],fetchbufD_instr[0],2'b00} + 64'd4);
                         
wire take_branchA = ({fetchbufA_v, IsBranch(fetchbufA_instr), predict_takenA}  == {`VAL, `TRUE, `TRUE}) ||
                        ((IsRet(fetchbufA_instr)|IsJmp(fetchbufA_instr)|IsCall(fetchbufA_instr)|
                        IsRTI(fetchbufA_instr)|| fetchbufA_instr[`INSTRUCTION_OP]==`BRK || fetchbufA_instr[`INSTRUCTION_OP]==`JAL) &&
                        fetchbufA_v);
wire take_branchB = ({fetchbufB_v, IsBranch(fetchbufB_instr), predict_takenB}  == {`VAL, `TRUE, `TRUE}) ||
                        ((IsRet(fetchbufB_instr)|IsJmp(fetchbufB_instr)|IsCall(fetchbufB_instr) ||
                        IsRTI(fetchbufB_instr)|| fetchbufB_instr[`INSTRUCTION_OP]==`BRK || fetchbufB_instr[`INSTRUCTION_OP]==`JAL) &&
                        fetchbufB_v);
wire take_branchC = ({fetchbufC_v, IsBranch(fetchbufC_instr), predict_takenC}  == {`VAL, `TRUE, `TRUE}) ||
                        ((IsRet(fetchbufC_instr)|IsJmp(fetchbufC_instr)|IsCall(fetchbufC_instr) ||
                        IsRTI(fetchbufC_instr)|| fetchbufC_instr[`INSTRUCTION_OP]==`BRK || fetchbufC_instr[`INSTRUCTION_OP]==`JAL) &&
                        fetchbufC_v);
wire take_branchD = ({fetchbufD_v, IsBranch(fetchbufD_instr), predict_takenD}  == {`VAL, `TRUE, `TRUE}) ||
                        ((IsRet(fetchbufD_instr)|IsJmp(fetchbufD_instr)|IsCall(fetchbufD_instr) ||
                        IsRTI(fetchbufD_instr)|| fetchbufD_instr[`INSTRUCTION_OP]==`BRK || fetchbufD_instr[`INSTRUCTION_OP]==`JAL) &&
                        fetchbufD_v);

assign take_branch0 = fetchbuf==1'b0 ? take_branchA : take_branchC;
assign take_branch1 = fetchbuf==1'b0 ? take_branchB : take_branchD;
wire take_branch = take_branch0 || take_branch1;

// Return address stack predictor is updated during the fetch stage on the 
// assumption that previous flow controls (branches) predicted correctly.
// Otherwise many small routines wouldn't predict the return address
// correctly because they hit the RET before the CALL reaches the 
// commit stage.
always @(posedge clk)
if (rst) begin
    for (n = 0; n < 16; n = n + 1)
         ras[n] <= RSTPC;
     rasp <= 4'd0;
end
else begin
	if (fetchbuf0_v && fetchbuf1_v && (queued1 || queued2)) begin
        case(fetchbuf0_instr[`INSTRUCTION_OP])
        `JAL:
        	// JAL LR,xxxx	assume call
        	if (fetchbuf0_instr[`INSTRUCTION_RB]==regLR) begin
                 ras[((rasp-6'd1)&15)] <= fetchbuf0_pc + 32'd4;
                 rasp <= rasp - 4'd1;
        	end
        	// JAL r0,[r29]	assume a ret
        	else if (fetchbuf0_instr[`INSTRUCTION_RB]==5'd00 &&
        			 fetchbuf0_instr[`INSTRUCTION_RA]==regLR) begin
        		rasp <= rasp + 4'd1;
        	end
        `CALL:
            begin
                 ras[((rasp-6'd1)&15)] <= fetchbuf0_pc + 32'd4;
                 rasp <= rasp - 4'd1;
            end
        `RET:    rasp <= rasp + 4'd1;
        default:	;
        endcase
	end
    else if (fetchbuf1_v && queued1)
        case(fetchbuf1_instr[`INSTRUCTION_OP])
        `JAL:
        	if (fetchbuf1_instr[`INSTRUCTION_RB]==regLR) begin
                 ras[((rasp-6'd1)&15)] <= fetchbuf1_pc + 32'd4;
                 rasp <= rasp - 4'd1;
        	end
        	else if (fetchbuf1_instr[`INSTRUCTION_RB]==5'd00 &&
        			 fetchbuf1_instr[`INSTRUCTION_RA]==regLR) begin
        		rasp <= rasp + 4'd1;
        	end
        `CALL:
            begin
                 ras[((rasp-6'd1)&15)] <= fetchbuf1_pc + 32'd4;
                 rasp <= rasp - 4'd1;
            end
        `RET:    rasp <= rasp + 4'd1;
        default:	;
        endcase
    else if (fetchbuf0_v && queued1)
        case(fetchbuf0_instr[`INSTRUCTION_OP])
        `JAL:
        	if (fetchbuf0_instr[`INSTRUCTION_RB]==regLR) begin
                 ras[((rasp-6'd1)&15)] <= fetchbuf0_pc + 32'd4;
                 rasp <= rasp - 4'd1;
        	end
        	else if (fetchbuf0_instr[`INSTRUCTION_RB]==5'd00 &&
        			 fetchbuf0_instr[`INSTRUCTION_RA]==regLR) begin
        		rasp <= rasp + 4'd1;
        	end
        `CALL:
            begin
                 ras[((rasp-6'd1)&15)] <= fetchbuf0_pc + 32'd4;
                 rasp <= rasp - 4'd1;
            end
        `RET:    rasp <= rasp + 4'd1;
        default:	;
        endcase
end

always @(posedge clk)
if (rst) begin
	 pc0 <= RSTPC;
     pc1 <= RSTPC + 32'd4;
     fetchbufA_v <= 0;
     fetchbufB_v <= 0;
     fetchbufC_v <= 0;
     fetchbufD_v <= 0;
     fetchbuf <= 0;
end
else begin

	 did_branchback0 <= take_branch0;
	 did_branchback1 <= take_branch1;

	if (branchmiss) begin
	     pc0 <= misspc;
	     pc1 <= misspc + 32'd4;
	     fetchbuf <= 1'b0;
	     fetchbufA_v <= `INV;
	     fetchbufB_v <= `INV;
	     fetchbufC_v <= `INV;
	     fetchbufD_v <= `INV;
	     $display("********************");
	     $display("********************");
	     $display("********************");
	     $display("Branch miss");
	     $display("misspc=%h", misspc);
	     $display("********************");
	     $display("********************");
	     $display("********************");
	end
	// Some of the testing for valid branch conditions has been removed. In real
	// hardware it isn't needed, and just increases the size of the core. It's
	// assumed that the hardware is working.
	// The risk is an error will occur during simulation and go missed.
	else if (take_branch) begin

	    // update the fetchbuf valid bits as well as fetchbuf itself
	    // ... this must be based on which things are backwards branches, how many things
	    // will get enqueued (0, 1, or 2), and how old the instructions are
	    if (fetchbuf == 1'b0) case ({fetchbufA_v, fetchbufB_v, fetchbufC_v, fetchbufD_v})

		4'b0000	: ;	// do nothing
//		4'b0001	: panic <= `PANIC_INVALIDFBSTATE;
//		4'b0010	: panic <= `PANIC_INVALIDFBSTATE;
//		4'b0011	: panic <= `PANIC_INVALIDFBSTATE;	// this looks like it might be screwy fetchbuf logic

		// because the first instruction has been enqueued, 
		// we must have noted this in the previous cycle.
		// therefore, pc0 and pc1 have to have been set appropriately ... so do a regular fetch
		// this looks like the following:
		//   cycle 0 - fetched a INSTR+BEQ, with fbB holding a branchback
		//   cycle 1 - enqueued fbA, stomped on fbB, stalled fetch + updated pc0/pc1
		//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufB_v appropriately
		4'b0100 :
		    begin
			    FetchCD();
			     fetchbufB_v <= !(queued1|queuedNop);	// if it can be queued, it will
			     fetchbuf <= fetchbuf + (queued1|queuedNop);
			end

//		4'b0101	: panic <= `PANIC_INVALIDFBSTATE;
//		4'b0110	: panic <= `PANIC_INVALIDFBSTATE;

		// this looks like the following:
		//   cycle 0 - fetched an INSTR+BEQ, with fbB holding a branchback
		//   cycle 1 - enqueued fbA, but not fbB, recognized branchback in fbB, stalled fetch + updated pc0/pc1
		//   cycle 2 - still could not enqueue fbB, but fetched from backwards target
		//   cycle 3 - where we are now ... update fetchbufB_v appropriately
		//
		// however -- if there are backwards branches in the latter two slots, it is more complex.
		// simple solution: leave it alone and wait until we are through with the first two slots.
		4'b0111 :
			begin
			     fetchbufB_v <= !(queued1|queuedNop);	// if it can be queued, it will
			     fetchbuf <= fetchbuf + (queued1|queuedNop);
			end

		// this looks like the following:
		//   cycle 0 - fetched a BEQ+INSTR, with fbA holding a branchback
		//   cycle 1 - stomped on fbB, but could not enqueue fbA, stalled fetch + updated pc0/pc1
		//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufA_v appropriately
		4'b1000 :
			begin
			    FetchCD();
			     fetchbufA_v <= !(queued1|queuedNop);	// if it can be queued, it will
			     fetchbuf <= fetchbuf + (queued1|queuedNop);
			end

//		4'b1001	: panic <= `PANIC_INVALIDFBSTATE;
//		4'b1010	: panic <= `PANIC_INVALIDFBSTATE;

		// this looks like the following:
		//   cycle 0 - fetched a BEQ+INSTR, with fbA holding a branchback
		//   cycle 1 - stomped on fbB, but could not enqueue fbA, stalled fetch + updated pc0/pc1
		//   cycle 2 - still could not enqueue fbA, but fetched from backwards target
		//   cycle 3 - where we are now ... set fetchbufA_v appropriately
		//
		// however -- if there are backwards branches in the latter two slots, it is more complex.
		// simple solution: leave it alone and wait until we are through with the first two slots.
		4'b1011 :
			begin
			     fetchbufA_v <=!(queued1|queuedNop);	// if it can be queued, it will
			     fetchbuf <= fetchbuf + (queued1|queuedNop);
			end

		// if fbB has the branchback, can't immediately tell which of the following scenarios it is:
		//   cycle 0 - fetched a pair of instructions, one or both of which is a branchback
		//   cycle 1 - where we are now.  stomp, enqueue, and update pc0/pc1
		// or
		//   cycle 0 - fetched a INSTR+BEQ, with fbB holding a branchback
		//   cycle 1 - could not enqueue fbA or fbB, stalled fetch + updated pc0/pc1
		//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufX_v appropriately
		// if fbA has the branchback, then it is scenario 1.
		// if fbB has it: if pc0 == fbB_pc, then it is the former scenario, else it is the latter
		4'b1100 : begin
			if (take_branchA) begin
			    // has to be first scenario
			     pc0 <= branch_pcA;
			     pc1 <= branch_pcA + 4;
			     fetchbufA_v <= !(queued1|queuedNop);	// if it can be queued, it will
			     fetchbufB_v <= `INV;		// stomp on it
			    if ((queued1|queuedNop))  fetchbuf <= 1'b0;
			end
			else if (take_branchB) begin
			    if (did_branchback0) begin
			    FetchCD();
				 fetchbufA_v <= !(queued1|queuedNop);	// if it can be queued, it will
				 fetchbufB_v <= !(queued2|queuedNop);	// if it can be queued, it will
				 fetchbuf <= fetchbuf + (queued2|queuedNop);
			    end
			    else begin
				 pc0 <= branch_pcB;
				 pc1 <= branch_pcB + 4;
				 fetchbufA_v <= !(queued1|queuedNop);	// if it can be queued, it will
				 fetchbufB_v <= !(queued2|queuedNop);	// if it can be queued, it will
				if ((queued2|queuedNop))  fetchbuf <= 1'b0;
			    end
			end
//			else panic <= `PANIC_BRANCHBACK;
		    end

//		4'b1101	: panic <= `PANIC_INVALIDFBSTATE;
//		4'b1110	: panic <= `PANIC_INVALIDFBSTATE;

		// this looks like the following:
		//   cycle 0 - fetched an INSTR+BEQ, with fbB holding a branchback
		//   cycle 1 - enqueued neither fbA nor fbB, recognized branchback in fbB, stalled fetch + updated pc0/pc1
		//   cycle 2 - still could not enqueue fbB, but fetched from backwards target
		//   cycle 3 - where we are now ... update fetchbufX_v appropriately
		//
		// however -- if there are backwards branches in the latter two slots, it is more complex.
		// simple solution: leave it alone and wait until we are through with the first two slots.
		4'b1111 :
			begin
			     fetchbufA_v <= !(queued1|queuedNop);	// if it can be queued, it will
			     fetchbufB_v <= !(queued2|queuedNop);	// if it can be queued, it will
			     fetchbuf <= fetchbuf + (queued2|queuedNop);
			end
        default:    ;
	    endcase
	    else case ({fetchbufC_v, fetchbufD_v, fetchbufA_v, fetchbufB_v})

		4'b0000	: ; // do nothing
//		4'b0001	: panic <= `PANIC_INVALIDFBSTATE;
//		4'b0010	: panic <= `PANIC_INVALIDFBSTATE;
//		4'b0011	: panic <= `PANIC_INVALIDFBSTATE;	// this looks like it might be screwy fetchbuf logic

		// because the first instruction has been enqueued, 
		// we must have noted this in the previous cycle.
		// therefore, pc0 and pc1 have to have been set appropriately ... so do a regular fetch
		// this looks like the following:
		//   cycle 0 - fetched a INSTR+BEQ, with fbD holding a branchback
		//   cycle 1 - enqueued fbC, stomped on fbD, stalled fetch + updated pc0/pc1
		//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufB_v appropriately
		4'b0100 :
			begin
			    FetchAB();
			     fetchbufD_v <= !(queued1|queuedNop);	// if it can be queued, it will
			     fetchbuf <= fetchbuf + (queued1|queuedNop);
			end

//		4'b0101	: panic <= `PANIC_INVALIDFBSTATE;
//		4'b0110	: panic <= `PANIC_INVALIDFBSTATE;

		// this looks like the following:
		//   cycle 0 - fetched an INSTR+BEQ, with fbD holding a branchback
		//   cycle 1 - enqueued fbC, but not fbD, recognized branchback in fbD, stalled fetch + updated pc0/pc1
		//   cycle 2 - still could not enqueue fbD, but fetched from backwards target
		//   cycle 3 - where we are now ... update fetchbufD_v appropriately
		//
		// however -- if there are backwards branches in the latter two slots, it is more complex.
		// simple solution: leave it alone and wait until we are through with the first two slots.
		4'b0111 :
			begin
			     fetchbufD_v <= !(queued1|queuedNop);	// if it can be queued, it will
			     fetchbuf <= fetchbuf + (queued1|queuedNop);
			end

		// this looks like the following:
		//   cycle 0 - fetched a BEQ+INSTR, with fbC holding a branchback
		//   cycle 1 - stomped on fbD, but could not enqueue fbC, stalled fetch + updated pc0/pc1
		//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufC_v appropriately
		4'b1000 :
			begin
			    FetchAB();
			     fetchbufC_v <= !(queued1|queuedNop);	// if it can be queued, it will
			     fetchbuf <= fetchbuf + (queued1|queuedNop);
			end

//		4'b1001	: panic <= `PANIC_INVALIDFBSTATE;
//		4'b1010	: panic <= `PANIC_INVALIDFBSTATE;

		// this looks like the following:
		//   cycle 0 - fetched a BEQ+INSTR, with fbC holding a branchback
		//   cycle 1 - stomped on fbD, but could not enqueue fbC, stalled fetch + updated pc0/pc1
		//   cycle 2 - still could not enqueue fbC, but fetched from backwards target
		//   cycle 3 - where we are now ... set fetchbufC_v appropriately
		//
		// however -- if there are backwards branches in the latter two slots, it is more complex.
		// simple solution: leave it alone and wait until we are through with the first two slots.
		4'b1011 :
			begin
			     fetchbufC_v <= !(queued1|queuedNop);	// if it can be queued, it will
			     fetchbuf <= fetchbuf + (queued1|queuedNop);
			end

		// if fbD has the branchback, can't immediately tell which of the following scenarios it is:
		//   cycle 0 - fetched a pair of instructions, one or both of which is a branchback
		//   cycle 1 - where we are now.  stomp, enqueue, and update pc0/pc1
		// or
		//   cycle 0 - fetched a INSTR+BEQ, with fbD holding a branchback
		//   cycle 1 - could not enqueue fbC or fbD, stalled fetch + updated pc0/pc1
		//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufX_v appropriately
		// if fbC has the branchback, then it is scenario 1.
		// if fbD has it: if pc0 == fbB_pc, then it is the former scenario, else it is the latter
		4'b1100 : begin
			if (take_branchC) begin
			    // has to be first scenario
			     pc0 <= branch_pcC;
			     pc1 <= branch_pcC + 4;
			     fetchbufC_v <= !(queued1|queuedNop);	// if it can be queued, it will
			     fetchbufD_v <= `INV;		// stomp on it
			    if ((queued1|queuedNop))  fetchbuf <= 1'b0;
			end
			else if (take_branchD) begin
			    if (did_branchback1) begin
			    FetchAB();
				 fetchbufC_v <= !(queued1|queuedNop);	// if it can be queued, it will
				 fetchbufD_v <= !(queued2|queuedNop);	// if it can be queued, it will
				 fetchbuf <= fetchbuf + (queued2|queuedNop);
			    end
			    else begin
				 pc0 <= branch_pcD;
				 pc1 <= branch_pcD + 4;
				 fetchbufC_v <= !(queued1|queuedNop);	// if it can be queued, it will
				 fetchbufD_v <= !(queued2|queuedNop);	// if it can be queued, it will
				if ((queued2|queuedNop))  fetchbuf <= 1'b0;
			    end
			end
//			else panic <= `PANIC_BRANCHBACK;
		    end

//		4'b1101	: panic <= `PANIC_INVALIDFBSTATE;
//		4'b1110	: panic <= `PANIC_INVALIDFBSTATE;

		// this looks like the following:
		//   cycle 0 - fetched an INSTR+BEQ, with fbD holding a branchback
		//   cycle 1 - enqueued neither fbC nor fbD, recognized branchback in fbD, stalled fetch + updated pc0/pc1
		//   cycle 2 - still could not enqueue fbD, but fetched from backwards target
		//   cycle 3 - where we are now ... update fetchbufX_v appropriately
		//
		// however -- if there are backwards branches in the latter two slots, it is more complex.
		// simple solution: leave it alone and wait until we are through with the first two slots.
		4'b1111 :
			begin
			     fetchbufC_v <= !(queued1|queuedNop);	// if it can be queued, it will
			     fetchbufD_v <= !(queued2|queuedNop);	// if it can be queued, it will
			     fetchbuf <= fetchbuf + (queued2|queuedNop);
			end
	    default:   ;
	    endcase

	end // if branchback

	else begin	// there is no branchback in the system
	    //
	    // update fetchbufX_v and fetchbuf ... relatively simple, as
	    // there are no backwards branches in the mix
	    if (fetchbuf == 1'b0) case ({fetchbufA_v, fetchbufB_v, (queued1|queuedNop), (queued2|queuedNop)})
		4'b00_00 : ;	// do nothing
//		4'b00_01 : panic <= `PANIC_INVALIDIQSTATE;
		4'b00_10 : ;	// do nothing
		4'b00_11 : ;	// do nothing
		4'b01_00 : ;	// do nothing
//		4'b01_01 : panic <= `PANIC_INVALIDIQSTATE;

		4'b01_10,
		4'b01_11 : begin	// enqueue fbB and flip fetchbuf
			 fetchbufB_v <= `INV;
			 fetchbuf <= ~fetchbuf;
		    end

		4'b10_00 : ;	// do nothing
//		4'b10_01 : panic <= `PANIC_INVALIDIQSTATE;

		4'b10_10,
		4'b10_11 : begin	// enqueue fbA and flip fetchbuf
			 fetchbufA_v <= `INV;
			 fetchbuf <= ~fetchbuf;
		    end

		4'b11_00 : ;	// do nothing
//		4'b11_01 : panic <= `PANIC_INVALIDIQSTATE;

		4'b11_10 : begin	// enqueue fbA but leave fetchbuf
			 fetchbufA_v <= `INV;
		    end

		4'b11_11 : begin	// enqueue both and flip fetchbuf
			 fetchbufA_v <= `INV;
			 fetchbufB_v <= `INV;
			 fetchbuf <= ~fetchbuf;
		    end
		default:  ;
	    endcase
	    else case ({fetchbufC_v, fetchbufD_v, (queued1|queuedNop), (queued2|queuedNop)})
		4'b00_00 : ;	// do nothing
//		4'b00_01 : panic <= `PANIC_INVALIDIQSTATE;
		4'b00_10 : ;	// do nothing
		4'b00_11 : ;	// do nothing
		4'b01_00 : ;	// do nothing
//		4'b01_01 : panic <= `PANIC_INVALIDIQSTATE;

		4'b01_10,
		4'b01_11 : begin	// enqueue fbD and flip fetchbuf
			 fetchbufD_v <= `INV;
			 fetchbuf <= ~fetchbuf;
		    end

		4'b10_00 : ;	// do nothing
//		4'b10_01 : panic <= `PANIC_INVALIDIQSTATE;

		4'b10_10,
		4'b10_11 : begin	// enqueue fbC and flip fetchbuf
			 fetchbufC_v <= `INV;
			 fetchbuf <= ~fetchbuf;
		    end

		4'b11_00 : ;	// do nothing
//		4'b11_01 : panic <= `PANIC_INVALIDIQSTATE;

		4'b11_10 : begin	// enqueue fbC but leave fetchbuf
			 fetchbufC_v <= `INV;
		    end

		4'b11_11 : begin	// enqueue both and flip fetchbuf
			 fetchbufC_v <= `INV;
			 fetchbufD_v <= `INV;
			 fetchbuf <= ~fetchbuf;
		    end
		default:  ;
	    endcase
	    //
	    // get data iff the fetch buffers are empty
	    //
	    if (fetchbufA_v == `INV && fetchbufB_v == `INV) begin
	        FetchAB();
	        // fetchbuf steering logic correction
	        if (fetchbufC_v==`INV && fetchbufD_v==`INV && phit)
	             fetchbuf <= 1'b0;
	    end
	    else if (fetchbufC_v == `INV && fetchbufD_v == `INV)
		    FetchCD();
	end
    //
    // get data iff the fetch buffers are empty
    //
    if (fetchbufA_v == `INV && fetchbufB_v == `INV && fetchbufC_v==`INV && fetchbufD_v==`INV) begin
        FetchAB();
        fetchbuf <= 1'b0;
    end
	
	// The fetchbuffer is invalidated at the end of a vector instruction
	// queue.
	if (nop_fetchbuf[0])  fetchbufA_v <= `INV;
	if (nop_fetchbuf[1])  fetchbufB_v <= `INV;
	if (nop_fetchbuf[2])  fetchbufC_v <= `INV;
	if (nop_fetchbuf[3])  fetchbufD_v <= `INV;
end

assign fetchbuf0_instr = (fetchbuf == 1'b0) ? fetchbufA_instr : fetchbufC_instr;
assign fetchbuf0_v     = (fetchbuf == 1'b0) ? fetchbufA_v     : fetchbufC_v    ;
assign fetchbuf0_pc    = (fetchbuf == 1'b0) ? fetchbufA_pc    : fetchbufC_pc   ;
assign fetchbuf1_instr = (fetchbuf == 1'b0) ? fetchbufB_instr : fetchbufD_instr;
assign fetchbuf1_v     = (fetchbuf == 1'b0) ? fetchbufB_v     : fetchbufD_v    ;
assign fetchbuf1_pc    = (fetchbuf == 1'b0) ? fetchbufB_pc    : fetchbufD_pc   ;

task FetchAB;
begin
    if (insn0[`INSTRUCTION_OP]==`EXEC)
         fetchbufA_instr <= codebuf0;
    else
         fetchbufA_instr <= insn0;
     fetchbufA_v <= `VAL;
     fetchbufA_pc <= pc0;
    if (insn1[`INSTRUCTION_OP]==`EXEC)
         fetchbufB_instr <= codebuf1;
    else
         fetchbufB_instr <= insn1;
     fetchbufB_v <= `VAL;
     fetchbufB_pc <= pc1;
    if (phit) begin
     pc0 <= pc0 + 8;
     pc1 <= pc1 + 8;
    end
end
endtask

task FetchCD;
begin
    if (insn0[`INSTRUCTION_OP]==`EXEC)
         fetchbufC_instr <= codebuf0;
    else
         fetchbufC_instr <= insn0;
     fetchbufC_v <= `VAL;
     fetchbufC_pc <= pc0;
    if (insn1[`INSTRUCTION_OP]==`EXEC)
         fetchbufD_instr <= codebuf1;
    else
         fetchbufD_instr <= insn1;
     fetchbufD_v <= `VAL;
     fetchbufD_pc <= pc1;
    if (phit) begin
     pc0 <= pc0 + 8;
     pc1 <= pc1 + 8;
    end
end
endtask

endmodule
