[org 0x7C00]                    ; Tell NASM our code is loaded at physical 0x7C00
[bits 16]                       ; Emit 16-bit Real Mode machine instructions

_start:
    ; 1. Disable interrupts and normalize CS:IP to 0x0000:0x7C00
    cli                         ; Clear Interrupt Flag (IF = 0 in EFLAGS)
    cld                         ; Clear Direction Flag so string ops increment SI/DI
    jmp 0x0000:.flush_cs        ; Far jump forces CS = 0x0000 regardless of BIOS

.flush_cs:
    xor ax, ax                  ; AX = 0x0000
    mov ds, ax                  ; Data Segment = 0x0000
    mov ss, ax                  ; Stack Segment = 0x0000
    mov sp, 0x7C00              ; Stack grows safely downward from 0x7C00 toward 0x0500

    ; 2. Unlock the A20 Address Line via Fast A20 Gate (System Control Port 0x92)
    in al, 0x92                 ; Read current Port 0x92 state into AL
    or al, 0b00000010           ; Set Bit 1 (A20 Enable)
    and al, 0b11111110          ; Ensure Bit 0 (Fast Reset) stays 0!
    out 0x92, al                ; Write updated byte back to Port 0x92

    ; 3. Read Control Register CR0 into 32-bit EAX (Allowed in 16-bit Ring 0!)
    mov eax, cr0                ; Inspect EAX in GDB: Bit 0 (PE) and Bit 31 (PG) are 0

    ; 4. Use Segmented Addressing to write directly to VGA RAM (0xB800:0x0000 = 0xB8000)
    mov bx, 0xB800
    mov es, bx                  ; Extra Segment (ES) = 0xB800
    xor di, di                  ; Offset DI = 0x0000 -> ES:DI points to physical 0xB8000
    mov si, boot_msg            ; DS:SI points to our string at 0x0000:boot_msg
    mov ah, 0x1F                ; Attribute: Bright White text (0xF) on Blue background (0x1)

.print_vga:
    lodsb                       ; Load byte from [DS:SI] into AL and increment SI
    test al, al                 ; Check for null terminator (0)
    jz .spin_halt
    mov [es:di], ax             ; Write 16-bit word (Color AH : Char AL) to [0xB800:DI]
    add di, 2                   ; Advance 2 bytes to next VGA character cell
    jmp .print_vga

.spin_halt:
    hlt                         ; Ring 0 privileged halt instruction
    jmp .spin_halt

boot_msg db "CH0: REAL MODE + A20 + CR0 VERIFIED", 0

; Pad binary to 510 bytes and write the 2-byte 0xAA55 BIOS signature
times 510 - ($ - $$) db 0
dw 0xAA55