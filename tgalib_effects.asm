section .text

%define effect_height(h)	((h) * 250 / 200)

; cx : Effect height (See effect_height macro)
eff_checkboard:
	push bx
	push dx
	mov bx, 0xF0F0 ; Even scanlines
	mov dx, 0x0F0F ; Odd scanlines
	call eff_andpixels
	pop dx
	pop bx
	ret

;;;;;;;;; Fade screen to black
; es : Video memory base
; cx : Effect height (See effect_height macro)
;
; 1: Half of the intensity bits are cleared
; 2: The remaining intensiry bits are cleared
; 3: Checkboard (black)
; 4: Clear (black)
eff_colorfade:
	push bx
	push cx
	push dx

	call waitVertRetrace
	call waitVertRetrace
	call waitVertRetrace
	call waitVertRetrace

	; Clear half of the intensity bits
	mov bx, 0x7F7F
	mov dx, 0xF7F7
	call eff_andpixels

	call waitVertRetrace
	call waitVertRetrace
	call waitVertRetrace
	call waitVertRetrace

	; Clear the other intensity bits
	mov bx, 0x7777
	mov dx, 0x7777
	call eff_andpixels

	call waitVertRetrace
	call waitVertRetrace
	call waitVertRetrace
	call waitVertRetrace

	; Checkboard
	call eff_checkboard

	call waitVertRetrace
	call waitVertRetrace
	call waitVertRetrace
	call waitVertRetrace

	; clearScreen could be called, if only the height
	; could be specified.
	mov bx, 0
	mov dx, bx
	call eff_andpixels

	call waitVertRetrace
	call waitVertRetrace
	call waitVertRetrace
	call waitVertRetrace

	pop dx
	pop cx
	pop bx
	ret

;;;;;;;;; And values with pixels
; es : Video memory base
; cx : Effect height (See effect_height macro)
eff_andpixels:
	push ax
	push di
	push si
	push ds
	push cx
	push bp

	mov ax, es
	mov ds, ax

	mov di, 0
	mov si, di
	mov bp, cx ; Save cx

_cb_lp1:
	%rep 16
		lodsw
		and ax, bx
		stosw
	%endrep
	loop _cb_lp1

	mov di, 0x2000
	mov si, di
	mov cx, bp
_cb_lp2:
	%rep 16
		lodsw
		and ax, dx
		stosw
	%endrep
	loop _cb_lp2

	mov di, 0x4000
	mov si, di
	mov cx, bp
_cb_lp3:
	%rep 16
		lodsw
		and ax, bx
		stosw
	%endrep
	loop _cb_lp3

	mov di, 0x6000
	mov si, di
	mov cx, bp
_cb_lp4:
	%rep 16
		lodsw
		and ax, dx
		stosw
	%endrep
	loop _cb_lp4

	pop bp
	pop cx
	pop ds
	pop si
	pop di
	pop ax
	ret


;;;;;;;;;;;; Make all colors 0 or 8
; es : Video memory base
; cx : Effect height (See effect_height macro)
eff_bw:
	push ax
	push di
	push si
	push ds
	push bx
	push dx
	push cx

	mov ax, es
	mov ds, ax

	mov di, 0
	mov si, di

	shl cx, 1
	shl cx, 1
	mov bp, cx

	mov dx, 4

_eff_bw_next_plane:

	mov cx, bp
	push dx
	push bp
	mov dx, 0x6666
	mov bp, 0x8888
_bw_lp:
%macro greyish 0
		lodsw
		and ax, dx
		jz %%_bw_sk
		mov bx, ax
		shl bx, 1
		or ax, bx
		shl ax, 1
		and ax, bp
%%_bw_sk:
		stosw
%endmacro
	greyish
	greyish
	greyish
	greyish
	loop _bw_lp
	pop bp
	pop dx

	and di, 0xE000
	add di, 0x2000
	mov si, di

	dec dx
	jne _eff_bw_next_plane


	pop cx
	pop dx
	pop bx
	pop ds
	pop si
	pop di
	pop ax

	ret

