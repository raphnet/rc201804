%ifndef _score_asm
%define _score_asm

%define SCORE_DIGITS	7

section .bss

; Unpacked BDC format. Least significant digit first.
score: resb SCORE_DIGITS
score_increment: resb SCORE_DIGITS

;; Macro to set all score_increment digits to zero
;
%macro SCORE_ZERO_INCREMENT 0
%assign i 0
%rep SCORE_DIGITS
	mov byte [score_increment+i], 0
%assign i i+1
%endrep
%endmacro

;; Macro to set the score increment
;
; Examples:
;
; SET_INCREMENT 1,0,0  <- set an increment of 100
; SET_INCREMENT 2,5    <- set an increment of 25
;
%macro SCORE_SET_INCREMENT 0-SCORE_DIGITS
SCORE_ZERO_INCREMENT
%assign i %0-1
%rep %0
	mov byte [score_increment+i], %1
%assign i i-1
%rotate 1
%endrep
%endmacro

section .text

	;;;;; score_clear
	;
	; Reset score to zero
	;
score_clear:
%assign i 0
%rep SCORE_DIGITS
	mov byte [score + i], 0
%assign i i+1
%endrep
	ret

score_add:
	push ax
	push bx
	push cx
	push es
	push si

	mov bx, score_increment
	mov si, score

	mov cx, SCORE_DIGITS-1
.lp:
		mov ax, [si]
		add al, [bx]
		aaa
		mov [si], ax
		inc bx
		inc si
	loop .lp

	pop si
	pop es
	pop cx
	pop bx
	pop ax
	ret

score_add100:
	SCORE_SET_INCREMENT 1,0,0
	call score_add
	ret

score_add1000:
	SCORE_SET_INCREMENT 1,0,0,0
	call score_add
	ret

%endif ; _score_asm
