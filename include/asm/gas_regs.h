/*
 * 20.jun.2019
 * gas_regs.h is added by ISOUX
 *
 * 'gas_regs.h' defines basic registers so that they can be assigned
 *  by values to avoid direct use of 'heavy' GAS syntax.
 *
 * NOTE! Values are automatically assigned to the registry by type of
 * (value): for example, if the type of value is (char) then the
 * expresion _eax(c); = mov al,c but _eax((long) c) = mov eax,c.
 *
 * Here the mixed Intel & Gas syntax, is posible at same time by using
 * the LLVM's Clang compiler.
 */

#ifndef _GAS_REGS
#define _GAS_REGS

/* 
 * Macros for seting registers with value. 
 * The minimum inevitable GAS syntax is used here
 */
#define _esi(value) __asm__ (""::"S" (value))
#define _edi(value) __asm__ (""::"D" (value))
#define _ecx(value) __asm__ (""::"c" (value))
#define _eax(value) __asm__ (""::"a" (value))
#define _ebx(value) __asm__ (""::"b" (value))
#define _edx(value) __asm__ (""::"d" (value))

/* Intel syntax */
#define _cli() __asm__ {cli}
#define _sti() __asm__ {sti}

/* The following terms are inevitable to be automatic
  * assigned values to the register and are given
  * decides whether there is a return or a forward or not.
  */
#define _return(value) __asm__ volatile ("":"=a" (value):)
#define _forward(value) __asm__ volatile (""::"a" (value))

/* jmp next line (2 times) */
#define _jmp_x2 __asm__ volatile ("jmp 1f\n" "1: jmp 2f\n" "2: ") 



/* For now here folows a chaged <asm/io.h> file with introducing
 * the new policy of using mixed assembler syntax, with goal
 * to be more understanding & readable, I hope :-)
 */
#define inb(port) ({		\
unsigned  char _v;		\
	_edx((short)port);	\
	__asm__ {in al, dx}	\
	_return(_v);			\
	_v;						\
})

#define inb_p(port) ({	\
unsigned char _v;			\
	_edx((short)port);	\
	__asm__ {in al, dx}	\
	_jmp_x2;					\
	_return(_v);			\
	_v;						\
})

#define outb(value,port) ({	\
   _eax(value);					\
   _edx((short)port);			\
   __asm__ {out dx, al}			\
  _forward(value);				\
})

#define outb_p(value,port) ({	\
   _eax(value);					\
   _edx((short)port);			\
   __asm__ {out dx, al}			\
   _jmp_x2;							\
	_forward(value);				\
})

#endif

