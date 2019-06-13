;
;	boot.asm
;
; boot.asm is loaded at 0x7c00 by the bios-startup routines, and moves itself
; out of the way to address 0x90000, and jumps there.
;
; It then loads the system at 0x10000, using BIOS interrupts. Thereafter
; it disables all interrupts, moves the system down to 0x0000, changes
; to protected mode, and calls the start of system. System then must
; RE-initialize the protected mode in it's own tables, and enable
; interrupts as needed.
;
; NOTE! currently system is at most 8*65536 bytes long. This should be no
; problem, even in the future. I want to keep it simple. This 512 kB
; kernel size should be enough - in fact more would mean we'd have to move
; not just these start-up routines, but also do something about the cache-
; memory (block IO devices). The area left over in the lower 640 kB is meant
; for these. No other memory is assumed to be "physical", ie all memory
; over 1Mb is demand-paging. All addresses under 1Mb are guaranteed to match
; their physical addresses.
;
; NOTE1 abouve is no longer valid in it's entirety. cache-memory is allocated
; above the 1Mb mark as well as below. Otherwise it is mainly correct.
;
; NOTE 2! The boot disk type must be set at compile-time, by setting
; the following equ. Having the boot-up procedure hunt for the right
; disk type is severe brain-damage.
; The loader has been made as simple as possible (had to, to get it
; in 512 bytes with the code to move to protected mode), and continuos
; read errors will result in a unbreakable loop. Reboot by hand. It
; loads pretty fast by getting whole sectors at a time whenever possible.
;
; 8.jun.2019
; Code is rewritten from boot.s (AS86) to boot.asm (NASM intel syntax) by ISOUX

USE16

org	0						; later we are adjust regs.

%include "boot.inc"		; contains the value of SYS_SIZE

SECTORS	equ	18			; 1.44Mb disks:
BOOT_SEG	equ 	0x07C0	; boot code at -> 0000:7C00
INIT_SEG	equ	0x9000	; init seg to -> 0x90000
SYS_SEG	equ	0x1000	; system loaded at -> 0x10000 (65536).
STACK_PTR equ	0x0400	; stack size of 512 bytes (over 512).
END_SEG	equ	SYS_SEG + (SYS_SIZE+15)/16

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; BOOT CODE
main:
;----------------------------------------------------
; boot load starts at 07C0:0000 or 0000:7C00, then
; prepare segment registers for itself moving of 
; boot code to INIT_SEG and jumps there.
;^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

	mov ax,BOOT_SEG	; setup ds register to BOOT_SEG
	mov ds,ax
	mov [bootdev],dl	;save stage of boot device
	mov ax,INIT_SEG	; setup es register to INIT_SEG
	mov es,ax
	mov cx,128			;copy 128*4 bytes = 512 Bytes
	xor si,si
	xor di,di
	rep movsd			;faster way to copy 0x80 dwords
	jmp INIT_SEG:init_entry
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; INIT CODE
init_entry:
;----------------------------------------------------
; adjust segment registers
	mov ax,cs
	mov ds,ax
	mov es,ax
	mov gs,ax
	mov fs,ax
;----------------------------------------------------
; ... & create stack in init segment
	mov ss,ax			; STACK_SEG		
	mov sp,STACK_PTR	; set the stack
;----------------------------------------------------
; print the load mesage 
	mov si, msg_load
	call Print
;----------------------------------------------------
; preparing for loadin system at -> 0x10000 (65536)
; then call load_image

	mov ax,SYS_SEG
	mov es,ax
	call load_image	;load image file into memory (0x1000:0000)
	call kill_motor 
	call save_cur_pos
	
; now we want to move to protected mode ...
   cli					; no interrupts allowed !
	call remov_right 

	lidt [idt_48]
	lgdt [gdt_48]
	
	; now we enable A20
	in al, 0x92
	or al, 2
	out 0x92, al

	mov	al,0x11		; initialization sequence
	out	0x20,al		; send it to 8259A-1
	;dw	0x00eb,0x00eb		; jmp $+2, jmp $+2
	out	0xA0,al		; and to 8259A-2
	;dw	0x00eb,0x00eb
	mov	al,0x20		; start of hardware int's (0x20)
	out	0x21,al
	;dw	0x00eb,0x00eb
	mov	al,0x28		; start of hardware int's 2 (0x28)
	out	0xA1,al
	;dw	0x00eb,0x00eb
	mov	al,0x04		; 8259-1 is master
	out	0x21,al
	;dw	0x00eb,0x00eb
	mov	al,0x02		; 8259-2 is slave
	out	0xA1,al
	;dw	0x00eb,0x00eb
	mov	al,0x01		; 8086 mode for both
	out	0x21,al
	;dw	0x00eb,0x00eb
	out	0xA1,al
	;dw	0x00eb,0x00eb
	mov	al,0xFF		; mask off all interrupts for now
	out	0x21,al
	;dw	0x00eb,0x00eb
	out	0xA1,al

	mov	ax,0x0001	; protected mode (PE) bit
	lmsw	ax				; This is it!

	jmp 8:0				; jmp offset 0 of segment 8 (cs)
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; PROCEDURES & FUNCTIONS

Error:
	mov     si,msg_fail
	call    Print
	mov     ah,0x00
	int     0x16		; await keypress
	ret
;****************************************************
;	Prints a string
;	DS=>SI: 0 terminated string

Print:			; Output string in SI to screen
	pusha
	mov ah,0x0E	; int 0x10 teletype function
.repeat:
	lodsb			; Get char from string
	cmp al, 0
	je .done		; If char is zero, end of string
	int 0x10		; Otherwise, print it
	jmp short .repeat
.done:
	popa
	ret
;****************************************************
;	load_image

load_image:
	mov ax,es
	test ax,0x0fff
die:
	jne die
	xor bx,bx
rp_read:
	mov ax,es
	cmp ax,END_SEG
	jb ok1_read
	ret
ok1_read:
	mov ax,SECTORS
	sub ax,[sread]
	mov cx,ax
	shl cx,9
	add cx,bx
	jnc ok2_read
	je ok2_read
	xor ax,ax
	sub ax,bx
	shr ax,9
ok2_read:
	call read_track
	mov cx,ax
	add ax,[sread]
	cmp ax,SECTORS
	jne ok3_read
	mov ax,1
	sub ax,[head]
	jne ok4_read
	inc word[track]
ok4_read:
	mov [head],ax
	xor ax,ax
ok3_read:
	mov [sread],ax
	shl cx,9
	add bx,cx
	jnc rp_read
	mov ax,es
	add ax,0x1000
	mov es,ax
	xor bx,bx
	jmp rp_read
;****************************************************
; Reads a series of sectors
; CX=>Number of sectors to read
; AX=>Starting sector
; ES:BX=>Buffer to read to

read_track:
	push ax
	push bx
	push cx
	push dx
	mov dx,[track]
	mov cx,[sread]
	inc cx
	mov ch,dl
	mov dx,[head]
	mov dh,dl
	mov dl,[bootdev]
	and dx,0x1ff
	mov ah,2
	int 0x13
	jc bad_rt
	pop dx
	pop cx
	pop bx
	pop ax
	ret
bad_rt:	mov ax,0
	mov dx,0
	int 0x13
	pop dx
	pop cx
	pop bx
	pop ax
	jmp short read_track
;****************************************************
;	kill_motor

kill_motor:
	push dx
	mov dx,0x3f2
	mov al,0
	out dx,al
	pop dx
	ret
;****************************************************
;	remov_right

remov_right:
	mov ax,0x0000
	cld				; 'direction'=0, movs moves forward
do_move:
	mov es,ax		; destination segment
	add ax,SYS_SEG
	cmp ax,INIT_SEG
	jz	end_move
	mov ds,ax		; source segment
	sub di,di
	sub si,si
	mov cx,0x8000
	rep
	movsw
	jmp short do_move
end_move:
	mov ax,cs		; right, forgot this at first. didn't work :-)
	mov ds,ax
	ret
;****************************************************
;	save_cur_pos = save curent cursor positon

save_cur_pos:
	mov	ah,3		; read cursor pos
	xor	bh,bh
	int	0x10		; save it in known place, con_init fetches
	mov	[510],dx	; it from 0x90510.
	ret
	
;****************************************************
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; DATA VARIABLES & CONSTATNTS

sread:	dw 0x01
head:		dw 0x00
track:	dw 0x00
bootdev:	db 0

gdt:
	dw	0,0,0,0		; dummy

	dw	0x07FF		; 8Mb - limit=2047 (2048*4096=8Mb)
	dw	0x0000		; base address=0
	dw	0x9A00		; code read/exec
	dw	0x00C0		; granularity=4096, 386

	dw	0x07FF		; 8Mb - limit=2047 (2048*4096=8Mb)
	dw	0x0000		; base address=0
	dw	0x9200		; data read/write
	dw	0x00C0		; granularity=4096, 386

idt_48:
	dw	0				; idt limit=0
	dw	0,0			; idt base=0L

gdt_48:
	dw	0x800			; gdt limit=2048, 256 GDT entries
	dw	gdt,0x9		; gdt base = 0X9xxxx

msg_load:	db "Loading system ...", 13,10,0
msg_fail:	db "Press a Key to Next",13,10,0
;****************************************************  
times 510-($-$$) DB 0
sign: dw 0xAA55
;****************************************************
