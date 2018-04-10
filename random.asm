;
;
;
;
; initRandom : No arguments, no return. Initializes random number generator
; getRandmm : Returns a random number in AX, with a minimum of AL and max of AH.
;
; clkRandom : Internal function. Runs one LFSR cycle. Current value returned in AX.
section .text

initRandom:
	call reseedRandom
	ret

	;;;;; Seeds the random using system clock
reseedRandom:
	push ax
	push bx
	push cx
	push dx

		; Read system clock counter
	mov ah, 0
	int 01Ah
	; Low order word of tick count in DX. Changes 18.206 times per second.
	and dx,dx
	jnz _seed_nz
	; We need to make sure the seed is non-zero, otherwise only zeros will
	; be returned. The output won't look random at all!
	mov word [random_lfsr_state], 0xACE1
_seed_nz:
	mov ax, dx
	call setRandomSeed

	pop dx
	pop cx
	pop bx
	pop ax

	ret

	;;;;; Seed the LFSR with a specific value.
	; Seed in AX.
	;
	; A given value always gives the same pseudo-random output.
setRandomSeed:
	mov [random_lfsr_state], ax
	ret

%macro randomizeAxMinMax 2
	mov al, %1
	mov ah, %2
	call getRandom8
%endmacro

	; getRandom8 : Returns a 8-bit random number in AX
	; Bounds: AH=max, AL=min.
getRandom8:
	push bx
	push cx
	push dx
	push ax ; order!

	sub ah, al ; Calculate range
	inc ah
	mov bl, ah ; Divisor
	xor bh, bh

	call clkRandom
	; result in ax
	xor ah,al

	xor dx,dx ; Clear remainder
	div bx 	; perform ax/bx. remainder goes in dx

	pop ax ; restore AX (min/max)

	xor ah,ah
	add dx, ax ; Add minimum

	mov ax,dx ; return value
	pop dx
	pop cx
	pop bx
	ret

	; Result in AX
clkRandom:
	push cx

	mov cx, 0

	; bit  = ((lfsr >> 0) ^ (lfsr >> 2) ^ (lfsr >> 3) ^ (lfsr >> 5) ) & 1;
	mov ax, [random_lfsr_state]
	xor cx, ax ; >> 0
	shr ax, 1
	shr ax, 1
	xor cx, ax ; >> 2
	shr ax, 1
	xor cx, ax ; >> 3
	shr ax, 1
	shr ax, 1
	xor cx, ax ; >> 5
	and cx, 1

	; lfsr =  (lfsr >> 1) | (bit << 15);
	mov ax, [random_lfsr_state]
	shr ax, 1
	ror cx, 1 ; bit << 15
	or ax, cx
	mov [random_lfsr_state], ax

	pop cx
	ret

section .bss

random_lfsr_state: resw 1
