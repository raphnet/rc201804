bits 16
cpu 8086

; Should be defined before inclusion or from command-line.
;%define ZAPPER_SUPPORT

%ifdef ZAPPER_SUPPORT
%include "zapper.asm"
%endif

%define glp_setHook(symbol, function) mov word [symbol], function

section .bss

glp_mustrun: resb 1

trig_active: resb 1

_first_hook:
glp_hook_esc: resw 1
glp_hook_trigger_pulled: resw 1
glp_hook_vert_retrace: resw 1
_last_hook:

section .data

section .text


	;;;;; Reset all hooks to default noop values
glp_clearHooks:
	push bx
	push cx
	mov word cx, (_last_hook - _first_hook)/2
	mov bx, glp_hook_esc
.lp:
	mov word [bx], gameloop_noop
	add bx, 2
	loop .lp
	pop cx
	pop bx
	ret


	;;;;; Call once to initialize the game loop
	;
	; Clears hooks
	;
glp_init:
	; Initialize mouse if enabled, otherwise does nothing.
	enable_mouse_mode
	call zapperInit
	call glp_clearHooks
	ret


	;;;;; Call from any hook to request exit from gameloop
glp_end:
	mov byte [glp_mustrun], 0
	ret


	;;;;; Run the gameloop until glp_end is called
glp_run:
	mov byte [glp_mustrun], 1
.loop:

	mov dx, 3DAh
	mov ah, 08h
	; If already in vertical retrace (fast computer or slow game code)
	; wait until retrace ends. Then wait until it starts again
	; to continue;
.waitNotInRetrace:
	in al, dx
	test al,ah
	jnz .waitNotInRetrace

	; Wait for retrace start
.notInRetrace:
	in al, dx
	test al,ah
	jz .notInRetrace

%ifdef ZAPPER_SUPPORT
	jmp_if_trigger_pulled .pulled
	jmp .not_pulled
.pulled:
	; Only call trigger hook on rising edge.
	jmp_mbyte_true [trig_active], .trigger_management_done
	mov byte [trig_active], 1
	call [glp_hook_trigger_pulled]
	jmp .trigger_management_done
.not_pulled:
	mov byte [trig_active], 0
.trigger_management_done:
%endif

	call [glp_hook_vert_retrace]

	; Call ESC pressed hook
	call checkESCpressed
	jnc .esc_not_pressed
	call [glp_hook_esc]
.esc_not_pressed:


	cmp byte [glp_mustrun], 1
	je .loop

	ret

; Do nothing placeholder for unused hooks
gameloop_noop:
	ret

