
section .text

	; CX : Number
	; DS:BX : Destination string
itoa:
	push ax
	push bx
	push cx
	push dx
	push es
	push di

	mov ax, ds
	mov es, ax
	mov di, bx

	cmp cx, 10
	jl _itoa_less_than_10
	cmp cx, 100
	jl _itoa_less_than_100
	cmp cx, 1000
	jl _itoa_less_than_1000
	cmp cx, 10000
	jl _itoa_less_than_10000

_itoa_less_than_100000:
	mov ax, cx
	mov bx, 10000
	mov dx, 0
	div bx
	mov cx, ax

	add cx, '0'
	mov ax, cx
	stosb

	mov cx, dx

_itoa_less_than_10000:
	mov ax, cx
	mov bx, 1000
	mov dx, 0
	div bx
	mov cx, ax

	add cx, '0'
	mov ax, cx
	stosb

	mov cx, dx

_itoa_less_than_1000:
	mov ax, cx
	mov bx, 100
	mov dx, 0
	div bx
	mov cx, ax

	add cx, '0'
	mov ax, cx
	stosb

	mov cx, dx

_itoa_less_than_100:
	mov ax, cx
	mov bx, 10
	mov dx, 0
	div bx
	mov cx, ax

	add cx, '0'
	mov ax, cx
	stosb

	mov cx, dx
_itoa_less_than_10:
	add cx, '0'
	mov ax, cx
	stosb

_itoa_done:
	pop di
	pop es
	pop dx
	pop cx
	pop bx
	pop ax
	ret

	;;;;
	; BX: Source cstring
	; CX: Destination string
strcpy:
	push ax
	push bx
	push cx
	push dx
	push es
	push di
	push si

	mov ax, ds
	mov es, ax

	mov si, bx
	mov di, cx

	cld
_strcpy_lp:
	lodsb
	stosb
	and al,al
	jnz _strcpy_lp

	pop si
	pop di
	pop es
	pop dx
	pop cx
	pop bx
	pop ax
	ret

	;;;;
	; BX: Zero-terminated string pointer
	; Returns length in CX
strlen:
	push ax
	push bx
	xor cx,cx

_strlen_lp:
	mov al, [bx]
	and al,al
	jz _strlen_end
	inc bx
	inc cx
	jmp _strlen_lp
_strlen_end:
	pop bx
	pop ax
	ret

	;;;;
	; Fill memory with byte values
	; AL: Value
	; BX: Destination
	; CX: Count
memset:
	push ax
	push bx
	push cx
	push dx
	push es
	push di

	mov dx, ds
	mov es, dx
	mov di, bx
	rep stosb

	pop di
	pop es
	pop dx
	pop cx
	pop bx
	pop ax
	ret


	;;;;
	; Fill memory with word values
	; AX: Value
	; BX: Destination
	; CX: Word count
	;
memset16:
	push ax
	push bx
	push cx
	push dx
	push es
	push di

	mov dx, ds
	mov es, dx
	mov di, bx
	rep stosw

	pop di
	pop es
	pop dx
	pop cx
	pop bx
	pop ax
	ret

