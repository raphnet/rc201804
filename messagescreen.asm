section .text

%define TEXTFONT_HEIGHT	8
%define MSGBOX_HEIGHT	32
%define MSGBOX_ORG_Y	(SCREEN_HEIGHT/2-MSGBOX_HEIGHT/2)
%define MSGBOX_BORDER_THICKNESS	4
%define MSGBOX_TEXT_Y	(SCREEN_HEIGHT/2-TEXTFONT_HEIGHT/2)

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
	mov cx, effect_height(SCREEN_HEIGHT)
	call eff_checkboard

	; Message background (clear)
	mov bx, MSGBOX_ORG_Y
	mov cx, MSGBOX_HEIGHT
	mov ax, 0
	call clearLinesRange

	; Top border
	mov bx, MSGBOX_ORG_Y
	mov cx, MSGBOX_BORDER_THICKNESS
	mov al, 3
	call clearLinesRange

	; Bottom border
	mov bx, MSGBOX_ORG_Y + MSGBOX_HEIGHT - MSGBOX_BORDER_THICKNESS
	mov cx, MSGBOX_BORDER_THICKNESS
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

;	mov bx,40
;	mov cx, 32
;	mov ax, 0
;	call clearLinesRange

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
	mov ax, SCREEN_WIDTH/2
	call subHalfStrwidthFromAX
	mov bx, MSGBOX_TEXT_Y
	ret

