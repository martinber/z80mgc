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

        ld      IX, ball_struct         ; Init ball
        ld      (IX+BALL_X), 82
        ld      (IX+BALL_Y), 30
        ld      (IX+BALL_VELY), 100
        ld      (IX+BALL_VELX), 100
        ld      (IX+BALL_DIRX), 0
        ld      (IX+BALL_DIRY), 1

        ld      A, 56                   ; Init pad
        ld      (pad_x), A
        ld      A, 3
        ld      (pad_len), A

        call    draw_bricks             ; Draw bricks

_loop:
        halt
        ld      A, (timer_0)            ; Continue waiting if less than 8 ticks passed
        and     0b00000011
        jr      NZ, _loop

        ld      A, 1
        ld      (debug), A
        call    move_ball_x             ; Move ball
        call    move_ball_y             ; Move ball
        ld      A, 0
        ld      (debug), A

        call    draw_pad                ; Draw pad

        call    draw_ball_v               ; Draw ball
        call    draw_ball_h               ; Draw ball


        ld      IX, pad_x              ; Move ball according to velocity
        inc     (IX+0)               ; Move pad by 1

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
; - IX: Ball struct
; Ret:
; - A: Tile it collided with
; Affects:
; - BC
; - HL
ball_collide:
; I want to end up with tile number in C, which is equal to (X/8 + Y/5 * 16), so I can go directly
; to the tile map
        ld      IX, ball_struct
        ld      C, (IX+BALL_X)              ; Load X position
        bit     0, (IX+BALL_DIRX)           ; If going right, add 1 so we check right edge of ball
        jr      NZ, _ball_collide_div_x
        inc     C

_ball_collide_div_x:
        srl     C                           ; Divide by 8
        srl     C
        srl     C


        ld      A, (IX+BALL_Y)              ; Divide A by 5 by substracting 5 until it becomes
        ld      B, -1                       ; negative. Result will be in B

        bit     0, (IX+BALL_DIRY)           ; If going down, add 1 so we check bottom edge of ball
        jr      NZ, _ball_collide_div_y
        inc     A

_ball_collide_div_y:
        cp      8*5                         ; Skip checking collision if A larger than 8*5, because
        jp      P, _ball_collide_ret_air    ; it means it is too far below to be in (tiles) map

_ball_collide_sub_5:
        inc     B
        sub     A, 5
        jp      P, _ball_collide_sub_5

        ld      A, 0                        ; Skip adding the 16 if B is already 0
        cp      B
        jr      Z, _ball_collide_ld

        ld      A, C                        ; Add 16*B
_ball_collide_add_16:
        add     A, 16
        djnz    _ball_collide_add_16

_ball_collide_ld:
        ld      H, tiles/255                ; Load tile in the position
        ld      L, A
        ld      A, (HL)

        ld      (HL), TILE_AIR              ; Remove brick
        ret

_ball_collide_ret_air:
        ld      A, TILE_AIR
        ret



; Args:
; - Nothing
; Ret:
; - A: 255 if no move, 0 if moved.
; Affects:
; - All
; Moves ball in Y direction if the time says so, checking collisions with blocks and returns which
; movement happened
move_ball_y:
; Check if I have to move in y
        ld      IX, ball_struct             ; Check if velocity + counter overflows which means
        ld      A, (IX+BALL_CNTY)           ; we move the ball this frame
        add     A, (IX+BALL_VELY)
        ld      (IX+BALL_CNTY), A
        ld      A, 255                      ; Leave A as 255 just in case we return A
        ret     NC

        bit     0, (IX+BALL_DIRY)           ; Check if we are going up or down
        jr      Z, _move_ball_y_down        ; Bit not set means we move down

_move_ball_y_up:
        dec     (IX+BALL_Y)                 ; Move down
        call    ball_collide                ; Collide with bricks
        cp      TILE_AIR                    ; Return if there was no colission
        ret     Z
        inc     (IX+BALL_Y)                 ; Revert the going down
        res     0, (IX+BALL_DIRY)           ; Store that ball is going up
        jr      _move_ball_y_down           ; Move up

_move_ball_y_down:
        inc     (IX+BALL_Y)                 ; Move down
        call    ball_collide                ; Collide with bricks
        cp      TILE_AIR                    ; Return if there was no colission
        ret     Z
        dec     (IX+BALL_Y)                 ; Revert the going down
        set     0, (IX+BALL_DIRY)           ; Store that ball is going up
        jr      _move_ball_y_up             ; Move up


; Args:
; - Nothing
; Ret:
; - A: 255 if no move, 0 if moved.
; Affects:
; - All
; Moves ball in X direction if the time says so, checking collisions with blocks and returns which
; movement happened
move_ball_x:
; Check if I have to move in y
        ld      IX, ball_struct             ; Check if velocity + counter overflows which means
        ld      A, (IX+BALL_CNTX)           ; we move the ball this frame
        add     A, (IX+BALL_VELX)
        ld      (IX+BALL_CNTX), A
        ld      A, 255                      ; Leave A as 255 just in case we return A
        ret     NC

        bit     0, (IX+BALL_DIRX)           ; Check if we are going up or down
        jr      Z, _move_ball_x_right       ; Bit not set means we move down

_move_ball_x_left:
        dec     (IX+BALL_X)                 ; Move left
        call    ball_collide                ; Collide with bricks
        cp      TILE_AIR                    ; Return if there was no colission
        ret     Z
        inc     (IX+BALL_X)                 ; Revert the going left
        res     0, (IX+BALL_DIRX)           ; Store that ball is going right
        jr      _move_ball_x_right          ; Move right

_move_ball_x_right:
        inc     (IX+BALL_X)                 ; Move right
        call    ball_collide                ; Collide with bricks
        cp      TILE_AIR                    ; Return if there was no colission
        ret     Z
        dec     (IX+BALL_X)                 ; Revert the going right
        set     0, (IX+BALL_DIRX)           ; Store that ball is going left
        jr      _move_ball_x_left           ; Move left



; Args:
; - Nothing
; Ret:
; - Nothing
; Affects:
; - All
move_ball:
        ld      IX, ball_struct
        bit     0, (IX+BALL_DIRX)
        jr      NZ, _move_ball_left
_move_ball_right:
        inc     (IX+BALL_X)
        jr      _move_ball_vert
_move_ball_left:
        dec     (IX+BALL_X)

_move_ball_vert:
        bit     0, (IX+BALL_DIRY)
        jr      NZ, _move_ball_up
_move_ball_down:
        inc     (IX+BALL_Y)
        ret
_move_ball_up:
        dec     (IX+BALL_Y)
        ret


; Args:
; - B: Byte
; - D: Y address
; - E: X address
; Ret:
; - Nothing
; Affects:
; - A
draw_byte:
        call    lcd_wait
        ld      A, D                        ; Write Y address
        or      LCD_EI_GD_ADDR
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, E                        ; Write X address
        or      LCD_EI_GD_ADDR
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, B                        ; Write sprite line
        out     IO_LCD_W_MEM, A
        ret


; Args:
; - IX: Ball struct
; Ret:
; - Nothing
; Affects:
; - All
draw_ball_h:
        ld      IX, ball_struct
        ld      D, (IX+BALL_Y)
        ld      E, (IX+BALL_X)
        ld      A, 0b00000111               ; A and L will hold the modulo 8 of X position
        and     E
        ld      L, A
        srl     E                           ; E will hold the X in tiles, which is X/8
        srl     E
        srl     E

        cp      7                           ; If X is modulo 7, we have to draw two tiles as below
        jr      Z, _draw_ball_h_wrapped
        cp      0                           ; If X is modulo 0, we might have to clear left tile
        jr      Z, _draw_ball_h_first
        jr      _draw_ball_h_normal         ; Otherwise draw normally the two lines

_draw_ball_h_first:
        bit     0, (IX+BALL_DIRX)           ; Will clear at the left tile only if going right
        jr      NZ, _draw_ball_h_normal
        dec     E                           ; Move left one tile
        ld      B, 0                        ; Draw 0 in DE
        call    draw_byte
        inc     D                           ; Now do it again one line below
        call    draw_byte
        inc     E                           ; Go back right and continue normally
        dec     D

_draw_ball_h_normal:
        ld      H, lut_ball/255             ; Get sprite to draw in LUT, lut_ball is 256-aligned and
                                            ; the offset is already in L

        ld      B, (HL)                     ; Draw sprite in DE
        call    draw_byte
        inc     D                           ; Now do it again one line below
        call    draw_byte

        ld      A, L                        ; If X is modulo 6, we might have to clear right tile
        cp      6
        ret     NZ                          ; Return if X is not modulo 6
        bit     0, (IX+BALL_DIRX)           ; Return if moving right
        ret     Z

        inc     E                           ; Then we move right and clear
        dec     D
        ld      B, 0
        call    draw_byte
        inc     D
        call    draw_byte
        ret

_draw_ball_h_wrapped:
        ld      B, 0b00000001               ; Draw one pixel in the right in DE
        call    draw_byte
        call    lcd_wait
        ld      A, 0b10000000               ; Draw one pixel in the left in the tile in the right
        out     IO_LCD_W_MEM, A
        inc     D                           ; Now do it again one line below
        call    draw_byte
        call    lcd_wait
        ld      A, 0b10000000
        out     IO_LCD_W_MEM, A
        ret


; Args:
; - IX: Ball struct
; Ret:
; - Nothing
; Affects:
; - All
draw_ball_v:
        ld      IX, ball_struct
        ld      D, (IX+BALL_Y)
        ld      E, (IX+BALL_X)
        ld      A, 0b00000111               ; A will hold the modulo 8 of X position
        and     E
        srl     E                           ; E will hold the X in tiles, which is X/8
        srl     E
        srl     E
        cp      7                           ; If X is modulo 7, we have to draw two tiles as below
        jr      Z, _draw_ball_v_wrapped

_draw_ball_v_normal:
        ld      H, lut_ball/255             ; Get sprite to draw in LUT, lut_ball is 256-aligned
        ld      L, A

        bit     0, (IX+BALL_DIRY)           ; If 0, we are going down so we have to clear the
        jr      NZ, _draw_ball_v_normal_2   ; graphics one pixel above, in (y, x) = (D-1, E)
        dec     D
        ld      B, 0
        call    draw_byte
        inc     D

_draw_ball_v_normal_2:
        ld      B, (HL)                     ; Draw sprite in DE
        call    draw_byte
        inc     D                           ; Now do it again one line below
        call    draw_byte

        bit     0, (IX+BALL_DIRY)           ; If 1, we are going up so we have to clear the
        ret     Z                           ; graphics one line below
        inc     D
        ld      B, 0
        call    draw_byte
        ret

_draw_ball_v_wrapped:
        bit     0, (IX+BALL_DIRY)           ; If 0, we are going down so we have to clear the
        jr      NZ, _draw_ball_v_normal_2   ; graphics one pixel above, in (y, x) = (D-1, E)
        dec     D
        ld      B, 0
        call    draw_byte
        call    lcd_wait
        ld      A, 0
        out     IO_LCD_W_MEM, A
        inc     D

_draw_ball_v_wrapped_2:
        ld      B, 0b00000001               ; Draw one pixel in the right in DE
        call    draw_byte
        call    lcd_wait
        ld      A, 0b10000000               ; Draw one pixel in the left in the tile in the right
        out     IO_LCD_W_MEM, A
        inc     D                           ; Now do it again one line below
        call    draw_byte
        call    lcd_wait
        ld      A, 0b10000000
        out     IO_LCD_W_MEM, A

        bit     0, (IX+BALL_DIRY)           ; If 1, we are going up so we have to clear the
        ret     Z                           ; graphics one line below
        inc     D
        ld      B, 0
        call    draw_byte
        call    lcd_wait
        ld      A, 0
        out     IO_LCD_W_MEM, A
        ret


; Args:
; - Nothing
; Ret:
; - Nothing
; Affects:
; - All
draw_pad:
        ld      C, IO_LCD_W_MEM             ; IO device
        ld      IX, sprite_pad              ; Sprite line should be in IX and IX+4 for right edge
        ld      H, 0                        ; Line number

        ld      A, (pad_x)                  ; Get pad_x / 8 in L
        ld      L, A
        srl     L
        srl     L
        srl     L

_draw_pad_line:
        ld      A, (pad_x)                  ; Get pad_x modulo 8 in B
        and     0b00000111
        ld      B, A

        call    lcd_wait
        ld      A, 60                       ; Write Y address
        add     H
        or      LCD_EI_GD_ADDR
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, L                        ; Write X address
        or      LCD_EI_GD_ADDR
        out     IO_LCD_W_INSTR, A

        ld      D, (IX)                     ; Left edge
        ld      E, (IX+4)                   ; Right edge

        ld      A, 0                        ; Skip shifting if B=0
        cp      B
        jr      Z, _draw_pad_shift_end
        xor     A                           ; Clear the third tile, reset carry for rotations below
_draw_pad_shift_loop:
        rr      D                           ; Shift right first tile
        rr      E                           ; Shift right second tile, repeating b7 and carrying b0
        rra                                 ; Shift carry into A for third tile
        djnz    _draw_pad_shift_loop
_draw_pad_shift_end:
        ld      B, A

        call    lcd_wait
        out     (C), D
        call    lcd_wait
        out     (C), E
        call    lcd_wait
        out     (C), B

        inc     IX                          ; Increment pointer to sprite line
        inc     H                           ; Increment counter of lines drawn
        ld      A, 4                        ; Loop if we drew less than 4 lines
        cp      H
        jr      NZ, _draw_pad_line
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

sprite_pad:     db      0b00111111      ; Left edge
                db      0b01111111
                db      0b01100000
                db      0b00111111

                db      0b11111100      ; Right edge
                db      0b11110110
                db      0b00000110
                db      0b11111100

                .align  0x0100
lut_ball:       db      0b11000000      ; This is a look up table for ball positions modulo 0 to 6
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
ball_struct:                            ; Contain several fields accessable with IX
BALL_X:         equ     0
BALL_Y:         equ     1
BALL_VELX:      equ     2
BALL_VELY:      equ     3
BALL_DIRX:      equ     4
BALL_DIRY:      equ     5
BALL_CNTX:      equ     6
BALL_CNTY:      equ     7
; Positon in pixels
ball_xy:                                ; ld BC,(ball_xy) will do B<-y, C<-x
ball_x:         data    1
ball_y:         data    1
; Velocity in pixels/frame/255
ball_vxvy:                              ; ld BC,(ball_vxvy) will do B<-vy, C<-vx
ball_vx:        data    1
ball_vy:        data    1
; Velocity direction 1 means up or right
ball_dxdy:                              ; ld BC,(ball_vxvy) will do B<-vy, C<-vx
ball_dx:        data    1
ball_dy:        data    1
; Move counter, so position is changed when it reaches 255
ball_cxcy:                              ; ld BC,(ball_xy) will do B<-y, C<-x
ball_cx:        data    1
ball_cy:        data    1


pad_x:          data    1
; Length in 8px tiles
pad_len:        data    1
; Variables for draw_bricks
_cur_y:         data    1
