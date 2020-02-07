;********************************************************************
; Excercise program: Lab 2 EEEN40280
; Using timer interrupt to generate variable frequency square wave 
; author        : 	Hamza Afridi and Ho Bao Anh Le
; Date          : 	30 January 2020
;
; File          : 	excercise.asm
;
; Hardware      : 	ADuC841 with clock frequency 11.0592 MHz
;
; Description   : 	Variable frequency generated at P3.6
;					Frequency selected from P2 (only 3 bits used)
;                 	Continuous status blinking LED at P3.4
;
;********************************************************************


; Include the ADuC841 SFR definitions
$NOMOD51
$INCLUDE (MOD841)

LED     EQU     P3.4      	; P3.4 is red LED on eval board
SIG		EQU		P3.6	  	; P3.6 is the pin where square wave is generated
BLINKFLAG EQU	07h			; Using bit addressable memory location to store blink flag. 0 and 1 are blinking off and on respectively.

CSEG
		ORG 	0000h		; set origin at start of code segment
		JMP		MAIN		; jump to main program
		
		ORG		002Bh		; timer 0 overflow interrupt address
		JMP		TF2ISR		; jump to interrupt service routine
		
		ORG		03h			; external interrupt address
		JMP		EXINT0ISR	; jump to interrupt service routine	

		ORG		0060h		; set origin above interrupt addresses	

SIGTAB: DW 37888,45056,47104,48256,50176,51712,58624,62080; Table to generate variable frequency
;********************************************************************
; SIGTAB table definition
;	This is a lookup table to 8 different frequencies 
;
;
;	cycles required	=	11059200/(frequency * 2)
;	recall value	=	2^16 - (cycles required)
;
;********************************************************************
;	frequency (Hz)	:	cycles required	:	recall value
;********************************************************************
;	200					27648				37888
;	270					20480				45056
;	300					18432				47104
;	320					17280				48256
;	360					15360				50176
;	400					13824				51712
;	800					6912				58624
;	1600				3456				62080
;********************************************************************

LEDTAB: DB 254,253,251,247,239,223,191,127; Table to generate one hot led on port 
;********************************************************************
; LEDTAB table definition
; 	Lookup table to generate one-hot LED display on P0. To turn LED on we need to write LOW on that pin.
;
;********************************************************************
;	binary		:		decimal
;********************************************************************
;	11111110			254
;	11111101			253
;	11111011			251
;	11110111			247
;	11101111			239
;	11011111			223
;	10111111			191
;	01111111			127
;********************************************************************

MAIN:	
; ------ Setup part - happens once only ----------------------------
		MOV		T2CON, #00000000b	; timer 2 mode 0, not gated
		SETB	IT0					; set external interrupt 0 to falling edge
		MOV		IE, #10100001b		; enable timer 2 interrupt and external interrupt 0
		SETB	PT2					; set timer 2 interrupt at higher priority
		SETB	TR2					; start timer 2
		MOV 	P2, #0FFh			; configure P2 as input	
		SETB	BLINKFLAG			; initially set BLINKFLAG	
		

; ------ Infinite Loop -------------
LOOP:	NOP
		JNB		BLINKFLAG, LOOP	; Skip reading port and blinking when BLINKFLAG is 0
		MOV		DPTR, #LEDTAB 	; Store the address of LEDTAB table
		MOV		A, P2			; read values from port 2 and store it in A
		ANL 	A, #00000111b	; discard 5 most significant bits
		MOVC	A,@A+DPTR		; select appropriate value from LEDTAB based on the offset stored in A
		MOV		P0,A			; write value to port 0
		CPL		LED				; complement status led
		CALL	DELAY			; wait for a delay
		JMP	LOOP			; jump to label LOOP

DELAY:    ; delay for time 100 ms. 
			MOV	  R5, #100d		; set number of repetitions for outer loop
DLY2:   	MOV   R7, #144		; middle loop repeats 144 times         
DLY1:   	MOV   R6, #24   	; inner loop repeats 24 times      
        	DJNZ  R6, $			; inner loop 24 x 3 cycles = 72 cycles            
        	DJNZ  R7, DLY1		; + 5 to reload, x 144 = 11093 cycles
			DJNZ  R5, DLY2		; + 5 to reload x 100 times = 1109300 cycles = 100 ms
        	RET					; return from subroutine

		
; ------ Interrupt service routine ---------------------------------	
TF2ISR:		; timer 2 overflow interrupt service routine
		CLR 	TF2				; clear timer 2 overflow flag
		PUSH	ACC				; store the value of A  in stack
		MOV		DPTR, #SIGTAB	; store starting address of SIGTAB table
		MOV 	A, P2			; move value of P2 to A
		ANL 	A, #00000111b	; discard 5 most significant bits
		RL 		A				; rotate left is equivalent to rotate left
		PUSH 	ACC				; push the A to stack again
		MOVC	A, @A+DPTR		; access address with offset 
		MOV		RCAP2H,A		; update recall higher bits first
		POP 	ACC				; pop A from stack
		INC		A				; increment by 1 to access neighboring byte
		MOVC 	A, @A+DPTR		; access address with offset
		MOV		RCAP2L,A		; update recall lower bits later
		CPL		SIG				; flip bit to generate output
		POP 	ACC				; pop A from stack to be reused in the program
		RETI					; return from interrupt
; ------------------------------------------------------------------	

; ------ Interrupt service routine ---------------------------------	
EXINT0ISR:		; External Interrupt 0
		CLR		EX0				; disable external interrupt 
		SETB	LED				; turn off the LED
		CALL 	DELAY			; delay
		JB		P3.2, DONE		; if P3.2 the interrupt pin is not low don't change the flag
		CPL		BLINKFLAG		; invert the value in BLINKFLAG
DONE
		SETB	EX0				; enable external interrupt
		RETI					; return from interrupt
; ------------------------------------------------------------------	

END