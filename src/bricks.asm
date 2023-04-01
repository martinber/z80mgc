

#code BRICKS_ROM

; Init
bricks_start::
        call    lcd_wait
        ld      A, LCD_BI_SET_8_B
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, LCD_BI_CLR
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, LCD_BI_ON
        out     IO_LCD_W_INSTR, A
; Write line 1
        call    lcd_wait
        ld      A, LCD_BI_DD_ADDR | LCD_DD_ADDR_L1
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, 'L'
        out     IO_LCD_W_MEM, A
        call    lcd_wait
        ld      A, 'C'
        out     IO_LCD_W_MEM, A
        call    lcd_wait
        ld      A, 'D'
        out     IO_LCD_W_MEM, A
; Write line 3
        call    lcd_wait
        ld      A, LCD_BI_DD_ADDR | LCD_DD_ADDR_L3
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, 'W'
        out     IO_LCD_W_MEM, A
        call    lcd_wait
        ld      A, 'o'
        out     IO_LCD_W_MEM, A
        call    lcd_wait
        ld      A, 'r'
        out     IO_LCD_W_MEM, A
        call    lcd_wait
        ld      A, 'k'
        out     IO_LCD_W_MEM, A
        call    lcd_wait
        ld      A, 's'
        out     IO_LCD_W_MEM, A

        halt


; - A: Trash
lcd_wait:
        in      A, IO_LCD_R_INSTR
        bit     7, A
        jr      NZ, lcd_wait
        ret

#data BRICKS_RAM, MAIN_RAM_end
