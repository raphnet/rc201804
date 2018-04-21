org 100h
bits 16
cpu 8086

;;;; Make sure to jump to main first before includes
section .text
jmp start

;;;; Includes
%include 'tgalib.asm'
%include 'random.asm'
%define ZAPPER_SUPPORT
%include 'gameloop.asm'
%include 'mobj.asm'

section .bss

section .data

; Symbols required to reference sprites by their ID.
; for instance: get16x16TileID (macro) or getTile16 (function)
first32x32_tile:
first16x16_tile:
	inc_resource droplet1
	inc_resource droplet2

first8x8_tile:

teststr: db 'Hello',0

section .bss

MOBJ_LIST_START droplets
;mobjarray_start:
DECLARE_MOBJ(drop1)
DECLARE_MOBJ(drop2)
DECLARE_MOBJ(drop3)
DECLARE_MOBJ(drop4)
DECLARE_MOBJ(drop5)
;mobjarray_end:
MOBJ_LIST_END droplets

;%define MOBJ_ARRAY_SIZE ((mobjarray_end - mobjarray_start) / mobj.size)


section .text

;;;; Entry point
start:
	call initRandom
	call initvlib
	call setvidmode
	call setupVRAMpointer
	mov al, 0
	call lang_select

	call setupVRAMpointer

	call glp_init ; Init gameloop
	call gameInitDropObjects ; Init game variables/state

	; Set gameloop hooks
	call glp_clearHooks
	glp_setHook(glp_hook_esc, glp_end) ; ESC quits game
	glp_setHook(glp_hook_trigger_pulled, onTriggerPulled)
	glp_setHook(glp_hook_vert_retrace, onVerticalRetrace)

	; Run the gameloop
	call glp_run
	jmp exit

	;;;;; Gameloop callback : Zapper trigger pulled
onTriggerPulled:
	call eraseTargets ; Draw black over target
	call detectLight
	jnz .miss ; No light should be detected unless a non-target object was pointed
	call highlightTargets ; Draw white over target
	call detectLight
	jz .miss ; Light should be seen unless the zapper is pointing to a black area
.detected:
	printxy 0,0,"Detected!"
	jmp .done
.miss:
	printxy 0,0,"miss      "
.done:
	call restoreTargets
	ret

eraseTargets:
	jmp gameEraseDropObjects
	;ret

highlightTargets:
	ret

restoreTargets:
	jmp gameDrawDropObjects
	;ret


	;;;;; Gameloop callback : Vertical retrace started
onVerticalRetrace:
	call gameEraseDropObjects
	call gameUpdateDropObjects
	call gameDrawDropObjects

	ret

gameUpdateDropObjects:
	MOBJ_LIST_FOREACH droplets
	call mobj_tick
	MOBJ_NEXT
	ret

gameDrawDropObjects:
	MOBJ_LIST_FOREACH droplets
		MOBJ_GET_SCR_X ax, bp
		MOBJ_GET_SCR_Y bx, bp
		mov si, res_droplet1
		call blit_tile16XY
	MOBJ_NEXT
	ret

gameEraseDropObjects:
	MOBJ_LIST_FOREACH droplets
		; Load current coordinates and adjust scale
		MOBJ_GET_SCR_X ax, bp
		MOBJ_GET_SCR_X bx, bp
		; Load object dimensinos
		push cx
		MOBJ_GET_W cx, bp
		MOBJ_GET_H dx, bp
		mov byte [draw_color], 0 ; Background
		call fillRect
		pop cx
	MOBJ_NEXT

	ret

gameInitDropObjects:
	MOBJ_LIST_FOREACH droplets
		call mobj_init
		MOBJ_SETSIZE bp, 16, 16
	MOBJ_NEXT

	; Hardcode default positions and speeds for now
	MOBJ_SETYVEL(drop1, 8)
	MOBJ_SETYVEL(drop2, 4)
	MOBJ_SETYVEL(drop3, 1)
	MOBJ_SETYVEL(drop4, 16)
	MOBJ_SETYVEL(drop5, 2)
	MOBJ_SETX(drop2, 100 * 16 )
	MOBJ_SETX(drop3, 80 * 16 )
	MOBJ_SETX(drop4, 60 * 16 )
	MOBJ_SETX(drop5, 140 * 16 )
	ret

; Restore original video mode,
; call dos service to exit
exit:
	call flushkeyboard
	call restorevidmode

	mov ah,04CH
	mov al,00 ; Return 0
	int 21h
.noreturn:	jmp .noreturn




