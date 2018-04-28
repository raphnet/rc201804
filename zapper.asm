org 100h
bits 16
cpu 8086

%define JOYSTICK_PORT	201h
;%define TRIGGER_BIT		0x40
;%define LIGHT_BIT		0x80
%define TRIGGER_BIT		0x10
%define LIGHT_BIT		0x20

;%define VISIBLE_MOUSE

; Jump to label if trigger pulled.
%macro jmp_if_trigger_pulled	1
	push ax
	push bx
	push cx
	push dx


%ifdef MOUSE_SUPPORT
	cmp byte [mousemode], 0
	jne %%mouse
%endif

	; Trigger from joystick button (normal)
%%joystick:
	mov dx, JOYSTICK_PORT
	in al, dx
	test al, TRIGGER_BIT
	jmp %%done

%ifdef MOUSE_SUPPORT
	; Trigger from left mouse button (mouse mode)
%%mouse:
	mov ax, 0x0005
	int 33h
	xor ax, 0xffff ; Invert logic (be active low like joystick)
	test ax, 0x0001 ; Left button
%endif

%%done:
	pop dx
	pop cx
	pop bx
	pop ax
	jz %1 ; Active low trigger
%endmacro

%define enable_mouse_mode	mov byte [mousemode], 1
%define disable_mouse_mode	mov byte [mousemode], 0

section .data

mousemode: db 0

section .bss

; Counts how many cycles until light started being seen
zapper_last_start: resw 1
; Counts for how many cycles light was seen
zapper_last_count: resw 1
; Only in mouse mode
zapper_last_x: resw 1

section .text

zapperInit:
%ifdef MOUSE_SUPPORT
	push ax
	push bx
	cmp byte [mousemode], 0
	je .done
	; INT 33,0 : Returns 0xffff in AX if driver installed
	mov ax, 0x0000
	int 33h
	and ax, ax
	jz .nomouse
%ifdef VISIBLE_MOUSE
	mov ax, 0x0001
	int 33h
%endif
	jmp .done
.nomouse:
	; Force mouse mode off if not driver is detected
	mov byte [mousemode], 0
.done:
	pop bx
	pop ax
%endif
	ret

waitTriggerReleased:
	jmp_if_trigger_pulled waitTriggerReleased
	ret

zapperComputeRealY:
	push ax
	push cx
	push dx

	; Make sure [zapper_last_count] is non-zero
	xor bx,bx ; Return value in case [zapper_last_count] is zero
	mov ax, [zapper_last_count]
	and ax,ax
	jz .bad_last_count

	;
	; Y = [zapper_last_start] * 200 / [zapper_last_count]
	;
	mov ax, [zapper_last_start]
	mov dx, 200
	mul dx ; AX:DX = AX * 200
	div word [zapper_last_count] ; AX:DX = AX:DX / [zapper_last_count]

	mov bx, ax ; Return Y value in BX

.bad_last_count:
	pop dx
	pop cx
	pop ax
	ret

	; Monitor the light input for a complete video frame
	; Exits during the next retrace period
	; ZF set if no light was detected.
	;
detectLight:
%ifdef MOUSE_SUPPORT
	cmp byte [mousemode], 0
	jnz detectLightMouse
%endif

	push ax
	push bx
	push cx
	push dx

	mov word [zapper_last_start], 0
	mov word [zapper_last_count], 0
	mov word [zapper_last_x], 0

	xor bx, bx ; Use bl to remember if light was seen, bh to detect changes
	mov cl, LIGHT_BIT ; mask to check light input bit
	mov ch, 08h ; mask to check vertical retrace

	; Wait until retrace ends first. Otherwise the next
	; loop would exit right away.
	mov dx, 3DAh
.loop_wait_retrace_end:
	in al, dx
	test al, ch
	jnz .loop_wait_retrace_end ; still in retrace

.loop_frame:
	inc word [zapper_last_count]
	; Check for light detection (active high)
	mov dx, JOYSTICK_PORT
	in al, dx
	and al, cl
	jz .not_rising_edge ; No light seen
	or bl, al ; Remember light seen

	cmp bh, bl
	je .not_rising_edge
	mov dx, [zapper_last_count]
	mov [zapper_last_start], dx
	mov bh, bl
.not_rising_edge:

	; Stop once vertical retrace starts again
	mov dx, 3DAh
	in al, dx
	test al, ch
	jz .loop_frame ; not in retrace yet

.done:
	; Bit LIGHT_BIT will be set in bl only if light
	; was seen. Otherwise bl will be zero.
	and bl, bl ; Set/clear ZF

	pop dx
	pop cx
	pop bx
	pop ax

	ret

%ifdef MOUSE_SUPPORT
detectLightMouse:
	push ax
	push bx
	push cx
	push dx

	mov ch, 08h ; mask to check vertical retrace

	; Wait until retrace ends first. Otherwise the next
	; loop would exit right away.
	mov dx, 3DAh
.loop_wait_retrace_end:
	in al, dx
	test al, ch
	jnz .loop_wait_retrace_end ; still in retrace

%ifdef VISIBLE_MOUSE
	mov ax, 0x0002 ; hide mouse cursor
	int 33h
%endif
	mov ax, 0x0005
	mov bx, 0 ; Left button
	int 33h
	; ax : Status
	; bx : count of button presses
	; cx : X
	; dx : Y

	; HACK ! Bug in dosbox perhaps? X coordinates
	; are scaled in tandy mode...
	shr cx, 1


	; fake vertical timing
	mov word [zapper_last_start], dx
	mov word [zapper_last_count], 200
	mov word [zapper_last_x], cx

	; Use the getPixel function from the video library
	mov ax, cx
	mov bx, dx

%if 0
	mov dl, 0xf
	call putPixel
%endif

	call getPixel
	; Returns the pixel color in DL, setting the zero flag if color is 0.
	; Perfect!
	pushf

%ifdef VISIBLE_MOUSE
	mov ax, 0x0001 ; show mouse cursor
	int 33h
%endif

	; Stop once vertical retrace starts again
	mov ch, 08h
	mov dx, 3DAh
.waitRetraceStart:
	in al, dx
	test al, ch
	jz .waitRetraceStart ; not in retrace yet


	popf

	pop dx
	pop cx
	pop bx
	pop ax

	ret
%endif
