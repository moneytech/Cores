// ============================================================================
//        __
//   \\__/ o\    (C) 2017-2018  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	FT64_idecoder.v
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
`include ".\FT64_defines.vh"

module FT64_idecoder(clk,idv_i,id_i,instr,vl,ven,thrd,predict_taken,Rt,bus,id_o,idv_o);
input clk;
input idv_i;
input [4:0] id_i;
input [47:0] instr;
input [7:0] vl;
input [5:0] ven;
input thrd;
input predict_taken;
input [4:0] Rt;
output reg [127:0] bus;
output reg [4:0] id_o;
output reg idv_o;

parameter TRUE = 1'b1;
parameter FALSE = 1'b0;

// Really IsPredictableBranch
// Does not include BccR's
//function IsBranch;
//input [47:0] isn;
//casez(isn[`INSTRUCTION_OP])
//`Bcc:   IsBranch = TRUE;
//`BBc:   IsBranch = TRUE;
//`BEQI:  IsBranch = TRUE;
//`CHK:   IsBranch = TRUE;
//default:    IsBranch = FALSE;
//endcase
//endfunction

wire iAlu;
mIsALU uialu1
(
	.instr(instr),
	.IsALU(iAlu)
);


reg IsALU;
always @*
case(instr[`INSTRUCTION_OP])
`R2:    if (instr[`INSTRUCTION_L2]==2'b00)
			case(instr[`INSTRUCTION_S2])
			`VMOV:		IsALU = TRUE;
	        `RTI:       IsALU = FALSE;
	        default:    IsALU = TRUE;
	        endcase
	    else
	    	IsALU = TRUE;
`BRK:   IsALU = FALSE;
`Bcc:   IsALU = FALSE;
`BBc:   IsALU = FALSE;
`BEQI:  IsALU = FALSE;
`CHK:   IsALU = FALSE;
`JAL:   IsALU = FALSE;
`JMP:	IsALU = FALSE;
`CALL:  IsALU = FALSE;
`RET:   IsALU = FALSE;
`FVECTOR:
			case(instr[`INSTRUCTION_S2])
            `VSHL,`VSHR,`VASR:  IsALU = TRUE;
            default:    IsALU = FALSE;  // Integer
            endcase
`IVECTOR:
			case(instr[`INSTRUCTION_S2])
            `VSHL,`VSHR,`VASR:  IsALU = TRUE;
            default:    IsALU = TRUE;  // Integer
            endcase
`FLOAT:		IsALU = FALSE;            
default:    IsALU = TRUE;
endcase

function IsAlu0Only;
input [47:0] isn;
begin
case(isn[`INSTRUCTION_OP])
`R2:
	if (isn[`INSTRUCTION_L2]==2'b00)
		case(isn[`INSTRUCTION_S2])
		`R1:        IsAlu0Only = TRUE;
		`SHIFTR,`SHIFT31,`SHIFT63:
			IsAlu0Only = TRUE;
		`LBX,`LBUX,`LCX,`LCUX,`LHX,`LHUX,`LWX,`LWRX:
			IsAlu0Only = TRUE;
		`SBX,`SCX,`SHX,`SWX,`SWCX: IsAlu0Only = TRUE;
		`LVX,`SVX,`LVx:  IsAlu0Only = TRUE;
		`MULU,`MULSU,`MUL,
		`DIVMODU,`DIVMODSU,`DIVMOD: IsAlu0Only = TRUE;
		`MIN,`MAX:  IsAlu0Only = TRUE;
		default:    IsAlu0Only = FALSE;
		endcase
	else
		IsAlu0Only = FALSE;
`IVECTOR,`FVECTOR:
	case(isn[`INSTRUCTION_S2])
	`VSHL,`VSHR,`VASR:  IsAlu0Only = TRUE;
	default: IsAlu0Only = FALSE;
	endcase
`BITFIELD:  IsAlu0Only = TRUE;
`MULUI,`MULI,
`DIVUI,`DIVI,
`MODI:   IsAlu0Only = TRUE;
`CSRRW: IsAlu0Only = TRUE;
default:    IsAlu0Only = FALSE;
endcase
end
endfunction

function IsFPU;
input [47:0] isn;
begin
case(isn[`INSTRUCTION_OP])
`FLOAT: IsFPU = TRUE;
`FVECTOR:
		    case(isn[`INSTRUCTION_S2])
            `VSHL,`VSHR,`VASR:  IsFPU = FALSE;
            default:    IsFPU = TRUE;
            endcase
default:    IsFPU = FALSE;
endcase
end
endfunction

reg IsFlowCtrl;

always @*
case(instr[`INSTRUCTION_OP])
`BRK:    IsFlowCtrl <= TRUE;
`RR:    case(instr[`INSTRUCTION_S2])
        `RTI:   IsFlowCtrl <= TRUE;
        default:    IsFlowCtrl <= FALSE;
        endcase
`Bcc:   IsFlowCtrl <= TRUE;
`BBc:		IsFlowCtrl <= TRUE;
`BEQI:  IsFlowCtrl <= TRUE;
`CHK:   IsFlowCtrl <= TRUE;
`JAL:   IsFlowCtrl <= TRUE;
`JMP:		IsFlowCtrl <= TRUE;
`CALL:  IsFlowCtrl <= TRUE;
`RET:   IsFlowCtrl <= TRUE;
default:    IsFlowCtrl <= FALSE;
endcase

//function IsFlowCtrl;
//input [47:0] isn;
//begin
//case(isn[`INSTRUCTION_OP])
//`BRK:    IsFlowCtrl = TRUE;
//`RR:    case(isn[`INSTRUCTION_S2])
//        `RTI:   IsFlowCtrl = TRUE;
//        default:    IsFlowCtrl = FALSE;
//        endcase
//`Bcc:   IsFlowCtrl = TRUE;
//`BBc:		IsFlowCtrl = TRUE;
//`BEQI:  IsFlowCtrl = TRUE;
//`CHK:   IsFlowCtrl = TRUE;
//`JAL:   IsFlowCtrl = TRUE;
//`JMP:		IsFlowCtrl = TRUE;
//`CALL:  IsFlowCtrl = TRUE;
//`RET:   IsFlowCtrl = TRUE;
//default:    IsFlowCtrl = FALSE;
//endcase
//end
//endfunction

// fnCanException
//
// Used by memory issue logic.
// Returns TRUE if the instruction can cause an exception.
// In debug mode any instruction could potentially cause a breakpoint exception.
// Rather than check all the addresses for potential debug exceptions it's
// simpler to just have it so that all instructions could exception. This will
// slow processing down somewhat as stores will only be done at the head of the
// instruction queue, but it's debug mode so we probably don't care.
//
function fnCanException;
input [47:0] isn;
begin
// ToDo add debug_on as input
`ifdef SUPPORT_DBG
if (debug_on)
    fnCanException = `TRUE;
else
`endif
case(isn[`INSTRUCTION_OP])
`FLOAT:
    case(isn[`INSTRUCTION_S2])
    `FDIV,`FMUL,`FADD,`FSUB,`FTX:
        fnCanException = `TRUE;
    default:    fnCanException = `FALSE;
    endcase
`ADDI,`DIVI,`MODI,`MULI:
    fnCanException = `TRUE;
`R2:
    case(isn[`INSTRUCTION_S2])
    `ADD,`SUB,`MUL,`DIVMOD,`MULSU,`DIVMODSU:   fnCanException = TRUE;
    `RTI:   fnCanException = TRUE;
    default:    fnCanException = FALSE;
    endcase
`Bcc:	fnCanException = TRUE;
`BEQI:	fnCanException = TRUE;
`CHK:	fnCanException = TRUE;
default:
    fnCanException = IsMem(isn);
endcase
end
endfunction

function IsLoad;
input [47:0] isn;
case(isn[`INSTRUCTION_OP])
`R2:
	if (isn[`INSTRUCTION_L2]==2'b00)
	    case(isn[`INSTRUCTION_S2])
	    `LBX:   IsLoad = TRUE;
	    `LBUX:  IsLoad = TRUE;
	    `LCX:   IsLoad = TRUE;
	    `LCUX:  IsLoad = TRUE;
	    `LHX:   IsLoad = TRUE;
	    `LHUX:  IsLoad = TRUE;
	    `LWX:   IsLoad = TRUE;
	    `LWRX:  IsLoad = TRUE;
	    `LVX:   IsLoad = TRUE;
	    `LVx:	IsLoad = TRUE;
	    default: IsLoad = FALSE;   
	    endcase
	else
		IsLoad = FALSE;
`LB:    IsLoad = TRUE;
`LBU:   IsLoad = TRUE;
`Lx:    IsLoad = TRUE;
`LxU:   IsLoad = TRUE;
`LWR:   IsLoad = TRUE;
`LV:    IsLoad = TRUE;
`LVx:   IsLoad = TRUE;
default:    IsLoad = FALSE;
endcase
endfunction

function [0:0] IsMem;
input [47:0] isn;
case(isn[`INSTRUCTION_OP])
`R2:
	if (isn[`INSTRUCTION_L2]==2'b00)
		case(isn[`INSTRUCTION_S2])
		`LBX:   IsMem = TRUE;
		`LBUX:  IsMem = TRUE;
		`LCX:   IsMem = TRUE;
		`LCUX:  IsMem = TRUE;
		`LHX:   IsMem = TRUE;
		`LHUX:  IsMem = TRUE;
		`LWX:   IsMem = TRUE;
		`LWRX:  IsMem = TRUE;
		`SBX:   IsMem = TRUE;
		`SCX:   IsMem = TRUE;
		`SHX:   IsMem = TRUE;
		`SWX:   IsMem = TRUE;
		`SWCX:  IsMem = TRUE;
		`INC:	IsMem = TRUE;
		`CASX:  IsMem = TRUE;
		`LVX,`SVX:  IsMem = TRUE;
		`LVx:	IsMem = TRUE;
		default: IsMem = FALSE;
		endcase
	else
		IsMem = FALSE;
`AMO:	IsMem = TRUE;
`LB:    IsMem = TRUE;
`LBU:   IsMem = TRUE;
`Lx:    IsMem = TRUE;
`LxU:   IsMem = TRUE;
`LWR:   IsMem = TRUE;
`LV,`SV:    IsMem = TRUE;
`INC:		IsMem = TRUE;
`SB:    IsMem = TRUE;
`Sx:    IsMem = TRUE;
`SWC:   IsMem = TRUE;
`CAS:   IsMem = TRUE;
`LVx:		IsMem = TRUE;
default:    IsMem = FALSE;
endcase
endfunction

function IsMemNdx;
input [47:0] isn;
case(isn[`INSTRUCTION_OP])
`R2:
	if (isn[`INSTRUCTION_L2]==2'b00)
	    case(isn[`INSTRUCTION_S2])
	    `LBX:   IsMemNdx = TRUE;
	    `LBUX:  IsMemNdx = TRUE;
	    `LCX:   IsMemNdx = TRUE;
	    `LCUX:  IsMemNdx = TRUE;
	    `LHX:   IsMemNdx = TRUE;
	    `LHUX:  IsMemNdx = TRUE;
	    `LWX:   IsMemNdx = TRUE;
	    `LWRX:  IsMemNdx = TRUE;
	    `SBX:   IsMemNdx = TRUE;
	    `SCX:   IsMemNdx = TRUE;
	    `SHX:   IsMemNdx = TRUE;
	    `SWX:   IsMemNdx = TRUE;
	    `SWCX:  IsMemNdx = TRUE;
	    `CASX:  IsMemNdx = TRUE;
	    `LVX,`SVX:  IsMemNdx = TRUE;
	    `LVx:	IsMemNdx = TRUE;
	    `INC:	IsMemNdx = TRUE;
	    default: IsMemNdx = FALSE;
	    endcase
	else
		IsMemNdx = FALSE;
default:    IsMemNdx = FALSE;
endcase
endfunction

function IsCAS;
input [47:0] isn;
case(isn[`INSTRUCTION_OP])
`R2:
	if (isn[`INSTRUCTION_L2]==2'b00)
	    case(isn[`INSTRUCTION_S2])
	    `CASX:   IsCAS = TRUE;
	    default:    IsCAS = FALSE;
	    endcase
	else
		IsCAS = FALSE;
`CAS:       IsCAS = TRUE;
default:    IsCAS = FALSE;
endcase
endfunction

function IsAMO;
input [47:0] isn;
case(isn[`INSTRUCTION_OP])
`AMO:       IsAMO = TRUE;
default:    IsAMO = FALSE;
endcase
endfunction

function IsInc;
input [47:0] isn;
case(isn[`INSTRUCTION_OP])
`R2:
   	if (isn[`INSTRUCTION_L2]==2'b00)
		case(isn[`INSTRUCTION_S2])
	    `INC:   IsInc = TRUE;
	    default:    IsInc = FALSE;
	    endcase
	else
		IsInc = FALSE;
`INC:    IsInc = TRUE;
default:    IsInc = FALSE;
endcase
endfunction

function IsSync;
input [47:0] isn;
IsSync = (isn[`INSTRUCTION_OP]==`R2 && isn[`INSTRUCTION_L2]==2'b00 && isn[`INSTRUCTION_S2]==`R1 && isn[22:18]==`SYNC); 
endfunction

function IsFSync;
input [47:0] isn;
IsFSync = (isn[`INSTRUCTION_OP]==`FLOAT && isn[`INSTRUCTION_L2]==2'b00 && isn[`INSTRUCTION_S2]==`FSYNC); 
endfunction

function IsMemdb;
input [47:0] isn;
IsMemdb = (isn[`INSTRUCTION_OP]==`R2 && isn[`INSTRUCTION_L2]==2'b00 && isn[`INSTRUCTION_S2]==`R1 && isn[22:18]==`MEMDB); 
endfunction

function IsMemsb;
input [47:0] isn;
IsMemsb = (isn[`INSTRUCTION_OP]==`RR && isn[`INSTRUCTION_L2]==2'b00 && isn[`INSTRUCTION_S2]==`R1 && isn[22:18]==`MEMSB); 
endfunction

function IsSEI;
input [47:0] isn;
IsSEI = (isn[`INSTRUCTION_OP]==`R2 && isn[`INSTRUCTION_L2]==2'b00 && isn[`INSTRUCTION_S2]==`SEI); 
endfunction

function IsShift48;
input [47:0] isn;
case(isn[`INSTRUCTION_OP])
`R2:
	if (isn[`INSTRUCTION_L2]==2'b01)
	    case(isn[47:42])
	    `SHIFTR: IsShift48 = TRUE;
	    default: IsShift48 = FALSE;
	    endcase
    else
    	IsShift48 = FALSE;
default: IsShift48 = FALSE;
endcase
endfunction

function IsLWRX;
input [47:0] isn;
case(isn[`INSTRUCTION_OP])
`R2:
	if (isn[`INSTRUCTION_L2]==2'b00)
	    case(isn[`INSTRUCTION_S2])
	    `LWRX:   IsLWRX = TRUE;
	    default:    IsLWRX = FALSE;
	    endcase
	else
		IsLWRX = FALSE;
default:    IsLWRX = FALSE;
endcase
endfunction

// Aquire / release bits are only available on indexed SWC / LWR
function IsSWCX;
input [47:0] isn;
case(isn[`INSTRUCTION_OP])
`R2:
	if (isn[`INSTRUCTION_L2]==2'b00)
	    case(isn[`INSTRUCTION_S2])
	    `SWCX:   IsSWCX = TRUE;
	    default:    IsSWCX = FALSE;
	    endcase
	else
		IsSWCX = FALSE;
default:    IsSWCX = FALSE;
endcase
endfunction

function IsJmp;
input [47:0] isn;
IsJmp = isn[`INSTRUCTION_OP]==`JMP && isn[7]==1'b0;
endfunction

// Really IsPredictableBranch
// Does not include BccR's
function IsBranch;
input [47:0] isn;
casez(isn[`INSTRUCTION_OP])
`Bcc:   IsBranch = TRUE;
`BBc:   IsBranch = TRUE;
`BEQI:  IsBranch = TRUE;
`CHK:   IsBranch = TRUE;
default:    IsBranch = FALSE;
endcase
endfunction

function IsBrk;
input [47:0] isn;
IsBrk = isn[`INSTRUCTION_OP]==`BRK && isn[`INSTRUCTION_L2]==2'b00;
endfunction

function IsRti;
input [47:0] isn;
IsRti = isn[`INSTRUCTION_OP]==`RR && isn[`INSTRUCTION_L2]==2'b00 && isn[`INSTRUCTION_S2]==`RTI;
endfunction

// Has an extendable 14-bit constant
function HasConst;
input [47:0] isn;
casez(isn[`INSTRUCTION_OP])
`ADDI:  HasConst = TRUE;
`SLTI:  HasConst = TRUE;
`SLTUI: HasConst = TRUE;
`SGTI:  HasConst = TRUE;
`SGTUI: HasConst = TRUE;
`ANDI:  HasConst = TRUE;
`ORI:   HasConst = TRUE;
`XORI:  HasConst = TRUE;
`XNORI: HasConst = TRUE;
`MULUI: HasConst = TRUE;
`MULI:  HasConst = TRUE;
`DIVUI: HasConst = TRUE;
`DIVI:  HasConst = TRUE;
`MODI:  HasConst = TRUE;
`LB:    HasConst = TRUE;
`LBU:   HasConst = TRUE;
`Lx:    HasConst = TRUE;
`LWR:		HasConst = TRUE;
`LV:    HasConst = TRUE;
`SB:  	HasConst = TRUE;
`Sx:  	HasConst = TRUE;
`SWC:   HasConst = TRUE;
`INC:		HasConst = TRUE;
`SV:    HasConst = TRUE;
`CAS:   HasConst = TRUE;
`JAL:   HasConst = TRUE;
`CALL:  HasConst = TRUE;
`RET:   HasConst = TRUE;
`LVx:		HasConst = TRUE;
default:    HasConst = FALSE;
endcase
endfunction

function IsRFW;
input [47:0] isn;
casez(isn[`INSTRUCTION_OP])
`IVECTOR:   IsRFW = TRUE;
`FVECTOR:   IsRFW = TRUE;
`R2:
	if (isn[`INSTRUCTION_L2]==2'b00)
	    case(isn[`INSTRUCTION_S2])
	    `R1:    IsRFW = TRUE;
	    `ADD:   IsRFW = TRUE;
	    `SUB:   IsRFW = TRUE;
	    `SLT:   IsRFW = TRUE;
	    `SLTU:  IsRFW = TRUE;
	    `SLE:   IsRFW = TRUE;
	    `SLEU:  IsRFW = TRUE;
	    `AND:   IsRFW = TRUE;
	    `OR:    IsRFW = TRUE;
	    `XOR:   IsRFW = TRUE;
	    `MULU:  IsRFW = TRUE;
	    `MULSU: IsRFW = TRUE;
	    `MUL:   IsRFW = TRUE;
	    `DIVMODU:  IsRFW = TRUE;
	    `DIVMODSU: IsRFW = TRUE;
	    `DIVMOD:IsRFW = TRUE;
	    `LBX:   IsRFW = TRUE;
	    `LBUX:  IsRFW = TRUE;
	    `LCX:   IsRFW = TRUE;
	    `LCUX:  IsRFW = TRUE;
	    `LHX:   IsRFW = TRUE;
	    `LHUX:  IsRFW = TRUE;
	    `LWX:   IsRFW = TRUE;
	    `LWRX:  IsRFW = TRUE;
	    `LVX:   IsRFW = TRUE;
	    `LVx:	IsRFW = TRUE;
	    `CASX:  IsRFW = TRUE;
	    `MOV:	IsRFW = TRUE;
	    `VMOV:	IsRFW = TRUE;
	    `SHIFTR,`SHIFT31,`SHIFT63:
		    	IsRFW = TRUE;
	    `MIN,`MAX:    IsRFW = TRUE;
	    `SEI:	IsRFW = TRUE;
	    default:    IsRFW = FALSE;
	    endcase
	else
		IsRFW = FALSE;
`BBc:
	case(isn[20:19])
	`IBNE:	IsRFW = TRUE;
	`DBNZ:	IsRFW = TRUE;
	default:	IsRFW = FALSE;
	endcase
`BITFIELD:  IsRFW = TRUE;
`ADDI:      IsRFW = TRUE;
`SLTI:      IsRFW = TRUE;
`SLTUI:     IsRFW = TRUE;
`SGTI:      IsRFW = TRUE;
`SGTUI:     IsRFW = TRUE;
`ANDI:      IsRFW = TRUE;
`ORI:       IsRFW = TRUE;
`XORI:      IsRFW = TRUE;
`MULUI:     IsRFW = TRUE;
`MULI:      IsRFW = TRUE;
`DIVUI:     IsRFW = TRUE;
`DIVI:      IsRFW = TRUE;
`MODI:      IsRFW = TRUE;
`JAL:       IsRFW = TRUE;
`CALL:      IsRFW = TRUE;  
`RET:       IsRFW = TRUE; 
`LB:        IsRFW = TRUE;
`LBU:       IsRFW = TRUE;
`Lx:        IsRFW = TRUE;
`LWR:       IsRFW = TRUE;
`LV:        IsRFW = TRUE;
`LVx:				IsRFW = TRUE;
`CAS:       IsRFW = TRUE;
`AMO:				IsRFW = TRUE;
`CSRRW:			IsRFW = TRUE;
default:    IsRFW = FALSE;
endcase
endfunction

// Determines which lanes of the target register get updated.
function [7:0] fnWe;
input [47:0] isn;
casez(isn[`INSTRUCTION_OP])
`R2:
	case(isn[`INSTRUCTION_S2])
	`R1:
		case(isn[22:18])
		`ABS,`CNTLZ,`CNTLO,`CNTPOP:
			case(isn[25:23])
			3'b000: fnWe = 8'h01;
			3'b001:	fnWe = 8'h03;
			3'b010:	fnWe = 8'h0F;
			3'b011:	fnWe = 8'hFF;
			default:	fnWe = 8'hFF;
			endcase
		default: fnWe = 8'hFF;
		endcase
	`SHIFT31:	fnWe = (~isn[25] & isn[21]) ? 8'hFF : 8'hFF;
	`SHIFT63:	fnWe = (~isn[25] & isn[21]) ? 8'hFF : 8'hFF;
	`SLT,`SLTU,`SLE,`SLEU,
	`ADD,`SUB,
	`AND,`OR,`XOR,
	`NAND,`NOR,`XNOR,
	`DIVMOD,`DIVMODU,`DIVMODSU,
	`MUL,`MULU,`MULSU:
		case(isn[25:23])
		3'b000: fnWe = 8'h01;
		3'b001:	fnWe = 8'h03;
		3'b010:	fnWe = 8'h0F;
		3'b011:	fnWe = 8'hFF;
		default:	fnWe = 8'hFF;
		endcase
	default: fnWe = 8'hFF;
	endcase
default:	fnWe = 8'hFF;
endcase
endfunction

// Detect if a source is automatically valid
function Source1Valid;
input [47:0] isn;
casez(isn[`INSTRUCTION_OP])
`BRK:   Source1Valid = TRUE;
`Bcc:   Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`BBc:   Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`BEQI:  Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`CHK:   Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`RR:    case(isn[`INSTRUCTION_S2])
        `SHIFT31:  Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
        `SHIFT63:  Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
        `SHIFTR:   Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
        default:   Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
        endcase
`ADDI:  Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`SLTI:  Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`SLTUI: Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`SGTI:  Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`SGTUI: Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`ANDI:  Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`ORI:   Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`XORI:  Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`XNORI: Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`MULUI: Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`AMO: 	Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`LB:    Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`LBU:   Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`Lx:    Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`LxU:   Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`LWR:   Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`LV:    Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`LVx:   Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`SB:    Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`Sx:    Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`SWC:   Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`SV:    Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`INC:   Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`CAS:   Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`JAL:   Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`RET:   Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`CSRRW: Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`BITFIELD: 	case(isn[31:28])
			`BFINSI:	Source1Valid = TRUE;
			default:	Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
			endcase
`IVECTOR:
			Source1Valid = FALSE;
default:    Source1Valid = TRUE;
endcase
endfunction
  
function Source2Valid;
input [47:0] isn;
casez(isn[`INSTRUCTION_OP])
`BRK:   Source2Valid = TRUE;
`Bcc:   Source2Valid = isn[`INSTRUCTION_RB]==5'd0;
`BBc:   Source2Valid = TRUE;
`BEQI:  Source2Valid = TRUE;
`CHK:   Source2Valid = isn[`INSTRUCTION_RB]==5'd0;
`RR:    case(isn[`INSTRUCTION_S2])
        `R1:       Source2Valid = TRUE;
        `SHIFTR:   Source2Valid = isn[25] ? 1'b1 : isn[`INSTRUCTION_RB]==5'd0;
        `SHIFT31:  Source2Valid = isn[25] ? 1'b1 : isn[`INSTRUCTION_RB]==5'd0;
        `SHIFT63:  Source2Valid = isn[25] ? 1'b1 : isn[`INSTRUCTION_RB]==5'd0;
        `LVX,`SVX: Source2Valid = FALSE;
        default:   Source2Valid = isn[`INSTRUCTION_RB]==5'd0;
        endcase
`ADDI:  Source2Valid = TRUE;
`SLTI:  Source2Valid = TRUE;
`SLTUI: Source2Valid = TRUE;
`SGTI:  Source2Valid = TRUE;
`SGTUI: Source2Valid = TRUE;
`ANDI:  Source2Valid = TRUE;
`ORI:   Source2Valid = TRUE;
`XORI:  Source2Valid = TRUE;
`XNORI: Source2Valid = TRUE;
`MULUI: Source2Valid = TRUE;
`LB:    Source2Valid = TRUE;
`LBU:   Source2Valid = TRUE;
`Lx:    Source2Valid = TRUE;
`LxU:   Source2Valid = TRUE;
`LWR:   Source2Valid = TRUE;
`LVx:   Source2Valid = TRUE;
`INC:		Source2Valid = TRUE;
`SB:    Source2Valid = isn[`INSTRUCTION_RB]==5'd0;
`Sx:    Source2Valid = isn[`INSTRUCTION_RB]==5'd0;
`SWC:   Source2Valid = isn[`INSTRUCTION_RB]==5'd0;
`CAS:   Source2Valid = isn[`INSTRUCTION_RB]==5'd0;
`JAL:   Source2Valid = TRUE;
`RET:   Source2Valid = isn[`INSTRUCTION_RB]==5'd0;
`IVECTOR:
		    case(isn[`INSTRUCTION_S2])
            `VABS:  Source2Valid = TRUE;
            `VMAND,`VMOR,`VMXOR,`VMXNOR,`VMPOP:
                Source2Valid = FALSE;
            `VADDS,`VSUBS,`VANDS,`VORS,`VXORS:
                Source2Valid = isn[`INSTRUCTION_RB]==5'd0;
            `VBITS2V:   Source2Valid = TRUE;
            `V2BITS:    Source2Valid = isn[`INSTRUCTION_RB]==5'd0;
            `VSHL,`VSHR,`VASR:  Source2Valid = isn[22:21]==2'd2;
            default:    Source2Valid = FALSE;
            endcase
`LV:        Source2Valid = TRUE;
`SV:        Source2Valid = FALSE;
`AMO:		Source2Valid = isn[31] || isn[`INSTRUCTION_RB]==5'd0;
default:    Source2Valid = TRUE;
endcase
endfunction

function Source3Valid;
input [47:0] isn;
case(isn[`INSTRUCTION_OP])
`IVECTOR:
    case(isn[`INSTRUCTION_S2])
    `VEX:       Source3Valid = TRUE;
    default:    Source3Valid = TRUE;
    endcase
`CHK:   Source3Valid = isn[`INSTRUCTION_RC]==5'd0;
`R2:
	if (isn[`INSTRUCTION_L2]==2'b01)
		case(isn[47:42])
    `CMOVEZ,`CMOVNZ:  Source3Valid = isn[`INSTRUCTION_RC]==5'd0;
		default:	Source3Valid = TRUE;
		endcase
	else
    case(isn[`INSTRUCTION_S2])
    `SBX:   Source3Valid = isn[`INSTRUCTION_RC]==5'd0;
    `SCX:   Source3Valid = isn[`INSTRUCTION_RC]==5'd0;
    `SHX:   Source3Valid = isn[`INSTRUCTION_RC]==5'd0;
    `SWX:   Source3Valid = isn[`INSTRUCTION_RC]==5'd0;
    `SWCX:  Source3Valid = isn[`INSTRUCTION_RC]==5'd0;
    `CASX:  Source3Valid = isn[`INSTRUCTION_RC]==5'd0;
    `MAJ:		Source3Valid = isn[`INSTRUCTION_RC]==5'd0;
    default:    Source3Valid = TRUE;
    endcase
default:    Source3Valid = TRUE;
endcase
endfunction

always @(posedge clk)
begin
	bus <= 128'h0;
	bus[`IB_CONST] <= instr[7:6]==2'b01 ? {{34{instr[47]}},instr[47:18]} :
																				{{50{instr[31]}},instr[31:18]};
	case(instr[7:6])
	2'b00:	bus[`IB_LN] <= 3'd4;
	2'b01:	bus[`IB_LN] <= 3'd6;
	default: bus[`IB_LN] <= 3'd2;
	endcase
//	bus[`IB_RT]		 <= fnRt(instr,ven,vl,thrd) | {thrd,7'b0};
//	bus[`IB_RC]		 <= fnRc(instr,ven,thrd) | {thrd,7'b0};
//	bus[`IB_RA]		 <= fnRa(instr,ven,vl,thrd) | {thrd,7'b0};
	bus[`IB_IMM]	 <= HasConst(instr);
	bus[`IB_A3V]   <= Source3Valid(instr);
	bus[`IB_A2V]   <= Source2Valid(instr);
	bus[`IB_A1V]   <= Source1Valid(instr);
	bus[`IB_BT]    <= (IsBranch(instr) && predict_taken);
	bus[`IB_ALU]   <= IsALU;
	bus[`IB_ALU0]  <= IsAlu0Only(instr);
	bus[`IB_FPU]   <= IsFPU(instr);
	bus[`IB_FC]		 <= IsFlowCtrl;
	bus[`IB_CANEX] <= fnCanException(instr);
	bus[`IB_LOAD]	 <= IsLoad(instr);
	bus[`IB_PRELOAD] <=   IsLoad(instr) && Rt==5'd0;
	bus[`IB_MEM]		<= IsMem(instr);
	bus[`IB_MEMNDX]	<= IsMemNdx(instr);
	bus[`IB_RMW]		<= IsCAS(instr) || IsAMO(instr) || IsInc(instr);
	bus[`IB_MEMDB]	<= IsMemdb(instr);
	bus[`IB_MEMSB]	<= IsMemsb(instr);
	bus[`IB_SHFT48] <= IsShift48(instr);
	bus[`IB_SEI]		<= IsSEI(instr);
	bus[`IB_AQ]			<= (IsAMO(instr)|IsLWRX(instr)|IsSWCX(instr)) & instr[25];
	bus[`IB_RL]			<= (IsAMO(instr)|IsLWRX(instr)|IsSWCX(instr)) & instr[24];
	bus[`IB_JMP]		<= IsJmp(instr);
	bus[`IB_BR]			<= IsBranch(instr);
	bus[`IB_SYNC]		<= IsSync(instr)||IsBrk(instr)||IsRti(instr);
	bus[`IB_FSYNC]	<= IsFSync(instr);
	bus[`IB_RFW]		<= Rt==5'd0 ? 1'b0 : IsRFW(instr);
	bus[`IB_WE]			<= fnWe(instr);
	id_o <= id_i;
	idv_o <= idv_i;
end

endmodule

module mIsALU(instr, IsALU);
input [47:0] instr;
output reg IsALU;
parameter TRUE = 1'b1;
parameter FALSE = 1'b0;

always @*
casez(instr[`INSTRUCTION_OP])
`R2:    if (instr[`INSTRUCTION_L2]==2'b00)
			case(instr[`INSTRUCTION_S2])
			`VMOV:		IsALU = TRUE;
	        `RTI:       IsALU = FALSE;
	        default:    IsALU = TRUE;
	        endcase
	    else
	    	IsALU = TRUE;
`BRK:   IsALU = FALSE;
`Bcc:   IsALU = FALSE;
`BBc:   IsALU = FALSE;
`BEQI:  IsALU = FALSE;
`CHK:   IsALU = FALSE;
`JAL:   IsALU = FALSE;
`JMP:	IsALU = FALSE;
`CALL:  IsALU = FALSE;
`RET:   IsALU = FALSE;
`FVECTOR:
			case(instr[`INSTRUCTION_S2])
            `VSHL,`VSHR,`VASR:  IsALU = TRUE;
            default:    IsALU = FALSE;  // Integer
            endcase
`IVECTOR:
			case(instr[`INSTRUCTION_S2])
            `VSHL,`VSHR,`VASR:  IsALU = TRUE;
            default:    IsALU = TRUE;  // Integer
            endcase
`FLOAT:		IsALU = FALSE;            
default:    IsALU = TRUE;
endcase

endmodule