; page.asm contains the low-level page-exception code.
; he real work is done in mm.c
;
; 14.jun.2019
; Code is rewritten from page.s (GAS) to page.asm
; (NASM intel syntax) by ISOUX

USE32
CPU 486

global page_fault

extern do_no_page, do_wp_page

page_fault:
		xchg   [esp],eax
		push   ecx
		push   edx
		push   ds
		push   es
		push   fs
		mov    edx,0x10
		mov    ds,edx
		mov    es,edx
		mov    fs,edx
		mov    edx,cr2
		push   edx
		push   eax
		test   eax,0x1
		jne    .1
		call   do_no_page
		jmp    .2
.1:	call   do_wp_page
.2:	add    esp,0x8
		pop    fs
		pop    es
		pop    ds
		pop    edx
		pop    ecx
		pop    eax
		iret

