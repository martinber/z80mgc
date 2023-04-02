; Screen size in pixels
FIELD_W:        equ     128
FIELD_H:        equ     64

; Can fit 16 bricks horizontally

#code BRICKS_ROM

; Init
bricks_start::
reset:
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

; Init ball
        ; ld      (ball_x), 64
        ; ld      (ball_y), 32
        ; ld      (ball_vx), 1
        ; ld      (ball_vy), 1

        halt


; ; Tengo que dibujar primero en un buffer de 16x4 y despues copiar
; draw_ball:
;         ld      B, (ball_x)
;         ld      DE, (ball_xy)
;         srl     B                       ; Divide by 8
;         srl     B
;         srl     B
;
;         ld      A, (sprite_ball)
;
; _draw_ball_s:
;         cp      B, D                    ; If both are equal, means ew are done shifting the tile
;         jp      Z, _draw_ball_s_end
;
;
;
; ; Tengo que dibujar primero en un buffer de 16x4 y despues copiar
; draw_ball:
;         ld      B, (ball_x)
;         ld      DE, (ball_xy)
;         srl     B                       ; Divide by 8
;         srl     B
;         srl     B
;
;         lcd_disp_sprite
;
; _draw_ball_s:
;         cp      B, D                    ; If both are equal, means ew are done shifting the tile
;         jp      Z, _draw_ball_s_end



; Levels in ROM

lvl_1:          db      0b01100000

; Bitmaps in ROM

; Sprite 0 is always empty. The tag points to the address of the last line
                db      0b01100000
                db      0b10010000
                db      0b10110000
sprite_ball:    db      0b01100000

                db      0b00000000
                db      0b00000000
                db      0b00000000
sprite_br0:     db      0b00000000

                db      0b01111110
                db      0b10000001
                db      0b10111111
sprite_br1:     db      0b01111110



#data BRICKS_RAM, MAIN_RAM_end

ball_xy:                                ; ld BC,(ball_xy) will do B<-y, C<-x
ball_x:         data    1
ball_y:         data    1
ball_vxvy:                              ; ld BC,(ball_vxvy) will do B<-vy, C<-vx
ball_vx:        data    1
ball_vy:        data    1
pad_x:          data    1

tile_buf:       data    8               ; Used to write temporarily a region of 16x4px
