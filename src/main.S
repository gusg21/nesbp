;;; INES Header
; 1x16k program, 1x8k graphics, no mapper.
INESPRG 1
INESCHR 1
INESMAP 0
INESMIR 1

;;; Macros

CTRL_STATE 			EQU $0001
CTRL_A 				EQU %10000000
CTRL_B 				EQU %01000000
CTRL_SELECT 		EQU %00100000
CTRL_START 			EQU %00010000
CTRL_UP 			EQU %00001000
CTRL_DOWN 			EQU %00000100
CTRL_LEFT 			EQU %00000010
CTRL_RIGHT 			EQU %00000001

PLAYERSPR_Y EQU $0200
PLAYERSPR_S EQU $0201
PLAYERSPR_C EQU $0202
PLAYERSPR_X EQU $0203

MACRO _SETPLAYERPOS x,y
	LDA #y
	STA PLAYERSPR_Y
	LDA #x
	STA PLAYERSPR_X
ENDM

;;; RESET handler

ORG $C000
RESET:
	SEI             ; disable IRQ
	CLD             ; disable decimal mode
	
	LDX #$40        ; disable IRQs from the APU 
	STX $4017
	
	LDX #$FF
	TXS             ; set SP = 255

	INX             ; make x = 0
	STX $2000       ; disable NMI
	STX $2001       ; disable sprites and background
	STX $4010       ; disable DMC IRQs
	
vblankwait1:
	; Crazy shenanigans for checking BIT 7 of the PPUSTATUS to wait for VBLANK.
	; Essentially, BIT 7 of $2002 is set when VBLANK is hit, which is put into the
	; negative flag by BIT. BPL will then loop back if this flag is _not_ set,
	; so once the flag is set we break out of the loop (fallthrough).
	BIT $2002
	BPL vblankwait1
	
clrmem:
	LDA #$00        ; A = 0
	@loop:
	STA $0000,X    ; store 0 -> $0000+x
	STA $0100,X    ; ...
	STA $0200,X
	STA $0300,X
	STA $0400,X
	STA $0500,X
	STA $0600,X
	STA $0700,X
	; LDA #$FE
	; STA $0300, x  ; store $FE -> $0300+x (why?)
	INX             ; x++
	BNE @loop      	; branch to loop start if x != 0
	
vblankwait2:
	BIT $2002
	BPL vblankwait2 ; see vblankwait1

; Copies data from "palette" into PPU palette memory.
loadpalettes:
	LDA $2002		; read PPUSTATUS to reset high/low latch (internal PPU trickery)
	
	LDA #$3F
	STA $2006		; write high byte of $3F00
	LDA #$00		
	STA $2006		; low byte
	
	LDX #$00
	@loop:
	LDA palette,X
	STA $2007		; write pallete+x into the PPU memory (via register)
	INX
	CPX #$20
	BNE @loop		; stop when x == 32 (0x20)
	

; Sprite stuffz
; We are using $0200-$02FF for our OAM source data for DMA.
	_SETPLAYERPOS $80,$80
	LDA #$00
	STA PLAYERSPR_S ; tile number = 0
	STA PLAYERSPR_C	; color = 0, no flipping

	LDA #%10000000  ; enable NMI, sprites from Pattern Table 0
	STA $2000

	LDA #%00010000  ; enable sprites
	STA $2001

forever:
	JMP forever     ; infinite loop

;;; NMI handler

NMI:
readinput:
	LDA #$01
	STA $4016
	LDA #$00
	STA $4016    	; tell both the controllers to latch buttons
	
	; A = 0
	STA CTRL_STATE  ; clear CTRL_STATE
	LDX #$00
	-
	ASL CTRL_STATE	; shift CTRL_STATE left
	LDA $4016		; read button state into A
	AND #%00000001  ; mask off the bit we want
	ORA CTRL_STATE  ; OR with the existing state
	STA CTRL_STATE 	; store our result
	INX				; only run this loop 8x
	CPX #$08
	BCC -
	
playermove:
	; Move right
	LDA CTRL_STATE
	AND #CTRL_RIGHT
	BEQ +
	INC PLAYERSPR_X
	+

	; Move left
	LDA CTRL_STATE
	AND #CTRL_LEFT
	BEQ +
	DEC PLAYERSPR_X
	+

	; Move up
	LDA CTRL_STATE
	AND #CTRL_UP
	BEQ +
	DEC PLAYERSPR_Y
	+

	; Move down
	LDA CTRL_STATE
	AND #CTRL_DOWN
	BEQ +
	INC PLAYERSPR_Y
	+

copyoammirror:
	LDA #$00
  	STA $2003  		; write to beginning (0 offset) of OAM
  	LDA #$02
  	STA $4014  		; read from the page beginning at $0200 (our OAM mirror) and begin 
					; the copy
	
	RTI            

;;; ROM Data

palette:
  .db $0F,$31,$21,$23,$0F,$35,$36,$37,$0F,$39,$3A,$3B,$0F,$3D,$3E,$0F
  .DB $0F,$31,$21,$23,$0F,$02,$38,$3C,$0F,$1C,$15,$14,$0F,$02,$38,$3C

;;; Vectors

ORG $FFFA
DW NMI
DW RESET
DW 0

;;; CHR-ROM

INCBIN "chr/main.chr"