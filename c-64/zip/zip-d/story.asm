	; Processor directive required by dasm
	PROCESSOR 6502
;
; Story loader for Commodore 64 ZIP version D, E and F
;
; This standalone program is the one visible file in
; the directory of a standard C-64 game disk, typically
; named "STORY".  When loaded and run, it pulls in the
; ZIP from the first two tracks, block by block as a
; "direct file", and jumps to it.
;
; The source to the game loaders has been lost.  This
; source has been reconstructed based on the contents
; of the binary program from a game disk and some of
; the constant and label names from the original source
; for ZIP version D for the Commodore 64.
;
; This program can be assembled with 'dasm'
; https://github.com/dasm-assembler/dasm
;

EOL	EQU	$0D		; EOL character/Carriage Return
CLS	EQU	$93		; Clear screen, home cursor
SWLC	EQU	$0E		; Switch to lower case char set

C64T	EQU	1		; C64 interpreter start track
C64S	EQU	2		; and sector

FAST	EQU	$0002		; Fast-Read Available flag
BUFPTR	EQU	$0003
COUNT	EQU	$0005
TRACK	EQU	$0006
SECTOR	EQU	$0007
TIME	EQU	$00A2		; System Jiffy Timer
NDX	EQU	$00C6		; # chars in keyboard buffer

;DIGPTR	EQU	$00FB		; Pointer for ASCII conversion routine
;ZIPPTR	EQU	$00FD		; Pointer for writing ZIP to RAM

COLOR	EQU	$0286		; Foreground color for text
NMINV	EQU	$0318		; NMI Interrupt Vector

	; ------
	; VIC-II
	; ------

	; COLOR REGISTERS

EXTCOL	EQU	$D020		; Border Color
BGCOLO	EQU	$D021		; Background Color

	; ---
	; SID
	; ---

        ; VOICE #1 REGISTERS

FRELO1	EQU	$D400		; FREQ
FREHI1	EQU	$D401		; FREQ HIGH BIT
PWLO1	EQU	$D402		; PULSE WIDTH
PWHI1	EQU	$D403		; PULSE WIDTH HIGH NIBBLE
VCREG1	EQU	$D404		; CONTROL
ATDCY1	EQU	$D405		; ATTACK/DECAY
SUREL1	EQU	$D406		; SUSTAIN/RELEASE

        ; MISCELLANEOUS REGISTERS

SIGVOL	EQU	$D418		; VOLUME/FILTER CONTROL



ZSTART	EQU	$0E00		; Load and Start address for ZIP

	ORG	$0801		; Start of BASIC address for C-64

	; -----------
	; BASIC START
	; -----------

	; Encoded line of BASIC for C-64
	; 1 SYS(2063)

	DC.W	NXTLIN  	; Forward pointer to next line of BASIC
        DC.W	1	      	; line number 1
        DC.B	$9E     	; SYS token
        DC.B	"(2063)",$00	; "(2063)<nul>"
NXTLIN  DC.B	$00,$00 	; No more BASIC statements

	; ----------
	; ZIP LOADER
	; ----------

	; This program pulls in the interpreter program/ZIP
	; from the front of the disk, stored as raw data (not
	; chained as a typical Commodore program is when stored
	; as a PRG file).  It's packed into the first 17 sectors
	; per track for as many tracks as needed to fit.  This
	; routine expects the ZIP to fit into 30 sectors of 256
	; bytes (7680 bytes total)

LOADER	CLD
	LDX	#$FF		; Reset machine stack
	TXS
	JSR	CLALL		; Close everything
	SEI
	LDA	#<DORTI		; Point the system NMI Vector
	STA	NMINV		; to a simple "RTI" instruction
	LDA	#>DORTI		; to disable the STOP/RESTORE exit
	STA	NMINV+1
	CLI

	LDA	#$C0		; Set Kernal and Control messages on 
	JSR	SETMSG

	LDA	#CLS		; Clear screen
	JSR	CHROUT
	LDA	#SWLC		; Use Upper/Lower Chars
	JSR	CHROUT
	LDA	#8
	JSR	CHROUT
	LDA	#1		; White
	STA	COLOR		; Text
	LDA	#12		; Gray
	STA	EXTCOL		; Border
	STA	BGCOLO		; and Background

	; Initialize the sound system

	LDA	#0		; Clear
	LDX	#$1C		; All
LOD0	STA	FRELO1,X	; SID registers
	DEX
	BPL	LOD0

	LDA	#5		; Set Voice #1
	STA	FREHI1		; to a soothing frequency
	LDA	#$F0
	STA	SUREL1

	LDA	#2		; Set Voice #1
	STA	PWLO1		; Pulse Width
	LDA	#8		; for a
	STA	PWHI1		; 50% duty cycle

	; Display "Loading game ..." message
	LDY	#13		; Position "Loading from" message
	LDX	#10		; at (13,10)
	CLC
	JSR	PLOT
	LDX	#<QLINE1
	LDA	#>QLINE1
	JSR	DLINE		; "Loading from a"

	LDY	#7		; Position "Commodore 1541" message
	LDX	#11		; at (7,11)
	CLC
	JSR	PLOT
	LDX	#<QLINE2
	LDA	#>QLINE2
	JSR	DLINE		; "Commodore 1541 Disk Drive?"

	LDA	#0
	STA	COLOR
	STA	NDX

	LDY	#13		; Position "Press Y or N" message
	LDX	#13		; at (13,13)
	CLC
	JSR	PLOT
	LDX	#<SAYYN
	LDA	#>SAYYN
	JSR	DLINE		; "(Press Y or N)"

GETL	JSR	GETIN		; Get a character from keyboarr
	TAX
	BEQ	GETL		; Repeat until something is pressed
	AND	#%01111111	; Screen out shifts
	CMP	#"Y"		; Did user type "Y"?
	BEQ	ISY		; Yes
	CMP	#"N"		; Did user type "N"?
	BEQ	ISN		; Yes
	LDA	#%00001111	; Full volume
	STA	SIGVOL
	LDA	#%01000001	; Start pulse
	STA	VCREG1
	LDA	#252		; Wait 4 jiffies
	STA	TIME
RAZZ	LDA	TIME
	BNE	RAZZ
	STA	VCREG1		; Stop pulse
	STA	SIGVOL		; Volume off
	STA	NDX		; Clear keyboard queue
	BEQ	GETL		; Ask again

ISN	LDA	#0		; Set Fast Flag to false
	BEQ	SETFAST
ISY	LDA	#$FF		; Set Fast Flag to true
SETFAST	STA	FAST

	LDA	#CLS		; Clear screen
	JSR	CHROUT
	LDA	#1		; White
	STA	COLOR		; Text

	LDY	#8		; Position "Story Loading" message
	LDX	#11		; at (8,11)
	CLC
	JSR	PLOT
	LDX	#<LOADNG
	LDA	#>LOADNG
	JSR	DLINE		; "The story is loading..."

	; Open command channel
	LDA	#15		; OPEN 15,8,15,"I0"
	TAY			; Secondary Address
	LDX	#8		; Device #8
	JSR	SETLFS		; Set up Logical File
	LDA	#I0L		; Length of filename
	LDX	#<I0		; Point to filename
	LDY	#>I0		; "I0"
	JSR	SETNAM
	JSR	OPEN		; Open the disk (Carry Clear if OK)

	; Open data channel
	LDA	#2		; OPEN 2,8,2,"#"
	TAY			; Secondary Address
	LDX	#8		; Always on drive 8
	JSR	SETLFS
	LDA	#POUNDL		; Point to filename
	LDX	#<POUND		; "#"
	LDY	#>POUND		; to let disk pick buffer
	JSR	SETNAM
	JSR	OPEN		; Open Channel (Carry Clear if OK)

	; Point to place in RAM to load ZIP
	LDA	#<ZSTART
	STA	BUFPTR
	LDA	#>ZSTART
	STA	BUFPTR+1

	; Init location and size of ZIP to load
	LDA	#C64S		; ... Sector 2
	STA	SECTOR
	LDA	#C64T		; Start loading from Track 1
	STA	TRACK
	LDA	#30		; ... and read in 30 sectors
	STA	COUNT

NXTSEC	JSR	DREAD		; Read one sector from disk
	INC	SECTOR		; Point to next sector
	LDA	SECTOR
	CMP	#17		; Use 17 sectors per track
	BCC	NOSEEK		; If below that, stay on this track
	INC	TRACK		; Point to next track
	LDA	#0		; Reset to sector 0
	STA	SECTOR
NOSEEK	INC	BUFPTR+1	; Point to next part of RAM
	DEC	COUNT		; Mark this sector off the count
	BNE	NXTSEC		; Do it again until all done

	; Close all files
	JSR	CLALL

	; Jump to start of ZIP
	JMP	ZSTART

	; ------------
	; READ A BLOCK
	; ------------

DREAD	LDA	TRACK		; Get track
	LDY	#2
TCON	JSR	DIV10		; Divide by 10
	ORA	#"0"		; Convert to ASCII
	STA	DTRAK,Y		; Store into string
	TXA			; Get quotient into .A
	DEY			; Zero-fill unused bytes
	BPL	TCON
	LDA	SECTOR		; Same for sector ID
	LDY	#2
SCON	JSR	DIV10
	ORA	#"0"
	STA	DSECT,Y
	TXA
	DEY
	BPL	SCON
	LDX	#15		; Select Command Channel
	JSR	CHKOUT
	LDY	#0
SCM0	LDA	COMLIN,Y	; Send the command line
	BEQ	SCMX		; to the drive channel
	JSR	CHROUT
	INY
	BNE	SCM0
SCMX	JSR	CLRCHN
	LDX	#15		; Output to the
	JSR	CHKOUT		; Command Channel
	LDY	#0
SBPL	LDA	BPLINE,Y	; Send buffer pointer reset command
	BEQ	SBPX		; to the drive channel
	JSR	CHROUT
	INY
	BNE	SBPL
SBPX	JSR	CLRCHN		; Select the Data Channel
	LDX	#2
	JSR	CHKIN

	; Read block
	LDY	#0
READ1	JSR	CHRIN		; Get a byte
	STA	(BUFPTR),Y	; Move to RAM
	INY
	BNE	READ1		; Do 256 byte
	JMP	CLRCHN		; Release command channel and return

	; ---------------
	; DIVIDE .A BY 10
	; ---------------

	; EXIT: Quotient in .X, Remainder in .A

DIV10	LDX	#0		; Clear quotient
D10L	CMP	#10		; Are there any 10s left to subtract?
	BCC	D10EX		; Done if not
	SBC	#10		; Subtract it
	INX
	BNE	D10L		; Repeat until we have our answer
D10EX	RTS

	; --------------------------
	; DIRECT PRINT LINE in .X/.A
	; --------------------------

	; ENTRY: String address in .X/.A (LSB/MSB)

DLINE	STX	BUFPTR		; Drop string address 
	STA	BUFPTR+1	; into pointer

	LDY	#0		; Init char-fetch index
DOUT	LDA	(BUFPTR),Y	; Get character
	BEQ	DEX		; Until NUL
	JSR	CHROUT	
	INY
	BNE	DOUT		; Repeat
DEX	JMP	CLRCHN		; Release output channel and return

I0	DC.B	"I0"		; "I0"
I0L	EQU	*-I0

POUND	DC.B	"#"		; "#"
POUNDL	EQU	*-POUND

COMLIN	DC.B	"U1:2,0,"	; CBM DOS block-read command
DTRAK	DC.B	"***,"		; ASCII track number to read
DSECT	DC.B	"***"		; ASCII sector number to read
	DC.B	EOL,$00

BPLINE	DC.B	"B-P:2,0"	; CBM DOS buffer-pointer reset command
	DC.B	EOL,$00

QLINE1	DC.B	"lOADING FROM A",0
QLINE2	DC.B	"cOMMODORE 1541 dISK dRIVE?",0
SAYYN	DC.B	"(pRESS y OR n)",0

LOADNG	DC.B	"tHE STORY IS LOADING ..."
	DC.B	EOL,EOL,0

DORTI	RTI				; RTI instruction for NMI

	; -------------------
	; KERNAL JUMP VECTORS
	; -------------------

CHKIN	EQU	$FFC6		; OPEN CHANNEL FOR INPUT
CHKOUT	EQU	$FFC9		; OPEN CHANNEL FOR OUTPUT
CHRIN	EQU	$FFCF		; INPUT CHARACTER FROM CHANNEL
CHROUT	EQU	$FFD2		; OUTPUT CHARACTER TO CHANNEL
CLALL	EQU	$FFE7		; CLOSE ALL CHANNELS & FILES
CLOSE	EQU	$FFC3		; CLOSE A FILE
CLRCHN	EQU	$FFCC		; CLEAR CHANNEL
GETIN	EQU	$FFE4		; GET CHAR FROM KEYBOARD QUEUE
OPEN	EQU	$FFC0		; OPEN A FILE
PLOT	EQU	$FFF0		; READ/SET CURSOR POSITION
SETLFS	EQU	$FFBA		; SET FILE ATTRIBUTES
SETMSG	EQU	$FF90		; SET KERNAL MESSAGES
SETNAM	EQU	$FFBD		; SET FILENAME
