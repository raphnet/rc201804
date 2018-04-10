section .text

;;;; blit_tile8XY : Blit a 8x8 tile to a destination coordinate
;
; ds:si : Pointer to tile data
; es:di : Video memory base (b800:0)
; ax: X coordinate (in pixels) (ANDed with 0xfffc)
; bx: Y coordinate (in pixels) (ANDed with 0xfffe)
blit_tile8XY:
	push ax
	push bx
	push cx
	push dx ; clobbered by MUL
	push di

	mov di, bx
	shl di, 1
	add di, cgarows
	mov di, [di]

	; X /= 4 (4 pixel per memory byte)
	mov cl, al
	and cl, 03h
	shr ax, 1
	shr ax, 1
	add di, ax ; Offset in line

	; Y /= 2 (only support even scanlines)
;	shr bx, 1
;	pushf

	; Y *=80 (skip to target row)
;	mov ax, 80
;	mul bx

;	add di, ax
;	popf
	test di, 0x2000
	jnz _bt8_odd
	call blit_tile8_even_y
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret
_bt8_odd:
	call blit_tile8_odd_y
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret

;;;; blit_tile8 : Blit a 8x8 tile to a specified screen location.
; ds:si : Pointer to tile data
; es:di : Offset (in video memory) (Note: Must be on an even line)
;
; cl: X offset (0-3)
;
; Due to the CGA low-res packing arrangement, the offset value given
; in byte places the tile on a grid of 4 pixels.
blit_tile8_even_y:
	push si
	push di

	cmp cl, 1
	je blit_tile8_even_y_x1
	cmp cl, 2
	je blit_tile8_even_y_x2
	cmp cl, 3
	je blit_tile8_even_y_x3
%macro movsw_post_add 1
	movsw
	add di, %1
%endmacro

	movsw_post_add 78
	movsw_post_add 78
	movsw_post_add 78
	movsw_post_add 0x2000 - (80*3) -2
	movsw_post_add 78
	movsw_post_add 78
	movsw_post_add 78
	movsw
	pop di
	pop si
	ret

blit_tile8_odd_y:
	push si
	push di

	cmp cl, 1
	je blit_tile8_odd_y_x1
	cmp cl, 2
	je blit_tile8_odd_y_x2
	cmp cl, 3
	je blit_tile8_odd_y_x3

;	add di, 0x2000
	movsw_post_add 78
	movsw_post_add 78
	movsw_post_add 78
	movsw
	sub di, 0x2000 + 80*2 + 2
	movsw_post_add 78
	movsw_post_add 78
	movsw_post_add 78
	movsw

	pop di
	pop si
	ret

	;;; X=1
blit_tile8_even_y_x1:
	mov cl, 2 ; shift
%macro cpWord_extra_byte_and_add 2
	lodsb
	xchg ah, al
	lodsb
	mov bl, al
	shr ax, cl
	xchg ah, al
	stosw
	ror bl, cl
	and bl, %2
	mov al, bl
	stosb
	add di, %1
%endmacro

	cpWord_extra_byte_and_add 77, 0xC0
	cpWord_extra_byte_and_add 77, 0xC0
	cpWord_extra_byte_and_add 77, 0xC0
	cpWord_extra_byte_and_add 0x2000 - (80 * 3) - 3 , 0xC0
	cpWord_extra_byte_and_add 77, 0xC0
	cpWord_extra_byte_and_add 77, 0xC0
	cpWord_extra_byte_and_add 77, 0xC0
	cpWord_extra_byte_and_add 77, 0xC0
	pop di
	pop si
	ret

	;;; X=2
blit_tile8_even_y_x2:
	mov cl, 4 ; shift
	cpWord_extra_byte_and_add 77, 0xF0
	cpWord_extra_byte_and_add 77, 0xF0
	cpWord_extra_byte_and_add 77, 0xF0
	cpWord_extra_byte_and_add 0x2000 - (80 * 3) - 3 , 0xF0
	cpWord_extra_byte_and_add 77, 0xF0
	cpWord_extra_byte_and_add 77, 0xF0
	cpWord_extra_byte_and_add 77, 0xF0
	cpWord_extra_byte_and_add 77, 0xF0
	pop di
	pop si
	ret

	;;; X=3
blit_tile8_even_y_x3:
	mov cl, 6 ; shift
	cpWord_extra_byte_and_add 77, 0xFC
	cpWord_extra_byte_and_add 77, 0xFC
	cpWord_extra_byte_and_add 77, 0xFC
	cpWord_extra_byte_and_add 0x2000 - (80 * 3) - 3 , 0xFC
	cpWord_extra_byte_and_add 77, 0xFC
	cpWord_extra_byte_and_add 77, 0xFC
	cpWord_extra_byte_and_add 77, 0xFC
	cpWord_extra_byte_and_add 77, 0xFC
	pop di
	pop si
	ret

	;;; X=1
blit_tile8_odd_y_x1:
	mov cl, 2 ; shift
	cpWord_extra_byte_and_add 77, 0xC0
	cpWord_extra_byte_and_add 77, 0xC0
	cpWord_extra_byte_and_add 77, 0xC0
	cpWord_extra_byte_and_add 0xE000 - (80 * 2) - 3 , 0xC0
	cpWord_extra_byte_and_add 77, 0xC0
	cpWord_extra_byte_and_add 77, 0xC0
	cpWord_extra_byte_and_add 77, 0xC0
	cpWord_extra_byte_and_add 77, 0xC0
	pop di
	pop si
	ret

	;;; X=2
blit_tile8_odd_y_x2:
	mov cl, 4 ; shift
	cpWord_extra_byte_and_add 77, 0xF0
	cpWord_extra_byte_and_add 77, 0xF0
	cpWord_extra_byte_and_add 77, 0xF0
	cpWord_extra_byte_and_add 0xE000 - (80 * 2) - 3 , 0xF0
	cpWord_extra_byte_and_add 77, 0xF0
	cpWord_extra_byte_and_add 77, 0xF0
	cpWord_extra_byte_and_add 77, 0xF0
	cpWord_extra_byte_and_add 77, 0xF0
	pop di
	pop si
	ret

	;;; X=3
blit_tile8_odd_y_x3:
	mov cl, 6 ; shift
	cpWord_extra_byte_and_add 77, 0xFC
	cpWord_extra_byte_and_add 77, 0xFC
	cpWord_extra_byte_and_add 77, 0xFC
	cpWord_extra_byte_and_add 0xE000 - (80 * 2) - 3 , 0xFC
	cpWord_extra_byte_and_add 77, 0xFC
	cpWord_extra_byte_and_add 77, 0xFC
	cpWord_extra_byte_and_add 77, 0xFC
	cpWord_extra_byte_and_add 77, 0xFC
	pop di
	pop si
	ret


