org 100h
bits 16
cpu 8086

;;;; Make sure to jump to main first before includes
section .text
jmp start

;;;; Includes
%include 'vgalib.asm'
%include 'random.asm'
%include 'zapper.asm'

section .bss

section .data

; Symbols required to reference sprites by their ID.
; for instance: get16x16TileID (macro) or getTile16 (function)
first32x32_tile:
first16x16_tile:
	inc_resource droplet1

first8x8_tile:
	times 32 db 0xff

teststr: db 'Hello',0

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

	; Initialize mouse if enabled, otherwise does nothing.
	enable_mouse_mode
	call zapperInit

	; This one is just a rectangle that will
	; not be "targettable"
	printxy 270,190,"Passive object"
%define TEST_TARGET_WIDTH	64
%define TEST_TARGET_HEIGHT	64
	mov ax, 320-TEST_TARGET_WIDTH/2
	mov bx, 240-TEST_TARGET_HEIGHT/2
	mov cx, TEST_TARGET_WIDTH
	mov dx, TEST_TARGET_HEIGHT
	mov byte [draw_color], 15
	call fillRect

	; Draw the real targetable square
	printxy 116,55,"Shootable object"
	call restoreTargets

	printxy 300,0,"VGA Zapdemo 1"

	mov si, first8x8_tile
	mov ax, 0
	mov bx, 0
	call blit_tile8XY

	mov ax, 16
	mov bx, 16
	mov si, res_droplet1
	call blit_tile16XY

	mov ax, 32
	mov bx, 32
	mov si, res_droplet1
	call blit_tile16XY

mainloop:
	call waitVertRetrace
	call checkESCpressed
	jc exit

	jmp_if_trigger_pulled trigger_pulled
	jmp mainloop

trigger_pulled:
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
	call waitTriggerReleased
	jmp mainloop


eraseTargets:
	mov ax, 180-TEST_TARGET_WIDTH/2
	mov bx, 100-TEST_TARGET_HEIGHT/2
	mov cx, TEST_TARGET_WIDTH
	mov dx, TEST_TARGET_HEIGHT
	mov byte [draw_color], 0
	call fillRect
	ret

highlightTargets:
	mov ax, 180-TEST_TARGET_WIDTH/2
	mov bx, 100-TEST_TARGET_HEIGHT/2
	mov cx, TEST_TARGET_WIDTH
	mov dx, TEST_TARGET_HEIGHT
	mov byte [draw_color], 15
	call fillRectEven
	ret

restoreTargets:
	mov ax, 180-TEST_TARGET_WIDTH/2
	mov bx, 100-TEST_TARGET_HEIGHT/2
	mov cx, TEST_TARGET_WIDTH
	mov dx, TEST_TARGET_HEIGHT
	mov byte [draw_color], 15
	call fillRect
	ret

; Restore original video mode,
; call dos service to exit
exit:
	call flushkeyboard
	call restorevidmode

	mov ah,04CH
	mov al,00 ; Return 0
	int 21h

