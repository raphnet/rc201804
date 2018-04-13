org 100h
bits 16
cpu 8086

;;;; Make sure to jump to main first before includes
section .text
jmp start

;;;; Includes
%include 'tgalib.asm'
%include 'random.asm'
%include 'zapper.asm'

section .bss

section .data

; Symbols required to reference sprites by their ID.
; for instance: get16x16TileID (macro) or getTile16 (function)
first32x32_tile:
first16x16_tile:
first8x8_tile:

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
%define TEST_TARGET_WIDTH	30
%define TEST_TARGET_HEIGHT	30
	mov ax, 160-TEST_TARGET_WIDTH/2
	mov bx, 100-TEST_TARGET_HEIGHT/2
	mov cx, TEST_TARGET_WIDTH
	mov dx, TEST_TARGET_HEIGHT
	mov byte [draw_color], 15
	call fillRect

	; Draw the real targetable square
	call restoreTargets

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
	mov ax, 80-TEST_TARGET_WIDTH/2
	mov bx, 50-TEST_TARGET_HEIGHT/2
	mov cx, TEST_TARGET_WIDTH
	mov dx, TEST_TARGET_HEIGHT
	mov byte [draw_color], 0
	call fillRect
	ret

highlightTargets:
	mov ax, 80-TEST_TARGET_WIDTH/2
	mov bx, 50-TEST_TARGET_HEIGHT/2
	mov cx, TEST_TARGET_WIDTH
	mov dx, TEST_TARGET_HEIGHT
	mov byte [draw_color], 15
	call fillRect
	ret

restoreTargets:
	jmp highlightTargets




; Restore original video mode,
; call dos service to exit
exit:
	call flushkeyboard
	call restorevidmode

	mov ah,04CH
	mov al,00 ; Return 0
	int 21h

