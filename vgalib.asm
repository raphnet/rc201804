%ifndef vgalib_asm__
%define vgalib_asm__

%include 'vgaregs.asm'

%include 'lang.asm'
%include 'videolib_common.asm'

%define SCREEN_WIDTH	640
%define SCREEN_HEIGHT	480
%define SCREEN_WORDS	((SCREEN_WIDTH/16)*SCREEN_HEIGHT)

; Macro to include a resource file. Argument: Resource name. (unquoted)
;
; A label matching the resource name prefixed by res_ will be created.
; The resource will be included using incbin.
; The full filename will be res_tga/name.tga
;
; i.e:
;   inc_resource droplet
; would include:
;	res_vga16/droplet.tga
; and the label would be:
; res_droplet:
%macro inc_resource 1
res_%1:
%defstr namestr %1
%strcat base "res_vga16/" namestr ; Build left part of path
%strcat filename base ".vga16"
incbin filename
%endmacro

section .bss

image_width_pixels: resw 1
image_width_bytes: resb 1 ; fits since 640 / 8 = 80
post_row_di_inc: resw 1

section .data

	; Generate a lookup table to multiply by the screen pitch
vgarows:
%assign line 0
%rep 480
	dw line*SCREEN_WIDTH/8
%assign line line+1
%endrep

font8x8: incbin "res_vga16/font.bin"

section .text

%macro setMapMask 1
	mov dx, VGA_SQ_PORT
	mov ax, (%1<<8 | VGA_SQ_MAP_MASK_IDX)
	out dx, ax
%endmacro

; Like setMapMask, but DX must be set
; to VGA_SQ_PORT first. For slightly
; faster repeated calling.
%macro setMapMask_dxpreset 1
	;mov dx, VGA_SQ_PORT
	mov ax, (%1<<8 | VGA_SQ_MAP_MASK_IDX)
	out dx, ax
%endmacro

%macro setFunction 1
	mov dx, VGA_GC_PORT
	mov ah, %1
	mov al, VGA_GC_DATA_ROTATE_IDX
	out dx, ax
%endmacro

;
;
%macro draw_color_to_vram 1 ; bit_mask
	setMapMask 0xF; all planes

	; write mode 2
	mov dx, VGA_GC_PORT
	mov al, VGA_GC_MODE_IDX
	mov ah, 2
	out dx, ax

	; Set bit mask
	;mov dx, VGA_GC_PORT
	mov ah, %1
	mov al, VGA_GC_BIT_MASK_IDX
	out dx, ax

	mov al, [draw_color] ; Load color argument in al
	mov [es:di], al

	; write mode
	;mov dx, VGA_GC_PORT
	mov al, VGA_GC_MODE_IDX
	mov ah, 0
	out dx, ax

	;mov dx, VGA_GC_PORT
	mov ah, 0xff
	mov al, VGA_GC_BIT_MASK_IDX
	out dx, ax

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
	shl bx, 1
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
	draw_color_to_vram 0xff

	; Read back the address once to fill the latches
	mov al, [es:di]

	setMapMask 0xF; all planes
	setFunction VGA_GC_ROTATE_AND ; AND logical function

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
	setFunction VGA_GC_ROTATE_ASIS

	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret

;;;;; Write black over a range of scanlines
;
; This exists since there is an optimisation opportunity
; for this case. But right now, it is just a bad wrapper around
; fillRect...
;
; es:di : Video memory base
; bx: First line
; cx: Number of lines
; al: Color (4-bit, right-aligned)
;
clearLinesRange:
	push ax
	push bx
	push cx
	push dx

	mov al, [draw_color]
	push ax

	mov ax, 0
	; bx already equals Y
	; cx already equals H
	mov dx, SCREEN_WIDTH
	mov byte [draw_color], 0
	call fillRect

	pop ax
	mov [draw_color], al

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
	shl bx, 1
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
	draw_color_to_vram 0xff

	; Read back the address once to fill the latches
	mov al, [es:di]

	setMapMask 0xF; all planes
	setFunction VGA_GC_ROTATE_AND ; AND logical function

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
	setFunction VGA_GC_ROTATE_ASIS

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

;;;; blit_imageXY : Blit an arbitrary size image at coordinate
;
; ds:si : Pointer to tile data
; es:di : Video memory base (b800:0)
; ax: X coordinate
; bx: Y coordinate
; cx: Image width (must be multiple of 8)
; dx: Image height
;
blit_imageXY:
	push ax
	push bx
	push cx
	push dx
	push si
	push di
	push bp

	; Skip to Y row
	shl bx, 1
	add di, [vgarows+bx]
	; Skip to X position in row : di += ax / 8
	shift_div_8 ax
	add di, ax

	; Store original CX value, compute number of bytes
	mov [image_width_pixels], cx
	shift_div_8 cx
	mov [image_width_bytes], cl

	; Compute the increment to point DI to the next row after a stride
	mov bx, SCREEN_WIDTH / 8
	sub bx, cx ; CX still holds width in bytes

	; height already placed in DX by caller. But DX is needed for out instruction.
	mov bp, dx
	mov dx, VGA_SQ_PORT
	.next_row:
		mov cl, [image_width_bytes]
		.lp_in_row:
			setMapMask_dxpreset 0x1 ; Blue
			lodsb ; AL = DS:SI
			es mov [di], al

			setMapMask_dxpreset 0x2 ; Green
			lodsb ; AL = DS:SI
			es mov [di], al

			setMapMask_dxpreset 0x4 ; Red
			lodsb ; AL = DS:SI
			es mov [di], al

			setMapMask_dxpreset 0x8 ; Intensity
			lodsb ; AL = DS:SI
			es mov [di], al
			inc di
			dec cl
		jnz .lp_in_row

		add di, bx

		dec bp
	jnz .next_row

	pop bp
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ax
	ret

;;;; blit_tile8XY : Blit a 8x8 tile to a destination coordinate
;
; Exists since there is an optimisation opportunity, but right now
; it only calls blit_imageXY
;
; ds:si : Pointer to tile data
; es:di : Video memory base
; ax: X coordinate (in pixels) (ANDed with 0xfffc)
; bx: Y coordinate (in pixels) (ANDed with 0xfffe)
blit_tile8XY:
	push cx
	push dx
	mov cx, 8
	mov dx, cx
	call blit_imageXY
	pop dx
	pop cx
	ret

;;;; blit_tile8XY : Blit a 8x8 tile to a destination coordinate
;
; Exists since there is an optimisation opportunity, but right now
; it only calls blit_imageXY
;
; ds:si : Pointer to tile data
; es:di : Video memory base
; ax: X coordinate (in pixels) (ANDed with 0xfffc)
; bx: Y coordinate (in pixels) (ANDed with 0xfffe)
;
blit_tile16XY:
	push cx
	push dx
	mov cx, 16
	mov dx, cx
	call blit_imageXY
	pop dx
	pop cx
	ret

	;;;;;; Get the color of a single pixel
	;
	; Args:
	;   es:di : Video memory base
	;   AX : X coordinate
	;   BX : Y coordinate
	;
	; Return:
	;   DX : Color
	;   Incidently, the zero flag is set if pixel is zero.
getPixel:
	push ax
	push bx
	push cx
	push di

	; Skip to Y row
	shl bx, 1
	add di, [vgarows+bx]
	; Skip to X position in row : di += ax / 8
	mov cx, ax ; save original X first
	shift_div_8 ax
	add di, ax

	and cl, 0x7
	mov bl, 0x80
	shr bl, cl ; BL will be used to mask the pixel

	xor bh, bh ; Color will be built in BH

	; Note: Read mode 0 assumed
	mov dx, VGA_GC_PORT
	mov al, VGA_GC_READ_MAP_SEL_IDX


	mov ah, 0 ; plane number (blue)
	out dx, ax
	mov cl, [es:di] ; Read 8 pixels
	and cl, bl ; Mask ours
	jz .a
	or bh, 0x01
.a:

	mov ah, 1 ; plane number (green)
	out dx, ax
	mov cl, [es:di] ; Read 8 pixels
	and cl, bl ; Mask ours
	jz .b
	or bh, 0x02
.b:

	mov ah, 2 ; plane number (red)
	out dx, ax
	mov cl, [es:di] ; Read 8 pixels
	and cl, bl ; Mask ours
	jz .c
	or bh, 0x04
.c:

	mov ah, 3 ; plane number (intensity)
	out dx, ax
	mov cl, [es:di] ; Read 8 pixels
	and cl, bl ; Mask ours
	jz .d
	or bh, 0x08
.d:

	mov dl, bh
	and dl, dl ; return with ZF set if black

	pop di
	pop cx
	pop bx
	pop ax
	ret

	;;;;;; Set the color of a single pixel
	;
	; es:di : Video memory base
	; AX : X coordinate
	; BX : Y coordinate
	; DL : Color
putPixel:
	push ax
	push bx
	push cx
	push dx
	push di

	; Skip to Y row
	shl bx, 1
	add di, [vgarows+bx]
	; Skip to X position in row : di += ax / 8
	mov cx, ax ; save original X first
	shift_div_8 ax
	add di, ax

	and cl, 0x7
	mov bl, 0x80
	shr bl, cl

	mov [draw_color], dl
	mov al, [es:di] ; dummy ready
	draw_color_to_vram bl

	pop di
	pop dx
	pop cx
	pop bx
	pop ax

	ret

;;;; getFontTile : Point DS:SI to a given tile ID
; Ascii in AL (range 32 - 255)
getFontTile:
	mov si, ax
	and si, 0xff
	shift_mul_32 si
	add si, font8x8 - (8*8/2)*32
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

; TODO
savescreen:
	ret

; TODO
restorescreen:
	ret

; TODO
%macro loadScreen 1
%endmacro

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

%include 'vgalib_effects.asm'

%endif
