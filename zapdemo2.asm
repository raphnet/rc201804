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
	call zapperInit

	; Draw a tall rectangle on the left side of the screen
	mov ax, 0
	mov bx, 0
	mov cx, 48
	mov dx, 200
	mov byte [draw_color], 15
	call fillRect

	call drawColorTest
	call drawThicknessTest

	; Instructions
	printxy 80,16,"* * Vertical timing test * *"
	printxy 80,42,"< < Aim at vertical bar"
	printxy 228,190,"ESC to quit"

mainloop:
	call waitVertRetrace
	call checkESCpressed
	jc exit

	call detectLight
	jz .nolight

	call .printStart
	call .printTotal
	call .printY

	jmp mainloop

.bad_last_count:
	printxy 100,80,"Bad count   "
	jmp mainloop

.nolight:
	printxy 100,80,"Start: - -  "
	call .printTotal
	jmp mainloop

.printStart:
	call waitVertRetrace
	printxy 100,80,"Start:      "
	mov ax, 100 + 8*8
	mov bx, 80
	mov cx, [zapper_last_start]
	call drawNumber
	ret

.printTotal:
	call waitVertRetrace
	printxy 100,90,"Total:      "
	mov ax, 100 + 8*8
	mov bx, 90
	mov cx, [zapper_last_count]
	call drawNumber
	ret

.printY:
	call zapperComputeRealY
	call waitVertRetrace

	; Clear previous height indicator by drawing
	; a black column as high as the screen
	push bx ; Save Y coord
		mov ax, 56 ; x
		mov bx, 0  ; y
		mov cx, 8  ; width
		mov dx, 200; height
		mov byte [draw_color], 0
		call fillRect
	pop bx

	; Draw the height indicator
	mov dx, 8 ; height is 8 now
	mov byte [draw_color], 12
	call fillRect

	printxy 100,100,"Y:         "
	mov cx, bx
	mov ax, 100 + 8*8
	mov bx, 100
	call drawNumber
	ret



drawThicknessTest:
	push ax
	push bx
	push cx
	push dx

	mov byte [draw_color], 15
	mov ax, 300
	mov bx, 32
	mov cx, 16

	mov dx, 1 ; Start with 1px thickness
.loop:
	call fillRect

	inc dx    ; Increase thickness

	add bx, dx ; New Y position by thickness
	add bx, 8 ; Gap between thickness bars

	cmp dx, 10 ; Stop once a certain thickness is reached
	jng .loop


	pop dx
	pop cx
	pop bx
	pop ax

	ret


drawColorTest:
	push ax
	push bx
	push cx
	push dx

	mov ax, 72
	mov bx, 130
	mov cx, 16
	mov dx, 16
	mov byte [draw_color], 0

	; normal colors
.loop:
	call fillRect

	add ax, 24 ; Advance X position
	inc byte [draw_color] ; Prepare next color
	cmp byte [draw_color], 8
	jne .loop

	; start a new row for 'bright' colors
	mov ax, 72
	add bx, 24
.loop2:
	call fillRect

	add ax, 24 ; Advance X position
	inc byte [draw_color] ; Prepare next color
	cmp byte [draw_color], 16
	jne .loop2

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

