section .text

%define effect_height(h)	((h) * 250 / 200)

eff_checkboard:
	push bx
	push dx
	mov bx, 0xCCCC ; Even scanlines
	mov dx, 0x3333 ; Odd scanlines
	call eff_andpixels
	pop dx
	pop bx
	ret

;;;;;;;; Keep only red values (orange becomes red, green turns off)
; cx : Effect height (See effect_height macro)
eff_reddish:
	push bx
	push dx

	mov bx, 0xAAAA
	mov dx, 0xAAAA
	call eff_andpixels

	pop dx
	pop bx
	ret

;;;;;;;; Keep only green values
; cx : Effect height (See effect_height macro)
eff_greenish:
	push bx
	push dx

	mov bx, 0x5555
	mov dx, 0x5555
	call eff_andpixels

	pop dx
	pop bx
	ret

;;;;;;;; Keep only red values (orange becomes red, green turns off)
; cx : Effect height (See effect_height macro)
eff_greenish_then_to_red:
	push bx
	push dx

	mov bx, 0x5555
	mov dx, 0x5555
	call eff_andshlpixels

	pop dx
	pop bx
	ret



;;;;;;;;; Fade screen to black
; es : Video memory base
; cx : Effect height (See effect_height macro)
;
; 1: Green becomes red, orange becomes black (even scanlines)
; 1: Green becomes red, orange becomes black (odd scanlines)
; 2: checkboard red screen
; 3: clear screen (black)
eff_colorfade:
	push bx
	push cx
	push dx

	call waitVertRetrace
	call waitVertRetrace
	call waitVertRetrace
	call waitVertRetrace

	mov bx, 0xBBBB
	mov dx, 0xEEEE
	call eff_andpixels

	call waitVertRetrace
	call waitVertRetrace
	call waitVertRetrace
	call waitVertRetrace

	mov bx, 0xEEEE
	mov dx, 0xBBBB
	call eff_andpixels

	call waitVertRetrace
	call waitVertRetrace
	call waitVertRetrace
	call waitVertRetrace

	call eff_checkboard

	call waitVertRetrace
	call waitVertRetrace
	call waitVertRetrace
	call waitVertRetrace

	; clearScreen could be called, if only the height
	; could be specified.
	mov bx, 0
	mov dx, bx
	call eff_andshlpixels

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

	mov ax, es
	mov ds, ax

	mov di, 0
	mov si, di

_cb_lp1:
	%rep 16
		lodsw
		and ax, bx
		stosw
	%endrep
	loop _cb_lp1

	mov di, 0x2000
	mov si, di
	pop cx
	push cx
_cb_lp2:
	%rep 16
		lodsw
		and ax, dx
		stosw
	%endrep
	loop _cb_lp2

	pop cx
	pop ds
	pop si
	pop di
	pop ax
	ret

;;;;;;;;; And values with pixels, then shift values one to the left
; es : Video memory base
; cx : Effect height (See effect_height macro)
eff_andshlpixels:
	push ax
	push di
	push si
	push ds
	push cx

	mov ax, es
	mov ds, ax

	mov di, 0
	mov si, di
_ccb_lp1:
	%rep 16
		lodsw
		and ax, bx
		shl ax, 1
		stosw
	%endrep
	loop _ccb_lp1

	mov di, 0x2000
	mov si, di
	pop cx
	push cx
_ccb_lp2:
	%rep 16
		lodsw
		and ax, dx
		shl ax, 1
		stosw
	%endrep
	loop _ccb_lp2

	pop cx
	pop ds
	pop si
	pop di
	pop ax
	ret


;;;;;;;;; ADD values to pixels
; es : Video memory base
; cx : Effect height (See effect_height macro)
eff_addpixels:
	push ax
	push di
	push si
	push ds
	push cx

	mov ax, es
	mov ds, ax

	mov di, 0
	mov si, di
_acb_lp1:
	%rep 16
		lodsw
		add ax, bx
		stosw
	%endrep
	loop _acb_lp1

	mov di, 0x2000
	mov si, di
	pop cx
	push cx
_acb_lp2:
	%rep 16
		lodsw
		add ax, dx
		stosw
	%endrep
	loop _acb_lp2

	pop cx
	pop ds
	pop si
	pop di
	pop ax
	ret

;;;;;;;;; SUB values from pixels
; es : Video memory base
; cx : Effect height (See effect_height macro)
eff_subpixels:
	push ax
	push di
	push si
	push ds
	push cx

	mov ax, es
	mov ds, ax

	mov di, 0
	mov si, di
_scb_lp1:
	%rep 16
		lodsw
		sub ax, bx
		stosw
	%endrep
	loop _scb_lp1

	mov di, 0x2000
	mov si, di
	pop cx
	push cx
_scb_lp2:
	%rep 16
		lodsw
		sub ax, dx
		stosw
	%endrep
	loop _scb_lp2

	pop cx
	pop ds
	pop si
	pop di
	pop ax
	ret

;;;;;;;;; Shift pixel values on time to the left
; es : Video memory base
; cx : Effect height (See effect_height macro)
eff_shlpixels:
	push ax
	push di
	push si
	push ds
	push cx

	mov ax, es
	mov ds, ax

	mov di, 0
	mov si, di
_shcb_lp1:
	%rep 16
		lodsw
		shl ax, 1
		stosw
	%endrep
	loop _shcb_lp1

	mov di, 0x2000
	mov si, di
	pop cx
	push cx
_shcb_lp2:
	%rep 16
		lodsw
		shl ax, 1
		stosw
	%endrep
	loop _shcb_lp2

	pop cx
	pop ds
	pop si
	pop di
	pop ax
	ret


