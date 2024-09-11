TITLE Using Low-Level I/O Procedures with Macros  (Proj6_sandeenk.asm)

; Author: Katherine Sandeen
; Last Modified: 6/3/24
; Description: Reinforces concepts related to string primitive
;	instructions and macros. This includes designing, implementing, and calling 
;	low-level I/O procedures, as well as implementing and using macros.

INCLUDE Irvine32.inc


; ----------------------------------------------------------------------------------
; Name: mGetString
; 
; Receives the user's keyboard input into a memory location.
;
; Preconditions: Parameters must exist as data labels.
;
; Postconditions: None.
;
; Receives:
;	promptAddr = string prompt address (reference)
;	inAddr     = address to store user's input (reference)
;	inLen	   = length of input string that can be accomodated (value)
;	outLen     = number of bytes read by the macro (reference)
;
; Returns: 
;	inAddr = storage address of received string
;	outLen = storage address of string length
; ----------------------------------------------------------------------------------
mGetString MACRO promptAddr:REQ, inAddr:REQ, inLen:REQ, outLen:REQ
	; save registers
	PUSH	EDI
	PUSH	EDX
	PUSH	ECX
	PUSH	EAX

	; display a prompt
	mDisplayString	promptAddr

	; read the input
	MOV		EDX, inAddr
	MOV		ECX, inLen
	MOV		EDI, outLen
	CALL	ReadString
	MOV		[EDI], EAX

	; restore registers
	POP		EAX
	POP		ECX
	POP		EDX
	POP		EDI
ENDM


; ----------------------------------------------------------------------------------
; Name: mDisplayString
;
; Prints the string passed in via memory location.
;
; Preconditions: String must be defined as a data label.
;
; Postconditions: None.
;
; Receives:
;	strOffset = string address (reference)
;
; Returns: None.
; ----------------------------------------------------------------------------------
mDisplayString MACRO strOffset:REQ
	PUSH	EDX							; save used register
	MOV		EDX, strOffset
	CALL	WriteString
	POP		EDX							; restore register
ENDM


STR_SIZE = 13							; 10 digits + sign symbol + null + 1
NUM_ARR_SIZE = 10


.data
; data storage
inString	BYTE	STR_SIZE DUP(?)
bytesRead	DWORD	0
validNum	SDWORD	0
numArray	SDWORD	NUM_ARR_SIZE DUP(0)
sum			SDWORD	0

; string storage
intro		BYTE	"Welcome to 'Using Low-Level I/O Procedures with Macros'... by Katie Sandeen",13,10,13,10,
					"Please input 10 signed integers, between -2,147,483,648 & 2,147,483,647, inclusive...",13,10,
					"Then I will display the integers, their total sum, and their avergage truncated value.",13,10,13,10,0
outro		BYTE	13,10,13,10,"That's all for this program. Goodbye, until next time...",13,10,0
inPrompt	BYTE	"Enter a signed integer: ",0
error		BYTE	"Invalid input, not a signed number or number was too big.",13,10,
					"Please try again: ",0
listHeader	BYTE	13,10,"Here are your numbers:",13,10,0
separator	BYTE	", ",0
sumHeader	BYTE	13,10,13,10,"The sum of your numbers is: ",0
avgHeader	BYTE	13,10,"Their truncated average is: ",0


.code
main PROC
	; --------------------------------------
	; Greet the user & display instructions.
	; --------------------------------------
	mDisplayString	OFFSET intro

	; ------------------------------------
	; Get valid integers from the user.
	; ------------------------------------
	; loop preliminaries
	MOV		ECX, NUM_ARR_SIZE
	MOV		EDI, OFFSET numArray
	CLD

_collectLoop:
	; ReadVal stack frame
	PUSH	OFFSET error
	PUSH	OFFSET inPrompt
	PUSH	OFFSET inString
	PUSH	STR_SIZE
	PUSH	OFFSET bytesRead
	PUSH	OFFSET validNum
	CALL	ReadVal

	; store numeric value in storage array
	MOV		EAX, validNum
	STOSD
	LOOP	_collectLoop

	; ---------------------------------
	; Display the integers.
	; ---------------------------------
	mDisplayString	OFFSET listHeader
	; loop preliminaries
	MOV		ECX, NUM_ARR_SIZE
	MOV		ESI, OFFSET numArray
	CLD

_displayLoop:
	LODSD
	; WriteVal stack frame
	PUSH	EAX
	CALL	WriteVal
	CMP		ECX, 1
	JZ		_displaySum
	mDisplayString	OFFSET separator
	LOOP	_displayLoop

	; --------------------------------
	; Display their sum.
	; --------------------------------
_displaySum:
	; CalcSum stack frame
	PUSH	OFFSET numArray
	PUSH	NUM_ARR_SIZE
	PUSH	OFFSET sum
	CALL	CalcSum

	; display result
	mDisplayString OFFSET sumHeader
	; WriteVal stack frame
	PUSH	sum
	CALL	WriteVal
	
	; ----------------------------------
	; Display their truncated average
	; ----------------------------------
	; calculate average
	MOV		EBX, NUM_ARR_SIZE
	MOV		EAX, sum
	CDQ
	IDIV	EBX

	; display result
	mDisplayString OFFSET avgHeader
	; WriteVal stack frame
	PUSH	EAX
	CALL	WriteVal

	; --------------------------------
	; Say goodbye to the user.
	; --------------------------------
	mDisplayString	OFFSET outro

	Invoke	ExitProcess,0				; exit to operating system
main ENDP


; ----------------------------------------------------------------------------------
; Name: ReadVal
;
; Gets user input in the form of a string of digits via mGetString macro. Converts
;	the string of ASCII digits to it's numeric value representation (SDWORD),
;	validating the input is a number. Stores value in a memory variable.
;
; Preconditions: Parameters must exist as data labels.
;
; Postconditions: None.
;
; Receives:
;	[EBP+28] = string error address (reference)
;	[EBP+24] = string prompt address (reference)
;	[EBP+20] = address to store user's input (reference)
;	[EBP+16] = length of input string that can be accomodated (value)
;	[EBP+12] = address to hold # bytes read by the macro (reference)
;	[EBP+8]  = address to hold validated number (reference)
;
; Returns: Validated number is stored at the global variable address dereferenced
;	by [EBP+8].
; ----------------------------------------------------------------------------------
ReadVal PROC
	LOCAL sign:BYTE

	; save registers
	PUSH	EAX
	PUSH	EBX
	PUSH	ECX
	PUSH	EDI
	PUSH	ESI

	; get user string input
	mGetString	[EBP+24], [EBP+20], [EBP+16], [EBP+12]

_validLoop:
	; check if length too long
	MOV		ESI, [EBP+12]
	MOV		ECX, [ESI]
	CMP		ECX, 0
	JZ		_error

	; convert string to numeric value
	MOV		sign, '+'
	MOV		ESI, [EBP+20]
	MOV		EBX, 0
	CLD
	XOR		EAX, EAX
	LODSB

	; check for a sign character at the front
	CMP		AL, '+'
	JNZ		_checkNeg
	LODSB
	DEC		ECX
_checkNeg:
	CMP		AL, '-'
	JNZ		_convertLoop
	MOV		sign, AL
	LODSB
	DEC		ECX

	; validate as a number
_convertLoop:
	CMP		AL, 48
	JB		_error
	CMP		AL, 57
	JA		_error

	; keep a tally of the converted digits,
	IMUL	EBX, 10
	JO		_error
	SUB		AL, 48

	; subtract if negative
	CMP		sign, '-'
	JNZ		_add
	SUB		EBX, EAX
	JO		_error
	JMP		_nextChar

_add:
	; else add if positive
	ADD		EBX, EAX
	JO		_error

_nextChar:
	; initiate next digit and loop
	XOR		EAX, EAX
	LODSB
	LOOP	_convertLoop

	; store validated number
	MOV		EDI, [EBP+8]
	MOV		[EDI], EBX
	
	; restore & dereference
	POP		ESI
	POP		EDI
	POP		ECX
	POP		EBX
	POP		EAX
	RET		24

; signal error
_error:
	mGetString	[EBP+28], [EBP+20], [EBP+16], [EBP+12]
	JMP		_validLoop

ReadVal ENDP


; ----------------------------------------------------------------------------------
; Name: WriteVal
;
; Converts a numeric SDWORD value to a string of ASCII digits. Invokes
;	mDisplayString macro to print the representation of the SDWORD to output.
;
; Preconditions: Parameter value must be validated numerical SDWORD.
;
; Postconditions: None.
;
; Receives:
;	[EBP+8] = numeric SDWORD (value)
;
; Returns: None.
; ----------------------------------------------------------------------------------
WriteVal PROC
	LOCAL revStr[12]:BYTE, numStr[12]:BYTE, sign:BYTE

	; save registers
	PUSH	EAX
	PUSH	EBX
	PUSH	ECX
	PUSH	EDI
	PUSH	EDX
	PUSH	ESI

	; check sign
	MOV		sign, '+'
	MOV		EAX, [EBP+8]
	CMP		EAX, 0
	JGE		_revConvert

	; add sign to output string if negative
	MOV		sign, '-'
	NEG		EAX

	; fill revStr w/ nums in reverse
_revConvert:
	LEA		ESI, revStr
	MOV		ECX, 0
_revLoop:
	MOV		EBX, 10
	XOR		EDX, EDX
	DIV		EBX
	ADD		EDX, 48
	MOV		[ESI], DL
	INC		ESI
	INC		ECX
	CMP		EAX, 0
	JNZ		_revLoop

	; flip revString into numStr
	DEC		ESI
	LEA		EDI, numStr

	; if neg, add sign first
	CMP		sign, '-'
	JNZ		_fwdLoop
	MOV		AL, sign
	STOSB

	; fill numStr with numbers forward
_fwdLoop:
	STD
	LODSB
	CLD
	STOSB
	LOOP	_fwdLoop

	; null terminate numStr
	MOV		AL, 0
	STOSB

	; print numString
	LEA		ESI, numStr
	mDisplayString	ESI

	; restore and dereference
	POP		ESI
	POP		EDX
	POP		EDI
	POP		ECX
	POP		EBX
	POP		EAX
	RET		4
WriteVal ENDP


; ----------------------------------------------------------------------------------
; Name: CalcSum
;
; Calculates the sum of all the numeric values within the parameter array.
;
; Preconditions: Parameter array must contain all valid numeric SDWORD values.
;
; Postconditions: None.
;
; Receives:
;	[EBP+16] = numeric array address (reference)
;	[EBP+12] = length of the numeric array (value)
;	[EBP+8]  = variable address to store sum (reference)	
;
; Returns: Sum is stored at the global variable address dereferenced by [EBP+8].
; ----------------------------------------------------------------------------------
CalcSum PROC
	; prepare EBP for Base+Offset
	PUSH	EBP
	MOV		EBP, ESP

	; save registers
	PUSH	EAX
	PUSH	EBX
	PUSH	ECX
	PUSH	EDI
	PUSH	ESI

	; init first value and prepare loop
	MOV		ECX, [EBP+12]
	MOV		EDI, [EBP+8]
	MOV		ESI, [EBP+16]
	LODSD
	MOV		[EDI], EAX					; destination variable will hold tally
	DEC		ECX

_sumLoop:
	LODSD
	ADD		[EDI], EAX
	LOOP	_sumLoop

	; restore registers and dereference stack
	POP		ESI
	POP		EDI
	POP		ECX
	POP		EBX
	POP		EAX
	POP		EBP
	RET		12
CalcSum ENDP


END main
