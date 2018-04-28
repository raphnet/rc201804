%ifndef _vgaregs_asm_
%define _vgaregs_asm_

; Sequencer port and indexes
%define VGA_SEQUENCER_PORT	0x3C4

; Graphic port and indexes
%define VGA_GC_PORT	0x3CE
%define VGA_GC_DATA_ROTATE_IDX	3

%define VGA_GC_ROTATE_ASIS		0
%define VGA_GC_ROTATE_AND		8

%endif ; _vgaregs_asm_
