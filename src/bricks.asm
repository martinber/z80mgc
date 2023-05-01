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

        ld      BC, 128                 ; Copy 128 bytes of level data to (tiles)
        ld      HL, lvl_2
        ld      DE, tiles
        ldir

        ld      A, 7                    ; Init ball
        ld      (ball_x), A
        ld      A, 0
        ld      (ball_y), A
        ld      A, 1
        ld      (ball_vx), A
        ld      A, 1
        ld      (ball_vy), A

        ld      A, 116                  ; Init pad
        ld      (pad_x), A
        ld      A, 3
        ld      (pad_len), A

        call    draw_bricks             ; Draw bricks

_loop:
        halt
        ld      A, (timer_0)            ; Continue waiting if less than 8 ticks passed
        and     0b00000011
        jr      NZ, _loop

        call    draw_pad                ; Draw pad

        call    draw_ball               ; Draw ball

        ld      IX, ball_x              ; Move ball according to velocity
        ld      A, (IX+0)
        add     A, (IX+2)
        ld      (IX+0), A
        ld      A, (IX+1)
        add     A, (IX+3)
        ld      (IX+1), A

        jr      _loop



; Args:
; - Nothing
; Ret:
; - Nothing
; Affects:
; - All
draw_bricks:
        ld      D, tiles/255                ; DE holds tile memory address. Table is 256-aligned, so
        ld      E, 0                        ; D will be high byte of table start address and the low
                                            ; will be the offset or actual position of the
                                            ; brick/tile. To get the Y position I can use E/16 and
                                            ; the remainder is the X position

        ld      A, 0 | LCD_EI_GD_ADDR       ; Holds Y coordinate in pixels of the bottom of the tile
        ld      (_cur_y), A                 ; from the top of the screen, I put it in another
                                            ; variable so I dont have to divide E by 16 and to do
                                            ; the OR with LCD_EI_GD_ADDR every time
_draw_bricks_loop:
        ld      H, sprite_null/256          ; Get sprite table start (it starts at Y=3 of the
                                            ; sprite, and its 256-aligned)

        ld      A, (DE)                     ; Get tile to draw

        sla     A                           ; Multiply the ID by 4 to get the offset of address of
        sla     A                           ; sprite.
        ld      L, A                        ; So now we have address of sprite in HL

        ld      C, IO_LCD_W_MEM             ; IO device
        ld      B, 4                        ; Sprite height
_draw_bricks_line_loop:
        call    lcd_wait
        ld      A, (_cur_y)                 ; Set Y address, already in OR with flag
        add     B
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, E                        ; Set X address, I have to modulo by 16 and OR with flag
        and     A, 0b00001111
        or      LCD_EI_GD_ADDR
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        outd                                ; Send to IO dev C, contents of (HL), decrement HL and B
        jr      NZ, _draw_bricks_line_loop
; End of loop
        inc     E                           ; Increment address

        ld      A, 0b00001111               ; See if E is multiple of 16 meaning we went down a line
        and     E
        jr      NZ, _draw_bricks_loop       ; Loop if we didnt reach end of line
        ld      A, (_cur_y)                 ; Add 5 to (_cur_y)
        add     A, 5
        ld      (_cur_y), A
        ld      A, 128                      ; See if E reached 128, meaning we alreade drew 8 lines
        cp      E
        jr      NZ, _draw_bricks_loop
        ret


; Args:
; - Nothing
; Ret:
; - Nothing
; Affects:
; - All
draw_ball:
        ld      DE, (ball_xy)               ; D<-y, E<-x
        ld      A, 0b00000111               ; A will hold the modulo 8 of X position
        and     E
        srl     E                           ; E will hold the X in tiles, which is X/8
        srl     E
        srl     E
        cp      7                           ; If X is modulo 7, we have to draw two tiles as below
        jr      Z, _draw_ball_wrapped
_draw_ball_normal:
        ld      H, lut_ball/255             ; Get sprite to draw in LUT, lut_ball is 256-aligned
        ld      L, A
        call    lcd_wait
        ld      A, D                        ; Write Y address
        or      LCD_EI_GD_ADDR
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, E                        ; Write X address
        or      LCD_EI_GD_ADDR
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, (HL)                     ; Write sprite line
        out     IO_LCD_W_MEM, A
        inc     D                           ; Now do it again one line below
        call    lcd_wait
        ld      A, D                        ; Write Y address
        or      LCD_EI_GD_ADDR
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, E                        ; Write X address
        or      LCD_EI_GD_ADDR
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, (HL)                     ; Write sprite line
        out     IO_LCD_W_MEM, A
        ret
_draw_ball_wrapped:
        call    lcd_wait
        ld      A, D                        ; Write Y address
        or      LCD_EI_GD_ADDR
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, E                        ; Write X address
        or      LCD_EI_GD_ADDR
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, 0b00000001               ; Draw one pixel in the right
        out     IO_LCD_W_MEM, A
        call    lcd_wait
        ld      A, 0b10000000               ; Draw one pixel in the left
        out     IO_LCD_W_MEM, A
        inc     D                           ; Now do it again one line below
        call    lcd_wait
        ld      A, D                        ; Write Y address
        or      LCD_EI_GD_ADDR
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, E                        ; Write X address
        or      LCD_EI_GD_ADDR
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, 0b00000001               ; Draw one pixel in the right
        out     IO_LCD_W_MEM, A
        call    lcd_wait
        ld      A, 0b10000000               ; Draw one pixel in the left
        out     IO_LCD_W_MEM, A
        ret


draw_pad:
        ld      C, IO_LCD_W_MEM             ; IO device

        ld      H, 0                        ; Line number
_draw_pad_line:
        call    lcd_wait
        ld      A, 60                       ; Write Y address
        add     H
        or      LCD_EI_GD_ADDR
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, 0                        ; Write X address
        or      LCD_EI_GD_ADDR
        out     IO_LCD_W_INSTR, A

        ld      B, 4; X modulo 16
        ld      L, 0b11000000; Sprite line
        ld      D, 0b00000011; Sprite line
_draw_pad_shift_loop:
        srl     L                           ; Shift right first tile
        sra     D                           ; Shift right second tile, repeating b7 and carrying b0
        rra                                 ; Shift carry into A for third tile
        djnz    _draw_pad_shift_loop
        ld      E, A

        call    lcd_wait
        out     (C), L
        call    lcd_wait
        out     (C), D
        call    lcd_wait
        out     (C), E

        inc     H
        ret


; Levels in ROM. Each line of bricks is 16 bytes, and there are max 8 lines of 5 px tall.
; I make aliases to TILE_AIR, TILE_DR0, etc so its easier
__:             equ     TILE_AIR
_0:             equ     TILE_BR0
_1:             equ     TILE_BR1
_2:             equ     TILE_BR2

lvl_1:          db      _0, _0, _0, __, __, _1, _1, __, __, _1, _1, __, __, _0, _0, _0
                db      _0, _0, _0, __, __, _1, _1, __, __, _1, _1, __, __, _0, _0, _0
                db      _0, _0, __, __, __, __, __, __, __, __, __, __, __, __, _0, _0
                db      _0, _0, __, __, __, __, __, __, __, __, __, __, __, __, _0, _0
                db      __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, __
                db      __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, __
                db      __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, __
                db      __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, __

lvl_2:          db      _2, _2, _0, _0, _0, _2, _2, _0, _0, _2, _2, _0, _0, _0, _2, _2
                db      _2, _2, _0, _0, _0, _1, _1, _0, _0, _1, _1, _0, _0, _0, _2, _2
                db      _0, _0, __, __, __, __, __, __, __, __, __, __, __, __, _0, _0
                db      _0, _0, __, __, __, __, __, __, __, __, __, __, __, __, _0, _0
                db      __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, __
                db      __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, __
                db      __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, __
                db      __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, __

; Bitmaps in ROM

; Sprite null (0) cannot be drawn because of alignment issues. Sprite
; The tag points to the address of the last line, and the last line of the empty
; sprite is 256-aligned so I can get the brick sprites as a LUT

                .align  0x0100
sprite_null:    db      0b00000000
TILE_NULL:      equ     0

                db      0b00000000
                db      0b00000000
                db      0b00000000
sprite_air:     db      0b00000000
TILE_AIR:       equ     1

                db      0b01111100
                db      0b10000010
                db      0b10111110
sprite_br0:     db      0b01111100
TILE_BR0:       equ     2

                db      0b01101100
                db      0b10010010
                db      0b10110110
sprite_br1:     db      0b01101100
TILE_BR1:       equ     3

                db      0b01111100
                db      0b11111110
                db      0b11111110
sprite_br2:     db      0b01111100
TILE_BR2:       equ     4

                .align  0x0100
lut_ball:       db      0b11000000      ; This is a lool up table for ball positions modulo 0 to 6
                db      0b01100000
                db      0b00110000
                db      0b00011000
                db      0b00001100
                db      0b00000110
                db      0b00000011



#data BRICKS_RAM, MAIN_RAM_end

lives:          data    1
level:          data    1
                align   0x0100
tiles:          data    16*8            ; Tiles, or state of the bricks of the level
; Positon in pixels
ball_xy:                                ; ld BC,(ball_xy) will do B<-y, C<-x
ball_x:         data    1
ball_y:         data    1
; Velocity in pixels/frame
ball_vxvy:                              ; ld BC,(ball_vxvy) will do B<-vy, C<-vx
ball_vx:        data    1
ball_vy:        data    1
pad_x:          data    1
; Length in 8px tiles
pad_len:        data    1
; Variables for draw_bricks
_cur_y:         data    1
