%include 'string.asm'
%include 'sin.asm'
%include 'sugar.asm'
%include 'lz4.asm'

%define INPUT_BUFFER_WORDS	8

section .text

%macro hline 4 ; X, Y, length, color
mov ax, %1
mov bx, %2
mov cx, %3
mov dl, %4
call putHorizLine
%endmacro

; Decompress to buffer, then copy to screen
; Arg 1: compressed data address
%macro loadScreenCGA 1
	mov si, %1
	mov ax, ds
	mov es, ax
	mov di, screen_backup
	call lz4_decompress
	; Restore ES:DI
	call setupVRAMpointer
	call restorescreen
%endmacro
%macro loadScreenTGA 1
	mov si, %1
	; ES:DI : Destionation (full screen)
	mov ax, ds
	add ax, 0x1000
	mov es, ax
	mov di, 0
	call lz4_decompress
	; Restore ES:DI
	call setupVRAMpointer
	call restorescreen
%endmacro

;;;; blit_tile8XY_center : Blit a 8x8 tile to a destination coordinate, centered
;
; ds:si : Pointer to tile data
; es:di : Video memory base (b800:0)
; ax: X coordinate (in pixels) (ANDed with 0xfffc)
; bx: Y coordinate (in pixels) (ANDed with 0xfffe)
;
;
;
blit_tile8XY_center:
	push ax
	push bx
	sub ax, 4
	sub bx, 4
	call blit_tile8XY
	pop bx
	pop ax
	ret

;;;;;;
;
; Clear the screen (fill with color 0)
;
clearScreen:
	push ax
	mov al, 0 ; color
	call fillScreen
	pop ax
	ret

%ifndef OPTIMISED_PUT_VERT_LINE
	;;;; put horizotal line
	;; es:di : Video memory base
	;; AX : X coordinate
	;; BX : Y coordinate
	;; CX ; Line length
	;; DL : Color
putVertLine:
	push bx
	push cx

_pvl_lp:
	call putPixel
	inc bx
	loop _pvl_lp

	pop cx
	pop bx
	ret
%endif

%ifndef SET_BGCOLOR_IMPLEMENTED
setBackgroundColor:
	ret
%endif
%ifndef FLASH_BACKGROUND_IMPLEMENTED
flashBackground:
	ret
%endif
	;;;; put horizotal line
	;; es:di : Video memory base
	;; AX : X coordinate
	;; BX : Y coordinate
	;; CX ; Line length
	;; DL : Color
putHorizLine:
	push ax
	push cx

_phl_lp:
	call putPixel
	inc ax
	loop _phl_lp

	pop cx
	pop ax
	ret

;;;; blit_tile
; ds:si : Pointer to tile data
; es:di : Video memory base (b800:0)
; ax: X coordinate (in pixels)
; bx: Y coordinate (in pixels)
;
blit_tile32XY:
	push cx
	push dx
	mov cx, 32
	mov dx, 32
	call blit_imageXY
	pop dx
	pop cx
	ret


	;;;;; Draw box (not filed)
	; es:di : Video memory base
	; ax : X origin
	; bx : Y origin
	; cx : Width
	; dx : Height
	; byte [draw_color] : Color
drawBox:
	push dx
	mov dl, [draw_color]
	call putHorizLine
	pop dx

	push dx
	push cx
	mov cx, dx
	mov dl, [draw_color]
	call putVertLine
	pop cx
	pop dx

	push dx
	push bx
	add bx, dx
	mov dl, [draw_color]
	call putHorizLine
	pop bx
	pop dx

	push dx
	push ax
	push cx
	add ax, cx
	mov cx, dx
	inc cx
	mov dl, [draw_color]
	call putVertLine
	pop cx
	pop ax
	pop dx

	ret

	;;;;;;;;
	; Read all buffered keystrokes, returning CF true if ESC is found
	;
checkESCpressed:
	push ax

_cep_flushmore:
	mov ah, 1
	int 16h
	jz _cep_done
	; remove key from buffer
	mov ah, 0
	int 16h
	cmp al, 27
	jz _cep_done_esc
	jmp _cep_flushmore

_cep_done_esc:
	stc
	pop ax
	ret

_cep_done:
	clc
	pop ax
	ret


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Read keyboard buffer until empty.
	;
flushkeyboard:
	push ax
_flushmore:
	mov ah, 1
	int 16h
	jz _nomorekeys
	; remove key from buffer
	mov ah, 0
	int 16h
	jmp _flushmore

_nomorekeys:
	pop ax
	ret

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; CX : Default value to put in input buffer
	;
inputNumberSetDefault:
	push bx
		call clearInputBuffer
		mov bx, input_buffer
		call itoa
	pop bx
	ret

	;;;;;;;;;;;;;;;;;;;;;;;;;;
	; CX : Value to load in input buffer
	; If CX < 0, input buffer left empty
	;
inputNumberRecall:
	push bx
		call clearInputBuffer
		cmp cx, 0
		jl _inr_empty
		mov bx, input_buffer
		call itoa
_inr_empty:
	pop bx
	ret

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; AX : X coordinate
	; BX : Y coordinate
	; CL : Max number of digits
	; CH : Flags
	;         0x01 : No buffer clear [use content as default value])
	;
	; DX : Label (set to 0 for none)
	;
	; Returns number in CX
	;
	; if CF,
	;	CX = 0 : Empty string
	;	CX = 1 : ESC pressed
inputNumber:
	push ax
	push bx
	push dx
	push ds
	push si

	mov byte [input_mode_numeric], 1
	call inputString
	mov byte [input_mode_numeric], 0
	jc _in_escape
	test byte [input_buffer], 0xff
	jnz _in_not_empty

	; Return empty
	mov cx, 0
_in_cf_return:
	stc
	pop si
	pop ds
	pop dx
	pop bx
	pop ax
	ret

_in_escape:
	mov cx, 1
	jmp _in_cf_return

_in_not_empty:

	mov si, input_buffer

	mov bx,0
_inum_lp:
	lodsb
	cmp al, 0
	jz _inum_str_done
	cmp al, ' '
	jz _inum_str_done

	cmp al, '0'
	JL _inum_str_done
	cmp al, '9'
	jg _inum_str_done

	; Now we know we have a digit
	sub al, '0'
	xor ah,ah
	push ax ; Save the new digit

		; Multiply the current value by 10
		mov ax, bx
		mov cl, 10
		mul cl
		mov bx, ax

		; Add the new value
	pop ax ; Restore the new digit
	add bx, ax

	jmp _inum_lp

_inum_str_done:
	mov cx, bx

	pop si
	pop ds
	pop dx
	pop bx
	pop ax
	ret


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Add the width of a string to AX
	;
	; Inputs:
	;   AX : Current X value
	;   DX : String
	; Output:
	;   AX : AX + strlen(DX) * 8
skipStringAX:
	push bx
	push cx

	mov bx, dx
	call strlen
	shl cx, 1
	shl cx, 1
	shl cx, 1
	add ax, cx

	pop cx
	pop bx
	ret


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Substract the width of a string from AX
	;
	; Inputs:
	;   AX : Current X value
	;   DX : String
	; Output:
	;   AX : AX - strlen(DX) * 8
subStrwidthFromAX:
	push bx
	push cx

	mov bx, dx
	call strlen
	shl cx, 1
	shl cx, 1
	shl cx, 1
	sub ax, cx

	pop cx
	pop bx
	ret




	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Substract the half-width of a string from AX
	; (useful for centering)
	;
	; Inputs:
	;   AX : Current X value
	;   DX : String
	; Output:
	;   AX : AX - strlen(DX) * 4
subHalfStrwidthFromAX:
	push bx
	push cx

	mov bx, dx
	call strlen
	shl cx, 1
	shl cx, 1
	sub ax, cx

	pop cx
	pop bx
	ret


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; AX : X coordinate
	; BX : Y coordinate
	; CL : Max chars
	; CH : Flags (0x01 : No clear buffer)
	; DX : Label
	; [input_mode_password_mode] If non-zero, echoes characters with *
	; [input_mode_numeric] If non-zero, accept only numeric characters
	; Result in [input_buffer]
	;
	; CF set if ESC pressed
	;
	; TAB has the same effect as ENTER, but sets global [tab_pressed]
inputString:
	push ax
	push bx
	push cx
	push dx
	push es
	push di

	call flushkeyboard

	mov byte [tab_pressed], 0

	and dx,dx
	jz _input_string_nolabel

	call drawString

	; Add label length to AX
	push bx
	push cx
		mov bx, dx
		call strlen
		shl cx, 1
		shl cx, 1
		shl cx, 1
		add ax, cx
	pop cx
	pop bx
_input_string_nolabel:

	cld

	and ch, 0x01
	jnz _input_string_noclear

	call clearInputBuffer
_input_string_noclear:

	; strip flags
	xor ch,ch

	push ax
	mov ax, ds
	mov es, ax
	pop ax
	mov di, input_buffer

	push bx
	push cx
	mov bx, input_buffer
	call strlen
	add di, cx
	pop cx
	pop bx

_input_nextchar:
	mov dx, input_buffer

	push es
	push di
		call setupVRAMpointer
		call waitVertRetrace
		call drawString
		push cx
			mov cl, [input_mode_password]
			mov byte [input_mode_password], 0
			push cx
				mov cx, str_cursor
				call drawStringAfterString
			pop cx
			mov [input_mode_password], cl
		pop cx
	pop di
	pop es

	push ax
_is_wait_key:
		call waitVertRetrace
		clc
		call_if_not_null [inputLoopCallback]
		jc _escapeinput

		mov ah,1
		int 16h
		jz _is_wait_key

		mov ah,0
		int 16h

		cmp al, 9
		je _tabinput
		cmp ax, 0F00h ; SHIFT + TAB
		je _tabinput
		cmp ax, 4800h ; up arrow
		je _tabinput
		cmp ax, 5000h ; down arrow
		je _tabinput
		cmp al, 13
		je _doneinput
		cmp al, 27
		je _escapeinput

		cmp al, 8
		jne _not_backspace

		; prepare for backspace. Check if first character
		cmp di, input_buffer
		je _cannot_backspace ; do nothing

		dec di
		xor ax, ax
		stosb
		dec di
		jmp _donecheck

_not_backspace:
		cmp al, 0x20
		jl _donecheck ; Ignore non printable characters

		; Force digits only in numeric mode
		cmp byte [input_mode_numeric], 0
		jz _accept_character
		cmp al, '0'
		jl _donecheck
		cmp al, '9'
		jg _donecheck

_accept_character:

		; Length limit
		mov dx, di
		sub dx, input_buffer
		cmp dx, cx
		jge _donecheck

		stosb
_cannot_backspace:
_donecheck:
	pop ax
	jmp _input_nextchar

_tabinput:
	mov byte [tab_pressed], 1
	jmp _doneinput

_escapeinput:
	stc
_doneinput:
	pop ax

_input_done:
	; Write a space to hide the cursor
	pushf
		call setupVRAMpointer
		call waitVertRetrace
		mov cx, ' '
		call drawCharAfterString
	popf
	pop di
	pop es
	pop dx
	pop cx
	pop bx
	pop ax
	ret


	;;;;;;; Ask a Yes/No question
	; AX: X
	; BX: Y
	; CX: default (0 for no, !0 for yes)
	; DX: Question string
	;
	; CX is 0 for no, !0 for yes
	; CF set if escape was pressed (CX undefined)
askYesNoQuestion:
	push ax
	push bx
	push dx

;	call waitVertRetrace
	call drawString
	push bx
	push cx
		mov bx, dx
		call strlen
		shl cx,1
		shl cx,1
		shl cx,1
		add ax, cx

	pop cx
	pop bx

	push dx
		mov dx, str_cursor
		call drawString
	pop dx

	call flushkeyboard

	push ax

_ayn_again:
	call waitVertRetrace
	test word [yesno_question_loopcallback], 0xffff
	jz _ayn_no_callback
	call [yesno_question_loopcallback]
_ayn_no_callback:
	; Poll first as we do not want to stay stuck in BIOS
	; since music stops.
	mov ah, 1
	int 16h
	jz _ayn_again

	mov ah, 0
	int 16h
	cmp al, 13
	je _ayn_default

	cmp al, [lang_yes_keys]
	je _ayn_yes
	cmp al, [lang_yes_keys+1]
	je _ayn_yes

	cmp al, [lang_no_keys]
	je _ayn_no
	cmp al, [lang_no_keys+1]
	je _ayn_no
	cmp al, 27
	jne _ayn_again

	pop ax
	stc
	jmp _ayn_done

_ayn_default:
	and cx, cx ; Check if default action is 'NO'
	jz _ayn_no
	; OTherwise Y

_ayn_yes:
	pop ax
	getStrDX str_yes
;	mov dx, msg_yes
	call waitVertRetrace
	call drawString
	mov cx, 1
	clc
	jmp _ayn_done

_ayn_no:
	pop ax
	getStrDX str_no
;	mov dx, msg_no
	call waitVertRetrace
	call drawString
	mov cx, 0
	clc
	;jmp _ayn_done

_ayn_done:
	pop dx
	pop bx
	pop ax
	ret


	;;;; Draw a label with a number% following it.
	;
	; AX,BX: X/Y
	; CX: Number
	; DX: Lable string
drawLabelNumberXXpc:
	push ax
	push bx
	push cx
	push dx

	call drawString

	; Get the string length
	push bx
	push cx
		mov bx, dx
		call strlen
		shl cx,1 ; Muliply by 8 (character width)
		shl cx,1
		shl cx,1
		add ax, cx ; Point BX after the string
	pop cx
	pop bx

	call drawNumber ; Draw number CX at AX,BX

	cmp cx, 100
	jl _dlnp_100
	add ax, 8
_dlnp_100:

	mov dx, str_percent
	add ax, 16
	call drawString

	pop dx
	pop cx
	pop bx
	pop ax
	ret


	;;;; Draw a label with a number following it.
	;
	; AX,BX: X/Y
	; CX: Number
	; DX: Lable string
drawLabelNumberXX:
	push ax
	push bx
	push cx
	push dx

	call drawString

	; Get the string length
	push bx
	push cx
		mov bx, dx
		call strlen
		shl cx,1 ; Muliply by 8 (character width)
		shl cx,1
		shl cx,1
		add ax, cx ; Point BX after the string (for the soon to come drawNumber)
	pop cx
	pop bx

	call drawNumber ; Draw number CX at AX,BX

	pop dx
	pop cx
	pop bx
	pop ax
	ret



	; AX : String X
	; BX : String Y
	; CX : CString to append
	; DX : CString to skip
drawStringAfterString:
	push ax
	push bx
	push cx
	push dx

	push bx
	push cx

		mov bx, dx
		call strlen ; length in CX
		shl cx, 1
		shl cx, 1
		shl cx, 1

		add ax, cx

	pop cx
	pop bx

	mov dx, cx
	call drawString

	pop dx
	pop cx
	pop bx
	pop ax
	ret


	; AX : String X
	; BX : String Y
	; CX : Char
	; DX : CString
drawCharAfterString:
	push ax
	push bx
	push cx
	push dx

	push bx
	push cx

		mov bx, dx
		call strlen ; length in CX
		shl cx, 1
		shl cx, 1
		shl cx, 1

		add ax, cx

	; restore Y and character
	pop cx
	pop bx

	call drawChar

	pop dx
	pop cx
	pop bx
	pop ax
	ret

	;;;; Draw a decimal number (left aligned)
	; AX: X
	; BX: Y
	; CX: Number
drawNumber:
	push ax
	push bx
	push cx
	push dx

	cmp cx, 10
	jl _dnxxn_less_than_10
	cmp cx, 100
	jl _dnxxn_less_than_100
	cmp cx, 1000
	jl _dnxxn_less_than_1000
	cmp cx, 10000
	jl _dnxxn_less_than_10000

_dnxxn_less_than_100000:
	push ax
	push bx
		mov ax, cx
		mov bx, 10000
		mov dx, 0
		div bx
		mov cx, ax
	pop bx
	pop ax

	add cx, '0'
	call drawChar
	add ax, 8

	mov cx, dx


_dnxxn_less_than_10000:
	push ax
	push bx
		mov ax, cx
		mov bx, 1000
		mov dx, 0
		div bx
		mov cx, ax
	pop bx
	pop ax

	add cx, '0'
	call drawChar
	add ax, 8

	mov cx, dx


_dnxxn_less_than_1000:
	push ax
	push bx
		mov ax, cx
		mov bx, 100
		mov dx, 0
		div bx
		mov cx, ax
	pop bx
	pop ax

	add cx, '0'
	call drawChar
	add ax, 8

	mov cx, dx

_dnxxn_less_than_100:
	push ax
	push bx
	mov ax, cx
		mov ax, cx
		mov bx, 10
		mov dx, 0
		div bx
		mov cx, ax
	pop bx
	pop ax

	add cx, '0'
	call drawChar
	add ax, 8

	mov cx, dx
_dnxxn_less_than_10:
	add cl, '0'
	call drawChar
	add ax, 8

_dnxxn_done:
	pop dx
	pop cx
	pop bx
	pop ax
	ret


;;;;; Draw a character at a given location
;; AX : X
;; BX : Y
;; CX : Character (8 bit)
drawChar:
	push cx
	push si
	push ax
		test cl, 0x80
		jz _not_latin
		sub cl, 0xa0 - 0x80
_not_latin:
		mov al, cl
		call getFontTile
	pop ax

	call blit_tile8XY

	pop si
	pop cx
	ret

%macro printxy 3
section .data
	%%printxystr: db %3,0
section .text
	push ax
	push bx
	push dx
	mov ax, %1
	mov bx, %2
	mov dx, %%printxystr
	call drawString
	pop dx
	pop bx
	pop ax
%endmacro

;;;;
;; AX : X coordinate
;; BX : Y coordinate
;; DX : Pointer to Cstring
drawString:
	push ax
	push bx
	push cx
	push dx

	test byte [input_mode_password], 0xff
	jz _drawString_normal

_drawString_pw_lp:
	push ax
	push bx
		mov bx,dx
		mov al, [bx]
		inc dx
		and al,al
		jz _drawStringDone
		mov cl, al
	pop bx
	pop ax
	cmp cl, ' ' ; Even in "password mode", spaces are drawn as spaces. This is a hack for inputstring
	jz _draw_exception_space
	mov cl, '*'
_draw_exception_space:
	call drawChar
	add ax, 8
	jmp _drawString_pw_lp
	jmp _drawStringDone

_drawString_normal:

	xor cx,cx

_drawStringLoop:
	; Save XY
	push ax
	push bx

	; Load character
	mov bx, dx
	mov al, [bx]
	inc dx
	and al, al
	jz _drawStringDone

	mov cl, al

	pop bx
	pop ax
	call drawChar

	add ax, 8

	jmp _drawStringLoop

_drawStringDone:
	pop bx
	pop ax

	pop dx
	pop cx
	pop bx
	pop ax
	ret

%ifdef HERCULES
;;;; checkVertRetrace
;
; ZF set when in retrace
checkVertRetrace:
	push ax
	push dx
	mov dx, 3BAh
	in al, dx
	test al, 80h	; Bit 7 goes to 0 during vertical retrace
	pop dx
	pop ax
	ret

waitIfNotVertRetrace:
	push ax
	push dx
	mov dx, 3BAh
	jmp _notInRetrace

waitVertRetrace:
	test byte [skip_vert_retrace], 0FFh
	jnz _skip_vert_retrace
;	ret
	push ax
	push dx
	mov dx, 3BAh
_waitNotInRetrace:
	in al, dx
	test al,80h
	jz _waitNotInRetrace
_notInRetrace:
	in al, dx
	test al,80h
	jnz _notInRetrace
	pop dx
	pop ax
_skip_vert_retrace:
	ret

%else  ; Not HERCULES

;;;; checkVertRetrace
;
; ZF set when in retrace
checkVertRetrace:
	push ax
	push dx
	mov dx, 3DAh
	in al, dx
	and al, 08h
	xor al, 08h
	pop dx
	pop ax
	ret

; This one returns right away if we are already in retrace
waitIfNotVertRetrace:
	push ax
	push dx
	mov dx, 3DAh
	jmp _notInRetrace

;;;; waitretrace
; es-di
waitVertRetrace:
	test byte [skip_vert_retrace], 0FFh
	jnz _skip_vert_retrace
;	ret
	push ax
	push dx
	mov dx, 3DAh
_waitNotInRetrace:
	in al, dx
	test al,08h
	jz _waitNotInRetrace
_notInRetrace:
	in al, dx
	test al,08h
	jnz _notInRetrace
	pop dx
	pop ax
_skip_vert_retrace:
	ret
%endif


;;;; vsync-based delay
; ax: Delay in milliseconds (resolution of ~16ms steps)
;
vsyncdelay:
	push ax
	push cx

	mov cx, ax
	; Divide by 16
	shr cx, 1
	shr cx, 1
	shr cx, 1
	shr cx, 1

_wvr:
	call waitVertRetrace
	loop _wvr

	pop cx
	pop ax
	ret

;;;; vsync-based delay
; ax: Delay in milliseconds (resolution of ~16ms steps)
;
vsyncdelay_interruptible:
	push ax
	push cx

	mov cx, ax
	; Divide by 16
	shr cx, 1
	shr cx, 1
	shr cx, 1
	shr cx, 1

_wvr2:
	call waitVertRetrace

	mov ah, 01
	int 16h
	jnz _wvr_out

	loop _wvr2
_wvr_out:

	pop cx
	pop ax
	ret



	; Blocking function similar to int 16h ah=0, but without
	; getting stuck in BIOS with interrupts potentially disabled
	; which stops background music.
	;
	; Returns values in AX as would int16h ah=0
getKey:
	call waitVertRetrace ; Animations will run
	mov ah, 01
	int 16h
	jz getKey

	; Remove the key from the queue
	mov ah, 0
	int 16h
	ret

	; Block until space is pressed
waitPressSpace:
	call getKey
	cmp al, ' '
	jne waitPressSpace
	ret


	;;;;
	;
	; Clear the inputString buffer
	;
clearInputBuffer:
	push ax
	push bx
	push cx
	mov ax, 0
	mov bx, input_buffer
	mov cx, INPUT_BUFFER_WORDS
	call memset16
	pop cx
	pop bx
	pop ax
	ret

justReturn:
	ret

initvlib_common:
	mov word [yesno_question_loopcallback], justReturn
	call clearInputBuffer
	mov byte [skip_vert_retrace], 0
	ret

section .data

str_percent: db "%",0
str_cursor: db "_ ",0 ; This is the cursor for inputString. The extra space clears characters when backspacing (ugly hack)
input_mode_password: db 0
input_mode_numeric: db 0
inputLoopCallback: dw 0

section .bss

yesno_question_loopcallback: resw 1
skip_vert_retrace: resb 1
old_mode: resb 1
input_buffer: resw INPUT_BUFFER_WORDS
tab_pressed: resb 1
draw_color: resb 1


