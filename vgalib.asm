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

image_width_bytes: resw 1
post_row_di_inc: resw 1

scr_backup_segment: resw 1

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

	; Save the draw_color variable
	mov ah, [draw_color]
	push ax

	mov byte [draw_color], al

	mov ax, 0 ; X start
	; bx already equals Y
	mov dx, cx ; Height in CX (number of lines)
	mov cx, SCREEN_WIDTH
	call fillRect

	; Restore the draw_color variable
	pop ax
	mov [draw_color], ah

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


	;;;;;; Clear (fill with color 0) a 32x32 square
	; AX : X
	; BX : Y
	; ES : Videomem base
	;
	;
	; Note: Byte-aligned squares only
clr32x32:
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

	setMapMask 0xF; all planes

	mov al, 0x00
	mov ah, 4 ; Scanline (4 bytes / 32 bits)
	mov bx, SCREEN_WIDTH / 8 - 4
%rep 32
	mov cl, ah
	rep stosb
	add di, bx
%endrep

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
; es:di : Video memory base
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

	; Convert width to bytes (8 pixels per byte)
	shift_div_8 cx

	; Compute the increment to point DI to the next row after a stride
	mov bx, SCREEN_WIDTH / 8
	sub bx, cx

	; DS:SI received in argument points to the image data

	mov bp, dx ; Keep image height in BP for loop
	mov dx, VGA_SQ_PORT ; Prepare DX for use by setMapMask_dxpreset
	mov al, VGA_SQ_MAP_MASK_IDX
	out dx, al
	inc dx ; point to register

	; Save row width in AH for repeated use below
	mov ah, cl
;	xor ch, ch ; No need, CX is < 80

%macro BLT_PLANE 1 ; plane mask
	; Set map mask
	mov al, %1
	out dx, al

	push di	; Save origin
	push bp
%%next_row:
		mov cl, ah
		rep movsb ; Copy DS:SI to ES:DI
		; Jump to next row
		add di, bx
	dec bp
	jnz %%next_row

	pop bp ; Restore image height for next plane
	pop di ; Restore DI to origin
%endmacro

	BLT_PLANE 0x01
	BLT_PLANE 0x02
	BLT_PLANE 0x04
	BLT_PLANE 0x08

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

;;;; blit_tile32XY : Blit a 32x32 tile to a destination coordinate
;
; ds:si : Pointer to tile data
; es:di : Video memory base
; ax: X coordinate (in pixels) (byte-aligned)
; bx: Y coordinate (in pixels)
;
blit_tile32XY:
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

	; Prepare the increment to point DI to the next row after a stride
	mov bx, SCREEN_WIDTH / 8 - 4
	mov bp, di ; Save the origin

	; DS:SI received in argument points to the image data

	mov dx, VGA_SQ_PORT ; Prepare DX for use by setMapMask_dxpreset
	mov al, VGA_SQ_MAP_MASK_IDX
	out dx, al
	inc dx ; point to register

%macro BLT_PLANE_4BYTES 1 ; plane mask
	; Set map mask
	mov al, %1
	out dx, al

%rep 32
	mov cl, 4
	rep movsb ; Copy DS:SI to ES:DI
	; Jump to next row
	add di, bx
%endrep

	mov di, bp
%endmacro

	BLT_PLANE_4BYTES 0x01
	BLT_PLANE_4BYTES 0x02
	BLT_PLANE_4BYTES 0x04
	BLT_PLANE_4BYTES 0x08

	pop bp
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ax
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
	; getTile64 : Points SI to a given tile ID
	; Tile ID in AX
getTile64:
	push ax
	push cx

	mov cl, 11 ; Multiply by 2048
	shl ax, cl
	add ax, first32x32_tile
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

	mov cl, 9 ; Multiply by 512
	shl ax, cl
	add ax, first32x32_tile
	mov si, ax

	pop cx
	pop ax
	ret

;;;;;;;; Copy the screen content to a memory buffer
;
; args:
;    ES  : Base of video memory
;
savescreen:
	push ax
	push bx
	push cx
	push dx
	push es
	push di
	push ds
	push si

	mov bx, [scr_backup_segment]
	mov ax, es

	; Source for string copy
	mov ds, ax

	; Destination for string copy
	mov es, bx
	xor di, di

	; Prepare values for OUT instrutions to video adapter
	mov dx, VGA_GC_PORT
	mov al, VGA_GC_READ_MAP_SEL_IDX

%macro advES 0
	; Segment increment after each plane
	mov bx, es
	add bx, (SCREEN_WIDTH*SCREEN_HEIGHT)/8/16
	mov es, bx
	xor di,di
%endmacro

%macro cpyPlane 1
	mov ah, %1 ; plane
	out dx, ax
	mov cx, SCREEN_WIDTH*SCREEN_HEIGHT/16
	xor si, si ; Start from segment:0000
	rep movsw ; ES:DI <- DS:SI
%endmacro

	;; Copy each plane

	cpyPlane 0
	advES
	cpyPlane 1
	advES
	cpyPlane 2
	advES
	cpyPlane 3

	pop si
	pop ds
	pop di
	pop es
	pop dx
	pop cx
	pop bx
	pop ax

	ret

;;;;;;;; Copy the screen content to a memory buffer
;
; args:
;    ES  : Base of video memory
;
restorescreen:
	push ax
	push bx
	push cx
	push dx
	push es
	push di
	push ds
	push si

	; The source for copy
	mov bx, [scr_backup_segment]
	mov ds, bx
	xor si:si

	; Prepare VGA writes
	mov dx, VGA_SQ_PORT

%macro restorePlane 1
	setMapMask_dxpreset %1
	mov cx, SCREEN_WIDTH*SCREEN_HEIGHT/16
	xor si, si
	xor di, di
	rep movsw ; ES:DI <- DS:SI
%endmacro

%macro advDS 0
	mov bx, ds
	add bx, (SCREEN_WIDTH*SCREEN_HEIGHT)/8/16
	mov ds, bx
%endmacro

	restorePlane 0x01
	advDS
	restorePlane 0x02
	advDS
	restorePlane 0x04
	advDS
	restorePlane 0x08

	pop si
	pop ds
	pop di
	pop es
	pop dx
	pop cx
	pop bx
	pop ax

	ret

;;;;;;
;
; Load and display screen compressed with LZ4
;
; SI : Source compressed data
;
%macro loadScreen 1
	push ax
	push bx
	push dx
	push si
	push di

	; DS:SI : Source compressed data
	mov si, %1

	; ES:DI : Destination (screen backup)
	;
	; Note: LZ4 also reads/copy decompressed data, so I
	; think decompressing in system memory first, then
	; copying to VRAM is faster.
	;
	push es

		mov bx, [scr_backup_segment]
		mov es, bx
		xor di, di

		; Prepare VAG port writes
		mov dx, VGA_SQ_PORT

		call lz4_decompress
		advES
		call lz4_decompress
		advES
		call lz4_decompress
		advES
		call lz4_decompress

	pop es

	call restorescreen

	pop di
	pop si
	pop dx
	pop bx
	pop ax
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
	;
	; Return with carry set on error
initvlib:
	push ax

	; This is a .COM executable, it should have been allocated the
	; biggest possible chunk of memory available.
	;
	; TODO : Check the PSP to see if we have enough
	;
	mov ax, ds
	add ax, 0x1000
	mov [scr_backup_segment], ax

	call initvlib_common
	pop ax
	ret

%include 'vgalib_effects.asm'

%endif
