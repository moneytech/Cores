;****************************************************************;
;                                                                ;
;		Tiny BASIC for the CS01                                      ;
;                                                                ;
; Derived from a 68000 derivative of Palo Alto Tiny BASIC as     ;
; published in the May 1976 issue of Dr. Dobb's Journal.         ;
; Adapted to the 68000 by:                                       ;
;	Gordon brndly						                         ;
;	12147 - 51 Street					                         ;
;	Edmonton AB  T5W 3G8					                     ;
;	Canada							                             ;
;	(updated mailing address for 1996)			                 ;
;                                                                ;
; Adapted to the CS01 by:                                        ;
;    Robert Finch                                                ;
;    Ontario, Canada                                             ;
;	 robfinch<remove>@finitron.ca    	                             ;  
;****************************************************************;
;  Copyright (C) 2016-2020 by Robert Finch. This program may be	 ;
;    freely distributed for personal use only. All commercial	 ;
;		       rights are reserved.			                     ;
;****************************************************************;
;
; Register Usage
; $t2 = text pointer (global usage)
; r3,r4 = inputs parameters to subroutines
; a1 = return value
;
;* Vers. 1.0  1984/7/17	- Original version by Gordon brndly
;*	1.1  1984/12/9	- Addition of '0x' print term by Marvin Lipford
;*	1.2  1985/4/9	- Bug fix in multiply routine by Rick Murray

CR		EQU	0x0D		;ASCII equates
LINEFD	EQU	0x0A		; Don't use LF (same as load float instruction)
TAB		EQU	0x09
CTRLC	EQU	0x03
CTRLH	EQU	0x08
CTRLI	EQU	0x09
CTRLJ	EQU	0x0A
CTRLK	EQU	0x0B
CTRLM   EQU 0x0D
CTRLS	EQU	0x13
CTRLX	EQU	0x18
XON		EQU	0x11
XOFF	EQU	0x13

FILENAME	EQU		0x6C0
FILEBUF		EQU		0x07F600
OSSP		EQU		0x700
TXTUNF		EQU		OSSP+4
VARBGN		EQU		TXTUNF+4
VAREND		EQU		VARBGN+4
LOPVAR		EQU		VAREND+4
STKGOS		EQU		LOPVAR+4
CURRNT		EQU		STKGOS+4
BUFFER		EQU		CURRNT+4
BUFLEN		EQU		84
LOPPT		EQU		BUFFER+84
LOPLN		EQU		LOPPT+4
LOPINC		EQU		LOPLN+4
LOPLMT		EQU		LOPINC+4
NUMWKA		EQU		LOPLMT+24
STKINP		EQU		NUMWKA+4
STKBOT		EQU		STKINP+4
usrJmp		EQU		STKBOT+4
IRQROUT		EQU		usrJmp+4

OUTPTR		EQU		IRQROUT+4
INPPTR		EQU		OUTPTR+4
CursorFlash	EQU		INPPTR+4
IRQFlag		EQU		CursorFlash+4

;
; Modifiable system constants:
;
;THRD_AREA	dw	0x04000000	; threading switch area 0x04000000-0x40FFFFF
;bitmap dw	0x00100000	; bitmap graphics memory 0x04100000-0x417FFFF
TXTBGN		EQU		0x001800	;TXT ;beginning of program memory
ENDMEM		EQU		0x008000	; end of available memory
STACKOFFS	EQU		0x07FFFC	; stack offset


		code
		align	4096
;
; Standard jump table. You can change these addresses if you are
; customizing this interpreter for a different environment.
;
TinyBasic:
GOSTART:	
		jmp	CSTART	;	Cold Start entry point
GOWARM:	
		jmp	WSTART	;	Warm Start entry point
GOOUT:	
		jmp	OUTC	;	Jump to character-out routine
GOIN:	
		jmp	INCH	;Jump to character-in routine
GOAUXO:	
		jmp	AUXOUT	;	Jump to auxiliary-out routine
GOAUXI:	
		jmp	AUXIN	;	Jump to auxiliary-in routine
GOBYE:	
		jmp	BYEBYE	;	Jump to monitor, DOS, etc.

	align	16
//message "CSTART"
public CSTART:
	; First save off the link register and OS sp value
	sw		$sp,OSSP
	ldi		$sp,#STACKOFFS	; initialize stack pointer
//	call	_RequestIOFocus
;	call	_DBGHomeCursor[pc]
	mov		a0,r0			; turn off keyboard echoing
//	call	SetKeyboardEcho
//	stz		CursorFlash
//	ldx		#0x10000020	; black chars, yellow background
;	stx		charToPrint
;	call	_DBGClearScreen[pc]
	ldi		a0,#msgInit	;	tell who we are
	call	PRMESG
	ldi		a0,#TXTBGN	;	init. end-of-program pointer
	sw		a0,TXTUNF
	ldi		a0,#ENDMEM	;	get address of end of memory
	ldi		a0,#$7F800
	sw		a0,STKBOT
	ldi		a0,#ENDMEM
	sw		a0,VAREND
	sub		a0,a0,#800 	;   100 vars
	sw    a0,VARBGN
	call  clearVars   ; clear the variable area
	sw		r0,IRQROUT
	lw    a0,VARBGN   ; calculate number of bytes free
	lw		a1,TXTUNF
	sub   a0,a0,a1
	ldi		a1,#6		; max 6 digits
	ldi		a2,#10	; base 10
	call  PRTNUM
	ldi		a0,#msgBytesFree
	call	PRMESG
WSTART:
	sw		x0,LOPVAR   ; initialize internal variables
	sw		x0,STKGOS
	sw		x0,CURRNT	;	current line number pointer = 0
	ldi		$sp,#STACKOFFS	;	init S.P. again, just in case
	ldi		a0,#msgReady	;	display "Ready"
	call	PRMESG
BASPRMPT:
	ldi		a0,#'>'		; Prompt with a '>' and
	call	GETLN		; read a line.
	call	TOUPBUF 	; convert to upper case
	mov		$s6,$t2		; save pointer to end of line
	ldi		$t2,#BUFFER	; point to the beginning of line
	call	TSTNUM		; is there a number there?
	call	IGNBLK		; skip trailing blanks
	lbu		$s6,[$t2]
	xor		$s6,$s6,#CR	; s6 = flag empty line
; does line no. exist? (or nonzero?)
	beq		v1,x0,DIRECT		; if not, it's a direct statement
	ldi		$t1,#$FFFFF
	ble		v0,$t1,ST2	; see if line no. is <= 16 bits
	ldi		a0,#msgLineRange	; if not, we've overflowed
	jmp		ERROR
ST2:
  mov		$a0,$v0		; a0 = line number
  mov		$s5,$t2			; save line buffer pointer
	sub		$t2,$t2,#4
  sw		$a0,[$t2]		;	This will end up in buffer
	call	FNDLN		; find this line in save area
	mov		$s7,$t3		; save possible line pointer
	beq		$v0,$x0,INSLINE	; if not found, insert
	mov		$a0,$t3
	call	DeleteLine
INSLINE:
	beq		$s6,$x0,BASPRMPT	; line was empty
	mov		$a0,$s5			; a0 = buffer pointer	
	; GetBuflen just get the length of the text.
	; A line number is stuffed just before the text
	; so length needs to be adjusted by 4.
	call	GetBuflen
	add		$s4,$v0,#4
	mov		$a0,$s7
	mov		$a1,$s4
	call	OpenSpace
	bne		$v0,$x0,.0001	; space available?
	ldi		a0,#msgTooBig	; no space available
	jmp		ERROR
.0001:
	mov		$a0,$s7			; target
	sub		$a1,$s5,#4	; source (incl lineno)
	mov		$a2,$s4			; length
	call	InsertLine
	bra		BASPRMPT

;------------------------------------------------------------------------------
; Parameters:
;		a0 = pointer to line to delete
; Modifies:
;		t0,t1,t2,t3
; Returns:
;		none
;------------------------------------------------------------------------------

DeleteLine:
	; Find the end of the line to delete
	add		$t0,$a0,#4		; t0 = pointer to line past line number
	ldi		$t2,#CR
	lw		$t3,TXTUNF		; last text address
.0002:
	lbu		$t1,[$t0]
	beq		$t1,$x0,.0003	; might be null
	beq		$t1,$t2,.0001	; lines end with CR
	add		$t0,$t0,#1
	bltu	$t0,$t3,.0002	; end of program?
.0001:
	add		$t0,$t0,#1
.0003:
	; pull text after eol overtop
	lbu		$t4,[$t0]			; copy from next line
	sb		$t4,[$a0]			; overtop deleted line
	add		$t0,$t0,#1		; increment pointers
	add		$a0,$a0,#1
	bleu	$t0,$t3,.0003	; to end of program
	; update end of text
	sub		$a0,$t0,$a0		; difference of pointers = length
	sub		$t3,$t3,$a0		
	sw		$t3,TXTUNF
	ret

;------------------------------------------------------------------------------
; Parameters:
; 	a0 = insertion point
; 	a1 = source buffer
; 	a2 = length
; Modifies:
;		a0,a1,a2,t1
; Returns:
;		none
;------------------------------------------------------------------------------

InsertLine:
	beq		$a2,$x0,.done		; zero length? Probably a SW error
.0001:
	lbu		$t1,[$a1]				; get from source text
	sb		$t1,[$a0]				; store to insertion point
	add		$a1,$a1,#1			; increment pointers
	add		$a0,$a0,#1
	sub		$a2,$a2,#1			; decrement length
	bgtu	$a2,$x0,.0001
.done:
	ret

;------------------------------------------------------------------------------
; GetBuflen - get the length of text in a buffer. The length is taken up to
; the first null character or carriage return character encountered.
;
; Parameters:
;		a0 = pointer to buffer
; Modifies:
;		t2,t3,t5
; Returns:
;		v0 = length of data in buffer
;------------------------------------------------------------------------------

GetBuflen:
	ldi		$v0,#0
	ldi		$t3,#CR
	mov		$t5,$a0
.0002:
	lbu		$t2,[$t5]
	add		$t5,$t5,#1
	beq		$t2,$x0,.0001
	beq		$t2,$t3,.0004
	add		$v0,$v0,#1
	bra		.0002
.0004:
	add		$v0,$v0,#1
.0001:
	ret

;------------------------------------------------------------------------------
; Parameters:
; 	a0 = place to insert line
; 	a1 = buffer length
; Modifies:
;		t1,t2,t3,t5
; Returns:
;		v0 = 1 if successful, 0 if not enough room available
;------------------------------------------------------------------------------

OpenSpace:
	lw		$t2,TXTUNF
	mov		$t3,$t2				; t3 = old end of text
	add		$t2,$t2,$a1		; increment end of text by buffer length
	lw		$t1,VARBGN		; compare to start of variables
	bgeu	$t2,$t1,.noSpace	; enough room?
	sw		$t2,TXTUNF		; yes, set new end of text
.0003:
	lbu		$t5,[$t3]			; copy old text
	sb		$t5,[$t2]			; to new text loc
	sub		$t3,$t3,#1		; decrement pointers
	sub		$t2,$t2,#1
	bgeu	$t3,$a0,.0003	; until insert point reached
	ldi		$v0,#1				; return success
	ret
.noSpace:
	ldi		$v0,#0
	ret	

;******************************************************************
;
; *** Tables *** DIRECT *** EXEC ***
;
; This section of the code tests a string against a table. When
; a match is found, control is transferred to the section of
; code according to the table.
;
; At 'EXEC', r8 should point to the string, r9 should point to
; the character table, and r10 should point to the execution
; table. At 'DIRECT', r8 should point to the string, r9 and
; r10 will be set up to point to TAB1 and TAB1_1, which are
; the tables of all direct and statement commands.
;
; A '.' in the string will terminate the test and the partial
; match will be considered as a match, e.g. 'P.', 'PR.','PRI.',
; 'PRIN.', or 'PRINT' will all match 'PRINT'.
;
; There are two tables: the character table and the execution
; table. The character table consists of any number of text items.
; Each item is a string of characters with the last character's
; high bit set to one. The execution table holds a 32-bit
; execution addresses that correspond to each entry in the
; character table.
;
; The end of the character table is a 0 byte which corresponds
; to the default routine in the execution table, which is
; executed if none of the other table items are matched.
;
; Character-matching tables:
TAB1:
	db	"LIS",'T'+0x80        ; Direct commands
	db	"LOA",'D'+0x80
	db	"NE",'W'+0x80
	db	"RU",'N'+0x80
	db	"SAV",'E'+0x80
TAB2:
	db	"NEX",'T'+0x80         ; Direct / statement
	db	"LE",'T'+0x80
	db	"I",'F'+0x80
	db	"GOT",'O'+0x80
	db	"GOSU",'B'+0x80
	db	"RETUR",'N'+0x80
	db	"RE",'M'+0x80
	db	"FO",'R'+0x80
	db	"INPU",'T'+0x80
	db	"PRIN",'T'+0x80
	db	"POK",'E'+0x80
	db	"POKE",'W'+0x80
	db	"POKE",'H'+0x80
	db	"YIEL",'D'+0x80
	db	"STO",'P'+0x80
	db	"BY",'E'+0x80
	db	"SY",'S'+0x80
	db	"CL",'S'+0x80
    db  "CL",'R'+0x80
    db	"RDC",'F'+0x80
    db	"ONIR",'Q'+0x80
    db	"WAI",'T'+0x80
	db	0
TAB4:
	db	"PEE",'K'+0x80         ;Functions
	db	"PEEK",'W'+0x80
	db	"PEEK",'H'+0x80
	db	"RN",'D'+0x80
	db	"AB",'S'+0x80
	db  "SG",'N'+0x80
	db	"TIC",'K'+0x80
	db	"SIZ",'E'+0x80
	db  "US",'R'+0x80
	db	0
TAB5:
	db	"T",'O'+0x80           ;"TO" in "FOR"
	db	0
TAB6:
	db	"STE",'P'+0x80         ;"STEP" in "FOR"
	db	0
TAB8:
	db	'>','='+0x80           ;Relational operators
	db	'<','>'+0x80
	db	'>'+0x80
	db	'='+0x80
	db	'<','='+0x80
	db	'<'+0x80
	db	0
TAB9:
    db  "AN",'D'+0x80
    db  0
TAB10:
    db  "O",'R'+0x80
    db  0

;* Execution address tables:
; We save some bytes by specifiying only the low order 16 bits of the address
;
	align	2
TAB1_1:
	dh	LISTX			;Direct commands
	dh	LOAD3
	dh	NEW
	dh	RUN
	dh	SAVE3
TAB2_1:
	dh	NEXT		;	Direct / statement
	dh	LET
	dh	IF0
	dh	GOTO
	dh	GOSUB
	dh	RETURN
	dh	IF2			; REM
	dh	FOR
	dh	INPUT
	dh	PRINT
	dh	POKE
	dh	POKEW
	dh	POKEH
	dh	YIELD0
	dh	STOP
	dh	GOBYE
	dh	SYSX
	dh	_cls
	dh  _clr
	dh	_rdcf
	dh  ONIRQ
	dh	WAITIRQ
	dh	DEFLT
TAB4_1:
	dh	PEEK			;Functions
	dh	PEEKW
	dh	PEEKH
	dh	RND
	dh	ABS
	dh  SGN
	dh	TICKX
	dh	SIZEX
	dh  USRX
	dh	XP40
TAB5_1
	dh	FR1			;"TO" in "FOR"
	dh	QWHAT
TAB6_1
	dh	FR2			;"STEP" in "FOR"
	dh	FR3
TAB8_1
	dh	XP11	;>=		Relational operators
	dh	XP12	;<>
	dh	XP13	;>
	dh	XP15	;=
	dh	XP14	;<=
	dh	XP16	;<
	dh	XP17
TAB9_1
    dh  XP_AND
    dh  XP_ANDX
TAB10_1
    dh  XP_OR
    dh  XP_ORX

;*
; r3 = match flag (trashed)
; r9 = text table
; r10 = exec table
; r11 = trashed
	align	16
//message "DIRECT"
DIRECT:
	ldi		$t3,#TAB1
	ldi		$t4,#TAB1_1
EXEC:
	call	IGNBLK		; ignore leading blanks
	mov		$t5,$t2		; save the pointer
	mov		r3,r0		; clear match flag
EXLP:
	lbu		a0,[$t2]		; get the program character
	add		$t2,$t2,#1
	lbu		a1,[$t3]		; get the table character
	bne		a1,x0,EXNGO		; If end of table,
	mov		$t2,$t5		;	restore the text pointer and...
	bra		EXGO		;   execute the default.
EXNGO:
	beq		a0,r3,EXGO	; Else check for period... if so, execute
	and		a1,a1,#0x7f	; ignore the table's high bit
	beq		a1,a0,EXMAT	;		is there a match?
	add		$t4,$t4,#2	;if not, try the next entry
	mov		$t2,$t5		; reset the program pointer
	mov		r3,x0		; sorry, no match
EX1:
	lbu		a0,[$t3]		; get to the end of the entry
	add		$t3,$t3,#1
	and		$t1,$a0,#$80
	beq		$t1,$r0,EX1	; test for bit 7 set
	bra		EXLP		; back for more matching
EXMAT:
	ldi		r3,#'.'		; we've got a match so far
	lbu		a0,[$t3]		; end of table entry?
	add		$t3,$t3,#1
	and		$t1,$a0,#$80
	beq		$t1,$r0,EXLP		; test for bit 7 set, if not, go back for more
EXGO:
	; execute the appropriate routine
	lhu		a0,[$t4]	; get the low mid order byte
	or		a0,a0,#$FFFC0000	; add in ROM base
	jmp		[a0]

    
;******************************************************************
;
; What follows is the code to execute direct and statement
; commands. Control is transferred to these points via the command
; table lookup code of 'DIRECT' and 'EXEC' in the last section.
; After the command is executed, control is transferred to other
; sections as follows:
;
; For 'LISTX', 'NEW', and 'STOP': go back to the warm start point.
; For 'RUN': go execute the first stored line if any; else go
; back to the warm start point.
; For 'GOTO' and 'GOSUB': go execute the target line.
; For 'RETURN' and 'NEXT'; go back to saved return line.
; For all others: if 'CURRNT' is 0, go to warm start; else go
; execute next command. (This is done in 'FINISH'.)
;
;******************************************************************
;
; *** NEW *** STOP *** RUN (& friends) *** GOTO ***
;
; 'NEW<CR>' sets TXTUNF to point to TXTBGN
;

NEW:
	call	ENDCHK
	ldi		v0,#TXTBGN
	sw		v0,TXTUNF	;	set the end pointer
	call  clearVars

; 'STOP<CR>' goes back to WSTART
;
STOP:
	call	ENDCHK
	jmp		WSTART		; WSTART will reset the stack

;------------------------------------------------------------------------------
; YIELD suspends execution of TinyBasic by switching to the next ready task.
;------------------------------------------------------------------------------

YIELD0:
	ldi		a0,#13
	ecall
	jmp		FINISH
	
;------------------------------------------------------------------------------
; 'RUN<CR>' finds the first stored line, stores its address
; in CURRNT, and starts executing it. Note that only those
; commands in TAB2 are legal for a stored program.
;
; There are 3 more entries in 'RUN':
; 'RUNNXL' finds next line, stores it's address and executes it.
; 'RUNTSL' stores the address of this line and executes it.
; 'RUNSML' continues the execution on same line.
;
RUN:
	call	ENDCHK
	ldi		$t2,#TXTBGN	;	set pointer to beginning
	sw		$t2,CURRNT
	call  clearVars

RUNNXL:					; RUN <next line>
	lw		$t2,CURRNT	; executing a program?
	bne		$t2,x0,.0001	; if not, we've finished a direct stat.
RUN2:
	jmp		WSTART
.0001:
	lw		a0,IRQROUT		; are we handling IRQ's ?
	beq		a0,x0,RUN1
	lw		$t1,IRQFlag		; was there an IRQ ?
	beq		$t1,x0,RUN1
	sw		x0,IRQFlag
	call	PUSHA_		; the same code as a GOSUB
	sub		$sp,$sp,#12
	lw		a0,STKGOS
	sw		a0,[$sp]
	lw		a0,CURRNT
	sw		a0,4[$sp]
	sw		$t2,8[$sp]
	sw		x0,LOPVAR		; load new values
	sw		$sp,STKGOS
	lw		$t3,IRQROUT
	bra		RUNTSL
RUN1:
	lw		$t3,$t2
	mov		a0,x0
	call	FNDLNP		; else find the next line number
	lw		$t1,TXTUNF	; if we've fallen off the end, stop
	bgeu	$t3,$t1,RUN2

RUNTSL					; RUN <this line>
	sw		$t3,CURRNT	; set CURRNT to point to the line no.
	add		$t2,$t3,#4	; set the text pointer to

RUNSML                 ; RUN <same line>
	call	CHKIO		; see if a control-C was pressed
	ldi		$t3,#TAB2		; find command in TAB2
	ldi		$t4,#TAB2_1
	jmp		EXEC		; and execute it


;******************************************************************
; 'GOTO expr<CR>' evaluates the expression, finds the target
; line, and jumps to 'RUNTSL' to do it.
;******************************************************************
;
GOTO:
	call	OREXPR		;evaluate the following expression
	mov   r5,v0
	call 	ENDCHK		;must find end of line
	mov   a0,r5
	call 	FNDLN		; find the target line
	bne		v0,x0,RUNTSL; go do it
	ldi		a0,#msgBadGotoGosub
	jmp		ERROR		; no such line no.

_clr:
    call    clearVars
    jmp     FINISH

; Clear the variable area of memory
clearVars:
	sub		$sp,$sp,#8
	sw		r6,[$sp]
	sw		$ra,4[$sp]
  ldi   r6,#100    	; number of word pairs to clear
  lw    v0,VARBGN
.cv1:
  sw		x0,[$v0]		; variable name
  sw		x0,4[$v0]		; and value
  add		v0,v0,#8
  sub		r6,r6,#1
	bgt		r6,x0,.cv1
  lw		r6,[$sp]
  lw		$ra,4[$sp]
  add		$sp,$sp,#8
  ret

;******************************************************************
; ONIRQ <line number>
; ONIRQ sets up an interrupt handler which acts like a specialized
; subroutine call. ONIRQ is coded like a GOTO that never executes.
;******************************************************************
;
ONIRQ:
	call	OREXPR		;evaluate the following expression
	mov   r5,v0
	call 	ENDCHK		;must find end of line
	mov   a0,r5
	call 	FNDLN		; find the target line
	bne		v0,r0,ONIRQ1
	sw		x0,IRQROUT
	jmp		FINISH
ONIRQ1:
	sw		$t3,IRQROUT
	jmp		FINISH

WAITIRQ:
	call	CHKIO		; see if a control-C was pressed
	lw		$t1,IRQFlag
	beq		$t1,x0,WAITIRQ
	jmp		FINISH


;******************************************************************
; LIST
;
; LISTX has two forms:
; 'LIST<CR>' lists all saved lines
; 'LIST #<CR>' starts listing at the line #
; Control-S pauses the listing, control-C stops it.
;******************************************************************
;
LISTX:
	call		TSTNUM		; see if there's a line no.
	mov      r5,v0
	call		ENDCHK		; if not, we get a zero
	mov      a0,r5
	call		FNDLN		; find this or next line
LS1:
	bne		v0,r0,LS4
LS5:
	lw		$t1,TXTUNF
	bgeu	$t3,$t1,WSTART	; warm start if we passed the end
LS4:
	mov		a0,$t3
	call	PRTLN		; print the line
	mov		$t3,$v0		; set pointer for next
	call	CHKIO		; check for listing halt request
	beq		v0,x0,LS3
	ldi		$t1,#CTRLS
	bne		v0,$t1,LS3; pause the listing?
LS2:
	call 	CHKIO		; if so, wait for another keypress
	beq		v0,r0,LS2
LS3:
;	mov		$v0,$x0
	bra		LS5
;	mov		a0,r0
;	call	FNDSKP	;FNDLNP		; find the next line
;	bra		LS1


;******************************************************************
; PRINT command is 'PRINT ....:' or 'PRINT ....<CR>'
; where '....' is a list of expressions, formats, back-arrows,
; and strings.	These items a separated by commas.
;
; A format is a pound sign followed by a number.  It controls
; the number of spaces the value of an expression is going to
; be printed in.  It stays effective for the rest of the print
; command unless changed by another format.  If no format is
; specified, 11 positions will be used.
;
; A string is quoted in a pair of single- or double-quotes.
;
; An underline (back-arrow) means generate a <CR> without a <LF>
;
; A <CR LF> is generated after the entire list has been printed
; or if the list is empty.  If the list ends with a semicolon,
; however, no <CR LF> is generated.
;******************************************************************
;
PRINT:
	ldi		r5,#11		; D4 = number of print spaces
	call	TSTC		; if null list and ":"
	dw		':'
	bra		PR2
	call	CRLF		; give CR-LF and continue
	jmp		RUNSML		;		execution on the same line
PR2:
	call	TSTC		;if null list and <CR>
	dw		CR
	bra		PR0
	call	CRLF		;also give CR-LF and
	jmp		RUNNXL		;execute the next line
PR0:
	call	TSTC		;else is it a format?
	dw		'#'
	bra		PR1
	call	OREXPR		; yes, evaluate expression
	mov		r5,v0	; and save it as print width
	bra		PR3		; look for more to print
PR1:
	call	TSTC	;	is character expression? (MRL)
	dw		'$'
	bra		PR4
	call	OREXPR	;	yep. Evaluate expression (MRL)
	call	GOOUT	;	print low byte (MRL)
	bra		PR3		;look for more. (MRL)
PR4:
	call	QTSTG	;	is it a string?
	; the following branch must occupy only 1 word!
	bra		PR8		;	if not, must be an expression
PR3:
	call		TSTC	;	if ",", go find next
	dw		','
	bra		PR6
	call		FIN		;in the list.
	bra		PR0
PR6:
	call		CRLF		;list ends here
	jmp		FINISH
PR8:
	call	OREXPR		; evaluate the expression
	mov		a0,v0
	ldi		a1,#5		; set the width
	ldi		a2,#10
	call	PRTNUM		; print its value
	bra		PR3			; more to print?


FINISH:
	call	FIN		; Check end of command
	jmp		QWHAT	; print "What?" if wrong


;*******************************************************************
;
; *** GOSUB *** & RETURN ***
;
; 'GOSUB expr:' or 'GOSUB expr<CR>' is like the 'GOTO' command,
; except that the current text pointer, stack pointer, etc. are
; saved so that execution can be continued after the subroutine
; 'RETURN's.  In order that 'GOSUB' can be nested (and even
; recursive), the save area must be stacked.  The stack pointer
; is saved in 'STKGOS'.  The old 'STKGOS' is saved on the stack.
; If we are in the main routine, 'STKGOS' is zero (this was done
; in the initialization section of the interpreter), but we still
; save it as a flag for no further 'RETURN's.
;******************************************************************
;
GOSUB:
	call	PUSHA_		; save the current 'FOR' parameters
	call	OREXPR		; get line number
	mov		$a0,$v0
	call	FNDLN		; find the target line
	bne		v0,r0,gosub1
	ldi		a0,#msgBadGotoGosub
	jmp		ERROR		; if not there, say "How?"
gosub1:
	sub		$sp,$sp,#12
	lw		a0,STKGOS	; 'STKGOS'
	sw		a0,[$sp]
	lw		a0,CURRNT	; found it, save old 'CURRNT'...
	sw		a0,4[$sp]
	sw		$t2,8[$sp]
	sw		$x0,LOPVAR		; load new values
	sw		$sp,STKGOS
	jmp		RUNTSL


;******************************************************************
; 'RETURN<CR>' undoes everything that 'GOSUB' did, and thus
; returns the execution to the command after the most recent
; 'GOSUB'.  If 'STKGOS' is zero, it indicates that we never had
; a 'GOSUB' and is thus an error.
;******************************************************************
;
RETURN:
	call	ENDCHK		; there should be just a <CR>
	lw		a1,STKGOS		; get old stack pointer
	bne		a1,x0,return1
	ldi		a0,#msgRetWoGosub
	jmp		ERROR		; if zero, it doesn't exist
return1:
	mov		$sp,a1		; else restore it
	lw		a0,[$sp]
	add		$sp,$sp,#4
	sw		a0,STKGOS	; and the old 'STKGOS'
	lw		a0,[$sp]
	add		$sp,$sp,#4
	sw		a0,CURRNT	; and the old 'CURRNT'
	lw		$t2,[$sp]	; and the old text pointer
	add		$sp,$sp,#4
	call	POPA_		;and the old 'FOR' parameters
	jmp		FINISH		;and we are back home

;******************************************************************
; *** FOR *** & NEXT ***
;
; 'FOR' has two forms:
; 'FOR var=exp1 TO exp2 STEP exp1' and 'FOR var=exp1 TO exp2'
; The second form means the same thing as the first form with a
; STEP of positive 1.  The interpreter will find the variable 'var'
; and set its value to the current value of 'exp1'.  It also
; evaluates 'exp2' and 'exp1' and saves all these together with
; the text pointer, etc. in the 'FOR' save area, which consists of
; 'LOPVAR', 'LOPINC', 'LOPLMT', 'LOPLN', and 'LOPPT'.  If there is
; already something in the save area (indicated by a non-zero
; 'LOPVAR'), then the old save area is saved on the stack before
; the new values are stored.  The interpreter will then dig in the
; stack and find out if this same variable was used in another
; currently active 'FOR' loop.  If that is the case, then the old
; 'FOR' loop is deactivated. (i.e. purged from the stack)
;******************************************************************
;
FOR:
	call	PUSHA_		; save the old 'FOR' save area
	call	SETVAL		; set the control variable
	sw		v0,LOPVAR		; save its address
	ldi		$t3,#TAB5
	ldi		$t4,#TAB5_1	; use 'EXEC' to test for 'TO'
	jmp		EXEC
FR1:
	call	OREXPR		; evaluate the limit
	sw		v0,LOPLMT	; save that
	ldi		$t3,#TAB6
	ldi		$t4,#TAB6_1	; use 'EXEC' to test for the word 'STEP
	jmp		EXEC
FR2:
	call	OREXPR		; found it, get the step value
	bra		FR4
FR3:
	ldi		v0,#1		; not found, step defaults to 1
FR4:
	sw		v0,LOPINC	; save that too
FR5:
	lw		a1,CURRNT
	sw		a1,LOPLN	; save address of current line number
	sw		$t2,LOPPT	; and text pointer
	mov		r3,$sp		; dig into the stack to find 'LOPVAR'
	lw		r6,LOPVAR
	bra		FR7
FR6:
	add		r3,r3,#20	; look at next stack frame
FR7:
	lw		a1,[r3]		; is it zero?
	beq		a1,x0,FR8	; if so, we're done
	bne		a1,r6,FR6	; same as current LOPVAR? nope, look some more

  mov		a0,r3	   ; Else remove 5 words from...
	mov		a1,$sp
	add		a2,r3,#20  ; inside the stack.
	call	MVDOWN
	add		$sp,$sp,#20	; set the SP 5 long words up
;	lw		a0,[$sp]		; ???
;	add		$sp,$sp,#4
FR8:
  jmp	    FINISH		; and continue execution


;******************************************************************
; 'NEXT var' serves as the logical (not necessarily physical) end
; of the 'FOR' loop.  The control variable 'var' is checked with
; the 'LOPVAR'.  If they are not the same, the interpreter digs in
; the stack to find the right one and purges all those that didn't
; match.  Either way, it then adds the 'STEP' to that variable and
; checks the result with against the limit value.  If it is within
; the limit, control loops back to the command following the
; 'FOR'.  If it's outside the limit, the save area is purged and
; execution continues.
;******************************************************************
;
NEXT:
	mov		a0,x0		; don't allocate it
	call	TSTV		; get address of variable
	bne		v0,x0,NX4
	ldi		a0,#msgNextVar
	bra		ERROR		; if no variable, say "What?"
NX4:
	mov		$t3,v0	; save variable's address
NX0:
	lw		a0,LOPVAR	; If 'LOPVAR' is zero, we never...
	bne		a0,x0,NX5	; had a FOR loop
	ldi		a0,#msgNextFor
	bra		ERROR
NX5:
	beq		a0,$t3,NX2	; else we check them OK, they agree
	call	POPA_		; nope, let's see the next frame
	bra		NX0
NX2:
	lw		a0,[$t3]		; get control variable's value
	lw		a1,LOPINC
	add		a0,a0,a1	; add in loop increment
;	BVS.L	QHOW		say "How?" for 32-bit overflow
	sw		a0,[$t3]		; save control variable's new value
	lw		r3,LOPLMT	; get loop's limit value
	bge		a1,x0,NX1	; check loop increment, branch if loop increment is positive
	blt		a0,r3,NXPurge	; test against limit
	bra     NX3
NX1:
	bgt		a0,r3,NXPurge
NX3:
	lw		$t2,LOPLN	; Within limit, go back to the...
	sw		$t2,CURRNT
	lw		$t2,LOPPT	; saved 'CURRNT' and text pointer.
	jmp		FINISH
NXPurge:
  call    POPA_        ; purge this loop
  jmp     FINISH


;******************************************************************
; *** REM *** IF *** INPUT *** LET (& DEFLT) ***
;
; 'REM' can be followed by anything and is ignored by the
; interpreter.
;
;REM
;    br	    IF2		    ; skip the rest of the line
; 'IF' is followed by an expression, as a condition and one or
; more commands (including other 'IF's) separated by colons.
; Note that the word 'THEN' is not used.  The interpreter evaluates
; the expression.  If it is non-zero, execution continues.  If it
; is zero, the commands that follow are ignored and execution
; continues on the next line.
;******************************************************************
;
IF0:
  call	OREXPR		; evaluate the expression
IF1:
  beq	  v0,x0,IF2	; is it zero? if not, continue
  jmp		RUNSML
IF2:
  mov		$t3,$t2	; set lookup pointer
	mov		a0,x0		; find line #0 (impossible)
	call	FNDSKP		; if so, skip the rest of the line
	bne		v0,x0,IF3; if no next line, do a warm start
	jmp		WSTART
IF3:
	jmp		RUNTSL		; run the next line


;******************************************************************
; INPUT is called first and establishes a stack frame
INPERR:
	lw		$sp,STKINP		; restore the old stack pointer
	lw		a0,[$sp]
	add		$sp,$sp,#4
	sw		a0,CURRNT		; and old 'CURRNT'
	lw		$t2,[$sp]		; and old text pointer
	add		$sp,$sp,#4
	add		$sp,$sp,#20	; fall through will subtract 20

; 'INPUT' is like the 'PRINT' command, and is followed by a list
; of items.  If the item is a string in single or double quotes,
; or is an underline (back arrow), it has the same effect as in
; 'PRINT'.  If an item is a variable, this variable name is
; printed out followed by a colon, then the interpreter waits for
; an expression to be typed in.  The variable is then set to the
; value of this expression.  If the variable is preceeded by a
; string (again in single or double quotes), the string will be
; displayed followed by a colon.  The interpreter the waits for an
; expression to be entered and sets the variable equal to the
; expression's value.  If the input expression is invalid, the
; interpreter will print "What?", "How?", or "Sorry" and reprint
; the prompt and redo the input.  The execution will not terminate
; unless you press control-C.  This is handled in 'INPERR'.
;
INPUT:
	sub		$sp,$sp,#20	; allocate five words on stack
	sw		r5,16[$sp]	; save off r5 into stack var
IP6:
	sw		$t2,[$sp]	; save in case of error
	call	QTSTG		; is next item a string?
	bra		IP2			; nope - this branch must take only 1 word
	ldi		a0,#1		; allocate var
	call	TSTV		; yes, but is it followed by a variable?
	beq    a0,r0,IP4   ; if not, brnch
	mov		$t4,a0		; put away the variable's address
	bra		IP3			; if so, input to variable
IP2:
	sw		$t2,4[$sp]	; save off in stack var for 'PRTSTG'
	ldi		a0,#1
	call	TSTV		; must be a variable now
	bne		a0,r0,IP7
	ldi		a0,#msgInputVar
	add		$sp,$sp,#20	; cleanup stack
	bra		ERROR		; "What?" it isn't?
IP7:
	mov		$t4,a0		; put away the variable's address
	lbu		r5,[$t2]		; get ready for 'PRTSTG' by null terminating
	sb		x0,[$t2]
	mov		a1,x0
	lw		a0,4[$sp]	; get back text pointer
	call	PRTSTG		; print string as prompt
	sb		r5,[$t2]		; un-null terminate
IP3
	sw		$t2,4[$sp]	; save in case of error
	lw		a0,CURRNT
	sw		a0,8[$sp]	; also save 'CURRNT'
	ldi		a0,#-1
	sw		a0,CURRNT	; flag that we are in INPUT
	sw		$sp,STKINP	; save the stack pointer too
	sw		$t4,12[$sp]	; save the variable address
	ldi		a0,#':'		; print a colon first
	call	GETLN		; then get an input line
	ldi		$t2,#BUFFER	; point to the buffer
	call	OREXPR		; evaluate the input
	lw		$t4,12[$sp]	; restore the variable address
	sw		a0,[$t4]	; save value in variable
	lw		a0,8[$sp]	; restore old 'CURRNT'
	sw		a0,CURRNT
	lw		$t2,4[$sp]	; and the old text pointer
IP4:
	call	TSTC
	dw		','
	bra		IP5
	bra		IP6			; yes, more items
IP5:
	lw		r5,16[$sp]
	add		$sp,$sp,#20	; cleanup stack
 	jmp		FINISH


DEFLT:
  lbu    	a0,[$t2]
  ldi			$t1,#CR
	beq	    a0,$t1,FINISH	    ; empty line is OK else it is 'LET'


;******************************************************************
; 'LET' is followed by a list of items separated by commas.
; Each item consists of a variable, an equals sign, and an
; expression.  The interpreter evaluates the expression and sets
; the variable to that value.  The interpreter will also handle
; 'LET' commands without the word 'LET'.  This is done by 'DEFLT'.
;******************************************************************
;
LET:
  call	SETVAL		; do the assignment
	call	TSTC		; check for more 'LET' items
	dw		','
	jmp		FINISH
	bra	    LET
LT1:
  jmp	    FINISH		; until we are finished.


;******************************************************************
; *** LOAD *** & SAVE ***
;
; These two commands transfer a program to/from an auxiliary
; device such as a cassette, another computer, etc.  The program
; is converted to an easily-stored format: each line starts with
; a colon, the line no. as 4 hex digits, and the rest of the line.
; At the end, a line starting with an '@' sign is sent.  This
; format can be read back with a minimum of processing time by
; the RTF65002
;******************************************************************
;
LOAD
	ldi		$t2,#TXTBGN	; set pointer to start of prog. area
	ldi		a0,#CR		; For a CP/M host, tell it we're ready...
	call	GOAUXO		; by sending a CR to finish PIP command.
LOD1:
	call	GOAUXI		; look for start of line
	ble		a0,r0,LOD1
	ldi		$t1,#'@'
	beq		a0,$t1,LODEND	; end of program?
	ldi		$t1,#$1A
	beq		a0,$t1,LODEND	; or EOF marker
	ldi		$t1,#':'
	bne		a0,$t1,LOD1	; if not, is it start of line? if not, wait for it
	call	GCHAR		; get line number
	sw		a0,[$t2]		; store it
	add		$t2,$t2,#4
LOD2:
	call	GOAUXI		; get another text char.
	ble		a0,r0,LOD2
	sb		a0,[$t2]		; store it
	add		$t2,$t2,#1
	ldi		$t1,#CR
	bne		a0,$t1,LOD2		; is it the end of the line? if not, go back for more
	bra		LOD1		; if so, start a new line
LODEND:
	sw		$t2,TXTUNF	; set end-of program pointer
	jmp		WSTART		; back to direct mode


; get character from input (32 bit value)
GCHAR:
	sub		$sp,$sp,#12
	sw		r5,[$sp]
	sw		r6,4[$sp]
	sw		$ra,8[$sp]
	ldi		r6,#8       ; repeat ten times
	ldi		r5,#0
GCHAR1:
	call	GOAUXI		; get a char
	ble		a0,r0,GCHAR1
	call	asciiToHex
	sll		r5,r5,#4
	or		r5,r5,a0
	sub		r6,r6,#1
	bgtu	r6,r0,GCHAR1
	mov		a0,r5
	lw		r5,[$sp]
	lw		r6,4[$sp]
	lw		$ra,8[$sp]
	add		$sp,$sp,#12
	ret

; convert an ascii char to hex code
; input
;	a0 = char to convert

asciiToHex:
	ldi		$t1,#'9'
	bleu	a0,$t1,a2h1; less than '9'
	sub		a0,a0,#7	; shift 'A' to '9'+1
a2h1:
	sub		a0,a0,#'0'
	and		a0,a0,#15	; make sure a nybble
	ret

GetFilename:
	sub		$sp,$sp,#4
	sw		$ra,[$sp]
	call	TSTC
	dw		'"'
	bra		gfn1
	mov		r3,r0
gfn2:
	lbu		a0,[$t2]		; get text character
	add		$t2,$t2,#1
	ldi		$t1,#'"'
	beq		a0,$t1,gfn3
	beq		a0,r0,gfn3
	sb		a0,FILENAME[r3]
	add		r3,r3,#1
	ldi		$t1,#64
	bltu	r3,$t1,gfn2
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret
gfn3:
	ldi		a0,#' '
	sb		a0,FILENAME[r3]
	add		r3,r3,#1
	ldi		$t1,#64
	bltu	r3,$t1,gfn3
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret
gfn1:
	jmp		WSTART

LOAD3:
	call	GetFilename
	call	AUXIN_INIT
	jmp		LOAD

;	call		OREXPR		;evaluate the following expression
;	ld		a0,#5000
	ld		a1,#$E00
	call	SDReadSector
	add		a0,a0,#1
	ldi		a1,#TXTBGN
LOAD4:
	sub		$sp,$sp,#4
	sw		a0,[$sp]
	call	SDReadSector
	add		a1,a1,#512
	lw		a0,[$sp]
	add		$sp,$sp,#4
	add		a0,a0,#1
	ldi		r4,#TXTBGN
	add		r4,r4,#65536
	blt		a1,r4,LOAD4
LOAD5:
	bra		WSTART


SAVE3:
	call	GetFilename
	call	AUXOUT_INIT
	jmp		SAVE

	call	OREXPR		;evaluate the following expression
;	lda		#5000		; starting sector
	ldi		a1,#$E00	; starting address to write
	call	SDWriteSector
	add		a0,a0,#1
	ldi		a1,#TXTBGN
SAVE4:
	sub		$sp,$sp,#4
	sw		a0,[$sp]
	call	SDWriteSector
	add		a1,a1,#512
	lw		a0,[$sp]
	add		$sp,$sp,#4
	add		a0,a0,#1
	ldi		r4,#TXTBGN
	add		r4,r4,#65536
	blt		a1,r4,SAVE4
	bra		WSTART

SAVE:
	ldi		$t2,#TXTBGN	;set pointer to start of prog. area
	lw		$t3,TXTUNF	;set pointer to end of prog. area
SAVE1:
	call	AUXOCRLF    ; send out a CR & LF (CP/M likes this)
	bgt		$t2,$t3,SAVEND; are we finished?
	ldi		a0,#':'		; if not, start a line
	call	GOAUXO
	lw		a0,[$t2]		; get line number
	add		$t2,$t2,#4
	call	PWORD       ; output line number as 5-digit hex
SAVE2:
	lbu		a0,[$t2]		; get a text char.
	add		$t2,$t2,#1
	ldi		$t1,#CR
	beq		a0,$t1,SAVE1	; is it the end of the line? if so, send CR & LF and start new line
	call	GOAUXO		; send it out
	bra		SAVE2		; go back for more text
SAVEND:
	ldi		a0,#'@'		; send end-of-program indicator
	call	GOAUXO
	call	AUXOCRLF    ; followed by a CR & LF
	ldi		a0,#$1A		; and a control-Z to end the CP/M file
	call	GOAUXO
	call	AUXOUT_FLUSH
	bra		WSTART		; then go do a warm start

; output a CR LF sequence to auxillary output
; Registers Affected
;   r3 = LF
AUXOCRLF:
	sub		$sp,$sp,#4
	sw		$ra,[$sp]
  ldi		a0,#CR
  call	GOAUXO
  ldi		a0,#LINEFD
  call	GOAUXO
  lw		$ra,[$sp]
  add		$sp,$sp,#4
  ret


; output a word in hex format
; tricky because of the need to reverse the order of the chars
PWORD:
	sub		$sp,$sp,#8
	sw		r5,[$sp]
	sw		$ra,4[$sp]
	ldi		r5,#NUMWKA+14
	mov		r4,a0		; r4 = value
pword1:
  mov   a0,r4	    ; a0 = value
  srl		r4,r4,#4	; shift over to next nybble
  call	toAsciiHex  ; convert LS nybble to ascii hex
  sb    a0,[r5]		; save in work area
  sub		r5,r5,#1
  ldi		$t1,#NUMWKA
	bge		r5,$t1,pword1
pword2:
  add		r5,r5,#1
  lbu   a0,[r5]     ; get char to output
	call	GOAUXO		; send it
	ldi		$t1,#NUMWKA+14
	blt		r5,$t1,pword2
	lw		r5,[$sp]
	lw		$ra,4[$sp]
	add		$sp,$sp,#8
	ret

; convert nybble in a1 to ascii hex chaa1
; a1 = character to convert

toAsciiHex:
	and		a0,a0,#15	; make sure it's a nybble
	ldi		$t1,#10
	blt		a0,$t1,tah1	; > 10 ?
	add		a0,a0,#7	; bump it up to the letter 'A'
tah1:
	add		a0,a0,#'0'	; bump up to ascii '0'
	ret


;******************************************************************
; *** POKE ***
;
; 'POKE expr1,expa1' stores the byte from 'expa1' into the memory
; address specified by 'expr1'.
; 'POKEW expr1,expa1' stores the word from 'expa1' into the memory
; address specified by 'expr1'.
; 'POKEH expr1,expa1' stores the half-word from 'expa1' into the memory
; address specified by 'expr1'.
;******************************************************************
;
POKE:
	call	OREXPR		; get the memory address
	call	TSTC		; it must be followed by a comma
	dw		','
	bra		PKER
	sub		$sp,$sp,#4
	sw		a0,[$sp]	; save the address
	call	OREXPR		; get the byte to be POKE'd
	lw		a1,[$sp]	; get the address back
	add		$sp,$sp,#4
	sb		a0,[a1]		; store the byte in memory
	jmp		FINISH

POKEW:
	call	OREXPR		; get the memory address
	call	TSTC		; it must be followed by a comma
	dw		','
	bra		PKER
	sub		$sp,$sp,#4
	sw		a0,[$sp]	; save the address
	call	OREXPR		; get the byte to be POKE'd
	lw		a1,[$sp]	; get the address back
	add		$sp,$sp,#4
	sw		a0,[a1]		; store the byte in memory
	jmp		FINISH

POKEH:
	call	OREXPR		; get the memory address
	call	TSTC		; it must be followed by a comma
	dw		','
	bra		PKER
	sub		$sp,$sp,#4
	sw		a0,[$sp]	; save the address
	call	OREXPR		; get the byte to be POKE'd
	lw		a1,[$sp]	; get the address back
	add		$sp,$sp,#4
	sh		a0,[a1]		; store the byte in memory
	jmp		FINISH

PKER:
	ldi		a0,#msgComma
	jmp		ERROR		; if no comma, say "What?"

;******************************************************************
; 'SYSX expr' jumps to the machine language subroutine whose
; starting address is specified by 'expr'.  The subroutine can use
; all registers but must leave the stack the way it found it.
; The subroutine returns to the interpreter by executing an RTS.
;******************************************************************

SYSX:
	call	OREXPR		; get the subroutine's address
	bne		v0,r0,sysx1; make sure we got a valid address
	ld		a0,#msgSYSBad
	jmp		ERROR
sysx1:
	sub		$sp,$sp,#4
	sw		$t2,[$sp]	; save the text pointer
	call	[v0]			; jump to the subroutine
	lw		$t2,[$sp]	; restore the text pointer
	add		$sp,$sp,#4
	jmp		FINISH

;******************************************************************
; *** EXPR ***
;
; 'EXPR' evaluates arithmetical or logical expressions.
; <OREXPR>::= <ANDEXPR> OR <ANDEXPR> ...
; <ANDEXPR>::=<EXPR> AND <EXPR> ...
; <EXPR>::=<ADDEXPR>
;	   <ADDEXPR><rel.op.><ADDEXPR>
; where <rel.op.> is one of the operators in TAB8 and the result
; of these operations is 1 if true and 0 if false.
; <ADDEXPR>::=(+ or -)<MULEXPR>(+ or -)<MULEXPR>(...
; where () are optional and (... are optional repeats.
; <MULEXPR>::=<FUNCEXPR>( <* or /><FUNCEXPR> )(...
; <FUNCEXPR>::=<variable>
;	    <function>
;	    (<EXPR>)
; <EXPR> is recursive so that the variable '@' can have an <EXPR>
; as an index, functions can have an <EXPR> as arguments, and
; <FUNCEXPR> can be an <EXPR> in parenthesis.
;

; <OREXPR>::=<ANDEXPR> OR <ANDEXPR> ...
;
OREXPR:
	sub		$sp,$sp,#12
	sw		$ra,[$sp]
	sw		r3,4[$sp]
	sw		r4,8[$sp]
	call	ANDEXPR		; get first <ANDEXPR>
XP_OR1:
	sub		$sp,$sp,#8
	sw		$v0,[$sp]		; save <ANDEXPR> value
	sw		$v1,4[$sp]	; save type
	ldi		$t3,#TAB10	; look up a logical operator
	ldi		$t4,#TAB10_1
	jmp		EXEC		; go do it
XP_OR:
  call	ANDEXPR
  lw		$a0,[$sp]
  add		$sp,$sp,#8
  or    v0,v0,a0
  bra   XP_OR1
XP_ORX:
  lw		$v0,[$sp]
  lw		$v1,4[$sp]
  add		$sp,$sp,#8
	lw		$ra,[$sp]
	lw		r3,4[$sp]
	lw		r4,8[$sp]
	add		$sp,$sp,#12
  ret


; <ANDEXPR>::=<EXPR> AND <EXPR> ...
;
ANDEXPR:
	sub		$sp,$sp,#4
	sw		$ra,[$sp]
	call	EXPR		; get first <EXPR>
XP_AND1:
	sub		$sp,$sp,#8
	sw		$v0,[$sp]		; save <EXPR> value
	sw		$v1,4[$sp]	; save type
	ldi		$t3,#TAB9		; look up a logical operator
	ldi		$t4,#TAB9_1
	jmp		EXEC		; go do it
XP_AND:
  call	EXPR
  lw		$a0,[$sp]
  add		$sp,$sp,#8
  and   v0,v0,a0
  bra   XP_AND1
XP_ANDX:
  lw		$v0,[$sp]
  lw		$v1,4[$sp]
  add		$sp,$sp,#8
	lw		$ra,[$sp]
	add		$sp,$sp,#4
  ret


; Determine if the character is a digit
;   Parameters
;       a0 = char to test
;   Returns
;       a0 = 1 if digit, otherwise 0
;
isDigit:
	ldi		$t1,#'0'
	blt		a0,$t1,isDigitFalse
	ldi		$t1,#'9'
	bgt		a0,$t1,isDigitFalse
	ldi		v0,#1
  ret
isDigitFalse:
  mov		v0,r0
  ret


; Determine if the character is a alphabetic
;   Parameters
;       a0 = char to test
;   Returns
;       a0 = 1 if alpha, otherwise 0
;
isAlpha:
	ldi		$t1,#'A'
	blt		a0,$t1,isAlphaFalse
	ldi		$t1,#'Z'
	ble		a0,$t1,isAlphaTrue
	ldi		$t1,#'a'
	blt		a0,$t1,isAlphaFalse
	ldi		$t1,#'z'
	bgt		a0,$t1,isAlphaFalse
isAlphaTrue:
  ldi		v0,#1
  ret
isAlphaFalse:
  mov		v0,r0
  ret


; Determine if the character is a alphanumeric
;   Parameters
;       a0 = char to test
;   Returns
;       a0 = 1 if alpha, otherwise 0
;
isAlnum:
	sub		$sp,$sp,#4
	sw		$ra,[$sp]
  call	isDigit
	bne		v0,r0,isDigitx	; if it is a digit
  call  isAlpha
isDigitx:
	lw		$ra,[$sp]
	add		$sp,$sp,#4
  ret

FORCEFIT:
	beq		a1,v1,.0001				; types match
	ldi		$t0,#0
	beq		a1,$t0,.intAnd
;	itof	$f1,$v0
	ldi		a0,#1
	ret
.intAnd:
	ldi		$t0,#1
	bne		$v1,$t0,.0001
;	itof	$f2,$a1
	ldi		$a1,#1
	ret
.0001:
	ret

EXPR:
	sub		$sp,$sp,#4
	sw		$ra,[$sp]
	call	ADDEXPR
	sub		$sp,$sp,#8				; save <ADDEXPR> value
	sw		v0,[$sp]
	sw		v1,4[$sp]					; save type
	ldi		$t3,#TAB8		; look up a relational operator
	ldi		$t4,#TAB8_1
	jmp		EXEC		; go do it
XP11:
	lw		a0,[$sp]
	lw		a1,4[$sp]
	add		$sp,$sp,#8
	call	XP18	; is it ">="?
	bge		a0,v0,XPRT1	; no, return v0=1
	bra		XPRT0	; else return v0=0
XP12:
	lw		a0,[$sp]
	lw		a1,4[$sp]
	add		$sp,$sp,#8
	call	XP18	; is it "<>"?
	bne		a0,v0,XPRT1	; no, return a1=1
	bra		XPRT0	; else return a1=0
XP13:
	lw		a0,[$sp]
	lw		a1,4[$sp]
	add		$sp,$sp,#8
	call	XP18	; is it ">"?
	bgt		a0,v0,XPRT1	; no, return a1=1
	bra		XPRT0	; else return a1=0
XP14:
	lw		a0,[$sp]
	lw		a1,4[$sp]
	add		$sp,$sp,#8
	call	XP18	; is it "<="?
	ble		a0,v0,XPRT1	; no, return a1=1
	bra		XPRT0	; else return a1=0
XP15:
	lw		a0,[$sp]
	lw		a1,4[$sp]
	add		$sp,$sp,#8
	call	XP18	; is it "="?
	beq		a0,v0,XPRT1	; if not, return a1=1
	bra		XPRT0	; else return a1=0
XP16:
	lw		a0,[$sp]
	lw		a1,4[$sp]
	add		$sp,$sp,#8
	call	XP18	; is it "<"?
	blt		a0,v0,XPRT1	; if not, return a1=1
	bra		XPRT0	; else return a1=0
XPRT0:
	mov		v0,x0   ; return a0=0 (false)
	mov		v1,x0		; type = int
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret
XPRT1:
	ldi		v0,#1	; return a0=1 (true)
	ldi		v1,#0	; type = int
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret

XP17:				; it's not a rel. operator
	lw		v0,[$sp]; return a1=<ADDEXPR>
	lw		v1,4[$sp]
	add		$sp,$sp,#8
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret

XP18:
	sub		$sp,$sp,#12
	sw		$ra,[$sp]
	sw		v0,4[$sp]
	sw		v1,8[$sp]
	call	ADDEXPR		; do a second <ADDEXPR>
	lw		a0,4[$sp]
	lw		a1,8[$sp]
	lw		$ra,[$sp]
	add		$sp,$sp,#12
	ret

; <ADDEXPR>::=(+ or -)<MULEXPR>(+ or -)<MULEXPR>(...
//message "ADDEXPR"
ADDEXPR:
	sub		$sp,$sp,#4
	sw		$ra,[$sp]
	call	TSTC		; negative sign?
	dw		'-'
	bra		XP21
	mov		v0,r0		; yes, fake '0-'
	sub		$sp,$sp,#8
	sw		v0,[$sp]
	sw		v1,4[$sp]
	bra		XP26
XP21:
	call	TSTC		; positive sign? ignore it
	dw		'+'
	bra		XP22
XP22:
	call	MULEXPR		; first <MULEXPR>
XP23:
	sub		$sp,$sp,#8; yes, save the value
	sw		v0,[$sp]
	sw		v1,4[$sp]	; and type
	call	TSTC		; add?
	dw		'+'
	bra		XP25
	call	MULEXPR		; get the second <MULEXPR>
XP24:
	lw		a0,[$sp]
	lw		a1,4[$sp]
	add		$sp,$sp,#8
	add		v0,v0,a0	; add it to the first <MULEXPR>
;	BVS.L	QHOW		brnch if there's an overflow
	bra		XP23		; else go back for more operations
XP25:
	call	TSTC		; subtract?
	dw		'-'
	bra		XP45
XP26:
	call	MULEXPR		; get second <MULEXPR>
	sub		v0,r0,v0	; change its sign
	bra		XP24		; and do an addition
XP45:
	lw		v0,[$sp]
	lw		v1,4[$sp]
	add		$sp,$sp,#8
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret


; <MULEXPR>::=<FUNCEXPR>( <* or /><FUNCEXPR> )(...

MULEXPR:
	sub		$sp,$sp,#4
	sw		$ra,[$sp]
	call	FUNCEXPR		; get first <FUNCEXPR>
XP31:
	sub		$sp,$sp,#8
	sw		v0,[$sp]; yes, save that first result
	sw		v1,4[$sp]
	call	TSTC		; multiply?
	dw		'*'
	bra		XP34
	call	FUNCEXPR		; get second <FUNCEXPR>
	lw		a0,[$sp]
	lw		a1,4[$sp]
	add		$sp,$sp,#8
	mul		v0,v0,a0	; multiply the two
	bra		XP31        ; then look for more terms
XP34:
	call	TSTC		; divide?
	dw		'/'
	bra		XP35
	call	FUNCEXPR		; get second <FUNCEXPR>
	lw		a0,[$sp]
	lw		a1,4[$sp]
	add		$sp,$sp,#8
	div		v0,v0,a0	; do the division
	bra		XP31		; go back for any more terms
XP35:
	call	TSTC
	dw		'%'
	bra		XP47
	call	FUNCEXPR
	lw		a0,[$sp]
	lw		a1,4[$sp]
	add		$sp,$sp,#8
	rem		v0,v0,a0
	bra		XP31
XP47:
	lw		v0,[$sp]
	lw		v1,4[$sp]
	add		$sp,$sp,#8
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret


; Functions are called through FUNCEXPR
; <FUNCEXPR>::=<variable>
;	    <function>
;	    (<EXPR>)

FUNCEXPR:
	sub		$sp,$sp,#4
	sw		$ra,[$sp]
  ldi		$t3,#TAB4		; find possible function
  ldi		$t4,#TAB4_1
	jmp		EXEC        ; branch to function which does subsequent ret for FUNCEXPR
XP40:                   ; we get here if it wasn't a function
	mov		a0,x0
	call	TSTV
	beq   v0,x0,XP41	; not a variable
	lw		$v0,[$v0]		; if a variable, return its value in v0
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret
XP41:
	call	TSTNUM		; or is it a number?
	bne		v1,x0,XP46	; (if not, # of digits will be zero) if so, return it in v0
	call	PARN        ; check for (EXPR)
XP46:
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret


; Check for a parenthesized expression
PARN:
	sub		$sp,$sp,#4
	sw		$ra,[$sp]	
	call	TSTC		; else look for ( OREXPR )
	dw		'('
	bra		XP43
	call	OREXPR
	call	TSTC
	dw		')'
	bra		XP43
XP42:
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret
XP43:
	add		$sp,$sp,#4		; get rid of return address
	ldi		a0,#msgWhat
	jmp		ERROR


; ===== Test for a valid variable name.  Returns Z=1 if not
;	found, else returns Z=0 and the address of the
;	variable in a0.
; Parameters
;		a0 = 1 = allocate if not found
; Returns
;		v0 = address of variable, zero if not found

TSTV:
	sub		$sp,$sp,#8
	sw		r5,[$sp]
	sw		$ra,4[$sp]
	mov		r5,a0		; r5=allocate flag
	call	IGNBLK
	lbu		a0,[$t2]		; look at the program text
	ldi		$t1,#'@'
	blt		a0,$t1,tstv_notfound	; C=1: not a variable
	bne		a0,$t1,TV1				; brnch if not "@" array
	add		$t2,$t2,#1	; If it is, it should be
	call	PARN		; followed by (EXPR) as its index.
;	BCS.L	QHOW		say "How?" if index is too big
	bra		TV3
TV3:
	sub		$sp,$sp,#4	; save the index
	sw		v0,[$sp]
	call	SIZEX		; get amount of free memory
	lw		a1,[$sp]
	add		$sp,$sp,#4	; get back the index
	blt		a1,v0,TV2		; see if there's enough memory
	add		$sp,$sp,#8
	jmp   QSORRY		; if not, say "Sorry"
TV2:
	lw		a0,VARBGN	; put address of array element...
	sub   v0,a0,a1    ; into a0 (neg. offset is used)
	bra   TSTVRT
TV1:	
  call	getVarName      ; get variable name
  beq   v0,x0,TSTVRT    ; if not, return v0=0
  mov		a0,v0
  mov		a1,r5
  call	findVar     ; find or allocate
TSTVRT:
	lw		r5,[$sp]
	lw		$ra,4[$sp]
	add		$sp,$sp,#8
	ret								; v0<>0 (if found)
tstv_notfound:
	lw		r5,[$sp]
	lw		$ra,4[$sp]
	add		$sp,$sp,#8
	mov		v0,x0				; v0=0 if not found
  ret

; Get a variable name. Called after blanks have been ignored.
;
; Returns
;   v0 = 3 character variable name + type
;
getVarName:
	sub		$sp,$sp,#8
	sw		r5,[$sp]
	sw		$ra,4[$sp]
  lbu   a0,[$t2]		; get first character
  sub		$sp,$sp,#4	; save off current name
  sw		a0,[$sp]
  call	isAlpha
  beq   v0,r0,gvn1
  ldi	  r5,#2       ; loop two more times

	; check for second/third character
gvn4:
	add		$t2,$t2,#1
	lbu   a0,[$t2]		; do we have another char ?
	call	isAlnum
	beq   v0,x0,gvn2	; nope
	lw		a0,[$sp]
	add		$sp,$sp,#4	; get varname
	sll		a0,a0,#8
	lbu   a1,[$t2]
	or    a0,a0,a1   ; add in new char
  sub		$sp,$sp,#4	; save off current name again
  sw		a0,[$sp]
  sub		r5,r5,#1
  bgt		r5,x0,gvn4

 	; now ignore extra variable name characters
gvn6:
	add		$t2,$t2,#1
	lbu   a0,[$t2]		; do we have another char ?
  call  isAlnum
  bne   v0,x0,gvn6	; keep looping as long as we have identifier chars

  ; check for a variable type
gvn2:
	lbu   a1,[$t2]
	ldi		$t1,#'%'
	beq		a1,$t1,gvn3
	ldi		$t1,#'$'
	beq		a1,$t1,gvn3
  sub		$t2,$t2,#1
  ldi		$a1,#'.'		; if no variable type assume float

  ; insert variable type indicator and return
gvn3:
	add		$t2,$t2,#1
	lw		a0,[$sp]
	add		$sp,$sp,#4	; get varname
	sll		a0,a0,#8
  or    v0,a0,a1    ; add in variable type
  lw		r5,[$sp]
  lw		$ra,4[$sp]
  add		$sp,$sp,#8
  ret								; return a0 = varname

  ; not a variable name
gvn1:
	add		$sp,$sp,#4	; pop a0 (varname)
	lw		r5,[$sp]
  lw		$ra,4[$sp]
	add		$sp,$sp,#8
  mov		v0,x0       ; return v0 = 0 if not a varname
  ret


; Find variable
;   a0 = varname
;		a1 = allocate flag
; Returns
;   v0 = variable address, Z =0 if found / allocated, Z=1 if not found

findVar:
	sub		$sp,$sp,#8
	sw		x7,[$sp]
	sw		x3,4[$sp]
  lw    x3,VARBGN
fv4:
  lw    x7,[x3]     ; get varname / type
  beq   x7,x0,fv3		; no more vars ?
  beq   a0,x7,fv1		; match ?
	add		x3,x3,#8		; move to next var
  lw    x7,VAREND		; 
  blt   x3,x7,fv4		; loop back to look at next var

  ; variable not found
  ; no more memory
  lw		x7,[$sp]
  lw		x3,4[$sp]
  add		$sp,$sp,#8
  ldi		a0,#msgVarSpace
  jmp   ERROR

  ; variable not found
  ; allocate new ?
fv3:
	beq		a1,x0,fv2
  sw    a0,[x3]     ; save varname / type
  ; found variable
  ; return address
fv1:
  add		v0,x3,#4
  lw		x7,[$sp]
  lw		x3,4[$sp]
  add		$sp,$sp,#8
  ret			    			; v0 = address

  ; didn't find var and not allocating
fv2:
  lw		x7,[$sp]
  lw		x3,4[$sp]
  add		$sp,$sp,#8
	mov		v0,x0				; v0 = nullptr
  ret

; The following functions are entered via a jump instruction with
; the return address already saved.

; ===== The PEEK function returns the byte stored at the address
;	contained in the following expression.
;
PEEK:
	call	PARN		; get the memory address
	lb		v0,[v0]		; get the addressed byte
	mov		v1,x0			; type = int
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret
PEEKW:
	call	PARN		; get the memory address
	lw		v0,[v0]		; get the addressed word
	mov		v1,x0			; type = int
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret
PEEKH:
	call	PARN		; get the memory address
	lh		v0,[v0]		; get the addressed byte
	mov		v1,x0			; type = int
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret


; user function call
; call the user function with argument in a0, type in a1
USRX:
	sub		$sp,$sp,#4
	sw		$t0,[$sp]
	call	PARN		; get expression value
	mov		a0,v0
	mov		a1,v1
	sub		$sp,$sp,#4	; save the text pointer
	sw		$t2,[$sp]
	lw		$t0,usrJmp
	call	[$t0]			; get usr vector, jump to the subroutine
	lw		$t2,[$sp]	; restore the text pointer
	add		$sp,$sp,#4
	lw		$t0,[$sp]
	add		$sp,$sp,#4
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret


; ===== The RND function returns a random number from 1 to
;	the value of the following expression in D0.
;
RND:
	call	PARN		; get the upper limit
	beq		v0,r0,rnd2	; it must be positive and non-zero
	blt		v0,r0,rnd1
	mov		a1,v0
	mov		v1,v0
	call	gen_rand	; generate a random number
	rem		v0,v0,v1
	add		v0,v0,#1
	mov		v1,x0
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret
rnd1:
	ldi		a0,#msgRNDBad
	add		$sp,$sp,#4
	jmp		ERROR
rnd2:
	call	gen_rand	; generate a random number
	mov		v1,x0
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret

; ===== The ABS function returns an absolute value in a1.
;
ABS:
	call	PARN		; get the following expr.'s value
	blt		v0,r0,ABS1
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret
ABS1:
	sub		v0,x0,v0
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret


;==== The TICK function returns the cpu tick value in a0.
;
TICKX:
	csrrw	v0,#$C00,x0
	mov		v1,x0
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret

; ===== The SGN function returns the sign in a0. +1,0, or -1
;
SGN:
	call	PARN		; get the following expr.'s value
	mov		v1,x0
	beq		v0,r0,SGN1
	blt		v0,r0,SGN2
	ldi		v0,#1
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret
SGN2:
	ldi		v0,#-1
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret
SGN1:
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret	

; ===== The SIZE function returns the size of free memory in v0.
; does not consider memory used by @()
;
SIZEX:
	lw		v0,VARBGN	; get the number of free bytes...
	lw		v1,TXTUNF	; between 'TXTUNF' and 'VARBGN'
	sub		v0,v0,v1
	mov		v1,x0			; type = int
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret					; return the number in v0


;******************************************************************
;
; *** SETVAL *** FIN *** ENDCHK *** ERROR (& friends) ***
;
; 'SETVAL' expects a variable, followed by an equal sign and then
; an expression.  It evaluates the expression and sets the variable
; to that value.
;
; returns
; a1 = variable's address
;
SETVAL:
	sub		$sp,$sp,#4
	sw		$ra,[$sp]
  ldi		a0,#1		; allocate var
  call	TSTV		; variable name?
  bne		v0,x0,.sv2
 	ldi		a0,#msgVar
	add		$sp,$sp,#4
 	jmp		ERROR 
.sv2:
	sub		$sp,$sp,#4
	sw		v0,[$sp]	; save the variable's address
	call	TSTC			; get past the "=" sign
	dw		'='
	bra		SV1
	call	OREXPR		; evaluate the expression
	lw		a1,[$sp]	; get back the variable's address
	add		$sp,$sp,#4
	sw    v0,[a1]   ; and save value in the variable
	mov		v0,a1			; return v0 = variable address
	lw		v1,-4[a1]
	and		v1,v1,#$FF
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret
SV1:
	add		$sp,$sp,#4
  jmp	  QWHAT		; if no "=" sign


; 'FIN' checks the end of a command.  If it ended with ":",
; execution continues.	If it ended with a CR, it finds the
; the next line and continues from there.
;
FIN:
	sub		$sp,$sp,#4
	sw		$ra,[$sp]
	call	TSTC		; *** FIN ***
	dw		':'
	bra		FI1
	add		$sp,$sp,#4	; if ":", discard return address
	jmp		RUNSML		; continue on the same line
FI1:
	call	TSTC		; not ":", is it a CR?
	dw		CR
	bra		FI2
						; else return to the caller
	add		$sp,$sp,#4	; yes, purge return address
	jmp		RUNNXL		; execute the next line
FI2:
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret					; else return to the caller


; 'ENDCHK' checks if a command is ended with a CR. This is
; required in certain commands, such as GOTO, RETURN, STOP, etc.
;
; Check that there is nothing else on the line
; Registers Affected
;   a0
;
ENDCHK:
	sub		$sp,$sp,#4
	sw		$ra,[$sp]
	call	IGNBLK
	lbu		a0,[$t2]
	ldi		$t1,#CR
	beq		a0,$t1,ec1	; does it end with a CR?
	ldi		a0,#msgExtraChars
	jmp		ERROR
ec1:
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret

; 'ERROR' prints the string pointed to by a0. It then prints the
; line pointed to by CURRNT with a "?" inserted at where the
; old text pointer (should be on top of the stack) points to.
; Execution of Tiny BASIC is stopped and a warm start is done.
; If CURRNT is zero (indicating a direct command), the direct
; command is not printed. If CURRNT is -1 (indicating
; 'INPUT' command in progress), the input line is not printed
; and execution is not terminated but continues at 'INPERR'.
;
; Related to 'ERROR' are the following:
; 'QWHAT' saves text pointer on stack and gets "What?" message.
; 'AWHAT' just gets the "What?" message and jumps to 'ERROR'.
; 'QSORRY' and 'ASORRY' do the same kind of thing.
; 'QHOW' and 'AHOW' also do this for "How?".
;
TOOBIG:
	ldi		a0,#msgTooBig
	bra		ERROR
QSORRY:
  ldi		a0,#SRYMSG
	bra	    ERROR
QWHAT:
	ldi		a0,#msgWhat
ERROR:
	call	PRMESG		; display the error message
	lw		a0,CURRNT	; get the current line pointer
	beq		a0,r0,ERROR1	; if zero, do a warm start
	ldi		$t1,#-1
	beq		a0,$t1,INPERR	; is the line no. pointer = -1? if so, redo input
	lbu		r5,[$t2]		; save the char. pointed to
	sb		x0,[$t2]		; put a zero where the error is
	lw		a0,CURRNT	; point to start of current line
	call	PRTLN		; display the line in error up to the 0
	mov     r6,a0	    ; save off end pointer
	sb		r5,[$t2]		; restore the character
	ldi		a0,#'?'		; display a "?"
	call	GOOUT
	mov		a1,r0		; stop char = 0
	sub		a0,r6,#1	; point back to the error char.
	call	PRTSTG		; display the rest of the line
ERROR1:
	jmp	    WSTART		; and do a warm start

;******************************************************************
;
; *** GETLN *** FNDLN (& friends) ***
;
; 'GETLN' reads in input line into 'BUFFER'. It first prompts with
; the character in r3 (given by the caller), then it fills the
; buffer and echos. It ignores LF's but still echos
; them back. Control-H is used to delete the last character
; entered (if there is one), and control-X is used to delete the
; whole line and start over again. CR signals the end of a line,
; and causes 'GETLN' to return.
;
;
GETLN:
	sub		$sp,$sp,#8
	sw		r5,[$sp]
	sw		$ra,4[$sp]
	call	GOOUT		; display the prompt
	ldi		a0,#1
;	sw		a0,CursorFlash	; turn on cursor flash
	ldi		a0,#' '		; and a space
	call	GOOUT
	ldi		$t2,#BUFFER	; $t2 is the buffer pointer
.GL1:
	call	CHKIO		; check keyboard
	beq		v0,x0,.GL1	; wait for a char. to come in
	ldi		$t1,#CTRLH
	beq		v0,$t1,.GL3	; delete last character? if so
	ldi		$t1,#CTRLX
	beq		v0,$t1,.GL4	; delete the whole line?
	ldi		$t1,#CR
	beq		v0,$t1,.GL2		; accept a CR
	ldi		$t1,#' '
	blt		v0,$t1,.GL1	; if other control char., discard it
.GL2:
	sb		v0,[$t2]		; save the char.
	add		$t2,$t2,#1
	sub		$sp,$sp,#4
	sw		v0,[$sp]
	mov		$a0,$v0
	call	GOOUT		; echo the char back out
	lw		v0,[$sp]; get char back (GOOUT destroys a0)
	add		$sp,$sp,#4
	ldi		$t1,#CR
	beq		v0,$t1,.GL7			; if it's a CR, end the line
	ldi		$t1,#BUFFER+BUFLEN-1
	blt		$t2,$t1,.GL1		; any more room? ; yes: get some more, else delete last char.
.GL3:
	ldi		a0,#CTRLH	; delete a char. if possible
	call	GOOUT
	ldi		a0,#' '
	call	GOOUT
	ldi		$t1,#BUFFER
	ble		$t2,$t1,.GL1	; any char.'s left?	; if not
	ldi		a0,#CTRLH		; if so, finish the BS-space-BS sequence
	call	GOOUT
	sub		$t2,$t2,#1	; decrement the text pointer
	bra		.GL1		; back for more
.GL4:
	mov		a0,$t2		; delete the whole line
	sub		r5,a0,#BUFFER   ; figure out how many backspaces we need
	beq		r5,r0,.GL6		; if none needed, brnch
	sub		r5,r5,#1		; loop count is one less
.GL5:
	ldi		a0,#CTRLH		; and display BS-space-BS sequences
	call	GOOUT
	ldi		a0,#' '
	call	GOOUT
	ldi		a0,#CTRLH
	call	GOOUT
	sub		r5,r5,#1
	bne		r5,r0,.GL5
.GL6:
	ldi		$t2,#BUFFER	; reinitialize the text pointer
	bra		.GL1		; and go back for more
.GL7:
	sb		x0,[$t2]		; null terminate line
;	sw		x0,CursorFlash	; turn off cursor flash
	ldi		a0,#LINEFD	; echo a LF for the CR
	call	GOOUT
	lw		r5,[$sp]
	lw		$ra,4[$sp]
	add		$sp,$sp,#8
	ret


; 'FNDLN' finds a line with a given line no. (in a0) in the
; text save area.  $t3 is used as the text pointer. If the line
; is found, $t3 will point to the beginning of that line
; (i.e. the high byte of the line no.), and $v0 = 1.
; If that line is not there and a line with a higher line no.
; is found, $t3 points there and $v0 = 0. If we reached
; the end of the text save area and cannot find the line, flags
; $t3 = 0, $v0 = 0.
; $v0=1 if line found
; r0 = 1	<= line is found
;	$t3 = pointer to line
; r0 = 0    <= line is not found
;	r9 = zero, if end of text area
;	r9 = otherwise higher line number
;
; 'FNDLN' will initialize $t3 to the beginning of the text save
; area to start the search. Some other entries of this routine
; will not initialize $t3 and do the search.
; 'FNDLNP' will start with $t3 and search for the line no.
; 'FNDNXT' will bump $t3 by 4, find a CR and then start search.
; 'FNDSKP' uses $t3 to find a CR, and then starts the search.
; return Z=1 if line is found, r9 = pointer to line
;
; Parameters
;	a0 = line number to find
;
FNDLN:
	ldi		$t1,#$FFFFF
	blt		a0,$t1,fl1	; line no. must be < 65535
	ld		a0,#msgLineRange
	jmp		ERROR
fl1:
	ldi		$t3,#TXTBGN	; init. the text save pointer

FNDLNP:
	lw		$t4,TXTUNF	; check if we passed the end
	bgeu	$t3,$t4,FNDRET1; if so, return with r9=0,a0=0
	sub		$sp,$sp,#8	; push a0
	sw		a0,[$sp]
	sw		ra,4[$sp]
	mov		a0,t3
	call	LoadWord		; get line number
	lw		a0,[$sp]		; pop a0
	lw		ra,4[$sp]
	add		$sp,$sp,#8
	beq		v0,a0,FNDRET2
	bltu	v0,a0,FNDNXT	; is this the line we want? no, not there yet
FNDRET:
	mov		v0,x0	; line not found, but $t3=next line pointer
	ret
FNDRET1:
;	eor		r9,r9,r9	; no higher line
	mov		v0,x0	; line not found
	ret
FNDRET2:
	ldi		v0,#1	; line found
	ret

FNDNXT:
	add		$t3,$t3,#4	; find the next line

FNDSKP:
	lbu		v1,[$t3]
	add		$t3,$t3,#1
	ldi		$t1,#CR
	bne		v1,$t1,FNDSKP	; try to find a CR, keep looking
	bra		FNDLNP		; check if end of text


;******************************************************************
; 'MVUP' moves a block up from where a0 points to where a1 points
; until a0=a2
;
MVUP1:
	lb		r4,[a0]
	sb		r4,[a1]
	add		a0,a0,#1
	add		a1,a1,#1
MVUP:
	bne		a0,a2,MVUP1
	ret


; 'MVDOWN' moves a block down from where a0 points to where a1
; points until a0=a2
;
MVDOWN1:
	sub		a0,a0,#1
	sub		a1,a1,#1
	lb		r4,[a0]
	sb		r4,[a1]
MVDOWN:
	bne		a0,a2,MVDOWN1
	ret


; 'POPA_' restores the 'FOR' loop variable save area from the stack
;
; 'PUSHA_' stacks for 'FOR' loop variable save area onto the stack
;
; Note: a single zero word is stored on the stack in the
; case that no FOR loops need to be saved. This needs to be
; done because PUSHA_ / POPA_ is called all the time.
//message "POPA_"
POPA_:
	lw		a0,[$sp]
	add		$sp,$sp,#4
	sw		a0,LOPVAR	; restore LOPVAR, but zero means no more
	beq		a0,x0,PP1
	lw		a0,[$sp]
	sw		a0,LOPPT
	lw		a0,4[$sp]
	sw		a0,LOPLN
	lw		a0,8[$sp]
	sw		a0,LOPLMT
	lw		a0,12[$sp]
	sw		a0,LOPINC
	add		$sp,$sp,#16
PP1:
	ret


PUSHA_:
	lw		a0,STKBOT	; Are we running out of stack room?
	add		a0,a0,#20	; we might need this many bytes
	blt		$sp,a0,QSORRY	; out of stack space
	lw		a1,LOPVAR		; save loop variables
	beq		a1,x0,PU1		; if LOPVAR is zero, that's all
	sub		$sp,$sp,#16
	lw		a0,LOPPT
	sw		a0,[$sp]
	lw		a0,LOPLN
	sw		a0,4[$sp]
	lw		a0,LOPLMT
	sw		a0,8[$sp]
	lw		a0,LOPINC
	sw		a0,12[$sp]
PU1:
	sub		$sp,$sp,#4
	sw		a1,[$sp]
	ret


;******************************************************************
;
; 'PRTSTG' prints a string pointed to by a0. It stops printing
; and returns to the caller when either a CR is printed or when
; the next byte is the same as what was passed in a1 by the
; caller.
;
; 'PRTLN' prints the saved text line pointed to by r3
; with line no. and all.
;

; a0 = pointer to string
; a1 = stop character
; return v0 = pointer to end of line + 1

PRTSTG:
	sub		$sp,$sp,#20
	sw		r5,[$sp]
	sw		r6,4[$sp]
	sw		r7,8[$sp]
	sw		$ra,12[$sp]
	sw		$a0,16[$sp]
	mov   r5,a0	    ; r5 = pointer
	mov   r6,a1	    ; r6 = stop char
.PS1:
  lbu   r7,[r5]     ; get a text character
	add		r5,r5,#1
	beq	  r7,r6,.PRTRET	; same as stop character? if so, return
	mov   a0,r7
	call	GOOUT		; display the char.
	ldi		$t1,#CR
	bne   r7,$t1,.PS1	; is it a C.R.? no, go back for more
	ldi		a0,#LINEFD  ; yes, add a L.F.
	call	GOOUT
.PRTRET:
  mov   v1,r7	    ; return a1 = stop char
	mov		v0,r5		; return a0 = line pointer
	lw		$r5,[$sp]
	lw		$r6,4[$sp]
	lw		$r7,8[$sp]
	lw		$ra,12[$sp]
	lw		$a0,16[$sp]
	add		$sp,$sp,#20
  ret					; then return


; 'QTSTG' looks for an underline (back-arrow on some systems),
; single-quote, or double-quote.  If none of these are found, returns
; to the caller.  If underline, outputs a CR without a LF.  If single
; or double quote, prints the quoted string and demands a matching
; end quote.  After the printing, the next i-word of the caller is
; skipped over (usually a branch instruction).
;
QTSTG:
	sub		$sp,$sp,#4
	sw		$ra,[$sp]
	call	TSTC		; *** QTSTG ***
	dw		'"'
	bra		QT3
	ldi		a1,#'"'		; it is a "
QT1:
	mov		a0,$t2
	call	PRTSTG		; print until another
	mov		$t2,v0
	ldi		$t1,#CR
	bne		v1,$t1,QT2	; was last one a CR?
	jmp		RUNNXL		; if so run next line
QT3:
	call	TSTC		; is it a single quote?
	dw		'\''
	bra		QT4
	ldi		a1,#'\''	; if so, do same as above
	bra		QT1
QT4:
	call	TSTC		; is it an underline?
	dw		'_'
	bra		QT5
	ldi		a0,#CR		; if so, output a CR without LF
	call	GOOUT
QT2:
	lw		$ra,[$sp]		; get return address
	add		$sp,$sp,#4
	jmp		4[$ra]		; skip following branch
QT5:					; not " ' or _
	lw		$ra,[$sp]		; get return address
	add		$sp,$sp,#4
	ret

; Output a CR LF sequence
;
prCRLF:
	sub		$sp,$sp,#4
	sw		$ra,[$sp]
	ldi		a0,#CR
	call	GOOUT
	ldi		a0,#LINEFD
	call	GOOUT
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret

;-------------------------------------------------------------------------------
; 'PRTNUM' prints the 32 bit number in a0, leading blanks are added if
; needed to pad the number of spaces to the number in a1.
; However, if the number of digits is larger than the no. in
; a1, all digits are printed anyway. Negative sign is also
; printed and counted in, positive sign is not.
;
; Parameters
; 	a0 = number to print
; 	a1 = number of digits
;		a2 = base (eg 10, 16)
; Register Usage
;		s2 = number of padding spaces
; Modifies:
;		a0,a1,t1
; Returns:
;		none
;-------------------------------------------------------------------------------

public PRTNUM:
	sub		$sp,$sp,#20
	sw		$s1,[$sp]
	sw		$s2,4[$sp]
	sw		$s3,8[$sp]
	sw		$s4,12[$sp]
	sw		$ra,16[$sp]
	ldi		s4,#NUMWKA	; r7 = pointer to numeric work area
	mov		s3,a0		; save number for later
	mov		s2,a1		; s2 = min number of chars
	bge		a0,x0,.PN2	; is it negative? if not
	sub		a0,x0,a0	; else make it positive
	sub		s2,s2,#1	; one less for width count
.PN2:
	ldi		$t1,#10
.PN1:
	rem		a1,a0,a2	; a1 = a0 mod 10
	div		a0,a0,a2	; a0 /= 10 divide by 10
	bleu	a1,a2,.PN7
	add		a1,a1,#'A'-10-'0'
.PN7:
	add		a1,a1,#'0'	; convert remainder to ascii
	sb		a1,[$s4]		; and store in buffer
	add		s4,s4,#1
	sub		s2,s2,#1	; decrement width
	bne		a0,x0,.PN1
	ble		$s2,$x0,.PN4	; test pad count, skip padding if not needed
.PN3:
	ldi		$a0,#' '		; display the required leading spaces
	call	GOOUT
	sub		$s2,$s2,#1
	bgt		$s2,$x0,.PN3
.PN4:
	bge		$s3,$x0,.PN5	; is number negative?
	ldi		$a0,#'-'		; if so, display the sign
	call	GOOUT
.PN5:
	ldi		$t1,#NUMWKA
.PN6:
	sub		$s4,$s4,#1
	lbu		$a0,[$s4]		; now unstack the digits and display
	call	GOOUT
	bgtu	$s4,$t1,.PN6

	lw		$s1,[$sp]
	lw		$s2,4[$sp]
	lw		$s3,8[$sp]
	lw		$s4,12[$sp]
	lw		$ra,16[$sp]
	add		$sp,$sp,#20
	ret

;-------------------------------------------------------------------------------
; Load a word from memory using unaligned access.
; Moves forwards through memory
;
; Parameters:
;		a0 = pointer to word
; Returns:
;		v0 = word loaded
;-------------------------------------------------------------------------------
LoadWord:
  lbu		$v0,[$a0]	
  lbu		$v1,1[$a0]
  sll		$v1,$v1,#8
  or		$v0,$v0,$v1
  lbu		$v1,2[$a0]
  sll		$v1,$v1,#16
  or		$v0,$v0,$v1
  lbu		$v1,3[$a0]
  sll		$v1,$v1,#24
  or		$v0,$v0,$v1
	ret

;-------------------------------------------------------------------------------
; Parameters:
; 	a0 = pointer to line
; Returns:
;		v0 = pointer to end of line + 1
;-------------------------------------------------------------------------------

PRTLN:
	sub		$sp,$sp,#16
	sw		$r5,[$sp]
	sw		$ra,4[$sp]
	sw		$a0,8[$sp]
	sw		$a1,12[$sp]
  mov		$r5,$a0		; r5 = pointer
  ; get the line number stored as binary
  ; assume unaligned loads not allowed
  call	LoadWord
  mov		a0,v0

	add		r5,r5,#4
  ldi		a1,#5       ; display a 0 or more digit line no.
  ldi		a2,#10
	call	PRTNUM
	ldi		a0,#' '     ; followed by a blank
	call	GOOUT
	mov		a1,r0       ; stop char. is a zero
	mov		a0,r5
	call  PRTSTG		; display the rest of the line
	lw		$r5,[$sp]
	lw		$ra,4[$sp]
	lw		$a0,8[$sp]
	lw		$a1,12[$sp]
	add		$sp,$sp,#16
	ret


; ===== Test text byte following the call to this subroutine. If it
;	equals the byte pointed to by t2, return to the code following
;	the call. 
;
; Parameters:
;		<static> word byte to look for
;		<static> branch if not found
; Registers Affected
;   none
; Returns
;		t2 = updated text pointer
;
TSTC:
	sub		$sp,$sp,#12
	sw		$a0,[$sp]
	sw		$ra,4[$sp]
	sw		$a1,8[$sp]
	call	IGNBLK		; ignore leading blanks
	lw		$ra,4[$sp]	; get return address, it's needed for a reference
	lbu		$a0,[$t2]
	lbu		$a1,[$ra]
	beq		$a1,$a0,TC1	; is it = to what t2 points to? if so
	lw		$a0,[$sp]		; restore a0
	lw		$a1,8[$sp]
	add		$sp,$sp,#12	;
	jmp		4[$ra]			; jump to the routine skip param
TC1:
	add		$t2,$t2,#1	; if equal, bump text pointer
	lw		$a0,[$sp]
	lw		$ra,4[$sp]
	lw		$a1,8[$sp]
	add		$sp,$sp,#12
	jmp		8[$ra]			; jump back, skip parm and branch


; ===== See if the text pointed to by $t2 is a number. If so,
;	return the number in $v0 and the number of digits in $v1,
;	else return zero in $v0 and $v1.
; Registers Affected
;   a0,a1,r3,r4
; Returns
; 	v0 = number
;		v1 = number of digits in number
;	t2 = updated text pointer
;
TSTNUM:
	sub		$sp,$sp,#8
	sw		$ra,4[$sp]
	sw		r3,[$sp]
	call	IGNBLK		; skip over blanks
	mov		$v0,$x0		; initialize return parameters
	mov		$v1,$x0
TN1:
	lbu		r3,[$t2]
	ldi		$t1,#'0'
	blt		r3,$t1,TSNMRET; is it less than zero?
	ldi		$t1,#'9'
	bgt		r3,$t1,TSNMRET; is it greater than nine?
	ldi		$t1,#$7FFFFFFFFFFFFFF
	bleu	$v0,$t1,TN2; see if there's room for new digit
	ldi		$a0,#msgNumTooBig
	jmp		ERROR		; if not, we've overflowd
TN2:
	add		$t2,$t2,#1	; adjust text pointer
	sll		$t3,$v0,#1	; quickly multiply result by 10
	sll		$v0,$v0,#3	; *8
	add		$v0,$v0,$t3	; *8 + *2
	and		r3,r3,#$0F	; add in the new digit
	add		$v0,$v0,r3
	add		$v1,$v1,#1	; increment the no. of digits
	bra		TN1
TSNMRET:
	lw		r3,[$sp]
	lw		$ra,4[$sp]
	add		$sp,$sp,#8
	ret


;===== Skip over blanks in the text pointed to by $t2.
;
; Registers Affected:
;	$t2
; Returns
;	$t2 = pointer updateded past any spaces or tabs
;
IGNBLK:
	sub		$sp,$sp,#4
	sw		$a0,[$sp]
IGB2:
	lbu		a0,[$t2]			; get char
	ldi		$t1,#' '
	beq		$a0,$t1,IGB1	; see if it's a space
	ldi		$t1,#'\t'
	bne		a0,$t1,IGBRET	; or a tab
IGB1:
	add		$t2,$t2,#1		; increment the text pointer
	bra		IGB2
IGBRET:
	lw		$a0,[$sp]
	add		$sp,$sp,#4
	ret

; ===== Convert the line of text in the input buffer to upper
;	case (except for stuff between quotes).
;
; Registers Affected
;   a0,r3
; Returns
;	r8 = pointing to end of text in buffer
;
TOUPBUF:
	sub		$sp,$sp,#4
	sw		$ra,[$sp]
	ldi		$t2,#BUFFER	; set up text pointer
	mov		r3,x0		; clear quote flag
TOUPB1:
	lbu		a0,[$t2]		; get the next text char.
	add		$t2,$t2,#1
	ldi		$t1,#CR
	beq		a0,$t1,TOUPBRT		; is it end of line?
	ldi		$t1,#'"'
	beq		a0,$t1,DOQUO	; a double quote?
	ldi		$t1,#'\''
	beq		a0,$t1,DOQUO	; or a single quote?
	bne		r3,x0,TOUPB1	; inside quotes?
	call	toUpper 	; convert to upper case
	sb		v0,-1[$t2]	; store it
	bra		TOUPB1		; and go back for more
DOQUO:
	bne		r3,x0,DOQUO1; are we inside quotes?
	mov		r3,a0		; if not, toggle inside-quotes flag
	bra		TOUPB1
DOQUO1:
	bne		r3,a0,TOUPB1; make sure we're ending proper quote
	mov		r3,r0		; else clear quote flag
	bra		TOUPB1
TOUPBRT:
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret


; ===== Convert the character in a0 to upper case
;
toUpper:
	mov		$v0,$a0
	slt		$t1,$v0,#'a'
	bne   $t1,$x0,TOUPRET	; is it < 'a'?
	ldi		$t1,#'z'
	bgt		$v0,$t1,TOUPRET	; or > 'z'?
	sub		$v0,$v0,#32	  ; if not, make it upper case
TOUPRET:
	ret

; 'CHKIO' checks the input. If there's no input, it will return
; to the caller with the a0=0. If there is input, the input byte is in a0.
; However, if a control-C is read, 'CHKIO' will warm-start BASIC and will
; not return to the caller.
;
//message "CHKIO"
CHKIO:
	sub		$sp,$sp,#4
	sw		$ra,[$sp]
	call	INCH		; get input if possible
	beq		$v0,$x0,CHKRET	; if Zero, no input
	xor		$v1,$v0,#CTRLC
	bne		$v1,$x0,CHKRET; is it control-C?
	jmp		WSTART		; if so, do a warm start
CHKRET:
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret

; ===== Display a CR-LF sequence
;
CRLF:
	ldi		a0,#CLMSG

; ===== Display a zero-ended string pointed to by register a0
; Registers Affected
;   a0,a1,r4
;
PRMESG:
	sub		$sp,$sp,#4
	sw		$ra,[$sp]
	call	SerialPutString
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret

;*****************************************************
; The following routines are the only ones that need *
; to be changed for a different I/O environment.     *
;*****************************************************

; ===== Output character to the console (Port 1) from register a0
;	(Preserves all registers.)
;
OUTC:
	jmp		SerialPutChar

; ===== Input a character from the console into register v0 (or
;	return Zero status if there's no character available).
;
INCH:
	sub 	$sp,$sp,#4
	sw		$ra,[$sp]
	call	SerialPeekChar
	add		$v0,$v0,#1				; prepare test -1
	beq		$v0,$x0,INCH1			; was = -1
	sub		$v0,$v0,#1				; get char back
	lw		$ra,[$sp]
	add		$sp,$sp,#4
	ret
INCH1:
	lw		$ra,[$sp]		; return a zero for no-char
	add		$sp,$sp,#4
	ret

; ===== Return to the resident monitor, operating system, etc.
;
//message "BYEBYE"
BYEBYE:
//	call	ReleaseIOFocus
	lw		$sp,OSSP
	jmp		Monitor
 

msgInit	db	CR,LINEFD,"CS01 Tiny BASIC v1.0",CR,LINEFD,"(C) 2017-2020  Robert Finch",CR,CR,0
OKMSG	db	CR,LINEFD,"OK",CR,0
msgWhat	db	"What?",CR,0
SRYMSG	db	"Sorry."
CLMSG	db	CR,0
msgReadError	db	"Compact FLASH read error",CR,0
msgNumTooBig	db	"Number is too big",CR,0
msgDivZero		db	"Division by zero",CR,0
msgVarSpace     db  "Out of variable space",CR,0
msgBytesFree	db	" bytes free",CR,0
msgReady		db	CR,"Ready",CR,0
msgComma		db	"Expecting a comma",CR,0
msgLineRange	db	"Line number too big",CR,0
msgVar			db "Expecting a variable",CR,0
msgRNDBad		db	"RND bad parameter",CR,0
msgSYSBad		db	"SYS bad address",CR,0
msgInputVar		db	"INPUT expecting a variable",CR,0
msgNextFor		db	"NEXT without FOR",CR,0
msgNextVar		db	"NEXT expecting a defined variable",CR,0
msgBadGotoGosub	db	"GOTO/GOSUB bad line number",CR,0
msgRetWoGosub   db	"RETURN without GOSUB",CR,0
msgTooBig		db	"Program is too big",CR,0
msgExtraChars	db	"Extra characters on line ignored",CR,0

LSTROM	equ	*		; end of possible ROM area
;	END

