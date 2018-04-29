%define NUM_LANGUAGES 2

section .data

empty_string: db "",0

section .bss

%macro getStrDX 1
	push bx
	mov bx, %1
	mov dx, [bx]
	pop bx
%endmacro

%macro getStrBX 1
	mov bx, %1
	mov bx, [bx]
%endmacro

; Pointers to strings. Those are pointed to the current
; language by lang_select using the macros below.
str_empty: resw 1
str_yes: resw 1
str_no: resw 1
lang_yes_keys: resw 1
lang_no_keys: resw 1
str_ready: resw 1
str_end_game: resw 1
str_gameover_message: resw 1
str_computer_useless: resw 1
str_new_high_score: resw 1

lang_current: resb 1

; Macros to set string pointers above. Used by language config code.


; Define a pair of characters (used for menu keys)
; 1: pointer name (eg: lang_yes_keys)
; 2: 'yY'
%macro defineCharPair 2
	push ax
	mov ax, %2
	mov [%1], ax
	pop ax
%endmacro

; Define a string.
; 1: pointer name (eg: str_empty)
; 2: The string
%macro defineString 2
section .data
	%%langstr: db %2,0
section .text
	mov word [%1], %%langstr
nop
%endmacro

section .text

; Advance to the next language.
lang_next:
	push ax

	mov al, [lang_current]
	inc al
	cmp al, NUM_LANGUAGES
	jge _first_lang

	call lang_select

	pop ax
	ret

_first_lang:
	mov al, 0
	mov [lang_current], al
	call lang_select

	pop ax
	ret

; AL : Language ID
;
; 0 : French
; 1 : English
;
lang_select:
	mov [lang_current], al
	and al,al
	jz _lang_fr

_lang_en: ; English language strings
	mov word [str_empty], empty_string
	defineCharPair lang_yes_keys, 'yY'
	defineCharPair lang_no_keys, 'nN'
	defineString str_yes, "Yes"
	defineString str_no, "No"

	defineString str_ready, "Ready?"
	defineString str_end_game, "End game?"

	defineString str_computer_useless, "Your computer is now useless,"
	defineString str_gameover_message, "you can't even type POKE anymore!"

	defineString str_new_high_score, "New high score!"

	ret

_lang_fr: ; French language strings
	mov word [str_empty], empty_string
	defineCharPair lang_yes_keys, 'oO'
	defineCharPair lang_no_keys, 'nN'
	defineString str_yes, "Oui"
	defineString str_no, "Non"

	defineString str_ready, "Êtes-vous prêt?"
	defineString str_end_game, "Arrêter la partie?"

	defineString str_computer_useless, "Votre ordinateur est inutile,"
	defineString str_gameover_message, "vous ne pouvez même plus écrire POKE"

	defineString str_new_high_score, "Nouveau record!"

	ret

