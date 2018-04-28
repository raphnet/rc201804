%ifndef _vgaregs_asm_
%define _vgaregs_asm_

; Sequencer port and indexes
%define VGA_SQ_PORT	0x3C4
%define VGA_SQ_MAP_MASK_IDX	2

; Graphic port and indexes
%define VGA_GC_PORT	0x3CE
%define VGA_GC_SET_RESET_IDX	0
%define VGA_GC_EN_SET_RESET_IDX	1
%define VGA_GC_DATA_ROTATE_IDX	3
%define VGA_GC_MODE_IDX			5
%define VGA_GC_BIT_MASK_IDX		8

%define VGA_GC_ROTATE_ASIS		0
%define VGA_GC_ROTATE_AND		8

%endif ; _vgaregs_asm_
