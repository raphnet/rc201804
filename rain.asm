org 100h
bits 16
cpu 8086

%ifdef VGA_VERSION
%define KEY_WIDTH 64
%define KEY_HEIGHT 64
%define DROP_WIDTH 32
%define DROP_HEIGHT 32
%else
%define KEY_WIDTH 32
%define KEY_HEIGHT 32
%define DROP_WIDTH 16
%define DROP_HEIGHT 16
%endif

%define FIRST_KEY_X	0
%define FIRST_KEY_Y (SCREEN_HEIGHT-KEY_HEIGHT)
%define NUM_KEYS (SCREEN_WIDTH/KEY_WIDTH)
%define DROP_FLOOR_Y (FIRST_KEY_Y-16)
%define DROPS_INITIAL_Y 20
%define DROP0_X	((KEY_WIDTH/2)-(DROP_WIDTH/2))
%define DROPS_X_PITCH KEY_WIDTH
%define MAX_DROPS	NUM_KEYS

; All labels on the first line
%define LABELS_Y		0
%define SCORE_LABEL_X	20
%define HIGH_LABEL_X	96
%define MISSES_LABEL_X	256

; The scores, below the labels
%define SCORE_X SCORE_LABEL_X
%define HIGH_SCORE_X HIGH_LABEL_X
%define SCORE_Y 10

; Gameover messages
%define GAMEOVER_KEYS_Y			((SCREEN_HEIGHT/2)-16-18)
%define GAMEOVER_MESSAGE_Y		((SCREEN_HEIGHT/2)+16)

; Titlescreen text
%ifdef VGA_VERSION
%define INSTRUCTION_3L_Y	400
%define INSTRUCTION_2L_Y	405
%define INSTRUCTION_X		24
%define INSTRUCTION_Y_INCR	10
%else
%define INSTRUCTION_3L_Y	165
%define INSTRUCTION_2L_Y	170
%define INSTRUCTION_X		24
%define INSTRUCTION_Y_INCR	10
%endif

; Difficulty control
%define DIFF_INITIAL_FRAMECOUNT_TOP	(60*2) ; One drop every 3 second
%define DIFF_MIN_FRAMECOUNT_TOP 	15 ; 4 per second
%define DIFF_INITIAL_VELOCITY		16
%define DIFF_MAX_INITIAL_VELOCITY	32
%define DIFF_MAX_BROKEN_KEYS		3
%define DIFF_INCREASE_INITIAL_VELOCITY_EVERY	5 ; every 5 ticks
; The initial limit of simultaneous drops on screen
%define DIFF_INITIAL_MAX_ACTIVE_DROPS	3
; Maximum simultaneous drops on screen
%define DIFF_MAXIMUM_ACTIVE_DROPS	6

;%define NO_ACCELERATION
%define NO_LOOSING

; Various values used with glp_end for glp_run return value.
%define RETVAL_WON			0
%define RETVAL_GAMEOVER		1
%define RETVAL_USER_QUIT	2

%ifdef VGA_VERSION
	%macro doBlitDroplet 0
		push cx
		push dx
		mov dx, 32
		mov cx, dx
		call blit_imageXY
		pop dx
		pop cx
	%endmacro
	%define getKeyTile getTile64
%else
	%define doBlitDroplet call blit_tile16XY
	%define getKeyTile getTile32
%endif

;;;; Make sure to jump to main first before includes
section .text
jmp start

;;;; Includes
%ifdef VGA_VERSION
%include 'vgalib.asm'
%elifdef CGA_VERSION
%include 'cgalib.asm'
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
cnt_next_initvel_incr: resw 1
max_active_drops: resb 1

; 0: Fine, 1-5: Breaking, ff: Broken (animation done)
keyconditions: resb NUM_KEYS
breaking_keys_framecount: resw 1
max_broken_keys: resb 1
num_broken_keys: resb 1

section .data

mouse_available: db 0

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

	inc_resource black_droplet
	inc_resource highlighted_droplet

first8x8_tile:

images:
	inc_resource game
	inc_resource over

mouse_pointer_data: incbin "mousepointer.bin"
%define MOUSE_POINTER_HOTSPOT_X 7
%define MOUSE_POINTER_HOTSPOT_Y 8

%ifdef CGA_VERSION
titlescreen: incbin "res_cga/title.lz4"
%elifdef VGA_VERSION
titlescreen: incbin "res_vga16/title.lz4"
%else
titlescreen: incbin "res_tga/title.lz4"
%endif

section .bss

MOBJ_LIST_START droplets
%assign id 1
%rep MAX_DROPS
	DECLARE_MOBJ(drop%+id)
%assign id id+1
%endrep
MOBJ_LIST_END droplets


section .text

;;;; Entry point
start:
	cld
	call initRandom
	call initvlib
	call setvidmode
	call setupVRAMpointer
	mov al, 1 ; english
	call lang_select

	call setupVRAMpointer

.title:

%ifdef MOUSE_SUPPORT
	mov byte [mouse_available], 0
	call mouse_init
	jnz .mouse_unavailable
.mouse_available:
	mov byte [mouse_available], 1
	mov si, mouse_pointer_data
	mov bx, MOUSE_POINTER_HOTSPOT_X
	mov cx, MOUSE_POINTER_HOTSPOT_Y
	call mouse_setpointer
	call mouse_show
.mouse_unavailable:
%endif

	call glp_init ; Init gameloop

	; Display opening screen
	loadScreen titlescreen
	; Display instructions

	jmp_mbyte_false [mouse_available], .nomouseoption
.withmouseoption:
	mov ax, INSTRUCTION_X
	mov bx, INSTRUCTION_3L_Y

	getStrDX str_click_mouse_button_or
	call drawString
	add bx, INSTRUCTION_Y_INCR

	getStrDX str_pull_trig_to_start
	call drawString
	add bx, INSTRUCTION_Y_INCR

	getStrDX str_press_esc_to_quit
	call drawString

	jmp .instructions_done
.nomouseoption:
	mov ax, INSTRUCTION_X
	mov bx, INSTRUCTION_2L_Y
	getStrDX str_Pull_trig_to_start
	call drawString
	add bx, INSTRUCTION_Y_INCR

	getStrDX str_press_esc_to_quit
	call drawString
.instructions_done:

	call waitTriggerOrMouseClick
	cmp ax, 0x0001
	je .play_with_mouse
	cmp ax, 0x0002
	je exit


.play_with_zapper:
	mov byte [mouse_enabled], 0

.play_with_mouse:
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
	jz .title
	cmp ax, RETVAL_GAMEOVER
	jz .gameover

	; otherwise, this will be RETVAL_WON
	jmp .next_level

.gameover:
	mov cx, effect_height(SCREEN_HEIGHT)
	call eff_checkboard

	getStrDX str_computer_useless
	mov ax, SCREEN_WIDTH/2
	call subHalfStrwidthFromAX
	mov bx, GAMEOVER_MESSAGE_Y
	call drawString

	getStrDX str_gameover_message
	mov ax, SCREEN_WIDTH/2
	call subHalfStrwidthFromAX
	add bx, 10
	call drawString

	mov si, res_game
	mov ax, (SCREEN_WIDTH/2-(128+16+128)/2)
	mov bx, GAMEOVER_KEYS_Y
	mov cx, 128
	mov dx, 32
	call blit_imageXY

	add ax, 128+16
	mov si, res_over
	call blit_imageXY


	call score_greaterThanHigh
	jnc .no_new_high_score

	getStrDX str_new_high_score
	mov ax, HIGH_SCORE_X
	mov bx, SCORE_Y + 10
	call drawString

	call score_copyToHigh
	call gameDrawHighScore

.no_new_high_score:
	call waitTriggerOrMouseClick

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
	mov si, res_highlighted_droplet
	MOBJ_LIST_FOREACH_ENABLED droplets
		; Use previous position as it has not yet been drawn at the new
		; position that was computed in the previous frame
		MOBJ_GET_PREV_SCR_X ax, bp
		MOBJ_GET_PREV_SCR_Y bx, bp
		doBlitDroplet
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
	jl .continue
	; Too many? Cause the game loop to end with game over
%ifndef NO_LOOSING
	mov ax, RETVAL_GAMEOVER
	call glp_end
%endif
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
		doBlitDroplet
	MOBJ_NEXT
	ret

	;;;;; gameEraseDropObjects
	;
	; Draw black over all drop objects
	;
gameEraseDropObjects:
	mov si, res_black_droplet
	MOBJ_LIST_FOREACH_ENABLED droplets
		MOBJ_GET_SCR_X ax, bp
		MOBJ_GET_SCR_Y bx, bp
		doBlitDroplet
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
		mov si, res_black_droplet
		doBlitDroplet
		MOBJ_GET_SCR_X ax, bp
		MOBJ_GET_SCR_Y bx, bp
		mov si, res_droplet1
		doBlitDroplet

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
	mov si, res_black_droplet
	doBlitDroplet

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
	;call gameIncreaseDifficultyTick

.ignore:

	call gameIncreaseDifficultyTick

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
		call getKeyTile ; returns tile id AX

		sub bx, keyconditions ; Key index in BX
		mov al, bl ; Index in AL
		mov bh, DROPS_X_PITCH
		mul bh ; AX = AL * DROPS_X_PITCH
		add ax, FIRST_KEY_X

		mov bx, FIRST_KEY_Y
		mov cx, KEY_WIDTH
		mov dx, KEY_HEIGHT
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
	mov si, res_black_droplet
	MOBJ_GET_PREV_SCR_X ax, bp
	MOBJ_GET_PREV_SCR_Y bx, bp
	doBlitDroplet
	MOBJ_GET_SCR_X ax, bp
	MOBJ_GET_SCR_Y bx, bp
	doBlitDroplet

	; TODO Score? Count? Increase difficulty?
	call score_add100

	call gameIncreaseDifficultyTick

	;mov word [dropscheduler_framecount], 0 ; force new drop now

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
	mov bx, [dropscheduler_framecount_top]

	; Add some random time to next target, to break rhythm
	mov al, 0
	mov ah, 30
	call getRandom8
	add bx, ax

	mov [dropscheduler_framecount], bx

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
	; Also give up if too many drops
	mov al, NUM_KEYS
	sub al, [max_active_drops]
	;cmp ah, NUM_KEYS-MAX_ACTIVE_DROPS
	cmp ah, al
	jle game_drop_scheduler_tick_done


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


	;;;;;; gameIncreaseDifficultyTick
	;
	; Called to increase game difficulty each time
	; a droplet is hit or a key gets broken (in other words,
	; once in the life of every droplet)
	;
gameIncreaseDifficultyTick:
	push ax

	; Increase the rate of appearance of new drops
	cmp word [dropscheduler_framecount_top], DIFF_MIN_FRAMECOUNT_TOP
	jle .max_rate_reached
	sub word [dropscheduler_framecount_top], 5
.max_rate_reached:

	; Increase initial velocity every N ticks
	inc word [cnt_next_initvel_incr]
	cmp word [cnt_next_initvel_incr], DIFF_INCREASE_INITIAL_VELOCITY_EVERY
	jl .no_initvel_incr

	; Random initial value for next count
	mov al, 0
	mov ah, DIFF_INCREASE_INITIAL_VELOCITY_EVERY/2
	call getRandom8
	mov word [cnt_next_initvel_incr], ax


	; Ok, time to incrase (multiply by 1.5)
	mov ax, [drop_initial_velocity]
	shr ax, 1
	or ax, 1 ; make sure to increase even when initial value is 1
	add word [drop_initial_velocity], ax

	; Impose a maximum
	cmp word [drop_initial_velocity], DIFF_MAX_INITIAL_VELOCITY
	jl .done
	; max reached, clamp it to DIFF_MAX_INITIAL_VELOCITY
	mov word [drop_initial_velocity], DIFF_MAX_INITIAL_VELOCITY

	cmp byte [max_active_drops], DIFF_MAXIMUM_ACTIVE_DROPS
	jge .done

	inc byte [max_active_drops]

.no_initvel_incr:
.done:
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

	;;;;; gameDrawHighScore
	;
	;
	;
gameDrawHighScore:
	push ax
	push bx
	push cx

	mov ax, HIGH_SCORE_X
	mov bx, SCORE_Y
%assign i SCORE_DIGITS-1
%rep SCORE_DIGITS
	mov cl, [high_score + i]
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
	printxy SCORE_LABEL_X,LABELS_Y,"Score"
	printxy HIGH_LABEL_X,LABELS_Y,"High"
;	printxy MISSES_LABEL_X,LABELS_Y,"Hits"

	; Draw keyboard keys
	mov bp, NUM_KEYS
	mov si, res_key_grey
	mov ax, FIRST_KEY_X
	mov bx, FIRST_KEY_Y
	mov cx, KEY_WIDTH
	mov dx, KEY_HEIGHT
.lp:
	push bp
	call blit_imageXY
	pop bp
	add ax, KEY_WIDTH
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
	mov word [dropscheduler_framecount_top], DIFF_INITIAL_FRAMECOUNT_TOP
	mov word [dropscheduler_framecount], 0
	mov word [drop_initial_velocity], DIFF_INITIAL_VELOCITY
	mov byte [max_broken_keys], DIFF_MAX_BROKEN_KEYS
	mov word [cnt_next_initvel_incr], 0x0000
	mov byte [max_active_drops], DIFF_INITIAL_MAX_ACTIVE_DROPS

	mov bx, [drop_initial_velocity]
	call gameInitDropObjects

	; Zero the score
	call score_clear

	call gameDrawHighScore

	pop bp
	pop si
	pop dx
	pop cx
	pop bx
	pop ax
	ret

	;;;;;;; waitTriggerOrMouseClick
	;
	; Block execution until the trigger
	; is pulled or the left mouse button
	; is clicked.
	;
	; Returns 0 in AX for trigger
	; Returns 1 in AX for mouse
	; Returns 2 in AX if ESC was pressed
waitTriggerOrMouseClick:
	call flushkeyboard
.loop:
	call checkESCpressed
	jc .escape

	; Save mouse enable state to have
	; jmp_if_trigger_pulled monitor
	; the trigger.
	mov al, [mouse_enabled]
	push ax
	mov byte [mouse_enabled], 0
	jmp_if_trigger_pulled .trigger
	pop ax
	mov [mouse_enabled], al

	; Check the mouse button ourselves
	jmp_mbyte_false [mouse_enabled], .loop
	mov ax, MOUSEFN_QUERY_BTN_COUNTERS
	int 33h
	and ax, 0x0001
	jnz .click

	jmp .loop

.trigger:
	pop ax
	mov [mouse_enabled], al
	mov ax, 0x0000
	ret

.click:
	mov ax, 0x0001
	ret

.escape:
	mov ax, 0x0002
	ret

;
; Output a string using int 10h
;
printStr:
	push ax
	push bx
	push cx
.lp:
	mov bx, dx
	mov al, [bx]
	and al,al
	jz .done

	mov ah, 0eh
	mov bh, 0
	mov cx, 1
	int 10h
	inc dx
	jmp .lp
.done:
	pop cx
	pop bx
	pop ax
	ret

;
;
;
printBanner:
	push ax
	push bx
	push dx


%assign i 1
%rep NUM_STR_THANKS
	; Position cursor
	mov ah, 02h
	mov bh, 0
	mov dh, i-1 ; row
	mov dl, 0 ; col
	int 10h

	getStrDX str_thanks%[i]
	call printStr
%assign i i+1
%endrep


	pop dx
	pop bx
	pop ax
	ret

; Restore original video mode,
; call dos service to exit
exit:
	call mouse_hide
	call flushkeyboard
	call restorevidmode

	call printBanner

	mov ah,04CH
	mov al,00 ; Return 0
	int 21h
.noreturn:	jmp .noreturn


