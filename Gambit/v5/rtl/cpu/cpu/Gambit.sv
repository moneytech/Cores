// ============================================================================
//        __
//   \\__/ o\    (C) 2019  Robert Finch, Waterloo
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
// 38961 62338
// 44403 71043
// 46190 73904
// 48453 77525
`include "..\inc\Gambit-config.sv"
`include "..\inc\Gambit-defines.sv"
`include "..\inc\Gambit-types.sv"

module Gambit(rst_i, clk_i, clk2x_i, clk4x_i, hartid_i, tm_clk_i, nmi_i, irq_i,
		bte_o, cti_o, bok_i, cyc_o, stb_o, ack_i, err_i, we_o, sel_o, adr_o, dat_o, dat_i,
    icl_o, exc_o);
parameter WID = 52;
input rst_i;
input clk_i;
input clk2x_i;
input clk4x_i;
input [51:0] hartid_i;
input tm_clk_i;
input nmi_i;
input [2:0] irq_i;
output reg [1:0] bte_o;
output reg [2:0] cti_o;
input bok_i;
output cyc_o;
output reg stb_o;
input ack_i;
input err_i;
output we_o;
output reg [7:0] sel_o;
output Address adr_o;
output reg [103:0] dat_o;
input [103:0] dat_i;
output icl_o;
output [7:0] exc_o;
parameter TM_CLKFREQ = 20000000;
parameter UOQ_ENTRIES = `UOQ_ENTRIES;
parameter IQ_ENTRIES = `IQ_ENTRIES;
parameter QSLOTS = `QSLOTS;
parameter FSLOTS = `FSLOTS;
parameter RENTRIES = `RENTRIES;
parameter RSLOTS = `RSLOTS;
parameter AREGS = 128;
parameter TRUE = 1'b1;
parameter FALSE = 1'b0;
parameter HIGH = 1'b1;
parameter LOW = 1'b0;
parameter VAL = 1'b1;
parameter INV = 1'b0;
parameter RSTIP = 52'hFFFFFFFFE0000;
parameter BRKIP = 52'hFFFFFFFFE0000;
parameter DEBUG = 1'b0;
parameter DBW = 16;
parameter ABW = 52;
parameter AMSB = ABW-1;
parameter RBIT = 5;
parameter WB_DEPTH = 7;

// Memory access sizes
parameter octa = 4'd0;
parameter byt = 4'd1;
parameter wyde = 4'd2;
parameter tbyt = 4'd3;
parameter tetra = 4'd4;
parameter ubyt = 4'd5;
parameter uwyde = 4'd6;
parameter utbyt = 4'd7;
parameter utetra = 4'd8;

//`include "..\Micro-op_Engine\Gambit-micro-program-parameters.sv"
`include "..\inc\Gambit-busStates.sv"

wire clk;
//BUFG uclkb1
//(
//	.I(clk_i),
//	.O(clk)
//);
assign clk = clk_i;

wire rdv_i;
wire wrv_i;
reg [AMSB:0] vadr;
reg cyc;
reg stb;
reg cyc_pending;	// An i-cache load is about to happen
reg we;

reg [31:0] rst_ctr;
reg [7:0] i;
integer n;
integer j, k;
integer row, col;
genvar g, h;

Data regs [0:31];
Data regsx [0:31];
Address lkregs [0:4];
Address lkregsx [0:4];
reg [15:0] crregs;
reg [15:0] crregsx;
reg [WID-1:0] msp, hsp, ssp;
reg [WID-1:0] mspx, hspx, sspx;

`ifdef SIM
initial begin
	for (n = 0; n < 32; n = n + 1) begin
		regsx[n] = 1'd0;
		regs[n] = 1'd0;
	end
	for (n = 0; n < 5; n = n + 1) begin
		lkregsx[n] = 1'd0;
		lkregs[n] = 1'd0;
	end
end
`endif
reg [15:0] sr;
reg sre;
reg [15:0] srx;
reg srex;

wire [AMSB:0] pc;
wire [AMSB:0] pcd;
reg [31:0] tick;
wire tick_roi = tick[`SNBITS] > 26'h3FFFFE0;

reg [WID-1:0] rfoa [0:QSLOTS-1];
reg [WID-1:0] rfob [0:QSLOTS-1];
reg [WID-1:0] rfot [0:QSLOTS-1];
reg [ 7:0] rfos [0:QSLOTS-1];

// Register read ports
reg [6:0] Rt [0:QSLOTS-1];
reg [6:0] Rb [0:QSLOTS-1];
reg [6:0] Ra [0:QSLOTS-1];


wire tlb_miss;
wire exv;

reg q1, q2, q1b, q1bx;	// number of macro instructions queued
reg qb;						// queue a brk instruction

reg [143:0] ic1_out;
reg [51:0] ic2_out;

reg  [3:0] panic;		// indexes the message structure
reg [127:0] message [0:15];	// indexed by panic

// - - - - - - - - - - - - - - - - - - - - - - -
// CSRs
// - - - - - - - - - - - - - - - - - - - - - - -
reg [51:0] cr0;
wire dce = cr0[30];
wire sple = cr0[35];

// status register
reg [51:0] status;
reg [14:0] im_stack;
reg [14:0] ol_stack;
reg [14:0] dl_stack;
reg [103:0] pl_stack;
wire [2:0] ol, dl;
wire [12:0] pl;
assign ol = ol_stack[2:0];
assign dl = dl_stack[2:0];
assign pl = pl_stack[12:0];

Address ipc [0:4];
reg [12:0] cause [0:7];
Address badaddr [0:7];
Instruction bad_instr [0:7];
reg [5:0] ld_time;
reg [79:0] wc_time;
reg [39:0] wc_time_secs;
reg [39:0] wc_time_frac;

reg [51:0] sema;	

// - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - -

reg excmiss;
Address excmisspc;

wire int_commit;

reg [103:0] xdati;

reg [31:0] uop_queued;
reg [31:0] ins_queued;
reg [31:0] ins_stomped;
reg [31:0] ins_committed;
reg [31:0] uop_stomped;
wire [31:0] uop_committed;
reg [31:0] ic_stalls;
reg [31:0] br_override;
reg [31:0] br_total;
reg [31:0] br_missed;

wire [2:0] queuedCnt;
wire [2:0] rqueuedCnt;
reg queuedNop;
reg [3:0] hi_amt;
reg [3:0] r_amt, r_amt2;

wire [2:0] iclen1;
reg [2:0] len1, len2, len1d, len2d;
Instruction insnx [0:1];

Qid tails [0:QSLOTS-1];
Qid heads [0:IQ_ENTRIES-1];
Rid rob_tails [0:RSLOTS-1];
Rid rob_heads [0:RENTRIES-1];
wire [FSLOTS-1:0] slotvd, pc_maskd, pc_mask;

// Micro instruction pointers.
reg [7:0] mip1, mip2;
wire nextBundle;

// Issue queue
reg [IQ_ENTRIES-1:0] iq_v = 1'd0;						// valid indicator (set from iq_state)
reg [IQ_ENTRIES-1:0] iq_done = 1'd0;
reg [IQ_ENTRIES-1:0] iq_out = 1'd0;
reg [IQ_ENTRIES-1:0] iq_agen = 1'd0;
QState iq_state [0:IQ_ENTRIES-1];
Seqnum iq_sn  [0:IQ_ENTRIES-1];		// sequence number
Address iq_pc [0:IQ_ENTRIES-1];	// program counter associated with instruction
reg [2:0] iq_len [0:IQ_ENTRIES-1];
reg [IQ_ENTRIES-1:0] iq_canex;
Address iq_ma [0:IQ_ENTRIES-1];		// memory address
Instruction iq_instr [0:IQ_ENTRIES-1];	// micro-op instruction
reg [1:0] iq_fl [0:IQ_ENTRIES-1];			// first or last indicators
reg [WID-1:0] iq_const [0:IQ_ENTRIES-1];
reg [IQ_ENTRIES-1:0] iq_hs;						// hardware (1) or software (0) interrupt
reg [IQ_ENTRIES-1:0] iq_alu = 1'h0;  	// alu type instruction
reg [IQ_ENTRIES-1:0] iq_alu0 = 1'h0;  	// alu0 type instruction
reg [IQ_ENTRIES-1:0] iq_sync = 1'd0;
reg [IQ_ENTRIES-1:0] iq_mem;	// touches memory: 1 if LW/SW
reg [2:0] iq_memsz [0:IQ_ENTRIES-1];
reg [IQ_ENTRIES-1:0] iq_wrap;
reg [IQ_ENTRIES-1:0] iq_load;	// is a memory load instruction
reg [IQ_ENTRIES-1:0] iq_store;	// is a memory store instruction
reg [22:0] iq_sel [0:IQ_ENTRIES-1];		// select lines, for memory overlap detect
reg [IQ_ENTRIES-1:0] iq_bt;						// branch taken
reg [IQ_ENTRIES-1:0] iq_pt;						// predicted taken branch
reg [IQ_ENTRIES-1:0] iq_fc;						// flow control instruction
reg [IQ_ENTRIES-1:0] iq_jmp;					// changes control flow: 1 if BEQ/JALR
reg [IQ_ENTRIES-1:0] iq_cmp;
reg [IQ_ENTRIES-1:0] iq_br;						// branch instruction
reg [IQ_ENTRIES-1:0] iq_takb;
reg [IQ_ENTRIES-1:0] iq_rfw;	// writes to register file
reg [IQ_ENTRIES-1:0] iq_sei;
reg [IQ_ENTRIES-1:0] iq_need_sr;
ExcCode iq_exc	[0:IQ_ENTRIES-1];	// only for branches ... indicates a HALT instruction
RegTag iq_tgt [0:IQ_ENTRIES-1];		// target register
reg [WID-1:0] iq_argA [0:IQ_ENTRIES-1];	// First argument
reg [WID-1:0] iq_argB [0:IQ_ENTRIES-1];	// Second argument
Rid iq_argA_s [0:IQ_ENTRIES-1];
Rid iq_argB_s [0:IQ_ENTRIES-1]; 
reg [IQ_ENTRIES-1:0] iq_argA_v;
reg [IQ_ENTRIES-1:0] iq_argB_v;
Rid iq_rid [0:IQ_ENTRIES-1];	// index of rob entry

// Re-order buffer
Rob rob;// = new();
Qid robIds [0:RENTRIES-1];

initial begin
	for (n = 0; n < RENTRIES; n = n + 1)
		robIds[n] = 1'd0;
end
always @*
	for (n = 0; n < RENTRIES; n = n + 1)
		robIds[n] = rob.robEntries[n].id;

function [`RENTRIES-1:0] GetV;
input dummy1;
	for (n = 0; n < `RENTRIES; n = n + 1)
		GetV[n] = rob.robEntries[n].state != RS_INVALID;
endfunction
function RobQState [0:`RENTRIES-1] GetState;
input dummy1;
	for (n = 0; n < `RENTRIES; n = n + 1)
		GetState[n] = rob.robEntries[n].state;
endfunction

// debugging
initial begin
for (n = 0; n < IQ_ENTRIES; n = n + 1)
	iq_argA_s[n] <= 1'd0;
	iq_argB_s[n] <= 1'd0;
end

reg [IQ_ENTRIES-1:0] iq_sr_source = {IQ_ENTRIES{1'b0}};
reg [IQ_ENTRIES-1:0] iq_source = {IQ_ENTRIES{1'b0}};
reg [IQ_ENTRIES-1:0] iq_source2 = {IQ_ENTRIES{1'b0}};
reg [IQ_ENTRIES-1:0] iq_imm;
reg [IQ_ENTRIES-1:0] iq_memready;
reg [IQ_ENTRIES-1:0] iq_memopsvalid;

reg [1:0] missued;
Qid last_issue0, last_issue1;
reg  [IQ_ENTRIES-1:0] iq_memissue;
reg [IQ_ENTRIES-1:0] iq_stomp;
reg [3:0] stompedOnRets;
reg [3:0] iq_fuid [0:IQ_ENTRIES-1];
reg  [IQ_ENTRIES-1:0] iq_alu0_issue;
reg  [IQ_ENTRIES-1:0] iq_alu1_issue;
wire [IQ_ENTRIES-1:0] iq_agen0_issue;
wire [IQ_ENTRIES-1:0] iq_agen1_issue;
reg  [IQ_ENTRIES-1:0] iq_id1issue;
reg  [IQ_ENTRIES-1:0] iq_id2issue;
reg  [IQ_ENTRIES-1:0] iq_id3issue;
reg [1:0] iq_mem_islot [0:IQ_ENTRIES-1];
wire [IQ_ENTRIES-1:0] iq_fcu_issue;

RegTagBitmap livetarget;
RegTagBitmap iq_livetarget [0:IQ_ENTRIES-1];
RegTagBitmap iq_latestID [0:IQ_ENTRIES-1];
RegTagBitmap iq_cumulative [0:IQ_ENTRIES-1];
RegTagBitmap iq_out2 [0:IQ_ENTRIES-1];
RegTagBitmap iq_out2a [0:IQ_ENTRIES-1];

reg [FSLOTS-1:0] take_branch;
wire [FSLOTS-1:0] take_branchd;
reg [FSLOTS-1:0] take_branchq;
reg [`QBITS] active_tag;

reg id1_v;
Qid id1_id;
Instruction id1_instr;
reg id1_pt;
RegTag id1_Rt;
wire [`IBTOP:0] id_bus [0:QSLOTS-1];

reg id2_v;
Qid id2_id;
Instruction id2_instr;
reg id2_pt;
RegTag id2_Rt;

Seqnum alu0_sn;
reg 				alu0_cmt;
wire				alu0_abort;
reg        alu0_ld;
reg        alu0_dataready;
wire       alu0_done = 1'b1;
wire       alu0_idle;
Qid alu0_sourceid;
Rid alu0_rid;
Instruction alu0_instr;
reg        alu0_mem;
reg        alu0_load;
reg        alu0_store;
reg        alu0_shft;
RegTag alu0_Ra;
Data alu0_argT;
Data alu0_argB;
Data alu0_argA;
Data alu0_argI;	// only used by BEQ
RegTag alu0_tgt;
Address alu0_pc;
Data alu0_bus;
Data alu0_out;
Qid alu0_id;

//(* mark_debug="true" *)
ExcCode alu0_exc;
wire        alu0_v = alu0_dataready;
Qid alu0_id1;
Qid alu1_id1;
reg issuing_on_alu0;
reg alu0_dne = TRUE;

reg [`SNBITS] alu1_sn;
reg 				alu1_cmt;
wire				alu1_abort;
reg        alu1_ld;
reg        alu1_dataready;
wire       alu1_done = 1'b1;
wire       alu1_idle;
Qid alu1_sourceid;
Rid alu1_rid;
Instruction alu1_instr;
reg        alu1_mem;
reg        alu1_load;
reg        alu1_store;
reg        alu1_shft;
RegTag alu1_Ra;
Data alu1_argT;
Data alu1_argB;
Data alu1_argA;
Data alu1_argI;	// only used by BEQ
RegTag alu1_tgt;
Address alu1_pc;
Data alu1_bus;
Data alu1_out;
Qid alu1_id;
ExcCode alu1_exc;
wire        alu1_v = alu1_dataready;
reg alu1_v1;
wire alu1_vsn;
reg issuing_on_alu1;
reg alu1_dne = TRUE;

wire agen0_vsn;
wire agen0_idle;
Seqnum agen0_sn;
Qid agen0_sourceid;
Qid agen0_id;
Rid agen0_rid;
RegTag agen0_tgt;
reg agen0_dataready;
wire agen0_v = agen0_dataready;
reg [2:0] agen0_unit;
Instruction agen0_instr;
reg agen0_mem2;
Address agen0_ma;
Data agen0_res;
Data agen0_argT, agen0_argB, agen0_argA, agen0_argI;
reg agen0_dne = TRUE;
reg agen0_stopString;
reg [11:0] agen0_bytecnt;
reg agen0_offset;
wire agen0_upd2;
reg [1:0] agen0_base;

wire agen1_vsn;
wire agen1_idle;
Seqnum agen1_sn;
Qid agen1_sourceid;
Qid agen1_id;
Rid agen1_rid;
RegTag agen1_tgt;
reg agen1_dataready;
wire agen1_v = agen1_dataready;
reg [2:0] agen1_unit;
Instruction agen1_instr;
reg agen1_mem2;
reg agen1_memdb;
reg agen1_memsb;
Address agen1_ma;
Data agen1_res;
Data agen1_argT, agen1_argB, agen1_argA, agen1_argI;
reg agen1_dne = TRUE;
wire agen1_upd2;
reg [1:0] agen1_base;

reg [7:0] fccnt;
reg [47:0] waitctr;
reg 				fcu_cmt;
reg        fcu_ld;
reg        fcu_dataready;
reg        fcu_done;
reg         fcu_idle = 1'b1;
Qid fcu_sourceid;
Rid fcu_rid;
Instruction fcu_instr;
Instruction fcu_prevInstr;
reg  [2:0] fcu_insln;
reg        fcu_pt = 1'b0;			// predict taken
reg        fcu_branch;
Data fcu_argT;
Data fcu_argA;
Data fcu_argB;
Data fcu_argC;
Data fcu_argI;
RegTag fcu_tgt;
Address fcu_pc;
Address fcu_nextpc;
Address fcu_brdisp;
Data fcu_out;
Data fcu_bus;
Qid fcu_id;
ExcCode fcu_exc;
wire fcu_v = fcu_dataready;
reg fcu_branchmiss;
reg fcu_branchhit;
reg fcu_clearbm;
Address fcu_misspc;
Address misspc;
reg fcu_wait;
reg fcu_hs;	// hardware / software interrupt indicator
reg fcu_dne = TRUE;
wire fcu_takb;

// write buffer
wire [2:0] wb_ptr;
Data wb_data;
Address wb_addr [0:WB_DEPTH-1];
wire [1:0] wb_ol;
wire [WB_DEPTH-1:0] wb_v;
wire wb_rmw;
wire [IQ_ENTRIES-1:0] wb_id;
wire [IQ_ENTRIES-1:0] wbo_id;
wire [7:0] wb_sel;
reg wb_en;
wire wb_hit0, wb_hit1;

wire freezepc;
reg phit;
reg phitd;

reg branchmiss = 1'b0;
wire branchmissd2;
reg branchhit = 1'b0;
Qid missid;
Seqnum misssn;

wire [1:0] issue_count;
reg [1:0] missue_count;
wire [IQ_ENTRIES-1:0] memissue;

wire        dram_avail;
reg	 [2:0] dram0;	// state of the DRAM request (latency = 4; can have three in pipeline)
reg	 [2:0] dram1;	// state of the DRAM request (latency = 4; can have three in pipeline)
Data dram0_argI, dram0_argB;
Data dram0_data;
Address dram0_addr;
Instruction dram0_instr;
reg        dram0_rmw;
reg		   dram0_preload;
RegTag dram0_tgt;
Qid dram0_id;
Rid dram0_rid;
reg        dram0_unc;
reg [2:0]  dram0_memsize;
reg        dram0_load;	// is a load operation
reg        dram0_store;
reg  [1:0] dram0_ol;
Data dram1_argI, dram1_argB;
Data dram1_data;
Address dram1_addr;
Instruction dram1_instr;
reg        dram1_rmw;
reg		   dram1_preload;
RegTag dram1_tgt;
Qid dram1_id;
Rid dram1_rid;
reg        dram1_unc;
reg [2:0]  dram1_memsize;
reg        dram1_load;
reg        dram1_store;
reg  [1:0] dram1_ol;

reg dramA_v;
Qid dramA_id;
Rid dramA_rid;
Data dramA_bus;
reg dramB_v;
Qid dramB_id;
Rid dramB_rid;
Data dramB_bus;

wire outstanding_stores;
reg [47:0] I;		// instruction count
reg [47:0] CC;	// commit count

reg commit0_v;
Rid commit0_id;
RegTag commit0_tgt;
reg commit0_rfw;
Data commit0_bus;
Rid commit0_rid;
reg commit1_v;
Rid commit1_id;
RegTag commit1_tgt;
reg commit1_rfw;
Data commit1_bus;
Rid commit1_rid;

reg [QSLOTS-1:0] queuedOn;
reg [IQ_ENTRIES-1:0] rqueuedOn;
wire [QSLOTS-1:0] queuedOnp;
wire [FSLOTS-1:0] predict_taken;
wire predict_taken0;
wire predict_taken1;
wire predict_taken2;
reg [QSLOTS-1:0] slot_rfw;

reg [8:0] opcode1, opcode2;

wire [FSLOTS-1:0] slotv;

// Branch decodes, needed to guide the program counter logic.
wire [`FSLOTS-1:0] slot_rts;
wire [`FSLOTS-1:0] slot_br;
wire [`FSLOTS-1:0] slot_jc;
wire [`FSLOTS-1:0] slot_jcl;
wire [`FSLOTS-1:0] slot_brk;
wire [3:0] slot_pf [0:FSLOTS-1];
reg [7:0] slot_rtsx;
reg [7:0] slot_brx;
reg [7:0] slot_jcx;
reg [7:0] slot_jclx;
reg [7:0] slot_brkx;
reg [3:0] slot_pfx [0:7];


always @(posedge clk_i)
if (rst_i) begin
	ic_stalls <= 0;
end
else begin
	if (!phit)
		ic_stalls <= ic_stalls + 2'd1;
end

always @(posedge clk_i)
if (rst_i) begin
	br_override <= 0;
end
else begin
	if (pc_override)
		br_override <= br_override + 2'd1;
end


wire [1023:0] ic_out;
reg [2:0] len2g [0:10];
generate begin : icouto
assign iclen1 = ic_out[15:13];
always @*
	len1 = ic_out[15:13];
for (g = 0; g < 11; g = g + 1)
always @*
	len2 = ic_out[{iclen1,4'h0}+13+:3];
for (g = 0; g < 11; g = g + 1) begin
	always @*
		ic1_out[g*13+:13] = ic_out[g*16+:13];
end
for (g = 0; g < 4; g = g + 1) begin
	always @*
		ic2_out[g*13+:13] = ic_out[(g+iclen1)*16+:13];
end
end
endgenerate


assign freezepc = ((~rst_ctr[`RSTC_BIT]) || nmi_i || (irq_i > ol_stack[2:0])) && !int_commit;

// Multiplex exceptional conditions into the instruction stream.
function [51:0] opcmux;
input [51:0] ico;
casez({branchmiss,freezepc})
2'b1?:	opcmux = 52'hC3;	// NOP
2'b01:
	casez({~rst_ctr[`RSTC_BIT],nmi_i,tick_roi,|irq_i})
	4'b1???:	opcmux = {39'h0,4'h0,`RST,`BRKGRP};
	4'b01??:	opcmux = {39'h0,4'h0,`NMI,`BRKGRP};
	4'b001?:	opcmux = {39'h0,4'h1,`NMI,`BRKGRP};
	4'b0001:	opcmux = {39'h0,1'b0,irq_i,`IRQ,`BRKGRP};
	// The following shouldn't happen (pc frozen without interrupt present).
	// It's a hardware error. Just do reset.
	default:	opcmux = {39'h0,4'h0,`RST,`BRKGRP};
	endcase
default:	opcmux = ico;
endcase
endfunction

// Since the micro-program doesn't support conditional logic or branches a 
// conditional load for the PFI instruction is accomplished here.
wire [8:0] opcode1a = opcmux(ic1_out[51:0]);
wire [8:0] opcode2a = opcmux(ic2_out[51:0]);
always @*
	if ((opcode1a==`PFI || opcode1a==`WAI) && |irq_i && !srx[4])
		opcode1 <= opcode1a|9'b1;
	else
		opcode1 <= opcode1a;
always @*
	if ((opcode2a==`PFI || opcode2a==`WAI) && |irq_i && !srx[4])
		opcode2 <= opcode2a|9'b1;
	else
		opcode2 <= opcode2a;

always @*
	insnx[0] = opcmux(ic1_out[51:0]);
always @*
	insnx[1] = opcmux(ic2_out[51:0]);

wire IsRst = (freezepc && ~rst_ctr[`RSTC_BIT]);
wire IsNmi = (freezepc & (nmi_i|tick_roi));
wire IsIrq = (freezepc & |irq_i & ~sr[3]);

Address btgt [0:FSLOTS-1];
Instruction insnxp [0:QSLOTS-1];
reg invdcl;
Address invlineAddr = 24'h0;
wire L1_invline;
Address L1_adr, L2_adr;
wire [475:0] L1_dat, L2_dat;
wire L1_wr, L2_wr;
wire L1_selpc;
wire L2_ld;
wire L1_ihit, L2_ihit, L2_ihita;
wire ihit;
assign ihit = L1_ihit;
wire L1_nxt, L2_nxt;					// advances cache way lfsr
wire [2:0] L2_cnt;
wire [415:0] ROM_dat;
wire [415:0] d0ROM_dat;
wire [415:0] d1ROM_dat;

wire isROM;
wire d0isROM, d1isROM;
wire d0L1_wr, d0L2_ld;
wire d1L1_wr, d1L2_ld;
Address d0L1_adr, d0L2_adr;
Address d1L1_adr, d1L2_adr;
wire d0L2_rhit, d0L2_whit;
wire d0L2_rhita, d1L2_rhita;
wire d0L1_nxt, d0L2_nxt;					// advances cache way lfsr
wire d1L1_dhit, d1L2_rhit, d1L2_whit;
wire d1L1_nxt, d1L2_nxt;					// advances cache way lfsr
wire [36:0] d0L1_sel, d0L2_sel;
wire [36:0] d1L1_sel, d1L2_sel;
wire [475:0] d0L1_dat, d0L2_rdat, d0L2_wdat;
wire [475:0] d1L1_dat, d1L2_rdat, d1L2_wdat;
wire d0L1_dhit;
wire d0L1_selpc;
wire d1L1_selpc, d1L2_selpc;
wire d0L1_invline,d1L1_invline;
//reg [255:0] dcbuf;

reg preload;
reg [1:0] dccnt;
reg [3:0] dcwait = 4'd3;
reg [3:0] dcwait_ctr = 4'd3;
wire dhit0, dhit1;
wire dhit0a, dhit1a;
wire dhit00, dhit10;
wire dhit01, dhit11;
Address dcadr;
Data dcdat;
reg dcwr;
reg [7:0] dcsel;
wire update_iq;
wire [IQ_ENTRIES-1:0] uid;
wire [RENTRIES-1:0] ruid;

wire [2:0] icti;
wire [1:0] ibte;
wire [1:0] iol = 2'b00;
wire icyc;
wire istb;
wire iwe = 1'b0;
wire [15:0] isel;
Address iadr;
reg iack_i;
reg iexv_i;
reg ierr_i;

wire [2:0] d0cti;
wire [1:0] d0bte;
wire [1:0] d0ol = 2'b00;
wire d0cyc;
wire d0stb;
wire d0we = 1'b0;
wire [15:0] d0sel;
Address d0adr;
reg d0ack_i;
reg d0rdv_i;
reg d0wrv_i;
reg d0err_i;

wire [2:0] d1cti;
wire [1:0] d1bte;
wire [1:0] d1ol = 2'b00;
wire d1cyc;
wire d1stb;
wire d1we = 1'b0;
wire [15:0] d1sel;
Address d1adr;
reg d1ack_i;
reg d1rdv_i;
reg d1wrv_i;
reg d1err_i;

wire [1:0] wol;
wire wcyc;
wire wstb;
wire wwe;
wire [15:0] wsel;
Address wadr;
wire [103:0] wdat;
wire wcr;
reg wack_i;
reg werr_i;
reg wrdv_i;
reg wwrv_i;
reg wtlbmiss_i;

reg [1:0] dol;
reg [2:0] dcti;
reg [1:0] dbte;
reg dcyc;
reg dstb;
reg dack_i;
reg derr_i;
reg dwe;
reg [7:0] dsel;
Address dadr;
reg [127:0] ddat;
wire [15:0] dselx = dsel << dadr[2:0];
reg dwrap;

function IsBranch;
input Instruction insn;
IsBranch = insn.br.opcode==`BRANCH0 || insn.br.opcode==`BRANCH1;
endfunction
function IsBrk;
input Instruction insn;
IsBrk = insn.gen.opcode==`BRKGRP;
endfunction
function IsRti;
input Instruction insn;
IsRti = insn.gen.opcode==`RETGRP && insn.wai.exop==`RTI;
endfunction
function IsRet;
input Instruction insn;
IsRet = insn.ret.opcode==`RETGRP && insn.ret.exop==`RET;
endfunction
function IsWai;
input Instruction insn;
IsWai = insn.gen.opcode==`WAI;
endfunction
function IsJal;
input Instruction insn;
IsJal = insn.jal.opcode==`JAL;
endfunction

reg [7:0] slot_waix;
wire [FSLOTS-1:0] slot_wai;
generate begin : mdecoders
for (g = 0; g < 8; g = g + 1)
always @*
begin
	slot_rtsx[g] = IsRet(ic1_out[g*13+:52]);
	slot_brx[g] = IsBranch(ic1_out[g*13+:52]);
	slot_jcx[g]	= IsJal(ic1_out[g*13+:52]);
	slot_brkx[g]	= IsBrk(ic1_out[g*13+:52]) || IsRti(ic1_out[g*13+:52]);
	slot_waix[g] = IsWai(ic1_out[g*13+:52]);
end
end
endgenerate

assign slot_rts[0] = slot_rtsx[0];
assign slot_rts[1] = slot_rtsx[iclen1];
assign slot_br[0] = slot_brx[0];
assign slot_br[1] = slot_brx[iclen1];
assign slot_jc[0] = slot_jcx[0];
assign slot_jc[1] = slot_jcx[iclen1];
assign slot_jcl[0] = slot_jclx[0];
assign slot_jcl[1] = slot_jclx[iclen1];
assign slot_brk[0] = slot_brkx[0];
assign slot_brk[1] = slot_brkx[iclen1];
assign slot_pf[0] = slot_pfx[0];
assign slot_pf[1] = slot_pfx[iclen1];
assign slot_wai[0] = slot_waix[0];
assign slot_wai[1] = slot_waix[iclen1];

initial begin
	take_branch = 2'b00;
end
always @*
begin
	take_branch[0] = (slot_br[0] && predict_taken[0]) || slot_brk[0];
	take_branch[1] = (slot_br[1] && predict_taken[1]) || slot_brk[1];
end

// Branching for purposes of the branch shadow.
reg [IQ_ENTRIES-1:0] is_qbranch;
reg [QSLOTS-1:0] slot_jmp;
reg [QSLOTS-1:0] uoq_take_branch;
always @*
for (n = 0; n < QSLOTS; n = n + 1)
	slot_jmp[n] = IsJal(insnx[n]);
always @*
for (n = 0; n < QSLOTS; n = n + 1)
	slot_rfw[n] = IsRFW(insnx[n]);

always @*
for (n = 0; n < IQ_ENTRIES; n = n + 1)
	is_qbranch[n] = iq_br[n];

wire [1:0] ic_fault;
wire [AMSB:0] missadr;
reg invic, invdc;
reg invicl;
reg [4:0] bstate;
wire [3:0] icstate;
reg [1:0] bwhich;

// The L1 address might not be equal to the ip if a cache update is taking
// place. This can lead to a false hit because once the cache is updated
// it'll match L1, but L1 hasn't switched back to ip yet, and it's a hit
// on the ip address we're looking for. => make sure the cache controller
// is IDLE.
wire nextb;		// fetch next bundle
always @*
	phit <= (ihit&&icstate==IDLE) && !invicl && icstate==IDLE;
always @(posedge clk)
if (rst_i)
	phitd <= 1'b1;
else begin
	if (phit & nextb)
		phitd <= phit;
end

function IsNop;
input [51:0] ins;
IsNop = ins[7:0]==`NOP;
endfunction

Rid next_iq_rid [0:IQ_ENTRIES-1];
wire [`RENTRIES-1:0] next_rob_v;



RegTagBitmap rf_v;								// register is valid
RegTagBitmap regIsValid;					// register is valid (in this cycle)
Rid rf_source[0:AREGS-1];

regfileValid urfv1
(
	.rst(rst_i),
	.clk(clk),
	.slotv(slotv),
	.slot_rfw(slot_rfw),
	.tails(tails),
	.livetarget(livetarget),
	.branchmiss(branchmiss),
	.rob_id(robIds),
	.commit0_v(commit0_v),
	.commit1_v(commit1_v),
	.commit0_id(commit0_id),
	.commit1_id(commit1_id),
	.commit0_tgt(commit0_tgt),
	.commit1_tgt(commit1_tgt),
	.commit0_rfw(commit0_rfw),
	.commit1_rfw(commit1_rfw),
	.rf_source(rf_source),
	.iq_source(iq_source),
	.Rd(Rt),
	.queuedOn(queuedOnp),
	.rf_v(rf_v),
	.regIsValid(regIsValid)
);

regfileSource urfs1
(
	.rst(rst_i),
	.clk(clk),
	.branchmiss(branchmiss),
	.heads(heads),
	.slotv(slotv),
	.slot_rfw(slot_rfw),
	.queuedOn(queuedOnp),
	.rqueuedOn(rqueuedOn),
	.iq_state(iq_state),
	.iq_rfw(iq_rfw),
	.Rd(Rt),
	.rob_tails(tails),
	.iq_latestID(iq_latestID),
	.iq_tgt(iq_tgt),
	.iq_rid(iq_rid),
	.rf_source(rf_source)
);

// Check how many instructions can be queued. An instruction can queue only if
// there are entries available in both the dispatch and re-order buffer. This
// quarentees the re-order buffer id is available during queue. The instruction
// can't execute until there is a place to put the result.
// The break bit in the instruction template must also be clear in order for an
// instruction to queue.
getQueuedCount ugqc1
(
	.branchmiss(branchmiss),
	.brk(3'b0),
	.phitd(phitd),
	.tails(tails),
	.rob_tails(tails),
	.slotvd(slotvd),
	.slot_jmp(slot_jmp),
	.take_branch(take_branch),
	.iq_v(iq_v),
	.rob_v(GetV(1)),
	.queuedCnt(queuedCnt),
	.queuedOnp(queuedOnp)
);

getRQueuedCount ugrqct1
(
	.rst(rst_i),
	.rob_tails(tails),
	.rob_v_i(GetV(1)),
	.rob_v_o(next_rob_v),
	.heads(heads),
	.iq_state(iq_state),
	.iq_rid_i(iq_rid),
	.iq_rid_o(next_iq_rid),
	.rqueuedCnt(rqueuedCnt),
	.rqueuedOn(rqueuedOn)
);

calc_ramt ucra1
(
	.hi_amt(hi_amt),
	.rob_heads(rob_heads),
	.rob_tails(rob_tails),
	.rob_state(GetState(1)),
	.r_amt(r_amt)
);

reg [1:0] max_cs;

programCounter upc1
(
	.rst(rst_i),
	.clk(clk),
	.q1(queuedCnt==2'd1),
	.q2(queuedCnt==2'd2),
	.q1bx(1'b0),
	.insnx(insnx),
	.phit(phit),
	.freezepc(freezepc),
	.branchmiss(branchmiss),
	.misspc(misspc),
	.len1(len1),
	.len2(len2),
	.len3(1'd0),
	.jc(slot_jc),
	.jcl(slot_jcl),
	.rts(slot_rts),
	.br(slot_br),
	.wai(slot_wai),
	.take_branch(take_branch),
	.btgt(btgt),
	.pc(pc),
	.pcd(pcd),
	.pc_chg(),
	.branch_pc(next_pc),
	.ra(52'd0),	//(ra),
	.pc_override(pc_override),
	.debug_on(debug_on)
);

`ifdef FCU_RSB
RSB ursb1
(
	.rst(rst_i),
	.clk(clk),
	.clk2x(clk2x_i),
	.clk4x(clk4x_i),
	.regLR(6'd61),
	.queuedOn(queuedOn),
	.jal(slot_jal),
	.Ra(Rb),
	.Rd(Rt),
	.call(slot_jsr),
	.ret(slot_rts),
	.pc(pcd),
	.ra(ra),
	.stompedRets(),
	.stompedRet()
);
`else
assign ra = `FCU_RA;
`endif

next_bundle unb1
(
	.rst(rst_i),
	.slotv(slotv),
	.phit(phit),
	.next(nextb)
);

ICController uicc1
(
	.rst_i(rst_i),
	.clk_i(clk_i),
	.missadr(missadr),
	.hit(L1_ihit),
	.bstate(bstate),
	.state(icstate),
	.invline(invicl),
	.invlineAddr(invlineAddr),
	.icl_ctr(),
	.ihitL2(L2_ihit),
	.L2_ld(L2_ld),
	.L2_cnt(L2_cnt),
	.L2_adr(L2_adr),
	.L2_dat(L2_dat),
	.L2_nxt(L2_nxt),
	.L1_selpc(L1_selpc),
	.L1_adr(L1_adr),
	.L1_dat(L1_dat),
	.L1_wr(L1_wr),
	.L1_invline(L1_invline),
	.ROM_dat(ROM_dat),
	.isROM(isROM),
	.icnxt(L1_nxt),
	.icwhich(),
	.icl_o(icl_o),
	.cti_o(icti),
	.bte_o(ibte),
	.bok_i(bok_i),
	.cyc_o(icyc),
	.stb_o(istb),
	.ack_i(iack_i),
	.err_i(ierr_i),
	.tlbmiss_i(tlb_miss),
	.exv_i(iexv_i),
	.sel_o(isel),
	.adr_o(iadr),
	.dat_i(dat_i)
);

L1_icache uic1
(
	.rst(rst_i),
	.clk(clk_i),
	.nxt(L1_nxt),
	.wr(L1_wr),
	.wadr(L1_adr),
	.adr(L1_selpc ? pc : L1_adr),
	.i(L1_dat),
	.o(ic_out),
	.fault(),
	.hit(L1_ihit),
	.invall(invic),
	.invline(L1_invline),
	.missadr(missadr)
);

L2_icache uic2
(
	.rst(rst_i),
	.clk(clk_i),
	.nxt(L2_nxt),
	.wr(L2_ld),
	.adr(L2_ld ? L2_adr : L1_adr),
	.cnt(L2_cnt),
	.exv_i(1'b0),
	.i(dat_i),
	.err_i(1'b0),
	.o(L2_dat),
	.hit(L2_ihita),
	.invall(invic),
	.invline(L1_invline)
);

assign L2_ihit = isROM|L2_ihita;
assign d0L2_rhit = d0isROM|d0L2_rhita;
assign d1L2_rhit = d1isROM|d1L2_rhita;

reg [8:0] rL1_adr;
reg [8:0] rd0L1_adr;
reg [8:0] rd1L1_adr;
wire [511:0] ROM_d;
(* ram_style="block" *)
reg [511:0] rommem [0:511];
initial begin
`include "d:/cores5/Gambit/v5/software/boot/fibonacci.ve0"
end
always @(posedge clk)
	rL1_adr <= L1_adr[13:5];
always @(posedge clk)
	rd0L1_adr <= d0L1_adr[13:5];
always @(posedge clk)
	rd1L1_adr <= d1L1_adr[13:5];
wire [511:0] romo = rommem[rL1_adr];
wire [511:0] romo0 = rommem[rd0L1_adr];
wire [511:0] romo1 = rommem[rd1L1_adr];
wire [12:0] romoo [0:31];
wire [12:0] romoo0 [0:31];
wire [12:0] romoo1 [0:31];
generate begin : romslices
for (g = 0; g < 32; g = g + 1)
begin
assign ROM_d = rommem[rd0L1_adr];
assign romoo[g] = romo[g*16+12:g*16];
assign romoo0[g] = romo0[g*16+12:g*16];
assign romoo1[g] = romo1[g*16+12:g*16];
assign ROM_dat[g*13+12:g*13] = romoo[g];
assign d0ROM_dat[g*13+12:g*13] = romoo0[g];
assign d1ROM_dat[g*13+12:g*13] = romoo1[g];
end
assign romoo0[31] = romo0[508:496];
end
endgenerate
//assign ROM_dat = rommem[rL1_adr];
//assign d0ROM_dat = rommem[rd0L1_adr];
//assign d1ROM_dat = rommem[rd1L1_adr];

//wire predict_taken;
wire predict_takenA;
wire predict_takenB;
wire predict_takenC;
wire predict_takenD;
wire predict_takenE;
wire predict_takenF;
wire predict_takenA1;
wire predict_takenB1;
wire predict_takenC1;
wire predict_takenD1;

wire btbwr0 = iq_state[heads[0]]==IQS_CMT && iq_fc[heads[0]];
wire btbwr1 = iq_state[heads[1]]==IQS_CMT && iq_fc[heads[1]];
wire btbwr2 = iq_state[heads[2]]==IQS_CMT && iq_fc[heads[2]];

wire fcu_clk;
`ifdef FCU_ENH
//BUFGCE ufcuclk
//(
//	.I(clk_i),
//	.CE(fcu_available),
//	.O(fcu_clk)
//);
`endif
assign fcu_clk = clk_i;

`ifdef FCU_BTB
BTB #(.AMSB(AMSB)) ubtb1
(
  .rst(rst_i),
  .clk(clk_i),
  .clk2x(clk2x_i),
  .clk4x(clk4x_i),
  .wr0(btbwr0),  
  .wadr0(iq_pc[heads[0]]),
  .wdat0(iq_ma[heads[0]]),
  .valid0((iq_br[heads[0]] ? iq_takb[heads[0]] : iq_bt[heads[0]]) & iq_v[heads[0]]),
  .wr1(btbwr1),  
  .wadr1(iq_pc[heads[1]]),
  .wdat1(iq_ma[heads[1]]),
  .valid1((iq_br[heads[1]] ? iq_takb[heads[1]] : iq_bt[heads[1]]) & iq_v[heads[1]]),
  .wr2(btbwr2),  
  .wadr2(iq_pc[heads[2]]),
  .wdat2(iq_ma[heads[2]]),
  .valid2((iq_br[heads[2]] ? iq_takb[heads[2]] : iq_bt[heads[2]]) & iq_v[heads[2]]),
  .rclk(~clk),
  .pcA(pc),
  .btgtA(btgt[0]),
  .pcB(pc + len1),
  .btgtB(btgt[1]),
  .pcC(pc + len1 + len2),
  .btgtC(),
  .npcA(pc + len1),
  .npcB(pc + len1 + len2),
  .npcC()
);
`else
assign btgt[0] = pc + len1;
assign btgt[1] = pc + len1 + len2;
`endif

Address pcs [0:FSLOTS-1];
assign pcs[0] = pc;
assign pcs[1] = pc + len1;

wire [3:0] xisBr;
Address xpc [0:3];
wire [3:0] xtkb;

assign xisBr[0] = iq_br[heads[0]] & commit0_v;// & ~\[heads[0]][5];
assign xisBr[1] = iq_br[heads[1]] & commit1_v;// & ~iq_instr[heads[1]][5];
assign xisBr[2] = 1'b0;// & ~iq_instr[heads[2]][5];
assign xisBr[3] = 1'b0;
assign xpc[0] = iq_pc[heads[0]];
assign xpc[1] = iq_pc[heads[1]];
assign xpc[2] = iq_pc[heads[2]];
assign xpc[3] = 1'd0;
assign xtkb[0] = commit0_v & iq_takb[heads[0]];
assign xtkb[1] = commit1_v & iq_takb[heads[1]];
assign xtkb[2] = 1'b0;
assign xtkb[3] = 1'b0;

wire [FSLOTS-1:0] predict_takenx;

`ifdef FCU_BP
gselectPredictor ubp1
(
  .rst(rst_i),
  .clk(clk_i),
  .clk2x(clk2x_i),
  .clk4x(clk4x_i),
  .en(1'b1),
  .xisBranch(xisBr),
  .xip(xpc),
  .takb(xtkb),
  .ip(pcs),
  .predict_taken(predict_takenx)
);
`else
assign predict_takenx[0] = insnx[0][15];
assign predict_takenx[1] = insnx[1][15];
`endif

assign predict_taken[0] = predict_takenx[0];
assign predict_taken[1] = predict_takenx[1];


reg StoreAck1, isStore;
Data dc0_out, dc1_out;
wire whit0, whit1, whit2;

wire wr_dcache0 = (dcwr)||(((bstate==B_StoreAck && StoreAck1) || (bstate==B_LSNAck && isStore)) && whit0);
wire wr_dcache1 = (dcwr)||(((bstate==B_StoreAck && StoreAck1) || (bstate==B_LSNAck && isStore)) && whit1);
wire rd_dcache0 = !dram0_unc & dram0_load;
wire rd_dcache1 = !dram1_unc & dram1_load;

DCController udcc1
(
	.rst_i(rst_i),
	.clk_i(clk_i),
	.dadr(dram0_addr),
	.rd(rd_dcache0),
	.wr(dcwr),
	.wsel(dcsel),
	.wadr(dcadr),
	.wdat(dcdat),
	.bstate(bstate),
	.state(),
	.invline(invdcl),
	.invlineAddr(invlineAddr),
	.icl_ctr(),
	.isROM(d0isROM),
	.ROM_dat(d0ROM_dat),
	.dL2_rhit(d0L2_rhit),
	.dL2_rdat(d0L2_rdat),
	.dL2_whit(d0L2_whit),
	.dL2_ld(d0L2_ld),
	.dL2_wsel(d0L2_sel),
	.dL2_wadr(d0L2_adr),
	.dL2_wdat(d0L2_wdat),
	.dL2_nxt(d0L2_nxt),
	.dL1_hit(d0L1_dhit),
	.dL1_selpc(d0L1_selpc),
	.dL1_sel(d0L1_sel),
	.dL1_adr(d0L1_adr),
	.dL1_dat(d0L1_dat),
	.dL1_wr(d0L1_wr),
	.dL1_invline(d0L1_invline),
	.dcnxt(d0L1_nxt),
	.dcwhich(),
	.dcl_o(),
	.cti_o(d0cti),
	.bte_o(d0bte),
	.bok_i(bok_i),
	.cyc_o(d0cyc),
	.stb_o(d0stb),
	.ack_i(d0ack_i),
	.err_i(d0err_i),
	.wrv_i(d0wrv_i),
	.rdv_i(d0rdv_i),
	.sel_o(d0sel),
	.adr_o(d0adr),
	.dat_i(dat_i)
);

L1_dcache udc1
(
	.rst(rst_i),
	.clk(clk_i),
	.nxt(d0L1_nxt),
	.wr(d0L1_wr),
	.sel(d0L1_sel),
	.adr(d0L1_selpc ? dram0_addr : d0L1_adr),
	.i({5'd0,d0L1_dat}),
	.o(dc0_out),
	.fault(),
	.hit(d0L1_dhit),
	.invall(1'b0),//invdc),
	.invline(1'b0)//d0L1_invline)
);

L2_dcache udc2
(
	.rst(rst_i),
	.clk(clk_i),
	.nxt(d0L2_nxt),
	.wr(d0L2_ld),
	.wadr(d0L2_adr),
	.radr(d0L1_adr),
	.sel(d0L2_sel),
	.tlbmiss_i(1'b0),
	.rdv_i(1'b0),
	.wrv_i(1'b0),
	.i(d0L2_wdat),
	.err_i(1'b0),
	.o(d0L2_rdat),
	.rhit(d0L2_rhita),
	.whit(d0L2_whit),
	.invall(1'b0),//invdc),
	.invline(1'b0)//d0L1_invline)
);


DCController udcc2
(
	.rst_i(rst_i),
	.clk_i(clk_i),
	.dadr(dram1_addr),
	.rd(rd_dcache1),
	.wr(dcwr),
	.wsel(dcsel),
	.wadr(dcadr),
	.wdat(dcdat),
	.bstate(bstate),
	.state(),
	.invline(invdcl),
	.invlineAddr(invlineAddr),
	.icl_ctr(),
	.isROM(d1isROM),
	.ROM_dat(d1ROM_dat),
	.dL2_rhit(d1L2_rhit),
	.dL2_rdat(d1L2_rdat),
	.dL2_whit(d1L2_whit),
	.dL2_ld(d1L2_ld),
	.dL2_wsel(d1L2_sel),
	.dL2_wadr(d1L2_adr),
	.dL2_wdat(d1L2_wdat),
	.dL2_nxt(d1L2_nxt),
	.dL1_hit(d1L1_dhit),
	.dL1_selpc(d1L1_selpc),
	.dL1_sel(d1L1_sel),
	.dL1_adr(d1L1_adr),
	.dL1_dat(d1L1_dat),
	.dL1_wr(d1L1_wr),
	.dL1_invline(d1L1_invline),
	.dcnxt(d1L1_nxt),
	.dcwhich(),
	.dcl_o(),
	.cti_o(d1cti),
	.bte_o(d1bte),
	.bok_i(bok_i),
	.cyc_o(d1cyc),
	.stb_o(d1stb),
	.ack_i(d1ack_i),
	.err_i(d1err_i),
	.wrv_i(d1wrv_i),
	.rdv_i(d1rdv_i),
	.sel_o(d1sel),
	.adr_o(d1adr),
	.dat_i(dat_i)
);

L1_dcache udc3
(
	.rst(rst_i),
	.clk(clk_i),
	.nxt(d1L1_nxt),
	.wr(d1L1_wr),
	.sel(d1L1_sel),
	.adr(d1L1_selpc ? dram1_addr : d1L1_adr),
	.i({5'd0,d1L1_dat}),
	.o(dc1_out),
	.fault(),
	.hit(d1L1_dhit),
	.invall(1'b0),//invdc),
	.invline(1'b0)//d1L1_invline)
);

L2_dcache udc4
(
	.rst(rst_i),
	.clk(clk_i),
	.nxt(d1L2_nxt),
	.wr(d1L2_ld),
	.wadr(d1L2_adr),
	.radr(d1L1_adr),
	.sel(d1L2_sel),
	.tlbmiss_i(1'b0),
	.rdv_i(1'b0),
	.wrv_i(1'b0),
	.i(d1L2_wdat),
	.err_i(1'b0),
	.o(d1L2_rdat),
	.rhit(d1L2_rhita),
	.whit(d1L2_whit),
	.invall(1'b0),//invdc),
	.invline(1'b0)//d1L1_invline)
);

Data aligned_data = fnDatiAlign(dram0_addr,xdati);
Data rdat0, rdat1;
assign rdat0 = fnDataExtend(dram0_instr,dram0_unc ? aligned_data : dc0_out);
assign rdat1 = fnDataExtend(dram1_instr,dram1_unc ? aligned_data : dc1_out);
assign dhit0a = d0L1_dhit;
assign dhit1a = d1L1_dhit;

wire [7:0] wb_fault;
wire wb_q0_done, wb_q1_done;
wire wb_has_bus;
assign dhit0 = dhit0a && !wb_hit0;
assign dhit1 = dhit1a && !wb_hit1;
wire wb_p0_wr = (dram0==`DRAMSLOT_BUSY && dram0_store);
wire wb_p1_wr = (dram1==`DRAMSLOT_BUSY && dram1_store);

writeBuffer #(.IQ_ENTRIES(IQ_ENTRIES)) uwb1
(
	.rst_i(rst_i),
	.clk_i(clk),
	.bstate(bstate),
	.cyc_pending(cyc_pending),
	.wb_has_bus(wb_has_bus),
	.wb_v(wb_v),
	.wb_addr(wb_addr),
	.update_iq(update_iq),
	.uid(uid),
	.ruid(ruid),
	.fault(wb_fault),
	.p0_id_i(dram0_id),
	.p0_rid_i(dram0_rid),
	.p0_wrap_i(dram0_wrap),
	.p0_wr_i(wb_p0_wr),
	.p0_ack_o(wb_q0_done),
	.p0_sel_i(fnSelect(dram0_instr)),
	.p0_adr_i(dram0_addr),
	.p0_dat_i(dram0_data),
	.p0_hit(wb_hit0),
	.p1_id_i(dram1_id),
	.p1_rid_i(dram1_rid),
	.p1_wrap_i(dram1_wrap),
	.p1_wr_i(wb_p1_wr),
	.p1_ack_o(wb_q1_done),
	.p1_sel_i(fnSelect(dram1_instr)),
	.p1_adr_i(dram1_addr),
	.p1_dat_i(dram1_data),
	.p1_hit(wb_hit1),
	.cyc_o(wcyc),
	.stb_o(wstb),
	.ack_i(wack_i),
	.err_i(werr_i),
	.tlbmiss_i(wtlbmiss_i),
	.wrv_i(wwrv_i),
	.we_o(wwe),
	.sel_o(wsel),
	.adr_o(wadr),
	.dat_o(wdat),
	.cr_o(wcr),
	.cwr_o(dcwr),
	.csel_o(dcsel),
	.cadr_o(dcadr),
	.cdat_o(dcdat)
);

wire rob_empty = GetV(1) == {RENTRIES{`INV}};

headptrs uhp1
(
	.rst(rst_i),
	.clk(clk),
	.amt(hi_amt),
	.heads(heads),
	.ramt(r_amt),
	.rob_heads(rob_heads),
	.headcnt(uop_committed)
);

tailptrs utp1
(
	.rst_i(rst_i),
	.clk_i(clk_i),
	.branchmiss(branchmiss),
	.iq_stomp(iq_stomp),
//	.iq_br_tag(iq_br_tag),
	.queuedCnt(queuedCnt),
	.iq_tails(tails),
	.rqueuedCnt(queuedCnt),
	.rob_tails(rob_tails),
//	.active_tag(miss_tag),
	.iq_rid(iq_rid)
);

function RegTag fnRt;
input Instruction ins;
case(ins.gen.opcode)
`ADDIS,`ANDIS,`ORIS,
`PERM_3R,`CSR,
`ADD_3R,`ADD_RI22,`ADD_RI35,
`SUB_3R,`SUB_RI22,`SUB_RI35,
`MUL_3R,`MUL_RI22,`MUL_RI35,
`AND_3R,`AND_RI22,`AND_RI35,
`OR_3R,`OR_RI22,`OR_RI35,
`EOR_3R,`EOR_RI22,`EOR_RI35:
	fnRt = {2'b00,ins.rr.Rt};
`ASL_3R,`ASR_3R,`ROL_3R,`ROR_3R,`LSR_3R:
	fnRt = {2'b00,ins.rr.Rt};
`BIT_3R,`BIT_RI22,`BIT_RI35,
`CMP_3R,`CMP_RI22,`CMP_RI35:
	fnRt = {2'b11,ins.rr.Rt};
`JAL,`JAL_RN:
	fnRt = {5'b11000,ins.jal.lk};
`MTx:
	fnRt = {2'b11,ins.rr.Rt};
`MFx:
	fnRt = {2'b00,ins.rr.Rt};
default:
	fnRt = 7'd0;
endcase
endfunction

function RegTag fnRa;
input Instruction ins;
case(ins.gen.opcode)
`ADDIS,`ANDIS,`ORIS,
`PERM_3R,`CSR,
`ADD_3R,`ADD_RI22,`ADD_RI35,
`SUB_3R,`SUB_RI22,`SUB_RI35,
`MUL_3R,`MUL_RI22,`MUL_RI35,
`AND_3R,`AND_RI22,`AND_RI35,
`OR_3R,`OR_RI22,`OR_RI35,
`EOR_3R,`EOR_RI22,`EOR_RI35:
	fnRa = {2'b00,ins.rr.Ra};
`ASL_3R,`ASR_3R,`ROL_3R,`ROR_3R,`LSR_3R:
	fnRa = {2'b00,ins.rr.Ra};
`BIT_3R,`BIT_RI22,`BIT_RI35,
`CMP_3R,`CMP_RI22,`CMP_RI35:
	fnRa = {2'b00,ins.rr.Ra};
`JAL_RN:
	fnRa = {3'b00,ins.jalrn.Ra};
`MTx:
	fnRa = {2'b00,ins.rr.Ra};
`MFx:
	fnRa = {2'b11,ins.rr.Ra};
`RETGRP:
	case(ins.ret.exop)
	`RET:	fnRa = {5'b11000,ins.ret.lk};
	`RTI:	fnRa = 7'b1100100;
	default:	;
	endcase
`BRANCH0,`BRANCH1:
	fnRa = {4'b1101,ins.br.cr};
default:
	fnRa = 7'd0;
endcase
endfunction

function RegTag fnRb;
input Instruction ins;
case(ins.gen.opcode)
`ADDIS,`ANDIS,`ORIS,
`PERM_3R,`CSR,
`ADD_3R,`ADD_RI22,`ADD_RI35,
`SUB_3R,`SUB_RI22,`SUB_RI35,
`MUL_3R,`MUL_RI22,`MUL_RI35,
`AND_3R,`AND_RI22,`AND_RI35,
`OR_3R,`OR_RI22,`OR_RI35,
`EOR_3R,`EOR_RI22,`EOR_RI35:
	fnRb = {2'b00,ins.rr.Rb};
`ASL_3R,`ASR_3R,`ROL_3R,`ROR_3R,`LSR_3R:
	fnRb = {2'b00,ins.rr.Rb};
`BIT_3R,`BIT_RI22,`BIT_RI35,
`CMP_3R,`CMP_RI22,`CMP_RI35:
	fnRb = {2'b00,ins.rr.Rb};
default:
	fnRb = 7'd0;
endcase
endfunction

always @*
for (n = 0; n < QSLOTS; n = n + 1)
	Rt[n] = fnRt(insnx[n]);
always @*
for (n = 0; n < QSLOTS; n = n + 1)
	Rb[n] = fnRb(insnx[n]);
always @*
for (n = 0; n < QSLOTS; n = n + 1)
	Ra[n] = fnRa(insnx[n]);

always @*
	for (n = 0; n < QSLOTS; n = n + 1) begin
		casez(Ra[n])
		7'b00?????:	
			if (Ra[n][4:0]==5'd31)
				case(ol)
				2'b00:	rfoa[n] <= msp;
				2'b01:	rfoa[n] <= hsp;
				2'b10:	rfoa[n] <= ssp;
				2'b11:	rfoa[n] <= regsx[Ra[n][4:0]];
				endcase
			else
				rfoa[n] <= regsx[Ra[n][4:0]];
		7'b11000??:	rfoa[n] <= lkregsx[Ra[n][1:0]];
		7'b1100100:	rfoa[n] <= lkregsx[4];
		7'b1101???:	rfoa[n] <= crregsx[Ra[n][2:0]];
		7'b1111000:	rfoa[n] <= ssp;
		7'b1111001:	rfoa[n] <= hsp;
		7'b1111010:	rfoa[n] <= msp;
		default:		rfoa[n] <= 52'd0;
		endcase
	end

always @*
	for (n = 0; n < QSLOTS; n = n + 1) begin
		casez(Rb[n])
		7'b00?????:
			if (Rb[n][4:0]==5'd31)
				case(ol)
				2'b00:	rfob[n] <= msp;
				2'b01:	rfob[n] <= hsp;
				2'b10:	rfob[n] <= ssp;
				2'b11:	rfob[n] <= regsx[Rb[n][4:0]];
				endcase
			else
				rfoa[n] <= regsx[Ra[n][4:0]];
		7'b11000??:	rfob[n] <= lkregsx[Rb[n][1:0]];
		7'b1100100:	rfob[n] <= lkregsx[4];
		7'b1101???:	rfob[n] <= crregsx[Rb[n][2:0]];
		7'b1111000:	rfob[n] <= ssp;
		7'b1111001:	rfob[n] <= hsp;
		7'b1111010:	rfob[n] <= msp;
		default:		rfob[n] <= 52'd0;
		endcase
	end

always @*
begin
	mspx = msp;
	hspx = hsp;
	sspx = ssp;
	if (commit0_v && commit0_rfw) begin
		if (commit0_tgt==7'b0011111)
			case(ol)
			2'b00:	mspx = commit0_bus;
			2'b01:	hspx = commit0_bus;
			2'b10:	sspx = commit0_bus;
			default:	;
			endcase
		else
			case(commit0_tgt)
			7'b1111000:	sspx = commit0_bus;
			7'b1111001:	hspx = commit0_bus;
			7'b1111010:	mspx = commit0_bus;
			endcase
	end
	if (commit1_v && commit1_rfw) begin
		if (commit1_tgt==7'b0011111)
			case(ol)
			2'b00:	mspx = commit1_bus;
			2'b01:	hspx = commit1_bus;
			2'b10:	sspx = commit1_bus;
			default:	;
			endcase
		else
			case(commit1_tgt)
			7'b1111000:	sspx = commit1_bus;
			7'b1111001:	hspx = commit1_bus;
			7'b1111010:	mspx = commit1_bus;
			endcase
	end
end

generate begin : regupd
for (g = 0; g < 32; g = g + 1)
always @*
	if (commit1_v && commit1_tgt==g && commit1_rfw)
		regsx[g] = commit1_bus;
	else if (commit0_v && commit0_tgt==g && commit0_rfw)
		regsx[g] = commit0_bus;
	else
		regsx[g] = regs[g];
end
endgenerate

generate begin : lkregupd
for (g = 96; g < 101; g = g + 1)
always @*
	if (commit1_v && commit1_tgt==g && commit1_rfw)
		lkregsx[g[2:0]] = commit1_bus;
	else if (commit0_v && commit0_tgt==g && commit0_rfw)
		lkregsx[g[2:0]] = commit0_bus;
	else
		lkregsx[g[2:0]] = lkregs[g[2:0]];
end
endgenerate

generate begin : crregupd
for (g = 0; g < 8; g = g + 1)
always @*
begin
	crregsx = crregs;
	if (commit0_v) begin
		if (commit0_tgt==103 && commit0_rfw)
			crregsx = commit0_bus[15:0];
		else if (commit0_tgt==g+104 && commit0_rfw)
			crregsx[g*2+:2] = commit0_bus[1:0];
	end
	if (commit1_v) begin
	 	if (commit1_tgt==103 && commit1_rfw)
			crregsx = commit1_bus[15:0];
		else if (commit1_tgt==g+104 && commit1_rfw)
			crregsx[g*2+:2] = commit1_bus[1:0];
	end
end
end
endgenerate


Data argA [0:QSLOTS-1];
Data argB [0:QSLOTS-1];

always @*
for (n = 0; n < QSLOTS; n = n + 1)
	argA[n] = rfoa[n];
always @*
for (n = 0; n < QSLOTS; n = n + 1)
	argB[n] = rfob[n];

generate begin : gDecoderInst
for (g = 0; g < IQ_ENTRIES; g = g + 1) begin
decoder7 iq0 (
	.num(iq_tgt[g]),
	.rfw(iq_rfw[g]),
	.out(iq_out2[g])
);
end
end
endgenerate

// Many instructions have am A source. It's only valid if the register is R0.
// So we default to FALSE for validity.
function SourceAValid;
input Instruction ins;
case(ins.gen.opcode)
`JAL_RN:	SourceAValid = ins.jalrn.Ra==4'h0;
`ADDIS,`ANDIS,`ORIS,
`PERM_3R,
`ADD_3R,`ADD_RI22,`ADD_RI35,
`SUB_3R,`SUB_RI22,`SUB_RI35,
`MUL_3R,`MUL_RI22,`MUL_RI35,
`AND_3R,`AND_RI22,`AND_RI35,
`OR_3R,`OR_RI22,`OR_RI35,
`EOR_3R,`EOR_RI22,`EOR_RI35:
	SourceAValid = ins.rr.Ra==5'd0;
`ASL_3R,`ASR_3R,`ROL_3R,`ROR_3R,`LSR_3R:
	SourceAValid = ins.rr.Ra==5'd0;
`BIT_3R,`BIT_RI22,`BIT_RI35,
`CMP_3R,`CMP_RI22,`CMP_RI35:
	SourceAValid = ins.rr.Ra==5'd0;
default:
	SourceAValid = FALSE;
endcase
endfunction

// Fewer instructions have a B source the B operand may also be an immediate
// value so it's usually automatically valid then.
// So the default is TRUE for validity.
function SourceBValid;
input Instruction ins;
case(ins.gen.opcode)
`PERM_3R,
`ADD_3R,`SUB_3R,`MUL_3R,
`AND_3R,`OR_3R,`EOR_3R:
	SourceBValid = ins.ri8.one || ins.rr.Rb==5'd0;
`ASL_3R,`ASR_3R,`ROL_3R,`ROR_3R,`LSR_3R:
	SourceBValid = ins.ri8.one || ins.rr.Rb==5'd0;
`BIT_3R,`CMP_3R:
	SourceBValid = ins.ri8.one || ins.rr.Rb==5'd0;
default:
	SourceBValid = TRUE;
endcase
endfunction

function IsMem;
input Instruction isn;
case(isn.gen.opcode)
`LD_D8,`LD_D22,`LD_D35,
`LDB_D8,`LDB_D22,`LDB_D35,
`ST_D8,`ST_D22,`ST_D35,
`STB_D8,`STB_D22,`STB_D35:
	IsMem = TRUE;
default:	IsMem = FALSE;
endcase
endfunction

function IsFlowCtrl;
input Instruction isn;
case(isn.gen.opcode)
`JAL,`JAL_RN,`BRANCH0,`BRANCH1:
	IsFlowCtrl = TRUE;
`BRKGRP:
	IsFlowCtrl = TRUE;
`RETGRP:
	IsFlowCtrl = TRUE;
`STPGRP:
	IsFlowCtrl = TRUE;
default:	IsFlowCtrl = FALSE;
endcase
endfunction

function IsRFW;
input Instruction isn;
case(isn.gen.opcode)
`NOP:	IsRFW = FALSE;
`BRANCH0,`BRANCH1:	IsRFW = FALSE;
`ST_D8,`ST_D22,`ST_D35,
`STB_D8,`STB_D22,`STB_D35:	IsRFW = FALSE;
default:	IsRFW = TRUE;
endcase
endfunction

function [3:0] fnSelect;
input Instruction isn;
case(isn.gen.opcode)
`LD_D8,`LD_D22,`LD_D35:			fnSelect = 4'b1111;
`LDB_D8,`LDB_D22,`LDB_D35:	fnSelect = 4'b0001;
`ST_D8,`ST_D22,`ST_D35:			fnSelect = 4'b1111;
`STB_D8,`STB_D22,`STB_D35:	fnSelect = 4'b0001;
default:	fnSelect = 4'b000;
endcase
endfunction

function Data fnDatiAlign;
input Address adr;
input [103:0] dat;
reg [103:0] adat;
begin
adat = dat >> (adr[3:0] * 13);
fnDatiAlign = adat[WID-1:0];
end
endfunction

function Data fnDataExtend;
input Instruction isn;
input Data dat;
case(isn.gen.opcode)
`LDB_D8,`LDB_D22,`LDB_D35:	fnDataExtend = {{39{dat[12]}},dat[12:0]};
default:	fnDataExtend = dat;
endcase
endfunction

// Simulation aid
function [31:0] fnMnemonic;
input Instruction ins;
case(ins.gen.opcode)
`ADD_3R,`ADD_RI22,`ADD_RI35:	fnMnemonic = "ADD ";
`SUB_3R,`SUB_RI22,`SUB_RI35:	fnMnemonic = "SUB ";
`CMP_3R,`CMP_RI22,`CMP_RI35:	fnMnemonic = "CMP ";
`OR_3R,`OR_RI22,`OR_RI35:	fnMnemonic = "OR  ";
`LD_D8,`LD_D22,`LD_D35:	
			fnMnemonic = "LD  ";
`ST_D8,`ST_D22,`ST_D35:		
			fnMnemonic = "ST  ";
`JAL,`JAL_RN:	
			fnMnemonic = "JAL ";
`BRANCH0,`BRANCH1:
			fnMnemonic = "BR  ";
`STPGRP:
	case(ins.stp.exop)
	`STP:	fnMnemonic = "STP ";
	`NOP:	fnMnemonic = "NOP ";
	`MRK:	fnMnemonic = "MRK ";
	default:	;
	endcase
default:	fnMnemonic = "????";
endcase
endfunction

initial begin
	panic = 4'd0;
end
/*
initial begin: Init
	//
	//
	// set up panic messages
	message[ `PANIC_NONE ]			= "NONE            ";
	message[ `PANIC_FETCHBUFBEQ ]		= "FETCHBUFBEQ     ";
	message[ `PANIC_INVALIDISLOT ]		= "INVALIDISLOT    ";
	message[ `PANIC_IDENTICALDRAMS ]	= "IDENTICALDRAMS  ";
	message[ `PANIC_OVERRUN ]		= "OVERRUN         ";
	message[ `PANIC_HALTINSTRUCTION ]	= "HALTINSTRUCTION ";
	message[ `PANIC_INVALIDMEMOP ]		= "INVALIDMEMOP    ";
	message[ `PANIC_INVALIDFBSTATE ]	= "INVALIDFBSTATE  ";
	message[ `PANIC_INVALIDIQSTATE ]	= "INVALIDIQSTATE  ";
	message[ `PANIC_BRANCHBACK ]		= "BRANCHBACK      ";
	message[ `PANIC_MEMORYRACE ]		= "MEMORYRACE      ";

end
*/
// Determine the head increment amount, this must match code later on.
always @*
begin
	hi_amt <= 3'd0;
	if (iq_v[heads[0]] && iq_state[heads[0]]==IQS_CMT) begin
		hi_amt <= 3'd1;
		if (iq_v[heads[1]] && iq_state[heads[1]]==IQS_CMT) begin
			hi_amt <= 3'd2;
			if (!iq_v[heads[2]] && heads[2] != tails[0])
				hi_amt <= 3'd3;
		end
	end
	else if (!iq_v[heads[0]]) begin
		if (heads[0] != tails[0]) begin
			hi_amt <= 3'd1;
			if (iq_v[heads[1]] && iq_state[heads[1]]==IQS_CMT) begin
				hi_amt <= 3'd2;
				if (!iq_v[heads[2]] && heads[2] != tails[0])
					hi_amt <= 3'd3;
			end
			else if (!iq_v[heads[1]]) begin
				if (heads[1] != tails[0]) begin
					hi_amt <= 3'd2;
					if (!iq_v[heads[2]]) begin
						if (heads[2] != tails[0]) begin
							hi_amt <= 3'd3;
						end
					end
				end
			end
		end
	end
end

//
// BRANCH-MISS LOGIC: livetarget
//
// livetarget implies that there is a not-to-be-stomped instruction that targets the register in question
// therefore, if it is zero it implies the rf_v value should become VALID on a branchmiss
// 

always @*
	for (n = 0; n < IQ_ENTRIES; n = n + 1)
		iq_livetarget[n] = {AREGS {iq_v[n]}} & {AREGS {~iq_stomp[n]}} & iq_out2[n];

always @*
for (j = 0; j < AREGS; j = j + 1) begin
	livetarget[j] = 1'b0;
	for (n = 0; n < IQ_ENTRIES; n = n + 1)
		livetarget[j] = livetarget[j] | iq_livetarget[n][j];
end

//
// BRANCH-MISS LOGIC: latestID
//
// latestID is the instruction queue ID of the newest instruction (latest) that targets
// a particular register.  looks a lot like scheduling logic, but in reverse.
// 
always @*
	for (n = 0; n < IQ_ENTRIES; n = n + 1) begin
		iq_cumulative[n] = 1'b0;
		for (j = n; j < n + IQ_ENTRIES; j = j + 1) begin
			if (missid==(j % IQ_ENTRIES))
				for (k = n; k <= j; k = k + 1)
					iq_cumulative[n] = iq_cumulative[n] | iq_livetarget[k % IQ_ENTRIES];
		end
	end

always @*
	for (n = 0; n < IQ_ENTRIES; n = n + 1)
    iq_latestID[n] = (missid == n || ((iq_livetarget[n] & iq_cumulative[(n+1)%IQ_ENTRIES]) == {AREGS{1'b0}}))
				    ? iq_livetarget[n]
				    : {AREGS{1'b0}};

always @*
	for (n = 0; n < IQ_ENTRIES; n = n + 1)
	  iq_source[n] = | iq_latestID[n];

//
// additional logic for ISSUE
//
// for the moment, we look at ALU-input buffers to allow back-to-back issue of 
// dependent instructions ... we do not, however, look ahead for DRAM requests 
// that will become valid in the next cycle.  instead, these have to propagate
// their results into the IQ entry directly, at which point it becomes issue-able
//

// note that, for all intents & purposes, iq_done == iq_agen ... no need to duplicate

wire [IQ_ENTRIES-1:0] args_valid;
wire [IQ_ENTRIES-1:0] could_issue;
wire [IQ_ENTRIES-1:0] could_issueid;

// Note that bypassing is provided only from the first fpu.
generate begin : issue_logic
for (g = 0; g < IQ_ENTRIES; g = g + 1)
begin
assign args_valid[g] =
		  (iq_argA_v[g]
`ifdef FU_BYPASS
        || (iq_argA_s[g] == alu0_rid && alu0_v)
        || ((iq_argA_s[g] == alu1_rid && alu1_v) && (`NUM_ALU > 1))
        || (iq_argA_s[g] == dramA_rid && dramA_v)
        || ((iq_argA_s[g] == dramB_rid && dramB_v) && (`NUM_MEM > 1))
`endif
        )
        // argA is a constant, it'll always be valid
    && (iq_argB_v[g] || iq_mem[g]	// a2 does not need to be valid immediately for a mem op (agen), it is checked by iq_memready logic
`ifdef FU_BYPASS
        || (iq_argB_s[g] == alu0_rid && alu0_v)
        || ((iq_argB_s[g] == alu1_rid && alu1_v) && (`NUM_ALU > 1))
        || (iq_argB_s[g] == dramA_rid && dramA_v)
        || ((iq_argB_s[g] == dramB_rid && dramB_v) && (`NUM_MEM > 1))
`endif
        )
    ;

assign could_issue[g] = iq_state[g]==IQS_QUEUED	&& args_valid[g];
                        //&& (iq_mem[g] ? !iq_agen[g] : 1'b1);

assign could_issueid[g] = (iq_state[g]!=IQS_INVALID);// || (g==tails[0] && canq1))// || (g==tails[1] && canq2))
end                                 
end
endgenerate

// Detect if there are any valid queue entries prior to the given queue entry.
initial begin
	j = 0;
end
reg [IQ_ENTRIES-1:0] prior_valid;
//generate begin : gPriorValid
always @*
begin
prior_valid = 1'd0;
for (j = 0; j < IQ_ENTRIES; j = j + 1)
begin
	prior_valid[heads[j]] = 1'b0;
	if (j > 0)
		for (n = j-1; n >= 0; n = n - 1)
			if (iq_sn[heads[n]] < iq_sn[heads[j]])
				prior_valid[heads[j]] = prior_valid[heads[j]]|iq_v[heads[n]];
end
end

//end
//endgenerate

// Detect if there are any valid sync instructions prior to the given queue 
// entry.
reg [IQ_ENTRIES-1:0] prior_sync;
//generate begin : gPriorSync
always @*
for (j = 0; j < IQ_ENTRIES; j = j + 1)
begin
	prior_sync[heads[j]] = 1'b0;
	if (j > 0)
		for (n = j-1; n >= 0; n = n - 1)
			if (iq_sn[heads[n]] < iq_sn[heads[j]])
				prior_sync[heads[j]] = prior_sync[heads[j]]|(iq_v[heads[n]] & iq_sync[heads[n]]);
end
//end
//endgenerate

//end
//endgenerate
aluIssue ualui1
(
	.heads(heads),
	.could_issue(could_issue),
	.alu0_idle(alu0_idle),
	.alu1_idle(alu1_idle),
	.iq_alu(iq_alu),
	.iq_alu0(iq_alu0),
	.prior_sync(prior_sync),
	.prior_valid(prior_valid),
	.issue0(iq_alu0_issue),
	.issue1(iq_alu1_issue)
);

always @*
begin
issuing_on_alu0 = FALSE;
for (n = 0; n < IQ_ENTRIES; n = n + 1)
	if (iq_alu0_issue[n] && !(iq_v[n] && iq_stomp[n])
												&& (alu0_done))
		issuing_on_alu0 = TRUE;
end

always @*
begin
issuing_on_alu1 = FALSE;
for (n = 0; n < IQ_ENTRIES; n = n + 1)
	if (iq_alu1_issue[n] && !(iq_v[n] && iq_stomp[n])
												&& (alu1_done))
		issuing_on_alu1 = TRUE;
end

reg issuing_on_agen0;
always @*
begin
issuing_on_agen0 = FALSE;
for (n = 0; n < IQ_ENTRIES; n = n + 1)
	if (iq_agen0_issue[n] && !(iq_v[n] && iq_stomp[n]))
		issuing_on_agen0 = TRUE;
end

reg issuing_on_agen1;
always @*
begin
issuing_on_agen1 = FALSE;
for (n = 0; n < IQ_ENTRIES; n = n + 1)
	if (iq_agen1_issue[n] && !(iq_v[n] && iq_stomp[n]))
		issuing_on_agen1 = TRUE;
end

reg issuing_on_fcu;
always @*
begin
issuing_on_fcu = FALSE;
for (n = 0; n < IQ_ENTRIES; n = n + 1)
	if (iq_fcu_issue[n] && !(iq_v[n] && iq_stomp[n]) && fcu_done)
		issuing_on_fcu = TRUE;
end

agenIssue uqgi1
(
	.agen0_idle(agen0_idle),
	.agen1_idle(agen1_idle),
	.heads(heads),
	.could_issue(could_issue),
	.iq_mem(iq_mem),
	.prior_sync(prior_sync), 
	.prior_valid(prior_valid),
	.issue0(iq_agen0_issue),
	.issue1(iq_agen1_issue)
);

Qid nid;

fcuIssue ufcui1
(
	.heads(heads),
	.branchmiss(branchmiss),
	.could_issue(could_issue),
	.fcu_id(fcu_id),
	.fcu_done(fcu_done),
	.iq_fc(iq_fc),
	.iq_br(iq_br),
	.iq_state(iq_state),
	.iq_sn(iq_sn),
	.prior_sync(prior_sync),
	.prior_valid(prior_valid),
	.issue(iq_fcu_issue),
	.nid(nid)
);

// Test if a given address is in the write buffer. This is done only for the
// first two queue slots to save logic on comparators.
reg inwb0;
always @*
begin
	inwb0 = FALSE;
	for (n = 0; n < `WB_DEPTH; n = n + 1)
		if (iq_ma[heads[0]][AMSB:4]==wb_addr[n][AMSB:4] && wb_v[n])
			inwb0 = TRUE;
end

reg inwb1;
always @*
begin
	inwb1 = FALSE;
	for (n = 0; n < `WB_DEPTH; n = n + 1)
		if (iq_ma[heads[1]][AMSB:4]==wb_addr[n][AMSB:4] && wb_v[n])
			inwb1 = TRUE;
end

always @*
begin
	for (n = 0; n < IQ_ENTRIES; n = n + 1) begin
		iq_v[n] = iq_state[n] != IQS_INVALID;
		iq_done[n] = iq_state[n]==IQS_DONE || iq_state[n]==IQS_CMT;
		iq_out[n] = iq_state[n]==IQS_OUT;
		iq_agen[n] = iq_state[n]==IQS_AGEN;
	end
end

// determine if the instructions ready to issue can, in fact, issue.
// "ready" means that the instruction has valid operands but has not gone yet
memissueLogic umi1
(
	.heads(heads),
	.iq_v(iq_v),
	.iq_memready(iq_memready),
	.iq_out(iq_out),
	.iq_done(iq_done),
	.iq_mem(iq_mem),
	.iq_agen(iq_agen), 
	.iq_load(iq_load),
	.iq_store(iq_store),
	.iq_sel(iq_sel),
	.iq_fc(iq_fc),
	.iq_aq({IQ_ENTRIES{1'b0}}),
	.iq_rl({IQ_ENTRIES{1'b0}}),
	.iq_ma(iq_ma),
	.iq_memsb({IQ_ENTRIES{1'b0}}),
	.iq_memdb({IQ_ENTRIES{1'b0}}),
	.iq_stomp(iq_stomp),
	.iq_canex({IQ_ENTRIES{1'b0}}), 
	.wb_v(wb_v),
	.inwb0(inwb0),
	.inwb1(inwb1),
	.sple(sple),
	.memissue(memissue),
	.issue_count(issue_count)
);

memissueSelect umis1
(	
	.heads(heads),
	.iq_stomp(iq_stomp),
	.iq_memissue(iq_memissue),
	.iq_state(iq_state),
	.dram0(dram0),
	.dram1(dram1),
	.issue0(last_issue0),
	.issue1(last_issue1)
);

stompLogic usl1
(
	.branchmiss(branchmiss),
	.misssn(misssn),
	.iq_sn(iq_sn),
	.iq_stomp(iq_stomp)
);

always @*
begin
	stompedOnRets = 1'b0;
//	for (n = 0; n < IQ_ENTRIES; n = n + 1)
//		if (iq_stomp[n] && iq_rts[n])
//			stompedOnRets = stompedOnRets + 4'd1;
end

EvalBranch ube1
(
	.instr(fcu_instr.raw),
	.a(fcu_argA),
	.takb(fcu_takb)
);


/*
wire will_clear_branchmiss = branchmiss && (
															(uoq_slotv[0] && uoq_pc[uoq_head]==misspc)
															|| (uoq_slotv[1] && uoq_pc[(uoq_head + 2'd1) % UOQ_ENTRIES]==misspc)
															|| (uoq_slotv[2] && uoq_pc[(uoq_head + 2'd2) % UOQ_ENTRIES]==misspc)
															);
*/													
wire will_clear_branchmiss = branchmiss && (pc==misspc);

always @*
case(fcu_instr.gen.opcode)
`BRKGRP:	fcu_misspc = RSTIP;
`RETGRP:	fcu_misspc = fcu_argA;
`JAL:			fcu_misspc = {fcu_pc[`AMSB:43],fcu_argI[42:0]};
`JAL_RN:	fcu_misspc = fcu_argA;
default:
	// The length of the branch instruction is hardcoded here.
	fcu_misspc = fcu_pt ? (fcu_pc + 2'd2) : (fcu_pc + fcu_brdisp + 2'd2);
endcase

// To avoid false branch mispredicts the branch isn't evaluated until the
// following instruction queues. The address of the next instruction is
// looked at to see if the BTB predicted correctly.

`ifdef FCU_ENH
wire fcu_followed = iq_sn[nid] > iq_sn[fcu_id];
`else
wire fcu_followed = `TRUE;
`endif
always @*
if (fcu_v) begin
	// Break and RTI switch register sets, and so are always treated as a branch miss in order to
	// flush the pipeline. Hardware interrupts also stream break instructions so they need to 
	// flushed from the queue so the interrupt is recognized only once.
	// BRK and RTI are handled as excmiss types which are processed during the commit stage.
	fcu_branchhit <= (fcu_branch && !(fcu_takb ^ fcu_pt));
	if (fcu_branch && (fcu_takb ^ fcu_pt))
    fcu_branchmiss = TRUE;
	else if (fcu_instr.jal.opcode==`JAL || fcu_instr.ret.opcode==`RETGRP || fcu_instr.wai.opcode==`BRKGRP) begin
		if (fcu_followed)
			fcu_branchmiss = iq_pc[nid]!=fcu_misspc;
		else
			fcu_branchmiss = TRUE;
	end
	else
    fcu_branchmiss = FALSE;
end
else
	fcu_branchmiss = FALSE;

// A holdover from nvio3 - not really needed here.
assign pc_mask = 2'b11;

//
// additional DRAM-enqueue logic

assign dram_avail = (dram0 == `DRAMSLOT_AVAIL || dram1 == `DRAMSLOT_AVAIL);

always @*
for (n = 0; n < IQ_ENTRIES; n = n + 1)
	iq_memopsvalid[n] <= (iq_mem[n] && (iq_store[n] ? iq_argA_v[n] : 1'b1) && iq_state[n]==IQS_AGEN);

always @*
for (n = 0; n < IQ_ENTRIES; n = n + 1)
	iq_memready[n] <= (iq_v[n] & iq_memopsvalid[n] & ~iq_memissue[n] & ~iq_stomp[n]);

assign outstanding_stores = (dram0 && dram0_store) ||
                            (dram1 && dram1_store);

//
// additional COMMIT logic
//

always @*
begin
	// The first commit bus is always tied to the same place
  commit0_v <= (iq_state[heads[0]] == IQS_CMT && ~|panic);
  commit0_id <= heads[0];	// if a memory op, it has a DRAM-bus id
  commit0_tgt <= rob.robEntries[heads[0]].tgt;
  commit0_rfw <= rob.robEntries[heads[0]].rfw;
  commit0_bus <= rob.robEntries[heads[0]].res;
  commit0_rid <= heads[0];

  commit1_v <= (hi_amt > 3'd1
             && iq_state[heads[1]] == IQS_CMT
             && ~|panic);
	commit1_id <= heads[1];
  commit1_tgt <= rob.robEntries[heads[1]].tgt;
  commit1_rfw <= rob.robEntries[heads[1]].rfw;
  commit1_bus <= rob.robEntries[heads[1]].res;
  commit1_rid <= heads[1];

end

assign int_commit = (commit0_v && iq_instr[heads[0]].wai.opcode==`BRKGRP && iq_instr[heads[0]].wai.exop > 2'd0)
									 || (hi_amt > 3'd1 && commit1_v && iq_instr[heads[1]].wai.opcode==`BRKGRP && iq_instr[heads[0]].wai.exop > 2'd0)
										;

//wire [143:0] id_bus[0], id_bus[1], id_bus[2];

generate begin : idecoders
for (g = 0; g < QSLOTS; g = g + 1)
begin
idecoder uid1
(
	.instr(insnx[g]),
	.predict_taken(predict_taken[g]),
	.bus(id_bus[g])
);
end
end
endgenerate

reg [51:0] csr_r;
wire [11:0] csrno = alu0_instr.csr.regno;
always @*
begin
    if (alu0_instr.csr.ol >= ol)
    casez(csrno[11:0])
    `CSR_CR0:       csr_r <= cr0;
    `CSR_HARTID:    csr_r <= hartid_i;
    `CSR_TICK:      csr_r <= tick;
//    `CSR_WBRCD:		csr_r <= wbrcd;
    `CSR_SEMA:      csr_r <= sema;
`ifdef SUPPORT_DBG    
    `CSR_DBAD0:     csr_r <= dbg_adr0;
    `CSR_DBAD1:     csr_r <= dbg_adr1;
    `CSR_DBAD2:     csr_r <= dbg_adr2;
    `CSR_DBAD3:     csr_r <= dbg_adr3;
    `CSR_DBCTRL:    csr_r <= dbg_ctrl;
    `CSR_DBSTAT:    csr_r <= dbg_stat;
`endif   
    `CSR_BADADR:    csr_r <= badaddr[alu0_instr.csr.ol];
    `CSR_BADINST:		csr_r <= bad_instr[alu0_instr.csr.ol];
    `CSR_CAUSE:     csr_r <= {38'd0,cause[alu0_instr.csr.ol]};
   	`CSR_DOI_STACK:	csr_r <= {7'd0,dl_stack,ol_stack,im_stack};
    `CSR_PL_STACKL:	csr_r <= pl_stack[51:0];
    `CSR_PL_STACKH:	csr_r <= pl_stack[103:52];
    `CSR_STATUS:    csr_r <= status;
    `CSR_IPC0:      csr_r <= ipc[0];
    `CSR_IPC1:      csr_r <= ipc[1];
    `CSR_IPC2:      csr_r <= ipc[2];
    `CSR_IPC3:      csr_r <= ipc[3];
    `CSR_IPC4:      csr_r <= ipc[4];
    `CSR_TIME_FRAC:		csr_r <= wc_time_frac;
    `CSR_TIME_SECS:		csr_r <= wc_time_secs;
    `CSR_INFO:
                    case(csrno[3:0])
                    4'd0:   csr_r <= "Finitr";  // manufacturer
                    4'd1:   csr_r <= "on    ";
                    4'd2:   csr_r <= "52 bit";  // CPU class
                    4'd3:   csr_r <= "      ";
                    4'd4:   csr_r <= "Gambit";  // Name
                    4'd5:   csr_r <= "      ";
                    4'd6:   csr_r <= 52'd1;       // model #
                    4'd7:   csr_r <= 52'd1;       // serial number
                    4'd8:   csr_r <= {26'd16384,26'd16384};   // cache sizes instruction,csr_ra
                    4'd9:   csr_r <= 52'd0;
                    default:    csr_r <= 52'd0;
                    endcase
    default:    begin    
    			$display("Unsupported CSR:%h",csrno);
    			csr_r <= 52'hEEEEEEEEEEEEEEEE;
    			end
    endcase
    else
        csr_r <= 52'h0;
end

alu ualu1
(
	.op(alu0_instr),
	.a(alu0_argA),
	.imm(alu0_argI),
	.b(alu0_argB),
	.o(alu0_bus),
	.csr_i(csr_r),
	.idle(alu0_idle)
);

alu ualu2
(
	.op(alu1_instr),
	.a(alu1_argA),
	.imm(alu1_argI),
	.b(alu1_argB),
	.o(alu1_bus),
	.csr_i(52'h0),
	.idle(alu1_idle)
);

agen uagn1
(
	.src1(agen0_argI),
	.src2(agen0_argA),
	.ma(agen0_ma),
	.idle(agen0_idle)
);

agen uagn2
(
	.src1(agen1_argI),
	.src2(agen1_argA),
	.ma(agen1_ma),
	.idle(agen1_idle)
);

wire [WID-1:0] ralu0_bus = alu0_bus;
wire [WID-1:0] ralu1_bus = alu1_bus;
wire [WID-1:0] rfcu_bus  = fcu_bus;
wire [WID-1:0] rdramA_bus = dramA_bus;
wire [WID-1:0] rdramB_bus = dramB_bus;


BusChannel mwhich;
wire [3:0] mstate;

extBusArbiter ueba1
(
	.rst(rst_i),
	.clk(clk),
	.cyc(cyc),
	.ack_i(ack_i),
	.icyc(icyc),
	.wb_has_bus(wb_has_bus),
	.d0cyc(d0cyc),
	.d1cyc(d1cyc),
	.dcyc(dcyc),
	.mwhich(mwhich),
	.mstate(mstate)
);

always @(posedge clk)
case(mwhich)
BC_ICACHE:
	begin
		cti_o <= icti;
		bte_o <= ibte;
		cyc <= icyc;
		stb <= istb;
		we <= 1'b0;
		sel_o <= isel;
		vadr <= iadr;
	end
BC_WRITEBUF:
	begin
		cti_o <= 3'b000;
		bte_o <= 2'b00;
		cyc <= wcyc;
		stb <= wstb;
		we <= wwe;
		sel_o <= wsel;
		vadr <= wadr;
		dat_o <= wdat;
	end
BC_DCACHE0:
	begin
		cti_o <= d0cti;
		bte_o <= d0bte;
		cyc <= d0cyc;
		stb <= d0stb;
		we <= `LOW;
		sel_o <= d0sel;
		vadr <= d0adr;
	end
BC_DCACHE1:
	begin
		cti_o <= d1cti;
		bte_o <= d1bte;
		cyc <= d1cyc;
		stb <= d1stb;
		we <= `LOW;
		sel_o <= d1sel;
		vadr <= d1adr;
	end
BC_UNCDATA:
	begin
		cti_o <= 3'b000;
		bte_o <= 2'b00;
		cyc <= dcyc;
		stb <= dstb;
		we <= dwe;
		sel_o <= dsel;
		vadr <= {dadr[AMSB:4],4'h0};
		dat_o <= ddat;
	end
BC_NULL:
	begin
		cti_o <= 3'b000;
		bte_o <= 2'b00;
		cyc <= 1'b0;
		stb <= 1'b0;
		we <= 1'b0;
		sel_o <= 16'h0;
		vadr <= 1'h0;
		dat_o <= 1'h0;
	end
endcase
assign cyc_o = cyc;
assign stb_o = stb;
assign we_o = we;
assign adr_o = vadr;

always @*
case(mwhich)
BC_ICACHE:
	begin
		iack_i <= ack_i;
		ierr_i <= err_i;
		iexv_i <= exv;
	end
BC_WRITEBUF:
	begin
		wack_i <= ack_i;
		werr_i <= err_i;
		wwrv_i <= wrv_i;
		wrdv_i <= rdv_i;
		wtlbmiss_i <= tlb_miss;
	end
BC_DCACHE0:
	begin
		d0ack_i <= ack_i;
		d0err_i <= err_i;
		d0wrv_i <= wrv_i;
		d0rdv_i <= rdv_i;
	end
BC_DCACHE1:
	begin
		d1ack_i <= ack_i;
		d1err_i <= err_i;
		d1wrv_i <= wrv_i;
		d1rdv_i <= rdv_i;
	end
BC_UNCDATA:
	begin
		dack_i <= ack_i;
		derr_i <= err_i;
//		dwrv_i <= wrv_i;
//		drdv_i <= rdv_i;
	end
default:
	begin
		iack_i <= `LOW;
		ierr_i <= `LOW;
		iexv_i <= `LOW;
		wack_i <= `LOW;
		werr_i <= `LOW;
		wwrv_i <= `LOW;
		wrdv_i <= `LOW;
		wtlbmiss_i <= `LOW;
		d0ack_i <= `LOW;
		d0err_i <= `LOW;
		d0wrv_i <= `LOW;
		d0rdv_i <= `LOW;
		d1ack_i <= `LOW;
		d1err_i <= `LOW;
		d1wrv_i <= `LOW;
		d1rdv_i <= `LOW;
		dack_i <= `LOW;
		derr_i <= `LOW;
	end
endcase

// Hold reset for five seconds
always @(posedge clk)
if (rst_i)
	rst_ctr <= 32'd0;
else begin
	if (~rst_ctr[`RSTC_BIT])
		rst_ctr <= rst_ctr + 2'd1;
end

slotValid usv1
(
	.rst(rst_i),
	.clk(clk),
	.branchmiss(branchmiss),
	.phit(phit),
	.nextb(nextb),
	.pc_mask(pc_mask),
	.pc_maskd(pc_maskd),
	.pc_override(pc_override),
	.q1(1'b0),
	.q2(nextb),//q2),
	.slot_jc(slot_jc),
	.slot_rts(slot_rts),
	.take_branch(take_branch),
	.slotv(slotv),
	.slotvd(slotvd),
	.debug_on(debug_on)
);

always @(posedge clk_i)
if (rst_i) begin
	ins_stomped = 0;
end
else begin
	for (n = 0; n < IQ_ENTRIES; n = n + 1)
		ins_stomped = ins_stomped + iq_stomp[n];
end

always @(posedge clk_i)
if (rst_i)
	ins_committed <= 0;
else begin
	ins_committed <= ins_committed + commit0_v + commit1_v;
end


always @(posedge clk_i)
if (rst_i)
	br_missed <= 0;
else
	br_missed <= br_missed + (fcu_branch & fcu_branchmiss);
always @(posedge clk_i)
if (rst_i)
	br_total <= 0;
else
	br_total <= br_total + (fcu_branch & fcu_v);


always @(posedge tm_clk_i)
begin
	if (|ld_time)
		wc_time <= {wc_time_secs,wc_time_frac};
	else begin
		wc_time[39:0] <= wc_time[39:0] + 32'd1;
		if (wc_time[39:0] >= TM_CLKFREQ-1) begin
			wc_time[39:0] <= 32'd0;
			wc_time[79:40] <= wc_time[79:40] + 32'd1;
		end
	end
end


//wire pe_branchmiss;
//edge_det ubmed1 (.rst(rst_i), .clk(clk), .ce(1'b1), .i(branchmiss), .pe(pe_branchmiss), .ne(), .ee());

always @(posedge clk_i)
if (rst_i) begin
	tick <= 0;
	uop_queued <= 0;
	ins_queued <= 0;
	q1b <= FALSE;
  for (n = 0; n < IQ_ENTRIES; n = n + 1) begin
  	iq_state[n] <= IQS_INVALID;
		iq_sn[n] <= n;
		iq_pt[n] <= FALSE;
		iq_bt[n] <= FALSE;
		iq_br[n] <= FALSE;
		iq_alu[n] <= FALSE;
		iq_fc[n] <= FALSE;
		iq_takb[n] <= FALSE;
		iq_jmp[n] <= FALSE;
		iq_load[n] <= FALSE;
		iq_rfw[n] <= FALSE;
		iq_pc[n] <= 52'h00E000;
		iq_instr[n] <= 52'h00;	// `UO_NOP
		iq_mem[n] <= FALSE;
		iq_memissue[n] <= FALSE;
		iq_mem_islot[n] <= 3'd0;
		iq_sel[n] <= 1'd0;
//		iq_memdb[n] <= 1'd0;
//		iq_memsb[n] <= 1'd0;
//		iq_aq[n] <= 1'd0;
//		iq_rl[n] <= 1'd0;
		iq_canex[n] <= 1'd0;
		iq_tgt[n] <= 6'd0;
		iq_imm[n] <= 1'b0;
		iq_ma[n] <= 1'b0;
		iq_argA[n] <= 64'd0;
		iq_argB[n] <= 64'd0;
		iq_argA_v[n] <= `INV;
		iq_argB_v[n] <= `INV;
		iq_argA_s[n] <= 5'd0;
		iq_argB_s[n] <= 5'd0;
		iq_fl[n] <= 2'b00;
		iq_rid[n] <= 3'd0;
  end
  	 //rob.reset();
     bwhich <= 2'b00;
     dram0 <= `DRAMSLOT_AVAIL;
     dram1 <= `DRAMSLOT_AVAIL;
//     dram0_instr <= `UO_NOP;
//     dram1_instr <= `UO_NOP;
     dram0_addr <= 32'h0;
     dram1_addr <= 32'h0;
     dram0_id <= 1'b0;
     dram1_id <= 1'b0;
     dram0_rid <= 1'd0;
     dram1_rid <= 1'd0;
     dram0_load <= 1'b0;
     dram1_load <= 1'b0;
     dram0_unc <= 1'b0;
     dram1_unc <= 1'b0;
     dram0_store <= 1'b0;
     dram1_store <= 1'b0;
     invic <= FALSE;
     invicl <= FALSE;
     alu0_dataready <= 1'b1;
     alu1_dataready <= 1'b1;
     alu0_sourceid <= 5'd0;
     alu1_sourceid <= 5'd0;
`define SIM_
`ifdef SIM_
		alu0_pc <= RSTIP;
//		alu0_instr <= `UO_NOP;
		alu0_argT <= 16'h0;
		alu0_argA <= 1'h0;
		alu0_argB <= 1'h0;
		alu0_argI <= 16'h0;
		alu0_mem <= 1'b0;
		alu0_shft <= 1'b0;
		alu0_tgt <= 3'h0;
		alu0_rid <= {RBIT{1'b1}};
		alu1_pc <= RSTIP;
//		alu1_instr <= `UO_NOP;
		alu1_argT <= 16'h0;
		alu1_argA <= 1'h0;
		alu1_argB <= 1'h0;
		alu1_argI <= 16'h0;
		alu1_mem <= 1'b0;
		alu1_shft <= 1'b0;
		alu1_tgt <= 3'h0;  
		alu1_rid <= {RBIT{1'b1}};
		agen0_argT <= 1'd0;
		agen0_argB <= 1'd0;
		agen0_argA <= 1'd0;
		agen0_dataready <= FALSE;
		agen1_argT <= 1'd0;
		agen1_argB <= 1'd0;
		agen1_argA <= 1'd0;
		agen1_dataready <= FALSE;
		fcu_branch <= 1'd0;
		fcu_id <= 1'd0;
`endif
     fcu_dataready <= 0;
//     fcu_instr <= `UO_NOP;
     dramA_v <= 0;
     dramB_v <= 0;
     I <= 0;
     CC <= 0;
     bstate <= BIDLE;
     cyc_pending <= `LOW;
     fcu_done <= `TRUE;
     wb_en <= `TRUE;
//		iq_ctr <= 40'd0;
//		bm_ctr <= 40'd0;
//		br_ctr <= 40'd0;
//		irq_ctr <= 40'd0;
		StoreAck1 <= `FALSE;
		dcyc <= `LOW;
		dstb <= `LOW;
		dwe <= `LOW;
		dsel <= 8'h00;
		dadr <= RSTIP;
		ddat <= 128'h0;
		regs[31] <= 52'h01FFC;
		msp <= 52'h01FFC;
		ol_stack <= 2'b00;
		dl_stack <= 2'b00;
		pl_stack <= 2'd0;
		cr0[30] = 1'b1;
end
else begin

	// Register file updates
	for (n = 1; n < 32; n = n + 1)
		regs[n] <= regsx[n];
		
	for (n = 0; n < 5; n = n + 1)
		lkregs[n] <= lkregsx[n];

	for (n = 0; n < 8; n = n + 1)
		crregs[n] <= crregsx[n];

	msp <= mspx;
	hsp <= hspx;
	ssp <= sspx;

//	if (|fb_panic)
//		panic <= fb_panic;

	// Only one branchmiss is allowed to be processed at a time. If a second 
	// branchmiss occurs while the first is being processed, it would have
	// to of occurred as a speculation in the branch shadow of the first.
	// The second instruction would be stomped on by the first branchmiss so
	// there is no need to process it.
	// The branchmiss has to be latched, then cleared later as there could
	// be a cache miss at the same time meaning the switch to the new pc
	// does not take place immediately.
	if (!branchmiss) begin
		if (excmiss) begin
			branchmiss <= `TRUE;
			misspc <= excmisspc;
			missid <= (|iq_exc[heads[0]] ? heads[0] : heads[1]);
			misssn <= (|iq_exc[heads[0]] ? iq_sn[heads[0]] : iq_sn[heads[1]]);
		end
		else
		if (fcu_branchmiss) begin
			branchmiss <= `TRUE;
			misspc <= fcu_misspc;
			missid <= fcu_sourceid;
			misssn <= iq_sn[fcu_sourceid];
		end
	end

	// Clear a branch miss when target instruction is fetched.
	if (will_clear_branchmiss) begin
		branchmiss <= `FALSE;
	end

	// The following signals only pulse

	// Instruction decode output should only pulse once for a queue entry. We
	// want the decode to be invalidated after a clock cycle so that it isn't
	// inadvertently used to update the queue at a later point.
	dramA_v <= `INV;
	dramB_v <= `INV;
	ld_time <= {ld_time[4:0],1'b0};
//	wc_times <= wc_time;

	invic <= FALSE;
	if (L1_invline)
		invicl <= FALSE;
	invdcl <= FALSE;
	tick <= tick + 4'd1;
	alu0_ld <= FALSE;
	alu1_ld <= FALSE;
	fcu_ld <= FALSE;
	queuedOn <= 1'b0;
	ins_queued <= ins_queued + queuedCnt;

  if (waitctr != 48'd0)
		waitctr <= waitctr - 4'd1;

	for (n = 0; n < QSLOTS; n = n + 1)
		if (tails[(n+1)%IQ_ENTRIES] != (tails[n] + 1) % IQ_ENTRIES) begin
			$display("Tails out of sync");
			$stop;
		end

	if (!branchmiss) begin
		queuedOn <= queuedOnp;
		if (queuedOnp[0]) begin
			queue_slot(0,tails[0],{tick[`SNBITS],1'b0},id_bus[0],tails[0]);
			if (queuedOnp[1]) begin
				queue_slot(1,tails[1],{tick[`SNBITS],1'b1},id_bus[1],tails[1]);
				arg_vs(2'b11);
			end
		end
		else if (queuedOnp[1]) begin
			queue_slot(1,tails[0],{tick[`SNBITS],1'b0},id_bus[1],tails[0]);
		end
	end

	if (alu0_v) begin
		rob.robEntries[ alu0_rid % RENTRIES ].res <= ralu0_bus;
		rob.robEntries[ alu0_rid % RENTRIES ].exc <= 4'h0;
	//	if (alu0_done) begin
			if (iq_state[alu0_rid % RENTRIES]==IQS_OUT) begin
				iq_state[alu0_id % IQ_ENTRIES] <= IQS_CMT;
				rob.robEntries[alu0_rid % RENTRIES].state <= RS_CMT;
			end
	//	end
		alu0_dataready <= FALSE;
	end

	if (alu1_v && `NUM_ALU > 1) begin
		rob.robEntries[ alu1_rid % RENTRIES ].res <= ralu1_bus;
		rob.robEntries[ alu1_rid % RENTRIES ].exc <= alu1_exc;
	//	if (alu1_done) begin
			if (iq_state[ alu1_rid % RENTRIES ]==IQS_OUT) begin
				iq_state[alu1_id % IQ_ENTRIES] <= IQS_CMT;
				rob.robEntries[ alu1_rid % RENTRIES ].state <= RS_CMT;
			end
	//	end
		alu1_dataready <= FALSE;
	end

	if (agen0_v) begin
		if (iq_state[agen0_id]==IQS_OUT)
			iq_state[agen0_id] <= IQS_AGEN;
		rob.robEntries[agen0_rid].res <= 1'h0;//agen1_ma;		// LEA needs this result
		rob.robEntries[agen0_rid].exc <= 4'h0;
		if (iq_state[agen0_id]==IQS_OUT) begin
			iq_ma[agen0_id] <= agen0_ma;
			iq_sel[agen0_id] <= fnSelect(agen0_instr) << agen0_ma[3:0];
		end
		agen0_dataready <= FALSE;
	end

	if (agen1_v && `NUM_AGEN > 1) begin
		if (iq_state[agen1_id]==IQS_OUT)
			iq_state[agen1_id] <= IQS_AGEN;
		rob.robEntries[agen1_rid].res <= 1'h0;//agen1_ma;		// LEA needs this result
		rob.robEntries[agen1_rid].exc <= 4'h0;
		if (iq_state[agen1_id]==IQS_OUT) begin
			iq_ma[agen1_id] <= agen1_ma;
			iq_sel[agen1_id] <= fnSelect(agen1_instr) << agen1_ma[3:0];
		end
		agen1_dataready <= FALSE;
	end

	if (fcu_v) begin
		fcu_done <= `TRUE;
		//fcu_sr_bus <= fcu_argS;
		//rob_sr_res[fcu_id] <= fcu_argS;
		//iq_ma  [ fcu_id ] <= fcu_misspc;
	  rob.robEntries[ fcu_rid ].res <= rfcu_bus;
	  rob.robEntries[ fcu_rid ].exc <= fcu_exc;
		if (iq_state[fcu_id]==IQS_OUT) begin
			iq_state[fcu_id ] <= IQS_CMT;
			rob.robEntries[fcu_rid ].state <= RS_CMT;
		end
		// takb is looked at only for branches to update the predictor. Here it is
		// unconditionally set, the value will be ignored if it's not a branch.
		iq_takb[ fcu_id ] <= fcu_takb;
		iq_ma [ fcu_id ] <= fcu_misspc;
		//br_ctr <= br_ctr + fcu_branch;
		fcu_dataready <= `INV;
	end

	// dramX_v only set on a load
	if (dramA_v && iq_v[ dramA_id ]) begin
		rob.robEntries[ dramA_rid ].res <= rdramA_bus;
		rob.robEntries[ dramA_rid ].state <= RS_CMT;
		iq_state[dramA_id ] <= IQS_CMT;
	end
	if (`NUM_MEM > 1 && dramB_v && iq_v[ dramB_id ]) begin
		rob.robEntries[ dramB_rid ].res <= rdramB_bus;
		rob.robEntries[ dramB_rid ].state <= RS_CMT;
		iq_state[dramB_id ] <= IQS_CMT;
	end

	if (wb_q0_done) begin
		dram0 <= `DRAMREQ_READY;
		iq_state[ dram0_id ] <= IQS_DONE;
	end
	if (wb_q1_done) begin
		dram1 <= `DRAMREQ_READY;
		iq_state[ dram1_id ] <= IQS_DONE;
	end

	if (update_iq) begin
		for (n = 0; n < RENTRIES; n = n + 1) begin
			if (ruid[n]) begin
	      rob.robEntries[n].exc <= wb_fault;
	     	rob.robEntries[n].state <= RS_CMT;
			end
		end
	end
	if (update_iq) begin
		for (n = 0; n < IQ_ENTRIES; n = n + 1) begin
			if (uid[n]) begin
				iq_state[n] <= IQS_CMT;
			end
		end
	end

//
// see if anybody else wants the results ... look at lots of buses:
//  - fpu_bus
//  - alu0_bus
//  - alu1_bus
//  - fcu_bus
//  - dram_bus
//  - commit0_bus
//  - commit1_bus
//

// More bypassing from one queue result to another queue entrys args.
// Boosts performance quite a bit, and also the core size.
`ifdef QBYPASSING
	setargs2();
`endif

	for (n = 0; n < IQ_ENTRIES; n = n + 1)
	begin
		setargs(n,{1'b0,commit0_id},commit0_v & commit0_rfw,commit0_bus);
		setargs(n,{1'b0,commit1_id},commit1_v & commit1_rfw,commit1_bus);

		setargs(n,{1'b0,alu0_rid},alu0_v,ralu0_bus);
		if (`NUM_ALU > 1)
			setargs(n,{1'b0,alu1_rid},alu1_v,ralu1_bus);

//		setargs(n,{1'b1,agen0_rid},agen0_v & agen0_mem2,agen0_res);
//		if (`NUM_AGEN > 1) begin
//			setargs(n,{1'b1,agen1_rid},agen1_v & agen1_mem2,agen1_res);
//		end

		setargs(n,{1'b0,fcu_rid},fcu_v,rfcu_bus);

		setargs(n,{1'b0,dramA_rid},dramA_v,rdramA_bus);
		if (`NUM_MEM > 1)
			setargs(n,{1'b0,dramB_rid},dramB_v,rdramB_bus);
			
	end

// Argument loading for functional units.
// X's on unused busses cause problems in SIM.
  for (n = 0; n < IQ_ENTRIES; n = n + 1)
    if (iq_alu0_issue[n] && !(iq_v[n] && iq_stomp[n])
										&& (alu0_done)) begin
			iq_fuid[n] <= 3'd0;
			alu0_sourceid	<= n[`QBITS];
			if (alu1_rid==n[`QBITS] && !issuing_on_alu1)
				alu1_rid <= {`QBIT{1'b1}};
			if (agen0_rid==n[`QBITS] && !issuing_on_agen0)
				agen0_rid <= {`QBIT{1'b1}};
			if (agen1_rid==n[`QBITS] && !issuing_on_agen1)
				agen1_rid <= {`QBIT{1'b1}};
			if (fcu_rid==n[`QBITS] && !issuing_on_fcu)
				fcu_rid <= {`QBIT{1'b1}};
					// The following line is a hack. The alu is done (tested above) so it
					// should be setting the state to CMT.
//					if (iq_state[alu0_id]==IQS_OUT)
//						iq_state[alu0_id] <= IQS_CMT;
			alu0_id <= n[`QBITS];
			alu0_rid <= iq_rid[n];
			alu0_instr	<= iq_instr[n];
			alu0_pc		<= iq_pc[n];
					// Agen output is not bypassed since there's only one
					// instruction (LEA) to bypass for.
      alu0_argI <= iq_const[n];
			argBypass(iq_argA_v[n],iq_argA_s[n],iq_argA[n],alu0_argA);
			argBypass(iq_argB_v[n],iq_argB_s[n],iq_argB[n],alu0_argB);
			alu0_tgt    <= iq_tgt[n];
			alu0_dataready <= 1'b1;	//IsSingleCycle(iq_instr[n]);
			alu0_ld <= TRUE;
			iq_state[n] <= IQS_OUT;
    end

	if (`NUM_ALU > 1) begin
    for (n = 0; n < IQ_ENTRIES; n = n + 1)
      if ((iq_alu1_issue[n] && !(iq_v[n] && iq_stomp[n])
												&& (alu1_done))) begin
				iq_fuid[n] <= 3'd1;
				alu1_sourceid	<= n[`QBITS];
				if (alu0_rid==n[`QBITS] && !issuing_on_alu0)
					alu0_rid <= {`QBIT{1'b1}};
				if (agen0_rid==n[`QBITS] && !issuing_on_agen0)
					agen0_rid <= {`QBIT{1'b1}};
				if (agen1_rid==n[`QBITS] && !issuing_on_agen1)
					agen1_rid <= {`QBIT{1'b1}};
				if (fcu_rid==n[`QBITS] && !issuing_on_fcu)
					fcu_rid <= {`QBIT{1'b1}};
								// The following line is a hack. The alu is done (tested above) so it
								// should be setting the state to CMT.
	//							if (iq_state[alu1_id]==IQS_OUT)
	//								iq_state[alu1_id] <= IQS_CMT;
				alu1_id <= n[`QBITS];
				alu1_rid <= iq_rid[n];
				alu1_instr	<= iq_instr[n];
				alu1_pc		<= iq_pc[n];
				alu1_argI <= iq_const[n];
				argBypass(iq_argA_v[n],iq_argA_s[n],iq_argA[n],alu1_argA);
				argBypass(iq_argB_v[n],iq_argB_s[n],iq_argB[n],alu1_argB);
				alu1_tgt    <= iq_tgt[n];
				alu1_dataready <= 1'b1;	//IsSingleCycle(iq_instr[n]);
				alu1_ld <= TRUE;
				iq_state[n] <= IQS_OUT;
      end
  end

  for (n = 0; n < IQ_ENTRIES; n = n + 1)
    if (iq_agen0_issue[n] && !(iq_v[n] && iq_stomp[n])) begin
      if (~agen0_v) begin
				iq_fuid[n] <= 3'd2;
				agen0_sourceid	<= n[`QBITS];
				if (alu0_rid==n[`QBITS] && !issuing_on_alu0)
					alu0_rid <= {`QBIT{1'b1}};
				if (alu1_rid==n[`QBITS] && !issuing_on_alu1)
					alu1_rid <= {`QBIT{1'b1}};
				if (agen1_rid==n[`QBITS] && !issuing_on_agen1)
					agen1_rid <= {`QBIT{1'b1}};
				if (fcu_rid==n[`QBITS] && !issuing_on_fcu)
					fcu_rid <= {`QBIT{1'b1}};
				agen0_id <= n[`QBITS];
				agen0_rid <= iq_rid[n];
				agen0_instr	<= iq_instr[n];
				agen0_argI <= iq_const[n];
				argBypass(iq_argB_v[n],iq_argB_s[n],iq_argB[n],agen0_argB);
				agen0_dataready <= 1'b1;
				iq_state[n] <= IQS_OUT;
      end
    end

	if (`NUM_AGEN > 1) begin
    for (n = 0; n < IQ_ENTRIES; n = n + 1)
      if (iq_agen1_issue[n] && !(iq_v[n] && iq_stomp[n])) begin
        if (~agen1_v) begin
					iq_fuid[n] <= 3'd3;
					agen1_sourceid	<= n[`QBITS];
					if (alu0_rid==n[`QBITS] && !issuing_on_alu0)
						alu0_rid <= {`QBIT{1'b1}};
					if (alu1_rid==n[`QBITS] && !issuing_on_alu1)
						alu1_rid <= {`QBIT{1'b1}};
					if (agen0_rid==n[`QBITS] && !issuing_on_agen0)
						agen0_rid <= {`QBIT{1'b1}};
					if (fcu_rid==n[`QBITS] && !issuing_on_fcu)
					fcu_rid <= {`QBIT{1'b1}};
					agen1_id <= n[`QBITS];
					agen1_rid <= iq_rid[n];
					agen1_instr	<= iq_instr[n];
//                 agen1_argB	<= iq_argB[n];	// ArgB not used by agen
					agen1_argI <= iq_const[n];
					argBypass(iq_argB_v[n],iq_argB_s[n],iq_argB[n],agen1_argB);
					agen1_dataready <= 1'b1;
					iq_state[n] <= IQS_OUT;
        end
      end
  end

  for (n = 0; n < IQ_ENTRIES; n = n + 1)
    if (iq_fcu_issue[n] && !(iq_v[n] && iq_stomp[n])) begin
      if (fcu_done) begin
					iq_fuid[n] <= 3'd6;
				fcu_sourceid	<= n[`QBITS];
        fcu_rid <= iq_rid[n];
					if (alu0_rid==n[`QBITS] && !issuing_on_alu0)
						alu0_rid <= {`QBIT{1'b1}};
					if (alu1_rid==n[`QBITS] && !issuing_on_alu1)
						alu1_rid <= {`QBIT{1'b1}};
					if (agen0_rid==n[`QBITS] && !issuing_on_agen0)
						agen0_rid <= {`QBIT{1'b1}};
					if (agen1_rid==n[`QBITS] && !issuing_on_agen1)
						agen1_rid <= {`QBIT{1'b1}};
				fcu_id <= n[`QBITS];
				fcu_prevInstr <= fcu_instr;
				fcu_instr	<= iq_instr[n];
				fcu_hs		<= iq_hs[n];
				fcu_pc		<= iq_pc[n];
				fcu_nextpc <= iq_pc[n] + iq_len[n];
				fcu_pt     <= iq_pt[n];
				fcu_brdisp <= iq_const[n];
				//$display("Branch tgt: %h", {iq_instr[n][39:22],iq_instr[n][5:3],iq_instr[n][4:3]});
				fcu_branch <= iq_br[n];
				fcu_argI <= iq_const[n];
				argBypass(iq_argA_v[n],iq_argA_s[n],iq_argA[n],fcu_argA);
				fcu_dataready <= 1'b1;
				fcu_clearbm <= `FALSE;
				fcu_ld <= TRUE;
				iq_state[n] <= IQS_OUT;
				fcu_done <= `FALSE;
      end
    end
    
//
// MEMORY
//
// update the memory queues and put data out on bus if appropriate
//

//
// dram0, dram1, dram2 are the "state machines" that keep track
// of three pipelined DRAM requests.  if any has the value "000", 
// then it can accept a request (which bumps it up to the value "001"
// at the end of the cycle).  once it hits the value "111" the request
// is finished and the dram_bus takes the value.  if it is a store, the 
// dram_bus value is not used, but the dram_v value along with the
// dram_id value signals the waiting memq entry that the store is
// completed and the instruction can commit.
//

// Flip the ready status to available. Used for loads or stores.

	if (dram0 == `DRAMREQ_READY)
		dram0 <= `DRAMSLOT_AVAIL;
	if (dram1 == `DRAMREQ_READY && `NUM_MEM > 1)
		dram1 <= `DRAMSLOT_AVAIL;

// grab requests that have finished and put them on the dram_bus
// If stomping on the instruction don't place the value on the argument
// bus to be loaded.
	if (dram0 == `DRAMREQ_READY && dram0_load) begin
		dramA_v <= !iq_stomp[dram0_id];
		dramA_id <= dram0_id;
		dramA_rid <= dram0_rid;
		dramA_bus <= rdat0;
	end
	if (dram1 == `DRAMREQ_READY && dram1_load && `NUM_MEM > 1) begin
		dramB_v <= !iq_stomp[dram1_id];
		dramB_id <= dram1_id;
		dramB_rid <= dram1_rid;
		dramB_bus <= rdat1;
	end

//
// determine if the instructions ready to issue can, in fact, issue.
// "ready" means that the instruction has valid operands but has not gone yet
	for (n = 0; n < IQ_ENTRIES; n = n + 1)
	if (memissue[n])
		iq_memissue[n] <= `VAL;
	//iq_memissue <= memissue;
	missue_count <= issue_count;

	for (n = 0; n < IQ_ENTRIES; n = n + 1)
		if (iq_v[n] && iq_stomp[n]) begin
			iq_mem[n] <= `INV;
			iq_load[n] <= `INV;
			iq_store[n] <= `INV;
			iq_state[n] <= IQS_INVALID;
			rob.robEntries[iq_rid[n]].state <= RS_INVALID;
	//		if (alu0_id==n)
	//			alu0_dataready <= FALSE;
	//		if (alu1_id==n)
	//			alu1_dataready <= FALSE;
			$display("stomp: IQS_INVALID[%d]",n);
		end

	if (last_issue0 < IQ_ENTRIES)
		tDram0Issue(last_issue0);
	if (last_issue1 < IQ_ENTRIES)
		tDram1Issue(last_issue1);
/*
	if (ohead[0]==heads[0])
		cmt_timer <= cmt_timer + 12'd1;
	else
		cmt_timer <= 12'd0;

	if (cmt_timer==12'd1000 && icstate==IDLE) begin
		iq_state[heads[0]] <= IQS_CMT;
		iq_exc[heads[0]] <= `FLT_CMT;
		cmt_timer <= 12'd0;
	end
*/
//
// COMMIT PHASE (dequeue only ... not register-file update)
//
// look at heads[0] and heads[1] and let 'em write to the register file if they are ready
//
//    always @(posedge clk) begin: commit_phase

// Fetch and queue are limited to two instructions per cycle, so we might as
// well limit retiring to two instructions max to conserve logic.
//
	head_inc(hi_amt);
	rob_head_inc(r_amt);

oddball_commit(commit0_v, heads[0], 2'd0);
oddball_commit(commit1_v, heads[1], 2'd1);

// A store will never be stomped on because they aren't issued until it's
// guarenteed there will be no change of flow.
// A load or other long running instruction might be stomped on by a change
// of program flow. Stomped on loads already in progress can be aborted early.
// In the case of an aborted load, random data is returned and any exceptions
// are nullified.
if (dram0_load)
case(dram0)
`DRAMSLOT_AVAIL:	;
`DRAMSLOT_BUSY:
	if (iq_v[dram0_id] && !iq_stomp[dram0_id]) begin
		if (dhit0 & !dram0_unc) begin
//			dramA_v <= !iq_stomp[dram0_id];
//			dramA_id <= dram0_id;
//			dramA_rid <= dram0_rid;
//			dramA_bus <= rdat0;
//			dramA_sr_bus <= 8'h00;
//			dramA_sr_bus[1] <= rdat0[7:0]==8'h00;
//			dramA_sr_bus[7] <= rdat0[7];
//			dramA_sr_tgts <= 8'h82;
//			dram0 <= `DRAMSLOT_AVAIL;
			dram0 <= `DRAMREQ_READY;
		end
	end
	else begin
		dram0 <= `DRAMREQ_READY;
		dram0_load <= `FALSE;
		//xdati <= {13{lfsro}};
	end
`DRAMSLOT_REQBUS:	
	if (iq_v[dram0_id] && !iq_stomp[dram0_id])
		;
	else begin
		dram0 <= `DRAMREQ_READY;
		dram0_load <= `FALSE;
		//xdati <= {13{lfsro}};
	end
`DRAMSLOT_HASBUS:
	if (iq_v[dram0_id] && !iq_stomp[dram0_id])
		;
	else begin
		dram0 <= `DRAMREQ_READY;
		dram0_load <= `FALSE;
		//xdati <= {13{lfsro}};
	end
`DRAMREQ_READY:		dram0 <= `DRAMSLOT_AVAIL;
endcase

if (dram1_load)
case(dram1)
`DRAMSLOT_AVAIL:	;
`DRAMSLOT_BUSY:
	if (iq_v[dram1_id] && !iq_stomp[dram1_id]) begin
		if (dhit1 && !dram1_unc) begin
//			dramB_v <= !iq_stomp[dram1_id];
//			dramB_id <= dram1_id;
//			dramB_rid <= dram1_rid;
//			dramB_bus <= rdat1;
//			dramB_sr_bus <= 8'h00;
//			dramB_sr_tgts <= 8'h82;
//			dramB_sr_bus[1] <= rdat1[7:0]==8'h00;
//			dramB_sr_bus[7] <= rdat1[7];
			dram1 <= `DRAMREQ_READY;
		end
	end
	else begin
		dram1 <= `DRAMREQ_READY;
		dram1_load <= `FALSE;
		//xdati <= {13{lfsro}};
	end
`DRAMSLOT_REQBUS:	
	if (iq_v[dram1_id] && !iq_stomp[dram1_id])
		;
	else begin
		dram1 <= `DRAMREQ_READY;
		dram1_load <= `FALSE;
		//xdati <= {13{lfsro}};
	end
`DRAMSLOT_HASBUS:
	if (iq_v[dram1_id] && !iq_stomp[dram1_id])
		;
	else begin
		dram1 <= `DRAMREQ_READY;
		dram1_load <= `FALSE;
		//xdati <= {13{lfsro}};
	end
`DRAMREQ_READY:		dram1 <= `DRAMSLOT_AVAIL;
endcase

case(bstate)
BIDLE:
	begin
		bwhich <= 2'b00;

        if (~|wb_v && dram0_unc && dram0==`DRAMSLOT_BUSY && dram0_load
        	&& !iq_stomp[dram0_id]) begin
`ifdef SUPPORT_DBG        	
            if (dbg_lmatch0) begin
               dramA_v <= `TRUE;
               dramA_id <= dram0_id;
               dramA_bus <= 64'h0;
               iq_exc[dram0_id] <= `FLT_DBG;
               dram0 <= `DRAMSLOT_AVAIL;
            end
            else
`endif            
            if (!dack_i) begin
               bwhich <= 2'b00;
               dram0 <= `DRAMSLOT_HASBUS;
               dcyc <= `HIGH;
               dstb <= `HIGH;
               dsel <= fnSelect(dram0_instr);
               dadr <= dram0_addr;
               dwrap <= dram0_wrap;
               dccnt <= 2'd0;
               bstate <= B_DLoadAck;
            end
        end
        else if (~|wb_v && dram1_unc && dram1==`DRAMSLOT_BUSY && dram1_load && `NUM_MEM > 1
        	&& !iq_stomp[dram1_id]) begin
`ifdef SUPPORT_DBG        	
            if (dbg_lmatch1) begin
               dramB_v <= `TRUE;
               dramB_id <= dram1_id;
               dramB_bus <= 64'h0;
               iq_exc[dram1_id] <= `FLT_DBG;
               dram1 <= `DRAMSLOT_AVAIL;
            end
            else
`endif            
            if (!dack_i) begin
               bwhich <= 2'b01;
               dram1 <= `DRAMSLOT_HASBUS;
               dcyc <= `HIGH;
               dstb <= `HIGH;
               dsel <= fnSelect(dram1_instr);
               dadr <= dram1_addr;
               dwrap <= dram1_wrap;
               dccnt <= 2'd0;
               bstate <= B_DLoadAck;
            end
        end
        // Check for L2 cache miss
        else if (~|wb_v && !L2_ihit && !dack_i)
        begin
        	cyc_pending <= `HIGH;
        	bstate <= B_WaitIC;
        	/*
           cti_o <= 3'b001;
           bte_o <= 2'b00;//2'b01;	// 4 beat burst wrap
           cyc <= `HIGH;
           stb_o <= `HIGH;
           sel_o <= 8'hFF;
           icl_o <= `HIGH;
           iccnt <= 3'd0;
           icack <= 1'b0;
//            adr_o <= icwhich ? {pc0[31:5],5'b0} : {pc1[31:5],5'b0};
//            L2_adr <= icwhich ? {pc0[31:5],5'b0} : {pc1[31:5],5'b0};
           vadr <= {L1_adr[AMSB:5],5'h0};
`ifdef SUPPORT_SMT          
`else 
           ol_o  <= ol;//???
`endif
           L2_adr <= {L1_adr[AMSB:5],5'h0};
           L2_xsel <= 1'b0;
           selL2 <= TRUE;
           bstate <= B_ICacheAck;
           */
        end
    end
B_WaitIC:
	begin
		cyc_pending <= `LOW;
//		cti_o <= icti;
//		bte_o <= ibte;
//		cyc <= icyc;
//		stb_o <= istb;
//		sel_o <= isel;
//		vadr <= iadr;
//		we <= 1'b0;
		if (L2_nxt)
			bstate <= BIDLE;
	end

// Regular load
B_DLoadAck:
  if (dack_i|derr_i|tlb_miss|rdv_i) begin
  	if (dselx > 16'h00FF && dccnt==2'd0) begin
  		dsel <= dselx[15:8];
  		dstb <= `LOW;
  		dadr <= dadr + 16'd1;
  		bstate <= B_DLoadNack;
  	end
  	else begin
  		wb_nack();
  		bstate <= B_LSNAck;
  	end
		case(dccnt)
		2'd0:	xdati[103:0] <= dat_i >> (dadr[2:0] * 13);
		2'd1:	
			case(dsel)
			8'b00000000:	;
			8'b00000001:	xdati[103:91] <= dat_i;
			8'b00000011:	xdati[103:78] <= dat_i;
			8'b00000111:	xdati[103:65] <= dat_i;
			default:			;
			endcase
		default:	;
		endcase
    case(bwhich)
    2'b00:  begin
           		dram0 <= `DRAMREQ_READY;
//             	if (iq_stomp[dram0_id])
//             		iq_exc [dram0_id] <= `FLT_NONE;
//             	else
//             		iq_exc [ dram0_id ] <= tlb_miss ? `FLT_TLB : err_i ? `FLT_DRF : rdv_i ? `FLT_DRF : `FLT_NONE;
            end
    2'b01:  if (`NUM_MEM > 1) begin
             dram1 <= `DRAMREQ_READY;
//             	if (iq_stomp[dram1_id])
//             		iq_exc [dram1_id] <= `FLT_NONE;
//             	else
//	             iq_exc [ dram1_id ] <= tlb_miss ? `FLT_TLB : err_i ? `FLT_DRF : rdv_i ? `FLT_DRF : `FLT_NONE;
            end
    default:    ;
    endcase
    dccnt <= dccnt + 2'd1;
		check_abort_load();
	end
B_DLoadNack:
	if (~dack_i) begin
		dstb <= `HIGH;
		bstate <= B_DLoadAck;
		check_abort_load();
	end

// Three cycles to detemrine if there's a cache hit during a store.
B16:
	begin
    case(bwhich)
    2'd0:      if (dhit0) begin  dram0 <= `DRAMREQ_READY; bstate <= B17; end
    2'd1:      if (dhit1) begin  dram1 <= `DRAMREQ_READY; bstate <= B17; end
    default:    bstate <= BIDLE;
    endcase
		check_abort_load();
  end
B17:
	begin
    bstate <= B18;
		check_abort_load();
  end
B18:
	begin
  	bstate <= B_LSNAck;
		check_abort_load();
	end
B_LSNAck:
	begin
		bstate <= BIDLE;
		StoreAck1 <= `FALSE;
		isStore <= `FALSE;
		check_abort_load();
	end
default:     bstate <= BIDLE;
endcase

`ifdef SIM
	$display("\n\n\n\n\n\n\n\n");
	$display("TIME %0d", $time);
	$display("%b %h #", pc_mask, pc);
	$display("%b %h #", pc_mask, pc + len1);
    $display ("--------------------------------------------------------------------- Regfile ---------------------------------------------------------------------");
  $display("ac: %h %d %d #", regsx[1], regIsValid[1], rf_source[1]);
  $display("xr: %h %d %d #", regsx[2], regIsValid[2], rf_source[2]);
  $display("yr: %h %d %d #", regsx[3], regIsValid[3], rf_source[3]);
  $display("sp: %h %d %d #", regsx[31], regIsValid[31], rf_source[31]);
  $display("tmp1: %h %d %d #", regsx[4], regIsValid[4], rf_source[4]);
  $display("tmp2: %h %d %d #", regsx[5], regIsValid[5], rf_source[5]);
`ifdef FCU_ENH
	$display("Call Stack:");
	for (n = 0; n < 16; n = n + 4)
		$display("%c%d: %h   %c%d: %h   %c%d: %h   %c%d: %h",
			ursb1.rasp==n+0 ?">" : " ", n[4:0]+0, ursb1.ras[n+0],
			ursb1.rasp==n+1 ?">" : " ", n[4:0]+1, ursb1.ras[n+1],
			ursb1.rasp==n+2 ?">" : " ", n[4:0]+2, ursb1.ras[n+2],
			ursb1.rasp==n+3 ?">" : " ", n[4:0]+3, ursb1.ras[n+3]
		);
	$display("\n");
`endif
//    $display("Return address stack:");
//    for (n = 0; n < 16; n = n + 1)
//        $display("%d %h", rasp+n[3:0], ras[rasp+n[3:0]]);
	$display("TakeBr:%d #", take_branch);//, backpc);
	$display("Insn%d: %h %h %h %h", 0, insnx[0], insnx[1], opcode1, opcode2);
	$display ("------------------------------------------------------------------------ Dispatch Buffer -----------------------------------------------------------------------");
	for (i=0; i<IQ_ENTRIES; i=i+1) 
	    $display("%c%c %d: %c%c%c %d %d %c%c %c %c%h %s %d,%s %h %h %d %d %h %d %d %h %d #",
		 (i[`QBITS]==heads[0])?"C":".",
		 (i[`QBITS]==tails[0])?"Q":".",
		  i[`QBITS],
		  iq_state[i]==IQS_INVALID ? "-" :
		  iq_state[i]==IQS_QUEUED ? "Q" :
		  iq_state[i]==IQS_OUT ? "O"  :
		  iq_state[i]==IQS_AGEN ? "A"  :
		  iq_state[i]==IQS_MEM ? "M"  :
		  iq_state[i]==IQS_DONE ? "D"  :
		  iq_state[i]==IQS_CMT ? "C"  : "?",
//		 iq_v[i] ? "v" : "-",
		 iq_done[i]?"d":"-",
		 iq_out[i]?"o":"-",
		 iq_bt[i],
		 iq_memissue[i],
		 iq_agen[i] ? "a": "-",
		 iq_alu0_issue[i]?"0":iq_alu1_issue[i]?"1":"-",
		 iq_stomp[i]?"s":"-",
		iq_fc[i] ? "F" : iq_mem[i] ? "M" : (iq_alu[i]==1'b1) ? "A" : "O", 
		iq_instr[i],fnMnemonic(iq_instr[i]), iq_tgt[i], iq_tgt[i],
		iq_const[i],
		iq_argA[i], iq_argA_v[i], iq_argA_s[i],
		iq_argB[i], iq_argB_v[i], iq_argB_s[i],
		iq_pc[i],
		iq_sn[i]
		);
		rob_display(heads[0],tails[0]);
    $display("DRAM");
	$display("%d %h %h %c%h %o #",
	    dram0, dram0_addr, dram0_data, (IsFlowCtrl(dram0_instr) ? 98 : (IsMem(dram0_instr)) ? 109 : 97), 
	    dram0_instr, dram0_id);
	  if (`NUM_MEM > 1)
	$display("%d %h %h %c%h %o #",
	    dram1, dram1_addr, dram1_data, (IsFlowCtrl(dram1_instr) ? 98 : (IsMem(dram1_instr)) ? 109 : 97), 
	    dram1_instr, dram1_id);
	$display("%d %h %o #", dramA_v, dramA_bus, dramA_id);
	if (`NUM_MEM > 1)
	$display("%d %h %o #", dramB_v, dramB_bus, dramB_id);
    $display("ALU");
	$display("%d %h %h %h %c%s %h %h #",
		alu0_dataready, 0, alu0_argT, alu0_argB, 
		 (IsFlowCtrl(alu0_instr) ? 98 : IsMem(alu0_instr) ? 109 : 97),
		fnMnemonic(alu0_instr), alu0_sourceid, alu0_pc);
	$display("%d %h %o 0 #", alu0_v, alu0_bus, alu0_id);
	if (`NUM_ALU > 1) begin
		$display("%d %h %h %h %c%s %h %h #",
			alu1_dataready, 0, alu1_argT, alu1_argB, 
		 	(IsFlowCtrl(alu1_instr) ? 98 : IsMem(alu1_instr) ? 109 : 97),
			fnMnemonic(alu1_instr), alu1_sourceid, alu1_pc);
		$display("%d %h %o 0 #", alu1_v, alu1_bus, alu1_id);
	end
	$display("FCU");
	$display("%d %h %h %h %h %c%c #", fcu_v, fcu_bus, 0, fcu_argT, fcu_argB, fcu_takb?"T":"-", fcu_pt?"T":"-");
	$display("%c %h %h %h %h #", fcu_branchmiss?"m":" ", fcu_sourceid, fcu_misspc, fcu_nextpc, fcu_brdisp); 
    $display("Commit");
	$display("0: %c %h %o %d #", commit0_v?"v":" ", commit0_bus, commit0_id, commit0_tgt);
	$display("1: %c %h %o %d #", commit1_v?"v":" ", commit1_bus, commit1_id, commit1_tgt);
    $display("instr. queued: %d", ins_queued);
    $display("instr. committed: %d", ins_committed);
    $display("I$ load stalls cycles: %d", ic_stalls);
    $display("Branch override BTB: %d", br_override);
    $display("Total branches: %d", br_total);
    $display("Missed branches: %d", br_missed);
  $display("Write Buffer:");
  for (n = `WB_DEPTH-1; n >= 0; n = n - 1)
  	$display("%c adr: %h dat: %h", wb_v[n]?" ":"*", wb_addr[n], uwb1.wb_data[n]);
    //$display("Write merges: %d", wb_merges);
`endif	// SIM

	$display("");

	if (|panic) begin
	    $display("");
	    $display("-----------------------------------------------------------------");
	    $display("-----------------------------------------------------------------");
	    $display("---------------     PANIC:%s     -----------------", message[panic]);
	    $display("-----------------------------------------------------------------");
	    $display("-----------------------------------------------------------------");
	    $display("");
	    $display("instructions committed: %d", I);
	    $display("total execution cycles: %d", $time / 10);
	    $display("");
	end
	if (|panic && ~outstanding_stores) begin
	    $finish;
	end
end	// end of clock domain

// ============================================================================
// ============================================================================
// Start of Tasks
// ============================================================================
// ============================================================================

task rob_displayEntry;
input integer i;
input Rid head;
input Rid tail;
begin
	$display("%c%c %d(%d): %c %h %d %h #",
	 (i[`RBITS]==head)?"C":".",
	 (i[`RBITS]==tail)?"Q":".",
	  i[`RBITS],
	  rob.robEntries[i].id,
	  rob.robEntries[i].state==RS_INVALID ? "-" :
	  rob.robEntries[i].state==RS_ASSIGNED ? "A"  :
	  rob.robEntries[i].state==RS_CMT ? "C"  : "D",
	  rob.robEntries[i].exc,
	  rob.robEntries[i].tgt,
	  rob.robEntries[i].res
	);
end
endtask

task rob_display;
input Rid head;
input Rid tail;
begin
	$display ("------------- Reorder Buffer ------------");
	for (i = 0; i < `RENTRIES; i = i + 1)
		rob_displayEntry(i, head, tail);
end
endtask


// This task takes care of commits for things other than the register file.
task oddball_commit;
input v;
input [`RBITS] head;
input [1:0] which;
reg thread;
begin
  if (v) begin
//    if (|rob_exc[head]) begin
//    	exc(head,thread,iq_exc[head]);
//    end
//		else
			case(rob.robEntries[head].instr.gen.opcode)
			`BRKGRP:
          begin
            excmiss <= TRUE;
            im_stack <= {im_stack[11:0],3'h7};
            ol_stack <= {ol_stack[11:0],3'b00};
            dl_stack <= {dl_stack[11:0],3'b00};
        		excmisspc <= 52'hFFFFFFFFE0000;
            for (n = 1; n < 5; n = n + 1)
            	ipc[n] <= ipc[n-1];
            pl_stack <= {pl_stack[90:0],13'h000};
            case(rob.robEntries[head].instr.wai.exop)
            `BRK:	
            	begin
            		cause[3'd0] <= {9'h4,rob.robEntries[head].instr.wai.sigmsk};	// 40h to 4Fh
		            ipc[0] <= rob.robEntries[head].pc + 2'd1;
		            lkregs[4] <= rob.robEntries[head].pc + 2'd1;
            	end
            `RST:	
            	begin
            		cause[3'd0] <= 13'h70;
		            ipc[0] <= rob.robEntries[head].pc;
		            lkregs[4] <= rob.robEntries[head].pc;
            	end
            `NMI:	
            	begin
            		if (rob.robEntries[head].instr.wai.exop==2'd1)	// SNR
            			cause[3'd0] <= 13'h61;
            		else
            			cause[3'd0] <= 13'h60;
		            ipc[0] <= rob.robEntries[head].pc;
		            lkregs[4] <= rob.robEntries[head].pc;
            	end
            `IRQ: 
            	begin
            		cause[3'd0] <= {9'h5,rob.robEntries[head].instr.wai.sigmsk};
		            ipc[0] <= rob.robEntries[head].pc;
		            lkregs[4] <= rob.robEntries[head].pc;
            	end
          	endcase
           	sema[0] <= 1'b0;
`ifdef SUPPORT_DBG                    
            dbg_ctrl[62:55] <= {dbg_ctrl[61:55],dbg_ctrl[63]}; 
            dbg_ctrl[63] <= FALSE;
`endif                    
          end
        `REX:
          if (ol < rob.robEntries[head].instr.rex.tgt) begin
            ol_stack[2:0] <= rob.robEntries[head].instr.rex.tgt;
            badaddr[{1'b0,rob.robEntries[head].instr.rex.tgt}] <= badaddr[{1'b0,ol}];
            bad_instr[{1'b0,rob.robEntries[head].instr.rex.tgt}] <= bad_instr[{1'b0,ol}];
            cause[{1'b0,rob.robEntries[head].instr.rex.tgt}] <= cause[{1'b0,ol}];
            pl_stack[12:0] <= rob.robEntries[head].instr.rex.pl | iq_argA[head][12:0];
          end
        `CACHE:
        		begin
	            case(rob.robEntries[head].instr.cache.icmd)
	            2'h1:	begin invicl <= TRUE; invlineAddr <= rob.robEntries[head].res; end
	            2'h2:  	invic <= TRUE;
	            default:	;
	          	endcase
	            case(rob.robEntries[head].instr.cache.dcmd)
	            3'h1:  cr0[30] <= TRUE;
	            3'h2:  cr0[30] <= FALSE;
	            3'h3:		invdcl <= TRUE;
	            3'h4:		invdc <= TRUE;
	            default:    ;
	            endcase
		        end
        `CSR:
        		begin
        			if (rob.robEntries[head].instr.csr.op[2])
        				write_csr(
        					rob.robEntries[head].instr.csr.op,
        					rob.robEntries[head].instr.csr.ol,
        					rob.robEntries[head].instr.csr.regno,
        					{rob.robEntries[head].instr.raw[32:29],rob.robEntries[head].instr.raw[16:12]}
        				);
        			else
        				write_csr(
        					rob.robEntries[head].instr.csr.op,
        					rob.robEntries[head].instr.csr.ol,
        					rob.robEntries[head].instr.csr.regno,
        					rob.robEntries[head].argA
        				);
        		end
 /*
        `FLT1:
					case(rob_instr[head][`FFUNCT5])
					`FRM: begin  
								fp_rm <= rob_res[head][6:4];
								end
          `FCX:
              begin
                  fp_sx <= fp_sx & ~rob_res[head][9];
                  fp_inex <= fp_inex & ~rob_res[head][8];
                  fp_dbzx <= fp_dbzx & ~(rob_res[head][7]|rob_res[head][4]);
                  fp_underx <= fp_underx & ~rob_res[head][6];
                  fp_overx <= fp_overx & ~rob_res[head][5];
                  fp_giopx <= fp_giopx & ~rob_res[head][4];
                  fp_infdivx <= fp_infdivx & ~rob_res[head][4];
                  fp_zerozerox <= fp_zerozerox & ~rob_res[head][4];
                  fp_subinfx   <= fp_subinfx   & ~rob_res[head][4];
                  fp_infzerox  <= fp_infzerox  & ~rob_res[head][4];
                  fp_NaNCmpx   <= fp_NaNCmpx   & ~rob_res[head][4];
                  fp_swtx <= 1'b0;
              end
          `FDX:
              begin
                  fp_inexe <= fp_inexe     & ~rob_res[head][8];
                  fp_dbzxe <= fp_dbzxe     & ~rob_res[head][7];
                  fp_underxe <= fp_underxe & ~rob_res[head][6];
                  fp_overxe <= fp_overxe   & ~rob_res[head][5];
                  fp_invopxe <= fp_invopxe & ~rob_res[head][4];
              end
          `FEX:
              begin
                  fp_inexe <= fp_inexe     | rob_res[head][8];
                  fp_dbzxe <= fp_dbzxe     | rob_res[head][7];
                  fp_underxe <= fp_underxe | rob_res[head][6];
                  fp_overxe <= fp_overxe   | rob_res[head][5];
                  fp_invopxe <= fp_invopxe | rob_res[head][4];
              end
            default:	;
            endcase
          default:
            begin
                // 31 to 29 is rounding mode
                // 28 to 24 are exception enables
                // 23 is nsfp
                // 22 is a fractie
                fp_fractie <= rob_status[head][22];
                fp_raz <= rob_status[head][21];
                // 20 is a 0
                fp_neg <= rob_status[head][19];
                fp_pos <= rob_status[head][18];
                fp_zero <= rob_status[head][17];
                fp_inf <= rob_status[head][16];
                // 15 swtx
                // 14 
                fp_inex <= fp_inex | (fp_inexe & rob_status[head][14]);
                fp_dbzx <= fp_dbzx | (fp_dbzxe & rob_status[head][13]);
                fp_underx <= fp_underx | (fp_underxe & rob_status[head][12]);
                fp_overx <= fp_overx | (fp_overxe & rob_status[head][11]);
                //fp_giopx <= fp_giopx | (fp_giopxe & iq_res2[head][10]);
                //fp_invopx <= fp_invopx | (fp_invopxe & iq_res2[head][24]);
                //
                fp_cvtx <= fp_cvtx |  (fp_giopxe & rob_status[head][7]);
                fp_sqrtx <= fp_sqrtx |  (fp_giopxe & rob_status[head][6]);
                fp_NaNCmpx <= fp_NaNCmpx |  (fp_giopxe & rob_status[head][5]);
                fp_infzerox <= fp_infzerox |  (fp_giopxe & rob_status[head][4]);
                fp_zerozerox <= fp_zerozerox |  (fp_giopxe & rob_status[head][3]);
                fp_infdivx <= fp_infdivx | (fp_giopxe & rob_status[head][2]);
                fp_subinfx <= fp_subinfx | (fp_giopxe & rob_status[head][1]);
                fp_snanx <= fp_snanx | (fp_giopxe & rob_status[head][0]);

            end
          endcase
 */
        endcase
        // Once the flow control instruction commits, NOP it out to allow
        // pending stores to be issued.
        rob.robEntries[head].instr.raw <= `NOP_INSN;
    end
end
endtask

task write_csr;
input [2:0] csrop;
input [2:0] csrol;
input [13:0] csrno;
input [127:0] dat;
begin
    if (csrol >= ol)
    case(csrop)
    3'd1,3'd5:   // CSRRW, CSRRWI
        casez(csrno[11:0])
        `CSR_CR0:       cr0 <= dat;
        `CSR_SEMA:      sema <= dat;
//        `CSR_KEYS:	keys <= dat;
//        `CSR_FSTAT:		fpu_csr[37:32] <= dat[37:32];
        `CSR_BADADR:    badaddr[csrol] <= dat;
        `CSR_BADINST:		bad_instr[csrol] <= dat;
        `CSR_CAUSE:     cause[csrol] <= dat[12:0];
        `CSR_DOI_STACK:	
        	begin
        		im_stack <= dat[14:0];
        		ol_stack <= dat[29:15];
        		dl_stack <= dat[44:30];
        	end
`ifdef SUPPORT_DBG        
        `CSR_DBAD0:     dbg_adr0 <= dat[AMSB:0];
        `CSR_DBAD1:     dbg_adr1 <= dat[AMSB:0];
        `CSR_DBAD2:     dbg_adr2 <= dat[AMSB:0];
        `CSR_DBAD3:     dbg_adr3 <= dat[AMSB:0];
        `CSR_DBCTRL:    dbg_ctrl <= dat;
`endif        
//        `CSR_CAS:       cas <= dat;
        `CSR_PL_STACKL:	pl_stack[51:0] <= dat;
        `CSR_PL_STACKH:	pl_stack[103:52] <= dat;
        `CSR_STATUS:    status <= dat;
        `CSR_IPC0:      ipc[0] <= dat;
        `CSR_IPC1:      ipc[1] <= dat;
        `CSR_IPC2:      ipc[2] <= dat;
        `CSR_IPC3:      ipc[3] <= dat;
        `CSR_IPC4:      ipc[4] <= dat;
        `CSR_TIME_FRAC:	wc_time_frac <= dat[39:0];
				`CSR_TIME_SECS:	begin
						wc_time_secs <= dat[39:0];
						ld_time <= 6'h3f;
						end
        default:    ;
        endcase
    3'd2,3'd6:   // CSRRS,CSRRSI
        case(csrno[11:0])
        `CSR_CR0:       cr0 <= cr0 | dat;
//        `CSR_WBRCD:		wbrcd <= wbrcd | dat;
`ifdef SUPPORT_DBG        
        `CSR_DBCTRL:    dbg_ctrl <= dbg_ctrl | dat;
`endif        
        `CSR_SEMA:      sema <= sema | dat;
        `CSR_STATUS:    status <= status | dat;
        default:    ;
        endcase
    3'd3,3'd7:   // CSRRC,CSRRCI
        case(csrno[11:0])
        `CSR_CR0:       cr0 <= cr0 & ~dat;
//        `CSR_WBRCD:		wbrcd <= wbrcd & ~dat;
`ifdef SUPPORT_DBG        
        `CSR_DBCTRL:    dbg_ctrl <= dbg_ctrl & ~dat;
`endif        
        `CSR_SEMA:      sema <= sema & ~dat;
        `CSR_STATUS:    status <= status & ~dat;
        default:    ;
        endcase
    default:    ;
    endcase
end
endtask

// Note the use of blocking(=) assigments here. For some reason in sim <= 
// assignments didn't work.
task argBypass;
input v;
input Rid src;
input Data iq_arg;
output Data arg;
begin
`ifdef FU_BYPASS
	if (v)
		arg = iq_arg;
	else
		case(src)
		alu0_rid:	arg = ralu0_bus;
		alu1_rid:	arg = ralu1_bus;
		dramA_rid:	arg = dramA_bus;
		dramB_rid:	arg = dramB_bus;
		default:	arg = {1{16'hDEAD}};
		endcase
`else
	arg = iq_arg;
`endif           
end
endtask

task check_abort_load;
begin
  case(bwhich)
  2'd0:	if (iq_stomp[dram0_id]) begin bstate <= BIDLE; dram0 <= `DRAMREQ_READY; end
  2'd1:	if (iq_stomp[dram1_id]) begin bstate <= BIDLE; dram1 <= `DRAMREQ_READY; end
  default:	if (iq_stomp[dram0_id]) begin bstate <= BIDLE; dram0 <= `DRAMREQ_READY; end
  endcase
end
endtask

// Increment the head pointers
// Also increments the instruction counter
// Used when instructions are committed.
// Also clear any outstanding state bits that foul things up.
//
task head_inc;
input [`QBITS] amt;
begin
	for (n = 0; n < IQ_ENTRIES; n = n + 1)
		if (n < amt) begin
			if (!((heads[n]==tails[0] && queuedCnt==3'd1)
			|| (heads[n]==tails[1] && queuedCnt==3'd2)
			|| (heads[n]==tails[2] && queuedCnt==3'd3)
			|| (heads[n]==tails[3] && queuedCnt==3'd4)
			)) begin
				iq_state[heads[n]] <= IQS_INVALID;
				rob.robEntries[heads[n]].state <= RS_INVALID;
				iq_mem[heads[n]] <= `FALSE;
				iq_alu[heads[n]] <= `FALSE;
				iq_fc[heads[n]] <= `FALSE;
//				if (alu0_id==heads[n] && iq_state[alu0_id]==IQS_CMT
//					&& !issuing_on_alu0)
//					alu0_dataready <= `FALSE;
//				if (alu1_id==heads[n] && iq_state[alu1_id]==IQS_CMT
//					&& !issuing_on_alu1)
//					alu1_dataready <= `FALSE;
//					$display("head_inc: IQS_INVALID[%d]",heads[n]);
		end
	end
			
//		if (iq_v[n])
//			iq_sn[n] <= /*(tosub > iq_sn[n]) ? 1'd0 : */iq_sn[n] - tosub;
end
endtask

// If incrementing by 1/2 then the first result in the rob entry was committed,
// but the second one wasn't. So leave the rob entry as valid and allow the
// commit to try again on the next cycle.
task rob_head_inc;
input [`RBITSP1] amt;
begin
	for (n = 0; n < RENTRIES; n = n + 1)
		if (n < amt) begin
			
			if (!((rob_heads[n][`RBITS]==rob_tails[0] && queuedCnt==3'd1)
				|| (rob_heads[n][`RBITS]==rob_tails[1] && queuedCnt==3'd2)
				|| (rob_heads[n][`RBITS]==rob_tails[2] && queuedCnt==3'd3)
				|| (rob_heads[n][`RBITS]==rob_tails[3] && queuedCnt==3'd4)
				)) begin
				
//					rob_state[rob_heads[n]] <= RS_INVALID;
					//iq_state[rob_id[rob_heads[n]]] <= IQS_INVALID;
					$display("rob_head_inc: IQS_INVALID[%d]",rob.robEntries[rob_heads[n]].id);
					//rob_state[rob_heads[n]] <= RS_INVALID;
			end
		end
end
endtask

task setargs;
input Qid nn;
input Rid id;
input v;
input [51:0] bus;
begin
  if (iq_argB_v[nn] == `INV && iq_argB_s[nn] == id && iq_v[nn] == `VAL && v == `VAL) begin
		iq_argB[nn] <= bus;
		iq_argB_v[nn] <= `VAL;
  end
  if (iq_argA_v[nn] == `INV && iq_argA_s[nn] == id && iq_v[nn] == `VAL && v == `VAL) begin
		iq_argA[nn] <= bus;
		iq_argA_v[nn] <= `VAL;
  end
end
endtask

task setargs2;
begin
	for (n = 0; n < IQ_ENTRIES; n = n + 1) begin
		for (j = 0; j < IQ_ENTRIES; j = j + 1) begin
			if (iq_state[j]==IQS_CMT && iq_rid[j]==iq_argB_s[n] && iq_argB_v[n]==`INV) begin
				iq_argB[n] <= rob.robEntries[iq_rid[j]].res;
				iq_argB_v[n] <= `VAL;
			end
			if (iq_state[j]==IQS_CMT && iq_rid[j]==iq_argA_s[n] && iq_argA_v[n]==`INV) begin
				iq_argA[n] <= rob.robEntries[iq_rid[j]].res;
				iq_argA_v[n] <= `VAL;
			end
		end
	end
end
endtask

// Patterns do not have all one bits! The tail queue slot depends on which set
// bit of the pattern is present. For instance patterns 001,010, and 100 all
// refer to the same tail - tail[0]. Need to count the set bits in the pattern
// to determine the tail number.
function [2:0] tails_rc;
input [QSLOTS-1:0] pat;
input [QSLOTS-1:0] rc;
reg [2:0] cnt;
begin
	cnt = 0;
	tails_rc = QSLOTS-1;
	for (n = 0; n < QSLOTS; n = n + 1) begin
		if (rc==n)
			tails_rc = cnt;
		if (pat[n])
			cnt = cnt + 1;
	end
end
endfunction

// Note that the register source id is set to the qid for now, until a ROB 
// entry is assigned. The rid will be looked up when the ROB entry is
// assigned.
task arg_vs;
input [QSLOTS-1:0] pat;
begin
	for (row = 0; row < QSLOTS; row = row + 1) begin
		if (pat[row]) begin
			iq_argA_v [tails[tails_rc(pat,row)]] <= regIsValid[Ra[row]] | SourceAValid(insnx[row]);
			iq_argA_s [tails[tails_rc(pat,row)]] <= rf_source[Ra[row]];
			// iq_argA is a constant
			iq_argB_v [tails[tails_rc(pat,row)]] <= regIsValid[Rb[row]] || Rb[row]==6'd0 || SourceBValid(insnx[row]);
			iq_argB_s [tails[tails_rc(pat,row)]] <= rf_source[Rb[row]];
			for (col = 0; col < QSLOTS; col = col + 1) begin
				if (col < row) begin
					if (pat[col]) begin
						if (Ra[row]==Rt[col] && slot_rfw[col] && Ra[row] != 6'd0) begin
							iq_argA_v [tails[tails_rc(pat,row)]] <= SourceAValid(insnx[row]);
							iq_argA_s [tails[tails_rc(pat,row)]] <= {1'b0,tails[tails_rc(pat,col)]};
						end
						if (Rb[row]==Rt[col] && slot_rfw[col] && Rb[row] != 6'd0) begin
							iq_argB_v [tails[tails_rc(pat,row)]] <= SourceBValid(insnx[row]);
							iq_argB_s [tails[tails_rc(pat,row)]] <= {1'b0,tails[tails_rc(pat,col)]};
						end
					end
				end
			end
		end
	end
end
endtask

task set_insn;
input Qid nn;
input [`IBTOP:0] bus;
begin
	iq_const [nn]  <= bus[`IB_CONST];
	iq_cmp	 [nn]  <= bus[`IB_CMP];
	iq_bt   [nn]  <= bus[`IB_BT];
	iq_alu  [nn]  <= bus[`IB_ALU];
	iq_alu0 [nn]  <= bus[`IB_ALU0];
	iq_fc   [nn]  <= bus[`IB_FC];
	iq_load [nn]  <= bus[`IB_LOAD];
	iq_store[nn]  <= bus[`IB_STORE];
	iq_memsz[nn]  <= bus[`IB_MEMSZ];
	iq_mem  [nn]  <= bus[`IB_MEM];
	iq_jmp  [nn]  <= bus[`IB_JAL];
	iq_br   [nn]  <= bus[`IB_BR];
	iq_rfw  [nn]  <= bus[`IB_RFW];
end
endtask

task queue_slot;
input [2:0] slot;
input Qid ndx;
input Seqnum seqnum;
input [`IBTOP:0] id_bus;
input Rid rid;
begin
	iq_rid[ndx] <= rid;
	iq_sn[ndx] <= seqnum;
	iq_state[ndx] <= IQS_QUEUED;
	//iq_br_tag[ndx] <= btag;
	iq_pc[ndx] <= pcs[slot];
	iq_len[ndx] <= slot ? len2 : len1;
	iq_instr[ndx] <= insnx[slot];
	iq_argA[ndx] <= argA[slot];
	iq_argB[ndx] <= argB[slot];
	iq_argA_v[ndx] <= regIsValid[Ra[slot]] || SourceAValid(insnx[slot]);
	iq_argB_v[ndx] <= regIsValid[Rb[slot]] || SourceBValid(insnx[slot]);
	iq_argA_s[ndx] <= rf_source[Ra[slot]];
	iq_argB_s[ndx] <= rf_source[Rb[slot]];
	iq_pt[ndx] <= take_branch[slot];
	iq_tgt[ndx] <= Rt[slot];
	set_insn(ndx,id_bus);
	rob.robEntries[rid].pc <= pcs[slot];
	rob.robEntries[rid].tgt <= Rt[slot];
	rob.robEntries[rid].rfw <= IsRFW(insnx[slot]);
	rob.robEntries[rid].res <= 1'd0;
	rob.robEntries[rid].state <= RS_ASSIGNED;
	rob.robEntries[rid].id <= ndx;
end
endtask

task tDram0Issue;
input [`QBITS] n;
begin
	if (iq_state[n]==IQS_AGEN) begin
//	dramA_v <= `INV;
		dram0 		<= `DRAMSLOT_BUSY;
		dram0_id 	<= n[`QBITS];
		dram0_rid <= iq_rid[n];
		dram0_instr <= iq_instr[n];
		dram0_tgt 	<= iq_tgt[n];
		dram0_data <= iq_argA[n][WID-1:0];
		dram0_addr	<= iq_ma[n];
		dram0_unc   <= iq_ma[n][51:20]==32'hFFFFFFFD || !dce;
		dram0_memsize <= iq_memsz[n];
		dram0_load <= iq_load[n];
		dram0_store <= iq_store[n];
		dram0_preload <= iq_load[n] & iq_tgt[n]==6'd0;
		iq_state[n] <= IQS_MEM;
		iq_memissue[n] <= `INV;
	end
end
endtask

task tDram1Issue;
input [`QBITS] n;
begin
	if (iq_state[n]==IQS_AGEN) begin
//	dramB_v <= `INV;
	dram1 		<= `DRAMSLOT_BUSY;
	dram1_id 	<= n[`QBITS];
	dram1_rid <= iq_rid[n];
	dram1_instr <= iq_instr[n];
	dram1_tgt 	<= iq_tgt[n];
	dram1_data <= iq_argA[n][WID-1:0];
	dram1_addr	<= iq_ma[n];
	dram1_unc   <= iq_ma[n][51:20]==32'hFFFFFFFD || !dce;
	dram1_memsize <= iq_memsz[n];
	dram1_load <= iq_load[n];
	dram1_store <= iq_store[n];
	dram1_preload <= iq_load[n] & iq_tgt[n]==6'd0;
	iq_state[n] <= IQS_MEM;
	iq_memissue[n] <= `INV;
	end
end
endtask

task wb_nack;
begin
	dcti <= 3'b000;
	dbte <= 2'b00;
	dcyc <= `LOW;
	dstb <= `LOW;
	dwe <= `LOW;
	dsel <= 8'h00;
//	vadr <= 32'hCCCCCCCC;
end
endtask

endmodule
