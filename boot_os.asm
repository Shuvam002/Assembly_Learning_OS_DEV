[org 0x7C00]                    ; BIOS loads boot sector at physical address 0x7C00
[bits 16]                       ; CPU starts in 16-bit Real Mode

_start:
    cli                         ; 1. Disable hardware interrupts during mode switch
    xor ax, ax
    mov ds, ax                  ; Zero Data Segment
    mov es, ax                  ; Zero Extra Segment
    mov ss, ax                  ; Zero Stack Segment
    mov sp, 0x7C00              ; Grow stack downward from 0x7C00

    lgdt [gdt_descriptor]       ; 2. Load Global Descriptor Table register

    mov eax, cr0                ; 3. Set Bit 0 (PE - Protection Enable) in CR0
    or eax, 0x1
    mov cr0, eax

    jmp 0x08:init_pm            ; 4. Far jump into 32-bit Code Segment (Selector 0x08)

; -----------------------------------------------------------------------------
; Global Descriptor Table (Flat 4GB Code and Data Segments for Ring 0)
; -----------------------------------------------------------------------------
align 8
gdt_start:
    dq 0x0000000000000000       ; Null Descriptor (Required at index 0)
gdt_code:
    dw 0xFFFF                   ; Limit (bits 0-15)
    dw 0x0000                   ; Base (bits 0-15)
    db 0x00                     ; Base (bits 16-23)
    db 10011010b                ; Access: Present, Ring 0, Code, Executable, Readable
    db 11001111b                ; Flags: 4KB Granularity, 32-bit + Limit (bits 16-19)
    db 0x00                     ; Base (bits 24-31)
gdt_data:
    dw 0xFFFF, 0x0000
    db 0x00, 10010010b, 11001111b, 0x00 ; Access: Ring 0 Data, Writable
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1  ; 16-bit Size of GDT minus 1
    dd gdt_start                ; 32-bit Base Address of GDT

; -----------------------------------------------------------------------------
; 32-Bit Protected Mode Kernel Entry
; -----------------------------------------------------------------------------
[bits 32]
init_pm:
    mov ax, 0x10                ; 0x10 is our GDT Data Segment selector
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov esp, 0x90000            ; Set 32-bit Ring 0 stack pointer at 0x90000

    ; 1. MMIO: Write "OS KERNEL ONLINE" directly to VGA RAM at 0xB8000
    mov edi, 0xB8000            ; VGA Text Buffer physical address
    mov esi, msg_kernel         ; Source string pointer
    mov ah, 0x0A                ; Color attribute: Light Green (0xA) on Black (0x0)

.vga_loop:
    lodsb                       ; Load next byte from [ESI] into AL and increment ESI
    test al, al                 ; Check for null terminator (0)
    jz .serial_out
    mov [edi], ax               ; Write 16-bit (Color:ASCII) directly to VGA MMIO
    add edi, 2                  ; Advance 2 bytes to next character cell
    jmp .vga_loop

    ; 2. Port I/O: Send confirmation string to COM1 Serial Port (0x3F8)
.serial_out:
    mov esi, msg_kernel
    mov dx, 0x3F8               ; COM1 UART data port address
.uart_loop:
    lodsb
    test al, al
    jz .halt_cpu
    out dx, al                  ; Hardware Port I/O write directly to UART
    jmp .uart_loop

.halt_cpu:
    hlt                         ; Put CPU into low-power sleep until next interrupt
    jmp .halt_cpu

msg_kernel db "OS KERNEL ONLINE [RING 0]", 10, 0

; Pad boot sector to 510 bytes and append the mandatory 0xAA55 BIOS boot signature
times 510 - ($ - $$) db 0
dw 0xAA55