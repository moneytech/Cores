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
//
// ============================================================================
//
`include "..\inc\Gambit-config.sv"
`include "..\inc\Gambit-defines.sv"
`include "..\inc\Gambit-types.sv"

module agenIssue(agen0_idle, agen1_idle, heads, could_issue, iq_mem, prior_sync, prior_valid, issue0, issue1);
input agen0_idle;
input agen1_idle;
input Qid heads [0:`IQ_ENTRIES-1];
input [`IQ_ENTRIES-1:0] could_issue;
input [`IQ_ENTRIES-1:0] iq_mem;
input [`IQ_ENTRIES-1:0] prior_sync;
input [`IQ_ENTRIES-1:0] prior_valid;
output reg [`IQ_ENTRIES-1:0] issue0;
output reg [`IQ_ENTRIES-1:0] issue1;


integer n;
Qid hd;

always @*
begin
	issue0 = {`IQ_ENTRIES{1'b0}};
	issue1 = {`IQ_ENTRIES{1'b0}};
	
	if (agen0_idle) begin
		for (n = 0; n < `IQ_ENTRIES; n = n + 1) begin
			hd = heads[n];
			if (could_issue[hd] && iq_mem[hd] && issue0 == {`IQ_ENTRIES{1'b0}}
			// If there are no valid queue entries prior it doesn't matter if there is
			// a sync.
			&& (!prior_sync[hd] || !prior_valid[hd])
			)
			  issue0[hd] = `TRUE;
		end
	end

	if (agen1_idle && `NUM_AGEN > 1) begin
		for (n = 0; n < `IQ_ENTRIES; n = n + 1) begin
			hd = heads[n];
			if (could_issue[hd] && iq_mem[hd]
				&& !issue0[hd]
				&& issue1 == {`IQ_ENTRIES{1'b0}}
				&& (!prior_sync[hd] || !prior_valid[hd])
			)
			  issue1[hd] = `TRUE;
		end
	end
end

endmodule