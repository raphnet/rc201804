org 100h
bits 16
cpu 8086


%define FIRST_KEY_X	0
%define FIRST_KEY_Y (200-32)
%define NUM_KEYS (320/32)
%define DROP_FLOOR_Y (FIRST_KEY_Y-16)
%define DROPS_INITIAL_Y 16
%define DROP0_X	8
%define DROPS_X_PITCH 32
%define MAX_DROPS	NUM_KEYS

; All labels on the first line
%define LABELS_Y		0
%define PLAYER_LABEL_X	0
%define LEVEL_LABEL_X	144
%define MISSES_LABEL_X	256

; The score, below the player
%define SCORE_X PLAYER_LABEL_X
%define SCORE_Y 10

%define NO_ACCELERATION

; Various values used with glp_end for glp_run return value.
%define RETVAL_WON			0
%define RETVAL_GAMEOVER		1
%define RETVAL_USER_QUIT	2


;;;; Make sure to jump to main first before includes
section .text
jmp start

;;;; Includes
%ifdef VGA_VERSION
%include 'vgalib.asm'
%else
%include 'tgalib.asm'
%endif
%include 'random.asm'
%define ZAPPER_SUPPORT
%include 'gameloop.asm'
%include 'mobj.asm'
%include 'score.asm'
%include 'messagescreen.asm'

section .bss

dropscheduler_framecount_top: resw 1
dropscheduler_framecount: resw 1
drop_initial_velocity: resw 1

; 0: Fine, 1-5: Breaking, ff: Broken (animation done)
keyconditions: resb NUM_KEYS
breaking_keys_framecount: resw 1
max_broken_keys: resb 1
num_broken_keys: resb 1

section .data

; Symbols required to reference sprites by their ID.
; for instance: get16x16TileID (macro) or getTile16 (function)
first32x32_tile:
	inc_resource key_grey
	inc_resource key_brk1
	inc_resource key_brk2
	inc_resource key_brk3
	inc_resource key_brk4
	inc_resource key_brk5
first16x16_tile:
	inc_resource droplet1
	inc_resource droplet2

	black_tile: times (16*16*2) db 0
	white_tile: times (16*16*2) db 0xff

first8x8_tile:

images:
	inc_resource game
	inc_resource over

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
	cld
	call initRandom
	call initvlib
	call setvidmode
	call setupVRAMpointer
	mov al, 0 ; english
	call lang_select

	call setupVRAMpointer
	call mouse_init
	call mouse_show
	call glp_init ; Init gameloop

.title:
	; TODO

.game:
	call mouse_hide
	call gamePrepareNew
	call mouse_show
	; Set gameloop hooks
	call glp_clearHooks
	glp_setHook(glp_hook_esc, onESCpressed)
	glp_setHook(glp_hook_trigger_pulled, onTriggerPulled)
	glp_setHook(glp_hook_vert_retrace, onVerticalRetrace)
.next_level:
	; Run the gameloop

	call glp_run

	; Value passed to glp_end placed in AX by gpl_run. Act according
	; to the reason why the game loop stopped
	cmp ax, RETVAL_USER_QUIT
	jz exit
	cmp ax, RETVAL_GAMEOVER
	jz .gameover

	; otherwise, this will be RETVAL_WON
	jmp .next_level

.gameover:
	mov cx, effect_height(200)
	call eff_checkboard

	getStrDX str_computer_useless
	mov ax, SCREEN_WIDTH/2
	call subHalfStrwidthFromAX
	mov bx, 50
	call drawString

	getStrDX str_gameover_message
	mov ax, SCREEN_WIDTH/2
	call subHalfStrwidthFromAX
	add bx, 10
	call drawString

	mov si, res_game
	mov ax, 24
	mov bx, 100-16
	mov cx, 128
	mov dx, 32
	call blit_imageXY

	add ax, 128+16
	mov si, res_over
	call blit_imageXY

	call flushkeyboard
	call waitPressSpace

	jmp .title

	;;;;; onESCpressed
	;
	; Called by the gameloop when the ESC key is pressed
	;
onESCpressed:
	push ax
	push cx
	push dx

	call messageScreen_start
.ask_again:
	getStrDX str_end_game
	call messageScreen_drawText_prepare
	mov cx, 0 ; default no
	call askYesNoQuestion ; CF set if ESC was pressed. CX = 0 for no
	jc .ask_again
	call messageScreen_end
	and cx,cx
	jz .done
	; ESC quits game
	mov ax, RETVAL_USER_QUIT
	call glp_end
.done:
	pop dx
	pop cx
	pop ax
	ret


	;;;;; onTriggerPulled
	;
	; Called by the gameloop when the trigger is pulled
	;
onTriggerPulled:
	; Start by hiding all droplets
	call mouse_hide
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
	call mouse_show
	ret

.miss:
	call gameDrawDropObjects
	call mouse_show
	ret

	;;;;; Gameloop callback : Vertical retrace started
	;
	; This is called at 60Hz.
	;
onVerticalRetrace:

	;; First, do stuff that races the beam such as erasing
	;; and drawing!

	; Erase and redraw objects that moved
	call mouse_hide
	call gameRedrawMovedObjects
	call gameAnimateBreakingKeys
	call gameDrawScore
	call mouse_show

	;; Now compute positions for next frame and run game logic

	; Update positions for next pass
	call gameUpdateDropObjects

	; Run the drop scheduler to "spawn" new raindrops, according
	; to elapsed time and game level
	call gameDropSchedulerTick

	; If there are too many broken keys, game over
	mov al, [max_broken_keys]
	cmp [num_broken_keys], al
	jle .continue
	; Too many? Cause the game loop to end with game over
	mov ax, RETVAL_GAMEOVER
	call glp_end

.continue:

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
%ifndef NO_ACCELERATION
		inc word [bp + mobj.yvel]
%endif
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
	MOBJ_GET_PREV_SCR_X ax, bp
	MOBJ_GET_PREV_SCR_Y bx, bp
	mov si, black_tile
	call blit_tile16XY

	; Make sure the previous position next time this object is enabled
	; and drawn is not below the keyboard!
	MOBJ_PREV_XY_TO_CUR bp

	; TODO : Break the key that was touched

	; Convert droplet BP to index
	mov ax, bp
	sub ax, droplets
	mov bl, mobj.size
	div bl ; al = ax / bl
	xor ah,ah
	; BX now contains the index
	mov bx, ax

	; First check that key is still fine
	mov al, [keyconditions + bx]
	and al, al
	jnz .ignore

	; Start the breaking animation
	mov byte [keyconditions + bx], 1

	; Broken key counter updated once animation ends

	;call score_add100
.ignore:
	pop si
	pop bx
	pop ax
	ret

	;;;;; gameAnimateBreakingKeys
	;
	; Called after drawing droplets in their new position
	;
gameAnimateBreakingKeys:
	inc word [breaking_keys_framecount]
	cmp word [breaking_keys_framecount], 4
	jl .done

	mov word [breaking_keys_framecount], 0

	mov bx, keyconditions
	mov cx, NUM_KEYS
.lp:
	xor ah,ah
	mov al, [bx]
	and al, al ; Fine (as drawn at beginning)
	jz .next
	cmp al, 0xff ; broken (done animating)
	jz .next

	; Draw current animation step
	push ax
	push bx
	push cx
		add ax, 1 ; Start from first broken key tile
		call getTile32 ; returns tile id AX

		sub bx, keyconditions ; Key index in BX
		mov al, bl ; Index in AL
		mov bh, DROPS_X_PITCH
		mul bh ; AX = AL * DROPS_X_PITCH
		add ax, FIRST_KEY_X

		mov bx, FIRST_KEY_Y
		mov cx, 32
		mov dx, 32
		call blit_imageXY
	pop cx
	pop bx
	pop ax

	; Now that we've drawn, take care of advancing to next
	; animation frame for next call
	inc ax
	cmp ax, 5
	jl .moretogo
	mov byte [bx], 0xff ; Broken key
	; count this key
	inc byte [num_broken_keys]
	jmp .next

.moretogo:
	mov [bx], al

.next:
	inc bx
	loop .lp

.done:
	ret

	;;;;; gameEventObjectHit
	;
	; Called when a raindrop was successfully shot
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
	call score_add100

	ret


	;;;;; gameDrawDropObjects
	;
	; Called once per frame. This function spawns new droplets
	; according to elapsed time and game parameters.
	;
gameDropSchedulerTick:
	push ax
	push bx

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
		mov bx, [drop_initial_velocity]
		MOBJ_SETYVEL(bp, bx)
		MOBJ_ENABLE bp

		jmp game_drop_scheduler_tick_done
.next:
		dec ax
	MOBJ_NEXT
game_drop_scheduler_tick_done:
	pop bx
	pop ax
	ret

	;;;;; gameDrawScore
	;
	;
	;
gameDrawScore:
	push ax
	push bx
	push cx

	mov ax, SCORE_X
	mov bx, SCORE_Y
%assign i SCORE_DIGITS-1
%rep SCORE_DIGITS
	mov cl, [score + i]
	add cl, '0'
	call drawChar
	add ax, 8
%assign i i-1
%endrep
	pop cx
	pop bx
	pop ax

	ret

	;;;;; gameInitDropObjects
	;
	; BX: Drop initial velocity
	;
gameInitDropObjects:
	push ax
	push bp

	mov ax, DROP0_X
	MOBJ_LIST_FOREACH droplets
		call mobj_init
		MOBJ_SETSIZE bp, 16, 16
		MOBJ_SET_SCR_X bp, ax
		MOBJ_SET_SCR_Y bp, DROPS_INITIAL_Y
		MOBJ_SETYVEL(bp, bx)
		add ax, DROPS_X_PITCH
	MOBJ_NEXT

	pop bp
	pop ax
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

	; Draw labels
	printxy PLAYER_LABEL_X,LABELS_Y,"Player 1"
	printxy LEVEL_LABEL_X,LABELS_Y,"Level"
	printxy MISSES_LABEL_X,LABELS_Y,"Misses"

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

	; At first, all keyboard keys are in good shape
	mov cx, NUM_KEYS
	mov bx, 0
.lp2:
	mov word [keyconditions + bx], 0 ; fine
	add bx, 2
	loop .lp2
	mov byte [num_broken_keys], 0

	; Initialize difficulty variables
	mov word [dropscheduler_framecount_top], 60 ; 1 per second
	mov word [dropscheduler_framecount], 0
	mov word [drop_initial_velocity], 12
	mov byte [max_broken_keys], 5

	mov bx, [drop_initial_velocity]
	call gameInitDropObjects

	; Zero the score
	call score_clear

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


