	PROCESSOR 16F877A
	INCLUDE "P16F877A.INC"


	__CONFIG 0x3731


	errorlevel -302, -305

Char 				EQU 0x21

TCNT				EQU	0x20	; Variable to count 123 interrupts for 2 second.
NUM_OF_OVERFLOWS 	EQU D'30' 	; 123
CURSOR_POS			EQU 0x22	; 0x8- for first row, 0xC- for second row

DIG_VAL				EQU 0x23	; to store current digit value
HAS_MAX				EQU 0x24	; indicate whether this digit is limited by an upper limit (65535) : Y:0xFF, N: 0x00
IS_MAX				EQU 0x25	; to store whether the current digit is at its limit (65535) : Y:0xFF, N: 0x00
MAX_ARR_IND			EQU 0x26	; array to hold the upper limits of each digit
								; from address 0x26 till 0x2A
CURR_ARR_IND		EQU 0x2B	; address of current index of the array

NUM1_HIGH			EQU 0x2C	; to store the first number high byte
NUM1_LOW			EQU 0x2D	; to store the first number low byte

NUM2_HIGH			EQU 0x2E	; to store the first number high byte
NUM2_LOW			EQU 0x2F	; to store the first number low byte

DIG_CNT				EQU 0x30	; to indicate the current digit index

IS_EQ				EQU 0x31	; store XOR reult of two numbers
LOOP_CNT			EQU 0x32	; to store loop count
TEMP				EQU 0x33
CURR_DISPLAY		EQU 0x34	; 0: NUM1, 1: OP, 2: NUM2, 3: RES, 4:keep,
								; 5: op_after_keep
CLICK_CNT			EQU 0x3A	; #of click in keep stage


OP_ARR 				EQU 0x35	; Array from 0x35 to 0x37
OP_ARR_TAIL			EQU 0x37
OP_ARR_IND			EQU 0x38	; index to OP_ARR
OP					EQU 0x39	; to store operation (0: +, 1: /, 2: %)
; 0x3A

NUMERATOR_HIGH 		EQU 0x3B
NUMERATOR_LOW  		EQU 0x3C
DENOMINATOR_HIGH 	EQU 0x3D
DENOMINATOR_LOW  	EQU 0x3E
COMP_DENOMINATOR_HIGH 	EQU 0x3F
COMP_DENOMINATOR_LOW  	EQU 0x40
QUOTIENT_HIGH 		EQU 0x41
QUOTIENT_LOW  		EQU 0x42
REMAINDER_HIGH 		EQU 0x43
REMAINDER_LOW 		EQU 0x44


TENS_ARR			EQU 0x45	; array to store the binary represntations of tens
								; from address 0x50 till 0x59
CURR_TENS_ARR_IND	EQU 0x50	; address of the current address of the array
TENS_TEMP			EQU 0x51	;

OPERAND1_HIGH		EQU 0x52
OPERAND1_LOW		EQU 0x53
OPERAND2_HIGH		EQU 0x54
OPERAND2_LOW		EQU 0x55
RESULT1_HIGH		EQU 0x56
RESULT1_LOW			EQU 0x57
RESULT2_HIGH		EQU 0x58
RESULT2_LOW			EQU 0x59
FLAG_REGISTER		EQU 0x5A
CARRY_FLAG			EQU 0x0
D5					EQU 0x5B
D4					EQU 0x5C
D3					EQU 0x5D
D2					EQU 0x5E
D1					EQU 0x5F
TEMP2				EQU	0x60
DIV_FLAG			EQU 0x61





; The instructions should start from here
	ORG 	0x00
	GOTO 	init


	ORG 	0x04
	GOTO 	ISR

;=================================================================================
; Program Initialization
;=================================================================================
init:

	;; initialize TCNT
	BANKSEL PORTA 				; move to Bank 0
	MOVLW 	NUM_OF_OVERFLOWS
	MOVWF 	TCNT				; TCNT = NUM_OF_OVERFLOWS

	;; initialize upper_limit array
	CALL 	INIT_MAX_ARR

	;; Setting pins and variables
	;; RB0 for button input
	BANKSEL TRISD				; move to Bank 1
	BSF 	TRISB, TRISB0		; Set RB0 as input


	;;setting Timer 0
	MOVLW 	b'00000111'			; set Timer0 prescaler to 256 (tick each 64us)
	MOVWF 	OPTION_REG			; move value to OPTION_REG

	;; Enable interrupts
	BANKSEL INTCON
	BSF 	INTCON, GIE			; Enable global interrupts
	BSF 	INTCON, TMR0IE 		; Enable Timer0 interrupts
	BSF 	INTCON, INTE		; Enable RB0 interrupt



	BANKSEL PORTD				; Move to Bank 0
	MOVLW 	0xC0
	MOVWF 	CURSOR_POS			; CURSOR_POS variable at the first column of the second row

	CLRF 	DIG_VAL				; DIG_VAL = 0
	CLRF 	CURR_DISPLAY		; CURR_DISPLAY = NUM1 (0)
	CLRF 	DIG_CNT				; DIG_CNT = 0
	CLRF 	IS_MAX				; IS_MAX = 0

	CLRF 	HAS_MAX
	COMF 	HAS_MAX, F			; HAS_MAX = 0xFF (First digit has alwayas an upperlimit of 6)

	CLRF 	OP					; OP = 0 (+)
	CALL 	INIT_OP_ARR

	CLRF	CLICK_CNT			;

	CLRF 	NUM1_HIGH			;
	CLRF 	NUM1_LOW			;
	CLRF 	NUM2_HIGH			;
	CLRF 	NUM2_LOW 			;

	;; initialize TENS_ARR
	CALL 	INIT_TENS_ARR 		;
	CLRF	FLAG_REGISTER


	BANKSEL PORTD				; Move to Bank 0

	GOTO 	start
;=================================================================================
; END OF Program Initialization
;=================================================================================


;=================================================================================
; Interrup Service Routine
;=================================================================================
ISR:
	BANKSEL INTCON

CHECK_BUTTON:
	BTFSC 	INTCON, INTF 		; Check if button int
	GOTO 	BUTTON_INT

CHECK_TIMER:
	BTFSC 	INTCON, TMR0IF 		; Check if timer int
	GOTO 	TIMER_INT

	BANKSEL PORTD
	retfie

	;--------------------------------------------------------------------
	; Button Interrupt
	;--------------------------------------------------------------------
BUTTON_INT:
	BANKSEL INTCON
	BCF 	INTCON, INTF		; Clear the raised interrupt bit
	BCF 	INTCON, INTE		; Disable button interrupt

	BANKSEL PORTD				; Move to Bank 0

	MOVLW 	d'30'
	CALL	xms
	BTFSC 	PORTB, RB0			; if button is still pressed
	GOTO 	CHECK_TIMER
	;; if displaying the result
	MOVLW	D'3'
	XORWF	CURR_DISPLAY, W
	BTFSC	STATUS, Z
	GOTO 	BACK_B

	;; if displaying the result
	MOVLW	D'6'
	XORWF	CURR_DISPLAY, W
	BTFSC	STATUS, Z
	GOTO 	BACK_B

	MOVLW	D'4'
	XORWF	CURR_DISPLAY, W
	BTFSC	STATUS, Z
	GOTO 	CHECK_CLICKS



	BTFSC 	CURR_DISPLAY,0		; if CURR_DISPLAY is 0 or 2, it is a number display
	CALL 	INC_OP				; change operation


	BTFSS 	CURR_DISPLAY,0
	CALL 	INC_DIGIT			; increment digit


BACK_B:

	BANKSEL INTCON
	BSF 	INTCON, INTE		; Enable button interrupt

	GOTO 	CHECK_TIMER			; Check Timer0 interrupt
	;--------------------------------------------------------------------
	; END OF Button Interrupt
	;--------------------------------------------------------------------

	;--------------------------------------------------------------------
	; Timer0 Interrupt
	;--------------------------------------------------------------------
TIMER_INT:
	BANKSEL INTCON
	BCF 	INTCON, TMR0IF		; clear ov bit
	BCF 	INTCON, TMR0IE 		; Disable timer0 interrupt


	BANKSEL PORTA				; Bank 0
	DECFSZ 	TCNT, F				; decrement TCNT and check if zero
	GOTO 	SKIP_INT_T			; skip interrupt handing

	;........................................
	; Timer0 Interrupt Handling
	;........................................
TIMER_HANDLING:

	BANKSEL PORTD
	INCF 	CURSOR_POS			; increment cursor position
	INCF 	DIG_CNT				; increment digit count

	CALL	PROCESS_CURRENT_DIGIT
	;; Check if DIG_CNT = 5 (end of the number)
	MOVLW 	D'5'
	XORWF 	DIG_CNT, W
	;; if not, continue to the next digit
	BTFSS 	STATUS, Z
	GOTO 	NEXT_DIGIT

	INCF 	CURR_DISPLAY
	CLRF 	DIG_CNT

	MOVLW	D'3'				; result stage
	XORWF	CURR_DISPLAY, W
	BTFSC	STATUS, Z
	GOTO	DISPLAY_RESULT

	MOVLW	D'4'				; keep stage
	XORWF	CURR_DISPLAY, W
	BTFSC	STATUS, Z
	GOTO	TIMER_KEEP_STAGE

	MOVLW	D'5'
	XORWF	CURR_DISPLAY, W
	BTFSC	STATUS, Z
	GOTO	OP_AFTER_KEEP

	MOVLW	D'6'
	XORWF	CURR_DISPLAY, W
	BTFSC	STATUS, Z
	GOTO	DISPLAY_RESULT

	;; Check the current display
	BTFSC 	CURR_DISPLAY,0		; if 0 or 2, it's a number
	GOTO 	NOT_NUM1

	GOTO 	FIRST_DIGIT

	;; If to display the op
NOT_NUM1:
	MOVLW 	MAX_ARR_IND			;
	MOVWF 	CURR_ARR_IND		; CURR_ARR_IND will point to the first index of the array
	MOVLW 	TENS_ARR			; ((ADDED))
	MOVWF 	CURR_TENS_ARR_IND	; ((ADDED)) CURR_ARR_IND will point to the first index of the array
	MOVLW 	D'4'				;
	MOVWF 	DIG_CNT				; DIG_CNT = 4, to be considered as the last character to be displayed in the current display
	MOVLW 	'+'
	CALL 	DISPLAY_OP

BACK_T:

	BANKSEL PORTA				; Bank 0

	;; Reset Timer

	MOVLW	D'3'
	XORWF	CURR_DISPLAY, W
	BTFSC	STATUS, Z
	GOTO 	THREE_SEC_DELAY

	MOVLW 	NUM_OF_OVERFLOWS
	MOVWF 	TCNT				; Reset TCNT Counter to NUM_OF_OVERFLOWS
	GOTO 	SKIP_INT_T

THREE_SEC_DELAY:
	MOVLW	D'46'
	MOVWF 	TCNT				; Reset TCNT Counter to NUM_OF_OVERFLOWS



SKIP_INT_T:

	BANKSEL TMR0				; Bank 0
	CLRF 	TMR0				; clear timer

	BANKSEL INTCON
	BSF 	INTCON, TMR0IE 		; Enable Timer0 interrupt

INT_END:

	BANKSEL PORTD				; Bank 0
	retfie

;=================================================================================
; END OF Interrup Service Routine
;=================================================================================


	INCLUDE "LCDIS.INC" ;

;=================================================================================
; Program Main Function
;=================================================================================
start:

	;; 10 ms deley, to start the LCD
	MOVLW	D'10'
	CALL 	xms

	;; init the LCD
	CALL 	inid

	;; Print
	CALL 	PRINT_ENTER_OPERATION


	;; Set the cursor on the first row of the second line
	MOVLW 	0xC0
	BCF 	Select, RS
	CALL	send

	;; display 0 for the first digit
	MOVLW '0'
	BSF 	Select, RS
	CALL 	send

	; return the cursor to the same position
	MOVLW 	0xC0
	BCF 	Select, RS
	CALL	send


	; Clear Timer 0 (Start Time counting now)
	BANKSEL PORTA				; Bank 0
	CLRF 	TMR0
	MOVLW	NUM_OF_OVERFLOWS
	MOVWF 	TCNT

	; make the cursor blink
	CALL 	BLINK_CURSOR

	;; end of the main finction (will be stuck here and will just handle interrupts)
loop:
	GOTO 	loop
;=================================================================================
; END OF Program Main Function
;=================================================================================


;=================================================================================
; TURN TIMER LED ON
;=================================================================================
LED_TURN_ON_T:

	BANKSEL PORTD
	BSF 	PORTD, RD2

	GOTO 	BACK_T
;=================================================================================
; END OF TURN TIMER LED ON
;=================================================================================


;=================================================================================
; TURN TIMER LED OFF
;=================================================================================
LED_TURN_OFF_T:

	BANKSEL PORTD
	BCF 	PORTD, RD2

	GOTO 	BACK_T
;=================================================================================
; END OF TURN TIMER LED OFF
;=================================================================================


;=================================================================================
; TURN BUTTON LED ON
;=================================================================================
LED_TURN_ON_B:

	BANKSEL PORTD
	BSF 	PORTD, RD3

	GOTO 	BACK_B
;=================================================================================
; END OF TURN BUTTON LED ON
;=================================================================================


;=================================================================================
; TURN BUTTON LED OFF
;=================================================================================
LED_TURN_OFF_B:

	BANKSEL PORTD
	BCF 	PORTD, RD3

	GOTO 	BACK_B
;=================================================================================
; END OF TURN BUTTON LED OFF
;=================================================================================



;=================================================================================
; Display "ENTER OPERATION" on LCD Function
;=================================================================================
PRINT_ENTER_OPERATION:

	BANKSEL INTCON
	BCF 	INTCON, GIE			; Disable global interrupts

	BANKSEL PORTA

	; move cursor to the the first column of first row
	BCF 	Select, RS
	MOVLW	0x80
	CALL 	send


	MOVLW 	'E'
	BSF 	Select, RS
	CALL 	send

	MOVLW 	'N'
	BSF 	Select, RS
	CALL 	send

	MOVLW 	'T'
	BSF 	Select, RS
	CALL 	send

	MOVLW 	'E'
	BSF 	Select, RS
	CALL 	send

	MOVLW 	'R'
	BSF 	Select, RS
	CALL 	send

	MOVLW 	' '
	BSF 	Select, RS
	CALL 	send

	MOVLW 	'O'
	BSF 	Select, RS
	CALL 	send

	MOVLW 	'P'
	BSF 	Select, RS
	CALL 	send

	MOVLW 	'E'
	BSF 	Select, RS
	CALL 	send

	MOVLW 	'R'
	BSF 	Select, RS
	CALL 	send

	MOVLW 	'A'
	BSF 	Select, RS
	CALL 	send

	MOVLW 	'T'
	BSF 	Select, RS
	CALL 	send

	MOVLW 	'I'
	BSF 	Select, RS
	CALL 	send

	MOVLW 	'O'
	BSF 	Select, RS
	CALL 	send

	MOVLW 	'N'
	BSF 	Select, RS
	CALL 	send

	BANKSEL INTCON
	BSF 	INTCON, GIE			; Enable global interrupts

	BANKSEL PORTA
	RETURN
;=================================================================================
; END OF Display "ENTER OPERATION" on LCD Function
;=================================================================================


;=================================================================================
; Initialize the MAX_ARR array values Function
;=================================================================================
INIT_MAX_ARR:

	BANKSEL PORTA
	MOVLW 	MAX_ARR_IND
	MOVWF 	CURR_ARR_IND
	MOVWF 	FSR
	MOVLW 	7
	MOVWF 	INDF
	INCF 	FSR,F

	MOVLW 	6
	MOVWF 	INDF
	INCF 	FSR,F

	MOVLW 	6
	MOVWF 	INDF
	INCF 	FSR,F

	MOVLW 	4
	MOVWF 	INDF
	INCF 	FSR,F

	MOVLW 	6
	MOVWF 	INDF

	RETURN
;=================================================================================
; END OF Initialize the MAX_ARR array values Function
;=================================================================================


;=================================================================================
; Increment Digit Function
;=================================================================================
INC_DIGIT:
	BANKSEL PORTA				; Bank 0
	;; Reset Timer
	MOVLW 	NUM_OF_OVERFLOWS
	MOVWF 	TCNT
	CLRF 	TMR0

	;; incerement the digit
	INCF 	DIG_VAL

	;; ckeck if reached the digit limit (65535)
	BTFSC 	HAS_MAX, 0
	CALL 	CHECK_MAX

	;; ckeck if exceeded 9
	MOVLW 	D'10'
	XORWF 	DIG_VAL,W
	BTFSC 	STATUS, Z		;skip next if it is not 10
	CLRF 	DIG_VAL

	;; display the digit
	MOVFW 	DIG_VAL
	CALL 	DISPLAY_DIGIT
	RETURN
;=================================================================================
; END OF Increment Digit Function
;=================================================================================


;=================================================================================
; Check if the digit reached its max limit Function
;=================================================================================
CHECK_MAX:
	CLRF 	IS_MAX

	MOVFW 	CURR_ARR_IND
	MOVWF 	FSR
	MOVFW 	INDF

	ADDLW 	0xFF 			;DECREMENT the MAX limit
	XORWF 	DIG_VAL,W
	BTFSC	STATUS, Z		;skip next if it is not max
	COMF 	IS_MAX, F


	MOVFW	 CURR_ARR_IND
	MOVWF 	FSR
	MOVFW 	INDF

	XORWF 	DIG_VAL,W

	BTFSS 	STATUS, Z		;skip next if > max
	RETURN

	CLRF 	DIG_VAL

	RETURN
;=================================================================================
; END OF Check if the digit reached its max limit Function
;=================================================================================


;=================================================================================
; Display Digit Function
;=================================================================================
DISPLAY_DIGIT:
	MOVWF 	TEMP

	MOVFW 	CURSOR_POS
	BCF 	Select, RS
	CALL	send

	MOVFW 	TEMP
	ADDLW 	'0'
	BSF 	Select, RS
	CALL 	send

	MOVFW 	CURSOR_POS
	BCF 	Select, RS
	CALL	send

	RETURN
;=================================================================================
; END OF Display Digit Function
;=================================================================================


;=================================================================================
; Display Digit with Cursor Increment Function
;=================================================================================
DISPLAY_DIGIT_WITH_INC:
	ADDLW 	'0'
	BSF 	Select, RS
	CALL 	send

	RETURN
;=================================================================================
; END OF Display Digit with Cursor Increment Function
;=================================================================================



;=================================================================================
; Change OP Function
;=================================================================================
INC_OP:
	BANKSEL PORTA			; Bank 0
	;; Reset Timer 0
	MOVLW 	NUM_OF_OVERFLOWS
	MOVWF 	TCNT
	CLRF 	TMR0


	INCF 	OP_ARR_IND
	INCF	OP

	MOVFW 	OP_ARR_IND
	MOVWF 	FSR
	MOVFW	OP
	MOVWF	IS_EQ
	MOVLW	D'3'
	XORWF	IS_EQ, F

	BTFSC	STATUS, Z
	GOTO	RESET_INDEX

	GOTO 	GET_OP

RESET_INDEX:
	CLRF	OP
	MOVLW	OP_ARR
	MOVWF	OP_ARR_IND
	MOVWF 	FSR

GET_OP:
	MOVFW 	INDF

	CALL 	DISPLAY_OP
	RETURN
;=================================================================================
; END OF Change OP Function
;=================================================================================


;=================================================================================
; Display OP Function (send op ASCII in W)
;=================================================================================
DISPLAY_OP
	BANKSEL PORTA
	MOVWF TEMP

	MOVFW 	CURSOR_POS
	BCF 	Select, RS
	CALL	send

	MOVFW 	TEMP
	BSF 	Select, RS
	CALL 	send

	MOVFW 	CURSOR_POS
	BCF 	Select, RS
	CALL	send

	RETURN
;=================================================================================
; END OF Display OP Function
;=================================================================================


;=================================================================================
; Initialize OP_ARR array values Function
;=================================================================================
INIT_OP_ARR:

	BANKSEL PORTA
	MOVLW 	OP_ARR
	MOVWF 	OP_ARR_IND
	MOVWF 	FSR
	MOVLW 	'+'
	MOVWF 	INDF
	INCF 	FSR,F

	MOVLW 	'/'
	MOVWF 	INDF
	INCF 	FSR,F

	MOVLW 	'%'
	MOVWF 	INDF

	RETURN

;=================================================================================
; Initialize OP_ARR array values Function
;=================================================================================


;=================================================================================
; Display Result Function
;=================================================================================
DISPLAY_RESULT:
	BANKSEL INTCON
	BCF 	INTCON, GIE			; Disable global interrupts

	BANKSEL PORTA

	MOVLW	D'3'
	MOVWF	CURR_DISPLAY

	MOVLW 	D'4'				;
	MOVWF 	DIG_CNT				; DIG_CNT = 4, so that the next interrupt the stage is incremented

	CLRF	CLICK_CNT


	;; Clear display screen
	BCF 	Select, RS
	MOVLW 	0x01
	CALL 	send

	;; Turn Off Cursor Display
	MOVLW	0x0C
	CALL	send

	;; Move cursor to the first column of the first row
	MOVLW 	0x80
	CALL	send

	;; PRINT "RESULT" on the first row
	BSF 	Select, RS
	MOVLW	'R'
	CALL	send

	MOVLW	'E'
	CALL	send

	MOVLW	'S'
	CALL	send

	MOVLW	'U'
	CALL	send

	MOVLW	'L'
	CALL	send

	MOVLW	'T'
	CALL	send


	;; Move cursor to the first column of the second row
	BCF 	Select, RS
	MOVLW 	0xC0
	MOVWF	CURSOR_POS
	CALL	send

	BSF 	Select, RS
	MOVLW 	'='
	CALL	send


	CALL 	CALCULATE_RESULT
;; TODO: REMOVE BOTH THE CALL AND THE FUNCTUIN
	;CALL 	DISPLAY_RES_NUM

	CLRF	OP
	MOVLW	OP_ARR
	MOVWF	OP_ARR_IND
	MOVLW 	D'4'				;
	MOVWF 	DIG_CNT				; DIG_CNT = 4, so that the next interrupt the stage is incremented

	BANKSEL INTCON
	BSF 	INTCON, GIE			; Enable global interrupts

	BANKSEL	PORTA

	GOTO 	BACK_T
;=================================================================================
; END OF Display Result Function
;=================================================================================


;=================================================================================
; Display Result Number Function
;=================================================================================
DISPLAY_RES_NUM:
	BANKSEL PORTA

	MOVFW 	NUM1_HIGH
	MOVWF 	NUMERATOR_HIGH

	MOVFW 	NUM1_LOW
	MOVWF 	NUMERATOR_LOW

	CALL 	DISPLAY_NUMBER

	MOVFW 	NUM2_HIGH
	MOVWF 	NUMERATOR_HIGH

	MOVFW 	NUM2_LOW
	MOVWF 	NUMERATOR_LOW

	CALL 	DISPLAY_NUMBER

	RETURN
;=================================================================================
; END OF Display Result Number Function
;=================================================================================


;=================================================================================
; Disable Timer
;=================================================================================
TIMER_KEEP_STAGE:
	BANKSEL	PORTA

	MOVLW 	D'4'				;
	MOVWF 	DIG_CNT				; DIG_CNT = 4, so that the next interrupt the stage is incremented


	;; if 0
	MOVLW	D'0'
	XORWF	CLICK_CNT, W
	BTFSC	STATUS, Z
	GOTO 	DEACTIVATE_TIMER

	MOVLW	D'1'
	XORWF	CLICK_CNT, W
	BTFSS	STATUS, Z
	GOTO 	BACK_T

	;; if 1
	INCF CURR_DISPLAY
	GOTO TIMER_HANDLING




DEACTIVATE_TIMER:
	BANKSEL INTCON
	BCF 	INTCON, TMR0IE 		; Disable timer0 interrupt

	BANKSEL PORTA				; Bank 0
	;; Move cursor to the first column of the first row
	BCF 	Select, RS
	MOVLW 	0x80
	CALL	send

	BANKSEL INTCON
	BCF 	INTCON, GIE			; Disable global interrupts

	BANKSEL PORTA				; Bank 0
	;; PRINT message on the first row
	BSF 	Select, RS
	MOVLW	'K'
	CALL	send

	MOVLW	'E'
	CALL	send

	MOVLW	'E'
	CALL	send

	MOVLW	'P'
	CALL	send

	MOVLW	'?'
	CALL	send

	MOVLW	' '
	CALL	send

	MOVLW	'['
	CALL	send

	MOVLW	'1'
	CALL	send

	MOVLW	':'
	CALL	send

	MOVLW	'Y'
	CALL	send

	MOVLW	','
	CALL	send

	MOVLW	' '
	CALL	send

	MOVLW	'2'
	CALL	send

	MOVLW	':'
	CALL	send

	MOVLW	'N'
	CALL	send

	MOVLW	']'
	CALL	send


	;; RESET Timer variables for the next time to be used
	MOVLW	D'46'
	MOVWF 	TCNT				; Reset TCNT Counter to 46 (3 sec)
	BANKSEL TMR0				; Bank 0
	CLRF 	TMR0				; clear timer

	BANKSEL INTCON
	BSF 	INTCON, GIE			; Enable global interrupts

	BANKSEL PORTA

	GOTO 	INT_END;
;=================================================================================
; END OF Disable Timer
;=================================================================================


;=================================================================================
; Check the number of clikcs in KEEP stage
;=================================================================================
CHECK_CLICKS:
	BANKSEL PORTA
	MOVLW	D'0'
	XORWF	CLICK_CNT, W
	BTFSC	STATUS, Z
	GOTO 	REACTIVATE_TIMER

	GOTO 	init

REACTIVATE_TIMER:
	;; RESET Timer variables for the next time to be used
	MOVLW	D'46'
	MOVWF 	TCNT				; Reset TCNT Counter to 46 (3 sec)
	BANKSEL TMR0				; Bank 0
	CLRF 	TMR0				; clear timer

	BCF 	INTCON, TMR0IF		; clear ov bit
	BSF 	INTCON, TMR0IE 		; Enable timer0 interrupt

	GOTO CHECK_CLICKS_END


CHECK_CLICKS_END:

	INCF	CLICK_CNT
	GOTO	BACK_B
;=================================================================================
; END OF Check the number of clikcs in KEEP stage
;=================================================================================


;=================================================================================
; OP_AFTER_KEEP
;=================================================================================
OP_AFTER_KEEP:
	BANKSEL PORTA				; Bank 0

	MOVLW 	D'4'				;
	MOVWF 	DIG_CNT				; DIG_CNT = 4, so that the next interrupt the stage is incremented



	;; Clear display screen
	BCF 	Select, RS
	MOVLW 	0x01
	CALL 	send

	CALL	PRINT_ENTER_OPERATION

;; Move cursor to the first column of the second row (op position)
	BCF 	Select, RS
	MOVLW 	0xC0
	MOVWF 	CURSOR_POS
	CALL	send
;;---------------------
;; DISPLAY FIRST NUM
;;---------------------
	MOVFW 	NUM1_HIGH
	MOVWF 	NUMERATOR_HIGH

	MOVFW 	NUM1_LOW
	MOVWF 	NUMERATOR_LOW

	CALL 	DISPLAY_NUMBER

	;; Move cursor to the seventh column of the second row (op position)
	BCF 	Select, RS
	MOVLW 	0xC6
	MOVWF 	CURSOR_POS
	CALL	send

;;---------------------
;; DISPLAY SECOND NUM
;;---------------------


	MOVFW 	NUM2_HIGH
	MOVWF 	NUMERATOR_HIGH

	MOVFW 	NUM2_LOW
	MOVWF 	NUMERATOR_LOW

	CALL 	DISPLAY_NUMBER




	;; Move cursor to the sixth column of the second row (op position)
	BCF 	Select, RS
	MOVLW 	0xC5
	MOVWF 	CURSOR_POS
	CALL	send

	CLRF	OP

	BSF 	Select, RS
	MOVLW 	'+'
	CALL 	DISPLAY_OP

	CALL 	BLINK_CURSOR

	MOVLW	D'5'
	MOVWF	CURR_DISPLAY

	GOTO	BACK_T

;=================================================================================
; END OF OP_AFTER_KEEP
;=================================================================================


;=================================================================================
; NEXT_DIGIT
;=================================================================================
NEXT_DIGIT:
;	CALL	PROCESS_CURRENT_DIGIT
	INCF 	CURR_ARR_IND		; Increment the index of max limit array
	INCF	CURR_TENS_ARR_IND
	INCF	CURR_TENS_ARR_IND
	CLRF 	DIG_VAL				; clear the digit value
	CLRW						; clear the Accumulator
	CALL 	DISPLAY_DIGIT		; Display the digit '0'

	CLRF 	HAS_MAX				; clear HAS_MAX idicator for the next digit
	;; Check if the number so far is at its max limit (65535)
	BTFSS 	IS_MAX, 0
	GOTO 	BACK_T
	; if it is:
	CLRF 	IS_MAX				; IS_MAX = 0
	CLRF 	HAS_MAX
	COMF 	HAS_MAX, F			; HAS_MAX = 0xFF
	GOTO 	BACK_T				; switch the led
;=================================================================================
; END OF NEXT_DIGIT
;=================================================================================

;=================================================================================
; FIRST_DIGIT
;=================================================================================
FIRST_DIGIT:
	CLRF 	IS_MAX				; IS_MAX = 0
	CLRF 	HAS_MAX
	COMF 	HAS_MAX, F

	MOVLW	MAX_ARR_IND
	MOVWF	CURR_ARR_IND
	CLRF 	DIG_VAL				; clear the digit value
	CLRW						; clear the Accumulator
	CALL 	DISPLAY_DIGIT		; Display the digit '0'
	GOTO 	BACK_T				; switch the led
;=================================================================================
; FIRST_DIGIT
;=================================================================================


;=================================================================================
; PROCESS_CURRENT_DIGIT
;=================================================================================
PROCESS_CURRENT_DIGIT:
	BANKSEL PORTA
	MOVLW	0x00
	XORWF	DIG_VAL, W
	BTFSC	STATUS, Z
	RETURN

	MOVLW	0x0				; NUM1
	XORWF	CURR_DISPLAY, W
	BTFSC	STATUS, Z
	GOTO	TENS_LOOP_START1

	MOVLW	D'2'				; NUM2
	XORWF	CURR_DISPLAY, W
	BTFSC	STATUS, Z
	GOTO	TENS_LOOP_START2

	RETURN

TENS_LOOP_START1:

	; PERFORM ADDITION FOR LOW
	MOVFW 	CURR_TENS_ARR_IND
	MOVWF 	FSR
	MOVFW 	INDF 	; ACCUMULATOR NOW HAS THE BINARY FROM TENS
	ADDWF	NUM1_LOW, F

	; ADD CARRY IF EXISTS
	BTFSC   STATUS, C
	INCF    NUM1_HIGH, 1

	; PERFORM ADDITION FOR HIGH
	INCF	CURR_TENS_ARR_IND
	MOVFW	CURR_TENS_ARR_IND
	MOVWF 	FSR
	MOVFW 	INDF 	; ACCUMULATOR NOW HAS THE BINARY FROM TENS
	ADDWF 	NUM1_HIGH, 1

	DECF	CURR_TENS_ARR_IND,F
	DECFSZ	DIG_VAL, 1
	GOTO	TENS_LOOP_START1
	RETURN

TENS_LOOP_START2:

	; PERFORM ADDITION FOR LOW
	MOVFW 	CURR_TENS_ARR_IND
	MOVWF 	FSR
	MOVFW 	INDF 	; ACCUMULATOR NOW HAS THE BINARY FROM TENS
	ADDWF	NUM2_LOW, F

	; ADD CARRY IF EXISTS
	BTFSC   STATUS, C
	INCF    NUM2_HIGH, 1

	; PERFORM ADDITION FOR HIGH
	INCF	CURR_TENS_ARR_IND
	MOVFW	CURR_TENS_ARR_IND
	MOVWF 	FSR
	MOVFW 	INDF 	; ACCUMULATOR NOW HAS THE BINARY FROM TENS
	ADDWF 	NUM2_HIGH, 1

	DECF	CURR_TENS_ARR_IND,F
	DECFSZ	DIG_VAL, 1
	GOTO	TENS_LOOP_START2
	RETURN
;=================================================================================
; END OF PROCESS_CURRENT_DIGIT
;=================================================================================


;=================================================================================
; Initialize the TENS_ARR with the binary representation value
;=================================================================================
INIT_TENS_ARR:

	BANKSEL PORTA
	MOVLW 	TENS_ARR
	MOVWF 	CURR_TENS_ARR_IND
	MOVWF 	FSR

	MOVLW 	B'00010000'
	MOVWF 	INDF
	INCF 	FSR,F

	MOVLW 	B'00100111'
	MOVWF 	INDF
	INCF 	FSR,F

	MOVLW 	B'11101000'
	MOVWF 	INDF
	INCF 	FSR,F

	MOVLW 	B'00000011'
	MOVWF 	INDF
	INCF 	FSR,F

	MOVLW 	B'01100100'
	MOVWF 	INDF
	INCF 	FSR,F

	MOVLW 	B'00000000'
	MOVWF 	INDF
	INCF 	FSR,F

	MOVLW 	B'00001010'
	MOVWF 	INDF
	INCF 	FSR,F

	MOVLW 	B'00000000'
	MOVWF 	INDF
	INCF 	FSR,F

	MOVLW 	B'00000001'
	MOVWF 	INDF
	INCF 	FSR,F

	MOVLW 	B'00000000'
	MOVWF 	INDF

	RETURN
;=================================================================================
; END OF Initialize the TENS_ARR with the binary representation value
;=================================================================================


;=================================================================================
; DIVISION FUNCTION
;	add description
;=================================================================================
DIV:
	BANKSEL PORTA

	CLRF 	QUOTIENT_HIGH
	CLRF 	QUOTIENT_LOW
	CLRF 	REMAINDER_HIGH
	CLRF 	REMAINDER_LOW

	MOVFW 	DENOMINATOR_LOW
	MOVWF	COMP_DENOMINATOR_LOW

	MOVFW 	DENOMINATOR_HIGH
	MOVWF	COMP_DENOMINATOR_HIGH

	; 1's comp of DENOMINATOR_LOW
	COMF	COMP_DENOMINATOR_LOW

	; 1's comp of DENOMINATOR_HIGH
	COMF	COMP_DENOMINATOR_HIGH

	; 2's comp of DENOMINATOR
	INCFSZ	COMP_DENOMINATOR_LOW
	GOTO DIV_LOOP			; if there is a carry, add to high byte
	INCF	COMP_DENOMINATOR_HIGH


DIV_LOOP:
	CLRF	DIV_FLAG
	;; increment Q
	INCFSZ	QUOTIENT_LOW
	GOTO 	DONE_INC_Q
	INCF	QUOTIENT_HIGH
	;NOP

DONE_INC_Q:

	; N Low = N low - D_low
	MOVFW	COMP_DENOMINATOR_LOW
	ADDWF	NUMERATOR_LOW, F

	; propagate carry
	BTFSS	STATUS, C
	GOTO	COMP_HIGH

	INCFSZ	NUMERATOR_HIGH
	GOTO	COMP_HIGH

	BSF		DIV_FLAG, 0

COMP_HIGH:
	; N High = N High - D High
	MOVFW	COMP_DENOMINATOR_HIGH
	ADDWF	NUMERATOR_HIGH, F

	BTFSC	DIV_FLAG, 0
	GOTO	DIV_LOOP

	; if no carry (N < D)
	BTFSS	STATUS, C
	GOTO 	DONE

	GOTO 	DIV_LOOP

DONE:

	;; Decrement Q
	;; check if Q low is 0
	MOVLW 	0x0
	XORWF	QUOTIENT_LOW, W
	BTFSC	STATUS, Z
	GOTO	DEC_Q_HIGH

	DECF 	QUOTIENT_LOW
	GOTO	CALC_REM

DEC_Q_HIGH:
	DECF	QUOTIENT_HIGH
	;;----

CALC_REM:
	;; Get R
	;; R = N (current) + D
	MOVFW	DENOMINATOR_LOW
	ADDWF	NUMERATOR_LOW, W
	MOVWF	REMAINDER_LOW

	;; ?????????????
	BTFSC	STATUS, C
	INCF	REMAINDER_HIGH

	MOVFW	DENOMINATOR_HIGH
	ADDWF	NUMERATOR_HIGH, W
	ADDWF	REMAINDER_HIGH, F

    RETURN
;=================================================================================
; END OF DIVISION FUNCTION
;=================================================================================


;=================================================================================
; Display Number FUNCTION
;---------------------------------------------------------------------------------
; 	argumnets: Number to display on 2 bytes: NUMERATOR_HIGH, NUMERATOR_LOW
;	Display to LCD
;=================================================================================
DISPLAY_NUMBER:

	BANKSEL PORTA


	;; divide by 10000
	MOVLW	0x10
	MOVWF	DENOMINATOR_LOW
	MOVLW	0x27
	MOVWF	DENOMINATOR_HIGH

	CALL 	DIV

	MOVFW	QUOTIENT_LOW
	MOVWF	D5

;;--------------------------------
	MOVFW	REMAINDER_HIGH
	MOVWF	NUMERATOR_HIGH

	MOVFW	REMAINDER_LOW
	MOVWF	NUMERATOR_LOW

	;; divide by 1000
	MOVLW	0xE8
	MOVWF	DENOMINATOR_LOW
	MOVLW	0x03
	MOVWF	DENOMINATOR_HIGH

	CALL 	DIV

	MOVFW	QUOTIENT_LOW
	MOVWF	D4
	;;-------------------------------
	MOVFW	REMAINDER_HIGH
	MOVWF	NUMERATOR_HIGH

	MOVFW	REMAINDER_LOW
	MOVWF 	NUMERATOR_LOW


	;; divide by 100
	MOVLW	0x64
	MOVWF	DENOMINATOR_LOW
	MOVLW	0x00
	MOVWF	DENOMINATOR_HIGH

	CALL 	DIV

	MOVFW	QUOTIENT_LOW
	MOVWF	D3
;;-------------------------------

	MOVFW	REMAINDER_HIGH
	MOVWF	NUMERATOR_HIGH

	MOVFW	REMAINDER_LOW
	MOVWF 	NUMERATOR_LOW

	;; divide by 10
	MOVLW	0x0A
	MOVWF	DENOMINATOR_LOW
	MOVLW	0x00
	MOVWF	DENOMINATOR_HIGH

	CALL 	DIV

	MOVFW	QUOTIENT_LOW
	MOVWF	D2

	MOVFW	REMAINDER_LOW
	MOVWF	D1

	BTFSS	FLAG_REGISTER, CARRY_FLAG
	GOTO DISPLAY

	MOVLW	D'6'
	ADDWF	D1, F		; D1 = D1 + 6
	MOVLW	D'10'
	SUBWF	D1, W
	BTFSS	STATUS, C	; if D1>=10
	GOTO 	D1_DONE

	MOVLW	D'10'
	SUBWF	D1, F
	INCF	D2

D1_DONE:
;------------------------

	MOVLW	D'3'
	ADDWF	D2, F		; D1 = D1 + 6
	MOVLW	D'10'
	SUBWF	D2, W
	BTFSS	STATUS, C	; if D1>=10
	GOTO 	D2_DONE

	MOVLW	D'10'
	SUBWF	D2, F
	INCF	D3

D2_DONE:
;------------------------

	MOVLW	D'5'
	ADDWF	D3, F		; D1 = D1 + 6
	MOVLW	D'10'
	SUBWF	D3, W
	BTFSS	STATUS, C	; if D1>=10
	GOTO 	D3_DONE

	MOVLW	D'10'
	SUBWF	D3, F
	INCF	D4

D3_DONE:
;------------------------
	MOVLW	D'5'
	ADDWF	D4, F		; D1 = D1 + 6
	MOVLW	D'10'
	SUBWF	D4, W
	BTFSS	STATUS, C	; if D1>=10
	GOTO 	D4_DONE

	MOVLW	D'10'
	SUBWF	D4, F
	INCF	D5

D4_DONE:
;------------------------
	MOVLW	D'6'
	ADDWF	D5, F		; D1 = D1 + 6
	MOVLW	D'10'
	SUBWF	D5, W
	BTFSS	STATUS, C	; if D1>=10
	GOTO 	D5_DONE

	MOVLW	D'10'
	SUBWF	D5, F

	MOVLW	0x01
	CALL DISPLAY_DIGIT_WITH_INC

D5_DONE:
;------------------------
DISPLAY:

	MOVFW D5
	CALL DISPLAY_DIGIT_WITH_INC

	MOVFW D4
	CALL DISPLAY_DIGIT_WITH_INC

	MOVFW D3
	CALL DISPLAY_DIGIT_WITH_INC

	MOVFW D2
	CALL DISPLAY_DIGIT_WITH_INC

	MOVFW D1
	CALL DISPLAY_DIGIT_WITH_INC

    RETURN

;=================================================================================
; END OF Display Number FUNCTION
;=================================================================================

;=================================================================================
; ADDITION FUNCTION
;=================================================================================
ADD:
	BANKSEL PORTA
	CLRF	RESULT1_LOW
	CLRF	RESULT1_HIGH
	BCF		FLAG_REGISTER, CARRY_FLAG

	MOVFW 	NUM1_HIGH
	MOVWF	RESULT1_HIGH

	MOVFW	NUM1_LOW
	MOVWF	RESULT1_LOW
	MOVFW	NUM2_LOW
	ADDWF	RESULT1_LOW, F

	BTFSS	STATUS, C
	GOTO	ADD_NUM2_HIGH_BYTE

	INCFSZ	RESULT1_HIGH
	GOTO	ADD_NUM2_HIGH_BYTE

	BSF		FLAG_REGISTER, CARRY_FLAG


ADD_NUM2_HIGH_BYTE:
	MOVFW	NUM2_HIGH
	ADDWF	RESULT1_HIGH, F

	BTFSC	STATUS, C
	BSF		FLAG_REGISTER, CARRY_FLAG

	RETURN
;=================================================================================
; END OF ADDITION FUNCTION
;=================================================================================

;=================================================================================
; CALCULATE RESULT
;=================================================================================
CALCULATE_RESULT:
	BANKSEL PORTA

	MOVLW	0x00
	XORWF	OP, W
	BTFSC	STATUS, Z
	GOTO	ADD_OP

	GOTO 	DIV_NUMS

ADD_OP:
	CALL	ADD
	MOVFW 	RESULT1_HIGH
	MOVWF 	NUMERATOR_HIGH
	MOVFW 	RESULT1_LOW
	MOVWF 	NUMERATOR_LOW
	CALL 	DISPLAY_NUMBER
	BCF		FLAG_REGISTER, CARRY_FLAG
	RETURN

DIV_NUMS:
	MOVLW	0x00
	XORWF	NUM2_HIGH, W
	BTFSS	STATUS, Z
	GOTO	PROCESS_DIV

	MOVLW	0x00
	XORWF	NUM2_LOW, W
	BTFSC	STATUS, Z
	CALL	PRINT_DIV_ERR

PROCESS_DIV:
	MOVFW	NUM1_LOW
	MOVWF	NUMERATOR_LOW

	MOVFw	NUM1_HIGH
	MOVWF	NUMERATOR_HIGH

	MOVFW	NUM2_LOW
	MOVWF	DENOMINATOR_LOW

	MOVFW	NUM2_HIGH
	MOVWF	DENOMINATOR_HIGH

	CALL 	DIV

	MOVFW 	REMAINDER_HIGH
	MOVWF	TEMP2

	MOVFW 	REMAINDER_LOW
	MOVWF	TEMP

	MOVLW	0x02
	XORWF	OP, W
	BTFSC	STATUS, Z
	GOTO	MOD_OP

	BSF		Select, RS
	MOVLW	'Q'
	CALL	send
	MOVLW	'='
	CALL	send



	MOVFW 	QUOTIENT_HIGH
	MOVWF 	NUMERATOR_HIGH
	MOVFW 	QUOTIENT_LOW
	MOVWF 	NUMERATOR_LOW
	CALL 	DISPLAY_NUMBER

	MOVLW	' '
	CALL	send
	MOVLW	'R'
	CALL	send
	MOVLW	'='
	CALL	send

MOD_OP:
	MOVFW 	TEMP2
	MOVWF 	NUMERATOR_HIGH
	MOVFW 	TEMP
	MOVWF 	NUMERATOR_LOW
	CALL 	DISPLAY_NUMBER

	RETURN


;=================================================================================
; END OF CALCULATE RESULT
;=================================================================================


;=================================================================================
; DISPLAY DIV BY ZERO ERRO MESSAG
;=================================================================================
PRINT_DIV_ERR:
	BSF		Select, RS
	MOVLW	'E'
	CALL	send
	MOVLW	'R'
	CALL	send
	MOVLW	'R'
	CALL	send
	MOVLW	'!'
	CALL	send
	MOVLW	' '
	CALL	send
	MOVLW	'D'
	CALL	send
	MOVLW	'I'
	CALL	send
	MOVLW	'V'
	CALL	send
	MOVLW	' '
	CALL	send
	MOVLW	'B'
	CALL	send
	MOVLW	'Y'
	CALL	send
	MOVLW	' '
	CALL	send
	MOVLW	'0'
	CALL	send
	RETURN
;=================================================================================
; END OF DISPLAY DIV BY ZERO ERRO MESSAG
;=================================================================================

	END
