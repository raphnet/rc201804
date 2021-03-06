section .text

; May seem pointless here, but used in CGA and TANDY libs
%define effect_height(h) (h)

;;;;;; eff_checkboard : Cover the screen with black pixels, in a checkboard pattern.
;
; cx : Effect height (See effect_height macro)
;
eff_checkboard:
	push ax
	push bx
	push cx
	push dx
	push di
	push bp

	setMapMask 0xF; all planes

	; write mode 2
	mov dx, VGA_GC_PORT ; Note: DX set here, also re-used below
	mov al, VGA_GC_MODE_IDX
	mov ah, 2
	out dx, ax

	;mov bp, SCREEN_HEIGHT
	mov bp, cx ; Argument: Number of lines to apply the effect on, starting from top of screen
	mov bl, 0x55 ; bit mask
	mov bh, 0x00 ; color (black)

.loop:
		; Set bit mask
		;mov dx, VGA_GC_PORT
		not bl ; invert bitmask on each scanline for checkboard effect
		mov ah, bl ; Bitmask in dh
		mov al, VGA_GC_BIT_MASK_IDX
		out dx, ax

		mov cx, SCREEN_WIDTH / 8
		mov al, bh ; Color in AL for stosb
.scanline:
			mov ah, [es:di]
			stosb
		loop .scanline

		dec bp
	jnz .loop

	; write mode
	;mov dx, VGA_GC_PORT
	mov al, VGA_GC_MODE_IDX
	mov ah, 0
	out dx, ax

	;mov dx, VGA_GC_PORT
	mov ah, 0xff
	mov al, VGA_GC_BIT_MASK_IDX
	out dx, ax

	pop bp
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret
