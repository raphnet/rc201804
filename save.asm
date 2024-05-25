
loadBestScore:

.open:
	mov ah, 0x3D    ; Open file by handle
	mov al, 0x00    ; Read-only
	mov dx, rec_filename
	int 21h
	jc .done
	; File handle in AX

.read:
	mov bx, ax      ; File handle
	mov ah, 0x3F    ; Read from file
	mov cx, SCORE_DIGITS
	mov dx, high_score
	int 21h
	jc .error
	jmp .close

.error:
.close:
	mov ah, 0x3e
	int 21h

.done:
	ret


saveBestScore:

.open:
	mov ah, 0x3C    ; Create file by handle
	mov cx, 0
	mov dx, rec_filename
	int 21h
	jc .error

.write:
	mov bx, ax      ; file handle
	mov ah, 0x40    ; write to file
	mov cx, SCORE_DIGITS
	mov dx, high_score
	int 21h
	jc .write_failed

	; otherwise, we are done
	jmp .close

.close:
	mov ah, 0x3e
	int 21h

.return:
	printStringLn "Best score saved."
	ret

.write_failed:
	mov ah, 0x3e ; close file, then display error
	int 21h

.error:
	printStringLn "Could not save best score"
	ret


