[org 0x7C00]
[bits 16]

_start:
    ; 1. Normalize 16-bit Real Mode segments and disable interrupts
    cli
    cld
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x7C00

    ; 2. Unlock A20 line via Fast A20 port 0x92
    in al, 0x92
    or al, 0b00000010
    and al, 0b11111110
    out 0x92, al

    ; 3. Load the 48-bit GDTR register (16-bit limit + 32-bit base)
    lgdt [gdt_descriptor]

    ; 4. Enable 32-bit Protected Mode by setting Bit 0 (PE) in CR0
    mov eax, cr0
    or eax, 0x00000001
    mov cr0, eax

    ; 5. Far jump loads CS with 0x08 (GDT Index 1) and flushes pipeline
    jmp 0x08:init_pm

; -----------------------------------------------------------------------------
; Global Descriptor Table (GDT)
; -----------------------------------------------------------------------------
align 8
gdt_start:
    ; Index 0 (Selector 0x00): Mandatory 8-byte Null Descriptor
    dq 0x0000000000000000

gdt_code:
    ; Index 1 (Selector 0x08): 32-Bit Ring 0 Flat Code Segment (0x00000000 - 0xFFFFFFFF)
    dw 0xFFFF                   ; Limit (bits 0-15)
    dw 0x0000                   ; Base (bits 0-15)
    db 0x00                     ; Base (bits 16-23)
    db 10011010b                ; Access (0x9A): P=1, DPL=00, S=1, E=1, DC=0, RW=1, A=0
    db 11001111b                ; Flags (0xCF): G=1 (4KB), DB=1 (32-bit), L=0 + Limit (16-19)
    db 0x00                     ; Base (bits 24-31)

gdt_data:
    ; Index 2 (Selector 0x10): 32-Bit Ring 0 Flat Data Segment (0x00000000 - 0xFFFFFFFF)
    dw 0xFFFF                   ; Limit (bits 0-15)
    dw 0x0000                   ; Base (bits 0-15)
    db 0x00                     ; Base (bits 16-23)
    db 10010010b                ; Access (0x92): P=1, DPL=00, S=1, E=0, DC=0, RW=1, A=0
    db 11001111b                ; Flags (0xCF): G=1 (4KB), DB=1 (32-bit), L=0 + Limit (16-19)
    db 0x00                     ; Base (bits 24-31)
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1  ; Size of GDT in bytes minus 1 (24 - 1 = 23)
    dd gdt_start                ; 32-bit physical base address of gdt_start

; -----------------------------------------------------------------------------
; 32-Bit Protected Mode Entry Point
; -----------------------------------------------------------------------------
[bits 32]
init_pm:
    ; 6. Reload all data and stack segment registers with Data Selector 0x10
    mov ax, 0x10
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov esp, 0x90000            ; Set 32-bit Stack Pointer in free RAM at 0x90000

    ; 7. Flat 32-Bit Addressing: Write directly to 0xB8000 without segment math!
    mov edi, 0xB8000            ; Direct 32-bit physical pointer to VGA memory
    mov esi, pm_msg             ; Direct 32-bit pointer to string
    mov ah, 0x0E                ; Color: Yellow text (0xE) on Black background (0x0)

.loop_vga:
    lodsb                       ; Load byte from [ESI] into AL, increment ESI
    test al, al
    jz .halt
    mov [edi], ax               ; Flat 32-bit write to [0xB8000 + offset]
    add edi, 2
    jmp .loop_vga

.halt:
    hlt
    jmp .halt

pm_msg db "CH1: 32-BIT PROTECTED MODE + FLAT GDT ACTIVE", 0

times 510 - ($ - $$) db 0
dw 0xAA55