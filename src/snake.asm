#target ROM

#include "z80mgc.asm"

STACK_SIZE:     equ     32 ; in bytes
; Screen size in characters/tiles
FIELD_W:        equ     16
FIELD_H:        equ     8
FIELD_WH:       equ     16*8
; Mask of bits necessary to represent field size
FIELD_W_MASK:   equ     0b00001111
FIELD_H_MASK:   equ     0b00000111
FIELD_WH_MASK:  equ     0b00011111
; Buttom map.
; In the hardware, each one of this bits will be set if the button is pressed and an IN instruction
; is executed
; The number corresponds to the bit that has to be checked with BIT
BUTTON_U:       equ     0 ; 0b00000001, U4
BUTTON_D:       equ     1 ; 0b00000010, Down
BUTTON_L:       equ     2 ; 0b00000100, Left
BUTTON_R:       equ     3 ; 0b00001000, Right
; Possible tile values written to RAM, they are also equal to the the sprite number
TILE_EMPTY:     equ     0x20
TILE_SN_U:      equ     0x01 ; Snake body moving up
TILE_SN_D:      equ     0x02
TILE_SN_L:      equ     0x03
TILE_SN_R:      equ     0x04
TILE_FOOD:      equ     0x05

#code ROM_CODE, 0x0000

start:
reset:
        ld      A, 255
        ld      (prng_seed), A          ; This will be updated each time the prng is run
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

        call    field_clear
; Init snake as two horizontal tiles
        ld      A, 0                    ; Set head and tail positions to 0
        ld      (sn_head_x), A
        ld      (sn_head_y), A
        ld      (sn_tail_x), A
        ld      (sn_tail_y), A
        ld      HL, sn_head_x           ; Move head 4 to the right
        inc     (HL)
        inc     (HL)
        ld      A, TILE_SN_R            ; Write worm to field, pointing right
        ld      BC, 0x00
        ld      A, TILE_SN_R
        call    set_tile
        ld      BC, 0x01
        ld      A, TILE_SN_R
        call    set_tile
        ld      BC, 0x02
        ld      A, TILE_SN_R
        call    set_tile
        call    put_food                ; Put food
        jp      main_loop               ; Start game loop


.org    0x0066
nmi:
        retn


main_loop:
; Read input and set direction
        in      A, IO_BUT_R             ; Load button states in B
        ld      B, A
        bit     BUTTON_U, B             ; Test if button was pressed
        call    NZ, button_up           ; Change dir if button is pressed
        bit     BUTTON_D, B
        call    NZ, button_down
        bit     BUTTON_L, B
        call    NZ, button_left
        bit     BUTTON_R, B
        call    NZ, button_right
_input_end:
; Move head
        ld      BC, (sn_head_xy)        ; Get head direction in A
        call    get_tile
        ld      BC, (sn_head_xy)        ; Move head in that direction
        call    move_bc_rel
        ld      (sn_head_xy), BC
        call    set_tile                ; Set new head tile, A will be the old tile
; Check what the tile was where we put the head
        cp      TILE_EMPTY              ; If tile was empty
        jr      Z, _move_tail           ; Just move the tail normally
        cp      TILE_FOOD               ; If tile wasnt food, it was a part of the snake, then reset
        jp      NZ, reset
        call    put_food             ; If it was food, put food
        jr      _move_tail_end          ; Also dont move the tail, so the snake grows
_move_tail:
; Move tail
        ld      A, TILE_EMPTY           ; Delete tail tile, A will be old tile
        ld      BC, (sn_tail_xy)
        call    set_tile
        ld      BC, (sn_tail_xy)        ; Move tail in that direction
        call    move_bc_rel
        ld      (sn_tail_xy), BC
_move_tail_end:
; Wait for NMI and loop
        halt                            ; Wait for NMI timer
        jr      main_loop


; Start moving in a certain direction
; Args:
; - A: Direction to move, e.g. TILE_SN_D
; Affects:
; - A
; - BC
; - DE
button_up:
        ld      BC, (sn_head_xy)        ; Load head position
        call    get_tile                ; Load tile in head
        cp      TILE_SN_D               ; If we were going down, return
        ret     Z
        ld      A, TILE_SN_U
        ld      BC, (sn_head_xy)        ; Load head position
        call    set_tile                ; Set new head tile, indicates direction
        ret
button_down:
        ld      BC, (sn_head_xy)
        call    get_tile
        cp      TILE_SN_U
        ret     Z
        ld      A, TILE_SN_D
        ld      BC, (sn_head_xy)
        call    set_tile
        ret
button_left:
        ld      BC, (sn_head_xy)
        call    get_tile
        cp      TILE_SN_R
        ret     Z
        ld      A, TILE_SN_L
        ld      BC, (sn_head_xy)
        call    set_tile
        ret
button_right:
        ld      BC, (sn_head_xy)
        call    get_tile
        cp      TILE_SN_L
        ret     Z
        ld      A, TILE_SN_R
        ld      BC, (sn_head_xy)
        call    set_tile
        ret


; Args:
; - None
; Ret:
; - None
; Affects:
; - A
; - BC
; - DE
; - HL
put_food:
        call    random_tile             ; Get random offset from (field) in A
        call    get_tile
        cp      TILE_EMPTY              ; If non empty, retry
        jr      NZ, put_food
        ld      A, TILE_FOOD            ; Place food in tile
        call    set_tile
        ret


; Args:
; - A: Value
; - B: Y position
; - C: X position
; Ret:
; - A: Old value (the previous value in memory)
; Affects:
; - A
; - BC
; - DE
; - HL
; - tmp_a
; Will calculate A <- (field + x + y * FIELD_W)
set_tile:
        push    AF                      ; Store arguments
        push    BC

        ld      DE, BC                  ; Will hold GRAM coordinates
        sla     D                       ; Multiply Y by 8 because it should be in px
        sla     D
        sla     D
        set     7, D                    ; Equivalent to do OR with LCD_EI_GD_ADDR
        set     7, E                    ; Equivalent to do OR with LCD_EI_GD_ADDR

        ld      HL, sprite_0            ; Set sprite address to start of sprites data
        ld      B, 0                    ; Load sprite number in BC
        ld      C, A
        sla     C                       ; Multiply C by 8 because it is the sprite height in memory
        sla     C
        sla     C
        add     HL, BC                  ; Add offset of sprite

        ld      B, 8                    ; Set sprite height
        call    lcd_disp_sprite

        pop     BC                      ; Restore arguments
        pop     AF

_set_tile_ram:
        ld      HL, field               ; Set HL to start of field
        ld      D, 0                    ; Put X in DE and add
        ld      E, C
        add     HL, DE
        ld      C, A                    ; Save value to store in C
        ld      A, B                    ; Jump if Y pos is zero
        or      A
        jp      Z, _set_tile_value
        ld      DE, FIELD_W
_set_tile_loop:
        add     HL, DE                  ; Add FIELD_W for each Y, decrementing B each time (Y pos)
        djnz    _set_tile_loop
_set_tile_value:
        ld      A, (HL)                 ; Return old value in A for convenience
        ld      (HL), C                 ; Set new value
        ret


; Args:
; - B: Y position
; - C: X position
; Ret:
; - A: Tile value
; - B: Y position
; - C: X position
; Affects:
; - A
; - DE
; - HL
; Will calculate A <- field + (sn_head_x) + (sn_head_y) * FIELD_W
get_tile:
        ld      HL, field               ; Set HL to start of field
        ld      D, 0                    ; Put X in DE and add
        ld      E, C
        add     HL, DE
        ld      A, B                    ; Jump if Y pos is zero
        or      A
        jp      Z, _get_tile_value
        ld      DE, FIELD_W
_get_tile_loop:
        add     HL, DE                  ; Add FIELD_W for each Y, decrementing B each time (Y pos)
        djnz    _get_tile_loop
_get_tile_value:
        ld      B, A                    ; Put Y position again in B
        ld      A, (HL)                 ; Read tile into A
        ret


; Args:
; - A: Direction (e.g. TILE_SN_U)
; - B: Y position
; - C: X position
; Ret:
; - A: Unmodified Direction
; - B: New Y position
; - C: New X position
move_bc_rel:
        cp      TILE_SN_U
        jr      Z, _move_bc_rel_up
        cp      TILE_SN_D
        jr      Z, _move_bc_rel_down
        cp      TILE_SN_L
        jr      Z, _move_bc_rel_left
        cp      TILE_SN_R
        jr      Z, _move_bc_rel_right
        halt                            ; Invalid direction
_move_bc_rel_up:
        dec     B                       ; Decrement
        ret     P                       ; Return if still positive
        ld      B, FIELD_H-1            ; Wrap if it became negative
        ret
_move_bc_rel_left:
        dec     C                       ; Decrement
        ret     P                       ; Return if still positive
        ld      C, FIELD_W-1            ; Wrap if it became negative
        ret
_move_bc_rel_down:
        inc     B                       ; Increment
        ld      A, B                    ; Jump if we need to wrap
        cp      FIELD_H
        jp      Z, _move_bc_rel_down_wrap
        ld      A, TILE_SN_D            ; Otherwise, set again A for convenience and return
        ret
_move_bc_rel_down_wrap:
        ld      B, 0                    ; Set to zero
        ld      A, TILE_SN_D            ; Set again A for convenience
        ret
_move_bc_rel_right:
        inc     C
        ld      A, C                    ; Jump if we need to wrap
        cp      FIELD_W
        jp      Z, _move_bc_rel_right_wrap
        ld      A, TILE_SN_R            ; Otherwise, set again A for convenience and return
        ret
_move_bc_rel_right_wrap:
        ld      C, 0                    ; Set to zero
        ld      A, TILE_SN_R            ; Set again A for convenience
        ret


; Args:
; - None
; Ret:
; - None
; TODO: clear screen too
field_clear:
        ld      HL, field               ; Init HL to memory location
        ld      A, 0                    ; Init count to 0
_field_clear_loop:
        cp      FIELD_W*FIELD_H             ; Return if A reached end
        ret     Z
        ld      (HL), TILE_EMPTY        ; Clear memory address
        inc     HL                      ; Go to next tile
        inc     A                       ; Count
        jr      _field_clear_loop       ; Loop



; Args:
; - None
; Ret:
; - A: Random number from 0 to 255
; Affects:
; - DE
; Modified from https://philpem.me.uk/leeedavison/z80/prng/index.html
; Looks at tail position to add randomness
; Adds the position of tail, so the player input will have an effect in the number
; TODO: Must avoid making the seed become zero
random_byte:
        ld      A, (prng_seed)          ; Get previous result
        and     0xB8                    ; Mask non feedback bits
        scf                             ; Set carry
        jp      PO, _random_byte_no_clr ; Skip clear if odd
        ccf                             ; Complement carry (clear it)
_random_byte_no_clr:
        ld      A, (prng_seed)          ; Get seed back
_random_byte_mod:
        ; ld      DE, (sn_tail_xy)        ; Load tail coordinates and add them
        ; add     D
        ; add     E
        ; jr      Z, _random_byte_mod
        rl      A                       ; Rotate carry into byte
        ld      (prng_seed), A          ; Save back for next run
        ret

        ; add     42                      ; Add something just in case seed and coords are zero
        ; or      A                       ; If zero, do again


; Args:
; - None
; Ret:
; - B: Y position
; - C: X position
; Affects:
; - A
; - DE
; For now, a byte is enough, but if the field were bigger I should make this 16-bit
random_tile:
_random_tile_x:
        call    random_byte             ; Get random byte in A for X position
        and     FIELD_W_MASK            ; Mask bits as a first approximation to shorten the value
        cp      FIELD_W                 ; Check if smaller than max
        jr      C, _random_tile_x_found ; If smaller than max
        sub     FIELD_W                 ; Else substract size
_random_tile_x_found:
        ld      C, A                    ; Store position
_random_tile_y:
        call    random_byte             ; Same for Y
        and     FIELD_H_MASK
        cp      FIELD_H
        jr      C, _random_tile_y_found
        sub     FIELD_W
        call    random_byte
_random_tile_y_found:
        ld      B, A                    ; Store position
        ret


; Args:
; - None
; Ret:
; - None
; Affects:
; - A
lcd_wait:
        in      A, IO_LCD_R_INSTR
        bit     7, A
        jr      NZ, lcd_wait
        ret


; Args:
; - None
; Ret:
; - None
; Affects:
; - A
; - B
; - E
lcd_clr_graphics:
        ld      E, 63                   ; Set Y of last line to clear
_lcd_clr_graphics_v:
        ld      B, 16                   ; Set counter for X position
        call    lcd_wait
        ld      A, E                    ; Set Y coordinate to E
        or      A, LCD_EI_GD_ADDR
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, LCD_EI_GD_ADDR | 0   ; Set X coordinate to zero
        out     IO_LCD_W_INSTR, A
_lcd_clr_graphics_h:
        call    lcd_wait
        ld      A, 0                    ; Set data to write
        out     IO_LCD_W_MEM, A         ; Write data. LCD increments X position
        djnz    _lcd_clr_graphics_h     ; Decrement X and jump if not zero
        dec     E                       ; Decrement Y and jump if still positive
        jp      P, _lcd_clr_graphics_v
        ret


; Args:
; - B: Sprite height
; - D: Y position of bottom of sprite already in OR with LCD_EI_GD_ADDR (in px from top of LCD)
; - E: X position already in OR with LCD_EI_GD_ADDR (in tiles of 8px)
; - HL: Address of end of sprite data
; Ret:
; - D: Unchanged
; - E: Unchanged
; Affects:
; - A
; - B
; - C
; - HL
; Expects LCD already in extended instruction mode
lcd_disp_sprite:
        ; ld      D, LCD_EI_GD_ADDR | 1       ; X
        ; ld      E, LCD_EI_GD_ADDR | (10+8)  ; Y
        ld      C, IO_LCD_W_MEM             ; IO device
        ; ld      B, 8                        ; Amount of bytes to write
        ; ld      HL, sprite                  ; Start of data
_lcd_disp_sprite_loop:
        call    lcd_wait
        ld      A, D                        ; Set Y address
        add     B
        dec     A
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, E                        ; Set X address
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        outd                                ; Send to IO dev C, contents of (HL), decrement HL and B
        jr      NZ, _lcd_disp_sprite_loop
        ret


; Bitmaps in ROM

; Sprite 0 is always empty. The tag points to the address of the last line
                db      0b00000000
                db      0b00000000
                db      0b00000000
                db      0b00000000
                db      0b00000000
                db      0b00000000
                db      0b00000000
sprite_0:       db      0b00000000

; TILE_SN_U
                db      0b01111110
                db      0b11111111
                db      0b11110111
                db      0b01111111
                db      0b11111110
                db      0b11101111
                db      0b11111111
                db      0b01111110
; TILE_SN_D
                db      0b01111110
                db      0b11111111
                db      0b11110111
                db      0b01111111
                db      0b11111110
                db      0b11101111
                db      0b11111111
                db      0b01111110
; TILE_SN_L
                db      0b01110110
                db      0b11111111
                db      0b11111111
                db      0b11011111
                db      0b11111011
                db      0b11111111
                db      0b11111111
                db      0b01101110
; TILE_SN_R
                db      0b01110110
                db      0b11111111
                db      0b11111111
                db      0b11011111
                db      0b11111011
                db      0b11111111
                db      0b11111111
                db      0b01101110
; TILE_FOOD
                db      0b00000000
                db      0b00111100
                db      0b01101110
                db      0b01111110
                db      0b01111110
                db      0b01111110
                db      0b00111100
                db      0b00000000

#data RAM_DATA, 0x8000

field:          data    FIELD_W*FIELD_H
sn_head_xy:                             ; ld BC,(sn_head_xy) will do B<-y, C<-x
sn_head_x:      data    1
sn_head_y:      data    1
sn_tail_xy:
sn_tail_x:      data    1
sn_tail_y:      data    1
prng_seed:      data    1               ; Has to be set non-zero on startup
tmp_a:          data    1
tmp_b:          data    1
tmp_c:          data    1
tmp_d:          data    1
tmp_e:          data    1
stack:          data    STACK_SIZE
