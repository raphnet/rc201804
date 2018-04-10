; Adapted from LZ4_8088.ASM by Jim Leonard
;
; Changes:
;  - SHR4table is in the data segment. The source of data
;    must therefore also be in the data segment.
;  - removed references to inb:outb buffers. It is up to the caller to setup those.
;  - nasm language changes
;    - local labels
;    - segment overrides
;    - hexadecimal notation
;
; lz4_decompress
;
; DS:SI		Source of data
; ES:DI		Destination buffer
; AX		Return decompressed size
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Surprise!  I don't know what assembler you are using (masm, tasm,
; nasm, jasm, a86, etc.) so you get to wrap either of these routines for your
; specific situation.  Be sure to read the TRASHES comment below.
;
; The speed-optimized routine is lz4_decompress and the size-optimized
; routine is lz4_decompress_small.

;COMMENT #
;function lz4_decompress(inb,outb:pointer):word
;
;Decompresses an LZ4 stream file with a compressed chunk 64K or less in size.
;Input:
;  DS:SI Location of source data.  DWORD magic header and DWORD chunk size
;        must be intact; it is best to load the entire LZ4 file into this
;        location before calling this code.
;
;Output:
;  ES:DI Decompressed data.  If using an entire 64K segment, decompression
;        is "safe" because overruns will wrap around the segment.
;  AX    Size of decompressed data.
;
;Trashes AX, BX, CX, DX, SI, DI
;        ...so preserve what you need before calling this code.
;#

section .data
@SHR4table:
%if 1
		%assign i 0
		%rep 16
		times 16 db i
		%assign i i+1
		%endrep
%endif

section .text

lz4_decompress:
        push    ds              ;preserve compiler assumptions
        push    bp              ;preserve compiler assumptions
        ;les     di,outb         ;load target buffer
        push    di              ;save original starting offset (in case != 0)
        ;lds     si,inb          ;load source buffer
        add     si,4            ;skip magic number
        cld                     ;make strings copy forward
        mov     bx,@SHR4table ;prepare BX for XLAT later on
        lodsw                   ;load chunk size low 16-bit word
        mov     bp,ax           ;BP = size of compressed chunk
        lodsw                   ;load chunk size high 16-bit word
        add     bp,si           ;BP = threshold to stop decompression
        or      ax,ax           ;is high word non-zero?
        jnz     .done           ;If so, chunk too big or malformed, abort

.starttoken:
        lodsb                   ;grab token to AL
        mov     dx,ax           ;preserve packed token in DX
  		xlat                    ;unpack upper 4 bits, faster than SHR reg,cl
        mov     cx,ax           ;CX = unpacked literal length token
        jcxz    .copymatches    ;if CX = 0, no literals; try matches
        cmp     al,0Fh          ;is it 15?
        jne     .doliteralcopy1 ;if so, build full length, else start copying
.build1stcount:                 ;this first count build is not the same
        lodsb                   ;fall-through jump as the one in the main loop
        add     cx,ax           ;because it is more likely that the very first
        cmp     al,0FFh          ;length is 15 or more
        je      .build1stcount
.doliteralcopy1:
        rep     movsb           ;src and dst might overlap so do this by bytes

;At this point, we might be done; all LZ4 data ends with five literals and the
;offset token is ignored.  If we're at the end of our compressed chunk, stop.

        cmp     si,bp           ;are we at the end of our compressed chunk?
        jae     .done           ;if so, jump to exit; otherwise, process match

.copymatches:
        lodsw                   ;AX = match offset
        xchg    dx,ax           ;AX = packed token, DX = match offset
        and     al,0Fh          ;unpack match length token
        cmp     al,0Fh          ;is it 15?
        xchg    cx,ax           ;(doesn't affect flags); don't need ax any more
        je      .buildmcount    ;if not, start copying, otherwise build count

.domatchcopy:
        cmp     dx,2            ;if match offset=1 or 2, we're repeating a value
        jbe     .domatchfill    ;if so, perform RLE expansion optimally
        push    ds
        xchg    si,ax           ;ds:si saved
        mov     si,di
        sub     si,dx
        mov     dx,es
        mov     ds,dx           ;ds:si points at match; es:di points at dest
        movsw
        movsw                   ;minimum match is 4 bytes; move them ourselves
        shr     cx,1
        rep     movsw           ;cx contains count-4 so copy the rest
        adc     cx,cx
        rep     movsb
        xchg    si,ax
        pop     ds              ;ds:si restored

.parsetoken:                    ;CX always 0 here because of REP
        xchg    cx,ax           ;zero ah here to benefit other reg loads
        lodsb                   ;grab token to AL
        mov     dx,ax           ;preserve packed token in DX
.copyliterals:                  ;next 5 lines are 8088-optimal, do not rearrange
  		xlat                    ;unpack upper 4 bits, faster than SHR reg,cl
        mov     cx,ax           ;CX = unpacked literal length token
        jcxz    .copymatches    ;if CX = 0, no literals; try matches
        cmp     al,0Fh          ;is it 15?
        je      .buildlcount    ;if so, build full length, else start copying
.doliteralcopy:                 ;src and dst might overlap so do this by bytes
        rep     movsb           ;if cx=0 nothing happens

;At this point, we might be done; all LZ4 data ends with five literals and the
;offset token is ignored.  If we're at the end of our compressed chunk, stop.

.testformore:
        cmp     si,bp           ;are we at the end of our compressed chunk?
        jb      .copymatches    ;if not, keep going
        jmp     .done           ;if so, end

.domatchfill:
        je      .domatchfill2   ;if DX=2, RLE by word, else by byte
.domatchfill1:
        es mov     al,[di-1]    ;load byte we are filling with
        mov     ah,al           ;copy to ah so we can do 16-bit fills
        stosw                   ;minimum match is 4 bytes, so we fill four
        stosw
        inc     cx              ;round up for the shift
        shr     cx,1            ;CX = remaining (count+1)/2
        rep     stosw           ;includes odd byte - ok because LZ4 never ends with matches
        adc     di,-1           ;Adjust dest unless original count was even
        jmp     .parsetoken     ;continue decompressing

.domatchfill2:
        es mov     ax,[di-2]    ;load word we are filling with
        stosw                   ;minimum match is 4 bytes, so we fill four
        stosw
        inc     cx              ;round up for the shift
        shr     cx,1            ;CX = remaining (count+1)/2
        rep     stosw           ;includes odd byte - ok because LZ4 never ends with matches
        adc     di,-1           ;Adjust dest unless original count was even
        jmp     .parsetoken     ;continue decompressing

.buildlcount:                   ;build full literal length count
        lodsb                   ;get next literal count byte
        add     cx,ax           ;increase count
        cmp     al,0FFh          ;more count bytes to read?
        je      .buildlcount
        jmp     .doliteralcopy

.buildmcount:                   ;build full match length count - AX is 0
        lodsb                   ;get next literal count byte
        add     cx,ax           ;increase count
        cmp     al,0FFh          ;more count bytes to read?
        je      .buildmcount
        jmp     .domatchcopy

.done:
        pop     ax              ;retrieve previous starting offset
        sub     di,ax           ;subtract prev offset from where we are now
        xchg    ax,di           ;AX = decompressed size
        pop     bp              ;restore compiler assumptions
        pop     ds              ;restore compiler assumptions
		ret
