;
; keyboard.asm
;
; 19.jun.2019
; Code is rewritten from keyboard.s (GAS) to keyboard.asm 
; (NASM intel syntax) by ISOUX 

USE32
CPU 486

global keyboard_interrupt

extern do_tty_interrupt, table_list

KRN_DATA equ 0x10

; these are for the keyboard read functions
size	equ 1024	; must be a power of two ! And MUST be the same
					; as in tty_io.c !!!! 
head equ 4
tail equ 8
proc_list equ 12
buf equ 16

mode: db 0		; caps, alt, ctrl and shift mode
leds:	db 0		; num-lock, caps, scroll-lock mode (num-lock on)
e0:	db 0

keyboard_interrupt:
	push eax
	push ebx
	push ecx
	push edx
	push ds
	push es
	mov eax,KRN_DATA
	mov ds,ax
	mov es,ax
	xor al,al		; eax is scan code
	in al,0x60
	cmp al, 0xe0
	je set_e0
	cmp al, 0xe1
	je set_e1
	call [key_table + eax * 4]
	mov byte[e0],0
e0_e1:
	in al,0x61
	jmp .1
.1:
	jmp .2
.2:
	or al,0x80
	jmp .3
.3:
	jmp .4
.4:
	out 0x61,al
	jmp .5
.5:
	jmp .6
.6:
	and al,0x7f
	out 0x61,al
	mov al,0x20
	out 0x20,al
	push 0x0
	call do_tty_interrupt
	add esp,0x04
	pop es
	pop ds
	pop edx
	pop ecx
	pop ebx
	pop eax
	iret
set_e0:
	mov byte[e0],1
	jmp short e0_e1
set_e1:
	mov byte[e0],2
	jmp short e0_e1
	
; This routine fills the buffer with max 8 bytes, taken from
; ebx:eax. (edx is high). The bytes are written in the
; order al,ah,axl,axh,bl,bh ... until eax is zero.
;~~~~~~~~~~~~~~~~~~~~~~~~~
put_queue:
	push ecx
	push edx
	mov edx,[table_list]		; read-queue for console
	mov ecx,[edx + head]
.1:	
	mov byte[edx + ecx*1 + buf], al
	inc ecx
	and ecx, size-1
	cmp ecx, [edx + tail]	; buffer full - discard everything
	je .3
	shrd eax,ebx,0x8
	je .2
	shr ebx,8
	jmp .1
.2:	
	mov [edx + head], ecx
	mov ecx,[edx + proc_list]
	test ecx,ecx
	je .3
	mov dword[ecx],0
.3:	
	pop edx
	pop ecx
	ret
;~~~~~~~~~~~~~~~~~~~~~~~~~	
ctrl:
	mov al,0x04
	jmp alt.1
alt:
	mov al,0x10
.1:
	cmp byte[e0],0
	je .2
	add al,al
.2:
	or byte[mode],al
	ret
unctrl:
	mov al,0x04
	jmp unalt.1
unalt:
	mov al,0x10
.1:
	cmp byte[e0],0
	je .2
	add al,al
.2:
	not al
	and byte[mode],al
	ret
;~~~~~~~~~~~~~~~~~~~~~~~~~	
lshift:
	or byte[mode],0x01
	ret
unlshift:
	and byte[mode],0xfe
	ret
rshift:
	or byte[mode],0x02
	ret
unrshift:
	and byte[mode],0xfd
	ret	
;~~~~~~~~~~~~~~~~~~~~~~~~
caps:
	test byte[mode],0x80
	jne cur2.1				; at cur2.2 local label
	xor byte[leds],0x04
	xor byte[mode],0x40
	or byte[mode],0x80
set_leds:
	call kb_wait
	mov al,0xed		;set led command
	out 0x60,al
	call kb_wait
	mov al,[leds]
	out 0x60,al
	ret
uncaps:
	and byte[mode],0x7f
	ret
scroll:
	xor byte[leds],0x01
	jmp short set_leds
num:
	xor byte[leds],0x02
	jmp short set_leds
;~~~~~~~~~~~~~~~~~~~~~~~~~
cursor:
	sub al,0x47
	jb cur2.1
	cmp	al, 12
	ja cur2.1
	jne cur2						; check for ctrl-alt-del
	test byte[mode], 0xc
	je cur
	test byte[mode], 0x30
	jne reboot 
cur2:
	cmp byte[e0], 0x1			; e0 forces cursor movement
	je cur
	test byte[leds], 0x2		; not num-lock forces cursor
	je cur
	test byte[mode], 0x3		; shift forces cursor
	jne cur
	xor ebx, ebx
	mov    al, byte[eax + num_table]
	jmp put_queue
.1:
	ret  
;~~~~~~~~~~~~~~~~~~~~~~~~~	  
cur:	
	mov al, byte[eax + cur_table]
	cmp al, '9'
	ja ok_cur
	mov ah, '~'
ok_cur:
	shl eax, 16
	mov ax,0x5b1b
	xor ebx,ebx
	jmp put_queue
;~~~~~~~~~~~~~~~~~~~~~~~~~	  	
num_table:
	db "789 456 1230,"
cur_table:
	db "HA5 DGC YB623"
;~~~~~~~~~~~~~~~~~~~~~~~~~	  
; this routine handles function keys
func:
	sub al,0x3b
	jb end_func
	cmp al,0x09
	jbe ok_func
	sub al,18
	cmp al,10
	jb end_func
	cmp al,11
	ja end_func
ok_func:
	cmp ecx,4		; check that there is enough room
	jl end_func
	mov eax,[eax * 4 + func_table]
	xor ebx,ebx
	jmp put_queue
end_func:
	ret
;~~~~~~~~~~~~~~~~~~~~~~~~~	  	
; function keys send F1:'esc [ [ A' F2:'esc [ [ B' etc.
func_table:
	dd 0x415b5b1b,0x425b5b1b,0x435b5b1b,0x445b5b1b
	dd 0x455b5b1b,0x465b5b1b,0x475b5b1b,0x485b5b1b
	dd 0x495b5b1b,0x4a5b5b1b,0x4b5b5b1b,0x4c5b5b1b
	
key_map:
	db 0,27
	db "1234567890-="	; db "1234567890+'" 
	db 127,9
	db "qwertyuiop[]"	; db "qwertyuiop}" 
	db 10,0 				; db 0,10,0 
	db "asdfghjkl;'`"	; db "asdfghjkl|{" 
	db 0					; db 0,0 
	db "\zxcvbnm,./"
	db 0,'*',0,32		; 36-39 
	times 16 db 0		; 3A-49 
	db '-',0,0,0,'+'	; 4A-4E 
	db 0,0,0,0,0,0,0	; 4F-55 
	db '<'
	times 10 db 0
	
	shift_map:
	db 0,27
	db "!@#$%^&*()_+"	; db "!\"#$%&/()=?`" 
	db 127,9
	db "QWERTYUIOP{}"	; db "QWERTYUIOP]^" 
	db 10,0
	db "ASDFGHJKL:", '"', "~"	; db "ASDFGHJKL\\[" 
	db 0					; db 0,0 * 
	db "|ZXCVBNM<>?_" 	; db "*ZXCVBNM;:_" 
	db 0,'*',0,32		; 36-39 
	times 16 db 0		; 3A-49 
	db '-',0,0,0,'+'	; 4A-4E 
	db 0,0,0,0,0,0,0	; 4F-55 
	db '>'
	times 10 db 0
	
alt_map:
	db 0,0
	db "\0@\0$\0\0{[]}\\\0"
	db 0,0
	db 0,0,0,0,0,0,0,0,0,0,0
	db '~',10,0
	db 0,0,0,0,0,0,0,0,0,0,0
	db 0,0
	db 0,0,0,0,0,0,0,0,0,0,0
	db 0,0,0,0		; 36-39 
	times 16 db 0		; 3A-49 
	db 0,0,0,0,0		; 4A-4E 
	db 0,0,0,0,0,0,0	; 4F-55 
	db '|'
	times 10 db 0
	
;~~~~~~~~~~~~~~~~~~~~~~~~~	
; do_self handles "normal" keys, ie keys that don't change meaning
; and which have just one character returns.

do_self:
	lea ebx,[alt_map]
	test byte[mode], 0x20		; alt-gr
	jne .1
	lea ebx,[shift_map]
	test byte[mode], 0x03
	jne .1
	lea ebx,[key_map]
.1:
	mov al,[ebx + eax*1]
	or al,al
	je none
	test byte[mode],0x4c			; ctrl or caps
	je .2
	cmp al,'a'
	jb .2
	cmp al,'z'
	ja .2
	sub al,32
.2:
	test byte[mode],0x0c				; ctrl
	je .3
	cmp al,64
	jb .3
	cmp al,64+32
	jae .3
	sub al,64
.3:
	test byte[mode],0x10				; left alt
	je .4
	or al,0x80
.4:
	and eax,0xff
	xor ebx,ebx	
	call put_queue
none:	
	ret
;~~~~~~~~~~~~~~~~~~~~~~~~~	
; minus has a routine of it's own, as a 'E0h' before
; the scan code for minus means that the numeric keypad
; slash was pushed.

minus:	
	cmp byte[e0], 0x1
	jne do_self
	mov eax, '/'
	xor ebx,ebx
	jmp put_queue
;~~~~~~~~~~~~~~~~~~~~~~~~~	
; This table decides which routine to call when a scan-code has been
; gotten. Most routines just call do_self, or none, depending if
; they are make or break.

key_table:
	dd none,do_self,do_self,do_self	; 00-03 s0 esc 1 2 
	dd do_self,do_self,do_self,do_self	; 04-07 3 4 5 6 
	dd do_self,do_self,do_self,do_self	; 08-0B 7 8 9 0 
	dd do_self,do_self,do_self,do_self	; 0C-0F + ' bs tab 
	dd do_self,do_self,do_self,do_self	; 10-13 q w e r 
	dd do_self,do_self,do_self,do_self	; 14-17 t y u i 
	dd do_self,do_self,do_self,do_self	; 18-1B o p } ^ 
	dd do_self,ctrl,do_self,do_self	; 1C-1F enter ctrl a s 
	dd do_self,do_self,do_self,do_self	; 20-23 d f g h 
	dd do_self,do_self,do_self,do_self	; 24-27 j k l | 
	dd do_self,do_self,lshift,do_self	; 28-2B { para lshift , 
	dd do_self,do_self,do_self,do_self	; 2C-2F z x c v 
	dd do_self,do_self,do_self,do_self	; 30-33 b n m , 
	dd do_self,minus,rshift,do_self	; 34-37 . - rshift * 
	dd alt,do_self,caps,func		; 38-3B alt sp caps f1 
	dd func,func,func,func		; 3C-3F f2 f3 f4 f5 
	dd func,func,func,func		; 40-43 f6 f7 f8 f9 
	dd func,num,scroll,cursor		; 44-47 f10 num scr home 
	dd cursor,cursor,do_self,cursor	; 48-4B up pgup - left 
	dd cursor,cursor,do_self,cursor	; 4C-4F n5 right + end 
	dd cursor,cursor,cursor,cursor	; 50-53 dn pgdn ins del 
	dd none,none,do_self,func		; 54-57 sysreq ? < f11 
	dd func,none,none,none		; 58-5B f12 ? ? ? 
	dd none,none,none,none		; 5C-5F ? ? ? ? 
	dd none,none,none,none		; 60-63 ? ? ? ? 
	dd none,none,none,none		; 64-67 ? ? ? ? 
	dd none,none,none,none		; 68-6B ? ? ? ? 
	dd none,none,none,none		; 6C-6F ? ? ? ? 
	dd none,none,none,none		; 70-73 ? ? ? ? 
	dd none,none,none,none		; 74-77 ? ? ? ? 
	dd none,none,none,none		; 78-7B ? ? ? ? 
	dd none,none,none,none		; 7C-7F ? ? ? ? 
	dd none,none,none,none		; 80-83 ? br br br 
	dd none,none,none,none		; 84-87 br br br br 
	dd none,none,none,none		; 88-8B br br br br 
	dd none,none,none,none		; 8C-8F br br br br 
	dd none,none,none,none		; 90-93 br br br br 
	dd none,none,none,none		; 94-97 br br br br 
	dd none,none,none,none		; 98-9B br br br br 
	dd none,unctrl,none,none		; 9C-9F br unctrl br br 
	dd none,none,none,none		; A0-A3 br br br br 
	dd none,none,none,none		; A4-A7 br br br br 
	dd none,none,unlshift,none		; A8-AB br br unlshift br 
	dd none,none,none,none		; AC-AF br br br br 
	dd none,none,none,none		; B0-B3 br br br br 
	dd none,none,unrshift,none		; B4-B7 br br unrshift br 
	dd unalt,none,uncaps,none		; B8-BB unalt br uncaps br 
	dd none,none,none,none		; BC-BF br br br br 
	dd none,none,none,none		; C0-C3 br br br br 
	dd none,none,none,none		; C4-C7 br br br br 
	dd none,none,none,none		; C8-CB br br br br 
	dd none,none,none,none		; CC-CF br br br br 
	dd none,none,none,none		; D0-D3 br br br br 
	dd none,none,none,none		; D4-D7 br br br br 
	dd none,none,none,none		; D8-DB br ? ? ? 
	dd none,none,none,none		; DC-DF ? ? ? ? 
	dd none,none,none,none		; E0-E3 e0 e1 ? ? 
	dd none,none,none,none		; E4-E7 ? ? ? ? 
	dd none,none,none,none		; E8-EB ? ? ? ? 
	dd none,none,none,none		; EC-EF ? ? ? ? 
	dd none,none,none,none		; F0-F3 ? ? ? ? 
	dd none,none,none,none		; F4-F7 ? ? ? ? 
	dd none,none,none,none		; F8-FB ? ? ? ? 
	dd none,none,none,none		; FC-FF ? ? ? ? 
;~~~~~~~~~~~~~~~~~~~~~~~~~	
; kb_wait waits for the keyboard controller buffer to empty.
; there is no timeout - if the buffer doesn't empty, we hang.

kb_wait:
	push eax
.1:	
	in al,0x64
	test al,0x02
	jne .1
	pop eax
	ret
;~~~~~~~~~~~~~~~~~~~~~~~~~
; This routine reboots the machine by asking the keyboard
; controller to pulse the reset-line low.
reboot:
	call kb_wait
	mov word[0x472],0x1234	; don't do memory check 
	mov al,0xfc					; pulse reset and A20 low 
	out 0x64,al
die:	
	jmp die

