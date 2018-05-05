%ifndef _mobj_asm
%define _mobj_asm

%include 'sugar.asm'

STRUC mobj ; mobj -> moving object
	.x: resw 1
	.y: resw 1
	;.w: resw 1
	;.h: resw 1
	.xvel: resw 1
	.yvel: resw 1
	.prev_x: resw 1
	.prev_y: resw 1
	.enabled: resb 1
	.size:
ENDSTRUC

; Macro to declare object in BSS
%define DECLARE_MOBJ(name) name: resb mobj.size

; Use these macros around arrays of declared MOBJ. Objects
; can be grouped in a list by the name argument, to be used
; later with MOBJ_GET_LIST_COUNT and used with MOBJ_LIST_FOREACH.
%macro MOBJ_LIST_START 1 ; List name
%1:
%endmacro
%macro MOBJ_LIST_END 1 ; List name
%1_end: resb mobj.size
%endmacro

; Load number or objects in list in register
%macro MOBJ_GET_LIST_COUNT 2 ; reg list_name
	mov %1, (%2_end - %2) / mobj.size
%endmacro

; Start a loop on all list items.
;
; Uses CX for the loop. Preserve it!
; BP points to the current list item on each iteration.
;
; See also: MOBJ_NEXT
;
%macro MOBJ_LIST_FOREACH 1
	MOBJ_GET_LIST_COUNT cx, %1
	mov bp, %1
.mobj_foreach_lp:
%endmacro

; Continue loop if there are still unprocessed list items;
; Use with MOBJ_FOREACH
%macro MOBJ_NEXT 0
.mobj_foreach_skip:
	add bp, mobj.size
	loop .mobj_foreach_lp
%endmacro

; Start a loop on all enabled list items
%macro MOBJ_LIST_FOREACH_ENABLED 1
	MOBJ_GET_LIST_COUNT cx, %1
	mov bp, %1
.mobj_foreach_lp:
	test byte [bp + mobj.enabled], 0xff
	jz .mobj_foreach_skip
%endmacro

; Start a loop on all enabled list items
%macro MOBJ_LIST_FOREACH_DISABLED 1
	MOBJ_GET_LIST_COUNT cx, %1
	mov bp, %1
.mobj_foreach_lp:
	test byte [bp + mobj.enabled], 0xff
	jnz .mobj_foreach_skip
%endmacro



; Convert stored value (x or y) to screen value
%define MOBJ_XY_TO_SCR(reg) shift_div_16 reg
; Convert screen value to stored (scaled) value
%define MOBJ_XY_FROM_SCR(reg) shift_mul_16 reg
; Mask for the bits corresponding to screen coordinates. Useful
; for comparing scaled values. (see mobj_scr_pos_changed)
%define MOBJ_SCR_MASK 0xfff0

; Macros to set various fields...
%define MOBJ_SETX(obj, val) mov word [obj + mobj.x], val
%define MOBJ_SETY(obj, val) mov word [obj + mobj.y], val
%define MOBJ_SETW(obj, val) mov word [obj + mobj.w], val
%define MOBJ_SETH(obj, val) mov word [obj + mobj.h], val
%define MOBJ_SETXVEL(obj, vel) mov word [obj + mobj.xvel], vel
%define MOBJ_SETYVEL(obj, vel) mov word [obj + mobj.yvel], vel
%macro MOBJ_STOP 1 ; mobj
	MOBJ_SETXVEL(%1, 0)
	MOBJ_SETYVEL(%1, 0)
%endmacro
%macro MOBJ_SETXY 3 ; mobj x y
	MOBJ_SETX(%1, %2)
	MOBJ_SETY(%1, %3)
%endmacro
%macro MOBJ_SETSIZE 3 ; mobj w h
	MOBJ_SETW(%1, %2)
	MOBJ_SETH(%1, %3)
%endmacro
%macro MOBJ_ENABLE 1 ; obj
	mov byte [%1 + mobj.enabled], 1
%endmacro
%macro MOBJ_DISABLE 1 ; obj
	mov byte [%1 + mobj.enabled], 0
%endmacro

; Get an object X screen position
; reg must be a 16-bit register (eg: ax)
; note: Arguments in "natural" order, as if using mov instruction
%macro MOBJ_GET_SCR_X 2 ; regx obj
	; load value
	mov %1, [%2 + mobj.x]
	; scale down to screen
	MOBJ_XY_TO_SCR(%1)
%endmacro
%macro MOBJ_GET_SCR_Y 2 ; regx obj
	; load value
	mov %1, [%2 + mobj.y]
	; scale down to screen
	MOBJ_XY_TO_SCR(%1)
%endmacro
%macro MOBJ_GET_PREV_SCR_X 2 ; regx obj
	; load value
	mov %1, [%2 + mobj.prev_x]
	; scale down to screen
	MOBJ_XY_TO_SCR(%1)
%endmacro
%macro MOBJ_GET_PREV_SCR_Y 2 ; regx obj
	; load value
	mov %1, [%2 + mobj.prev_y]
	; scale down to screen
	MOBJ_XY_TO_SCR(%1)
%endmacro

; Set an object X screen position;
;
; note: Arguments in "natural" order as if using mov instruction
%macro MOBJ_SET_SCR_X 2 ; obj reg/imm
	push ax
	mov_mword_through_ax [%1 + mobj.prev_x], [%1 + mobj.x]
	pop ax
	push ax
	mov ax, %2
	MOBJ_XY_FROM_SCR(ax)
	mov [%1 + mobj.x], ax
	pop ax
%endmacro
%macro MOBJ_SET_SCR_Y 2 ; obj reg/imm
	push ax
	mov_mword_through_ax [%1 + mobj.prev_y], [%1 + mobj.y]
	pop ax
	push ax
	mov ax, %2
	MOBJ_XY_FROM_SCR(ax)
	mov [%1 + mobj.y], ax
	pop ax
%endmacro


; Get object width/height, mov-like syntax
%macro MOBJ_GET_W 2
	mov %1, [%2 + mobj.w]
%endmacro
%macro MOBJ_GET_H 2
	mov %1, [%2 + mobj.h]
%endmacro

%macro MOBJ_CUR_XY_TO_PREV 1
	push ax
	mov_mword_through_ax [%1 + mobj.prev_x], [%1 + mobj.x]
	mov_mword_through_ax [%1 + mobj.prev_y], [%1 + mobj.y]
	pop ax
%endmacro

%macro MOBJ_PREV_XY_TO_CUR 1
	push ax
	mov_mword_through_ax [%1 + mobj.x], [%1 + mobj.prev_x]
	mov_mword_through_ax [%1 + mobj.y], [%1 + mobj.prev_y]
	pop ax
%endmacro

.data:

	;;;;;; mobj_tick : Update an object position
	;
	; Meant to be called at a regular interval.
	; Effect: .x += .xvel, .y += .yvel
	;
	; BP must point to a mobj struc
mobj_tick:
	push ax

	; Save current position
	MOBJ_CUR_XY_TO_PREV bp

	; Load current position value, add velocity, store back
	mov ax, [bp + mobj.x]
	add ax, [bp + mobj.xvel]
	mov [bp + mobj.x], ax
	mov ax, [bp + mobj.y]
	add ax, [bp + mobj.yvel]
	mov [bp + mobj.y], ax
	pop ax
	ret

	;;;;;; mobj_init : Set default (zero) values on an object
	;
	; BP must point to a mobj struct
	;
mobj_init:
	push ax
	push cx
	push es
	push di

	mov ax, ds
	mov es, ax
	mov di, bp
	mov al, 0
	mov cx, mobj.size
	rep stosb

	pop di
	pop es
	pop cx
	pop ax

	ret

	;;;;;; mobj_scr_pos_changed : Check if the screen position of an object has changed
	;
	; Useful to only redraw objects whose position ON SCREEN has changed.
	;
	; BP must point to a mobj struct
	; Zero flag set if unchanged
	;
mobj_scr_pos_changed:
	push ax
	push bx

	mov ax, [bp + mobj.x]
	mov bx, [bp + mobj.prev_x]
	and ax, MOBJ_SCR_MASK
	and bx, MOBJ_SCR_MASK
	cmp ax, bx
	jnz .done

	mov ax, [bp + mobj.y]
	mov bx, [bp + mobj.prev_y]
	and ax, MOBJ_SCR_MASK
	and bx, MOBJ_SCR_MASK
	cmp ax, bx

.done:
	pop bx
	pop ax
	ret

%endif
