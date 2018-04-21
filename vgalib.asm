%ifndef vgalib_asm__
%define vgalib_asm__

%include 'lang.asm'
%include 'videolib_common.asm'

%define SCREEN_WIDTH	640
%define SCREEN_HEIGHT	480
%define SCREEN_WORDS	((SCREEN_WIDTH/16)*SCREEN_HEIGHT)

section .bss

section .data

	; Generate a lookup table to multiply by the screen pitch
vgarows:
%assign line 0
%rep 480
	dw line*SCREEN_WIDTH/8
%assign line line+1
%endrep

section .text

%macro setMapMask 1
	mov dx, 0x3c4
	mov ah, %1
	mov al, 2
	out dx, ax
%endmacro

%macro setFunction 1
	mov dx, 0x3ce
	mov ah, %1
	mov al, 3
	out dx, ax
%endmacro

%macro draw_color_to_vram
setMapMask 0x1 ; Blue
	mov al, [draw_color] ; Load color argument in al
	and al, 1  ; Mask blue
	jz %%a ; Zero? All bits are zero. AL is ready
	mov al, 0xff ; All bits are one
%%a:
	mov [es:di], al

	setMapMask 0x2 ; Green
	mov al, [draw_color] ; Load color argument in al
	and al, 2  ; Mask green
	jz %%b ; Zero? All bits are zero. AL is ready
	mov al, 0xff ; All bits are one
%%b:
	mov [es:di], al

	setMapMask 0x4 ; Red
	mov al, [draw_color] ; Load color argument in al
	and al, 4  ; Mask red
	jz %%c ; Zero? All bits are zero. AL is ready
	mov al, 0xff ; All bits are one
%%c:
	mov [es:di], al

	setMapMask 0x8 ; Intensity
	mov al, [draw_color] ; Load color argument in al
	and al, 8  ; Mask intensity
	jz %%d ; Zero? All bits are zero. AL is ready
	mov al, 0xff ; All bits are one
%%d:
	mov [es:di], al
%endmacro

;;;; setvidemode
;
; Returns with CF set if it fails
;
setvidmode:
	push ax
	push bx
	push dx

	mov ah, 0fh ; Get Video State
	int 10h
	mov byte [old_mode], al

	; set video mode
	mov ah, 00h ; Set video mode
	mov al, 12h ; VGA 640x480 16 colors
	int 10h

	mov ah, 0fh ; Get Video State
	int 10h

	; Check if it worked
	cmp al, 12h ; VGA 640x480 16 colors
	je _set_video_mode_ok

	stc ; Indicate failure
	jmp _set_video_mode_return

_set_video_mode_ok:
	clc ; clear carry (success)

_set_video_mode_return:
	pop dx
	pop bx
	pop ax
	ret

restorevidmode:
	push ax
	mov ah, 00
	mov al, [old_mode]
	int 10h
	pop ax
	ret

	;;;;;
	; es:di : Video memory base
	; ax: X
	; bx: Y
	; cx: Width
	; dx: Height
	; [draw_color] : Pixel color
	;
	; Note: Lazy coding, requires 8 pixel X alignment everywhere
	;
fillRectEven:
	push ax
	push bx
	push cx
	push dx
	push di

	; Skip to Y row
	add di, [vgarows+bx]
	; Skip to X position in row : di += ax / 8
	shift_div_8 ax
	add di, ax

	; Convert width to bytes
	shift_div_8 cx
	jz .done ; Less than 8 pixles draws nothing! (TODO)

	mov bx, dx ; Move dx (height) to bx as dx is about to be used by macros with OUTs

	; Take [draw_color] and send the 4 lower bits to the
	; corresponding planes at address es:di
	draw_color_to_vram

	; Read back the address once to fill the latches
	mov al, [es:di]

	setMapMask 0xF; all planes
	setFunction 8 ; AND logical function

	mov al, 0xff
	mov dx, cx ; Keep with in dx as cx will be modified by the loop
	mov bp, SCREEN_WIDTH / 8 ; Screen pitch
	sub bp, cx ; pointer increment to reposition on next row after drawing stride
.nextline:
	; Repeat 8-pixel color stride over all bytes in this line
	mov cx, dx
	rep stosb ; TODO : stosw would be faster, but need to take care of alignment..
	add di, bp ; Skip to starting point on next row
	add di, SCREEN_WIDTH / 8 ; Skip to starting point on next row

	dec bx ; repeat until height has been covered
	jz .done
	dec bx
	jnz .nextline

.done:
	setFunction 0 ; AND logical function

	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret



	;;;;;
	; es:di : Video memory base
	; ax: X
	; bx: Y
	; cx: Width
	; dx: Height
	; [draw_color] : Pixel color
	;
	; Note: Lazy coding, requires 8 pixel X alignment everywhere
	;
fillRect:
	push ax
	push bx
	push cx
	push dx
	push di

	; Skip to Y row
	add di, [vgarows+bx]
	; Skip to X position in row : di += ax / 8
	shift_div_8 ax
	add di, ax

	; Convert width to bytes
	shift_div_8 cx
	jz .done ; Less than 8 pixles draws nothing! (TODO)

	mov bx, dx ; Move dx (height) to bx as dx is about to be used by macros with OUTs

	; Take [draw_color] and send the 4 lower bits to the
	; corresponding planes at address es:di
	draw_color_to_vram

	; Read back the address once to fill the latches
	mov al, [es:di]

	setMapMask 0xF; all planes
	setFunction 8 ; AND logical function

	mov al, 0xff
	mov dx, cx ; Keep with in dx as cx will be modified by the loop
	mov bp, SCREEN_WIDTH / 8 ; Screen pitch
	sub bp, cx ; pointer increment to reposition on next row after drawing stride
.nextline:
	; Repeat 8-pixel color stride over all bytes in this line
	mov cx, dx
	rep stosb ; TODO : stosw would be faster, but need to take care of alignment..
	add di, bp ; Skip to starting point on next row

	dec bx ; repeat until height has been covered
	jnz .nextline

.done:
	setFunction 0 ; AND logical function

	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret


	; es:di : Video memory base (as set by setupVRAMpointer)
	; al : Color
fillScreen:
	push ax
	push cx
	push di

	mov cl, al ; Save color

	setMapMask 0x1 ; Blue
	mov al, cl ; Load color argument in al
	and al, 1  ; Mask blue
	jz .a ; Zero? All bits are zero. AL is ready
	mov al, 0xff ; All bits are one
.a:
	mov [es:di], al

	setMapMask 0x2 ; Green
	mov al, cl ; Load color argument in al
	and al, 2  ; Mask green
	jz .b ; Zero? All bits are zero. AL is ready
	mov al, 0xff ; All bits are one
.b:
	mov [es:di], al

	setMapMask 0x4 ; Red
	mov al, cl ; Load color argument in al
	and al, 4  ; Mask red
	jz .c ; Zero? All bits are zero. AL is ready
	mov al, 0xff ; All bits are one
.c:
	mov [es:di], al

	setMapMask 0x8 ; Intensity
	mov al, cl ; Load color argument in al
	and al, 8  ; Mask intensity
	jz .d ; Zero? All bits are zero. AL is ready
	mov al, 0xff ; All bits are one
.d:
	mov [es:di], al

	; Read back the address once to fill the latches
	mov al, [es:di]

	setMapMask 0xF; all planes
	setFunction 8 ; AND logical function
	mov ax, 0xFFFF
	mov cx, SCREEN_WORDS
	rep stosw

	setFunction 0 ; AND logical function

	pop di
	pop cx
	pop ax
	ret

blit_tile8XY:
	; TODO
	ret

putPixel:
	; TODO
	ret

blit_imageXY:
	; TODO
	ret

getFontTile:
	; TODO
	ret


; Points ES:DI to the base of video memory.
; Must be called before using most of the functions in this library.
; Can be called only once if ES:DI is never used (or preserved when modified)
setupVRAMpointer:
	push ax
	mov ax,0a000h
	mov es,ax
	xor di,di
	pop ax
	ret

	;;;; Initialize video library.
initvlib:
	call initvlib_common
	ret



%endif
