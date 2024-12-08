#code DEBUG_ROM

debug_start::
reset:
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
        call    lcd_wait                ; Set extended mode
        ld      A, LCD_BI_SET_8_E
        out     IO_LCD_W_INSTR, A
        call    lcd_wait                ; Turn on graphics
        ld      A, LCD_EI_SET_8_E_G
        out     IO_LCD_W_INSTR, A
        call    lcd_clr_graphics        ; Clear graphics

        ; Draw version

        call    lcd_wait                ; Set basic mode
        ld      A, LCD_BI_SET_8_B
        out     IO_LCD_W_INSTR, A

        call    lcd_wait                ; Write line 1
        ld      A, LCD_BI_DD_ADDR | LCD_DD_ADDR_L1
        out     IO_LCD_W_INSTR, A

        ld      HL, version_msg_1
        call    print
        ld      HL, version_msg_2
        call    print

        ; Draw credits

        call    lcd_wait                ; Set extended mode
        ld      A, LCD_BI_SET_8_E
        out     IO_LCD_W_INSTR, A

        ld      A, 60                   ; Y position of sprite
        ld      E, 8                    ; X position of sprite
        call    calc_fbuf_addr
        ld      HL, credits_0           ; Set sprite address to start of sprites data
        ld      C, 4                    ; Set sprite height
        call    copy_sprite

        ld      A, 60
        ld      E, 9
        call    calc_fbuf_addr
        ld      HL, credits_1
        ld      C, 4
        call    copy_sprite

        ld      A, 60
        ld      E, 10
        call    calc_fbuf_addr
        ld      HL, credits_2
        ld      C, 4
        call    copy_sprite

        ld      A, 60
        ld      E, 11
        call    calc_fbuf_addr
        ld      HL, credits_3
        ld      C, 4
        call    copy_sprite

        ld      A, 60
        ld      E, 12
        call    calc_fbuf_addr
        ld      HL, credits_4
        ld      C, 4
        call    copy_sprite

        ld      A, 60
        ld      E, 13
        call    calc_fbuf_addr
        ld      HL, credits_5
        ld      C, 4
        call    copy_sprite

        ld      A, 60
        ld      E, 14
        call    calc_fbuf_addr
        ld      HL, credits_6
        ld      C, 4
        call    copy_sprite

        ld      A, 60
        ld      E, 15
        call    calc_fbuf_addr
        ld      HL, credits_7
        ld      C, 4
        call    copy_sprite

        call    disp_fbuf

        jp      main

main:
        halt
        jp main

credits_0:      db      0b10001001      ; Credits graphics
                db      0b11011010
                db      0b10101011
                db      0b10001010

credits_1:      db      0b10011100
                db      0b01010010
                db      0b11011100
                db      0b01010010

credits_2:      db      0b11101010
                db      0b01001011
                db      0b01001010
                db      0b01001010

credits_3:      db      0b01001110
                db      0b01001111
                db      0b11001001
                db      0b01001111

credits_4:      db      0b01111011
                db      0b01110010
                db      0b01000011
                db      0b01111010

credits_5:      db      0b10010010
                db      0b01011010
                db      0b10010110
                db      0b01010010

credits_6:      db      0b01100111
                db      0b10010100
                db      0b11110111
                db      0b10010100

credits_7:      db      0b00111001
                db      0b10100101
                db      0b00100101
                db      0b10111001

version_msg_1:  defb    "z80mgc ",0
version_msg_2:  incbin  "version.txt"
                defb    0               ; Null char for version

#data DEBUG_RAM, MAIN_RAM_end

