	; Processor directive required by dasm
	PROCESSOR 6502
;
; Game loader for Commodore 64 ZIP version A
;
; This standalone program is the one visible file in
; the directory of a standard C-64 game disk, typically
; named "GAME".  When loaded and run, it pulls in the
; ZIP from the first two tracks, block by block as a
; "direct file", and jumps to it.
;
; The source to the game loaders has been lost.  This
; source has been reconstructed based on the contents
; of the binary program from a game disk and some of
; the constant and label names from the original source
; for the 'tftp' utility program for the Commodore 128.
;
; This program can be assembled with 'dasm'
; https://github.com/dasm-assembler/dasm
;

EOL	EQU	$0D		; EOL character/Carriage Return
CLS	EQU	$93		; Clear screen, home cursor
SWLC	EQU	$0E		; Switch to lower case char set

C64T	EQU	1		; C64 interpreter start track
C64S	EQU	0		; and sector

DIGPTR	EQU	$00FB		; Pointer for ASCII conversion routine
ZIPPTR	EQU	$00FD		; Pointer for writing ZIP to RAM

ZSTART	EQU	$0C00		; Load and Start address for ZIP

	ORG	$0801		; Start of BASIC address for C-64

	; -----------
	; BASIC START
	; -----------

	; Encoded line of BASIC for C-64
	; 10 SYS(2063)

	DC.W	NXTLIN  	; Forward pointer to next line of BASIC
        DC.W	10      	; line number 10
        DC.B	$9E     	; SYS token
        DC.B	"(2063)",$00	; "(2063)<nul>"
NXTLIN  DC.B	$00,$00 	; No more BASIC statements

	; ----------
	; ZIP LOADER
	; ----------

	; This program pulls in the interpreter program/ZIP
	; from the front of the disk, stored as raw data (not
	; chained as a typical Commodore program is when stored
	; as a PRG file).  It's packed into the first 16 sectors
	; per track for as many tracks as needed to fit.  This
	; routine expects the ZIP to fit into 32 sectors of 256
	; bytes (8192 bytes total)

LOADER	LDA	#$C0		; Set Kernal and Control messages on 
	JSR	SETMSG

	; Init location and size of ZIP to load
	LDA	#C64T		; Start loading from Track 1
	STA	TRACK
	LDA	#C64S		; ... Sector 0
	STA	SECTOR
	LDA	#32		; ... and read in 32 sectors
	STA	COUNT

	; Display "Loading game ..." message
	LDA	#CLS		; Clear screen
	JSR	CHROUT
	LDX	#11		; Move cursor to (12, 11)
	LDY	#12
	CLC
	JSR	PLOT

	LDY	#0
LOUT	LDA	LOADNG,Y
	JSR	CHROUT
	INY
	CPY	#LOADNGL
	BCC	LOUT

	; Open command channel
	JSR	CLRCHN
	LDA	#15		; OPEN 15,8,15,"I0"
	LDX	#8		; Device #8
	LDY	#15		; Secondary Address
	JSR	SETLFS		; Set up Logical File
	LDA	#I0L		; Length of filename
	LDX	#<I0		; Point to filename
	LDY	#>I0		; "I0"
	JSR	SETNAM
	JSR	OPEN		; Open the disk (Carry Clear if OK)

	; Open data channel
	LDA	#2		; OPEN 2,8,2,"#"
	LDX	#8		; Always on drive 8
	LDY	#2		; Secondary addr
	JSR	SETLFS
	LDA	#POUNDL		; Point to filename
	LDX	#<POUND		; "#"
	LDY	#>POUND		; to let disk pick buffer
	JSR	SETNAM
	JSR	OPEN		; Open Channel (Carry Clear if OK)

	; Point to place in RAM to load ZIP
	LDA	#<ZSTART
	STA	ZIPPTR
	LDA	#>ZSTART
	STA	ZIPPTR+1

	; Get initial Track and Sector then read the disk
	LDX	TRACK
	LDY	SECTOR
NXTSEC	JSR	DREAD		; Read one sector from disk
	LDX	TRACK
	LDY	SECTOR
	INY
	CPY	#16		; Only use up to sector 15
	BCC	NOSEEK
	INX			; Advance to next track
	STX	TRACK
	LDY	#0		; And reset to sector 0
NOSEEK	STY	SECTOR
	INC	ZIPPTR+1
	DEC	COUNT		; Count down number of sectors to read
	BNE	NXTSEC

	; Close Data and Command Channel
	LDA	#2		; CLOSE 2
	JSR	CLOSE
	LDA	#15		; CLOSE 15
	JSR	CLOSE
	JSR	CLALL

	; Jump to start of ZIP
	JMP	ZSTART

; Variables for reading disk (all over-written by initialization code)
TRACK	DC.B	0		; Current Track
SECTOR	DC.B	0		; Current Sector
COUNT	DC.B	0		; Remaining disk blocks to read

; Filenames for OPEN calls
I0	DC.B	"I0"
I0L	EQU	*-I0
POUND	DC.B	"#"
POUNDL	EQU	*-POUND

	; ------------
	; READ A BLOCK
	; ------------

	; ENTER: TRACK IN .X, SECTOR IN .Y
DREAD	TYA
	PHA
	TXA

	; Convert Track to ASCII in COMLIN
	LDX	#<DTRAK
	LDY	#>DTRAK
	JSR	BIN2ASC

	; Convert Sector to ASCII in COMLIN
	PLA
	LDX	#<DSECT
	LDY	#>DSECT
	JSR	BIN2ASC

	; Select Command Channel
	LDX	#15		; Output to the
	JSR	CHKOUT		; Command Channel

	LDY	#0
SCM0	LDA	COMLIN,Y	; Send the command line
	JSR	CHROUT		; to the drive channel
	INY			; a byte at a time
	CPY	#CMLL
	BCC	SCM0

	; Send buffer pointer reset command
	JSR	CLRCHN
	LDX	#15		; Output to the
	JSR	CHKOUT		; Command Channel
	LDY	#0
SBPL	LDA	BPLINE,Y
	JSR	CHROUT
	INY
	CPY	#BPLL
	BCC	SBPL

	; Select Data Channel
	JSR	CLRCHN
	LDX	#2
	JSR	CHKIN

	; Read block
	LDY	#0
READ1	JSR	CHRIN
	STA	(ZIPPTR),Y
	INY
	BNE	READ1
	JMP	CLRCHN

COMLIN	DC.B	"U1:2,0,"	; CBM DOS block-read command
DTRAK	DC.B	"000,"		; ASCII track number to read
DSECT	DC.B	"000"		; ASCII sector number to read
	DC.B	EOL
CMLL	EQU	*-COMLIN

BPLINE	DC.B	"B-P:2,0"	; CBM DOS buffer-pointer reset command
	DC.B	EOL
BPLL	EQU	*-BPLINE

LOADNG	DC.B	SWLC
	DC.B	"lOADING GAME ..."
LOADNGL	EQU	*-LOADNG

	; -------------------
	; CONVERT .A to ASCII
	; -------------------

	; ENTER: TRACK/SECTOR NUMBER in .A
	; EXIT: ASCII numeric string at .Y/.X

BIN2ASC STX	DIGPTR		; Point at beginning of number string
	STY	DIGPTR+1
	LDY	#2		; Max 2 digits, starting with ones place
BCON	JSR	DIV10		; Divide .A by 10
	ORA	#"0"		; Convert binary remainder to ASCII
	STA	(DIGPTR),Y	; store ASCII digit in string
	TXA			; move quotient to .A
	DEY			; Point back to previous (larger) digit
	BPL	BCON		; Loop back for second (tens) digit
	RTS

	; ---------------
	; DIVIDE .A BY 10
	; ---------------

	; EXIT: Quotient in .X, Remainder in .A

DIV10	LDX	#0	; Clear quotient
D10L	CMP	#10	; Are there any 10s left to subtract?
	BCC	D10EX	; Done if not
	SEC		; Yes
	SBC	#10	; Subtract it
	INX		; Increase the quotient
	JMP	D10L	; Repeat until we have our answer
D10EX	RTS

	; Binary memory garbage from original version of "GAME"
	;
	; This is not required for successful operation.
	; It is included to permit an exact binary match
	; against the original.

	HEX	FFFF0000FFFF0000FFFF0000FFFF0000	; "................"
	HEX	FFFF0000FFFF0000FFFF0000FFFF0000	; "................"
	HEX	FFFF0000FFFF8000FDFF0000FFFF0000	; "................"
	HEX	FFFF0000FFFF0400FFFF2400FEFF0000	; "..........$....."
	HEX	FFFF0000FFFF0000FFFF0000FFFF0000	; "................"
	HEX	FFFF0000FFFF0000FFFF0000FFFF0000	; "................"
	HEX	FFFF0000FFFF0000FFFFA100FFDF0000	; "................"
	HEX	FFFF0000FFFF0000FFFF0000FFFF0000	; "................"
	HEX	FFFF0000FFFF0000FFFF0000FFFF0000	; "................"
	HEX	FFFF0000FFFF0000FFFF0000FFFF0000	; "................"
	HEX	FFFF0000FFFF8000FDFF0000FFFF0000	; "................"
	HEX	FFFF0000FFFF0000FFFF2100FBFF      	; "..........!..."

	; ------------------------
	; KERNAL JUMP VECTORS
	; ------------------------

CHKIN	EQU	$FFC6		; OPEN CHANNEL FOR INPUT
CHKOUT	EQU	$FFC9		; OPEN CHANNEL FOR OUTPUT
CHRIN	EQU	$FFCF		; INPUT CHARACTER FROM CHANNEL
CHROUT	EQU	$FFD2		; OUTPUT CHARACTER TO CHANNEL
CLALL	EQU	$FFE7		; CLOSE ALL CHANNELS & FILES
CLOSE	EQU	$FFC3		; CLOSE A FILE
CLRCHN	EQU	$FFCC		; CLEAR CHANNEL
OPEN	EQU	$FFC0		; OPEN A FILE
PLOT	EQU	$FFF0		; READ/SET CURSOR POSITION
SETLFS	EQU	$FFBA		; SET FILE ATTRIBUTES
SETMSG	EQU	$FF90		; SET KERNAL MESSAGES
SETNAM	EQU	$FFBD		; SET FILENAME

