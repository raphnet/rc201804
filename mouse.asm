%ifndef _mouse_asm__
%define _mouse_asm__

%define MOUSEFN_RESET_QUERY			0x0000
%define MOUSEFN_SHOW				0x0001
%define MOUSEFN_HIDE				0x0002
%define MOUSEFN_QUERY_BTN_COUNTERS	0x0005
%define MOUSEFN_SET_POINTER_SHAPE	0x0009

section .data

mouse_enabled: db 0

section .bss

section .text

	;;;;;; Initialize mouse driver
	;
	; If a mouse driver is detected, [mouse_enabled] will be true
	; when this returns, and mouse function will have an effect if called.
	;
	; If no driver is detected, or mouse_init was never called, mouse functions
	; won't have an effect if called. Code doing its own int 33h calls can check
	; the [mouse_enabled] variable to skip mouse code if necessary.
	;
mouse_init:
	push ax
	push bx

	; INT 33,0 : Returns 0xffff in AX if driver installed
	mov ax, MOUSEFN_RESET_QUERY
	int 33h

	cmp ax, 0xffff
	je .mouse_present
	jmp .done

.mouse_present:
	; Enable mouse mode
	mov byte [mouse_enabled], 1

.done:
	pop bx
	pop ax

	ret

	;;;;;; Hide mouse pointer
	;
	;
	;
mouse_hide:
	jmp_mbyte_false [mouse_enabled], .done
	push ax
	mov ax, MOUSEFN_HIDE ; hide mouse cursor
	int 33h
	pop ax
.done:
	ret

	;;;;;; Show mouse pointer
	;
	;
	;
mouse_show:
	jmp_mbyte_false [mouse_enabled], .done
	push ax
	mov ax, MOUSEFN_SHOW ; show mouse cursor
	int 33h
	pop ax
.done:
	ret

	;;;;;; Set mouse pointer shape
	;
	; DS:SI : Data
	; BX : Hotspot X
	; CX : Hotspot Y
mouse_setpointer:
	jmp_mbyte_false [mouse_enabled], .done

	push ax
	push dx
	push es

	mov ax, MOUSEFN_SET_POINTER_SHAPE
	mov dx, si
	push ds
	pop es
	int 33h

	pop es
	pop dx
	pop ax

.done:
	ret


%endif ; _mouse_asm__
