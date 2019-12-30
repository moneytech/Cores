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
//
`include "..\inc\Gambit-config.sv"
`include "..\inc\Gambit-types.sv"

`define VAL		1'b1
`define INV		1'b0

module regfileValid(rst, clk, slotv, slot_rfw, tails,
	livetarget, branchmiss, rob_id,
	commit0_v, commit1_v,
	commit0_id, commit1_id,
	commit0_tgt, commit1_tgt,
	commit0_rfw, commit1_rfw,
	rf_source, iq_source, queuedOn,
	Rd, rf_v, regIsValid);
parameter AREGS = 128;
parameter RBIT = 5;
parameter IQ_ENTRIES = `IQ_ENTRIES;
parameter QSLOTS = `QSLOTS;
parameter RENTRIES = `RENTRIES;
parameter VAL = 1'b1;
parameter INV = 1'b0;
input rst;
input clk;
input [QSLOTS-1:0] slotv;
input [QSLOTS-1:0] slot_rfw;
input Rid tails [0:QSLOTS-1];
input [AREGS-1:0] livetarget;
input branchmiss;
input Qid rob_id [0:RENTRIES-1];
input commit0_v;
input commit1_v;
input Rid commit0_id;
input Rid commit1_id;
input RegTag commit0_tgt;
input RegTag commit1_tgt;
input commit0_rfw;
input commit1_rfw;
input Qid rf_source [0:AREGS-1];
input [IQ_ENTRIES-1:0] iq_source;
input RegTag Rd [0:QSLOTS-1];
input [QSLOTS-1:0] queuedOn;
output reg [`AREGS-1:0] rf_v;
output reg [`AREGS-1:0] regIsValid;	// advanced signal

integer n;
Qid id0, id1;

// Detect if a given register will become valid during the current cycle.
// We want a signal that is active during the current clock cycle for the read
// through register file, which trims a cycle off register access for every
// instruction. But two different kinds of assignment statements can't be
// placed under the same always block, it's a bad practice and may not work.
// So a signal is created here with it's own always block.
always @*
begin
	for (n = 1; n < AREGS; n = n + 1)
	begin
		regIsValid[n] = rf_v[n];
		if (branchmiss) begin
       if (~(livetarget[n]))
     			regIsValid[n] = `VAL;
    end

		id0 = rob_id[commit0_id];
		id1 = rob_id[commit1_id];
		if (commit0_v && n==commit0_tgt && !rf_v[n] && commit0_rfw)
			regIsValid[n] = ((rf_source[ n ] == commit0_id) || (branchmiss && (iq_source[ id0 ])));
		if (commit1_v && n==commit1_tgt && !rf_v[n] && commit1_rfw)
			regIsValid[n] = ((rf_source[ n ] == commit1_id) || (branchmiss && (iq_source[ id1 ])));
	end
	
	regIsValid[0] = `VAL;
end


always @(posedge clk)
if (rst) begin
  for (n = 0; n < AREGS; n = n + 1)
    rf_v[n] <= `VAL;
end
else begin

	if (branchmiss) begin
		for (n = 1; n < AREGS; n = n + 1)
			if (~(livetarget[n])) begin
				rf_v[n] <= `VAL;
		end
	end

  // The source for the register file data might have changed since it was
  // placed on the commit bus. So it's needed to check that the source is
  // still as expected to validate the register.
	if (commit0_v && commit0_rfw) begin
		$display("!rfv=%d %d",!rf_v[ commit0_tgt ], rf_v[ commit0_tgt ] );
    if (!rf_v[ commit0_tgt ]) begin
      rf_v[ commit0_tgt ] <= (rf_source[ commit0_tgt ] == commit0_id) || (branchmiss && (iq_source[ rob_id[commit0_id] ]));
      $display("rfv 0: %d %d", rf_source[ commit0_tgt], commit0_id);
    end
  end
  if (commit1_v && commit1_rfw) begin
		$display("!rfv=%d %d",!rf_v[ commit1_tgt ], rf_v[ commit1_tgt] );
    if (!rf_v[ commit1_tgt ]) begin //&& !(commit0_v && (rf_source[ commit0_tgt[RBIT:0] ] == commit0_id || (branchmiss && iq_source[ commit0_id[`QBITS] ]))))
      rf_v[ commit1_tgt ] <= (rf_source[ commit1_tgt ] == commit1_id) || (branchmiss && (iq_source[ rob_id[commit1_id] ]));
      $display("rfv 1: %d %d", rf_source[ commit0_tgt ][`RBITS], commit0_id);
    end
  end

	$display("slot_rfw: %h", slot_rfw);
	$display("quedon : %h", queuedOn);
	$display("slotv: %h", slotv);
	if (!branchmiss) begin
		if (queuedOn[0]) begin
			if (slot_rfw[0]) begin
				rf_v [Rd[0]] <= `INV;
			end
		end
		if (queuedOn[1]) begin
			if (slot_rfw[1]) begin
				rf_v [Rd[1]] <= `INV;
			end
		end
	end
/*
		case(slotv)
		2'b00:	;
		2'b01:
			if (queuedOn[0]) begin
				if (slot_rfw[0]) begin
					rf_v [Rd[0]] <= `INV;
				end
			end
		2'b10:
			if (queuedOn[1]) begin
				if (slot_rfw[1]) begin
					rf_v [Rd[1]] <= `INV;
				end
			end
		2'b11:
			begin
				if (queuedOn[0]) begin
					if (slot_rfw[0]) begin
						rf_v [Rd[0]] <= `INV;
					end
				end
				if (queuedOn[1]) begin
					if (slot_rfw[1]) begin
						rf_v [Rd[1]] <= `INV;
					end
				end
			end
		endcase
*/
	rf_v[0] <= `VAL;
end

endmodule