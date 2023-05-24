#code CHECK_ROM

; Init
check_start::
reset:

; Test LCD text

        ld      SP, stack+STACK_SIZE    ; Set stack
        call    lcd_wait                ; Init LCD
        ld      A, LCD_BI_SET_8_B
        out     IO_LCD_W_INSTR, A
        call    lcd_wait                ; Clear LCD text
        ld      A, LCD_BI_CLR
        out     IO_LCD_W_INSTR, A
        call    lcd_wait                ; Turn LCD on
        ld      A, LCD_BI_ON
        out     IO_LCD_W_INSTR, A

        call    lcd_wait                ; Write line 1
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
        call    lcd_wait                ; Write line 3
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

; Test RAM and LCD text

; Init
        call    lcd_wait                ; Init LCD
        ld      A, LCD_BI_SET_8_B
        out     IO_LCD_W_INSTR, A
        call    lcd_wait                ; Clear LCD text
        ld      A, LCD_BI_CLR
        out     IO_LCD_W_INSTR, A
        call    lcd_wait                ; Turn LCD on
        ld      A, LCD_BI_ON
        out     IO_LCD_W_INSTR, A

        ld      A, 'R'                  ; Write to RAM, read and write it to LCD
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

        call    lcd_wait
        ld      A, LCD_BI_DD_ADDR | LCD_DD_ADDR_L1
        out     IO_LCD_W_INSTR, A

        call    lcd_wait
        ld      A, (ram_test)
        out     IO_LCD_W_MEM, A
        call    lcd_wait
        ld      A, (ram_test+1)
        out     IO_LCD_W_MEM, A
        call    lcd_wait
        ld      A, (ram_test+2)
        out     IO_LCD_W_MEM, A
        call    lcd_wait
        ld      A, (ram_test+3)
        out     IO_LCD_W_MEM, A
        call    lcd_wait
        ld      A, (ram_test+4)
        out     IO_LCD_W_MEM, A
        call    lcd_wait
        ld      A, (ram_test+5)
        out     IO_LCD_W_MEM, A

; Test LCD graphics

        call    lcd_wait                    ; Init graphics
        ld      A, LCD_EI_SET_8_E_G         ; Twice because first only sets extended mode
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, LCD_EI_SET_8_E_G
        out     IO_LCD_W_INSTR, A

                                            ; Clear graphics

        ld      E, 31                       ; Y
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
        call    lcd_wait                    ; Write 0 two times
        ld      A, 0
        out     IO_LCD_W_MEM, A
        call    lcd_wait                    ; Write 0 two times
        ld      A, 0
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
        jr      NZ, write_sprite_loop

write_sprite_loop_end:

        call    lcd_wait
        ld      A, LCD_EI_SET_8_B_G
        out     IO_LCD_W_INSTR, A

; Keep looping

loop:
        halt
        jr      loop


                db      0b01100110
                db      0b01100110
                db      0b00000000
                db      0b00001000
                db      0b00001100
                db      0b00000000
                db      0b10000001
sprite:         db      0b01111110

#data CHECK_RAM, MAIN_RAM_end

ram_test:       data    8
