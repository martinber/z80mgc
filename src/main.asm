#target ROM

; Boot code for the console

; This file includes all the other sources and selects the game to start.
; Each game should (assuming the game is named snake):
; - Use #code SNAKE_ROM without address or size
; - Use #data SNAKE_RAM, MAIN_ROM_end so the address is after the reserved space for this main code,
;   and the address is the same as the other games use (we never run 2 games at the same time)
; - Have a global label named snake_start
; - Cannot use A' and F'

; Framebuffer address offsets from fbuf start:
; Lines 0 to 31:
; 0x000 0x040 0x080 0x0C0 0x100 0x140 0x180 0x1C0 0x200 0x240 0x280 0x2C0 0x300 0x340 0x380 0x3C0
; 0x001 0x041 0x081 0x0C1 0x101 0x141 0x181 0x1C1 0x201 0x241 0x281 0x2C1 0x301 0x341 0x381 0x3C1
; 0x002 0x042 0x082 0x0C2 0x102 0x142 0x182 0x1C2 0x202 0x242 0x282 0x2C2 0x302 0x342 0x382 0x3C2
; ...
; 0x01D 0x05D 0x09D 0x0DD 0x11D 0x15D 0x19D 0x1DD 0x21D 0x25D 0x29D 0x2DD 0x31D 0x35D 0x39D 0x3DD
; 0x01E 0x05E 0x09E 0x0DE 0x11E 0x15E 0x19E 0x1DE 0x21E 0x25E 0x29E 0x2DE 0x31E 0x35E 0x39E 0x3DE
; 0x01F 0x05F 0x09F 0x0DF 0x11F 0x15F 0x19F 0x1DF 0x21F 0x25F 0x29F 0x2DF 0x31F 0x35F 0x39F 0x3DF
;
; Lines 32 to 63:
; 0x020 0x060 0x0A0 0x0E0 0x120 0x160 0x1A0 0x1E0 0x220 0x260 0x2A0 0x2E0 0x320 0x360 0x3A0 0x3E0
; 0x021 0x061 0x0A1 0x0E1 0x121 0x161 0x1A1 0x1E1 0x221 0x261 0x2A1 0x2E1 0x321 0x361 0x3A1 0x3E1
; 0x022 0x062 0x0A2 0x0E2 0x122 0x162 0x1A2 0x1E2 0x222 0x262 0x2A2 0x2E2 0x322 0x362 0x3A2 0x3E2
; ...
; 0x03D 0x07D 0x0BD 0x0FD 0x13D 0x17D 0x1BD 0x1FD 0x23D 0x27D 0x2BD 0x2FD 0x33D 0x37D 0x3BD 0x3FD
; 0x03E 0x07E 0x0BE 0x0FE 0x13E 0x17E 0x1BE 0x1FE 0x23E 0x27E 0x2BE 0x2FE 0x33E 0x37E 0x3BE 0x3FE
; 0x03F 0x07F 0x0BF 0x0FF 0x13F 0x17F 0x1BF 0x1FF 0x23F 0x27F 0x2BF 0x2FF 0x33F 0x37F 0x3BF 0x3FF


STACK_SIZE:     equ     32              ; in bytes
FBUF_SIZE:      equ     16*64           ; in bytes

#code BOOT_ROM, 0x0000, 0x0066

boot:
        ld      SP, stack+STACK_SIZE    ; Set stack
        ld      A, 1                    ; Set debug to 0
        ld      (debug), A

        call    welcome_start
        ; jp      snake_start
        ; jp      bricks_start

#code MAIN_NMI, 0x066

nmi:
        ex      AF, AF'
        ld      A, (timer_0)            ; Increment timer 0
        inc     A
        ld      (timer_0), A
        ld      A, (timer_1)            ; Increment timer 1
        inc     A
        ld      (timer_1), A
        ex      AF, AF'
        retn


; Args:
; - None
; Ret:
; - None
; Affects:
; - A
; - B
; - E
lcd_clr_graphics:
        ld      E, 63                   ; Set Y of last line to clear
_lcd_clr_graphics_v:
        ld      B, 16                   ; Set counter for X position
        call    lcd_wait
        ld      A, E                    ; Set Y coordinate to E
        or      A, LCD_EI_GD_ADDR
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, LCD_EI_GD_ADDR | 0   ; Set X coordinate to zero
        out     IO_LCD_W_INSTR, A
_lcd_clr_graphics_h:
        call    lcd_wait
        ld      A, 0                    ; Set data to write
        out     IO_LCD_W_MEM, A         ; Write data. LCD increments X position
        djnz    _lcd_clr_graphics_h     ; Decrement X and jump if not zero
        dec     E                       ; Decrement Y and jump if still positive
        jp      P, _lcd_clr_graphics_v
        ret


; Print a string until a null char
; Args:
; - HL: Address of first char
; Affects:
; - A
print:
        call    lcd_wait
        ld      A, (HL)
        cp      0
        ret     Z
        out     IO_LCD_W_MEM, A
        inc     HL
        jr      print


#data MAIN_RAM, 0x8000

fbuf:           data    FBUF_SIZE       ; Framebuffer, it is expected to be available at 0x8000
fbuf_end:
debug:          data    1               ; Flag that will be read by the emulator in address 0x8400
stack:          data    STACK_SIZE
timers:
timer_0:        data    1
timer_1:        data    1

tmp_a:          data    1               ; Scratch variables. Can be used as e.g:
tmp_bc:                                 ; ld BC, (tmp_bc)
tmp_c:          data    1
tmp_b:          data    1
tmp_de:
tmp_e:          data    1
tmp_d:          data    1

#include "z80mgc.asm"

#local
#include "welcome.asm"
#endlocal

#local
#include "snake.asm"
#endlocal

#local
#include "bricks.asm"
#endlocal
