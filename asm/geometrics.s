.include "durango_hw.inc"
.include "crt0.inc"
.PC02

.export _fillScreen
.export _drawPixel
.export _strokeRect
.export _fillRect

.import incsp3
.import incsp5
.importzp  sp

;-----------------------------------------------------------------------
; FILL SCREEN
;-----------------------------------------------------------------------
.proc _fillScreen: near
    LDX #>SCREEN_3
    STX VMEM_POINTER+1
    LDY #<SCREEN_3
    STY VMEM_POINTER
    loop:
    STA (VMEM_POINTER), Y
    INY
    BNE loop
	INC VMEM_POINTER+1
    BPL loop
    RTS
.endproc

;-----------------------------------------------------------------------
; DRAW PIXEL
;-----------------------------------------------------------------------
.proc _drawPixel: near
    ; Load x coord
    LDY #$02
    LDA (sp), Y
	TAX						; input for PLOT routine
    
    ; Load y coord
    LDY #$01
    LDA (sp), Y
    TAY						; input for PLOT routine

    ; Load color
;	LDY #$00
	LDA (sp)				; CMOS does not need ,Y
	STA COLOUR				; input for PLOT routine (actually px_col)
    
	JSR dxplot				; must call as it has many exit points
	JMP incsp3   			; Remove args from stack... and exit procedura

; *** input ***
; X = x coordinate (<128 in colour, <256 in HIRES)
; Y = y coordinate (<128 in colour, <256 in HIRES)
px_col	= COLOUR			; colour in II format (17*index, HIRES reads d7 only)

; *** zeropage usage ***
cio_pt	= VMEM_POINTER		; (screen pointer)
fw_cbyt	= TEMP1				; (temporary storage, could be elsewhere)

; *** usual addresses ***
IO8attr	= VIDEO_MODE		; compatible IO8lh for setting attributes (d7=HIRES, d6=INVERSE, now d5-d4 include screen block)

dxplot:
	STZ cio_pt				; common to all modes (3)
	TYA						; get Y coordinate... (2)
	LSR
	ROR cio_pt
	LSR
	ROR cio_pt				; divide by 4 instead of times 64, already OK for colour (2+5+2+5)
	BIT IO8attr				; check screen mode (4)
	BPL colplot				; * HIRES plot below * (3/2 for COLOUR/HIRES)
		LSR
		ROR cio_pt			; divide by 8 instead of times 32! (2+5)
		STA cio_pt+1		; LSB ready, temporary MSB (3)
		LDA IO8attr			; get flags... (4)
		AND #$30			; ...for the selected screen... (2)
		ASL					; ...and shift them to final position (2)
		ORA cio_pt+1
		STA cio_pt+1		; full pointer ready! (3+3)
		TXA					; get X coordinate (2)
		LSR
		LSR
		LSR					; 8 pixels per byte (2+2+2)
		TAY					; this is actual indexing offset (2)
		TXA					; X again (2)
		AND #7				; MOD 8 (2)
		TAX					; use as index (2)
		LDA pixtab, X		; get pixel within byte (4)
		BIT px_col			; check colour to plot (4*)
		BPL unplot_h		; alternative clear routine (2/3)
			ORA (cio_pt), Y		; add to previous data (5/ + 6/ + 6/)
			STA (cio_pt), Y
			RTS
unplot_h:
		EOR #$FF			; * HIRES UNPLOT * negate pattern (/2)
		AND (cio_pt), Y		; subtract pixel from previous data (/5 + /6 + /6)
		STA (cio_pt), Y
		RTS
colplot:
	STA cio_pt+1			; LSB ready, temporary MSB (3)
	LDA IO8attr				; get flags... (4)
	AND #$30				; ...for the selected screen... (2)
	ASL						; ...and shift them to final position (2)
	ORA cio_pt+1			; add to MSB (3+3)
	STA cio_pt+1
	TXA						; get X coordinate (2)
	LSR						; in half (C is set for odd pixels) (2)
	TAY						; this is actual indexing offset (2)
	LDA #$0F				; _inverse_ mask for even pixel (2)
	LDX #$F0				; and colour mask for it (2)
	BCC evpix
		LDA #$F0			; otherwise is odd (3/2+2+2 for even/odd)
		LDX #$0F
evpix:
	AND (cio_pt), Y			; keep original data in byte... (5)
	STA fw_cbyt				; store temporarily (4*)
	TXA						; retrieve mask... (2)
	AND px_col				; extract active colour bits (4*)
	ORA fw_cbyt				; ...adding new pixel (4*)
	STA (cio_pt), Y			; EEEEEEEEK (6+6)
	RTS
.endproc

;-----------------------------------------------------------------------
; STROKE RECT
;-----------------------------------------------------------------------
.proc _strokeRect:near
    ; Load x coord
    LDY #$04
    LDA (sp), Y
    
    ; Load y coord
    LDY #$03
    LDA (sp), Y
    
    ; Load color
    LDY #$00
    LDA (sp), Y
    
    ; Load height
    LDY #$01
    LDA (sp), Y

    ; Load width
    LDY #$02
    LDA (sp), Y
    

    ; Remove args from stack
    JSR incsp5
    RTS
.endproc


;-----------------------------------------------------------------------
; FILL RECT
;-----------------------------------------------------------------------
.proc _fillRect:near
    ; Load x coord
    LDY #$04
    LDA (sp), Y
	STA X_COORD
	
    ; Load y coord
    LDY #$03
    LDA (sp), Y
    STA Y_COORD
	
    ; Load color
;	LDY #$00
	LDA (sp)				; CMOS does not need ,Y
	STA COLOUR
    
    ; Load height
    LDY #$01
    LDA (sp), Y
	STA HEIGHT
	
    ; Load width
    LDY #$02
    LDA (sp), Y
    STA WIDTH

	JSR fill_xywh			; must be called as has a few exit points

    ; Remove args from stack... and return to caller
    JMP incsp5

; *** input ***
x1	= X_COORD				; NW corner x coordinate (<128 in colour, <256 in HIRES)
y1	= Y_COORD				; NW corner y coordinate (<128 in colour, <256 in HIRES)
wid	= WIDTH
x2	= WIDTH					; alternatively, width (will be converted into x1,x2 format)
hei = HEIGHT
y2	= HEIGHT				; alternatively, height (will be converted into y1,y2 format)
col	= COLOUR				; pixel colour, in II format (17*index), HIRES expects 0 (black) or $FF (white)

; *** zeropage usage and local variables ***
cio_pt	= VMEM_POINTER		; screen pointer

; *** other variables (not necessarily in zero page) ***
exc		= TEMP1				; flag for incomplete bytes at each side (could be elshewhere) @ $21
tmp		= exc+1				; temporary use (could be elsewhere)
lines	= tmp+1				; raster counter (could be elsewhere)
bytes	= lines+1			; drawn line width (could be elsewhere)
l_ex	= bytes+1			; extra W pixels (id, HIRES only)
r_ex	= l_ex+1			; extra E pixels (id, HIRES only) @ $26

; *** Durango definitions ***
IO8attr= VIDEO_MODE			; compatible IO8lh for setting attributes (d7=HIRES, d6=INVERSE, now d5-d4 include screen block)

; *** interface for (x,y,w,h) format ***
fill_xywh:
	LDA wid
	BEQ exit				; don't draw anything if zero width!
	CLC
	ADC x1
	STA x2					; swap width for East coordinate
	LDA hei
	BEQ exit				; don't draw anything if zero height!
	CLC
	ADC y1
	STA y2					; swap height for South coordinate
; may now compute number of lines and bytes *** (bytes could be done later, as differs from HIRES)
	LDA x1					; lower limit
	LSR						; check odd bit into C
	LDA x2					; higher limit...
	ADC #0					; ...needs one more if lower was odd
	SEC
	SBC x1					; roughly number of pixels
	LSR						; half of that, is bytes
	ROR exc					; E pixel is active, will end at D6 (after second rotation)
	STA bytes
; number of lines is straightforward
	LDA y2
	SEC
	SBC y1
	STA lines				; all OK
; compute NW screen address (once)
	LDA y1					; get North coordinate... (3)
	STA cio_pt+1			; will be operated later
	LDA #0					; this will be stored at cio_pt
	LSR cio_pt+1
	ROR
	LSR cio_pt+1
	ROR						; divide by 4 instead of times 64, already OK for colour (2+5+2+5)
	BIT IO8attr				; check screen mode (4)
		BPL colfill
		BMI hrfill			; jump to HIRES routine
exit:
		RTS
colfill:
	STA cio_pt				; temporary storage
	LDA x1					; get W coordinate
	LSR						; halved
	ROR exc					; this will store W extra pixel at D7
	CLC						; as we don't know previous exc contents
	ADC cio_pt
	STA cio_pt				; LSB ready, the ADD won't cross page
	LDA IO8attr				; get flags... (4)
	AND #$30				; ...for the selected screen... (2)
	ASL						; ...and shift them to final position (2)
	ORA cio_pt+1			; add to MSB (3+3)
	STA cio_pt+1
c_line:
; first draw whole bytes ASAP
		LDA col				; get colour index twice
		LDY bytes			; number of bytes, except odd E
			BEQ c_sete		; only one pixel (E), manage separately
		DEY					; maximum offset
			BEQ c_setw		; only one pixel (W), manage separately
cbytloop:
			STA (cio_pt), Y	; store whole byte
			DEY
			BNE cbytloop	; do not reach zero
c_exc:
; check for extra pixels
		BIT exc				; check uneven bits
		BVS c_setw			; extra at W (or BMI?)
		BMI c_sete			; extra at E (or BVS?)
			STA (cio_pt), Y	; otherwise last byte is full
			BRA c_eok
c_setw:
		AND #$0F			; keep rightmost pixel colour
		STA tmp				; mask is ready
		LDA (cio_pt), Y		; get original screen contents! (Y=0)
		AND #$F0			; filter out right pixel...
		ORA tmp				; ...as we fill it now
		STA (cio_pt), Y
		BIT exc				; unfortunately we must do this, or manage W pixel first
		BPL c_eok			; no extra bit at E (or BVC?)
			LDA col			; in case next filter gets triggered
c_sete:
			LDY bytes		; this is now the proper index!
			AND #$F0		; keep leftmost pixel
			STA tmp			; mask is ready
			LDA (cio_pt), Y	; get original screen contents!
			AND #$0F		; filter out left pixel...
			ORA tmp			; ...as we fill it now
			STA (cio_pt), Y
c_eok:
; advance to next line
		LDA #$40			; OK for colour
		CLC
		ADC cio_pt
		STA cio_pt
		BCC cl_nowrap
			INC cio_pt+1
cl_nowrap:
		DEC lines
		BNE c_line			; repeat for remaining lines
	RTS
; *** HIRES version ***
hrfill:
; finish proper Y-address computation
	LSR cio_pt+1
	ROR						; divide by 8 instead of times 32 in HIRES mode
	STA cio_pt				; temporary storage
	LDA IO8attr				; get flags... (4)
	AND #$30				; ...for the selected screen... (2)
	ASL						; ...and shift them to final position (2)
	ORA cio_pt+1			; add to MSB (3+3)
	STA cio_pt+1
; lines is OK, but both 'bytes' and new l_ex & r_ex values must be recomputed, plus 'exc'
; determine extra EW pixels
	LDA x2
	AND #7					; modulo 8
	STA r_ex				; 0...7 extra E pixels
	CMP #1					; Carry if >0
	ROR exc					; E pixels present, flag will end at D6 (after second rotation)
	LDA x1
	AND #7					; modulo 8
	STA l_ex				; 0...7 extra W pixels
	CMP #1					; Carry if >0
	ROR exc					; W pixels present, flag at D7
; compute bytes
	LDA exc					; get flags...
	ASL						; ...and put W flag into carry
	LDA x2
	SEC
	SBC x1					; QUICK AND DIRTY**********
	LSR
	LSR
	LSR
	STA bytes				; ...give or take
; add X offset
	LDA x1
	LSR
	LSR
	LSR						; NW / 8
	CLC
	ADC cio_pt
	STA cio_pt				; no C is expected
h_line:
; first draw whole bytes ASAP
		LDA col				; get 'colour' value (0=black, $FF=white)
		LDY bytes			; number of bytes, except extra E
			BEQ h_sete		; only extra E pixels, manage separately
		DEY					; maximum offset
			BEQ h_setw		; only extra W pixels, manage separately
hbytloop:
			STA (cio_pt), Y	; store whole byte
			DEY
			BNE hbytloop	; do not reach zero
h_exc:
; check for extra pixels
		BIT exc				; check uneven bits
		BVS h_setw			; extra at W (or BMI?)
		BMI h_sete			; extra at E (or BVS?)
			STA (cio_pt), Y	; otherwise last byte is full
			BRA h_eok
h_setw:
		LDX l_ex			; get mask index
		AND w_mask, X		; keep rightmost pixels
		STA tmp				; mask is ready
		LDA w_mask, X		; get mask again...
		EOR #$FF			; ...inverted
		AND (cio_pt), Y		; extract original screen intact pixels... (Y=0)
		ORA tmp				; ...as we add the remaining ones now
		STA (cio_pt), Y
		BIT exc				; unfortunately we must do this, or manage W pixel first
		BPL h_eok			; no extra bit at E (or BVC?)
			LDA col			; in case next filter gets triggered
h_sete:
			LDY bytes		; this is now the proper index!
			AND e_mask, X	; keep leftmost pixels
			STA tmp			; mask is ready
			LDA e_mask, X	; get mask again...
			EOR #$FF		; ...inverted
			AND (cio_pt), Y	; extract original screen intact pixels... (Y=0)
			ORA tmp			; ...as we add the remaining ones now
			STA (cio_pt), Y
h_eok:
; advance to next line
		LDA #$20			; OK for HIRES
		CLC
		ADC cio_pt
		STA cio_pt
		BCC hl_nowrap
			INC cio_pt+1
hl_nowrap:
		DEC lines
		BNE h_line			; repeat for remaining lines
	RTS
.endproc


;-----------------------------------------------------------------------
; DATA
;-----------------------------------------------------------------------
; *** data ***
; _drawPixel
pixtab:
	.byt	128, 64, 32, 16, 8, 4, 2, 1		; bit patterns from offset
; _drawFillRect
e_mask:
	.byt	0, %10000000, %11000000, %11100000, %11110000, %11111000, %11111100, %11111110	; [0] never used
w_mask:
	.byt	0, %00000001, %00000011, %00000111, %00001111, %00011111, %00111111, %01111111	; [0] never used
