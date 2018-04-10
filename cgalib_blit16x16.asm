section .text

%macro regs_pop 0
	pop si
	pop di
	pop cx
	pop bx
	pop ax
%endmacro

%macro regs_push 0
	push ax
	push bx
	push cx
	push di
	push si
%endmacro

;;;; blit_tile16XY : Blit a 16x16 tile to a destination coordinate
;
; ds:si : Pointer to tile data
; es:di : Video memory base (b800:0)
; ax: X coordinate (in pixels)
; bx: Y coordinate (in pixels)
;
blit_tile16XY:
	regs_push

	shl bx, 1
	add bx, cgarows
	add di, [bx]

	test di, 0x2000
	jz blit_tile16_even_y

;;;; blit_tile16_odd_y : Blit a 16x16 tile to a specified screen location.
; ds:si : Pointer to tile data
; es:di : Offset (in video memory) (Note: Must be on an odd line)
;
blit_tile16_odd_y:
	; X /= 4 (4 pixel per memory byte)
	mov ch, al ; Keep last bits in DL for later
	shr ax, 1
	shr ax, 1
	add di, ax ; Offset in line

	cld
	and ch, 0x03
	jz blit_tile16_odd_y_x0
	cmp ch, 2
	jl blit_tile16_odd_y_x1
	je blit_tile16_odd_y_x2
	jg blit_tile16_odd_y_x3

blit_tile16_odd_y_x0:

%macro movsw2_post_add 1
	movsw
	movsw
	add di, %1
%endmacro

	mov al, 76
	mov bx, 0x2000 + (80*6) + 4

	; Even
	%rep 7
	movsw2_post_add ax
	%endrep
	times 2 movsw
	; Odd
	sub di, bx
	%rep 7
	movsw2_post_add ax
	%endrep
	times 2 movsw

	regs_pop
	ret



;;;; blit_tile16_even_y : Blit a 16x16 tile to a specified screen location.
; ds:si : Pointer to tile data
; es:di : Offset (in video memory) (Note: Must be on an even line)
;
; Due to the CGA low-res packing arrangement, the offset value given
; in byte places the tile on a grid of 4 pixels.
blit_tile16_even_y:

	mov ch, al
	and ch,0x03
	jz blit_tile16_even_y_x0
	cmp ch, 2
	jl blit_tile16_even_y_x1
	je blit_tile16_even_y_x2
	jg blit_tile16_even_y_x3


blit_tile16_even_y_x0:
	; X /= 4 (4 pixel per memory byte)
	shr ax, 1
	shr ax, 1
	add di, ax ; Offset in line

	mov al, 76
	mov bx, 0x2000 - (80*7) - 4
	; Even
	%rep 7
	movsw2_post_add ax
	%endrep
	movsw2_post_add bx
	%rep 7
	movsw2_post_add ax
	%endrep
	;times 2 movsw
	movsw
	movsw

	regs_pop
	ret


blit_tile16_even_y_x1:
	; X /= 4 (4 pixel per memory byte)
	shr ax, 1
	shr ax, 1
	add di, ax ; Offset in line

	mov cl, 2 ; shift
%macro cpDWord_extra_byte_and_add 2
	lodsb
	xchg ah, al
	lodsb
	mov bh, al
	shr ax, cl
	xchg ah, al
	stosw

	ror bh, cl
	and bh, %2

	lodsb
	xchg ah, al
	lodsb
	mov bl, al
	shr ax, cl
	or ah, bh
	xchg ah, al
	stosw
	ror bl, cl
	and bl, %2
	mov al, bl
	stosb
	add di, %1
%endmacro

;	pop di
;	pop si
;	ret
	%rep 7
	cpDWord_extra_byte_and_add 75, 0xC0
	%endrep
	cpDWord_extra_byte_and_add 0x2000 - (80 * 7) - 5 , 0xC0
	%rep 8
	cpDWord_extra_byte_and_add 75, 0xC0
	%endrep

	regs_pop
	ret

blit_tile16_even_y_x2:
	; X /= 4 (4 pixel per memory byte)
	shr ax, 1
	shr ax, 1
	add di, ax ; Offset in line

	mov cl, 4 ; shift
	%rep 7
	cpDWord_extra_byte_and_add 75, 0xF0
	%endrep
	cpDWord_extra_byte_and_add 0x2000 - (80 * 7) - 5 , 0xF0
	%rep 8
	cpDWord_extra_byte_and_add 75, 0xF0
	%endrep

	regs_pop
	ret

blit_tile16_even_y_x3:
	; X /= 4 (4 pixel per memory byte)
	shr ax, 1
	shr ax, 1
	add di, ax ; Offset in line

	mov cl, 6 ; shift
	%rep 7
	cpDWord_extra_byte_and_add 75, 0xFC
	%endrep
	cpDWord_extra_byte_and_add 0x2000 - (80 * 7) - 5 , 0xFC
	%rep 8
	cpDWord_extra_byte_and_add 75, 0xFC
	%endrep

	regs_pop
	ret

blit_tile16_odd_y_x1:
	mov cl, 2 ; shift
	%rep 7
	cpDWord_extra_byte_and_add 75, 0xC0
	%endrep
	cpDWord_extra_byte_and_add 0xE000 - (80 * 6) - 5 , 0xC0
	%rep 8
	cpDWord_extra_byte_and_add 75, 0xC0
	%endrep

	regs_pop
	ret

blit_tile16_odd_y_x2:
	mov cl, 4 ; shift
	%rep 7
	cpDWord_extra_byte_and_add 75, 0xF0
	%endrep
	cpDWord_extra_byte_and_add 0xE000 - (80 * 6) - 5 , 0xF0
	%rep 8
	cpDWord_extra_byte_and_add 75, 0xF0
	%endrep

	regs_pop
	ret

blit_tile16_odd_y_x3:
	mov cl, 6 ; shift
	%rep 7
	cpDWord_extra_byte_and_add 75, 0xFC
	%endrep
	cpDWord_extra_byte_and_add 0xE000 - (80 * 6) - 5 , 0xFC
	%rep 8
	cpDWord_extra_byte_and_add 75, 0xFC
	%endrep

	regs_pop
	ret


