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
_loop:
        call    draw_bricks
        halt
        jp      _loop


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


draw_bricks:

        ; ld      (_tile_addr_h), tiles/255   ; Tile memory address. Table is 256-aligned, so the high
        ; ld      (_cur_pos), 0               ; byte will be the table start and the low will be the
        ;                                     ; offset or actual position of the brick/tile. To get
        ;                                     ; the Y position I can use (_cur_pos)/16 and the
        ;                                     ; remainder is the X position
        ld      D, tiles/255
        ld      E, 0
        ld      A, 0 | LCD_EI_GD_ADDR       ; Holds Y coordinate in pixels of the bottom of the tile
                                            ; from the top of the screen
        ld      (_cur_y), A

_draw_bricks_loop:

        ld      H, sprite_null/256          ; Get sprite table start (it starts at Y=3 of the
                                            ; sprite, and its 256-aligned)

        ; ld      L, (_tile_addr)             ; Get tile to draw
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

; Increment addresses
        inc     E

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



; Levels in ROM. Each line of bricks is 16 bytes, and there are max 8 lines of 5 px tall

                align   0x0100
lvl_1:          db      1, 1, 1, 0, 0, 2, 2, 0, 0, 2, 2, 0, 0, 1, 1, 1
                db      1, 1, 1, 0, 0, 2, 2, 0, 0, 2, 2, 0, 0, 1, 1, 1
                db      1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1
                db      1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1
                db      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                db      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                db      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                db      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

; Current bricks, its a modifyable copy of the level. Move to RAM

__:             equ     TILE_AIR
_0:             equ     TILE_BR0
_1:             equ     TILE_BR1
                align   0x0100
tiles:          db      _0, _0, _0, __, __, _1, _1, __, __, _1, _1, __, __, _0, _0, _0
                db      _0, _0, _0, __, __, _1, _1, __, __, _1, _1, __, __, _0, _0, _0
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

                db      0b01111110
                db      0b11111111
                db      0b11111111
sprite_br2:     db      0b01111110
TILE_BR2:       equ     4

                db      0b01100000
                db      0b10010000
                db      0b10110000
sprite_ball:    db      0b01100000



#data BRICKS_RAM, MAIN_RAM_end

lives:          data    1
level:          data    1
; Positon in pixels
ball_xy:                                ; ld BC,(ball_xy) will do B<-y, C<-x
ball_x:         data    1
ball_y:         data    1
pad_x:          data    1
; Velocity in pixels/frame
ball_vxvy:                              ; ld BC,(ball_vxvy) will do B<-vy, C<-vx
ball_vx:        data    1
ball_vy:        data    1
; Length in 8px tiles
pad_len:        data    1
; Variables for draw_bricks
_tile_addr:                             ; table is 256-aligned, so _cur_pos will be the offset and I
_cur_pos:         data    1             ; put it directly in the low byte
_tile_addr_h:     data    1
_cur_xy:                                ; ld BC,(_cur_xy) will do B<-y, C<-x
_cur_x:         data    1
_cur_y:         data    1
