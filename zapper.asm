org 100h
bits 16
cpu 8086

%define JOYSTICK_PORT	201h

%define TRIGGER_BIT		0x40
%define LIGHT_BIT		0x80

; Jump to label if trigger pulled.
%macro jmp_if_trigger_pulled	1
	push ax
	push dx
	mov dx, JOYSTICK_PORT
	in al, dx
	test al, TRIGGER_BIT
	pop dx
	pop ax
	jz %1 ; Active low trigger
%endmacro

section .text

waitTriggerReleased:
	jmp_if_trigger_pulled waitTriggerReleased
	ret

	; Monitor the light input for a complete video frame
	;
	; Assumes it is called during vertical retrace
	;
detectLight:
	push ax
	push bx
	push cx
	push dx

	; Wait until retrace ends to start monitoring
	call waitIfNotVertRetrace
	mov cl, LIGHT_BIT
	mov ch, 08h
.loop:
	; Check for light detection (active high)
	mov dx, JOYSTICK_PORT
	in al, dx
	test al, cl
	jnz .detected
	; Stop once vertical retrace starts again
	mov dx, 3DAh
	in al, dx
	test al, ch
	jz .loop ; no in retrace yet

	; Not detected: Clear carry, return
.not_detected:
	clc
	jmp .done

	; Detected! Set carry, return
.detected:
	stc
	jmp .done

.done:
	pop dx
	pop cx
	pop bx
	pop ax

	ret
