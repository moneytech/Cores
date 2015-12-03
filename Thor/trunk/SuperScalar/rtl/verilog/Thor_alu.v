// ============================================================================
//        __
//   \\__/ o\    (C) 2013  Robert Finch, Stratford
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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
// Thor SuperScalar
// ALU
//
// ============================================================================
//
`include "Thor_defines.v"

module Thor_alu(alu_op, alu_fn, alu_argA, alu_argB, alu_argC, alu_argI, alu_pc, insnsz, o);
parameter DBW=64;
input [7:0] alu_op;
input [5:0] alu_fn;
input [DBW-1:0] alu_argA;
input [DBW-1:0] alu_argB;
input [DBW-1:0] alu_argC;
input [DBW-1:0] alu_argI;
input [DBW-1:0] alu_pc;
input [3:0] insnsz;
output reg [DBW-1:0] o;

wire signed [DBW-1:0] alu_argAs = alu_argA;
wire signed [DBW-1:0] alu_argBs = alu_argB;
wire signed [DBW-1:0] alu_argIs = alu_argI;
wire [DBW-1:0] andi_res = alu_argA & alu_argI;

integer n;

wire [7:0] bcdao,bcdso;
wire [15:0] bcdmo;
wire [DBW-1:0] bf_out;
wire [DBW-1:0] shfto;

Thor_shifter #(DBW) ushft0
(
	.func(alu_fn),
	.a(alu_argA),
	.b(alu_argB),
	.o(shfto)
);

BCDAdd ubcda
(
	.ci(1'b0),
	.a(alu_argA[7:0]),
	.b(alu_argB[7:0]),
	.o(bcdao),
	.c()
);

BCDSub ubcds
(
	.ci(1'b0),
	.a(alu_argA[7:0]),
	.b(alu_argB[7:0]),
	.o(bcdso),
	.c()
);

BCDMul2 ubcdm
(
	.a(alu_argA),
	.b(alu_argB),
	.o(bcdmo)
);

Thor_bitfield #(DBW) ubf1
(
	.op(alu_fn),
	.a(alu_argA),
	.b(alu_argB),
	.m(alu_argI[11:0]),
	.o(bf_out),
	.masko()
);


always @(alu_argI or alu_argA or alu_argB or alu_argC or alu_op or alu_fn or insnsz)
begin
casex(alu_op)
`LDI,`LDIS:			o <= alu_argI;
`RR:
	case(alu_fn)
	`ADD,`ADDU:		o <= alu_argA + alu_argB;
	`SUB,`SUBU:		o <= alu_argA - alu_argB;
	`_2ADDU:		o <= {alu_argA[DBW-2:0],1'b0} + alu_argB;
	`_4ADDU:		o <= {alu_argA[DBW-3:0],2'b0} + alu_argB;
	`_8ADDU:		o <= {alu_argA[DBW-4:0],3'b0} + alu_argB;
	`_16ADDU:		o <= {alu_argA[DBW-5:0],4'b0} + alu_argB;
	`MIN:           o <= alu_argA < alu_argB ? alu_argA : alu_argB;
	`MAX:           o <= alu_argA < alu_argB ? alu_argB : alu_argA;
	default:   o <= 64'd0;
	endcase
`_2ADDUI:		o <= {alu_argA[DBW-2:0],1'b0} + alu_argI;
`_4ADDUI:		o <= {alu_argA[DBW-3:0],2'b0} + alu_argI;
`_8ADDUI:		o <= {alu_argA[DBW-4:0],3'b0} + alu_argI;
`_16ADDUI:		o <= {alu_argA[DBW-5:0],4'b0} + alu_argI;
`R:
    case(alu_fn[3:0])
    `MOV:       o <= alu_argA;
    `NEG:		o <= -alu_argA;
    `NOT:       o <= ~alu_argA;
    `ABS:       o <= alu_argA[DBW] ? -alu_argA : alu_argA;
    `SGN:       o <= alu_argA[DBW] ? 64'hFFFFFFFFFFFFFFFF : alu_argA==64'd0 ? 64'd0 : 64'd1;
    default:    o <= 64'hDEADDEADDEADDEAD;
    endcase
`STS:		o <= alu_argA;
`DOUBLE:
	case (alu_fn)
	`FMOV:      o <= alu_argA;
	`FNEG:		o <= {~alu_argA[DBW-1],alu_argA[DBW-2:0]};
	`FABS:		o <= {1'b0,alu_argA[DBW-2:0]};
	`FSIGN:			if (DBW==64)
						o <= alu_argA[DBW-2:0]==0 ? {DBW{1'b0}} : {alu_argA[DBW-1],1'b0,{10{1'b1}},{52{1'b0}}};
					else
						o <= alu_argA[DBW-2:0]==0 ? {DBW{1'b0}} : {alu_argA[DBW-1],1'b0,{7{1'b1}},{23{1'b0}}};
	default:	o <= 64'd0;
	endcase
`ADDI,`ADDUI,`ADDUIS:
                o <= alu_argA + alu_argI;
`SUBI,`SUBUI,`PUSH:
            	o <= alu_argA - alu_argI;
`ANDI:			o <= alu_argA & alu_argI;
`ORI:			o <= alu_argA | alu_argI;
`EORI:			o <= alu_argA ^ alu_argI;
`LOGIC,`MLO:
	case(alu_fn)
	`AND:			o <= alu_argA & alu_argB;
	`ANDC:			o <= alu_argA & ~alu_argB;
	`OR:			o <= alu_argA | alu_argB;
	`ORC:			o <= alu_argA | ~alu_argB;
	`EOR:			o <= alu_argA ^ alu_argB;
	`NAND:			o <= ~(alu_argA & alu_argB);
	`NOR:			o <= ~(alu_argA | alu_argB);
	`ENOR:			o <= ~(alu_argA ^ alu_argB);
	default:       o <= 64'd0;
	endcase
`BITI:
    begin
        o[0] <= andi_res==64'd0;
        o[1] <= andi_res[DBW-1];
    	o[2] <= andi_res[0];
        o[3] <= 1'b0;
        o[DBW-1:4] <= 60'd0;
    end
`TST:	
	case(alu_fn)
	6'd0:	// TST - integer
		begin
			o[0] <= alu_argA == 64'd0;
			o[1] <= alu_argA[DBW-1];
			o[2] <= 1'b0;
			o[3] <= 1'b0;
			o[DBW-1:4] <= 60'd0;
		end
	6'd1:	// FSTST - float single
		begin
			o[0] <= alu_argA[30:0]==31'd0;	// + or - zero
			o[1] <= alu_argA[31];			// signed less than
			o[2] <= alu_argA[31];
			// unordered
			o[3] <= alu_argA[30:23]==8'hFF && alu_argA[22:0]!=23'd0;	// NaN
			o[DBW-1:4] <= 60'd0;
		end
	6'd2:	// FTST - float double
		begin
			o[0] <= alu_argA[DBW-2:0]==63'd0;	// + or - zero
			o[1] <= alu_argA[DBW-1];			// signed less than
			o[2] <= alu_argA[DBW-1];
			// unordered
			if (DBW==64)
				o[3] <= alu_argA[62:52]==11'h7FF && alu_argA[51:0]!=52'd0;	// NaN
			else
				o[3] <= 1'b0;
			o[DBW-1:4] <= 60'd0;
		end
	default:	o <= 64'd0;
	endcase
`CMP:	begin
			o[0] <= alu_argA == alu_argB;
			o[1] <= alu_argAs < alu_argBs;
			o[2] <= alu_argA < alu_argB;
			o[3] <= 1'b0;
			o[DBW-1:4] <= 64'd0;
		end
`CMPI:	begin
			o[0] <= alu_argA == alu_argI;
			o[1] <= alu_argAs < alu_argIs;
			o[2] <= alu_argA < alu_argI;
			o[3] <= 1'b0;
			o[DBW-1:4] <= 64'd0;
		end
`LB,`LBU,`LC,`LCU,`LH,`LHU,`LW,`SB,`SC,`SH,`SW,`CAS,`LVB,`LVC,`LVH,`LVH,`STI,
`LWS,`SWS,`LEA,`RTS2:
				o <= alu_argA + alu_argI;
`LBX,`LBUX,`SBX,
`LCX,`LCUX,`SCX,
`LHX,`LHUX,`SHX,
`LWX,`SWX:	o <= alu_argA + alu_argB;
`JSR,`JSRS,`JSRZ,`SYS:	o <= alu_pc + insnsz;
`INT:		o <= alu_pc;
`MFSPR,`MTSPR:	begin
                o <= alu_argA;
                end
`MUX:	begin
			for (n = 0; n < DBW; n = n + 1)
				o[n] <= alu_argA[n] ? alu_argB[n] : alu_argC[n];
		end
`BCD:
		case(alu_fn)
		`BCDADD:	o <= bcdao;
		`BCDSUB:	o <= bcdso;
		`BCDMUL:	o <= bcdmo;
		default:	o <= 64'd0;
		endcase
`SHIFT:	o <= shfto;
`BITFIELD:	o <= bf_out;
`LOOP:      o <= alu_argB - 64'd1;
default:	o <= 64'hDEADDEADDEADDEAD;
endcase
end
endmodule
