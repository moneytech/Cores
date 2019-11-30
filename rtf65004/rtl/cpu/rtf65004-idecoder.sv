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
`include ".\rtf65004-config.sv"
`include ".\rtf65004-defines.sv"

module idecoder(instr,predict_taken,bus);
input [15:0] instr;
input predict_taken;
output reg [`IBTOP:0] bus;

parameter TRUE = 1'b1;
parameter FALSE = 1'b0;
// Memory access sizes
parameter byt = 3'd0;
parameter wyde = 3'd1;

function IsMem;
input [15:0] isn;
case(isn[15:10])
`UO_LDB,`UO_LDW,`UO_STB,`UO_STW:
	IsMem = TRUE;
default:
	IsMem = FALSE;
endcase
endfunction

function IsLoad;
input [15:0] isn;
case(isn[15:10])
`UO_LDB,`UO_LDW:
	IsLoad = TRUE;
default:
	IsLoad = FALSE;
endcase
endfunction

function IsStore;
input [15:0] isn;
case(isn[15:10])
`UO_STB,`UO_STW:
	IsStore = TRUE;
default:
	IsStore = FALSE;
endcase
endfunction


function [2:0] MemSize;
input [15:0] isn;
casez(isn[15:10])
`UO_LDB:	MemSize = byt;
`UO_LDW:	MemSize = wyde;
`UO_STB:	MemSize = byt;
`UO_STW:	MemSize = wyde;
default:	MemSize = byt;
endcase
endfunction

function IsSei;
input [15:0] isn;
IsSei = isn[15:10]==`UO_SEI;
endfunction

function IsJmp;
input [15:0] isn;
IsJmp = isn[15:0]==`UO_JMP;
endfunction

// Really IsPredictableBranch
// Does not include BccR's
function IsBranch;
input [15:0] isn;
case(isn[15:10])
`UO_BEQ,`UO_BNE,`UO_BCS,`UO_BCC,`UO_BVS,`UO_BVC,`UO_BMI,`UO_BPL:
	IsBranch = TRUE;
default:
	IsBranch = FALSE;
endcase
endfunction

function IsRFW;
input [15:0] isn;
case(isn[15:10])
`UO_LDB,`UO_LDW,
`UO_ADDB,`UO_ADDW,`UO_ADCB,`UO_SBCB,
`UO_ANDB,`UO_ORB,`UO_EORB,
`UO_ASLB,`UO_LSRB,`UO_ROLB,`UO_RORB,
`UO_MOV:
	IsRFW = TRUE;
default
	IsRFW = FALSE;
endcase
endfunction

always @*
begin
	bus <= 167'h0;
	bus[`IB_CMP] <= IsCmp(instr);
//	bus[`IB_CONST] <= {{58{instr[39]}},instr[39:35],instr[32:16]};
//	bus[`IB_RT]		 <= fnRd(instr,ven,vl,thrd) | {thrd,7'b0};
//	bus[`IB_RC]		 <= fnRc(instr,ven,thrd) | {thrd,7'b0};
//	bus[`IB_RA]		 <= fnRa(instr,ven,vl,thrd) | {thrd,7'b0};
	bus[`IB_SRC1]		 <= instr[9:6];
	bus[`IB_SRC2]		 <= instr[2:0];
	bus[`IB_DST]		 <= instr[5:3];
	bus[`IB_IMM]	 <= HasConst(instr);
	// IB_BT is now used to indicate when to update the branch target buffer.
	// This occurs when one of the instructions with an unknown or calculated
	// target is present.
	bus[`IB_BT]		 <= 1'b0;
	bus[`IB_ALU]   <= instr[7:6]==2'b10;
	bus[`IB_FC]		 <= instr[7:5]==3'h6;
	bus[`IB_CANEX] <= fnCanException(instr);
	bus[`IB_LOAD]	 <= IsLoad(instr);
	bus[`IB_STORE]	<= IsStore(instr);
	bus[`IB_MEMSZ]  <= MemSize(instr);
	bus[`IB_MEM]		<= IsMem(instr);
	bus[`IB_SEI]		<= IsSei(instr);
	bus[`IB_JMP]		<= IsJmp(instr);
	bus[`IB_BR]			<= IsBranch(instr);
	bus[`IB_RFW]		<= IsRFW(instr);
end

endmodule
