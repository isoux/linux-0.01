#
# Makefile for linux.
# If you don't have '-mstring-insns' in your gcc (and nobody but me has :-)
# remove them from the CFLAGS defines.
#

#AS	=as --32 
LD	=ld -m  elf_i386 
LDFLAGS	=-M -Ttext 0 -e startup_32
#LDFLAGS	=-s -x -M -Ttext 0 -e startup_32
CC	=gcc
CLANG=clang
CFLAGS	=-Wall -O -std=gnu89 -fstrength-reduce -fomit-frame-pointer \
		-fno-stack-protector -fno-builtin -g -m32
CPP	=gcc -E -nostdinc -Iinclude

CLANG_FLAGS = -Wall -O -std=gnu89  -fomit-frame-pointer -m32 -finline-functions \
		-fno-stack-protector -nostdinc -g -I../include -fasm-blocks \
		-masm=intel  -fasm

ARCHIVES=kernel/kernel.o mm/mm.o fs/fs.o
LIBS	=lib/lib.a

.SUFFIXES: .asm .llo

.c.s:
	$(CC) $(CFLAGS) \
	-nostdinc -Iinclude -S -o $*.s $<
.s.o:
	$(AS) --32 -o $*.o $<
.c.o:
	$(CC) $(CFLAGS) \
	-nostdinc -Iinclude -c -o $*.o $<
.c.llo:
	$(CLANG) $(CLANG_FLAGS) \
	-c -o $*.llo $<

all:	Image

Image: boot/boot tools/system 
	cat boot/boot > Image
	cat tools/system.bin >> Image
	
tools/system:	boot/head.o init/main.o \
		$(ARCHIVES) $(LIBS)
	$(LD) $(LDFLAGS) boot/head.o init/main.o \
	$(ARCHIVES) \
	$(LIBS) \
	-o tools/system > System.map
	objcopy  -O binary -R .note -R .comment tools/system tools/system.bin
	(echo -n "SYS_SIZE equ ";stat -c%s tools/system.bin \
	| tr '\012' ' ') > boot/boot.inc
	
boot/boot:	boot/boot.asm tools/system
	(cd boot; make boot)

boot/head.o: boot/head.asm
	(cd boot; make head.o)
		
kernel/kernel.o:
	(cd kernel; make)

mm/mm.o:
	(cd mm; make)

fs/fs.o:
	(cd fs; make)

lib/lib.a:
	(cd lib; make)

	
run:
	qemu-system-i386 -drive format=raw,file=Image,index=0,if=floppy -boot a -hdb hd_oldlinux.img -m 8 -machine pc-0.10
	
dump:
	objdump -D --disassembler-options=intel tools/system > System.dum

clean:
	rm -f Image System.map tmp_make boot/boot core
	rm -f init/*.o boot/*.o tools/system tools/system.bin
	(cd boot;make clean)
	(cd mm;make clean)
	(cd fs;make clean)
	(cd kernel;make clean)
	(cd lib;make clean)

backup: clean
	(cd .. ; tar cf - linux | compress16 - > backup.Z)
#	sync

dep:
	sed '/\#\#\# Dependencies/q' < Makefile > tmp_make
	(for i in init/*.c;do echo -n "init/";$(CPP) -M $$i;done) >> tmp_make
	cp tmp_make Makefile
	(cd fs; make dep)
	(cd kernel; make dep)
	(cd mm; make dep)


### Dependencies:
init/main.o : init/main.c include/unistd.h include/sys/stat.h \
  include/sys/types.h include/sys/times.h include/sys/utsname.h \
  include/utime.h include/time.h include/linux/tty.h include/termios.h \
  include/linux/sched.h include/linux/head.h include/linux/fs.h \
  include/linux/mm.h include/asm/system.h include/asm/io.h include/stddef.h \
  include/stdarg.h include/fcntl.h 

