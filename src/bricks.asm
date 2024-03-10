; Screen size in pixels
FIELD_W:        equ     128
FIELD_H:        equ     64

; Can fit 16 bricks horizontally

#code BRICKS_ROM

; Init
bricks_start::
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

        call    clr_fbuf

        ld      BC, 128                 ; Copy 128 bytes of level data to (tiles)
        ld      HL, lvl_1
        ld      DE, tiles
        ldir

        ld      IX, ball_struct         ; Init ball
        ld      (IX+BALL_X), 52
        ld      (IX+BALL_Y), 18
        ld      (IX+BALL_VELY), 30
        ld      (IX+BALL_VELX), 60
        ld      (IX+BALL_DIRX), 1
        ld      (IX+BALL_DIRY), 1

        ld      A, 56                   ; Init pad
        ld      (pad_x), A
        ld      A, 14                   ; 14 instead of 16 because pad has 2 empty pixels in the
        ld      (pad_w), A              ; edges

        call    draw_bricks             ; Draw bricks
        call    disp_fbuf

_loop:
        halt

        ; ld      A, (timer_0)            ; Continue waiting if less than 2 ticks passed
        ; and     0b00000001
        ; jr      NZ, _loop

        call    move_ball_x             ; Move ball and collide with bricks and walls
        call    move_ball_y

        call    pad_collide             ; Collide with pad

        call    move_pad
        call    draw_pad

        ; TODO: Only draw lines with updates
        call    disp_fbuf

        jr      _loop


; Args:
; - Nothing
; Ret:
; - Nothing
; Affects:
; - All
draw_bricks:
        ld      B, tiles/255                ; BC holds tile memory address. Table is 256-aligned, so
        ld      C, 0                        ; B will be high byte of table start address and C will
                                            ; be the offset or actual position of the brick/tile:
                                            ; C = 0bYYYYXXXX
                                            ; To get the Y position I can use C/16 and the remainder
                                            ; is the X position

_draw_bricks_loop_col:
        ld      A, 0                        ; Calculate fbuf address for Y=0 and X=C (C will always
        ld      E, C                        ; have higher bytes corresponding to Y equal to 0)
        call    calc_fbuf_addr              ; Now DE holds address of fbuf. TODO: I think I can
                                            ; optimize this so I don't call calc_fbuf_addr

_draw_bricks_loop:

        ld      A, (BC)                     ; Get tile to draw
        push    BC                          ; And save tile address in stack for later

        cp      A, TILE_AIR                 ; If the tile has nothing, increment fbuf address by 4
        jr      NZ, _draw_bricks_loop_draw  ; and skip drawing
        inc     DE
        inc     DE
        inc     DE
        inc     DE
        jr      _draw_bricks_loop_skip

_draw_bricks_loop_draw:
        ld      H, sprite_air/256           ; Get sprite table start. It is 256-aligned
        sla     A                           ; Multiply the ID by 4 to get the offset of address of
        sla     A                           ; sprite.
        ld      L, A                        ; So now we have address of sprite in HL

        ld      C, 4                        ; Copy sprite, height is 4px
        call    copy_sprite

_draw_bricks_loop_skip:
        inc     DE                          ; Increment fbuf address by one, because bricks are
                                            ; padded 1px each other

        pop     BC                          ; Retrieve tile memory address
        ld      HL, 16                      ; Add 16 to descend a line
        add     HL, BC
        ld      BC, HL

        bit     7, C                        ; Check if we reached C=128 which happens when we reach
                                            ; line 8
        jr      Z, _draw_bricks_loop        ; If we didn't go over last line, loop normally

        ld      A, C                        ; Otherwise, go to start of next column
        inc     A                           ; Move horizontally to the right in tile table
        and     0b00001111                  ; Set Y position in the tile table to 0
        ld      C, A

        jr      NZ, _draw_bricks_loop_col   ; If we didn't go over last column, loop new column
        ret


; Args:
; - IX: Ball struct
; Ret:
; -
; Affects:
; - All
; Keep in mind that pad sprite has an empty pixel on each side, and that the ball position is of the
; bottom left corner
pad_collide:
        ld      IX, ball_struct
        ld      A, (IX+BALL_Y)              ; Load ball_y position
        cp      59                          ; Return if ball is too high
        ret     M
        ld      B, A                        ; Put ball_y in B

        ld      A, (IX+BALL_X)              ; Load ball_x position in C
        ld      C, A

        ld      A, (pad_x)                  ; Put pad_left_x in D
        ld      D, A

        ld      A, (pad_w)                  ; Add pad width to X to obtain pad_right_x in E
        add     D
        ld      E, A

        ld      A, C                        ; If ball_x < pad_left_x, return since ball at left
        sub     D
        ret     M

        ld      A, E                        ; If pad_right_x < ball_x, return since ball at right
        sub     C
        ret     M

        ld      A, (pad_w)                  ; Get middle position of pad: pad_left_x + pad_w/2
        sra     A
        add     D
        sub     C                           ; Substract pad_x to get distance from ball,
                                            ; where -1 means ball is 1px to the
                                            ; right of pad, and +6 means 6px to the left

        ld      C, A                        ; Save in C

        jp      P, _pad_collide_l           ; If result > 0, then colliding with left edge

_pad_collide_r:
        ld      A, 61                       ; Check if Y is too low
        cp      B
        jp      M, _pad_collide_r_low

        ld      (IX+BALL_DIRY), 1           ; Bounce upwards
        dec     (IX+BALL_Y)
        jr      _pad_collide_calc_vx

_pad_collide_r_low:
        ld      (IX+BALL_DIRX), 0           ; Bounce right
        inc     (IX+BALL_X)
        ret

_pad_collide_l:
        ld      A, 61                       ; Check if Y is too low
        cp      B
        jp      M, _pad_collide_l_low
        ld      (IX+BALL_DIRY), 1           ; Bounce upwards
        dec     (IX+BALL_Y)
        jr      _pad_collide_calc_vx

_pad_collide_l_low:
        ld      (IX+BALL_DIRX), 1           ; Bounce left
        dec     (IX+BALL_X)
        ret

_pad_collide_calc_vx:
        ld      A, (IX+BALL_VELX)           ; Load horizontal speed of ball
        bit     0, (IX+BALL_DIRX)           ; Check if negative
        jr      Z, _pad_collide_calc_vx_pos

_pad_collide_calc_vx_neg:
        add     C                           ; Add offset to X speed
        add     C                           ; Add offset to X speed
        add     C                           ; Add offset to X speed
        jp      M, _pad_collide_set_vx_pos  ; Invert if it became negative
        ld      (IX+BALL_VELX), A
        ret

_pad_collide_set_vx_pos:
        neg
        ld      (IX+BALL_VELX), A
        res     0, (IX+BALL_DIRX)
        ret

_pad_collide_calc_vx_pos:
        sub     C                           ; Subtract offset to X speed
        sub     C                           ; Subtract offset to X speed
        sub     C                           ; Subtract offset to X speed
        jp      M, _pad_collide_set_vx_neg  ; Invert if it became negative
        ld      (IX+BALL_VELX), A
        ret

_pad_collide_set_vx_neg:
        neg
        ld      (IX+BALL_VELX), A
        set     0, (IX+BALL_DIRX)
        ret


; Args:
; - IX: Ball struct
; Ret:
; - A: Tile it collided with
; - HL: Tile memory address
; Affects:
; - BC
; The ball has 4 corners (UL, UR, LL, LR). The corners used for collision detection are LL or LR
; depending if the ball is going left or right. Upper corners are not used because the bricks are
; 5px tall but the sprite is 4px tall, so using only LL and LR work out. Another detail is that when
; ball is going direction down-right and we check only LR, it will clip if the collission only
; happens in UR, but since the bricks have no graphics in the bottom part then this cliiping gives
; no problems
; TODO: Should check collission in LR px and if the modulo is 0 then also directly check the tile in
; the left
brick_collide:
; I want to end up with tile number in C, which is equal to (X/8 + Y/5 * 16), so I can go directly
; to the tile map
        ld      IX, ball_struct
        ld      A, (IX+BALL_X)              ; Load X position

        cp      0                           ; Check if too far left
        jp      M, _brick_collide_bound

        cp      127                         ; Check if too far right, 127 instead of 128 because
        jp      P, _brick_collide_bound     ; ball is 2px wide

        ld      C, A                        ; Load X position in C
        bit     0, (IX+BALL_DIRX)           ; If going right, add 1 so we check right edge of ball
        jr      NZ, _brick_collide_div_x
        inc     C

_brick_collide_div_x:
        srl     C                           ; Divide by 8
        srl     C
        srl     C

        ld      A, (IX+BALL_Y)              ; Divide A by 5 by substracting 5 until it becomes
        ld      B, -1                       ; negative. Result will be in B

        cp      0                           ; Check if too far up
        jp      M, _brick_collide_bound

        cp      64                          ; Check if too far down TODO remove
        jp      P, reset

        inc     A                           ; Add 1 so we check bottom edge of ball

_brick_collide_div_y:
        cp      8*5                         ; If A larger than 8*5, return because it is too far
        jp      P, _brick_collide_air       ; below to be in (tiles) map

_brick_collide_sub_5:
        inc     B
        sub     A, 5
        jp      P, _brick_collide_sub_5

        ld      A, 0                        ; Skip adding the 16 if B is already 0, and we will
        cp      B                           ; Calculate C + 16*B in A
        ld      A, C
        jr      Z, _brick_collide_ld
_brick_collide_add_16:
        add     A, 16
        djnz    _brick_collide_add_16

_brick_collide_ld:
        ld      H, tiles/255                ; Load tile in the position
        ld      L, A
        ld      A, (HL)

        ld      (HL), TILE_AIR              ; Remove brick
        ret

_brick_collide_air:
        ld      A, TILE_AIR
        ret

_brick_collide_bound:
        ld      A, 255
        ret


move_pad:
        ld      HL, pad_x                   ; Load pad_x address in HL and pad_x in B
        ld      B, (HL)
        in      A, IO_BUT_R                 ; Load button states in A
        bit     BUTTON_L, A                 ; Move if button was pressed
        jr      Z, _move_pad_left
        bit     BUTTON_R, A
        jr      Z, _move_pad_right
        ret

_move_pad_right:
        ld      A, (pad_w);                 ; Calculate -max_pad_x = -(FIELD_W - pad_x)
        sub     FIELD_W
        add     2
        add     B                           ; Add pad_x and I can move only if result is positive
        ret     P
        inc     (HL)                        ; Move pad and return
        ret

_move_pad_left:
        ld      A, 0                        ; Check if pad_x is bigger than zero
        cp      B
        ret     P
        dec     (HL)                        ; Move pad and return
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
        ld      A, (IX+BALL_VELY)           ; we move the ball this frame
        sla     A                           ; Shift to multiply velocity by 2 and make game faster
        add     A, (IX+BALL_CNTY)
        ld      (IX+BALL_CNTY), A
        ld      A, 255                      ; Leave A as 255 just in case we return A
        ret     NC

        bit     0, (IX+BALL_DIRY)           ; Check if we are going up or down
        jr      Z, _move_ball_y_down        ; Bit not set means we move down

_move_ball_y_up:
        dec     (IX+BALL_Y)                 ; Move up
        call    brick_collide               ; Collide with bricks
        cp      TILE_AIR                    ; Return if there was no colission
        ret     Z
        inc     (IX+BALL_Y)                 ; Revert the going up
        res     0, (IX+BALL_DIRY)           ; Store that ball is going down
        ; call    draw_bricks                 ; TODO: Draw single brick
        jr      _move_ball_y_down           ; Move down

_move_ball_y_down:
        inc     (IX+BALL_Y)                 ; Move down
        call    brick_collide               ; Collide with bricks
        cp      TILE_AIR                    ; Return if there was no colission
        ret     Z
        dec     (IX+BALL_Y)                 ; Revert the going down
        set     0, (IX+BALL_DIRY)           ; Store that ball is going up
        ; call    draw_bricks                 ; TODO: Draw single brick
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
        ld      A, (IX+BALL_VELX)           ; we move the ball this frame
        sla     A                           ; Shift to multiply velocity by 2 and make game faster
        add     A, (IX+BALL_CNTX)
        ld      (IX+BALL_CNTX), A
        ld      A, 255                      ; Leave A as 255 just in case we return A
        ret     NC

        bit     0, (IX+BALL_DIRX)           ; Check if we are going up or down
        jr      Z, _move_ball_x_right       ; Bit not set means we move down

_move_ball_x_left:
        dec     (IX+BALL_X)                 ; Move left
        call    brick_collide               ; Collide with bricks
        cp      TILE_AIR                    ; Return if there was no colission
        ret     Z
        inc     (IX+BALL_X)                 ; Revert the going left
        res     0, (IX+BALL_DIRX)           ; Store that ball is going right
        ; call    draw_bricks
        jr      _move_ball_x_right          ; Move right

_move_ball_x_right:
        inc     (IX+BALL_X)                 ; Move right
        call    brick_collide               ; Collide with bricks
        cp      TILE_AIR                    ; Return if there was no colission
        ret     Z
        dec     (IX+BALL_X)                 ; Revert the going right
        set     0, (IX+BALL_DIRX)           ; Store that ball is going left
        ; call    draw_bricks
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


; ; Args:
; ; - B: Byte
; ; - D: Y address
; ; - E: X address
; ; Ret:
; ; - Nothing
; ; Affects:
; ; - A
; draw_byte:
;         call    lcd_wait
;         ld      A, D                        ; Write Y address
;         or      LCD_EI_GD_ADDR
;         out     IO_LCD_W_INSTR, A
;         call    lcd_wait
;         ld      A, E                        ; Write X address
;         or      LCD_EI_GD_ADDR
;         out     IO_LCD_W_INSTR, A
;         call    lcd_wait
;         ld      A, B                        ; Write sprite line
;         out     IO_LCD_W_MEM, A
;         ret


; ; Args:
; ; - IX: Ball struct
; ; - C: If bit 0 = 0, will draw what is on (HL), which should be sprite_air so nothing is drawn
; ; Ret:
; ; - Nothing
; ; Affects:
; ; - All
; draw_ball:
;
;         ld      IX, ball_struct
;         ld      D, (IX+BALL_Y)
;         ld      E, (IX+BALL_X)
;         ld      A, 0b00000111               ; A will hold the modulo 8 of X position
;         and     E
;
;         bit     0, C                        ; If A is zero, we will draw what (HL) has
;         jr      Z, _draw_ball_get_x
;         ld      H, lut_ball/255             ; In (HL) get line to draw in LUT, lut_ball is
;                                             ; 256-aligned.
;         ld      L, A                        ; Put modulo of X position in A
;
; _draw_ball_get_x:
;         srl     E                           ; E will hold the X in tiles, which is X/8
;         srl     E
;         srl     E
;
;         cp      7                           ; If X is modulo 7, we have to draw two tiles
;         jr      Z, _draw_ball_wrapped
;
; _draw_ball_normal:
;         ld      B, (HL)                     ; Draw sprite in DE
;         call    draw_byte
;         inc     D                           ; Now do it again one line below
;         call    draw_byte
;         ret
;
; _draw_ball_wrapped:
;         ld      B, C                        ; Draw one pixel in the right in DE, or nothing if C=0
;         call    draw_byte
;         call    lcd_wait
;         rrc     C                           ; Draw one pixel in the left in the tile in the right if
;         ld      A, C                        ; C = 1
;         out     IO_LCD_W_MEM, A
;         inc     D                           ; Now do it again one line below
;         call    draw_byte
;         call    lcd_wait
;         ld      A, C
;         out     IO_LCD_W_MEM, A
;         ret


; Args:
; - Nothing
; Ret:
; - Nothing
; Affects:
; - All
draw_pad:
        ld      A, (pad_x)                  ; Get pad_x modulo 8 in B
        and     0b00000111
        ld      B, A

        ld      HL, sprite_pad              ; Get correct shift of left pad sprite
        cp      0
        jr      Z, _draw_pad_shift_end
        ld      DE, 12
_draw_pad_shift:
        add     HL, DE
        djnz    _draw_pad_shift
_draw_pad_shift_end:                        ; Now HL has address of correct left pad sprite

        ld      A, (pad_x)                  ; Get pad_x / 8 in E
        ld      E, A
        srl     E
        srl     E
        srl     E

        ld      A, 60
        call    calc_fbuf_addr              ; Get fbuf address in DE

        ; TODO: I have to add some tiles if the pad is larger than 3 tiles. And the position of the
        ; added tiles is after left pad or middle pad depending if modulo 8 of (pad_x) is bigger
        ; than 4

        ld      C, 4
        call    copy_sprite                 ; Draw left pad sprite

        ld      A, E                        ; Add 60 to fbuf address to go one tile right and 4 up
        add     A, 60                       ; First add 60 to LSB
        ld      E, A
        ld      A, D
        adc     A, 0                        ; And if there was carry, add it to MSB
        ld      D, A

        ld      C, 4
        call    copy_sprite                 ; Draw middle pad sprite

        ld      A, E                        ; Add 60 to fbuf address to go one tile right and 4 up
        add     A, 60
        ld      E, A
        ld      A, D
        adc     A, 0
        ld      D, A

        ld      C, 4
        call    copy_sprite                 ; Draw right pad sprite

        ret



; ; Args:
; ; - Nothing
; ; Ret:
; ; - Nothing
; ; Affects:
; ; - All
; draw_pad:
;         ld      C, IO_LCD_W_MEM             ; IO device
;         ld      IX, sprite_pad              ; Sprite line should be in IX and IX+4 for right edge
;         ld      H, 0                        ; Line number
;
;         ld      A, (pad_x)                  ; Get pad_x / 8 in L
;         ld      L, A
;         srl     L
;         srl     L
;         srl     L
;
; _draw_pad_line:
;         ld      A, (pad_x)                  ; Get pad_x modulo 8 in B
;         and     0b00000111
;         ld      B, A
;
;         call    lcd_wait
;         ld      A, 60                       ; Write Y address
;         add     H
;         or      LCD_EI_GD_ADDR
;         out     IO_LCD_W_INSTR, A
;         call    lcd_wait
;         ld      A, L                        ; Write X address
;         or      LCD_EI_GD_ADDR
;         out     IO_LCD_W_INSTR, A
;
;         ld      D, (IX)                     ; Left edge
;         ld      E, (IX+4)                   ; Right edge
;
;         ld      A, 0                        ; Skip shifting if B=0
;         cp      B
;         jr      Z, _draw_pad_shift_end
;         xor     A                           ; Clear the third tile, reset carry for rotations below
; _draw_pad_shift_loop:
;         rr      D                           ; Shift right first tile
;         rr      E                           ; Shift right second tile, repeating b7 and carrying b0
;         rra                                 ; Shift carry into A for third tile
;         djnz    _draw_pad_shift_loop
; _draw_pad_shift_end:
;         ld      B, A
;
;         call    lcd_wait
;         out     (C), D
;         call    lcd_wait
;         out     (C), E
;         call    lcd_wait
;         out     (C), B
;
;         inc     IX                          ; Increment pointer to sprite line
;         inc     H                           ; Increment counter of lines drawn
;         ld      A, 4                        ; Loop if we drew less than 4 lines
;         cp      H
;         jr      NZ, _draw_pad_line
;         ret


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

lvl_3:          db      _0, _0, _0, _0, _0, _0, _0, _0, _0, _0, _0, _0, _0, _0, _0, _0
                db      _0, __, __, __, __, __, __, __, __, __, __, __, __, __, __, _0
                db      _0, _0, _0, _0, _0, _0, _0, _0, _0, _0, _0, _0, _0, _0, _0, _0
                db      _0, __, __, __, __, __, __, __, __, __, __, __, __, __, __, _0
                db      _0, _0, _0, _0, _0, _0, _0, _0, _0, _0, _0, _0, _0, _0, _0, _0
                db      __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, __
                db      __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, __
                db      __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, __

; Bitmaps in ROM

; Sprite null (0) cannot be drawn because of alignment issues. Sprite
; The tag points to the address of the last line, and the last line of the empty
; sprite is 256-aligned so I can get the brick sprites as a LUT

                .align  0x0100
; sprite_null:    db      0b00000000
; TILE_NULL:      equ     0

TILE_AIR:       equ     0
sprite_air:     db      0b00000000
                db      0b00000000
                db      0b00000000
                db      0b00000000

TILE_BR0:       equ     1
sprite_br0:     db      0b01111100
                db      0b10000010
                db      0b10111110
                db      0b01111100

TILE_BR1:       equ     2
sprite_br1:     db      0b01101100
                db      0b10010010
                db      0b10110110
                db      0b01101100

TILE_BR2:       equ     3
sprite_br2:     db      0b01111100
                db      0b11111110
                db      0b11111110
                db      0b01111100

; sprite_pad:     db      0b00111111      ; Left edge
;                 db      0b01111111
;                 db      0b01100000
;                 db      0b00111111
;
;                 db      0b11111100      ; Right edge
;                 db      0b11110110
;                 db      0b00000110
;                 db      0b11111100

sprite_pad:     db      0b00111111                          ; Left tile
                db      0b01111111
                db      0b01100000
                db      0b00111111
                db                0b11111100                ; Middle tile
                db                0b11110110
                db                0b00000110
                db                0b11111100
                db                          0b00000000      ; Right tile
                db                          0b00000000
                db                          0b00000000
                db                          0b00000000

                db      0b00011111                          ; Now the same for each X offset
                db      0b00111111
                db      0b00110000
                db      0b00011111
                db                0b11111110
                db                0b11111011
                db                0b00000011
                db                0b11111110
                db                          0b00000000
                db                          0b00000000
                db                          0b00000000
                db                          0b00000000

                db      0b00001111
                db      0b00011111
                db      0b00011000
                db      0b00001111
                db                0b11111111
                db                0b11111101
                db                0b00000001
                db                0b11111111
                db                          0b00000000
                db                          0b10000000
                db                          0b10000000
                db                          0b00000000

                db      0b00000111
                db      0b00001111
                db      0b00001100
                db      0b00000111
                db                0b11111111
                db                0b11111110
                db                0b00000000
                db                0b11111111
                db                          0b10000000
                db                          0b11000000
                db                          0b11000000
                db                          0b10000000

                db      0b00000011
                db      0b00000111
                db      0b00000110
                db      0b00000011
                db                0b11111111
                db                0b11111111
                db                0b00000000
                db                0b11111111
                db                          0b11000000
                db                          0b01100000
                db                          0b01100000
                db                          0b11000000

                db      0b00000001
                db      0b00000011
                db      0b00000011
                db      0b00000001
                db                0b11111111
                db                0b11111111
                db                0b00000000
                db                0b11111111
                db                          0b11100000
                db                          0b10110000
                db                          0b00110000
                db                          0b11100000

                db      0b00000000
                db      0b00000001
                db      0b00000001
                db      0b00000000
                db                0b11111111
                db                0b11111111
                db                0b10000000
                db                0b11111111
                db                          0b11110000
                db                          0b11011000
                db                          0b00011000
                db                          0b11110000

                db      0b00000000
                db      0b00000000
                db      0b00000000
                db      0b00000000
                db                0b01111111
                db                0b11111111
                db                0b11000000
                db                0b01111111
                db                          0b11111000
                db                          0b11101100
                db                          0b00001100
                db                          0b11111000

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
; Length in pixels without counting 2 empty pixels of sprite. So two 8px tiles equal to 14px
pad_w:          data    1
; Variables for draw_bricks
_cur_y:         data    1
