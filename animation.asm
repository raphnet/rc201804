%define MAX_ANIMATIONS		8

section .text

%macro animationFastForward 1
mov byte [fastForwardAnimation], %1
%endmacro

animationNormal:
	ret

initAnimations:
	call clearAnimations
	animationFastForward	0
	ret

clearAnimations:
	push bx
	push cx

	mov cx, MAX_ANIMATIONS
	mov bx, animations
clearanim_lp:
	mov word [bx], 0
	add bx, 2
	loop clearanim_lp

	pop cx
	pop bx
	ret

	;;;;
	; AX : X
	; BX : Y
	; DX : Animation pointer
moveAnimation:
	push ax
	push bx
	push dx

	xchg bx, dx
	mov [bx+3], ax ; X
	mov [bx+5], dx ; Y

	pop dx
	pop bx
	pop ax
	ret

	;;;;
	;
	; AX : Animation ID (< MAX_ANIMATIONS)
	; BX : Animation pointer
registerAnimation:
	push ax
	push bx
	push cx

	shl ax, 1
	add ax, animations
	xchg ax,bx
	mov [bx], ax

	pop cx
	pop bx
	pop ax
	ret

	;;;;
	;
	; AX : Animation ID
clearAnimation:
	push bx
		mov bx, ax
		shl bx, 1
		add bx, animations
		mov word [bx], 0
	pop bx
	ret

	;;;
	; bx : Animation pointer
	;
	; Structure:
	;	db num_images
	;	db current_image
	;	db current_count
	;	dw X, Y
	;	db first_tile_id
	;	db timing[num_images]
doAnimate:
	push ax
	push bx
	push cx

	mov al, [bx+7] ; First tile
	add al, [bx+1] ; Current image
	xor ah,ah
	call getTile16
	push bx
		; Load X,Y and draw
		mov ax, [bx+3]
		mov bx, [bx+5]
		call blit_tile16XY
	pop bx

	mov al, [bx+1] ; Current image
	xor ah, ah
	push bx
		add bx, ax
		add bx, 8 ; Offset for first timing value
		mov al, [bx] ; Timing in al
	pop bx

	cmp byte [fastForwardAnimation], 0
	jne _da_next_frame

	; Count cycles
	mov ah, [bx+2] ; Current count
	inc ah
	mov [bx+2], ah

	cmp ah, al
	jg _da_next_frame
	jmp _da_done

_da_next_frame:
	mov byte [bx+2], 0 ; Clear cycle cnt
	mov al, [bx+1] ; Cur frame
	inc al
	mov [bx+1], al

	mov cl, [bx] ; Num images
	cmp al, cl
	jge _da_image0
	jmp _da_done

_da_image0:
	mov byte [bx+1], 0 ; current image

_da_done:
	pop cx
	pop bx
	pop ax
	ret

	;;;;;;;;;;;;;;;;;;;;
	; Processes up to 8 animations (see animations and doAnimate)
	; Call once per frame.
	;
runAnimations:
	push ax
	push bx
	push cx
	push es
	push di
	push si
	call setupVRAMpointer

	mov cx, MAX_ANIMATIONS
	mov bx, animations
runAnim_loop:
	mov ax, [bx]
	and ax,ax
	jz ra_skip
	push bx
		mov bx, ax
		call doAnimate
	pop bx
ra_skip:

	add bx, 2
	loop runAnim_loop

	pop si
	pop di
	pop es
	pop cx
	pop bx
	pop ax
	ret

section .data

section .bss

fastForwardAnimation: resb 1
animations: resw MAX_ANIMATIONS
