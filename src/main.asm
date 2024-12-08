#target ROM

; Boot code for the console

; This file includes all the other sources and selects the game to start.
; Each game should (assuming the game is named snake):
; - Use #code SNAKE_ROM without address or size
; - Use #data SNAKE_RAM, MAIN_ROM_end so the address is after the reserved space for this main code,
;   and the address is the same as the other games use (we never run 2 games at the same time)
; - Have a global label named snake_start
; - Cannot use A' and F'


STACK_SIZE:     equ     32              ; in bytes
FBUF_SIZE:      equ     16*64           ; in bytes

#code BOOT_ROM, 0x0000, 0x0066

boot:
        ld      SP, stack+STACK_SIZE    ; Set stack
        ld      A, 0                    ; Set debug to 0 or 1
        ld      (debug), A

        call    welcome_start

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
        ld      E, 31                   ; Set Y of last line to clear
_lcd_clr_graphics_v:
        ld      B, 32                   ; Set counter for X=16 with 2 byte writes per position
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

#local
#include "debug.asm"
#endlocal
