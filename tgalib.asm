; Based on a quick and dirty library for CGA Low-res mode
; By Raphaël Assénat, started May 2016
;
;

%define BITS_PER_PIXEL	4

%include 'lang.asm'
%include 'animation.asm'
%include 'videolib_common.asm'

%define get16x16TileID(label)	((label-first16x16_tile)/(4*32))
%define effect_height(h)	((h) * 250 / 200);  TODO

; Macro to include a resource file. Argument: Resource name. (unquoted)
;
; A label matching the resource name prefixed by res_ will be created.
; The resource will be included using incbin.
; The full filename will be res_tga/name.tga
;
; i.e:
;   inc_resource droplet
; would include:
;	res_tga/droplet.tga
; and the label would be:
; res_droplet:
%macro inc_resource 1
res_%1:
%defstr namestr %1
%strcat base "res_tga/" namestr ; Build left part of path
%strcat filename base ".tga"
incbin filename
%endmacro

section .text

;;;;;
;
; Clear a 8x8 rectangle
; AX : X
; BX : Y
; ES : video memory base
clr8x8:
	push ax
	push cx
	push di

	mov di, bx
	shl di, 1
	add di, tgarows
	mov di, [di]

	test al, 1
	jnz _clr8x8_odd_x

	shr ax, 1
	add di, ax
	mov cx, 4

_clr8x8_even_x:
	mov ax, 0
_clr8x8_even_x_lp:
	stosw
	stosw
	add di, 160-4
	stosw
	stosw
	add di, 0x2000 - 4 - 160
	js _clr8x8_even_x_adv
	loop _clr8x8_even_x_lp
	pop di	; done
	pop cx
	pop ax
	ret

_clr8x8_even_x_adv:
	and di, 0x1FFF
	add di, 160
	loop _clr8x8_even_x_lp
	pop di	; done
	pop cx
	pop ax
	ret

_clr8x8_odd_x:
	shr ax, 1
	add di, ax
	mov cx, 4

	mov ax, 0
_clr8x8_odd_x_lp:
	stosw
	stosw
	stosb
	add di, 160-5
	stosw
	stosw
	stosb
	add di, 0x2000 - 5 - 160
	js _clr8x8_odd_x_adv
	loop _clr8x8_odd_x_lp
	pop di	; done
	pop cx
	pop ax
	ret

_clr8x8_odd_x_adv:
	and di, 0x1FFF
	add di, 160
	loop _clr8x8_odd_x_lp
	pop di	; done
	pop cx
	pop ax
	ret

;;;;;
; es:di : Video memory base
; bx: First line
; cx: Number of lines
; al: Color (4-bit, right-aligned)
;
clearLinesRange:
	push ax
	push bx
	push cx
	push di


	mov ah, al
	shl ah, 1
	shl ah, 1
	shl ah, 1
	shl ah, 1
	or ah, al
	mov al, ah

	mov di, bx
	shl di, 1
	add di, tgarows
	mov di, [di]

	mov bx, cx ; Use bx to count lines

_clr_next_line:
	mov cx, 80
	rep stosw

	dec bx
	jz _clr_done

	add di, 0x2000 - 160
	js _clr_incr
	jmp _clr_next_line

_clr_incr:
	and di, 0x1FFF
	add di, 160
	jmp _clr_next_line

_clr_done:
	pop di
	pop cx
	pop bx
	pop ax

	ret

;;;; blit_imageXY : Blit an arbitrary size image at coordinate
;
; ds:si : Pointer to tile data
; es:di : Video memory base (b800:0)
; ax: X coordinate (in pixels) (ANDed with 0xfffc)
; bx: Y coordinate (in pixels) (ANDed with 0xfffe)
; cx: Image width (must be multiple of 4)
; dx: Image height (must be multiple of 4)
;
blit_imageXY: ; TODO
	push ax
	push bx
	push cx
	push dx
	push di
	push si

	mov di, bx
	shl di, 1
	add di, tgarows
	mov di, [di]

	shr ax, 1
	add di, ax

	; Divide width by four (movsw copies 4 pixels)
	shr cx, 1
	shr cx, 1
	mov bp, cx ; Keep n cycles for stride in BP

	; Divide height by four and keep it in AX
	shr dx, 1
	shr dx, 1
	mov ax, dx

%macro btx_blit_plane	0
	mov ax, dx
%%btx_stride_lp:
	mov cx, bp
	rep movsw
	add di, 160
	sub di, bp
	sub di, bp
	dec ax
	jnz %%btx_stride_lp
%endmacro

%macro di_next_plane	0
	add di, 0x2000
	js %%advance
	jmp %%continue
%%advance:
	and di, 0x1FFF
	add di, 160
%%continue:
%endmacro

	push di
	btx_blit_plane
	pop di
	di_next_plane
	push di
	btx_blit_plane
	pop di
	di_next_plane
	push di
	btx_blit_plane
	pop di
	di_next_plane
	btx_blit_plane

	pop si
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
fillRect:
	push ax
	push bx
	push cx
	push dx
	push di
	push bp

	; Get row pointer
	mov di, bx
	shl di, 1
	add di, tgarows
	mov di, [di]

	; Column offset
	shr ax, 1
	add di, ax

	mov al, [draw_color]
	mov ah, al
	shl ah, 1
	shl ah, 1
	shl ah, 1
	shl ah, 1
	or al, ah
	mov ah, al

	shr cx, 1 ; Divide width by 4 as we are working on 4 pixel blocks
	shr cx, 1
	mov bp, cx ; Keep it in bp
	; dx is our height (number of rows)
_fr_next_row:
	mov cx, bp
	rep stosw
	dec dx
	jz _fr_done
	; next row
	sub di, bp
	sub di, bp
	add di, 0x2000
	js _fr_adv
	jmp _fr_next_row

_fr_adv:
	and di, 0x1fff
	add di, 160
	jmp _fr_next_row

_fr_done:
	pop bp
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret

;;;; blit_tile8XY : Blit a 8x8 tile to a destination coordinate
;
; ds:si : Pointer to tile data
; es:di : Video memory base (b800:0)
; ax: X coordinate (in pixels) (ANDed with 0xfffc)
; bx: Y coordinate (in pixels) (ANDed with 0xfffe)

blit_tile8XY:
	push ax
	push bx
	push cx
	push dx
	push di
	push si

	mov di, bx
	shl di, 1
	add di, tgarows
	mov di, [di]

	shr ax, 1
	jc bt8_unaligned
	add di, ax

	cld

bt8_aligned:
	mov cx, 4
bt8_ln_aligned_lp:
	movsw
	movsw
	add di, 160-4
	movsw
	movsw

	add di, 0x2000 - 4 - 160
	js bt8x_advance

	loop bt8_ln_aligned_lp
	jmp bt8x_done

bt8x_advance:
	and di, 0x1FFF
	add di, 160
	loop bt8_ln_aligned_lp
	jmp bt8x_done

bt8_unaligned:
	add di, ax
	mov cx, 4
bt8_ln_unaligned_lp:
	push cx
	mov cl, 4
	mov dx, 2

bt8_stride2:
	lodsw		; Load 4 pixels
	xchg ah, al	; Restore order
	ror ax, cl	; Move
	mov bl, ah	; 4th pixel to BL high bits
	and ah, 0x0f
	xchg ah, al
	stosw		; Store 3 pixels (first one black)

	lodsw		; Get 4 pixles
	xchg ah, al	; Restore order
	ror ax, cl	; Move
	mov bh, ah	; 4th pixel to BH high bits
	and bl, 0xf0
	and ah, 0x0f
	or ah, bl
	xchg ah, al
	stosw

	and bh, 0xf0
	mov al, bh
	stosb

	dec dx
	jz bt8_strideover

	add di, 160-5
	jmp bt8_stride2
bt8_strideover:

	pop cx

	add di, 0x2000 - 5 - 160
	js bt8x_un_advance

	loop bt8_ln_unaligned_lp
	jmp bt8x_done

bt8x_un_advance:
	and di, 0x1FFF
	add di, 160
	loop bt8_ln_aligned_lp
	jmp bt8x_done



bt8x_done:
	pop si
	pop di
	pop dx
	pop cx
	pop bx
	pop ax

	ret

blit_tile16XY:
	push ax
	push bx
	push cx
	push dx
	push di
	push si

	mov di, bx
	shl di, 1
	add di, tgarows
	mov di, [di]

	shr ax, 1
;	jc bt8_unaligned
	add di, ax

	cld

bt16_aligned:
	mov dx, 4
bt16_ln_aligned_lp:
	mov cx, 4
	rep movsw
	add di, 160-8
	mov cx, 4
	rep movsw
	add di, 160-8
	mov cx, 4
	rep movsw
	add di, 160-8
	mov cx, 4
	rep movsw

	add di, 0x2000 - 3*160-8
	js bt16x_advance

	dec dx
	jnz bt16_ln_aligned_lp
	jmp bt16x_done

bt16x_advance:
	and di, 0x1FFF
	add di, 160
	dec dx
	jnz bt16_ln_aligned_lp
	jmp bt16x_done

bt16x_done:
	pop si
	pop di
	pop dx
	pop cx
	pop bx
	pop ax

	ret

%macro getPixelMacro_clobCX_DX_SI 0
	push ax

	; row address
	mov si, bx
		shl si, 1
		add si, tgarows
		mov si, [si]
		add si, di

	; row offset
	mov dx, ax
	shr dx, 1
	add si, dx

	mov cl, al

	ES lodsb ; ES:SI to al

	and cl, 1
	xor cl, 1
	shl cl, 1
	shl cl, 1

	shr al, cl
	mov dl, al
	xor dh,dh
	and dl, 0x0f

	pop ax
%endmacro

	;;;; get pixel for TGA video memory
	;; es:di : Video memory base
	;; AX : X coordinate
	;; BX : Y coordinate
	;; DL : Color
	; Incidently, the zero flag is set if pixel is zero.
getPixel:
	push ax
	push cx
	push si

	; row address
	mov si, bx
		shl si, 1
		add si, tgarows
		mov si, [si]
		add si, di
;	mov bx, dx

	; row offset
	mov dx, ax
	shr dx, 1
	add si, dx

	mov cl, al

	ES lodsb ; ES:SI to al

	and cl, 1
	xor cl, 1
	shl cl, 1
	shl cl, 1

	shr al, cl
	mov dl, al
	xor dh,dh
	and dl, 0x0f

	pop si
	pop cx
	pop ax

	ret



	;;;; put pixel for TGA video memory
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
	add si, tgarows
	mov di, [si]

	mov cx,es
	mov ds,cx

	; Isolate the correct 2 bits
	mov cl, al
	xor cl, 0xff
	and cl, 1
	shl cl, 1 ; 4 bpp
	shl cl, 1 ; 4 bpp

	; Prepare mask and value to OR simultaneously
	; dl holds color in 4 lower bits
	and dx, 0x000f
	or dx, 0xf0f0
	rol dx, cl
	xor dl, dh ; Cleanup pixel

	; SI + X / 2
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
	mov di, 0
	mov ax, ds
	add ax, 0x1000
	mov es, ax
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
	mov al, 09h ; Tandy 16 color 320x200
	int 10h

	mov ah, 0fh ; Get Video State
	int 10h

	cmp al, 09h ; Tandy 16 color 320x200
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

;;;; getFontTile : Point DS:SI to a given tile ID
; Ascii in AL (range 32 - 255)
getFontTile:
	push ax
	push cx

	xor ah,ah
	sub al, 32
	mov cl, 5
	shl ax, cl
	add ax, font8x8
	mov si, ax

	pop ax
	pop cx
	ret

; es:di : Video memory base
; al: Color (4-bit, right-aligned)
fillScreen:
	push ax
	push bx
	push cx
	push di

	; Repeat the color for each packed pixel over AX
	mov cl, 4
	and al, 0fh
	mov ah, al
	shl al, cl
	or ah, al
	mov al, ah

	; 00 scans
	mov bx, 50
_fs_0_lp:
	mov cx, 80
	rep stosw
	dec bx
	jnz _fs_0_lp

	mov di, 0x2000
	mov bx, 50
_fs_1_lp:
	mov cx, 80
	rep stosw
	dec bx
	jnz _fs_1_lp

	mov di, 0x4000
	mov bx, 50
_fs_2_lp:
	mov cx, 80
	rep stosw
	dec bx
	jnz _fs_2_lp

	mov di, 0x6000
	mov bx, 50
_fs_3_lp:
	mov cx, 80
	rep stosw
	dec bx
	jnz _fs_3_lp

	pop di
	pop cx
	pop bx
	pop ax
	ret

	; Save screen content to backup buffer. (TGA format)
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
	mov di, 0
	mov ax, es
	add ax, 0x1000
	mov es, ax
	;mov di, screen_backup

	mov cx, (6000h + 320*200/4/2) / 2
	rep movsw

%if 0
	mov cx, 320*200/4/2/2 ; 320x200 image, 4 banks, 2 pixels per byte, copy 2 bytes per loop
	rep movsw ; ds:si to es:di

	mov si, 2000h
	mov cx, 320*200/4/2/2
	rep movsw

	mov si, 4000h
	mov cx, 320*200/4/2/2
	rep movsw

	mov si, 6000h
	mov cx, 320*200/4/2/2
	rep movsw
%endif
	pop si
	pop ds
	pop di
	pop es
	pop cx
	pop ax
	ret

	; Restore screen from backup buffer. (TGA format)
	; es:di : Video memory base
restorescreen:
	push ax
	push cx
	push di
	push si

mov ax, ds
add ax, 0x1000
mov ds, ax

	mov si, 0
	;mov si, screen_backup

	mov cx, (6000h + 320*200/4/2) / 2
	rep movsw

%if 0
	mov cx, 320*200/4/2/2
	rep movsw

	mov di, 2000h
	mov cx, 320*200/4/2/2
	rep movsw

	mov di, 4000h
	mov cx, 320*200/4/2/2
	rep movsw

	mov di, 6000h
	mov cx, 320*200/4/2/2
	rep movsw
%endif

mov ax, ds
sub ax, 0x1000
mov ds, ax

	pop si
	pop di
	pop cx
	pop ax
	ret

	;;;;;;;;;;;;;;
	; getTile32 : Points DS:SI to a given tile ID
	; Tile ID in AX
getTile32:
	push ax
	push cx

	mov cl, 9 ; Multiply by 512
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
	push bx
	push cx
	mov bx, first16x16_tile

	; Multiply by 128 (the size for one tile)
	mov cl, 7
	shl ax, cl

	add bx, ax

	mov si, bx
	pop cx
	pop bx
	pop ax
	ret

	;;;;;;;;;;;;;;
	; getTile8 : Points DS:SI to a given tile ID
	; Tile ID in AX
getTile8:
	push ax
	push bx
	push cx
	mov bx, first8x8_tile

	; Multiply by 32 (the size for one tile)
	mov cl, 5
	shl ax, cl

	add bx, ax

	mov si, bx
	pop cx
	pop bx
	pop ax
	ret



section .data

font8x8: incbin "res/tgafont.bin" ; Starts at ASCII 32
tgarows: incbin "res/tgarows.bin"

section .bss
;screen_backup: resb 320*200/2

section .text
	; Include blitters
	; Include common code
%include 'tgalib_effects.asm'
