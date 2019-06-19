;
; asm.asm contains the low-level code for most hardware faults.
; page_exception is handled by the mm, so that isn't here. This
; file also handles (hopefully) fpu-exceptions due to TS-bit, as
; the fpu must be properly saved/resored. This hasn't been tested.
;
; 19.jun.2019
; Code is rewritten from asm.s (GAS) to asm.asm 
; (NASM intel syntax) by ISOUX 

USE32
CPU 486

global divide_error, debug, int3, overflow, bounds, invalid_op, \
		 device_not_available, coprocessor_segment_overrun, nmi, \
		 invalid_TSS, reserved, stack_segment, double_fault, \
		 general_protection, coprocessor_error, segment_not_present
		 
extern do_divide_error, do_int3, do_nmi, do_overflow, do_bounds, \
		 do_invalid_op, do_device_not_available, last_task_used_math, \
		 math_state_restore, current, do_coprocessor_segment_overrun, \
		 do_reserved, do_coprocessor_error, do_double_fault, \
		 do_invalid_TSS, do_segment_not_present, do_stack_segment, \
		 do_general_protection

KRN_DATA equ 0x10 

divide_error:
	push do_divide_error
no_error_code:
	xchg dword[esp], eax
	push ebx
	push ecx
	push edx
	push edi
	push esi
	push ebp
	push ds
	push es
	push fs
	push 0x0					; "error code"
	lea edx, [esp + 44]
	push edx
	mov edx, KRN_DATA		; 0x10
	mov ds, edx
	mov es, edx
	mov fs, edx
	call eax
	add esp, 0x8
	pop fs
	pop es
	pop ds
	pop ebp
	pop esi
	pop edi
	pop edx
	pop ecx
	pop ebx
	pop eax
	iret
	
debug:
	push do_int3		; _do_debug
	jmp no_error_code

nmi:
	push do_nmi
	jmp no_error_code

int3:
	push do_int3
	jmp no_error_code

overflow:
	push do_overflow
	jmp no_error_code

bounds:
	push do_bounds
	jmp no_error_code

invalid_op:
	push do_invalid_op
	jmp no_error_code
	
math_emulate:
	pop eax
	push do_device_not_available
	jmp no_error_code
device_not_available:
	push eax
	mov eax, cr0
	bt  eax, 0x2			; EM (math emulation bit)
	jc math_emulate
	clts						; clear TS so that we can use math
	mov eax, [current]
	cmp eax, dword[last_task_used_math]
	je .1						; shouldn't happen really ...
	push ecx
	push edx
	push ds
	mov eax, KRN_DATA  ; 0x10
	mov  ds,eax
	call math_state_restore
	pop ds
	pop edx
	pop ecx
.1:
	pop eax
	iret 
	
coprocessor_segment_overrun:
	push do_coprocessor_segment_overrun
	jmp no_error_code

reserved:
	push do_reserved
	jmp no_error_code

coprocessor_error:
	push do_coprocessor_error
	jmp no_error_code

double_fault:
	push do_double_fault
error_code:
	xchg dword[esp + 0x4], eax		; error code <-> eax
	xchg dword[esp], ebx				; &function <-> ebx
	push   ecx
	push   edx
	push   edi
	push   esi
	push   ebp
	push   ds
	push   es
	push   fs
	push   eax							; error code
	lea    eax,[esp + 44]			; offset
	push   eax
	mov    eax, KRN_DATA  			; 0x10
	mov    ds,eax
	mov    es,eax
	mov    fs,eax
	call   ebx
	add    esp,0x8
	pop    fs
	pop    es
	pop    ds
	pop    ebp
	pop    esi
	pop    edi
	pop    edx
	pop    ecx
	pop    ebx
	pop    eax
	iret	
	
invalid_TSS:
	push do_invalid_TSS
	jmp error_code

segment_not_present:
	push do_segment_not_present
	jmp error_code

stack_segment:
	push do_stack_segment
	jmp error_code

general_protection:
	push do_general_protection
	jmp error_code
