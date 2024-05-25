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

str_thanks1: resw 1
str_thanks2: resw 1
str_thanks3: resw 1
str_thanks4: resw 1
str_thanks5: resw 1
str_thanks6: resw 1
str_thanks7: resw 1
str_thanks8: resw 1
str_thanks9: resw 1

str_click_mouse_button_or: resw 1
str_pull_trig_to_start: resw 1
str_Pull_trig_to_start: resw 1
str_press_esc_to_quit: resw 1

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

	defineString str_thanks1, "Rain Zapper v1.1"
	defineString str_thanks2, "Copyright (C) 2018 Raphael Assenat"
	defineString str_thanks3, "Made for RC2018/04"
	defineString str_thanks4, ""
	defineString str_thanks5, "Special thanks and greetings to:"
	defineString str_thanks6, " - Sion for sketching the title screen illustration"
	defineString str_thanks7, " - Jim Leonard for his 8088 LZ4 decompression code"
	defineString str_thanks8, ""
	defineString str_thanks9, "Thank you for playing!"

	defineString str_click_mouse_button_or, "Click left mouse button or"
	defineString str_pull_trig_to_start, "pull the trigger to start playing!"
	defineString str_Pull_trig_to_start, "Pull the trigger to start playing!"
	defineString str_press_esc_to_quit, "Press ESC to quit"
%define NUM_STR_THANKS	9

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

	defineString str_thanks1, "Rain Zapper v1.1"
	defineString str_thanks2, "Copyright (C) 2018 Raphael Assenat"
	defineString str_thanks3, "Fait pour RC2018/04"
	defineString str_thanks4, ""
	defineString str_thanks5, "Remerciements et salutations:"
	defineString str_thanks6, " - À Sion pour l'esquisse de l'écran d'accueil"
	defineString str_thanks7, " - À Jim Leonard pour le code de décompression LZ4"
	defineString str_thanks8, ""
	defineString str_thanks9, "Merci d'avoir joué!"

	ret

