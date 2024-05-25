%define CHAN2PORT   0x42
%define PPIPORTB    0x61

section .data

pcspkr_tone: dw 0
pcspkr_timeout: dw 0
pcspkr_val: dw 0
pcspkr_inc: dw 0

section .code


pcspkr_frame:
	push ax
	mov ax, [pcspkr_timeout]
	and ax, ax
	jz .done

	; Apply freq inc
	mov ax, [pcspkr_tone]
	add ax, [pcspkr_inc]
	mov [pcspkr_tone], ax

	mov dx, CHAN2PORT
	out dx, al
	mov al, ah
	out dx, al


	; Count timer down
	mov ax, [pcspkr_timeout]
	dec ax
	mov [pcspkr_timeout], ax
	jnz .done
	; When reaching 0,  silence it
	call pcspkr_tone_off
.done:
	pop ax
	ret

pcspkr_init:
	call pcspkr_gate
	ret


pcspkr_ungate:
    push ax
    ; PC and XT : I/O address 61h, "PPI Port B", read/write
    ;       7 6 5 4 3 2 1 0
    ;       * * * * * * . .  Not relevant to speaker - do not modify!
    ;       . . . . . . * .  Speaker Data
    ;       . . . . . . . *  Timer 2 Gate
    in al, PPIPORTB     ; read existing port bits
    or al, 3            ; turn on speaker gating
    out PPIPORTB, al    ; set new bits
    pop ax
    ret


pcspkr_gate:
    push ax
    in al, PPIPORTB
    and al, ~3
    out PPIPORTB, al
    pop ax
    ret


pcspkr_shutdown:
    call pcspkr_gate
    ret


    ; AX : Freq in Hz
	; CX : Number of frames to play sound
pcspkr_tone_on:
    push ax
    push bx
    push dx

    mov bx, ax

	mov [pcspkr_inc], dx

    ; Make sure the freq. is at least 37 Hz (otherwise divisision is out of range)
    cmp bx, 37
    jae .minok
    mov bx, 37
.minok:

    ; reference clock is 1193182 Hz (0x1234de)
    mov dx, 0x0012
    mov ax, 0x34de

    idiv bx

    ; save the frequency.
    mov [pcspkr_tone], ax
	mov [pcspkr_timeout], cx

	mov dx, CHAN2PORT
	out dx, al
	mov al, ah
	out dx, al

	call pcspkr_ungate

.ret:
    pop dx
    pop bx
    pop ax

    ret


pcspkr_tone_off:
	call pcspkr_gate
    ret



