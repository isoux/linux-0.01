linux-0.01 On Ubuntu 18.04 with GCC-7.3 & NASM assembler

First of all, thanks Mariuz!

After a lot of time, I managed to compile this revised version of the first kernel on machines with Ubuntu 18.04 64 and 32 bit versions. So you can compile them and try them on 64 and 32 bit Intel machines.

The kernel runs in both emulators: QEMU ver. 2.11.1 and Bochs ver 2.6. and that was a great success for me ...

I also uploaded the bochsrc.txt file so that the bochs runs from the command line from the root where the kernel(Image) is and qemu runs from the cmd line by the command: make run, but first unzip the file hd_oldlinux.img.zip.

In this branch: working-ver, I'll update new stuffs, actually stuffs compiled with new tools for compiling. At this moment you must have installed NASM assembler on your system. For fans of the authentic kernel as mr. Torvalds wrote it with the available tools for that time, I left the Master branch, which I will no longer update with new things. So on this: working-ver branch I'll update new things.

Enjoy work and improvement. sincerely Isoux
