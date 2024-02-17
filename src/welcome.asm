#code WELCOME_ROM

N_GAMES:        equ     2               ; Max 16 supported

; Init
welcome_start::

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

        ld      HL, welcome_msg
        call    print

        ld      A, 0                    ; Set first game as selected
        ld      (selected_game), A

        jp      loop


; Keep looping

loop:

        ld      HL, games_names         ; Set HL to games_names + selected_game * 16
        ld      B, 0
        ld      A, (selected_game)
        ld      C, A
        sla     C
        sla     C
        sla     C
        add     HL, BC

        call    lcd_wait                ; Write line 3
        ld      A, LCD_BI_DD_ADDR | LCD_DD_ADDR_L3
        out     IO_LCD_W_INSTR, A

        call    print                   ; Print game name in HL

        halt
        jr      loop

welcome_msg:    defb    "==== z80mgc ====",0
games_names:    defb    " ",16," Snake        ",0    ; Required length: 15 chars + null. 16 is a >
                defb    " ",16," Bricks       ",0

                db      0b01100110
                db      0b01100110
                db      0b00000000
                db      0b00001000
                db      0b00001100
                db      0b00000000
                db      0b10000001
sprite:         db      0b01111110

#data WELCOME_RAM, MAIN_RAM_end

selected_game:  data    8
