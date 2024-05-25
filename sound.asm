sndeffect_shoot_hit:
	push ax
	push cx
	push dx
		mov ax, 700
		mov cx, 4
		mov dx, 0
		call pcspkr_tone_on
	pop dx
	pop cx
	pop ax
	ret

sndeffect_shoot_miss:
	push ax
	push cx
	push dx
		mov ax, 100
		mov cx, 2
		mov dx, 800
		call pcspkr_tone_on
	pop dx
	pop cx
	pop ax
	ret


sndeffect_missed:
	push ax
	push cx
	push dx
		mov ax, 80
		mov cx, 50
		mov dx, 100
		call pcspkr_tone_on
	pop dx
	pop cx
	pop ax
	ret

sndeffect_newdrop:
	push ax
	push cx
	push dx
		mov ax, 1000
		mov cx, 8
		mov dx, -26
		call pcspkr_tone_on
	pop dx
	pop cx
	pop ax
	ret



