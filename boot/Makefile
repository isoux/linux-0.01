# Makefile for boot 
# 2019.06.12 by ISOUX 
AS	= nasm
AS_BIN_FLAGS = -f bin
AS_ELF_FLAGS = -f elf32


boot: boot.asm
	$(AS) $(AS_BIN_FLAGS) -o boot $<
	
	
head.o: head.asm
	$(AS) $(AS_ELF_FLAGS) -o $*.o $< 
	
clean:
	rm -f boot.inc
	
boot: boot.inc
