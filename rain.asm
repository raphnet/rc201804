org 100h
bits 16
cpu 8086


%define FIRST_KEY_X	0
%define FIRST_KEY_Y (200-32)
%define NUM_KEYS (320/32)
%define DROP_FLOOR_Y (FIRST_KEY_Y-16)
%define DROPS_INITIAL_Y 0
%define MAX_DROPS	NUM_KEYS

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

dropscheduler_framecount_top: resw 1
dropscheduler_framecount: resw 1

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
	MOBJ_LIST_FOREACH_ENABLED droplets
		MOBJ_GET_SCR_X ax, bp
		MOBJ_GET_SCR_Y bx, bp
		call blit_tile16XY
		call detectLight
		jnz .hit ; Only one object can be hit. So it's fine to exit the loop
	MOBJ_NEXT

	jmp .miss

.hit:
	call gameEventObjectHit

	; Force redraw of all objects
	call gameDrawDropObjects
	ret

.miss:
	call gameDrawDropObjects
	ret

	;;;;; Gameloop callback : Vertical retrace started
	;
	; This is called at 60Hz.
	;
onVerticalRetrace:

	;; First, do stuff that races the beam such as erasing
	;; and drawing!

	; Erase and redraw objects that moved
	call gameRedrawMovedObjects

	;; Now compute positions for next frame and run game logic

	; Update positions for next pass
	call gameUpdateDropObjects

	; Run the drop scheduler to "spawn" new raindrops, according
	; to elapsed time and game level
	call gameDropSchedulerTick

	ret

	;;;;; gameUpdateDropObjects
	;
	; Apply motion to all drop objects (call mobj_tick) and
	; detect objects that reach the keyboard
	;
gameUpdateDropObjects:
	MOBJ_LIST_FOREACH_ENABLED droplets
	call mobj_tick
	MOBJ_GET_SCR_Y ax, bp
	cmp ax, DROP_FLOOR_Y
	jl .next

	call gameEventObjectReachedFloor
.next:
	MOBJ_NEXT
	ret

	;;;;; gameDrawObjects
	;
	; Draw all drop objects to the screen, even those
	; that have not moved and do not need to be redrawn.
	;
gameDrawDropObjects:
	mov si, res_droplet1
	MOBJ_LIST_FOREACH_ENABLED droplets
		MOBJ_GET_SCR_X ax, bp
		MOBJ_GET_SCR_Y bx, bp
		call blit_tile16XY
	MOBJ_NEXT
	ret

	;;;;; gameEraseDropObjects
	;
	; Draw black over all drop objects
	;
gameEraseDropObjects:
	mov si, black_tile
	MOBJ_LIST_FOREACH_ENABLED droplets
		MOBJ_GET_SCR_X ax, bp
		MOBJ_GET_SCR_Y bx, bp
		call blit_tile16XY
	MOBJ_NEXT
	ret

	;;;;; gameRedrawMovedObjects
	;
	; For objects that moved:
	;  - Draw black over old positon
	;  - Draw object at current positon
	;
gameRedrawMovedObjects:
	MOBJ_LIST_FOREACH_ENABLED droplets
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

	;;;;; gameEventObjectReachedFloor
	;
	; Called when a raindrop reaches the keyboard.
	; BP = mobj
	;
gameEventObjectReachedFloor:
	push ax
	push bx
	push si

	; Disable the object
	MOBJ_DISABLE bp

	; Draw black over it
	MOBJ_GET_SCR_X ax, bp
	MOBJ_GET_SCR_Y bx, bp
	mov si, black_tile
	call blit_tile16XY

	; TODO : Break the key that was touched

	pop si
	pop bx
	pop ax
	ret


	;;;;; gameEventObjectReachedFloor
	;
	; Called when a raindrop reaches the keyboard.
	; BP = mobj
	;
gameEventObjectHit:

	; Disable the object
	MOBJ_DISABLE bp

	; Draw black over it
	MOBJ_GET_SCR_X ax, bp
	MOBJ_GET_SCR_Y bx, bp
	mov si, black_tile
	call blit_tile16XY

	; TODO Score? Count? Increase difficulty?
	ret


	;;;;; gameDrawDropObjects
	;
	; Called once per frame. This function spawns new droplets
	; according to elapsed time and game parameters.
	;
gameDropSchedulerTick:
	push ax

	mov ax, [dropscheduler_framecount]
	test ax, 0xffff
	jz .time_for_newdrop

	; Not yet. Decrease and store new count and return
	dec ax
	mov [dropscheduler_framecount], ax
	jmp game_drop_scheduler_tick_done

	; Ok, it's time to spawn a new droplet!
.time_for_newdrop:
	; Reset the counter
	mov ax, [dropscheduler_framecount_top]
	mov [dropscheduler_framecount], ax

	; There are as many dropX objects as there are keys.
	; We can only have one drop falling above a given key.
	; Here we need to select a random drop

	; 1st: Count the number of inactive drops
count_inactive_drops:
	mov ah, 0
	MOBJ_LIST_FOREACH_DISABLED droplets
		inc ah
	MOBJ_NEXT
	; Give up if all slots are busy
	test ah, 0xff
	jz game_drop_scheduler_tick_done

	; Otherwise, select a new one at random
spawn_new_drop:
	mov al, 0
	dec ah ; Ah countains a count, we need a max for getRandom8
	call getRandom8 ; returns random number of AL-AH range in AX
	MOBJ_LIST_FOREACH_DISABLED droplets
		test ax, 0xffff
		jnz .next

		MOBJ_SET_SCR_Y bp, DROPS_INITIAL_Y
		MOBJ_ENABLE bp

		jmp game_drop_scheduler_tick_done
.next:
		dec ax
	MOBJ_NEXT


game_drop_scheduler_tick_done:
	pop ax
	ret


	;;;;; gameInitDropObjects
	;
	;
	;
gameInitDropObjects:
	MOBJ_LIST_FOREACH droplets
		call mobj_init
		MOBJ_SETSIZE bp, 16, 16
	MOBJ_NEXT

	; Hardcode default positions and speeds for now
%assign id 1
%rep MAX_DROPS
	MOBJ_SETYVEL(drop%+id, 16)
	MOBJ_SET_SCR_X drop%+id, (32 * id + 8)
	MOBJ_SET_SCR_Y drop%+id, DROPS_INITIAL_Y
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

	; Clear screen
	mov al, 0
	call fillScreen

	; Draw keyboard keys
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


	; Initialize difficulty variables
	mov word [dropscheduler_framecount_top], 60 ; 1 per second
	mov word [dropscheduler_framecount], 0

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


