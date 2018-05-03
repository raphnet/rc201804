; A quick and dirty library for CGA Low-res mode
; By Raphaël Assénat, started December 2015
;
;
%include 'lang.asm'
%include 'animation.asm'

%define SCREEN_WIDTH	320
%define SCREEN_HEIGHT	200

%define BITS_PER_PIXEL	2
%define OPTIMISED_PUT_VERT_LINE
%define SET_BGCOLOR_IMPLEMENTED
%define FLASH_BACKGROUND_IMPLEMENTED
%include 'videolib_common.asm'

%define get16x16TileID(label)	((label-first16x16_tile)/(4*16))

; Macro to include a resource file. Argument: Resource name. (unquoted)
;
; A label matching the resource name prefixed by res_ will be created.
; The resource will be included using incbin.
; The full filename will be res_tga/name.tga
;
; i.e:
;   inc_resource droplet
; would include:
;	res_cga/droplet.cga
; and the label would be:
; res_droplet:
%macro inc_resource 1
res_%1:
%defstr namestr %1
%strcat base "res_cga/" namestr ; Build left part of path
%strcat filename base ".cga"
incbin filename
%endmacro


section .text


; Points ES:DI to the base of video memory.
; Must be called before using most of the functions in this library.
; Can be called only once if ES:DI is never used (or preserved when modified)
setupVRAMpointer:
	push ax
	mov ax,0B800h
	mov es,ax
	xor di,di
	pop ax
	ret

; Points ES:DI to an off-screen surface
setupOFFSCREENpointer:
	push ax
	mov di, screen_backup
	mov ax, ds
	mov es, ax
	pop ax
	ret

;;;;; ; TODO
;
; Clear a 8x8 rectangle
; AX : X
; BX : Y
; ES : video memory base

clr8x8:
	push ax
	push di

	cld

	; Get row
	mov di, bx
	shl di, 1
	add di, cgarows
	mov di, [di]

	test al, 3
	jz _clr8x8_double

_clr8x8_triple:
	; Get col (x/4)
	shr ax, 1
	shr ax, 1
	add di, ax

	xor ax, ax ; clear is color 0
	;mov ax, 255 ; clear is color 0
	stosw
	stosb
	add di, 77
	stosw
	stosb
	add di, 77
	stosw
	stosb
	add di, 77
	stosw
	stosb
	sub di, 80 * 3 + 3
	xor di, 0x2000
	test di, 0x2000
	jnz _c3_waseven
	add di, 80
_c3_waseven:

	stosw
	stosb
	add di, 77
	stosw
	stosb
	add di, 77
	stosw
	stosb
	add di, 77
	stosw
	stosb

	pop di
	pop ax
	ret
_clr8x8_double:
	; Get col (x/4)
	shr ax, 1
	shr ax, 1
	add di, ax

	xor ax, ax ; clear is color 0
	;mov ax, 255 ; clear is color 0
	stosw
	add di, 78
	stosw
	add di, 78
	stosw
	add di, 78
	stosw
	sub di, 80 * 3 + 2
	xor di, 0x2000

	test di, 0x2000
	jnz _c2_waseven
	add di, 80
_c2_waseven:


	stosw
	add di, 78
	stosw
	add di, 78
	stosw
	add di, 78
	stosw

	pop di
	pop ax
	ret

;;;;;
; es:di : Video memory base
; ax: Offset in line (on a 4 pixel grid)
; bx: First line
; cx: Width
; dx: Height
; [draw_color] : Pixel color
;
fillRect:
	push ax
	push bx
	push cx
	push dx
	push di

	and cx,cx
	jz _fr_lines_range_done
	and dx,dx
	jz _fr_lines_range_done

	; Repeat the color for each packed pixel over AX
	push ax
	mov al, [draw_color]

	and al, 03h
	mov ah, al
	shl al,1
	shl al,1
	or ah, al
	shl al,1
	shl al,1
	or ah, al
	shl al,1
	shl al,1
	or ah, al
	mov al, ah

	mov [draw_color], al
	pop ax

	push ax
	push bx
		mov ax, bx
		shr ax, 1
		mov bl, 80
		mul bl
		add di, ax
	pop bx
	pop ax

	cld

	shr ax, 1
	shr ax, 1 ; Divide start_x by 4
	add di, ax

	shr cx, 1 ; Divide width by 4
	shr cx, 1

	; Prepare AX with draw color
	mov al, [draw_color]
	mov ah, al

	test bx, 1
	jz _fr_even
	add di, 0x2000
	jmp _fr_start_on_odd_line

_fr_even:
	push cx
	rep stosb
	pop cx
	dec dx
	jz _fr_lines_range_done

_fr_odd:
	add di, 0x2000
	sub di, cx
_fr_start_on_odd_line:
	push cx
	; clear line
	rep stosb
	pop cx
	dec dx
	jz _fr_lines_range_done
	sub di, cx
	sub di, 0x2000-80
	; clean line
	jmp _fr_even

_fr_lines_range_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret


;;;;;
; es:di : Video memory base
; bx: First line
; cx: Number of lines
; al: Color (2-bit, right-aligned)
;
clearLinesRange:
	push ax
	push bx
	push cx
	push dx
	push di

	and cx,cx
	jz _clr_lines_range_done

	; Repeat the color for each packed pixel over AX
	and al, 03h
	mov ah, al
	shl al,1
	shl al,1
	or ah, al
	shl al,1
	shl al,1
	or ah, al
	shl al,1
	shl al,1
	or ah, al
	mov al, ah

	push ax
	push bx
		shl bx, 1
		add bx, cgarows
		mov di, [bx]
;		mov ax, bx
;		shr ax, 1
;		mov bl, 80
;		mul bl
;		add di, ax
	pop bx
	pop ax

	cld

	test bx, 1
	jz _clr_even
	jmp _start_on_odd_line

_clr_even:
	times 40 stosw
	dec cx
	jz _clr_lines_range_done

_clr_odd:
	add di, 0x2000-80
_start_on_odd_line:
	; clear line
	times 40 stosw

	dec cx
	jz _clr_lines_range_done

	sub di, 0x2000
	; clean line
	jmp _clr_even

_clr_lines_range_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret

	; es:di : Video memory base
savescreen:
	push ax
	push cx
	push es
	push di
	push ds
	push si

	;xchg es, ds
	push es
	push ds
	pop es
	pop ds

	xchg si, di
	mov di, screen_backup

	mov cx, 320*200/16
	rep movsw ; ds:si to es:di

	mov di, screen_backup + 2000h
	mov si, 2000h
	mov cx, 320*200/16
	rep movsw

	pop si
	pop ds
	pop di
	pop es
	pop cx
	pop ax
	ret

	; es:di : Video memory base
restorescreen:
	push ax
	push cx
	push di
	push si

	mov si, screen_backup
	mov cx, 320*200/16
	rep movsw

	mov si, screen_backup + 2000h

	mov di, 2000h
	mov cx, 320*200/16
	rep movsw

	pop si
	pop di
	pop cx
	pop ax
	ret

; es:di : Video memory base
; al: Color (2-bit, right-aligned)
fillScreen:
	push ax
	push bx
	push cx
	push di

	; Repeat the color for each packed pixel over AX
	and al, 03h
	mov ah, al
	shl al,1
	shl al,1
	or ah, al
	shl al,1
	shl al,1
	or ah, al
	shl al,1
	shl al,1
	or ah, al
	mov al, ah

	; Even lines
	mov bx, 100
_fs_even_lp:
	mov cx, 40
	rep stosw
	dec bx
	jnz _fs_even_lp

	; Odd field
	mov bx, 100
	add di, 0x2000-(100*80)
_fs_odd_lp:
	mov cx, 40
	rep stosw
	dec bx
	jnz _fs_odd_lp

	pop di
	pop cx
	pop bx
	pop ax
	ret

	;;;; put vertical line
	;; es:di : Video memory base
	;; AX : X coordinate
	;; BX : Y coordinate
	;; CX : Line length
	;; DL : Color
putVertLine:
	push ax
	push cx
	push dx
	push di
	push si
	push ds


	push cx

	mov si, bx
	shl si, 1
	add si, cgarows
	mov di, [si]

	mov cx,es
	mov ds,cx

	; Isolate the correct 2 bits
	mov cl, al
	xor cl, 0xff
	and cl, 3
	shl cl, 1 ; 2 bpp

	; Prepare mask and value to OR simultaneously
	; dl holds color in 2 lower bits
	and dx, 0x0003
	or dx, 0xfcfc
	rol dx, cl
	xor dl, dh ; Cleanup pixel

	; SI + X / 4
	shr ax, 1
	shr ax, 1
	add di, ax

	mov si, di ; Need to read pixel first

	pop cx

	test di, 0x2000
	jnz _dvl_odd

_dvl_loop:
		lodsb ; read pixel to al
		and al, dh ; mask pixel
		or al, dl ; Apply pixel
		stosb ; al
		add di, 0x2000-1
		mov si, di

		dec cx
		jz _dvl_loop_done

	_dvl_odd:

		lodsb ; read pixel to al
		and al, dh ; mask pixel
		or al, dl ; Apply pixel
		stosb ; al


		sub di, 0x2000 + 1 - 80
		mov si, di

		loop _dvl_loop
_dvl_loop_done:
	pop ds
	pop si
	pop di
	pop dx
	pop cx
	pop ax
	ret

	;;;; put pixel
	;; es:di : Video memory base
	;; AX : X coordinate
	;; BX : Y coordinate
	;; DL : Color
putPixel:
	push ax
	push cx
	push dx
	push di
	push si
	push ds

	mov si, bx
	shl si, 1
	add si, cgarows
	add di, [si]

	mov cx,es
	mov ds,cx

	; Isolate the correct 2 bits
	mov cl, al
	xor cl, 0xff
	and cl, 3
	shl cl, 1 ; 2 bpp

	; Prepare mask and value to OR simultaneously
	; dl holds color in 2 lower bits
	and dx, 0x0003
	or dx, 0xfcfc
	rol dx, cl
	xor dl, dh ; Cleanup pixel

	; SI + X / 4
	shr ax, 1
	shr ax, 1
	add di, ax

	mov si, di ; Need to read pixel first

	lodsb ; read pixel to al

	and al, dh ; mask pixel
	or al, dl ; Apply pixel

	; Write the pixel back
	stosb ; al

	pop ds
	pop si
	pop di
	pop dx
	pop cx
	pop ax
	ret

%macro getPixelMacro_clobCX_DX_SI 0
	push ax
	; row address
	mov si, bx
		shl si, 1
		add si, cgarows
		mov si, [si]
		add si, di

	; row offset
	mov dx, ax
	shr dx, 1
	shr dx, 1
	add si, dx
	; Isolate the correct 2 bits
	mov cl, al
	inc cl
	and cl, 3
	shl cl, 1
	ES lodsb ; DS:SI to al
	rol al, cl
	and al, 3
	mov dl, al
	pop ax
%endmacro

	;;;; get pixel
	;; es:di : Video memory base
	;; AX : X coordinate
	;; BX : Y coordinate
	; Return the color value in DL
	; Incidently, the zero flag is set if pixel is zero.
getPixel:
	push ax
	push cx
	push si

	; row address
	mov dx, bx
		shl bx, 1
		add bx, cgarows
		mov si, di
		add si, [bx]
	mov bx, dx


	; row offset
	mov dx, ax
	shr dx, 1
	shr dx, 1
	add si, dx

	; Isolate the correct 2 bits
	mov cl, al
	inc cl
	and cl, 3
	shl cl, 1
	ES lodsb ; DS:SI to al

	rol al, cl
	and ax, 3
	mov dx, ax

	pop si
	pop cx
	pop ax

	ret


;;;; getFontTile : Point DS:SI to a given tile ID
; Ascii in AL (range 32 - 255)
getFontTile:
	push ax
	push cx

	xor ah,ah
	sub al, 32
	mov cl, 4
	shl ax, cl
	add ax, font8x8
	mov si, ax

	pop ax
	pop cx
	ret


;;;; blit_imageXY : Blit an arbitrary size image at coordinate
;
; ds:si : Pointer to tile data
; es:di : Video memory base (b800:0)
; ax: X coordinate (in pixels) (ANDed with 0xfffc)
; bx: Y coordinate (in pixels) (ANDed with 0xfffe)
; cx: Image width (must be multiple of 4)
; dx: Image height (must be multiple of 2)
;
blit_imageXY:
	push ax
	push bx
	push cx
	push dx

	push di

	; X /= 4 (4 pixel per memory byte)
	shr ax, 1
	shr ax, 1
	add di, ax ; Offset in line

	; Y /= 2 (only support even scanlines)
	shr bx, 1

	; Y *=80 (skip to target row)
	mov ax, 80
	push dx
	mul bx
	pop dx

	add di, ax

	;; 
	mov bx, dx ; Height
	shr cx, 1 ; Convert width pixels to bytes (/4)
	shr cx, 1
	call blit_image

	pop di

	pop dx
	pop cx
	pop bx
	pop ax
	ret


;;;; blit_image : Blit an arbitrary image to a specified screen location.
; ds:si : Pointer to tile data
; es:di : Offset (in video memory) (Note: Must be on an even line)
; bx: Number of lines
; cx: Number of bytes per line
;
; Due to the CGA low-res packing arrangement, the offset value given
; in byte places the tile on a grid of 4 pixels.
blit_image:
	push ax
	push bx
	push cx
	push dx
	push ds
	push si
	push es
	push di

	; save pointer in dx
	mov dx, di

	; pre-compute how many byte to next line
	mov ax, 80
	sub ax, cx ; ax = increment

	; Save BX and compute the number of even lines >> 1
	push bx
	shr bx, 1

_bi_lp:
	push cx
	rep movsb
	pop cx

	add di, ax ; Next line

	dec bx
	jnz _bi_lp


	;llll Even lines are done. restore original BX
	pop bx
	shr bx, 1 ; Divide by 2 again
	jz _bi_done ; 0 means there was a single line. Already blitted above, nothing to do.

	mov di, dx ; Restore origin pointer
	add di, 0x2000 ; Skip to odd field

_bi_lp2:
	push cx
	rep movsb
	pop cx

	add di, ax ; Next line

	dec bx
	jnz _bi_lp2


_bi_done:
	pop di
	pop es
	pop si
	pop ds
	pop dx
	pop cx
	pop bx
	pop ax
	ret


setHighIntensity:
	push ax
	push dx

	mov dx, 3D9h
	mov al, 0x10
	out dx, al

;;; VGA
	;mov ah, 0x0b
	;mov bh, 0
	;mov bl, 0x10
	;int 10h
;;; END VGA

;;; VGA
	mov ax, 1000h
	mov bl, 2
	mov bh, 0x14
	int 10h
	mov bl, 3
	mov bh, 0x16
	int 10h
;;; END VGA

	pop dx
	pop ax
	ret

setLowIntensity:
	push ax
	push dx

	mov dx, 3D9h
	mov al, 0x00
	out dx, al

;;; VGA
	;mov ah, 0x0b
	;mov bh, 0
	;mov bl, 0x00
	;int 10h
;;; END VGA

;;; VGA
	mov ax, 1000h
	mov bl, 2
	mov bh, 0x4
	int 10h
	mov ax, 1000h
	mov bl, 3
	mov bh, 0x6
	int 10h
;;;

	pop dx
	pop ax
	ret


;;;; Set background color
; BL : Color (IBGR)
setBackgroundColor:
	push ax
	push bx
;	push dx

	mov ah, 0Bh	; Set palette
	mov bh, 0 ; background
;	mov bl, 0
	int 10h

;	mov dx, 03d9h
;	mov al, [reg_3d9h]
;	and al, 0f0h
;	or al, bl
;	out dx, al
;	mov [reg_3d9h], al

;	pop dx
	pop bx
	pop ax
	ret

;;;; Flash background
flashBackground:
	push ax
	push bx
	push cx
	push dx

	call waitVertRetrace
	mov bl, 06h ; Brow
	call setBackgroundColor

	call waitVertRetrace
	call waitVertRetrace
	call waitVertRetrace
	call waitVertRetrace
	mov bl, 0Eh ; Yellow
	call setBackgroundColor

	call waitVertRetrace
	call waitVertRetrace
	call waitVertRetrace
	call waitVertRetrace
	mov bl, 0 ; Black
	call setBackgroundColor

	pop dx
	pop cx
	pop bx
	pop ax

	ret

	;;;; Initialize video library.
initvlib:
	call initvlib_common
	call initAnimations
	ret

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

	mov ah, 00h ; Set video mode
	mov al, 04h ; Mode 4
	int 10h

	mov ah, 0fh ; Get Video State
	int 10h

	cmp al, 04h ; Mode 4
	je _set_video_mode_ok

	stc ; Indicate failure
	jmp _set_video_mode_return

	; Ok
_set_video_mode_ok:
	mov ah, 0bh	; Set palette
	mov bh, 1 ; 4-color palette select
	;mov bl, 0 ; green/red/brown
	mov bl, 1 ; cyan magenta white
	int 10h

	mov ah, 0Bh	; Set palette
	mov bh, 0 ; background
	mov bl, 0
	int 10h

	clc ; Clear carry (success)
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

	;;;;;;;;;;;;;;
	; getTile8 : Points DS:SI to a given tile ID
	; Tile ID in AX
getTile8:
	push ax
	push cx

	mov cl, 4
	shl ax, cl
	add ax, first8x8_tile
	mov si, ax

	pop cx
	pop ax
	ret

	;;;;;;;;;;;;;;
	; getTile32 : Points DS:SI to a given tile ID
	; Tile ID in AX
getTile32:
	push ax
	push cx

	mov cl, 8
	shl ax, cl
	add ax, first32x32_tile
	mov si, ax

	pop cx
	pop ax
	ret


	;;;;;;;;;;;;;;
	; getTile16 : Points DS:SI to a given tile ID
	; Tile ID in AX
getTile16:
	push ax
	push cx

	mov cl, 6
	shl ax, cl ; x64
	add ax, first16x16_tile
	mov si, ax

	pop cx
	pop ax
	ret

; Decompress to buffer, then copy to screen
; Arg 1: compressed data address
%macro loadScreen 1
	mov si, %1
	mov ax, ds
	mov es, ax
	mov di, screen_backup
	call lz4_decompress
	; Restore ES:DI
	call setupVRAMpointer
	call restorescreen
%endmacro



section .data

font8x8: incbin "res_cga/font.bin" ; Starts at ASCII 32
cgarows: incbin "res_cga/rows.bin"

section .bss

reg_3d9h: resb 1	; Register is write only
screen_backup: resb 2000h + (320*100/4)

section .text

%include 'cgalib_blit8x8.asm'
%include 'cgalib_blit16x16.asm'
%include 'cgalib_effects.asm'
