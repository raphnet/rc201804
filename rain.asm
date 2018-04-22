org 100h
bits 16
cpu 8086

%define MAX_DROPS	8

%define FIRST_KEY_X	0
%define FIRST_KEY_Y (200-32)
%define NUM_KEYS (320/32)
%define DROP_FLOOR_Y (FIRST_KEY_Y-16)

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
	inc_resource key_grey
first16x16_tile:
	inc_resource droplet1
	inc_resource droplet2

	black_tile: times (16*16*2) db 0
	white_tile: times (16*16*2) db 0xff

first8x8_tile:

teststr: db 'Hello',0

section .bss

MOBJ_LIST_START droplets
;mobjarray_start:
%assign id 1
%rep MAX_DROPS
DECLARE_MOBJ(drop%+id)
%assign id id+1
%endrep
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
	call gamePrepareNew

	; Set gameloop hooks
	call glp_clearHooks
	glp_setHook(glp_hook_esc, glp_end) ; ESC quits game
	glp_setHook(glp_hook_trigger_pulled, onTriggerPulled)
	glp_setHook(glp_hook_vert_retrace, onVerticalRetrace)


	; Run the gameloop
	call glp_run
	jmp exit

onTriggerPulled:
	; Start by hiding all droplets
	call gameEraseDropObjects
	call detectLight
	jnz .miss ; All objects are black. No light should be seen.

	; Now draw each on in white, checking for light.
	mov si, white_tile
	MOBJ_LIST_FOREACH droplets
		MOBJ_GET_SCR_X ax, bp
		MOBJ_GET_SCR_Y bx, bp
		call blit_tile16XY
		call detectLight
		jnz .hit
	MOBJ_NEXT

	jmp .miss

.hit:
	; Restart fall
	MOBJ_SET_SCR_Y bp, 0
	; Force redraw of all objects
	call gameDrawDropObjects
	ret

.miss:
	call gameDrawDropObjects
	ret

	;;;;; Gameloop callback : Vertical retrace started
onVerticalRetrace:
	; Erase and redraw objects that moved
	call gameRedrawMovedObjects
	; Update positions for next pass
	call gameUpdateDropObjects

%if 0
	printxy 100,90,"Val:                 "
	mov ax, 100 + 5*8
	mov bx, 90
	mov cx, [zapper_last_x]
	call drawNumber
	add ax, 32
	mov cx, [zapper_last_start]
	call drawNumber
%endif

	ret

gameUpdateDropObjects:
	MOBJ_LIST_FOREACH droplets
	call mobj_tick
	MOBJ_GET_SCR_Y ax, bp
	cmp ax, DROP_FLOOR_Y
	jl .next
	; TODO : Loose points, etc
	MOBJ_SET_SCR_Y bp, 0
.next:
	MOBJ_NEXT
	ret

gameDrawDropObjects:
	mov si, res_droplet1
	MOBJ_LIST_FOREACH droplets
		call mobj_scr_pos_changed
		MOBJ_GET_SCR_X ax, bp
		MOBJ_GET_SCR_Y bx, bp
		call blit_tile16XY
	MOBJ_NEXT
	ret

gameEraseDropObjects:
	mov si, black_tile
	MOBJ_LIST_FOREACH droplets
		call mobj_scr_pos_changed
		MOBJ_GET_SCR_X ax, bp
		MOBJ_GET_SCR_Y bx, bp
		call blit_tile16XY
	MOBJ_NEXT
	ret

gameRedrawMovedObjects:
	MOBJ_LIST_FOREACH droplets
		call mobj_scr_pos_changed
		jz .skip
		MOBJ_GET_PREV_SCR_X ax, bp
		MOBJ_GET_PREV_SCR_Y bx, bp
		mov si, black_tile
		call blit_tile16XY
		MOBJ_GET_SCR_X ax, bp
		MOBJ_GET_SCR_Y bx, bp
		mov si, res_droplet1
		call blit_tile16XY
.skip:
	MOBJ_NEXT
	ret

gameHighlightDropObjects:
	mov si, white_tile
	MOBJ_LIST_FOREACH droplets
		MOBJ_GET_SCR_X ax, bp
		MOBJ_GET_SCR_Y bx, bp
		call blit_tile16XY
	MOBJ_NEXT
	ret


gameInitDropObjects:
	MOBJ_LIST_FOREACH droplets
		call mobj_init
		MOBJ_SETSIZE bp, 16, 16
	MOBJ_NEXT

	; Hardcode default positions and speeds for now
%assign id 1
%rep MAX_DROPS
	MOBJ_SETYVEL(drop%+id, id * 2)
	MOBJ_SET_SCR_X drop%+id, (16 * id)
	MOBJ_SET_SCR_Y drop%+id, 32
%assign id id+1
%endrep
	ret

gamePrepareNew:
	push ax
	push bx
	push cx
	push dx
	push si
	push bp

	mov al, 0
	call fillScreen

	mov bp, NUM_KEYS
	mov si, res_key_grey
	mov ax, FIRST_KEY_X
	mov bx, FIRST_KEY_Y
	mov cx, 32
	mov dx, 32
.lp:
	push bp
	call blit_imageXY
	pop bp
	add ax, 32
	dec bp
	jnz .lp

	pop bp
	pop si
	pop dx
	pop cx
	pop bx
	pop ax
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


