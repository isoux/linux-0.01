;
; head.asm contains the 32-bit startup code.
;
; NOTE!!! Startup happens at absolute address 0x00000000, which is also where
; the page directory will exist. The startup code will be overwritten by
; the page directory.
;
; 11.jun.2019
; Code is rewritten from head.s (GAS) to head.asm 
; (NASM intel syntax) by ISOUX

USE32
CPU 486
;_________________________________________________

; defines
KRN_BASE equ 0x0000
KRN_CODE equ 0x08
KRN_DATA equ 0x10

; global & extern linked variables
global startup_32, idt, gdt, pg_dir
extern main, stack_start
;_________________________________________________

pg_dir:
startup_32:
	mov eax,KRN_DATA
	mov ds,ax
	mov es,ax
	mov fs,ax
	mov gs,ax
	lss esp,[stack_start]
	call setup_idt
	call setup_gdt
	mov eax,KRN_DATA		;reload all the segment registers
	mov ds,ax				;after changing gdt. CS was already
	mov es,ax				;reloaded in 'setup_gdt'
	mov fs,ax
	mov gs,ax
	lss esp,[stack_start]
	xor eax,eax
.1:
	inc eax					;check that A20 really IS enabled
	mov [0],eax
	cmp [0x100000],eax
	jz .1

	mov eax,cr0				;check math chip
	and eax,0x80000011	;Save PG,ET,PE
	test eax,0x10
	jnz .2					;ET is set - 387 is present
	or eax,4					;else set emulate bit
.2:
	mov cr0,eax
	jmp after_page_tables
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;  setup_idt
;
;  sets up a idt with 256 entries pointing to
;  ignore_int, interrupt gates. It then loads
;  idt. Everything that wants to install itself
;  in the idt-table may do so themselves. Interrupts
;  are enabled elsewhere, when we can be relatively
;  sure everything is ok. This routine will be over-
;  written by the page tables.

setup_idt:
	lea edx,[ignore_int]
	mov eax,0x00080000
	mov ax,dx				;selector = 0x0008 = cs
	mov dx,0x8E00			;interrupt gate - dpl=0, present

	lea edi,[idt]
	mov ecx,256
rp_sidt:
	mov [edi],eax
	mov [edi+4],edx
	add edi,8
	dec ecx
	jne rp_sidt
	lidt [idt_descr]
	ret
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;  setup_gdt
;
;  This routines sets up a new gdt and loads it.
;  Only two entries are currently built, the same
;  ones that were built in init.s. The routine
;  is VERY complicated at two whole lines, so this
;  rather long comment is certainly needed :-).
;  This routine will beoverwritten by the page tables.

setup_gdt:
	lgdt [gdt_descr]
	ret
times 0x1000-$+$$ db 0
pg0:

times 0x1000 db 0
pg1:

times 0x1000 db 0
pg2:				;This is not used yet, but if you
					;want to expand past 8 Mb, you'll have
					;to use it.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

after_page_tables:
	push 0				;These are the parameters to main :-)
	push 0
	push 0
	push L6				;return address for main, if it decides to.
	push main
	jmp setup_paging
L6:
	jmp L6				;main should never return here, but
						;just in case, we know what happens.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; This is the default interrupt "handler"

align 2
ignore_int:
	inc byte[0xb8000+160]	;put something on the screen
	mov byte[0xb8000+161],2	;that we know something happened
	iret
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Setup_paging
;
; This routine sets up paging by setting the page bit
; in cr0. The page tables are set up, identity-mapping
; the first 8MB. The pager assumes that no illegal
; addresses are produced (ie >4Mb on a 4Mb machine).
;
; NOTE! Although all physical memory should be identity
; mapped by this routine, only the kernel page functions
; use the >1Mb addresses directly. All "normal" functions
; use just the lower 1Mb, or the local data space, which
; will be mapped to some other place - mm keeps track of
; that.
;
; For those with more memory than 8 Mb - tough luck. I've
; not got it, why should you :-) The source is here. Change
; it. (Seriously - it shouldn't be too difficult. Mostly
; change some constants etc. I left it at 8Mb, as my machine
; even cannot be extended past that (ok, but it was cheap :-)
; I've tried to show which constants to change by having
; some kind of marker at them (search for "8Mb"), but I
; won't guarantee that's all :-( )

align 2
setup_paging:
	mov ecx,1024*3
	xor eax,eax
	xor edi,edi					;pg_dir is at 0x000
	cld
	rep stosd
	mov dword[pg_dir],pg0+7		;set present bit/user r/w 
	mov dword[pg_dir+4],pg1+7	;--------- " " ---------
	mov edi,pg1+4092
	mov eax,0x7ff007			;8Mb - 4096 + 7 (r/w user,p)
	std
j1: stosd						;fill pages backwards - more efficient :-
	sub eax,0x1000
	jnl j1
	xor eax,eax					;pg_dir is at 0x0000
	mov cr3,eax					;cr3 - page directory start
	mov eax,cr0
	or eax,0x80000000
	mov cr0,eax					;set paging (PG) bit
	ret							;this also flushes prefetch-queue
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

align 2
dw 0

idt_descr:
	dw 256*8-1					;idt contains 256 entries
	dd idt
	
align 2
dw 0

gdt_descr:
	dw 256*8-1					;so does gdt (not that that's any
	dd gdt						;magic number, but it works for me :^)

align 8
idt:	times 256*8 db 0		; idt is uninitialized

gdt:	dq 0x0000000000000000	; NULL descriptor */
		dq 0x00c09a00000007ff	; 8Mb KRN_CODE
		dq 0x00c09200000007ff	; 8Mb KRN_DATA
		dq 0x0000000000000000	; TEMPORARY - don't use
		times 252*8 db 0			; space for LDT's and TSS's etc 

