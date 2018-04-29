%ifndef _score_asm
%define _score_asm

%define SCORE_DIGITS	5

section .bss

; Unpacked BDC format. Least significant digit first.
score: resb SCORE_DIGITS
score_increment: resb SCORE_DIGITS
high_score: resb SCORE_DIGITS

;; Macro to set all score_increment digits to zero
;
%macro SCORE_ZERO_INCREMENT 0
%assign i 0
%rep SCORE_DIGITS
	mov byte [score_increment+i], 0
%assign i i+1
%endrep
%endmacro

%macro SCORE_ZERO_HIGH 0
%assign i 0
%rep SCORE_DIGITS
	mov byte [high_score+i], 0
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

%macro SCORE_SET_HIGH 0-SCORE_DIGITS
SCORE_ZERO_HIGH
%assign i %0-1
%rep %0
	mov byte [high_score+i], %1
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

	;;;;;; score_copyToHigh
	;
	; Copy the current score to the high score
	;
score_copyToHigh:
	push ax
	push bx

	mov bx, 0
.lp:
	mov al, [score + bx]
	mov [high_score + bx], al

	inc bx
	cmp bx, SCORE_DIGITS
	jl .lp

	pop bx
	pop ax
	ret

	;;;;;; score_greaterThanHigh
	;
	; Return with carry set if current score is greater than high score
	;
score_greaterThanHigh:
	push ax
	push bx

	mov bx, SCORE_DIGITS-1
.lp:
	mov al, [bx + score]
	mov ah, [bx + high_score]
	cmp al,ah
	jg .greater
	jl .lesser
	; equal digit? continue
	dec bx
	jnz .lp

	; equality
	jmp .lesser

.greater:
	stc
	jmp .return
.lesser:
	clc
.return:
	pop bx
	pop ax
	ret

%endif ; _score_asm
