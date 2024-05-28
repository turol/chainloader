# chainloader
A floppy boot sector that boots from the hard drive

To compile:

`nasm -o chain.bin chain.asm`

or:

`yasm -o chain.bin chain.asm`

To build image:
```
dd if=/dev/zero of=chainloader.img bs=1 count=1474560
mkfs.fat -F 12 -n CHAINLOADER chainloader.img
dd conv=notrunc if=chain.bin of=chainloader.img
```
