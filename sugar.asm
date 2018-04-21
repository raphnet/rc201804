%ifndef _sugar_asm
%define _sugar_asm

section .text

%macro shift_div_8 1
; On later CPUs, this could be replaced by shr %1, 3
	shr %1, 1
	shr %1, 1
	shr %1, 1
%endmacro

%macro shift_div_16 1
; On later CPUs, this could be replaced by shr %1, 4
	shr %1, 1
	shr %1, 1
	shr %1, 1
	shr %1, 1
%endmacro


; Perform an indirect call if the destination is not null
;
; call_if_not_null [address]
;
%macro call_if_not_null 1
	test word %1, 0xffff
	jz %%nocall
	call %1
%%nocall:
%endmacro

; Jump if a memory byte equals an immediate value
;
; jump_if_membyte_equals [address] compare_value label
;
%macro jmp_mbyte_equals 3
	cmp byte %1, %2
	je %3
%endmacro

; Jump if a memory byte does not equal an immediate value
;
; jump_if_membyte_equals [address] compare_value label
;
%macro jmp_mbyte_not_equal 3
	cmp byte %1, %2
	jne %3
%endmacro


; Jump if a memory byte differs from an immediate value
;
; jump_if_mbyte_neq [address] compare_value label
;
%macro jmp_mbyte_neq 3
	cmp byte %1, %2
	jne %3
%endmacro

; Jump if a memory byte is zero
;
; jmp_mbyte_zero [address] dst_label
;
%macro jmp_mbyte_z 2
	test byte %1, 0xff
	jz %2
%endmacro
%define jmp_mbyte_false jmp_mbyte_z

; Jump if a memory byte is non-zero
;
; jmp_mbyte_nz [address] dst_label
;
%macro jmp_mbyte_nz 2
	test byte %1, 0xff
	jnz %2
%endmacro
%define jmp_mbyte_true jmp_mbyte_nz

;;; Move a memory word (memory to memory) using AX as temporary storage
;
; mov_mword_through_ax [dest], [src]
%macro mov_mword_through_ax 2
	mov ax, %2
	mov %1, ax
%endmacro

;;; Move a memory byte (memory to memory) using AL as temporary storage
;
; mov_mbyte_through_al [dest], [src]
%macro mov_mbyte_through_al 2
	mov al, %2
	mov %1, al
%endmacro


%endif
