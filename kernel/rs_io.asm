;
;	rs_io.asm
;
; This module implements the rs232 io interrupts.
;
; 19.jun.2019
; Code is rewritten from rs_io.s (GAS) to rs_io.asm 
; (NASM intel syntax) by ISOUX 

USE32
CPU 486

global rs1_interrupt, rs2_interrupt

extern table_list, do_tty_interrupt

size	equ 1024		; must be power of two !
						; and must match the value
						; in tty_io.c!!! 

; these are the offsets into the read/write buffer structures 
rs_addr	equ 0
head 		equ 4
tail 		equ 8
proc_list	equ 12
buf	 	equ 16

startup	equ 256	; chars left in write queue when we restart it 

; These are the actual interrupt routines. They look where
; the interrupt is coming from, and take appropriate action.

align 2
rs1_interrupt:
	push table_list + 8
	jmp rs_int
align 2
rs2_interrupt:
	push table_list + 16
rs_int:	
	push edx
	push ecx
	push ebx
	push eax
	push es
	push ds			; as this is an interrupt, we cannot
	push 0x10		; know that bs is ok. Load it
	pop ds
	push 0x10
	pop es
	mov edx, [esp + 24]
	mov edx, [edx]
	mov edx, [edx + rs_addr]
	add edx, 2		; interrupt ident. reg
rep_int:
	xor eax,eax
	in al, dx
	test al, 1
	jne end
	cmp al, 6		; this shouldn't happen, but ...
	ja end
	mov ecx, [esp + 24]
	push edx
	sub edx, 2
	call DWORD [eax * 2 + jmp_table]	; NOTE! not *4, bit0 is 0 already 
	pop edx
	jmp rep_int
end:
	mov al, 0x20
	out 0x20, al		; EOI 
	pop ds
	pop es
	pop eax
	pop ebx
	pop ecx
	pop edx
	add esp, 4			; jump over _table_list entry
	iret

jmp_table:
	dd modem_status,write_char,read_char,line_status
	
align 2
modem_status:
	add edx, 6			; clear intr by reading modem status reg.
	in al, dx
	ret

align 2
line_status:
	add edx, 5		; clear intr by reading line status reg.
	in al, dx
	ret

align 2
read_char:
	in al, dx
	mov edx, ecx
	sub edx, table_list
	shr edx, 3
	mov ecx, [ecx]				; read-queue
	mov ebx, [ecx + head]
	mov  BYTE [ecx + ebx*1 + buf], al
	inc ebx
	and ebx, size - 1
	cmp ebx, [ecx + tail]
	je .1
	mov [ecx + head], ebx
	push edx
	call do_tty_interrupt
	add esp, 4
.1:	
	ret
	
align 2
write_char:
	mov  ecx, [ecx+0x4]		; write-queue
	mov  ebx, [ecx + head]
	sub  ebx, [ecx + tail]
	and ebx, size-1			; nr chars in queue
	je write_buffer_empty
	cmp ebx, startup
	ja .1
	mov ebx, [ecx + proc_list]	; wake up sleeping process
	test ebx, ebx					; is there any?
	je .1
	mov DWORD [ebx], 0
.1:	
	mov ebx, [ecx + tail]
	mov al, [ecx + ebx*1 + buf]
	out dx, al
	inc ebx
	and ebx, size-1
	mov [ecx + tail], ebx
	cmp ebx, [ecx + head]
	je write_buffer_empty
	ret
align 2
write_buffer_empty:
	mov ebx, [ecx + proc_list]	; wake up sleeping process
	test ebx,ebx					; is there any?
	je .1
	mov DWORD [ebx], 0
.1:	
	inc edx
	in al, dx
	jmp .2
.2:	
	jmp .3
.3:	
	and al, 0xd			; disable transmit interrupt
	out dx, al
	ret

