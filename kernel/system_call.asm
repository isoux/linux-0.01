;
;  system_call.asm  contains the system-call low-level handling routines.
; This also contains the timer-interrupt handler, as some of the code is
; the same. The hd-interrupt is also here.
;
; NOTE: This code handles signal-recognition, which happens every time
; after a timer-interrupt and after each system call. Ordinary interrupts
; don't handle signal-recognition, as that would clutter them up totally
; unnecessarily.
;
; 18.jun.2019
; Code is rewritten from system_call.s (GAS) to system_call.asm 
; (NASM intel syntax) by ISOUX 
;
; Stack layout in 'ret_from_system_call':
;
;	[esp+0] - eax
;	[esp+4] - ebx
;	[esp+8] - ecx
;	[esp+0x0c] - edx
;	[esp+0x10] - fs
;	[esp+0x14] - es
;	[esp+0x18] - ds
;	[esp+0x1C] - eip
;	[esp+0x20] - cs
;	[esp+0x24] - eflags
;	[esp+0x28] - oldesp
;	[esp+0x2C] - oldss

USE32
CPU 486

KRN_CODE equ 0x08
KRN_DATA equ 0x10
USR_DATA equ 0x17

SIG_CHLD	equ 17
_EAX		equ 0x00
_EBX		equ 0x04
_ECX		equ 0x08
_EDX		equ 0x0C
_FS		equ 0x10
_ES		equ 0x14
_DS		equ 0x18
_EIP		equ 0x1C
_CS		equ 0x20
EFLAGS	equ 0x24
OLDESP	equ 0x28
OLDSS		equ 0x2C

state		equ 0		; these are offsets into the task-struct.
counter	equ 4
priority equ 8
signal	equ 12
restorer equ 16	; address of info-restorer
sig_fn	equ 20	; table of 32 signal addresses

nr_system_calls equ 319

global system_call, sys_fork, timer_interrupt, \
		 hd_interrupt, sys_execve

extern schedule, sys_call_table, sys_null, current, \
		 verify_area, jiffies, do_timer, do_execve, \
		 copy_process, do_hd, unexpected_hd_interrupt, \
		 find_empty_process, task, do_exit

align 2
bad_sys_call:
	mov eax, -1
	iret
	
align 2
reschedule:
	push ret_from_sys_call
	jmp schedule
	
align 2
system_call:
	cmp eax, nr_system_calls-1
	ja bad_sys_call
	push ds
	push es
	push fs
	push edx
	push ecx				; push ebx,ecx,edx as parameters
	push ebx				; to the system call
	mov edx, KRN_DATA ; set up ds,es to kernel space (0x10)
	mov ds,edx
	mov es,edx
	mov edx, USR_DATA	; fs points to local data space (0x17)
	mov fs, edx
	
	mov edx, [eax * 4 + sys_call_table]	; if sys_null
	cmp edx, sys_null		; then the syscall is not
	jne .1					; implemented.
	pop edx					; 1st argument is syscall nr
	push eax
	
.1: ; local label system_call = system_call.1
	call [eax * 4 + sys_call_table]
	push eax
	mov eax, [current]
	cmp DWORD [eax + state], 0		; state
	jne reschedule
	cmp DWORD [eax + counter], 0	; counter
	je reschedule
ret_from_sys_call:
	mov eax, [current]			; task[0] cannot have signals
	cmp eax, DWORD [task]
	je .2
	mov ebx,DWORD [esp + _CS]	; was old code segment supervisor
	test ebx, 0x03					; mode? If so - don't check signals
	je .2
	cmp WORD [esp + OLDSS], USR_DATA ; was stack segment = 0x17 ?
	jne .2
.1: 
	mov ebx, DWORD [eax + signal] ; signals (bitmap, 32 signals)
	bsf ecx, ebx		; cx is signal nr, return if none
	je .2
	btr ebx, ecx		; clear it
	mov DWORD [eax + signal], ebx
	mov ebx, DWORD [eax + ecx * 4 + sig_fn]	; ebx is signal handler address
	cmp ebx, 0x01
	jb default_signal		; 0 is default signal handler - exit
	je .1						; 1 is ignore - find next signal
	mov DWORD [eax + ecx * 4 + sig_fn], 0x0	; reset signal handler address
	inc ecx
	xchg DWORD [esp + _EIP], ebx
	sub DWORD [esp + OLDESP], 0x1c 	; 28
	mov edx, DWORD [esp + OLDESP]		; push old return address on stack
	push eax									; but first check that it's ok.
	push ecx
	push 0x1c	; 28
	push edx
	call verify_area
	pop edx
	add esp, 0x04
	pop ecx
	pop eax
	mov eax, [eax + restorer]
	mov [fs:edx], eax			; flag/reg restorer
   mov [fs:edx + 4], ecx   ; signal nr 
	mov eax, [esp + _EAX]
	mov [fs:edx + 8], eax	; old eax
	mov eax, [esp + _ECX]
   mov [fs:edx + 12], eax	; old ecx
	mov eax, [esp + _EDX]
	mov [fs:edx + 16], eax	; old edx
	mov eax, [esp + EFLAGS]
	mov [fs:edx + 20], eax	; old eflags
	mov [fs:edx + 24], ebx	; old return addr
.2:
	pop eax
	pop ebx
	pop ecx
	pop edx
	pop fs
	pop es
	pop ds
	iret
	
default_signal:
	inc	ecx
	cmp	ecx, SIG_CHLD
	je		ret_from_sys_call.1	; local label .1
	push	ecx
	call	do_exit					; remember to set bit 7 when dumping core
	add	esp,0x4
   jmp   ret_from_sys_call.2	; local label .2
   
align 2
timer_interrupt:
	push ds			; save ds,es and put kernel data space
	push es			; into them. fs is used by _system_call
	push fs
	push edx			; we save eax,ecx,edx as gcc doesn't
	push ecx			; save those across function calls. ebx
	push ebx			; is saved as we use that in ret_sys_call
	push eax
	mov eax, KRN_DATA ;(0x10)
	mov ds,eax
	mov es,eax
	mov eax, USR_DATA	;(0x17)
	mov fs, eax
	inc DWORD [ds: jiffies]
	mov al, 0x20				; EOI to interrupt controller #1
	out 0x20, al
	mov eax, [esp + _CS]
	and eax, 0x3				; eax is CPL (0 or 3, 0=supervisor)
	push eax
	call do_timer				; 'do_timer(long CPL)' does everything from
	add esp, 0x4				; task switching to accounting ...
	jmp ret_from_sys_call

align 2
sys_execve:
	lea eax,[esp + _EIP]
	push eax
	call do_execve
	add esp, 0x4
	ret
	
align 2
sys_fork:
	call find_empty_process
	test eax, eax
	js .1
	push gs
	push esi
	push edi
	push ebp
	push eax
	call copy_process
	add esp, 20
.1:	
	ret

hd_interrupt:
	push eax
	push ecx
	push edx
	push ds
	push es
	push fs
	mov eax, KRN_DATA ;(0x10)
	mov ds, eax
	mov es, eax
	mov eax, USR_DATA	;(0x17)
	mov fs, eax
	mov al, 0x20
	out 0x20,al			; EOI to interrupt controller #1
	jmp .1				; give port chance to breathe
.1:	
	jmp .2
.2:	
	out 0xA0, al		; same to controller #2
	mov eax, [do_hd]
	test eax,eax
	jne .3
	mov eax, unexpected_hd_interrupt
.3:	
	call eax				; "interesting" way of handling intr.
	pop fs
	pop es
	pop ds
	pop edx
	pop ecx
	pop eax
	iret	
		

