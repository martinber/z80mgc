#target ROM

#include "z80mgc.asm"

STACK_SIZE:     equ     32 ; in bytes

#code ROM_CODE, 0x0000

start:
        jp      run_tests


.org    0x0066
nmi:
        nop
        nop
        jp      run_tests

run_tests:

;;;;;;;;;;;;;;; Test LCD text



; Init
        ld      A, LCD_BI_SET_8_B
        call    lcd_w_instr
        ld      A, LCD_BI_CLR
        call    lcd_w_instr
        ld      A, LCD_BI_ON
        call    lcd_w_instr
; Write line 1
        ld      A, LCD_BI_DD_ADDR | LCD_DD_ADDR_L1
        call    lcd_w_instr
        ld      A, 'L'
        call    lcd_w_mem
        ld      A, 'C'
        call    lcd_w_mem
        ld      A, 'D'
        call    lcd_w_mem
; Write line 3
        ld      A, LCD_BI_DD_ADDR | LCD_DD_ADDR_L3
        call    lcd_w_instr
        ld      A, 'W'
        call    lcd_w_mem
        ld      A, 'o'
        call    lcd_w_mem
        ld      A, 'r'
        call    lcd_w_mem
        ld      A, 'k'
        call    lcd_w_mem
        ld      A, 's'
        call    lcd_w_mem

;;;;;;;;;;;;;;; Test RAM and LCD text

; Init
        ld      A, LCD_BI_SET_8_B
        call    lcd_w_instr
        ld      A, LCD_BI_CLR
        call    lcd_w_instr
        ld      A, LCD_BI_ON
        call    lcd_w_instr
; Write to RAM, read and write it to LCD
        ld      A, 'R'
        ld      (ram_test), A
        ld      A, 'A'
        ld      (ram_test+1), A
        ld      A, 'M'
        ld      (ram_test+2), A
        ld      A, ' '
        ld      (ram_test+3), A
        ld      A, 'O'
        ld      (ram_test+4), A
        ld      A, 'K'
        ld      (ram_test+5), A

        ld      A, LCD_BI_DD_ADDR | LCD_DD_ADDR_L1
        call    lcd_w_instr

        ld      A, (ram_test)
        call    lcd_w_mem
        ld      A, (ram_test+1)
        call    lcd_w_mem
        ld      A, (ram_test+2)
        call    lcd_w_mem
        ld      A, (ram_test+3)
        call    lcd_w_mem
        ld      A, (ram_test+4)
        call    lcd_w_mem
        ld      A, (ram_test+5)
        call    lcd_w_mem


;;;;;;;;;;;;;;; Test LCD graphics

; Init graphics

        ld      A, LCD_EI_SET_8_E_G         ; Twice because first only sets extended mode
        call    lcd_w_instr
        ld      A, LCD_EI_SET_8_E_G
        call    lcd_w_instr

; Clear graphics

        ld      E, 63                       ; Y
clear_loop_ver:
        ld      B, 16                       ; Counter for X
        call    lcd_wait
        ld      A, E                        ; Set Y
        or      A, LCD_EI_GD_ADDR
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, LCD_EI_GD_ADDR | 0       ; Set X to zero
        out     IO_LCD_W_INSTR, A
clear_loop_hor:
        call    lcd_wait
        ld      A, 0                        ; Data
        out     IO_LCD_W_MEM, A
        djnz    clear_loop_hor              ; Decrement B and jump if not zero

        dec     E                           ; Decrement Y and jump if still positive
        jp      P, clear_loop_ver

; Write graphics

        ld      D, LCD_EI_GD_ADDR | 1       ; X
        ld      E, LCD_EI_GD_ADDR | (10+8)  ; Y
        ld      C, IO_LCD_W_MEM             ; IO device
        ld      B, 8                        ; Amount of bytes to write
        ld      HL, sprite                  ; Start of data
write_sprite_loop:
        call    lcd_wait
        ld      A, E                        ; Set Y address
        add     B
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, D                        ; Set X address
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        outd                                ; Send to IO dev C, contents of (HL), decrement HL and B
        jr      Z, write_sprite_loop_end
        jr      write_sprite_loop

write_sprite_loop_end:

        call    lcd_wait
        ld      A, LCD_EI_SET_8_B_G
        out     IO_LCD_W_INSTR, A

        halt

; ; Test scroll
;         ld      A, LCD_EI_SET_8_E_G
;         out     IO_LCD_W_INSTR, A
;
;         ld      A, LCD_EI_VSCR
;         out     IO_LCD_W_INSTR, A
;
;         ld      A, LCD_EI_VSCR_A | 0x04     ; Scroll half a line
;         out     IO_LCD_W_INSTR, A



; - A: Instruction

; - C: Trash
lcd_w_instr:
        ld      C, IO_LCD_R_INSTR
_lcd_w_instr_check_busy:
        in      (C)                         ; Undocumented instruction. Only sets flags
        jp      M, _lcd_w_instr_check_busy
        out     IO_LCD_W_INSTR, A
        ret


; - A: Trash
lcd_wait:
        in      A, IO_LCD_R_INSTR
        bit     7, A
        jr      NZ, lcd_wait
        ret

; - A: Data

; - C: Trash
lcd_w_mem:
        ld      C, IO_LCD_R_INSTR
_lcd_w_mem_check_busy:
        in      (C)                         ; Undocumented instruction. Only sets flags
        jp      M, _lcd_w_mem_check_busy
        out     IO_LCD_W_MEM, A
        ret


                db      0b01100110
                db      0b01100110
                db      0b00000000
                db      0b00001000
                db      0b00001100
                db      0b00000000
                db      0b10000001
sprite:         db      0b01111110


#data RAM_DATA, 0x8000

ram_test:       data    8
stack:          data    STACK_SIZE
