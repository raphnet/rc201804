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
%define TEST_TARGET_WIDTH	30
%define TEST_TARGET_HEIGHT	30
	mov ax, 160-TEST_TARGET_WIDTH/2
	mov bx, 100-TEST_TARGET_HEIGHT/2
	mov cx, TEST_TARGET_WIDTH
	mov dx, TEST_TARGET_HEIGHT
	mov byte [draw_color], 15
	call fillRect


mainloop:
	call waitVertRetrace
	call checkESCpressed
	jc exit

	jmp_if_trigger_pulled trigger_pulled
	jmp mainloop

trigger_pulled:

	call detectLight
	jc .detected

.not_detected:
	printxy 0,0,"              "
	call waitTriggerReleased
	jmp mainloop

.detected:
	printxy 0,0,"Detected!"
	call waitTriggerReleased
	jmp mainloop


; Restore original video mode,
; call dos service to exit
exit:
	call flushkeyboard
	call restorevidmode

	mov ah,04CH
	mov al,00 ; Return 0
	int 21h

