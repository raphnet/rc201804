section .text

%define effect_height(h) ((h) * SCREEN_WIDTH / 8)

eff_checkboard:
	push ax
	push bx
	push cx
	push dx
	push di

	setMapMask 0xF; all planes

	; write mode 2
	mov dx, VGA_GC_PORT
	mov al, VGA_GC_MODE_IDX
	mov ah, 2
	out dx, ax


	mov bp, SCREEN_HEIGHT
	mov bl, 0x55 ; bit mask
	mov bh, 0x0 ; color (black)
.loop:
		mov cx, SCREEN_WIDTH / 8
.scanline:
			mov al, [es:di]

			; Set bit mask
			;mov dx, VGA_GC_PORT
			mov ah, bl
			mov al, VGA_GC_BIT_MASK_IDX
			out dx, ax

			; write color
			mov [es:di], bh

			inc di
		loop .scanline
		not bl
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

	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret
