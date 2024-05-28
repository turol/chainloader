; MIT License
;
; Copyright (c) 2024 Turo Lamminen
;
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.

; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.

; To compile:
;   nasm -o chain.bin chain.asm
; or:
;   yasm -o chain.bin chain.asm

; To build image:
;  dd if=/dev/zero of=chainloader.img bs=1 count=1474560
;  mkfs.fat -F 12 -n CHAINLOADER chainloader.img
;  dd conv=notrunc if=chain.bin of=chainloader.img

BITS 16
; we use print function which is only in AT BIOS
CPU 286

origin_addr    equ 0x7c00
relocate_addr  equ 0x0600

ORG origin_addr


; usage: print message, length
%macro print 2

    ; get cursor position
    mov dx, 0
    mov ax, 0x0300
    mov bx, 0
    ; make sure bios doesn't clobber message
    int 0x10
    ; return values in dx

    mov ax, 0x1301
    mov bx, 0x0007 ; color
    mov bp, %1
    mov cx, %2
    ; leave dx as  set by cursor pos check
    int 0x10

%endmacro


start:
    ; jump to actual code
    jmp main

    ; align to 3 bytes
    times (3 + $$ - $) db 0x90

bios_data_block:
    db 'CHAINLDR'
    dw 0x0200
    db 0x01
    dw 0x0001
    db 0x02
    dw 0x00E0
    dw 0x0B40
    db 0xF0
    dw 0x0009
    dw 0x0012
    dw 0x0002
    dd 0x0
    dd 0x0
    db 0x0
    db 0x0
    db 0x29
    dd 0x0C4A08E8
    db 'CHAINLOADER'
    db 'FAT12   '

main:
    ; save some registers
    ; since we want to leave most registers exactly as set by BIOS
    ; but can't use stack since it might be small
    ; at this point DS does not point to the same as segment as CS either
    mov [cs:saved_ax], ax
    mov ax, ds
    mov [cs:saved_ds], ax
    ; load DS so we don't need overrides any more
    xor ax, ax
    mov ds, ax

    ; save some more registers
    ; don't need dx, it's going to be used to pass parameter to the MBR
    mov [saved_bx], bx
    mov [saved_cx], cx
    mov [saved_di], di
    mov [saved_si], si
    mov [saved_bp], bp
    mov [saved_es], es
    mov es, ax

    ; clear direction flag in case BIOS left it wrong
    cld

    ; relocate ourselves to 0x0600
    ; that is the same address that MBR uses to relocate itself
    mov di, relocate_addr
    mov si, origin_addr
    mov cx, 512
    rep movsb

    ; jump to relocated code
    jmp relocate_addr + relocated - $$

relocated:

    print chain_msg, chain_msg_len

    ; load hard disk MBR into origin_addr
    mov ax, 0x0201
    mov bx, origin_addr
    mov cx, 0x0001
    mov dx, 0x0080
    int 0x13
    jc read_error

    ; we have successfully loaded hard drive MBR
    ; which means we've clobbered the original copy of ourself

    ; restore saved registers
    ; remember to account for relocation
    mov bx, [saved_bx - origin_addr + relocate_addr]
    mov cx, [saved_cx - origin_addr + relocate_addr]
    mov di, [saved_di - origin_addr + relocate_addr]
    mov si, [saved_si - origin_addr + relocate_addr]
    mov bp, [saved_bp - origin_addr + relocate_addr]
    mov es, [saved_es - origin_addr + relocate_addr]
    mov ax, [saved_ds - origin_addr + relocate_addr]
    mov ds, ax
    mov ax, [cs:saved_ax - origin_addr + relocate_addr]

    ; set values mbr expects from bios
    mov dx, 0x80 ; first hard disk

    ; jump to loaded MBR
    jmp 0x0:origin_addr

read_error:
    print read_error_msg, read_error_len

halted:
    hlt
    jmp halted

saved_ax: dw 0
saved_bx: dw 0
saved_cx: dw 0
saved_di: dw 0
saved_si: dw 0
saved_bp: dw 0
saved_ds: dw 0
saved_es: dw 0

chain_msg: db "Chain loading from hard drive...", 0x0d, 0x0a
chain_msg_len equ $ - chain_msg

read_error_msg: db "Failed to read from hard drive. System halted.", 0x0d, 0x0a
read_error_len equ $ - read_error_msg

    ; align signature to 510 bytes
    times (510 + $$ - $) db 0xCC

    ; signature so BIOS knows this is a valid boot sector
signature:
    db 0x55, 0xAA
