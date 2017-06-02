; ============================================================================
; FTBios816.asm
;        __
;   \\__/ o\    (C) 2014-2017  Robert Finch, Waterloo
;    \  __ /    All rights reserved.
;     \/_//     robfinch<remove>@finitron.ca
;       ||
;  
;
; This source file is free software: you can redistribute it and/or modify 
; it under the terms of the GNU Lesser General Public License as published 
; by the Free Software Foundation, either version 3 of the License, or     
; (at your option) any later version.                                      
;                                                                          
; This source file is distributed in the hope that it will be useful,      
; but WITHOUT ANY WARRANTY; without even the implied warranty of           
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            
; GNU General Public License for more details.                             
;                                                                          
; You should have received a copy of the GNU General Public License        
; along with this program.  If not, see <http://www.gnu.org/licenses/>.    
;                                                                          
; ============================================================================
;
CR			EQU		13
LF			EQU		10
ESC			EQU		$1B
BS			EQU		8
CTRLC		EQU		3

SC_LSHIFT	EQU		$12
SC_RSHIFT	EQU		$59
SC_KEYUP	EQU		$F0
SC_EXTEND	EQU		$E0
SC_CTRL		EQU		$14
SC_ALT		EQU		$11
SC_DEL		EQU		$71		; extend
SC_LCTRL	EQU		$58
SC_NUMLOCK	EQU		$77
SC_SCROLLLOCK	EQU	$7E
SC_CAPSLOCK	EQU		$58

TEXTROWS	EQU		31
TEXTCOLS	EQU		84

TickCount	EQU		$4
KeyState1	EQU		$8
KeyState2	EQU		$9
KeybdLEDs	EQU		$A
KeybdWaitFlag	EQU	$B
NumWorkArea	EQU		$C

; Range $10 to $1F reserved for hardware counters
CNT0L		EQU		$10
CNT0M		EQU		$11
CNT0H		EQU		$12
RangeStart	EQU		$20
RangeEnd	EQU		$24
CursorX		EQU		$30
CursorY		EQU		$32
VideoPos	EQU		$34
NormAttr	EQU		$36
StringPos	EQU		$38
EscState	EQU		$3C
Vidptr		EQU		$40
Vidregs		EQU		$46
Textcols	EQU		$4C
Textrows	EQU		$4E

reg_cs		EQU		$80
reg_ds		EQU		reg_cs + 4
reg_ss		EQU		reg_ds + 4
reg_pc		EQU		reg_ss + 4
reg_a		EQU		reg_pc + 4
reg_x		EQU		reg_a + 4
reg_y		EQU		reg_x + 4
reg_sp		EQU		reg_y + 4
reg_sr		EQU		reg_sp + 4
reg_db		EQU		reg_sr + 4
reg_dp		EQU		reg_db + 4
reg_bl		EQU		reg_dp + 4
reg_mp		EQU		reg_bl + 4

cs_save		EQU		$80
ds_save		EQU		$84
pc_save		EQU		$88
pb_save		EQU		$8C
acc_save	EQU		$90
x_save		EQU		$94
y_save		EQU		$98
sp_save		EQU		$9C
sr_save		EQU		$A0
srx_save	EQU		$A4
db_save		EQU		$A8
dpr_save	EQU		$AC

;running_task	EQU		$B8

keybd_char	EQU		$BA
rw_flag		EQU		$BA
keybd_cmd	EQU		$BC
WorkTR		EQU		$BE
ExitCode	EQU		$C0
secnum		EQU		$C4
bufptr		EQU		$C8
qcnt		EQU		$CC
IOFocusTask	EQU		$CE
TaskSwitchEn	EQU	$D0
TimeoutList	EQU		$D2
ldtrec		EQU		$100
timeout1	EQU		$104

RTCBuf		EQU		$300
OutputVec	EQU		$03F0

PCS0		EQU		$B000
PCS1		EQU		PCS0 + 2
PCS2		EQU		PCS1 + 2
PCS3		EQU		PCS2 + 2
PCS4	    EQU		PCS3 + 2
PCS5		EQU		PCS4 + 2
CTR0_LMT	EQU		PCS0 + 16
CTR0_CTRL	EQU		CTR0_LMT + 3
CTR1_LMT	EQU		CTR0_CTRL + 1
CTR1_CTRL	EQU		CTR1_LMT + 3
MPU_IRQ_STATUS	EQU		$B01F

VIDBUF		EQU		$D0000		; FD0000
VIDREGS		EQU		$EA000
PRNG		EQU		$EA100
KEYBD		EQU		$EA110
FAC1		EQU		$EA200

SPIMASTER	EQU		$00FEC000
SPI_MASTER_VERSION_REG	EQU	SPIMASTER+$00
SPI_MASTER_CONTROL_REG	EQU	SPIMASTER+$01
SPI_TRANS_TYPE_REG	EQU		SPIMASTER+$02
SPI_TRANS_CTRL_REG	EQU		SPIMASTER+$03
SPI_TRANS_STATUS_REG	EQU	SPIMASTER+$04
SPI_TRANS_ERROR_REG		EQU	SPIMASTER+$05
SPI_DIRECT_ACCESS_DATA_REG		EQU	SPIMASTER+$06
SPI_SD_SECT_7_0_REG		EQU	SPIMASTER+$07
SPI_SD_SECT_15_8_REG	EQU	SPIMASTER+$08
SPI_SD_SECT_23_16_REG	EQU	SPIMASTER+$09
SPI_SD_SECT_31_24_REG	EQU	SPIMASTER+$0A
SPI_RX_FIFO_DATA_REG	EQU	SPIMASTER+$10
SPI_RX_FIFO_DATA_COUNT_MSB	EQU	SPIMASTER+$11
SPI_RX_FIFO_DATA_COUNT_LSB  EQU SPIMASTER+$12
SPI_RX_FIFO_CTRL_REG		EQU	SPIMASTER+$14
SPI_TX_FIFO_DATA_REG	EQU	SPIMASTER+$20
SPI_TX_FIFO_CTRL_REG	EQU	SPIMASTER+$24
SPI_RESP_BYTE1			EQU	SPIMASTER+$30
SPI_RESP_BYTE2			EQU	SPIMASTER+$31
SPI_RESP_BYTE3			EQU	SPIMASTER+$32
SPI_RESP_BYTE4			EQU	SPIMASTER+$33

SPI_INIT_SD			EQU		$01
SPI_TRANS_START		EQU		$01
SPI_TRANS_BUSY		EQU		$01
SPI_INIT_NO_ERROR	EQU		$00
SPI_READ_NO_ERROR	EQU		$00
SPI_WRITE_NO_ERROR	EQU		$00
SPI_RW_READ_SD_BLOCK	EQU		$02
SPI_RW_WRITE_SD_BLOCK	EQU		$03

I2C_MASTER		EQU		$00FEC100
I2C_PRESCALE_LO	EQU		I2C_MASTER+$00
I2C_PRESCALE_HI	EQU		I2C_MASTER+$01
I2C_CONTROL		EQU		I2C_MASTER+$02
I2C_TX			EQU		I2C_MASTER+$03
I2C_RX			EQU		I2C_MASTER+$03
I2C_CMD			EQU		I2C_MASTER+$04
I2C_STAT		EQU		I2C_MASTER+$04

READY_FIFO		EQU		$00FEC200
READY_FIFO_CNT	EQU		$00FEC210
TIMEOUT_LIST	EQU		$00FEC300

; Timeout list commands
TOL_NOP			EQU		0
TOL_DEC			EQU		1
TOL_INS			EQU		2
TOL_RMV			EQU		3

SID			EQU		$EB000		; FEB000
SID_FREQ0		EQU		$00
SID_PW0			EQU		$04
SID_CTRL0		EQU		$08
SID_ATTACK0		EQU		$0C
SID_DECAY0		EQU		$10
SID_SUSTAIN0	EQU		$14
SID_RELEASE0	EQU		$18
SID_WADR0		EQU		$1C
SID_VOLUME		EQU		$B0

do_invaders			EQU		$7868

NR_JCB			EQU		64
NR_TCB			EQU		512
NR_MBX			EQU		1024
NR_MSG			EQU		4096
TS_READY		EQU		1
TS_WAITMSG		EQU		2
MQS_NEWEST		EQU		0		; message queue strategy
MT_NONE			EQU		0
MT_FREE			EQU		1

TCB_SIZE		EQU		64
tcbs			EQU		$20000
TCB_Next		EQU		$00	; 2 byte handles
TCB_Prev		EQU		$02	; 2 byte handles
TCB_Timeout		EQU		$04	; 4 byte value
TCB_mbq_next	EQU		$08	; 2 byte handles
TCB_mbq_prev	EQU		$0A	; 2 byte handles
TCB_msg_d1		EQU		$0C	; 4 byte value
TCB_msg_d2		EQU		$10	; 4 byte value
TCB_msg_d3		EQU		$14	; 4 byte value
TCB_msg_tgtadr	EQU		$18	; 2 byte handle
TCB_msg_retadr	EQU		$1A	; 2 byte handle
TCB_msg_link	EQU		$1C	; 2 byte handle
TCB_msg_type	EQU		$1E	; 2 byte value
TCB_hMbx1		EQU		$20	; 2 byte handle
TCB_hMbx2		EQU		$22	; 2 byte handle
TCB_hMbx3		EQU		$24	; 2 byte handle
TCB_hMbx4		EQU		$26	; 2 byte handle
TCB_hWaitMbx	EQU		$28	; 2 byte handle
TCB_number		EQU		$2A	; 2 byte value
TCB_priority	EQU		$2C	; 1 byte value
TCB_status		EQU		$2D	; 1 byte value
TCB_affinity	EQU		$2E	; 1 byte value
TCB_hJob		EQU		$2F	; 1 byte handle
TCB_start_tick	EQU		$30	; 4 byte value
TCB_end_tick	EQU		$34	; 4 byte value
TCB_ticks		EQU		$38	; 4 byte value
TCB_exception	EQU		$3C	; 4 byte value

JCB_SIZE		EQU		1024
jcbs			EQU		tcbs + TCB_SIZE * NR_TCB
JCB_iof_next	EQU		$000	; 1 byte value
JCB_iof_prev	EQU		$001	; 1 byte value
JCB_user_name	EQU		$002	; 32 byte value
JCB_path		EQU		$022	; 256 byte value
JCB_exit_runfile	EQU	$122	; 256 byte value
JCB_command_line	EQU	$222	; 256 byte value
JCB_pVidMem		EQU		$322	; 6 byte value
JCB_pVirtVidMem	EQU		$328	; 6 byte value
JCB_VideoCols	EQU		$32E	; 1 byte value
JCB_VideoRows	EQU		$32F	; 1 byte value
JCB_CursorRow	EQU		$330	; 1 byte value
JCB_CursorCol	EQU		$331	; 1 byte value
JCB_NormAttr	EQU		$332	; 2 byte value
JCB_KeyState1	EQU		$334	; 2 byte value
JCB_KeyState2	EQU		$336	; 2 byte value
JCB_KeybdWaitFlag	EQU	$338	; 1 byte value
JCB_KeybdHead	EQU		$339
JCB_KeybdTail	EQU		$33A
JCB_KeybdBuffer	EQU		$33B	; 32 byte value
JCB_number		EQU		$35B	; 1 byte value
JCB_tasks		EQU		$35C	; 2 byte value * 8
JCB_next		EQU		$35E	; 1 byte value

; 1024 mailboxes
mailboxes		EQU		jcbs + JCB_SIZE * NR_JCB
MBX_SIZE		EQU		24
MBX_link		EQU		$00	; 1 byte value
MBX_owner		EQU		$01	; 1 byte value
MBX_tq_head		EQU		$02	; 2 byte value
MBX_tq_tail		EQU		$04	; 2 byte value
MBX_mq_head		EQU		$06	; 2 byte value
MBX_mq_tail		EQU		$08	; 2 byte value
MBX_tq_count	EQU		$0C	; 2 byte value
MBX_mq_count	EQU		$0E	; 2 byte value
MBX_mq_size		EQU		$10	; 2 byte value
MBX_mq_missed	EQU		$12	; 2 byte value
MBX_mq_strategy	EQU		$14	; 1 byte value

messages	EQU		mailboxes + MBX_SIZE * NR_MBX
MSG_d1		EQU		$00	; 4 byte value	( 4096 messages )
MSG_d2		EQU		$04	; 4 byte value
MSG_d3		EQU		$08	; 4 byte value
MSG_tgtadr	EQU		$0C	; 2 byte handle
MSG_retadr	EQU		$0E	; 2 byte handle
MSG_link	EQU		$10	; 2 byte handle
MSG_type	EQU		$12	; 2 byte value
MSG_SIZE	EQU		MSG_type + 2

running_task	EQU		messages + MSG_SIZE * NR_MSG
hTcbTmp		EQU		running_task + 2
hMbxTmp		EQU		hTcbTmp + 2
hMsgTmp		EQU		hMbxTmp + 2

.include "supermon832.asm"
.include "FAC1ToString.asm"
.include "invaders.asm"

;	cpu		W65C816S
	cpu		FT832
	.org	$C000

start:
	SEI					; not strictly necessary after power on reset
	CLD
;	CLV					; overflow low
;	SEC					; carry high
;	XCE					; sets 32 bit mode, 32 bit registers
;	REP		#$30		; 32 bit registers
;	MEM		32
;	NDX		32
;	LDA		#$3FFF
;	TAS
;
	CLC					; switch to '816 mode
	BIT		start		; set overflow bit
	XCE
	REP		#$30		; set 16 bit regs & mem
	NDX 	16
	MEM		16

	; Setup all the segment descriptors
	; This must be done before the stack can be accessed, and
	; before subroutine calls and task switching can be made.

	; First setup segment #0, the segment the core starts running under.
	; It's setup for flat addressing.
	LDA		#0
	XBAW
	LDA		#0
	LDX		#$98D		; present, writeable, executable, max size.
	TAY
	SDU
	INY

	; Flag remaining segments as not present 
	LDX		#$000		; not present, non-executable, non-writeable, min size
.0003:
	SDU					; update segment descriptor
	INY
	CPY		#4096
	BNE		.0003

	; setup code segment #1
	LDX		#$905		; executable, 64k
	TAY
	INY
	SDU
	; setup data segment #2
	LDX		#$88B		; writeable, 256M
	INY
	SDU
	; setup stack segment #3 (for 65c02 mode)
	LDX		#$882		; writeable, 1k (based at zero)
	INY
	SDU
	; setup stack segment #4 (for 65c816 mode)
	LDX		#$885		; writeable, 64k (based at zero)
	INY
	SDU
	; seg #5 is the maxed out segment
	LDX		#$98D		; executable, writable, max size
	INY
	SDU

	; I/O segment
	LDA		#$00F0
	XBAW
	LDA		#$0000
	LDX		#$887		; writeable, 1M (based at $F00000)
	LDY		#$FFF
	SDU

	; now set the code segment (test far jump)
	JMF		1:.0004
.0004:
	; set the stack segment
	; (must be before PEA/PLDS)
	LDA		#5
	TASS
	LDA		#$6BFF		; set top of stack
	TAS

	; setup the programmable address decodes
	LDA		#$0070		; program chip selects for I/O
	STA		PCS0		; at $007000
	LDA		#$0071
	STA		PCS1
;	LDA		#$FEA1		; select $FEA1xx I/O
;	STA		PCS3
;	LDA		#$0000		; select zero page ram
;	STA		PCS5

	; set the data segment
	; this must be setup after address decoding is setup
	PEA		5
	PLDS

	; Setup the counters
	SEP		#$30		; set 8 bit regs
	NDX		8			; tell the assembler
	MEM		8
	; Counter #0 is setup as a free running tick count
	LDA		#$FF		; set limit to $FFFFFF
	STA		CTR0_LMT
	STA		CTR0_LMT+1
	STA		CTR0_LMT+2
	LDA		#$14		; count up, on mpu clock
	STA		CTR0_CTRL
	; Counter #1 is set to interrupt at a 50Hz rate
	LDA		#$2A	;94		; divide by 95794 (for 50Hz)
	STA		CTR1_LMT		; FFFFFE = 2Hz with 33MHz clock
	LDA		#$2C	;57
	STA		CTR1_LMT+1
	LDA		#$0A	;09
	STA		CTR1_LMT+2
	LDA		#$05		; count down, on mpu clock, irq disenabled
	STA		CTR1_CTRL
	; Counter #2 isn't setup

	REP		#$30		; set 16 bit regs & mem
	NDX 	16
	MEM		16

	LDA		#$20
	STA		TCB_priority
	LDA		#0
	JSR		InsertIntoReadyFifo
	JSR		ResetKbd

	STZ		TaskSwitchEn
;	FORK	#8			; fork a BIOS context
;	TTA
;	CMP		#8
;	BNE		.0002
;	RTT
;.0002:
	; Setup the task registers
	LDY		#9			; # tasks to setup
	LDX		#1
.0001:
	LDT		TaskStartTbl,X
	INX
	DEY
	BNE		.0001

	STZ		running_task

	LDA		#BrkRout1
	STA		$0102

	STZ		TickCount
	STZ		TickCount+2
Task0:
	CLI
	NOP
	NOP
	NOP
	; Start the single stepping task.
	LDA		#$01
	STA		$7000
	TSK		#9
.0001:
	LDA		#$04
	STA		$7000
	LDA		#$FFF
	STA		Vidptr+4
	STA		Vidregs+4
	LDA		#VIDBUF>>16
	STA		Vidptr+2
	STZ		Vidptr
	LDA		#$BF0D	; 'm'
	STA		FAR {Vidptr}
	LDA		#VIDREGS >> 16
	STA		Vidregs+2
	LDA		#VIDREGS
	STA		Vidregs
	LDY		#7	
	LDA		#$21		; divide by 3 vertically, 2 horizontally
	JSR		SetVideoReg	; clear POR state
	LDA		#84		; set window left position 84
	LDY		#2
	JSR		SetVideoReg
	LDA		#0
	LDY		#3
	JSR		SetVideoReg
	LDA		#16			; set window top position
	LDY		#4
	JSR		SetVideoReg
	JSR		GetTextRowsCols
	LDA		#DisplayChar
	STA		OutputVec
	LDA		OutputVec
	CMP		#DisplayChar
	BNE		.0001
	LDA		#$02
	STA		$7000
	LDA		#$BF00
	STA		NormAttr
	JSR		ClearScreen
	JSR		HomeCursor
;	JSR		beep
	LDA		#$03
	STA		5:$7000
	PEA		5
	PEA		msgStarting
	JSR		DisplayString
	JSR		rtc_init
	JSR		rtc_read
	CMP		#0
	BEQ		.0006
	PEA		1
	PEA		msgRtcReadFail
	JSR		DisplayString
.0006:
;	SEP		#$1000		; turn on single step mode
;	LDA		#0
;	STA		$FFF:FAC1
;	STA		$FFF:FAC1+2
;	STA		$FFF:FAC1+4
;	STA		$FFF:FAC1+6
;	STA		$FFF:FAC1+8
;	STA		$FFF:FAC1+10
;	LDA		#3
;	STA		$7000
;	LDA		#1234
;	STA		FAC1
;	LDA		#5			; FIX2FLT
;	JSR 	FPCommandWait
;	LDA		#4
;	STA		$7000
;	JSR		DivideByTen
;	LDA		#5
;	STA		$7000
;	JSR		FAC1ToString
;	PEA		2
;	PEA		$3A0
;	JSR		DisplayString
;	LDA		#' '
;	JSR		OutChar
;	JSR		DispFAC1

;	FORK	#11
;	TTA
;	CMP		#11
;	LBEQ	KeybdInit

	; Create a workhorse BIOS context that will allow subroutine calls into
	; the BIOS code from alternate contexts which may not have the same VM
	; settings.
	;
	SEI
	FORK	#$FC
	TTA
	AND		#$01FF
	CMP		#$FC
	BNE		TaskMon
TaskFC:
	LDX		#$FC*2
	LDA		#$20
	STA		TCB_priority,X
	TXA
	LSR
	JSR		InsertIntoReadyFifo
.0003
	SEI
	PLA
	LDX		#$23FF
	TXS
	PHA
	CLI
	NOP		; allow CLI to take place
	NOP
	NOP
	NOP
	NOP
	RTT
	BRA		.0003
TaskMon:
	CLI

Mon1:
.mon1:
	LDA		#$6BFF
	TAS
	JSR		CursorOn
	JSR		OutCRLF
	LDA		#'$'
	STA		TaskSwitchEn
.mon3:
	JSR		OutChar
	JSR		KeybdGetCharWait
	AND		#$FF
;	CMP		#'.'
;	BEQ		.mon3
	CMP		#CR
	BNE		.mon3
	LDA		CursorY
	ASL
	TAX
	LDA		CS:LineTbl,X
	ASL
	TAX
.mon4:
	JSR		IgnoreBlanks
	JSR		MonGetch
	CMP		#'$'
	BEQ		.mon4
	CMP		#'S'
	BNE		.mon2
	JSR		MonGetch
	CMP		#'E'
	LBEQ	GetSecnum
	LDA		#$20
	STA		TCB_priority+8
	STZ		TCB_status		; monitor is no longer ready
	LDA		#8
	STA		IOFocusTask
	JSR		InsertIntoReadyFifo
	TSK		JMP:#8
	BRA		.mon1
	;JMP		$8000		; invoke Supermon832
.mon2:
	CMP		#'C'
	BNE		.mon5
	JSR		ClearScreen
	JSR		HomeCursor
	BRA		.mon1
.mon5:
	CMP		#'M'
	BNE		.mon6
	JSR		doMemoryDump
	BRA		Mon1
.mon6:
	CMP		#'D'
	LBEQ	doD
	CMP		#'>'
	LBEQ	doMemoryEdit
	CMP		#'F'
	LBEQ	doFill
	CMP		#'J'
	LBEQ	doJump
	CMP		#'T'
	LBEQ	doTask
	CMP		#'I'
	LBEQ	doInvaders
	CMP		#'R'
	BNE		.mon7
	JSR		MonGetch
	CMP		#'D'
	LBEQ	doRead
	DEX
	DEX
	BRL		doRegs
.mon7:
	CMP		#'B'
	LBEQ	doBasic
	CMP		#'W'
	LBEQ	doWrite
	BRL		Mon1

; Get a character from the screen, skipping over spaces and tabs
;
MonGetNonSpace:
.0001:
	JSR		MonGetch
	CMP		#' '
	BEQ		.0001
	RTS

; Get a character from the screen.
;
MonGetch:
	LDA		$FFF:VIDBUF,X
	INX
	INX
	AND		#$FF
	JSR		ScreenToAscii
	RTS

MonErr:
	PEA		1
	PEA		msgErr
	JSR		DisplayString
	BRL		Mon1

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
doD:
	JSR		MonGetch
	CMP		#'T'
	BEQ		doDate
	DEX
	DEX
	BRL		doDisassemble

;------------------------------------------------------------------------------
; DT? - displays the date from the RTC
; DT <year> <month> <day> - updates the RTC with the year, month and day.
;------------------------------------------------------------------------------

doDate:
	JSR		MonGetch
	CMP		#'?'
	BEQ		DispDate
	DEX
	DEX
	JSR		GetHexNumber
	CPY		#0
	BEQ		.0001
	LDA		NumWorkArea
	STA.B	RTCBuf+6
	JSR		GetHexNumber
	CPY		#0
	BEQ		.0001
	LDA		NumWorkArea
	STA.B	RTCBuf+5
	JSR		GetHexNumber
	CPY		#0
	BEQ		.0001
	LDA		NumWorkArea
	STA.B	RTCBuf+4
	JSR		rtc_write
.0001:
	BRL		Mon1

DispDate:
	JSR		rtc_read
	LDA.B	RTCBuf+6
	JSR		DispByte
	LDA		#'/'
	JSR		OutChar
	LDA.B	RTCBuf+5
	JSR		DispByte
	LDA		#'/'
	JSR		OutChar
	LDA.B	RTCBuf+4
	JSR		DispByte
	JSR		OutCRLF
	BRL		Mon1
		
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
doTask:
	JSR		MonGetch
	CMP		#'S'
	BNE		.0001
	JSR		GetHexNumber
	LDA		NumWorkArea
	ASL
	TAX		
	LDA		#$20
	STA		TCB_priority,X
	LDA		NumWorkArea
	JSR		InsertIntoReadyFifo
;	TSK
	BRL		Mon1
.0001:
	DEX
	DEX
	JSR		GetHexNumber
	LDA		NumWorkArea
	TSK
	BRK		Mon1

;------------------------------------------------------------------------------
; Start the BASIC interpreter.
;------------------------------------------------------------------------------

doBasic:
	LDA		#$0001
	XBAW
	LDA		#$0000
	LDX		#$985		; executable, writeable, 64k (based at $10000)
	LDY		#$FFD
	SDU
	LDA		#$20
	STA		TCB_priority+7
	STZ		TCB_status	; monitor is no longer ready
	LDA		#7
	STA		IOFocusTask
	JSR		InsertIntoReadyFifo
	TSK		#7
	BRL		Mon1
	
;------------------------------------------------------------------------------
; Get starting sector number for SD Card read/write routines
;------------------------------------------------------------------------------

GetSecnum:
	JSR		GetHexNumber
	LDA		NumWorkArea
	STA		secnum
	LDA		NumWorkArea+2
	STA		secnum+2
	BRL		Mon1

;------------------------------------------------------------------------------
; Read or write a block of memory to SD Card.
;------------------------------------------------------------------------------

doWrite:
	LDA		#$FFFF
	STA		rw_flag
	BRA		doReadWrite
doRead:
	STZ		rw_flag
doReadWrite:
	JSR		GetRange
	JSR		spi_master_init
	CMP		#0
	BEQ		.0004
	BRL		Mon1
.0004:
	JSR		OutCRLF
.0002:
	JSR		DispSecnum
	LDA		RangeStart+2
	PHA
	LDA		RangeStart
	PHA
	LDA		secnum+2
	PHA
	LDA		secnum
	PHA
	BIT		rw_flag
	BVC		.0005
	JSR		spi_master_write
	BRA		.0006
.0005:
	JSR		spi_master_read
.0006:
	INC		secnum
	BNE		.0001
	INC		secnum+2
.0001:
	CLC
	LDA		RangeStart
	ADC		#512
	STA		RangeStart
	LDA		RangeStart+2
	ADC		#0
	STA		RangeStart+2
	SEC
	LDA		RangeStart
	SBC		RangeEnd
	LDA		RangeStart+2
	SBC		RangeEnd+2
	BLT		.0002
	JSR		OutCRLF
	BRL		Mon1

DispSecnum:
	LDA		secnum+2
	JSR		DispWord
	LDA		secnum
	JSR		DispWord
	LDA		#$0D
	JMP		OutChar

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
doInvaders:
	LDA		#$FFFF
	STA		do_invaders
	TSK		#5
;	FORK	#5
;	TTA
;	CMP		#5
;	LBEQ	InvadersTask
	BRL		Mon1

;------------------------------------------------------------------------------
; Display Registers
; R<xx>		xx = context register to display
; Update Registers
; R.<reg> <val>
;	reg = CS PB PC A X Y SP SR DS DB DP or MP
;------------------------------------------------------------------------------

doRegs:
	JSR		MonGetch
	CMP		#'.'
	LBNE	.0004
	JSR		MonGetch
	CMP		#'C'
	BNE		.0005
	JSR		MonGetch
	CMP		#'S'
	LBNE	Mon1
	JSR		IgnoreBlanks
	JSR		GetHexNumber
	LDA		NumWorkArea
	STA		reg_cs
	LDA		NumWorkArea+2
	STA		reg_cs+2
.buildrec
	JSR		BuildRec
	LDX		WorkTR
	LDT		ldtrec
	BRL		Mon1
.0005:
	CMP		#'P'
	BNE		.0006
	JSR		MonGetch
	CMP		#'B'
	BNE		.0007
	JSR		IgnoreBlanks
	JSR		GetHexNumber
	LDA		NumWorkArea+2
	STA		reg_pc+2
	BRA		.buildrec
.0007:
	CMP		#'C'
	LBNE	Mon1
	JSR		IgnoreBlanks
	JSR		GetHexNumber
	LDA		NumWorkArea
	STA		reg_pc
	BRA		.buildrec
.0006:
	CMP		#'A'
	BNE		.0008
	JSR		IgnoreBlanks
	JSR		GetHexNumber
	LDA		NumWorkArea
	STA		reg_a
	LDA		NumWorkArea+2
	STA		reg_a+2
	BRA		.buildrec
.0008:
	CMP		#'X'
	BNE		.0009
	JSR		IgnoreBlanks
	JSR		GetHexNumber
	LDA		NumWorkArea
	STA		reg_x
	LDA		NumWorkArea+2
	STA		reg_x+2
	BRL		.buildrec
.0009:
	CMP		#'Y'
	BNE		.0010
	JSR		IgnoreBlanks
	JSR		GetHexNumber
	LDA		NumWorkArea
	STA		reg_y
	LDA		NumWorkArea+2
	STA		reg_y+2
	BRL		.buildrec
.0010:
	CMP		#'S'
	BNE		.0011
	JSR		MonGetch
	CMP		#'P'
	BNE		.0015
	JSR		IgnoreBlanks
	JSR		GetHexNumber
	LDA		NumWorkArea
	STA		reg_sp
	LDA		NumWorkArea+2
	STA		reg_sp+2
	BRL		.buildrec
.0015:
	CMP		#'R'
	LBNE	Mon1
	JSR		IgnoreBlanks
	JSR		GetHexNumber
	LDA		NumWorkArea
	STA		reg_sr
	BRL		.buildrec
.0011:
	CMP		#'D'
	LBNE	Mon14
	JSR		MonGetch
	CMP		#'S'
	BNE		.0012
	JSR		IgnoreBlanks
	JSR		GetHexNumber
	LDA		NumWorkArea
	STA		reg_ds
	LDA		NumWorkArea+2
	STA		reg_ds+2
	BRL		.buildrec
.0012:
	CMP		#'B'
	BNE		.0013
	JSR		IgnoreBlanks
	JSR		GetHexNumber
	LDA		NumWorkArea
	STA		reg_db
	BRL		.buildrec
.0013:
	CMP		#'P'
	LBNE	Mon1
	JSR		IgnoreBlanks
	JSR		GetHexNumber
	LDA		NumWorkArea
	STA		reg_dp
	BRL		.buildrec
.0014:
	CMP		#'M'
	LBNE	Mon1
	JSR		MonGetch
	CMP		#'P'
	LBNE	Mon1
	JSR		IgnoreBlanks
	JSR		GetHexNumber
	LDA		NumWorkArea
	STA		reg_mp
	BRL		.buildrec

.0004:
	DEX
	DEX
;	JSR		IgnoreBlanks
	JSR		GetHexNumber
	CPY		#0
	LBEQ	Mon1
	LDA		NumWorkArea
	STA		WorkTR
	BSR		DispRegs
	BRL		Mon1

DispRegs:
	PEA		1
	PEA		msgRegs
	JSR		DisplayString
	JSR		space

	LDA		WorkTR
	ASL
	ASL
	ASL
	ASL
	TAX

	LDY		#0
.0001:
	INF
	INX
	STA		reg_cs,Y
	XBAW
	STA		reg_cs+2,Y
	INY4
	CPY		#48
	BNE		.0001

	; Display CS
	LDA		reg_cs
	JSR		DispWord
	LDA		#':'
	JSR		OutChar

	; Display PB PC
	LDA		reg_pc+2
	JSR		DispByte
	LDA		reg_pc
	JSR		DispWord
	JSR		space

	; Display SRX,SR
	LDA		reg_cs+32
	LDX		#16
.0003:
	ASL
	PHA
	LDA		#'0'
	ADC		#0
	JSR		DispNybble
	PLA
	DEX
	BNE		.0003
	JSR		space

	LDX		#16
.0002
	; display Acc,.X,.Y,.SP
	LDA		reg_cs+2,X
	JSR		DispWord
	LDA		reg_cs,X
	JSR		DispWord
	JSR		space
	INX4
	CPX		#32
	BNE		.0002

	PEA		1
	PEA		msgRegs2
	JSR		DisplayString
	JSR		space

	; Display SS
	LDA		reg_ss
	JSR		DispWord
	JSR		space

	; Display DS
	LDA		reg_ds
	JSR		DispWord
	JSR		space

	; Display DB
	LDA		reg_db
	JSR		DispByte
	JSR		space

	; Display DPR
	LDA		reg_dp
	JSR		DispWord
	JSR		space

	; Display back link
	LDA		reg_bl
	JSR		DispWord

	; Display map number
	JSR		space
	LDA		reg_mp
	JSR		DispByte

	JSR		OutCRLF
	RTS

; Build a startup record from the register values so that a context reg
; may be loaded

BuildRec:
	LDA		reg_cs
	STA		ldtrec
	LDA		reg_ds
	STA		ldtrec+2
	LDA		reg_ss
	STA		ldtrec+4
	LDA		reg_pc
	STA		ldtrec+6
	LDA		reg_pc+2
	AND		#$FF
	SEP		#$30		; 8 bit regs
	MEM		8
	XBA
	LDA		reg_a
	XBA
	REP		#$30
	MEM		16
	STA		ldtrec+8
	LDA		reg_a+1
	STA		ldtrec+10
	LDA		reg_a+3
	STA		ldtrec+12
	LDA		reg_x+1
	STA		ldtrec+14
	LDA		reg_x+3
	STA		ldtrec+16
	LDA		reg_y+1
	STA		ldtrec+18
	LDA		reg_y+3
	STA		ldtrec+20
	LDA		reg_sp+1
	STA		ldtrec+22
	LDA		reg_sp+3
	STA		ldtrec+24
	SEP		#$30
	LDA		reg_sr+1
	STA		ldtrec+26
	LDA		reg_db
	STA		ldtrec+27
	LDA		reg_dp
	STA		ldtrec+28
	LDA		reg_dp+1
	STA		ldtrec+29
	LDA		reg_mp
	STA		ldtrec+30
	STZ		ldtrec+31
	REP		#$30
	RTS

;------------------------------------------------------------------------------
; Dump memory.
;------------------------------------------------------------------------------

doMemoryDump:
	JSR		IgnoreBlanks
	JSR		GetRange
	JSR		OutCRLF
.0007:
	LDA		#'>'
	JSR		OutChar
	JSR		DispRangeStart
	LDY		#0
.0001:
	LDA		{RangeStart},Y
	JSR		DispByte
	LDA		#' '
	JSR		OutChar
	INY
	CPY		#8
	BNE		.0001
	LDY 	#0
.0005:
	LDA		{RangeStart},Y
	AND		#$FF
	CMP		#' '
	BCS		.0002
.0004:
	LDA		#'.'
	BRA		.0003
.0002:
	CMP		#$7f
	BCS		.0004
.0003:
	JSR		OutChar
	INY
	CPY		#8
	BNE		.0005
	JSR		OutCRLF
	CLC
	LDA		RangeStart
	ADC		#8
	STA		RangeStart
	BCC		.0006
	INC		RangeStart+2
.0006:
	SEC
	LDA		RangeEnd
	SBC		RangeStart
	LDA		RangeEnd+2
	SBC		RangeStart+2
	PHP
	JSR		KeybdGetCharNoWait;Ctx,7
	AND		#$FF
	CMP		#CTRLC
	BEQ		.0009
	PLP
	BPL		.0007
.0008:
	RTS
.0009:
	PLP
	RTS

;------------------------------------------------------------------------------
; Edit memory.
; ><memory address> <val1> <val2> ... <val8>
;------------------------------------------------------------------------------

doMemoryEdit:
	JSR		IgnoreBlanks
	JSR		GetHexNumber
	CPY		#0
	LBEQ	Mon1
	LDA		NumWorkArea
	STA		RangeStart
	LDA		NumWorkArea+2
	STA		RangeStart+2
	LDY		#0
.0001:
	PHY
	JSR		IgnoreBlanks
	JSR		GetHexNumber
	CPY		#0
	BEQ		.0002
	PLY
	SEP		#$20
	LDA		NumWorkArea
	STA		{RangeStart},Y
	REP		#$20
	INY
	CPY		#8
	BNE		.0001
	BRL		Mon1
.0002:
	PLY
	BRL		Mon1

;------------------------------------------------------------------------------
; Fill memory.
; $F <start address> <end address> <val1>
;------------------------------------------------------------------------------

doFill:
	JSR		IgnoreBlanks
	JSR		GetHexNumber
	CPY		#0
	LBEQ	MonErr
	LDA		NumWorkArea
	STA		RangeStart
	LDA		NumWorkArea+2
	STA		RangeStart+2
	JSR		IgnoreBlanks
	JSR		GetHexNumber
	CPY		#0
	LBEQ	MonErr
	LDA		NumWorkArea
	STA		RangeEnd
	LDA		NumWorkArea+2
	STA		RangeEnd+2
	JSR		IgnoreBlanks
	JSR		GetHexNumber
	CPY		#0
	LBEQ	MonErr
	LDX		NumWorkArea
	; Process in 32 bit mode
	SEP		#$200
	REP		#$100
	LDA		RangeEnd
	SEC
	SBC		RangeStart
	LDY		RangeStart
	FIL		$00
	; Back to 16 bits mode
	REP		#$200
	SEP		#$100
	BRL		Mon1

;------------------------------------------------------------------------------
; Disassemble code
;------------------------------------------------------------------------------

doDisassemble:
	JSR		MonGetch
	CMP		#'M'
	BEQ		.0002
.0004:
	CMP		#'N'
	BNE		.0003
	SEP		#$20
	MEM		8
	LDA		$BC
	ORA		#$40
	STA		$BC
	REP		#$20
	BRA		.0005
.0002:
	SEP		#$20
	LDA		$BC
	ORA		#$80
	STA		$BC
	REP		#$20
	JSR		MonGetch
	BRA		.0004
	MEM		16
.0003:
	DEX
	DEX
.0005:
	JSR		IgnoreBlanks
	JSR		GetRange
	LDA		RangeStart
	STA		$8F				; addra
	LDA		RangeStart+1
	STA		$90
	JSR		OutCRLF
	LDY		#20
.0001:
	PHY
	SEP		#$30
	JSR		dpycod
	REP		#$30
	JSR		OutCRLF
	PLY
	DEY
	BNE		.0001
	JMP		Mon1

;$BC flimflag

;------------------------------------------------------------------------------
; Jump to subroutine
;
; Either JSR for 16 bit address or JSL for 24 bit address
;------------------------------------------------------------------------------

doJump:
	JSR		MonGetch
	CMP		#'S'
	LBNE	Mon1
	JSR		MonGetch
	CMP		#'R'
	BNE		.testL
	JSR		IgnoreBlanks
	JSR		GetHexNumber
	CPY		#0
	LBEQ	Mon1
	LDA		NumWorkArea
	STA		RangeEnd
	LDX		#0
	JSR		(RangeEnd,X)
	BRL		Mon1
.testL:
	CMP		#'L'
	LBNE	Mon1
	JSR		IgnoreBlanks
	JSR		GetHexNumber
	CPY		#0
	LBEQ	Mon1
	LDA		#$5C			; JML opcode
	STA		RangeEnd-1
	LDA		NumWorkArea
	STA		RangeEnd
	LDA		NumWorkArea+1
	STA		RangeEnd+1
	LDA		#RangeEnd
	CACHE	#1				; 1= invalidate instruction line identified by accumulator
	JSL		RangeEnd
	BRL		Mon1

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
DispRangeStart:
	LDA		RangeStart+1
	JSR		DispWord
	LDA		RangeStart
	JSR		DispByte
	LDA		#' '
	JMP		OutChar
	
;------------------------------------------------------------------------------
; Skip over blanks in the input
;------------------------------------------------------------------------------

IgnoreBlanks:
.0001:
	JSR		MonGetch
	CMP		#' '
	BEQ		.0001
	DEX
	DEX
	RTS

;------------------------------------------------------------------------------
; BIOSInput allows full screen editing of text until a carriage return is keyed
; at which point the line the cursor is on is copied to a buffer. The buffer
; must be at least TEXTCOLS characters in size.
;------------------------------------------------------------------------------
;
BIOSInput:
.bin1:
	JSR		KeybdGetCharWait
	AND		#$FF
	CMP		#CR
	BEQ		.bin2
	JSR		OutChar
	BRA		.bin1
.bin2:
	LDA		CursorX
	BEQ		.bin4
	LDA		VideoPos	; get current video position
	SEC
	SBC		CursorX		; go back to the start of the line
	ASL
	TAX
.bin3:
	LDA		$FFF:VIDBUF,X
	AND		#$FF
	STA		(3,s),Y
	INX
	INX
	INY
	DEC		CursorX
	BNE		.bin3
	LDA		#0
.bin4:
	STA		(3,s),Y	; NULL terminate buffer
	RTS

.st0003:
	LDA		$FFF:KEYBD
	BPL		.st0003
	PHA						; save off the char (we need to trash acc)
	LDA		$FFF:KEYBD+4	; clear keyboard strobe (must be a read operation)
	PLA						; restore char
	JSR		DisplayChar
	BRA		.st0003
	ldy		#$0000
.st0001:
	ldx		#$0000
.st0002:
	inx
	bne		.st0002
	jsr		echo_switch
	iny
	bra		.st0001

msgStarting:
	.byte	"FT832 Test System Starting",CR,LF,0

echo_switch:
	lda		$7100
	sta		$7000
	rts

;------------------------------------------------------------------------------
; On entry to the SSM task the .A register will be set to the task number
; being single stepped. The .X register will contain the address of the
; next instruction to execute.
;------------------------------------------------------------------------------

SSMInit:
	; setup SSM data segment in SDT
	LDY		#6
	LDA		#1
	XBAW
	LDA		#$0000
	LDX		#$882		; 1k data
	SDU
	; Setup SSM stack segment in SDT
	INY
	LDA		#$0400
	LDX		#$882		; 1k stack
	SDU
	; Setup SSM code segment in SDT
	INY
	LDA		#$0000
	XBAW
	LDA		#$0000
	LDX		#$905
	SDU
	JMF		8:.0001
.0001:
	; Initialize data selector and stack selector, pointer
	; The stack is begin switched from the one currently defined by
	; by the task table. So the return task needs to be popped off
	; the current stack and placed on the new one.
	PLX					; get the task to return to
	LDA		#7
	SEI
	TASS
	LDA		#$3FF		; setup stack pointer
	TAS
	CLI
	PHX					; save return task on new stack
	PEA		6
	PLDS

	LDA		#$6100
	STA		NormAttr
	LDA		#4095		; set segment
	STA		Vidptr+4
	STA		Vidregs+4
	LDA		#$000B		; screen location is $FB0000
	STA		Vidptr+2
	STZ		Vidptr
	LDA		#$000E		; regset is at $FEA010
	STA		Vidregs+2
	LDA		#$A010
	STA		Vidregs
	LDY		#7
	LDA		#$10		; divide by 2 vertically, 1 horizontally
	JSR		SetVideoReg
	LDA		#180		; set window left position 672
	LDY		#2
	JSR		SetVideoReg
	LDA		#2
	LDY		#3
	JSR		SetVideoReg
	LDA		#32			; set window top position
	LDY		#4
	JSR		SetVideoReg
	JSR		GetTextRowsCols
	LDA		#DisplayChar
	STA		OutputVec
	JSR		ClearScreen
	JSR		HomeCursor
	PEA		8
	PEA		msgSSM
	JSR		DisplayString
	RTT
SSMTask:
	STA		WorkTR
	JSR		DispRegs
.0004:
	LDA		#'S'
	JSR		OutChar
	LDA		#'S'
	JSR		OutChar
	LDA		#'M'
	JSR		OutChar
	LDA		#'>'
.0005:
	JSR		OutChar
.0008:
	JSR		KeybdGetCharWait
	BCS		.0008
	AND		#$FF
	CMP		#'S'		; step
	BNE		.0001
.0002:
	RTT
	BRA		SSMTask
.0001:
	CMP		#'X'
	BNE		.0006
	LDA		reg_sr
	AND		#$EFFF
	STA		reg_sr
	JSR		BuildRec
	LDX		WorkTR
	LDT		ldtrec
	RTT
	BRA		SSMTask
.0006:
	CMP		#CR
	BNE		.0005
	LDA		CursorY
	ASL
	TAX
	LDA		CS:LineTbl,X
	CLC
	ADC		#4
	ASL
	TAX
	JSR		IgnoreBlanks
	JSR		MonGetch
	CMP		#'M'
	BNE		.0007
	JSR		doMemoryDump
.0007:
	BRL		.0005
	RTT
	BRL		SSMTask

msgSSM:
	.byte	"Single step mode task starting.",CR,LF,0

;------------------------------------------------------------------------------
; Convert Ascii character to screen character.
;------------------------------------------------------------------------------

AsciiToScreen:
	AND		#$FF
	BIT		#%00100000	; if bit 5 isn't set
	BEQ		.00001
	BIT		#%01000000	; or bit 6 isn't set
	BEQ		.00001
	AND		#%10011111
.00001:
	rts

	MEM		8
AsciiToScreen8:
	BIT		#%00100000	; if bit 5 isn't set
	BEQ		.00001
	BIT		#%01000000	; or bit 6 isn't set
	BEQ		.00001
	AND		#%10011111
.00001:
	rts

	MEM		16
;------------------------------------------------------------------------------
; Convert screen character to ascii character
;------------------------------------------------------------------------------
;
ScreenToAscii:
	AND		#$FF
	CMP		#26+1
	BCS		.0001
	ADC		#$60
.0001:
	RTS

;------------------------------------------------------------------------------
; Display a character on the screen device
; Expects the processor to be in 16 bit mode with 16 bit acc and 16 bit indexes
;------------------------------------------------------------------------------
;
DisplayChar:
	AND		#$0FF
	BIT		EscState		; check if processing escape sequence
	LBMI	processEsc
	CMP		#BS
	LBEQ	doBackSpace
	CMP		#$91			; cursor right
	LBEQ	doCursorRight
	CMP		#$93			; cursor left
	LBEQ	doCursorLeft
	CMP		#$90			; cursor up
	LBEQ	doCursorUp
	CMP		#$92			; cursor down
	LBEQ	doCursorDown
	CMP		#$99			; delete
	LBEQ	doDelete
	CMP		#CR
	BEQ		doCR
	CMP		#LF
	BEQ		doLF
	CMP		#$94
	LBEQ	doCursorHome	; cursor home
	CMP		#ESC
	BNE		.0003
	STZ		EscState		; put a -1 in the escape state
	DEC		EscState
	RTS
.0003:
	JSR		AsciiToScreen
	ORA		NormAttr
	PHA
	LDA		VideoPos
	ASL
	TAY
	PLA
	STA		FAR {Vidptr},Y
	LDA		CursorX
	INA
	CMP		Textcols
	BNE		.0001
	STZ		CursorX
	LDA		CursorY
	INA
	CMP		Textrows
	BEQ		.0002
	STA		CursorY
	BRL		SyncVideoPos
.0002:
	DEA
	JSR		SyncVideoPos
	BRL		ScrollUp
.0001:
	STA		CursorX
	BRL		SyncVideoPos
doCR:
	STZ		CursorX
	BRL		SyncVideoPos
doLF:
	LDA		CursorY
	INA
	CMP		Textrows
	LBPL	ScrollUp
	STA		CursorY
	BRL		SyncVideoPos

; Process escape sequences for WYSE terminal emulation
; Handles:
; {esc}T		- clear to end of line
; {esc}W		- delete character
; {esc}`1		- cursor on
; {esc}`0		- cursor off
; {esc}({esc}G4	- reverse video
; {esc}({esc}G0	- normal video
;
; EscState
; -1 = first esc char
; -2 = second esc char
; ...
;
processEsc:
	LDX		EscState
	CPX		#-1
	BNE		.0006
	CMP		#'T'	; clear to EOL
	BNE		.0003
	LDA		VideoPos
	ASL
	TAY
	LDX		CursorX
	INX
.0001:
	CPX		Textcols
	BPL		.0002
	LDA		#' '
	ORA		NormAttr
	STA		FAR {Vidptr},Y
	INX
	INY
	INY
	BNE		.0001
.0002:
	STZ		EscState
	RTS
.0003:
	CMP		#'W'
	BNE		.0004
	STZ		EscState
	BRL		doDelete
.0004:
	CMP		#'`'
	BNE		.0005
	LDA		#-2
	STA		EscState
	RTS
.0005:
	CMP		#'('
	BNE		.0008
	LDA		#-3
	STA		EscState
	RTS
.0008:
	STZ		EscState
	RTS
.0006:
	CPX		#-2
	BNE		.0007
	STZ		EscState
	CMP		#'1'
	LBEQ	CursorOn
	CMP		#'0'
	LBEQ	CursorOff
	RTS
.0007:
	CPX		#-3
	BNE		.0009
	CMP		#ESC
	BNE		.0008
	LDA		#-4
	STA		EscState
	RTS
.0009:
	CPX		#-4
	BNE		.0010
	CMP		#'G'
	BNE		.0008
	LDA		#-5
	STA		EscState
	RTS
.0010:
	CPX		#-5
	BNE		.0008
	STZ		EscState
	CMP		#'4'
	BNE		.0011
	LDA		NormAttr
	; Swap the high nybbles of the attribute
	XBA				
	SEP		#$30		; set 8 bit regs
	NDX		8			; tell the assembler
	MEM		8
	ROL
	ROL
	ROL
	ROL
	REP		#$30		; set 16 bit regs
	NDX		16			; tell the assembler
	MEM		16
	XBA
	AND		#$FF00
	STA		NormAttr
	RTS
.0011:
	CMP		#'0'
	BNE		.0012
	LDA		#$BF00		; Light Grey on Dark Grey
	STA		NormAttr
	RTS
.0012:
	LDA		#$BF00		; Light Grey on Dark Grey
	STA		NormAttr
	RTS

doBackSpace:
	LDX		CursorX
	BEQ		.0001		; Can't backspace anymore
	LDA		VideoPos
	ASL
	TAY
.0002:
	LDA		FAR {Vidptr},Y
	DEY
	DEY
	STA		FAR {Vidptr},Y
	INY4
	INX
	CPX		Textcols
	BNE		.0002
.0003:
	LDA		#' '
	ORA		NormAttr
	STA		FAR {Vidptr},Y
	DEC		CursorX
	BRL		SyncVideoPos
.0001:
	RTS

; Deleting a character does not change the video position so there's no need
; to resynchronize it.

doDelete:
	LDX		CursorX
	LDA		VideoPos
	ASL
	TAY
.0002:
	INX
	CPX		Textcols
	BPL		.0001
	DEX
	INY
	INY
	LDA		FAR {Vidptr},Y
	DEY
	DEY
	STA		FAR {Vidptr},Y
	INY
	INY
	INX
	BRA		.0002
.0001:
	LDA		#' '
	ORA		NormAttr
	STA		FAR {Vidptr},Y
	RTS

doCursorHome:
	LDA		CursorX
	BEQ		doCursor1
	STZ		CursorX
	BRA		SyncVideoPos
doCursorRight:
	LDA		CursorX
	INA
	CMP		Textcols
	BPL		doRTS
doCursor2:
	STA		CursorX
	BRA		SyncVideoPos
doCursorLeft:
	LDA		CursorX
	BEQ		doRTS
	DEA
	BRA		doCursor2
doCursorUp:
	LDA		CursorY
	BEQ		doRTS
	DEA
	BRA		doCursor1
doCursorDown:
	LDA		CursorY
	INA
	CMP		Textrows
	BPL		doRTS
doCursor1:
	STA		CursorY
	BRA		SyncVideoPos
doRTS:
	RTS

HomeCursor:
	LDA		#0
	STZ		CursorX
	STZ		CursorY

; Synchronize the absolute video position with the cursor co-ordinates.
;
SyncVideoPos:
	PHA
	PHY
	LDA		CursorY
	ASL
	TAX
	LDA		5:LineTbl,X
	CLC
	ADC		CursorX
	STA		VideoPos
	LDY		#13
	STA		FAR {Vidregs},Y		; Update the position in the text controller
	PLY
	PLA
	RTS

OutCRLF:
	LDA		#CR
	JSR		OutChar
	LDA		#LF

OutChar:
	PHX
	PHY
	PHP
	REP		#$30
	MEM		16
	NDX		16
	LDX		#0
	JSR		(OutputVec,x)
	PLP
	PLY
	PLX
	RTS

DisplayString:
;	PLA							; pop return address
;	PLX							; get string address parameter
;	PHA							; push return address
	PHP							; push reg settings
	SEP		#$20				; ACC = 8 bit
	MEM		8
;	STX		StringPos
	LDY		#0
.0002:
	LDA		FAR (4,S),Y
	BEQ		.0001
	JSR		OutChar
	INY
	BRA		.0002
.0001:
	PLP							; restore regs settings
;	REP		#$20				; ACC 16 bits
	MEM		16
	RTS		#4					; pop stack argument

DisplayString2:
	PLA							; pop return address
	PLX							; get string address parameter
	PHA							; push return address
	SEP		#$20				; ACC = 8 bit
	STX		StringPos
	LDY		#0
	LDX		#50
.0002:
	LDA		(StringPos),Y
	JSR		OutChar
	INY
	DEX
	BNE		.0002
.0001:
	REP		#$20				; ACC 16 bits
	RTS

GetTextRowsCols:
	PHA
	PHY
	LDY		#0
	LDA.UB	FAR {Vidregs},Y
	STA		Textcols
	INY
	LDA.UB	FAR {Vidregs},Y
	STA		Textrows
	PLY
	PLA
	RTS

; .Y = register number to set
; Acc = value
;
SetVideoReg:
	PHP								; save regs size settings
	SEP		#$20
	STA		FAR {Vidregs},Y
	PLP								; restore reg size settings
	RTS

CursorOn:
	PHA
	PHY
	LDY		#9
	LDA		#$1F60
	STA		FAR {Vidregs},Y
	PLY
	PLA
	RTS

CursorOff:
	PHA
	PHY
	LDY		#9
	LDA		#$0020
	STA		FAR {Vidregs},Y
	PLY
	PLA
	RTS

ClearScreen:
	LDX		#4095
	LDY		#$00
	LDA		#' '
	JSR		AsciiToScreen
	ORA		NormAttr
.0001:
	STA		FAR {Vidptr},Y
	INY
	INY
	DEX
	BNE		.0001
	RTS

ScrollUp:
	LDY		#0				; .Y used as index to char
	LDX 	#2603			; number of chars on screen
.0001:
	PHY						; save off current .Y
	TYA								
	CLC						; Add double the number of text
	ADC		Textcols		; columns to .Y to find start of next
	CLC						; row 
	ADC		Textcols
	TAY						
	LDA		FAR {Vidptr},Y	; .A = Load buffer[textcols+Y]
	PLY						; .Y = restore current .Y
	STA		FAR {Vidptr},Y	; Store .A in buffer[0+Y]
	INY						; advance to next character
	INY						; decrement total char count
	DEX
	BNE		.0001
	LDA		Textrows
	DEA

BlankLine:
	ASL
	TAY
	LDA		CS:LineTbl,Y
	ASL
	TAY
	LDX		Textcols		; number of chars to clear
	LDA		NormAttr
	ORA		#$20			; space
.0001:
	STA		FAR {Vidptr},Y
	INY						; increment to next char
	INY
	DEX						; decrement number of chars
	BNE		.0001
	RTS

DispDWord:
	XBAW
	JSR		DispWord
	XBAW
DispWord:
	XBA
	JSR		DispByte
	XBA
DispByte:
	PHA
	LSR
	LSR
	LSR
	LSR
	JSR		DispNybble
	PLA
DispNybble:
	PHA
	AND		#$0F
	CMP		#10
	BCC		.0001
	ADC		#'A'-11			; -11 cause the carry is set
	JSR		OutChar
	PLA
	RTS
.0001:
	ORA		#'0'
	JSR		OutChar
	PLA
	RTS

space:
	PHA
	LDA		#' '
	JSR		OutChar
	PLA
	RTS

;------------------------------------------------------------------------------
; Get a range (two hex numbers)
;------------------------------------------------------------------------------

GetRange:
	JSR		IgnoreBlanks
	JSR		GetHexNumber
	CPY		#0
	BEQ		.0001
	LDA		NumWorkArea
	STA		RangeStart
	STA		RangeEnd
	LDA		NumWorkArea+2
	STA		RangeStart+2
	STA		RangeEnd+2
	JSR		IgnoreBlanks
	JSR		GetHexNumber
	CPY		#0
	BEQ		.0001
	LDA		NumWorkArea
	STA		RangeEnd
	LDA		NumWorkArea+2
	STA		RangeEnd+2
.0001:
	RTS
	
;------------------------------------------------------------------------------
; Get a hexidecimal number. Maximum of six digits.
; .X = text pointer (updated)
;------------------------------------------------------------------------------
;
GetHexNumber:
	LDY		#0					; maximum of eight digits
	STZ		NumWorkArea
	STZ		NumWorkArea+2
gthxn2:
	JSR		MonGetch
	JSR		AsciiToHexNybble
	BMI		gthxn1
	ASL		NumWorkArea
	ROL		NumWorkArea+2
	ASL		NumWorkArea
	ROL		NumWorkArea+2
	ASL		NumWorkArea
	ROL		NumWorkArea+2
	ASL		NumWorkArea
	ROL		NumWorkArea+2
	ORA		NumWorkArea
	STA		NumWorkArea
	INY
	CPY		#8
	BNE		gthxn2
	RTS
gthxn1:
	DEX
	DEX
	RTS

;------------------------------------------------------------------------------
; Convert ASCII character in the range '0' to '9', 'a' to 'f' or 'A' to 'F'
; to a hex nybble.
;------------------------------------------------------------------------------
;
AsciiToHexNybble:
	CMP		#'0'
	BCC		gthx3
	CMP		#'9'+1
	BCS		gthx5
	SEC
	SBC		#'0'
	RTS
gthx5:
	CMP		#'A'
	BCC		gthx3
	CMP		#'F'+1
	BCS		gthx6
	SEC
	SBC		#'A'
	CLC
	ADC		#10
	RTS
gthx6:
	CMP		#'a'
	BCC		gthx3
	CMP		#'z'+1
	BCS		gthx3
	SEC
	SBC		#'a'
	CLC
	ADC		#10
	RTS
gthx3:
	LDA		#-1		; not a hex number
	RTS

AsciiToDecNybble:
	CMP		#'0'
	BCC		gtdc3
	CMP		#'9'+1
	BCS		gtdc3
	SEC
	SBC		#'0'
	RTS
gtdc3:
	LDA		#-1
	RTS

getcharNoWait:
	LDA		#1
	STA		ZS:keybd_cmd
	TSK		#6
	LDA		ZS:keybd_char
	BPL		.0001
	SEC
	RTS
.0001:
	CLC
	RTS

getcharWait:
	LDA		#2
	STA		ZS:keybd_cmd
	TSK		#6
	LDA		ZS:keybd_char
	BPL		.0001
	SEC
	RTS
.0001:
	CLC
	RTS

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; Keyboard processing routines follow.
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
ResetKbd:
	SEP		#$30
	MEM		8
	NDX		8
	STZ		KeyState1
	STZ		KeyState2
	LDA		#$FF
	STA		$FFF:KEYBD
	JSR		KeybdWaitTx
	REP		#$30
	MEM		16
	NDX		16
	RTS
KeybdInit:
	LDA		#$2000
	TAS
	LDA		#5
	STA		keybd_cmd
	SEP		#$30
	MEM		8
	NDX		8
	STZ		KeyState1
	STZ		KeyState2
	LDY		#12
	RTT
.resetAgain:
	LDA		#$FF			; send reset code to keyboard
	STA		$FFF:KEYBD
	JSR		KeybdWaitTx
.0001:
	JSR		KeybdRecvByte	; Look for $AA
	BCC		.tryAgain
	CMP		#$AA			;
	BEQ		.config
.0002:
	; wait until keyboard not busy
	JSR		Wait10ms
	LDA		$FFF:KEYBD+1		;
	BIT		#$40
	BNE		.tryAgain
	LDA		#$FF			; send reset code to keyboard
	STA		$FFF:KEYBD
	JSR		Wait10ms
	JSR		KeybdWaitTx		; wait until no longer busy
	JSR		KeybdRecvByte	; look for an ACK ($FA)
	BCC		.tryAgain
	CMP		#$FE
	BEQ		.tryAgain
	CMP		#$FA
	BNE		.tryAgain
	JSR		KeybdRecvByte
	CMP		#$FC			; reset error ?
	BEQ		.tryAgain
	CMP		#$AA			; reset complete okay ?
	BNE		.tryAgain
.config:
	JSR		KeybdWaitBusy
	LDA		#$F0			; send scan code select
	STA		$FFF:KEYBD
	JSR		KeybdWaitTx
	BCC		.tryAgain
	JSR		KeybdRecvByte	; wait for response from keyboard
	BCC		.tryAgain
	CMP		#$FE
	BEQ		.tryAgain
	CMP		#$FA
	BEQ		.0004
.tryAgain:
	DEY
	BNE		.0001
	DEC		keybd_cmd
	BNE		.resetAgain
.keybdErr:
	REP		#$30
	PEA		1
	PEA		msgKeybdNR
	JSR		DisplayString
	RTT
	BRA		KeybdService
.0004:
	LDA		#2				; select scan code set #2
	STA		$FFF:KEYBD
	JSR		KeybdWaitTx
	BCC		.tryAgain
	JSR		KeybdRecvByte
	BCC		.tryAgain
	REP		#$30
	RTT
	BRA		KeybdService

KeybdService:
	REP		#$30
	MEM		16
	NDX		16
	LDA		#$2000
	TAS
	LDA		keybd_cmd
	CMP		#1
	BNE		.0001
	JSR		KeybdGetCharNoWait
	BCS		.nokey
	STZ		keybd_cmd
	STA		keybd_char
	RTT
	BRA		KeybdService
.nokey
	LDA		#-1
	STZ		keybd_cmd
	STA		keybd_char
	RTT
	BRA		KeybdService
.0001:
	CMP		#2
	BNE		.0002
	JSR		KeybdGetCharWait
	STZ		keybd_cmd
	STA		keybd_char
	RTT
	BRA		KeybdService
.0002:
	RTT
	BRA		KeybdService

	MEM		8
	NDX		8

; Receive a byte from the keyboard, used after a command is sent to the
; keyboard in order to wait for a response.
;
KeybdRecvByte:
	PHY
	LDY		#20				; wait up to .2s
.0003:
	JSR		KeybdWaitBusy
	LDA		$FFF:KEYBD+1	; wait for response from keyboard
	ASL						; is input buffer full ?
	BCS		.0004			; yes, branch
	JSR		Wait10ms		; wait a bit
	DEY
	BNE		.0003			; go back and try again
	PLY						; timeout
	CLC						; carry clear = no code
	RTS
.0004:
	LDA		$FFF:KEYBD		; clear recieve state
	PLY
	SEC						; carry set = code available
	RTS

; Wait until the keyboard isn't busy anymore
; Wait until the keyboard transmit is complete
; Returns .CF = 1 if successful, .CF=0 timeout
;
KeybdWaitBusy:				; alias for KeybdWaitTx
KeybdWaitTx:
	PHA
	PHY
	LDY		#10				; wait a max of .1s
.0001:
	LDA		$FFF:KEYBD+1
	BIT		#$40			; check for transmit busy bit
	BEQ		.0002			; branch if bit clear
	JSR		Wait10ms		; delay a little bit
	DEY						; go back and try again
	BNE		.0001
	PLY						; timed out
	PLA
	CLC						; return carry clear
	RTS
.0002:
	PLY						; wait complete, return 
	PLA
	SEC						; carry set
	RTS

; Wait approximately 10ms. Used by keyboard routines. Makes use of the free
; running counter #0.
; .A = trashed (=-5)
;
Wait10ms:
	PHA
	PHX				; save .X
	LDA		ZS:CNT0H	; get starting count
	TAX				; save it off in .X
.0002:
	SEC				; compare to current counter value
	SBC		ZS:CNT0H
	EOR		#$FF	; make negative
	CMP		#10
	BPL     .0001
	TXA				; prepare for next check, get startcount in .A
	BRA		.0002	; go back if less than 5 ticks
.0001:
	PLX				; restore .X
	PLA
	RTS

	MEM		16
	NDX		16

msgKeybdNR:
	.byte	CR,LF,"Keyboard not responding.",CR,LF,0

	cpu		FT832

KeybdGetCharNoWaitCtx:
	JSR		KeybdGetCharNoWait
	RTC		#0
	
KeybdGetCharNoWait:
	PHP
	SEI
	REP		#$30
	MEM		16
	NDX		16
	TTA
	CMP		IOFocusTask
	BNE		.noFocus
	SEP		#$20
	REP		#$10
	MEM		8
	NDX		16
	STZ		TaskSwitchEn
	CLI
	LDA		#0
	STA		KeybdWaitFlag
	BRA		KeybdGetChar1
.noFocus:
	PLP
	SEC		; flag no key available
	RTS

KeybdGetCharWait:
	PHP
	SEP		#$20
	REP		#$10
	MEM		8
	NDX		16
	LDA		#$FF
	STA		KeybdWaitFlag
	BRA		KeybdGetChar1

; Wait for a keyboard character to be available
; Returns (CF=1) if no key available
; Return key (CF=0) if key is available
;
;
KeybdGetChar:
	PHP
	SEP		#$20		; 8 bit acc
	REP		#$10
	MEM		8
	NDX		16
KeybdGetChar1:
	PHX
	XBA					; force .B to zero for TAX
	LDA		#0
	XBA
.0002:
.0003:
	LDA		$FFF:KEYBD+1		; check MSB of keyboard status reg.
	ROL
	ROL
	BCS		.0003		; check busy flag, branch if busy
	ROR
	BCS		.0006		; branch if keystroke ready
	BIT		KeybdWaitFlag
	BMI		.0003
	PLX
	PLP
	SEC
	RTS
.0006:
	LDA		$FFF:KEYBD	; get scan code value
	STZ		$FFF:KEYBD+2	; clear read flag
	;REP		#$20
	;JSR		DispByte
	;JSR		space
	;SEP		#$20
.0001:
	CMP		#SC_KEYUP	; keyup scan code ?
	LBEQ	.doKeyup	; 
	CMP		#SC_EXTEND	; extended scan code ?
	LBEQ	.doExtend
	CMP		#$14		; control ?
	LBEQ	.doCtrl
	CMP		#$12		; left shift
	LBEQ	.doShift
	CMP		#$59		; right shift
	LBEQ	.doShift
	CMP		#SC_NUMLOCK
	LBEQ	.doNumLock
	CMP		#SC_CAPSLOCK
	LBEQ	.doCapsLock
	CMP		#SC_SCROLLLOCK
	LBEQ	.doScrollLock
	LSR		KeyState1
	BCS		.0003
	TAX
	LDA		#$80
	BIT		KeyState2	; Is extended code ?
	BEQ		.0010
	LDA		#$7F
	AND		KeyState2
	STA		KeyState2
	LSR		KeyState1	; clear keyup
	TXA
	AND		#$7F
	TAX
	LDA		cs:keybdExtendedCodes,X
	BRA		.0008
.0010:
	LDA		#4
	BIT		KeyState2	; Is Cntrl down ?
	BEQ		.0009
	TXA
	AND		#$7F		; table is 128 chars
	TAX
	LDA		cs:keybdControlCodes,X
	BRA		.0008
.0009:
	LDA		#$1			; Is shift down ?
	BIT		KeyState2
	BEQ		.0007
	LDA		cs:shiftedScanCodes,X
	BRA		.0008
.0007:
	LDA		cs:unshiftedScanCodes,X
.0008:
	PLX
	PLP
	CLC
	RTS
	MEM		8
.doKeyup:
	LDA		#1
	TSB		KeyState1
	BRL		.0003
.doExtend:				; set extended key flag
	LDA		KeyState2
	ORA		#$80
	STA		KeyState2
	BRL		.0003
.doCtrl:
	LDA		#4
	LSR		KeyState1	; check key up/down	
	BCC		.0004		; keydown = carry clear
	TRB		KeyState2
	BRL		.0003
.0004:
	TSB		KeyState2	; set control active bit
	BRL		.0003
.doShift:
	LDA		#1
	LSR		KeyState1	; check key up/down	
	BCC		.0005
	TRB		KeyState2
	BRL		.0003
.0005:
	TSB		KeyState2
	BRL		.0003
.doNumLock:
	LDA		KeyState2
	EOR		#16
	STA		KeyState2
	SEP		#$30
	JSR		KeybdSetLEDStatus
	REP		#$20
	BRL		.0003
.doCapsLock:
	LDA		KeyState2
	EOR		#32
	STA		KeyState2
	SEP		#$30
	JSR		KeybdSetLEDStatus
	REP		#$20
	BRL		.0003
.doScrollLock:
	LDA		KeyState2
	EOR		#64
	STA		KeyState2
	SEP		#$30
	JSR		KeybdSetLEDStatus
	REP		#$20
	BRL		.0003

KeybdSetLEDStatus:
;	PHDS				; save off DS
;	PEA		5			; set DS to zero
;	PLDS
	LDA		#0
	STA		KeybdLEDs
	LDA		#16
	BIT		KeyState2
	BEQ		.0002
	LDA		KeybdLEDs	; set bit 1 for Num lock, 0 for scrolllock , 2 for caps lock
	ORA		#$2
	STA		KeybdLEDs
.0002:
	LDA		#32
	BIT		KeyState2
	BEQ		.0003
	LDA		KeybdLEDs
	ORA		#$4
	STA		KeybdLEDs
.0003:
	LDA		#64
	BIT		KeyState2
	BEQ		.0004
	LDA		KeybdLEDs
	ORA		#1
	STA		KeybdLEDs
.0004:
	LDA		#$ED		; set status LEDs command
	STA		$FFF:KEYBD
	JSR		KeybdWaitTx
	JSR		KeybdRecvByte
	BCC		.0001
	CMP		#$FA
	LDA		KeybdLEDs
	STA		$FFF:KEYBD
	JSR		KeybdWaitTx
	JSR		KeybdRecvByte	; wait for $FA byte
.0001:
;	PLDS				; recover DS
	RTS


	;--------------------------------------------------------------------------
	; PS2 scan codes to ascii conversion tables.
	;--------------------------------------------------------------------------
	;
unshiftedScanCodes:
	.byte	$2e,$a9,$2e,$a5,$a3,$a1,$a2,$ac
	.byte	$2e,$aa,$a8,$a6,$a4,$09,$60,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$71,$31,$2e
	.byte	$2e,$2e,$7a,$73,$61,$77,$32,$2e
	.byte	$2e,$63,$78,$64,$65,$34,$33,$2e
	.byte	$2e,$20,$76,$66,$74,$72,$35,$2e
	.byte	$2e,$6e,$62,$68,$67,$79,$36,$2e
	.byte	$2e,$2e,$6d,$6a,$75,$37,$38,$2e
	.byte	$2e,$2c,$6b,$69,$6f,$30,$39,$2e
	.byte	$2e,$2e,$2f,$6c,$3b,$70,$2d,$2e
	.byte	$2e,$2e,$27,$2e,$5b,$3d,$2e,$2e
	.byte	$ad,$2e,$0d,$5d,$2e,$5c,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$08,$2e
	.byte	$2e,$95,$2e,$93,$94,$2e,$2e,$2e
	.byte	$98,$7f,$92,$2e,$91,$90,$1b,$af
	.byte	$ab,$2e,$97,$2e,$2e,$96,$ae,$2e

	.byte	$2e,$2e,$2e,$a7,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$fa,$2e,$2e,$2e,$2e,$2e

shiftedScanCodes:
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$09,$7e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$51,$21,$2e
	.byte	$2e,$2e,$5a,$53,$41,$57,$40,$2e
	.byte	$2e,$43,$58,$44,$45,$24,$23,$2e
	.byte	$2e,$20,$56,$46,$54,$52,$25,$2e
	.byte	$2e,$4e,$42,$48,$47,$59,$5e,$2e
	.byte	$2e,$2e,$4d,$4a,$55,$26,$2a,$2e
	.byte	$2e,$3c,$4b,$49,$4f,$29,$28,$2e
	.byte	$2e,$3e,$3f,$4c,$3a,$50,$5f,$2e
	.byte	$2e,$2e,$22,$2e,$7b,$2b,$2e,$2e
	.byte	$2e,$2e,$0d,$7d,$2e,$7c,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$08,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$7f,$2e,$2e,$2e,$2e,$1b,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e

	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e

; control
keybdControlCodes:
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$09,$7e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$11,$21,$2e
	.byte	$2e,$2e,$1a,$13,$01,$17,$40,$2e
	.byte	$2e,$03,$18,$04,$05,$24,$23,$2e
	.byte	$2e,$20,$16,$06,$14,$12,$25,$2e
	.byte	$2e,$0e,$02,$08,$07,$19,$5e,$2e
	.byte	$2e,$2e,$0d,$0a,$15,$26,$2a,$2e
	.byte	$2e,$3c,$0b,$09,$0f,$29,$28,$2e
	.byte	$2e,$3e,$3f,$0c,$3a,$10,$5f,$2e
	.byte	$2e,$2e,$22,$2e,$7b,$2b,$2e,$2e
	.byte	$2e,$2e,$0d,$7d,$2e,$7c,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$08,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$7f,$2e,$2e,$2e,$2e,$1b,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e

keybdExtendedCodes:
	.byte	$2e,$2e,$2e,$2e,$a3,$a1,$a2,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	.byte	$2e,$95,$2e,$93,$94,$2e,$2e,$2e
	.byte	$98,$99,$92,$2e,$91,$90,$2e,$2e
	.byte	$2e,$2e,$97,$2e,$2e,$96,$2e,$2e

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; SPI MASTER driver
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

; spi_master_init
; Initialize the spi master controller

spi_master_init:
	
	PHP
	SEP		#$20
	MEM		8
	LDA		#SPI_INIT_SD
	STA		SPI_TRANS_TYPE_REG
	LDA		#SPI_TRANS_START
	STA		SPI_TRANS_CTRL_REG
.0001:
	LDA		SPI_TRANS_STS_REG		; wait for SPI transfer to complete
	CMP		#SPI_TRANS_BUSY
	BEQ		.0001
	LDA		SPI_TRANS_ERROR_REG
	AND		#3	; INIT errors
	CMP		#SPI_INIT_NO_ERROR
	BEQ		.0004
	PLP
	MEM		16
	NDX		16
	PEA		1
	PEA		msgSpiInitError
	JSR		DisplayString
	LDA		#1
	RTS
.0004:
	PLP
	;PEA		1
	;PEA		msgSpiInited
	;JSR		DisplayString
	LDA		#0
	RTS

; spi_master_read
; read a block from the SD card
;
; Parameters:
;	32 bit buffer address pushed onto stack
;	32 bit block number pushed onto stack
;
spi_master_read:
	PHP
	SEP		#$20
	MEM		8
	NDX		16
	TSX
	LDA		4,X
	STA		SPI_SD_SECT_7_0_REG
	LDA		5,X
	STA		SPI_SD_SECT_15_8_REG
	LDA		6,X
	STA		SPI_SD_SECT_23_16_REG
	LDA		7,X
	STA		SPI_SD_SECT_31_24_REG
	LDA		8,X
	STA		bufptr
	LDA		9,X
	STA		bufptr+1
	LDA		10,X
	STA		bufptr+2
	LDA		11,X
	STA		bufptr+3
	LDA		#SPI_RW_READ_SD_BLOCK
	STA		SPI_TRANS_TYPE_REG
	LDA		#SPI_TRANS_START
	STA		SPI_TRANS_CTRL_REG
.0001:
	LDA		SPI_TRANS_STS_REG		; wait for SPI transfer to complete
	CMP		#SPI_TRANS_BUSY
	BEQ		.0001
	LDA		SPI_TRANS_ERROR_REG
	LSR
	LSR
	AND		#3	; INIT errors
	CMP		#SPI_READ_NO_ERROR
	BEQ		.0004
	PLP
	MEM		16
	PEA		1
	PEA		msgSpiReadError
	JSR		DisplayString
	LDA		#1
	RTS		#8
.0004:
	REP		#$10
	MEM		8
	NDX		16
	LDX		#512
	LDY		#0
.0003:
	;TXA
	;AND		#$0F
	;BNE		.0002
	;PLP
	;JSR		OutCRLF
	;PHP
	;SEP		#$20
.0002:
	LDA		SPI_RX_FIFO_DATA_REG
	STA		{bufptr},Y
	INY
	;PLP
	;JSR		DispByte
	;JSR		space
	;PHP
	SEP		#$20
	DEX
	BNE		.0003
	PLP
	;JSR		OutCRLF
	MEM		16
	NDX		16
	LDA		#0
	RTS		#8

spi_master_write:
	PHP
	SEP		#$20
	MEM		8
	NDX		16

	TSX
	LDA		8,X
	STA		bufptr
	LDA		9,X
	STA		bufptr+1
	LDA		10,X
	STA		bufptr+2
	LDA		11,X
	STA		bufptr+3

	LDY		#0
.0001:
	LDA		{bufptr},Y
	STA		SPI_TX_FIFO_DATA_REG
	INY
	CPY		#512
	BNE		.0001

	LDA		4,X
	STA		SPI_SD_SECT_7_0_REG
	LDA		5,X
	STA		SPI_SD_SECT_15_8_REG
	LDA		6,X
	STA		SPI_SD_SECT_23_16_REG
	LDA		7,X
	STA		SPI_SD_SECT_31_24_REG

	LDA		#SPI_RW_WRITE_SD_BLOCK
	STA		SPI_TRANS_TYPE_REG
	LDA		#SPI_TRANS_START
	STA		SPI_TRANS_CTRL_REG
.0002:
	LDA		SPI_TRANS_STS_REG		; wait for SPI transfer to complete
	CMP		#SPI_TRANS_BUSY
	BEQ		.0002
	LDA		SPI_TRANS_ERROR_REG
	LSR
	LSR
	LSR
	LSR
	AND		#3	; write errors
	CMP		#SPI_WRITE_NO_ERROR
	BEQ		.0004
	PLP
	MEM		16
	PEA		1
	PEA		msgSpiWriteError
	JSR		DisplayString
	LDA		#1
	RTS		#8
.0004:
	PLP
	LDA		#0
	RTS		#8

msgSpiInitError:
.byte	"Error initializing SPI master",$0D,$0A,$00
msgSpiInited:
.byte	"SPI master inited",$0D,$0A,$00
msgSpiReadError:
.byte	"SPI read error",$0D,$0A,$00
msgSpiWriteError:
.byte	"SPI write error",$0D,$0A,$00

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; RTC driver for MCP7941x
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

rtc_init:
		LDA		#53					; constant for 125kHz I2C from 33MHz 
		STA		I2C_PRESCALE_LO
		RTS

; Read all the RTC sram registers into a buffer

rtc_read:
		PHP
		SEP		#$30
		MEM		8
		NDX		8
		LDA		#$80				; enable I2C
		STA		I2C_CONTROL
		LDA		#$DE				; read address, write op
		LDY		#$90				; STA + wr bit
		JSR		rtc_wr_cmd
		BMI		.rxerr
		LDA		#$00				; address zero
		LDY		#$10				; wr bit
		JSR		rtc_wr_cmd
		BMI		.rxerr
		LDA		#$DF				; read address, read op
		LDY		#$90				; STA + wr bit
		JSR		rtc_wr_cmd
		BMI		.rxerr
		LDX		#0
.0001:
		LDA		#$20				; rd bit
		STA		I2C_CMD
		JSR		rtc_wait_tip
		LDA		I2C_STAT
		BMI		.rxerr
		LDA		I2C_RX
		STA		RTCBuf,X
		INX
		CPX		#$5F
		BNE		.0001
		LDA		#$68				; STO, rd bit + nack
		STA		I2C_CMD
		JSR		rtc_wait_tip
		LDA		I2C_STAT
		BMI		.rxerr
		LDA		I2C_RX
		STA		RTCBuf,X
		LDA		#0					; disable I2C and return 0
		STA		I2C_CONTROL
		PLP
		RTS
.rxerr:
		STZ		I2C_CONTROL			; disable I2C and return status
		PLP
		RTS

rtc_wait_tip:
.0001:
		LDA		I2C_STAT
		AND		#$4					; transmit in progress bit
		BNE		.0001
		RTS

rtc_wr_cmd:
		STA		I2C_TX
		STY		I2C_CMD
		JSR		rtc_wait_tip
		LDA		I2C_STAT
		RTS

rtc_write:
		PHP
		SEP		#$30
		MEM		8
		NDX		8
		LDA		#$80				; enable I2C
		STA		I2C_CONTROL
		LDA		#$DE				; read address, write op
		LDY		#$90				; STA + wr bit
		JSR		rtc_wr_cmd
		BMI		.rxerr
		LDA		#$00				; address zero
		LDY		#$10				; wr bit
		JSR		rtc_wr_cmd
		BMI		.rxerr
		LDX		#0
.0001:
		LDA		RTCBuf,X
		LDY		#$10
		JSR		rtc_wr_cmd
		BMI		.rxerr
		INX
		CPX		#$5F
		BNE		.0001
		LDA		RTCBuf,X
		LDY		#$50				; STO, wr bit
		JSR		rtc_wr_cmd
		BMI		.rxerr
		LDA		#0					; disable I2C and return 0
		STA		I2C_CONTROL
		PLP
		RTS
.rxerr:
		STZ		I2C_CONTROL			; disable I2C and return status
		PLP
		RTS

msgRtcReadFail:
	.byte	"RTC read/write failed.",$0D,$0A,$00

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

; Get char routine for Supermon
; This routine might be called with 8 bit regs.
;
	MEM		16
	NDX		16
SuperGetch:
	JSR		KeybdGetCharNoWait
	AND		#$FF
	RTC		#0
	BRL		TaskFC

; Put char routine for Supermon
;
SuperPutch:
	JSR		OutChar
	RTC		#0
	BRL		TaskFC

; Char get routine for BASIC
; Same thing as for Supermon, except carry flag needs to be inverted
; This routine should be called from a different context than the BIOS,
; otherwise the call will be ignored.
;
BasicGetch:
	LDA		#$F1
	STA		$7000
	JSR		KeybdGetCharNoWait
	AND		#$FF
	CMC
	RTC		#0
	BRL		TaskFC

xitBasic:
	PLX						; get rid of task to return to, we won't be returning
	STA		ExitCode
	STZ		TCB_status+7	; no longer ready
	STZ		IOFocusTask
	STZ		IOFocusTask+1
	TSK		JMP:#0
	BRL		TaskFC

warm_start:
	SEP		#$100		; 16 bit mode
	REP		#$30		; 16 bit MEM,NDX
	MEM		16
	NDX		16
	LDA		#$3FFF
	TAS
	JSR		CursorOn
	BRL		Mon1

	cpu		FT832
ICacheIL832:
	CACHE	#1			; 1= invalidate instruction line identified by accumulator
	RTS

;============================================================================
; Multi-tasking kernel
;============================================================================

.include "FMTKmsg.asm"

	MEM		32
	NDX		32
;----------------------------------------------------------------------------
; SelectTaskToRun:
;
; Selects a task to run from the ready fifo. The ready fifo is really a 
; group of fifos, one each for a priority group. Priority groups are
; $0x, $1x, $2x, $3x, $4x
;
; Returns
;	.A = task number to run
; Modifies:
;	.X, .Y, and flags
;----------------------------------------------------------------------------

StartQ:
	.byte	0,1,0,2,0,3,0,4,0,1,0,2,0,3,0,4

SelectTaskToRun:
	LDA		#4
	STA.B	qcnt
	LDA		TickCount		; vary the starting queue to check
	AND		#$0F			; based on the tick count
	TAY
	LDA.B	StartQ,Y
	ASL
	TAX
.nextQ:
.notReady:
	LDA.H	READY_FIFO_CNT,X	; get count of ready tasks in fifo
	BEQ		.fifoEmpty
	LDA.H	READY_FIFO,X	; get ready task from fifo
	STA.H	hTcbTmp
	JSR		hTcbToAddr
	TAY
	LDA.B	TCB_status,Y	; check the status and make sure it's ready
	CMP		#TS_READY
	BNE		.notReady
	LDA.H	hTcbTmp
	STA.H	READY_FIFO,X	; add back to fifo as last entry
	RTS

	; move to the next queue
.fifoEmpty:
	INX
	INX
	CPX		#10
	BLT		.0001
	LDX		#0				; cycle back around to first Q
.0001:
	DEC.B	qcnt
	BNE		.nextQ
	TTA						; if all queues empty, keep running the current
	RTS

;----------------------------------------------------------------------------
; Insert task into ready fifo.
; Parameters:
;	.A = handle to TCB
;----------------------------------------------------------------------------

InsertIntoReadyFifo:
	PHA
	JSR		hTcbToAddr
	TAX							; .X = task number (index into tables)
	LDA		#TS_READY			; set task status to ready
	STA.B	TCB_status,X
	LDA.B	TCB_priority,X		; get the priority
	LSR							; use upper nybble to identify priority que
	LSR
	LSR
	LSR
	ASL
	TAY
	PLA
	STA.H	READY_FIFO,Y
	RTS

; IRQ routine for all modes. The interrupted task must of had interrupts
; enabled and this status should be saved on the stack with the value of
; the status register. The RTI instruction will pop the status register off
; the stack and restore the interrupt enable.
; Note that all this routine does is switch to a task which has a different
; register set, so there's no need to stack and restore registers. The
; task switch also allows the routine to be located anywhere in the memory
; system, so we don't have to worry about using up bank 0 memory.

IRQRout832:
IRQRout816:
IRQRout02:
	TSK		#1			; switch to the interrupt handling task
	RTI

; This task has interrupts masked in it's startup record and therefore runs
; with interrupts masked as the task never enables interrupts. Note that it's
; important that interrupts are masked while this is running, otherwise the
; uncleared interrupt status would cause another interrupt resulting in an
; infinite interrupt loop.

Task1:
	LDA.B	MPU_IRQ_STATUS	; check if counter expired
	BIT		#2				; counter #1 IRQ active bit
	BEQ		.0001			; no IRQ ?
	LDA		TickCount		; increment the tick count
	INA						; lower 16 bits
	STA		TickCount
	STA.B	$FFF:$D00A4		; update on-screen IRQ live indicator
	LDA		#$05			; count down, on mpu clock, irq enabled (clears irq)
	STA.B	CTR1_CTRL		; set control register clearing interrupt
	LDA.B	$0:$100DF		; Set flag for EhBASIC Irq
	ORA		#$20
	STA.B	$0:$100DF
.nextTo:
	LDA		#TOL_DEC
	STA.B	TIMEOUT_LIST	; decrement the timeout list
	NOP						; might take up to 3 clock cycles
	NOP
	LDA.H	TIMEOUT_LIST+2	; get any timedout task
	BMI		.noMoreTos
	JSR		InsertIntoReadyFifo
	BRA		.nextTo
.noMoreTos:
	LDA.B	TaskSwitchEn	; only switch tasks if enabled
	BEQ		.0001
	JSR		SelectTaskToRun
	TSX
	STA.H	$1,X			; change return task # on stack
.0001:
	RIT					; return from interrupt task
	BRA		Task1		; the next time task1 is run it will start here

	MEM		16
	NDX		16
BtnuIRQ:
	LDA.B	$FFF:$D00A0
	INA
	STA.B	$FFF:$D00A0
	JSR		spi_master_init
	CMP		#0
	BNE		.0001
	LDX		#0
.0002:
	PEA		$000F
	TXA
	XBA
	ASL
	PHA
	PEA		0
	PEA		0
	STX		reg_x
	JSR		spi_master_read
	LDX		reg_x
	INX
	CPX		#128
	BNE		.0002
.0001:
	RIT
	BRA		BtnuIRQ

; IRQ handler task - 32 bit
;
IRQTask:
	MEM		8
	NDX		32
IRQTask1:
	LDA		MPU_IRQ_STATUS	; check if counter expired
	BIT		#2
	BEQ		.0001
	LDX		TickCount		; increment the tick count
	INX
	STX		TickCount
	STX.B	$FFF:$D00A2			; update on-screen IRQ live indicator
	LDA		#$05			; count down, on mpu clock, irq enabled (clears irq)
	STA		CTR1_CTRL
.0001:
	RTT					; go back to interrupted task
	BRA		IRQTask1	; the next time task is run it will start here

; This little task sample runs in native 32 bit mode and displays
; "Hello World!" on the screen.

	CPU		FT832
	MEM		8
	NDX		32

Task2:
	LDX		#84*2*3
.0003:
	LDY		#0
.0002:
	LDA		CS:msgHelloWorld,Y
	BEQ		.0001
	JSR		AsciiToScreen8
	STA		$FFF:VIDBUF,X
	INX
	INX
	INY
	BRA		.0002
.0001:
	RTT
	BRA		.0003

msgHelloWorld:
	.byte	CR,LF,"Hello World!",CR,LF,0

	NDX		16
	MEM		16

BrkTask:
	INC		$FFD00000
	RTT
	BRA		BrkTask

; The following store sequence for the benefit of Supermon816
;
BrkRout:
	PHD
	PHB
	REP		#$30
	PHA
	PHX
	PHY
	JMP		($0102)		; This jump normally points to BrkRout1
BrkRout1:
	REP		#$30
	PLY
	PLX
	PLA
	PLB
	PLD
	SEP		#$20
	PLA
	REP		#$30
	PLA
	JSR		DispWord
	LDX		#0
	LDY		#64
.0001:
	.word	$f042		; pchist
	JSR		DispWord
	LDA		#' '
	JSR		OutChar
	INX
	DEY
	BNE		.0001
	LDA		#$FFFF
	STA		$7000
Hung:
	BRA		Hung

	;--------------------------------------------------------
	;--------------------------------------------------------
	; I/O page is located at $F0xx
	;--------------------------------------------------------
	;--------------------------------------------------------	
	;org		$F100

LineTbl:
	.WORD	0
	.WORD	TEXTCOLS
	.WORD	TEXTCOLS*2
	.WORD	TEXTCOLS*3
	.WORD	TEXTCOLS*4
	.WORD	TEXTCOLS*5
	.WORD	TEXTCOLS*6
	.WORD	TEXTCOLS*7
	.WORD	TEXTCOLS*8
	.WORD	TEXTCOLS*9
	.WORD	TEXTCOLS*10
	.WORD	TEXTCOLS*11
	.WORD	TEXTCOLS*12
	.WORD	TEXTCOLS*13
	.WORD	TEXTCOLS*14
	.WORD	TEXTCOLS*15
	.WORD	TEXTCOLS*16
	.WORD	TEXTCOLS*17
	.WORD	TEXTCOLS*18
	.WORD	TEXTCOLS*19
	.WORD	TEXTCOLS*20
	.WORD	TEXTCOLS*21
	.WORD	TEXTCOLS*22
	.WORD	TEXTCOLS*23
	.WORD	TEXTCOLS*24
	.WORD	TEXTCOLS*25
	.WORD	TEXTCOLS*26
	.WORD	TEXTCOLS*27
	.WORD	TEXTCOLS*28
	.WORD	TEXTCOLS*29
	.WORD	TEXTCOLS*30

TaskStartTbl:
	.WORD	0			; CS
	.WORD	0			; DS
	.WORD	0			; SS
	.WORD	Task0		; PC
	.BYTE	Task0>>16	; PB
	.WORD	0			; acc
	.WORD	0
	.WORD	0			; x
	.WORD	0
	.WORD	0			; y
	.WORD	0
	.WORD	$3FFF		; sp
	.WORD	0
	.BYTE	4			; SR
	.BYTE	1			; SR extension
	.BYTE	0			; DB
	.WORD	0			; DPR
	.WORD	0

	; TASK #1
	; Interrupt handler task
	.WORD	0			; CS
	.WORD	5			; DS
	.WORD	5			; SS
	.WORD	Task1		; PC
	.BYTE	Task1>>16
	.WORD	0			; acc
	.WORD	0
	.WORD	0			; x
	.WORD	0
	.WORD	0			; y
	.WORD	0
	.WORD	$3BFF		; sp
	.WORD	0
	.BYTE	4			; SR
	.BYTE	2			; SR extension	(32 bit mode)
	.BYTE	0			; DB
	.WORD	0			; DPR
	.WORD	0

	.WORD	0			; CS
	.WORD	0			; DS
	.WORD	0			; SS
	.WORD	Task2		; PC
	.BYTE	Task2>>16
	.WORD	0			; acc
	.WORD	0
	.WORD	0			; x
	.WORD	0
	.WORD	0			; y
	.WORD	0
	.WORD	$37FF		; sp
	.WORD	0
	.BYTE	$20			; SR			; eight bit mem
	.BYTE	2			; SR extension
	.BYTE	0			; DB
	.WORD	0			; DPR
	.WORD	0

	; TASK #3
	; Button Interrupt handler task
	.WORD	0			; CS
	.WORD	5			; DS
	.WORD	5			; SS
	.WORD	BtnuIRQ		; PC
	.BYTE	BtnuIRQ>>16
	.WORD	0			; acc
	.WORD	0
	.WORD	0			; x
	.WORD	0
	.WORD	0			; y
	.WORD	0
	.WORD	$3AFF		; sp
	.WORD	0
	.BYTE	4			; SR
	.BYTE	1			; SR extension
	.BYTE	0			; DB
	.WORD	0			; DPR
	.WORD	0

	.WORD	0			; CS
	.WORD	0			; DS
	.WORD	0			; SS
	.WORD	BrkTask		; PC
	.BYTE	BrkTask>>16
	.WORD	0			; acc
	.WORD	0
	.WORD	0			; x
	.WORD	0
	.WORD	0			; y
	.WORD	0
	.WORD	$2FFF		; sp
	.WORD	0
	.BYTE	0			; SR
	.BYTE	1			; SR extension
	.BYTE	0			; DB
	.WORD	0			; DPR
	.WORD	0

	; task #5
	; DS is placed at $7800
	.WORD	0			; CS
	.WORD	0    		; DS
	.WORD	0			; SS
	.WORD	InvadersTask	; PC
	.BYTE	InvadersTask>>16
	.WORD	0			; acc
	.WORD	0
	.WORD	0			; x
	.WORD	0
	.WORD	0			; y
	.WORD	0
	.WORD	$2BFF		; sp
	.WORD	0
	.BYTE	0			; SR
	.BYTE	1			; SR extension
	.BYTE	0			; DB
	.WORD	0			; DPR
	.WORD	0

	.WORD	0			; CS
	.WORD	0			; DS
	.WORD	0			; SS
	.WORD	IRQTask		; PC
	.BYTE	IRQTask>>16
	.WORD	0			; acc
	.WORD	0
	.WORD	0			; x
	.WORD	0
	.WORD	0			; y
	.WORD	0
	.WORD	$27FF		; sp
	.WORD	0
	.BYTE	$24			; SR	8 bit acc, mask interrupts
	.BYTE	2			; SR extension - 832 mode
	.BYTE	0			; DB
	.WORD	0			; DPR
	.WORD	0

	; task 7 (Basic)
	.WORD	$FFD		; CS
	.WORD	$FFD		; DS
	.WORD	$FFD		; SS
	.WORD	$C000		; PC
	.BYTE	$00
	.WORD	0			; acc
	.WORD	0
	.WORD	0			; x
	.WORD	0
	.WORD	0			; y
	.WORD	0
	.WORD	$01FF		; sp
	.WORD	0
	.BYTE	0			; SR
	.BYTE	0			; SR extension - 832 mode
	.BYTE	0			; DB
	.WORD	0			; DPR
	.WORD	63			; map

	; task 8 (Supermon)
	.WORD	$0			; CS
	.WORD	$5			; DS
	.WORD	$5			; SS
	.WORD	$C000		; PC
	.BYTE	$00
	.WORD	0			; acc
	.WORD	0
	.WORD	0			; x
	.WORD	0
	.WORD	0			; y
	.WORD	0
	.WORD	$2BFF		; sp
	.WORD	0
	.BYTE	0			; SR
	.BYTE	1			; SR extension - 832 mode
	.BYTE	0			; DB
	.WORD	0			; DPR
	.WORD	0			; map

	; task 9 (single step)
	.WORD	0			; CS
	.WORD	0			; DS
	.WORD	0			; SS
	.WORD	SSMInit		; PC
	.BYTE	SSMTnit>>16
	.WORD	0			; acc
	.WORD	0
	.WORD	0			; x
	.WORD	0
	.WORD	0			; y
	.WORD	0
	.WORD	$33FF		; sp
	.WORD	0
	.BYTE	$4			; SR	16 bit regs, mask interrupts
	.BYTE	1			; SR extension - 816 mode
	.BYTE	0			; DB
	.WORD	0			; DPR
	.WORD	0

msgRegs:
	.byte	CR,LF
    .byte   "             xxxsxi31",CR,LF
    .byte   "  CS  PB PC  xxxsxn26NVmxDIZC    .A       .X       .Y       SP  ",CR,LF,0
msgRegs2:
	.byte	CR,LF
	.byte	"  SS   DS  DB  DP   BL  MP",CR,LF,0
msgErr:
	.byte	"***Err",CR,LF,0

;	cpu		FT832
;	MEM		32
;	NDX		32
;	LDA		#$12345678
;	LDX		#$98765432
;	STA.B	{$23},Y
;	LDY.UH	$44455556,X
;	LDA.H	CS:$44455556,X
;	LDA.UB	SEG $8888:$1234,Y
;	JSF	    $0000:start
;	RTF
;	ADC     SEG $9821:$1200,X
;	EOR     $821:$1200,X
;	EOR     $841:$12
;	SBC     FAR {$24},Y
;	AND     FAR($25)
;	ORA     FAR ($26,x)
;	TSK		#2
;	TSK
;	LDT		$10000,X

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; +---------------------------+
; | block status / ptr to free|
; +---------------------------+
; | pointer to previous block |
; +---------------------------+
; | pointer to next block     |
; +---------------------------+
;
	MEM		32
	NDX		32
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
FreeSysMem:
	SEC
	SBC		#12		;	backup to block header
	TAY				;	.Y = pointer to block to free (this)
	PHP				; save interrupt mask
	SEI				; no interrupts
	STZ		$0,Y	; set status as free
	LDX		$8,Y	;	.X = pointer to next block
	LDA		$0,X	;	.A = next->status
	BEQ		.0001	;	branch if not free
	; merge block with next free block
	LDA		$8,X	;   .A = pointer to next next block
	STA		$8,Y	;
	TAX
	STY		$4,X	;	next->next->prev = this
.0001:
	; merge block with a previous free block
	LDX		$4,Y	;	.X = pointer to prev block
	LDA		$0,X	;	.A = prev->status
	BEQ		.0002	;	branch if not free
	LDA		$8,Y	;   prev->next = this->next
	STA		$8,X
	TAY				;	.Y = this->next
	STX		$4,Y	;	this->next->prev = this->prev
	TXY
.0002:
	LDA		heap_free_ptr
	STA		$0,Y
	STY		heap_free_ptr
	PLP
	RTS

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
	; round allocation size to mmu available sizes

	LDX		#0
	CLC				; add room for header
	ADC		#12
.0002:
	CMP		mmas,X
	BLE		.0001
	INX
	INX
	INX
	INX
	BRA		.0002
.0001:
	LDA		mmas,X
	TAX
	LDY		free_heap_ptr
	; subtract .Y from .A
	SEC
	LDA		$8,Y
	STY		tmpy
	SBC		tmpy
	CMP		mmas,X
	BLT		.0003
	; here block is big enough
	PHA
	LDA		$0,Y
	STA		free_heap_ptr
	STZ		$0,Y
	PLA
	SEC
	SBC		mmas,X
	CMP		#$0FF
	BLT		.0004

.0004:
	


; Memory management allocation sizes
;
mmas:
	WORD	$0000,$0000
	WORD	$00FF,$0000
	WORD	$03FF,$0000
	WORD	$0FFF,$0000
	WORD	$3FFF,$0000
	WORD	$FFFF,$0000
	WORD	$FFFF,$0003
	WORD	$FFFF,$000F
	WORD	$FFFF,$003F
	WORD	$FFFF,$00FF
	WORD	$FFFF,$03FF
	WORD	$FFFF,$0FFF
	WORD	$FFFF,$3FFF
	WORD	$FFFF,$FFFF

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
	MEM		16
	NDX		16
	JMP		MusicPlay
beep:
	LDA		#15					; set volume to max
	STA		$FFF:SID+SID_VOLUME		
	LDA		#$0C6F				; 10C6F = 800 Hz
	STA		$FFF:SID+SID_FREQ0
	LDA		#1
	STA		$FFF:SID+SID_FREQ0+2
	LDA		#195				; 2ms
	STA		$FFF:SID+SID_ATTACK0
	STZ		$FFF:SID+SID_ATTACK0+2
	LDA		#2344				; 24 ms decay
	STA		$FFF:SID+SID_DECAY0
	STZ		$FFF:SID+SID_DECAY0+2
	LDA		#$80				; 50% sustain level
	STA		$FFF:SID+SID_SUSTAIN0
	LDA		#48828				; 500 ms release
	STA		$FFF:SID+SID_RELEASE0
	STZ		$FFF:SID+SID_RELEASE0+2
	LDA		#1					; reset envelope generator
	STA		$FFF:SID+SID_CTRL0+2
	NOP
	NOP
	STZ		$FFF:SID+SID_CTRL0+2
	LDA		#$1504				; gate on
	STA		$FFF:SID+SID_CTRL0
	; delay for about 1s
	LDY		#39
.0002:
	LDX		#65535
.0001:
	DEX
	BNE		.0001
	DEY
	BNE		.0002
	LDA		#$0504				; gate off
	STA		$FFF:SID+SID_CTRL0
	RTS
	
music_tbl:
	dh	1
	dw	33673		; G4
	dw	12			; 1/8 sec
	dw	4			; space

	dh	1
	dw	33673		; G4
	dw	12			; 1/8
	dw	4			; space

	dh	1
	dw	33673		; G4
	dw	12			; 1/8
	dw	4			; space

	dh	0
	dw	0			; G4
	dw	0			; 1/8
	dw	0			; space

MusicPlay:
	LDX		#0
	LDA		#195				; 2ms
	STA		$FFF:SID+SID_ATTACK0
	STZ		$FFF:SID+SID_ATTACK0+2
	LDA		#2344				; 24 ms decay
	STA		$FFF:SID+SID_DECAY0
	STZ		$FFF:SID+SID_DECAY0+2
	LDA		#$D0				; sustain level
	STA		$FFF:SID+SID_SUSTAIN0
	LDA		#4600				; ??? ms release
	STA		$FFF:SID+SID_RELEASE0
	STZ		$FFF:SID+SID_RELEASE0+2
.0001:
	LDA		music_tbl,x			; check for last note
	BEQ		.xit
	LDA		music_tbl+2,x			; set the frequency
	STA		$FFF:SID+SID_FREQ0
	LDA		music_tbl+4,x
	STA		$FFF:SID+SID_FREQ0+2
	LDA		#$1504				; gate on
	STA		$FFF:SID+SID_CTRL0
	SEI
	LDA		music_tbl+6,x
	STA		timeout1
	LDA		music_tbl+8,x
	STA		timeout1+2
	JSR		MusicWaitTimeout
	LDA		#$0504				; gate off
	STA		$FFF:SID+SID_CTRL0
	SEI
	LDA		music_tbl+10,x		; note release delay
	STA		timeout1
	LDA		music_tbl+12,x
	STA		timeout1+2
	JSR		MusicWaitTimeout
	INX
	INX
	INX4
	INX4
	INX4
	BRA		.0001
.xit:
	RTS

MusicWaitTimeout:
.0001:
	CLI
	NOP
	NOP
	SEI
	LDA		timeout1
	ORA		timeout1+2
	BNE		.0001
	CLI
	RTS

MusicTimeoutIRQ:
	REP		#$30
	MEM		16
	NDX		16
	LDA		timeout1
	ORA		timeout1+2
	BEQ		.0001
	SEC
	LDA		timeout1
	SBC		#1
	STA		timeout1
	LDA		timeout1+2
	SBC		#0
	STA		timeout1+2
.0001:
	RTS

	.org	$FE00
	JMP		SuperGetch
	JMP		warm_start
	JMP		SuperPutch
	JMP		BIOSInput
	JMP		BasicGetch
	JMP		xitBasic

	.org 	$FFD6
	dw		4			; task #4

	.org	$FFDE
	dw		6			; task #6

	.org	$FFE0
	dw		3

	.org 	$FFE6
	dw		BrkRout

	.org	$FFEE		; '816 IRQ vector
	dw		1			; IRQRout816

	.org	$FFFC
	dw		$E000

	.org	$FFFE
	dw		1			; IRQRout02
