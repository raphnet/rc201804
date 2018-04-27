section .text

	;;;;; messageScreen_start
	;
	; Prepare for a message screen by saving the screen content and
	; then applying a checkerboard effect to darken the playfield. Then
	; display the message top and bottom borders, and fill.
	;
messageScreen_start:
	push ax
	push bx
	push cx
	push dx

	call savescreen
	mov cx, effect_height(200)
	call eff_checkboard

	mov bx,40
	mov cx, 32
	mov ax, 0
	call clearLinesRange

	mov bx, 40
	mov cx, 4
	mov al, 3
	call clearLinesRange

	mov bx, 56
	mov cx, 4
	mov al, 3
	call clearLinesRange

	pop dx
	pop cx
	pop bx
	pop ax

	ret

	;;;;; messageScreen_end
	;
	; Restore the screen after a mesage
	;
messageScreen_end:
	push ax
	push bx
	push cx

	mov bx,40
	mov cx, 32
	mov ax, 0
	call clearLinesRange

	call restorescreen

	pop cx
	pop bx
	pop ax

	ret

	;;;; messageSCreen_drawText_prepare
	;
	; Prepare AX and BX for calling drawtext based on length
	; of string pointed by DX.
	;
	; Returns with AX and BX set for centered string
messageScreen_drawText_prepare:
	mov ax, 160
	call subHalfStrwidthFromAX
	mov bx, 46
	ret

