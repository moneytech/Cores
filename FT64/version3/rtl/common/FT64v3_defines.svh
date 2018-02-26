// ============================================================================
//        __
//   \\__/ o\    (C) 2017-2018  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	FT64_defines.v
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
//`define DEBUG_LOGIC 1'b1
`define HIGH        1'b1
`define LOW         1'b0
`define TRUE        1'b1
`define FALSE       1'b0
//`define Q2VECTORS   1'b1

`define ZERO		64'd0

`define SYS     8'h34
`define VECTOR  8'h01
`define VCMPRSS     5'h00
`define VCIDX       5'h01
`define VSCAN       5'h02
`define VABS        5'h03
`define VADD        5'h04
`define VSUB        5'h05
`define VSxx        5'h06
`define VSEQ            3'd0
`define VSNE            3'd1
`define VSLT            3'd2
`define VSGE            3'd3
`define VSLE            3'd4
`define VSGT            3'd5
`define VSUN            3'd7
`define VSxxS       5'h07
`define VAND        5'h08
`define VOR         5'h09
`define VXOR        5'h0A
`define VXCHG       5'h0B
`define VSHL        5'h0C
`define VSHR        5'h0D
`define VASR        5'h0E
`define VSxxSb		5'h0F
`define VSHLV       5'h10
`define VSHRV       5'h11
`define VROLV       5'h12
`define VRORV       5'h13
`define VADDS       5'h14
`define VSUBS       5'h15
`define VSxxSU      5'h17
`define VANDS       5'h18
`define VORS        5'h19
`define VXORS       5'h1A
`define VSxxSUb		5'h1F
`define VBITS2V     6'h20
`define V2BITS      6'h21
`define VEINS       6'h22
`define VEX         6'h23
`define VFLT2INT    6'h24
`define VINT2FLT    6'h25
`define VSIGN       6'h26
`define VSxxU       6'h27
`define VCNTPOP     6'h28
`define VMULS       6'h2A
`define VDIVS       6'h2E
`define VSxxUb		6'h2F
`define VMxx		6'h30
`define VMAND       	3'h0
`define VMOR        	3'h1
`define VMXOR       	3'h2
`define VMXNOR      	3'h3
`define VMPOP       	3'h4
`define VMFILL      	3'h5
`define VMFIRST     	3'h6
`define VMLAST      	3'h7
`define VMUL        6'h3A
`define VDIV        6'h3E
`define VSxxb       6'h3F
`define RR      8'h02
`define BCD         6'h00
`define BCDADD          5'h00
`define BCDSUB          5'h01
`define BCDMUL          5'h02
`define SHL     6'h10
`define SHR     6'h11
`define ASL     6'h12
`define ASR     6'h13
`define ROL     6'h14
`define ROR     6'h15
`define R1          6'h01
`define CNTLZ           5'h00
`define CNTLO           5'h01
`define CNTPOP          5'h02
`define ABS             5'h04
`define NOT             5'h05
`define REDOR           5'h06
`define MEMDB			5'h10
`define MEMSB			5'h11
`define SYNC        	5'h12
`define CHAIN_OFF		5'h14
`define CHAIN_ON		5'h15
`define BMM			6'h03
`define ADD	        6'h04
`define SUB         6'h05
`define CMP         6'h06
`define CMPU        6'h07
`define AND         6'h08
`define OR          6'h09
`define XOR         6'h0A
`define NAND        6'h0C
`define NOR         6'h0D
`define XNOR        6'h0E

`define CALLR       6'h18
`define CMPP		6'h19
`define CMPUP		6'h1A
`define MUX         6'h1B
`define LWRX        6'h1D
`define CACHEX      6'h1E
`define MOV			6'h22
`define CASX        6'h25
`define LVWS        6'h26
`define SVWS        6'h27
`define CMOVEQ      6'h28
`define CMOVNE      6'h29
`define MIN         6'h2C
`define MAX         6'h2D
`define MAJ         6'h2E
`define SEI         6'h30
`define WAIT        6'h31
`define RTI         6'h32
`define RTE         6'h32
`define VMOV        6'h33
`define MUL         6'h18
`define MULU        6'h19
`define MULSU       6'h1A
`define DIVMODU     6'h3C
`define DIVMODSU    6'h3D
`define DIVMOD      6'h3E
`define ADDI	7'h04
`define BITFIELD    7'h05
`define CMPI    7'h06
`define CMPUI   7'h07
`define ANDI    7'h08
`define ORI     7'h09
`define XORI    7'h0A
`define EXEC    7'h0C
`define QOPI    8'h0B
`define QORI        3'd0
`define QADDI       3'd1
`define QANDI       3'd2
`define QXORI       3'd3
`define DIVI    7'h1C
`define DIVUI   7'h1D
`define DIVSUI  7'h1E
`define FSYNC       6'h36
`define CSRRW   7'h0E
`define FLOAT   7'h0F
`define MULI    7'h18
`define MULUI   7'h19
`define MULSUI  7'h1A
`define SEQI	7'h20
`define SNEI    7'h21
`define SLTI    7'h22
`define SGEI    7'h23
`define SLEI    7'h24
`define SGTI    7'h25
`define SLTUI   7'h26
`define SGEUI   7'h27
`define SLEUI   7'h28
`define SGTUI   7'h29
`define SEQ		7'h20
`define SNE     7'h21
`define SLT     7'h22
`define SGE     7'h23
`define SLE     7'h24
`define SGT     7'h25
`define SLTU    7'h26
`define SGEU    7'h27
`define SLEU    7'h28
`define SGTU    7'h29
`define CACHE   7'h2A
`define MODI    7'h2C
`define MODUI   7'h2D
`define MODSUI  7'h2E
`define NOP     6'h1C
`define CALL    7'h31
`define JAL	    7'h33
`define REX     7'h35
`define CACHEX  6'h2A
`define BFINSI			4'h4
`define CAS     6'h25
`define JMP     7'h30
`define RET     7'h32
`define Bcc    	7'h38
`define BEQ         3'd0
`define BNE         3'd1
`define BLT         3'd2
`define BGE         3'd3
`define BLTU        3'd4
`define BGEU        3'd5
`define BccR    7'h39
`define BBc     7'h3C
`define IBNE		3'd6
`define DBNZ		3'd7
`define BEQI    7'h3D
`define FBcc	7'h3E
`define FBEQ        3'd0
`define FBNE        3'd1
`define FBLT        3'd2
`define FBGE        3'd3
`define FBUN        3'd7
`define FBccR	7'h3F
`define LB      7'h40
`define LBU     7'h41
`define LBO     7'h42
`define LC      7'h43
`define LCU     7'h44
`define LCO     7'h45
`define LH      7'h46
`define LHU     7'h47
`define LW      7'h49
`define CHK     6'h34
`define LHO		7'h48
`define LV      7'h4E
`define LVB		7'h50
`define LVBU	7'h51
`define LVBO	7'h52
`define LVC		7'h53
`define LVCU	7'h54
`define LVCO	7'h55
`define LVH		7'h56
`define LVHU	7'h57
`define LVHO	7'h58
`define LVW		7'h59
`define LVWR    7'h5D
`define IndexedLoad	7'h4D
`define LBX         5'h00
`define LBUX        5'h01
`define LBOX		5'h02
`define LCX         5'h03
`define LCUX        5'h04
`define LCOX       	5'h05
`define LHX         5'h06
`define LHUX        5'h07
`define LHOX		5'h08
`define LWX         5'h09
`define LVX         5'h0E
`define LVBX		5'h10
`define LVBUX		5'h11
`define LVBOX		5'h12
`define LVCX		5'h13
`define LVCUX		5'h14
`define LVCOX		5'h15
`define LVHX		5'h16
`define LVHUX		5'h17
`define LVHOX		5'h18
`define LVWX		5'h19
`define LVWRX		5'h1D
`define LVVX		5'h1E
`define SB      7'h60
`define SC      7'h61
`define SH      7'h62
`define SW	    7'h63
`define SWC     7'h65
`define SV      7'h66
`define Indexed		7'h67
`define SBX         5'h00
`define SCX         5'h01
`define SHX         5'h02
`define SWX         5'h03
`define SWCX        5'h05
`define SVX         5'h06
`define AMO_SWAPX	5'h10
`define AMO_ADDX	5'h11
`define AMO_ANDX	5'h12
`define AMO_ORX		5'h13
`define AMO_XORX	5'h14
`define AMO_MINX	5'h15
`define AMO_MAXX	5'h16
`define AMO_MINUX	5'h17
`define AMO_MAXUX	5'h18
`define AMO_SHLX	5'h19
`define AMO_SHRX	5'h1A
`define INCX		5'h1B

`define AMO_SWAP	7'h70
`define AMO_ADD		7'h71
`define AMO_AND		7'h72
`define AMO_OR		7'h73
`define AMO_XOR		7'h74
`define AMO_MIN		7'h75
`define AMO_MAX		7'h76
`define AMO_MINU	7'h77
`define AMO_MAXU	7'h78
`define AMO_SHL		7'h79
`define AMO_SHR		7'h7A
`define INC			7'h7B

`define FMOV    5'h10
`define FTOI    5'h12
`define ITOF    5'h13
`define FNEG    5'h14
`define FABS    5'h15
`define FSIGN   5'h16
`define FMAN    5'h17
`define FNABS   5'h18
`define FCVTSD  5'h19
`define FCVTSQ  5'h1B
`define FSTAT   5'h1C
`define FTX     6'h20
`define FCX     6'h21
`define FEX     6'h22
`define FDX     6'h23
`define FRM     6'h24
`define FCVTDS  6'h29

`define FADD    5'h04
`define FSUB    5'h05
`define FCMP    5'h06
`define FMUL    5'h08
`define FDIV    5'h09


`define NOP_INSN    {26'd0,`NOP}

`define CSR_CR0     11'h000
`define CSR_HARTID  11'h001
`define CSR_TICK    11'h002
`define CSR_PCR     11'h003
`define CSR_CAUSE   11'h006
`define CSR_BADADR  11'h007
`define CSR_PCR2    11'h008
`define CSR_SCRATCH 11'h009
`define CSR_SEMA    11'h00C
`define CSR_SBL     11'h00E
`define CSR_SBU     11'h00F
`define CSR_TCB		11'h010
`define CSR_FSTAT   11'h014
`define CSR_DBAD0   11'h018
`define CSR_DBAD1   11'h019
`define CSR_DBAD2   11'h01A
`define CSR_DBAD3   11'h01B
`define CSR_DBCTRL  11'h01C
`define CSR_DBSTAT  11'h01D
`define CSR_CAS     11'h02C
`define CSR_TVEC    11'b00000110???
`define CSR_IM_STACK	11'h040
`define CSR_OL_STACK	11'h041
`define CSR_PL_STACK	11'h042
`define CSR_RS_STACK	11'h043
`define CSR_STATUS 	11'h044
`define CSR_EPC0    11'h048
`define CSR_EPC1    11'h049
`define CSR_EPC2    11'h04A
`define CSR_EPC3    11'h04B
`define CSR_EPC4    11'h04C
`define CSR_EPC5    11'h04D
`define CSR_EPC6    11'h04E
`define CSR_EPC7    11'h04F
`define CSR_CODEBUF 11'b00010??????
`define CSR_TIME	11'h7E0
`define CSR_INFO    11'b111_1111_????

`define OL_USER         2'd3
`define OL_SUPERVISOR   2'd2
`define OL_HYPERVISOR   2'd1
`define OL_MACHINE      2'd0

// JALR and EXTENDED are synonyms
`define EXTEND	3'd7

// system-call subclasses:
`define SYS_NONE	3'd0
`define SYS_CALL	3'd1
`define SYS_MFSR	3'd2
`define SYS_MTSR	3'd3
`define SYS_RFU1	3'd4
`define SYS_RFU2	3'd5
`define SYS_RFU3	3'd6
`define SYS_EXC		3'd7	// doesn't need to be last, but what the heck

// exception types:
`define EXC_NONE	9'd000
`define EXC_HALT	9'd1
`define EXC_TLBMISS	9'd2
`define EXC_SIGSEGV	9'd3
`define EXC_INVALID	9'd4

`define FLT_NONE    7'd00
`define FLT_SSM     7'd32
`define FLT_DBG     7'd33
`define FLT_TGT     7'd34
`define FLT_IADR    7'd36
`define FLT_FLT     7'd38
`define FLT_CHK     7'd39
`define FLT_DBZ     7'd40
`define FLT_OFL     7'd41
`define FLT_EXF     7'd49
`define FLT_DWF     7'd50
`define FLT_DRF     7'd51
`define FLT_PRIV    7'd53
`define FLT_STK     7'd56
`define FLT_DBE     7'd60
`define FLT_IBE     7'd61

//`define INSTRUCTION_OP	15:13	// opcode
//`define INSTRUCTION_RA	12:10	// rA 
//`define INSTRUCTION_RB	9:7	// rB 
//`define INSTRUCTION_RC	2:0	// rC 
//`define INSTRUCTION_IM	6:0	// immediate (7-bit)
//`define INSTRUCTION_LI	9:0	// large unsigned immediate (10-bit, 0-extended)
//`define INSTRUCTION_SB	6	// immediate's sign bit
//`define INSTRUCTION_S1  6:4	// contains the syscall sub-class (NONE, CALL, MFSR, MTSR, EXC, etc.)
//`define INSTRUCTION_S2  3:0	// contains the sub-class identifier value

`define INSTRUCTION_OP  7:0
`define INSTRUCTION_RA  13:8
`define INSTRUCTION_VA	12:8
`define INSTRUCTION_RB  19:14
`define INSTRUCTION_VB  18:14
`define INSTRUCTION_RC  25:20
`define INSTRUCTION_VC  24:20
`define INSTRUCTION_RD  31:26
`define INSTRUCTION_IM  35:20
`define INSTRUCTION_SB  35
`define INSTRUCTION_S1  25:20
`define INSTRUCTION_S2  35:30
`define INSTRUCTION_COND    22:20

`define FORW_BRANCH	1'b0
`define BACK_BRANCH	1'b1

`define DRAMSLOT_AVAIL	3'b000
`define DRAMSLOT_BUSY	3'b001
`define DRAMSLOT_REQBUS	3'b101
`define DRAMSLOT_HASBUS	3'b110
`define DRAMREQ_READY	3'b111

`define INV	1'b0
`define VAL	1'b1

//
// define PANIC types
//
`define PANIC_NONE		4'd0
`define PANIC_FETCHBUFBEQ	4'd1
`define PANIC_INVALIDISLOT	4'd2
`define PANIC_MEMORYRACE	4'd3
`define PANIC_IDENTICALDRAMS	4'd4
`define PANIC_OVERRUN		4'd5
`define PANIC_HALTINSTRUCTION	4'd6
`define PANIC_INVALIDMEMOP	4'd7
`define PANIC_INVALIDFBSTATE	4'd9
`define PANIC_INVALIDIQSTATE	4'd10
`define PANIC_BRANCHBACK	4'd11
`define PANIC_BADTARGETID	4'd12

 
