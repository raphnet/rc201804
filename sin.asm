section .data

sinlut: incbin "sinlut.bin"

section .text

	;;;; Lookup the sinus of an angle
	; AX : Angle in degrees
	;
	; returns sin(angle) * 1000 in AX
sin:
	push bx
	push cx
	push dx

_sin_positive:
	; Condition angle (0 to 360) by modulo
	xor dx,dx ; clear remainder
	mov bx, 360
	div bx ; ax/bx. remainder in dx

	mov cx, 0 ; No inversion
	push cx

	cmp dx, 180
	jl _positive_sin

	pop cx
	mov cx, 1 ; Inversion
	push cx

	mov cx, 359
	sub cx, dx
	mov dx, cx

_positive_sin:
	; At this point, angle is in DX and between 0 and 179
	cmp dx, 90 ; 0-89 (rising)
	jl _sin_dolut
	mov cx, 179
	sub cx, dx
	mov dx, cx

_sin_dolut:
	mov bx, sinlut
	shl dx, 1		; sinlut is a table of words
	add bx, dx 		; Point bx to the proper word
	mov ax, [bx]	; Get the sinus value into AX

	pop cx
	and cx,cx
	jz _sin_noinv

	neg ax

_sin_noinv:
	pop dx
	pop cx
	pop bx
	ret


