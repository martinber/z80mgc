#target ROM

STACK_SIZE:     equ     32 ; in bytes
; Screen size in characters/tiles
FIELD_W:        equ     8
FIELD_H:        equ     4
FIELD_WH:       equ     8*4
; Mask of bits necessary to represent field size
FIELD_W_MASK:   equ     0b00000111
FIELD_H_MASK:   equ     0b00000011
FIELD_WH_MASK:  equ     0b00001111
; Buttom map.
; In the hardware, each one of this bits will be set if the button is pressed and an IN instruction
; is executed
; The number corresponds to the bit that has to be checked with BIT
BUTTON_U:       equ     0 ; 0b00000001, U4
BUTTON_D:       equ     1 ; 0b00000010, Down
BUTTON_L:       equ     2 ; 0b00000100, Left
BUTTON_R:       equ     3 ; 0b00001000, Right
; Possible tile values written to RAM, they are also the characters show on the LCD
TILE_EMPTY:     equ     0x20
TILE_SN_U:      equ     0x5E ; Snake body moving up
TILE_SN_D:      equ     0x76
TILE_SN_L:      equ     0x3C
TILE_SN_R:      equ     0x3E
TILE_FOOD:      equ     0x02


; IO addresses. Bits: (b7,b6,b5) = port, b1 = RW (read), b0: DI (memory)
IO_BUT_R:           equ     0x00;
IO_LCD_W_INSTR:     equ     0b10000000
IO_LCD_R_INSTR:     equ     0b10000010
IO_LCD_W_MEM:       equ     0b10000001
IO_LCD_R_MEM:       equ     0b10000011

; LCD basic instructions
LCD_BI_CLR:         equ     0b00000001 ; Clear
LCD_BI_HOME:        equ     0b00000010 ; Move address counter to 0
LCD_BI_DIR_L:       equ     0b00000100 ; Change text direction to left
LCD_BI_DIR_R:       equ     0b00000110 ; Change text direction to right
LCD_BI_DIR_L_SH:    equ     0b00000101 ; Change text direction to left w/shift
LCD_BI_DIR_R_SH:    equ     0b00000111 ; Change text direction to right w/shift
LCD_BI_OFF:         equ     0b00001000 ; Turn off display, cursor and blink
LCD_BI_ON:          equ     0b00001100 ; Turn on display without cursor
LCD_BI_ON_CUR:      equ     0b00001110 ; Turn on display with cursor
LCD_BI_ON_CUR_BL:   equ     0b00001111 ; Turn on display with cursor and blink
LCD_BI_MV_L:        equ     0b00010000 ; Move cursor left
LCD_BI_MV_R:        equ     0b00010100 ; Move cursor right
LCD_BI_MV_L_SH:     equ     0b00011000 ; Move cursor left and shift
LCD_BI_MV_R_SH:     equ     0b00011100 ; Move cursor right and shift
LCD_BI_SET_8_E:     equ     0b00110100 ; Set 8 bit extended mode
LCD_BI_SET_8_B:     equ     0b00110000 ; Set 8 bit basic mode
LCD_BI_SET_4_E:     equ     0b00100100 ; Set 4 bit extended mode
LCD_BI_SET_4_B:     equ     0b00100000 ; Set 4 bit basic mode
LCD_BI_CG_ADDR:     equ     0b01000000 ; Set CGRAM address, should OR the address. Should use
                                       ; LCD_EI_ADDR if LCD_EI_VSCR was set
LCD_BI_DD_ADDR:     equ     0b10000000 ; Set DDRAM address, should OR the address

; LCD extended instructions
LCD_EI_STANDBY:     equ     0b00000001 ; Clear
LCD_EI_ADDR:        equ     0b00000010 ; RAM address set mode (!SR). Use LCD_BI_CG_ADDR after
LCD_EI_VSCR:        equ     0b00000011 ; Vertical scroll position (SR) mode. Use LCD_EI_VSCR_A after
LCD_EI_REV_1:       equ     0b00000100 ; Reverse line 1
LCD_EI_REV_2:       equ     0b00000101 ; Reverse line 2
LCD_EI_REV_3:       equ     0b00000110 ; Reverse line 3
LCD_EI_REV_4:       equ     0b00000111 ; Reverse line 4
LCD_EI_SET_8_E:     equ     0b00110100 ; Set 8 bit extended mode
LCD_EI_SET_8_B:     equ     0b00110000 ; Set 8 bit basic mode
LCD_EI_SET_4_E:     equ     0b00100100 ; Set 4 bit extended mode
LCD_EI_SET_4_B:     equ     0b00100000 ; Set 4 bit basic mode
LCD_EI_SET_8_E_G:   equ     0b00110110 ; Set 8 bit extended mode with graphics
LCD_EI_SET_8_B_G:   equ     0b00110010 ; Set 8 bit basic mode with graphics
LCD_EI_SET_4_E_G:   equ     0b00100110 ; Set 4 bit extended mode with graphics
LCD_EI_SET_4_B_G:   equ     0b00100010 ; Set 4 bit basic mode with graphics

LCD_EI_VSCR_A:      equ     0b01000000 ; Set vertical scroll address, should OR the address
                                       ; Should set LCD_EI_VSCR first, otherwise it will modify
                                       ; unexisting IRAM?
LCD_EI_GD_ADDR:     equ     0b10000000 ; Set GDRAM address, should OR the address and call twice

; Constants
LCD_DD_ADDR_L1:     equ     0x00       ; First line DDRAM address
LCD_DD_ADDR_L2:     equ     0x10       ; Second line DDRAM address
LCD_DD_ADDR_L3:     equ     0x08       ; Third line DDRAM address
LCD_DD_ADDR_L4:     equ     0x18       ; Fourth line DDRAM address

; When using second scroll bank for double buffering, first line is at 0x20 instead of 0x00
LCD_DD_ADDR_B2:     equ     0x20


#code ROM_CODE, 0x0000

start:
reset:
        ld      A, 255
        ld      (prng_seed), A          ; This will be updated each time the prng is run
        ld      SP, stack+STACK_SIZE
        ld      A, LCD_BI_SET_8_B
        out     IO_LCD_W_INSTR, A
        ld      A, LCD_BI_CLR
        out     IO_LCD_W_INSTR, A
        ld      A, LCD_BI_ON
        out     IO_LCD_W_INSTR, A
        ld      A, LCD_BI_DD_ADDR | LCD_DD_ADDR_L1
        out     IO_LCD_W_INSTR, A
        ld      A, 'H'
        out     IO_LCD_W_MEM, A
        ld      A, 'i'
        out     IO_LCD_W_MEM, A
        ld      A, '!'
        out     IO_LCD_W_MEM, A
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
input_end:
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
; Will calculate A <- (field + x + y * FIELD_W)
set_tile:

        ld      D, A                    ; Store value in D

        ld      A, B
        cp      0
        jr      Z, _set_tile_l1
        cp      1
        jr      Z, _set_tile_l2
        cp      2
        jr      Z, _set_tile_l3
        cp      3
        jr      Z, _set_tile_l4
        halt                            ; Invalid line
_set_tile_l1:
        ld      A, LCD_BI_DD_ADDR | LCD_DD_ADDR_L1
        jr      _set_tile_l_end
_set_tile_l2:
        ld      A, LCD_BI_DD_ADDR | LCD_DD_ADDR_L2
        jr      _set_tile_l_end
_set_tile_l3:
        ld      A, LCD_BI_DD_ADDR | LCD_DD_ADDR_L3
        jr      _set_tile_l_end
_set_tile_l4:
        ld      A, LCD_BI_DD_ADDR | LCD_DD_ADDR_L4
        jr      _set_tile_l_end
_set_tile_l_end:
        add     A, C
        out     IO_LCD_W_INSTR, A
        ld      A, D
        out     IO_LCD_W_MEM, A
        ld      A, D
        out     IO_LCD_W_MEM, A
        ld      A, D                    ; Restore value in A

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
random_byte:
        ld      A, (prng_seed)          ; Get previous result
        and     0xB8                    ; Mask non feedback bits
        scf                             ; Set carry
        jp      PO, _random_byte_no_clr ; Skip clear if odd
        ccf                             ; Complement carry (clear it)
_random_byte_no_clr:
        ld      A, (prng_seed)          ; Get seed back
; TODO: Add influence of position of tail, being careful that the rng never becomes zero
        ; ld      DE, (sn_tail_xy)        ; Load tail coordinates and add them
        ; add     D
        ; add     E
        rl      A                       ; Rotate carry into byte
        ld      (prng_seed), A          ; Save back for next run
        ret


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

; Characters used to display each thing
disp_empty:     ds      ' '
disp_sn_u:      ds      '1'
disp_sn_d:      ds      '1'
disp_sn_l:      ds      '-'
disp_sn_r:      ds      '-'
disp_food:      ds      'O'

#data RAM_DATA, 0x8000

field:          data    FIELD_W*FIELD_H
sn_head_xy:                             ; ld BC,(sn_head_xy) will do B<-y, C<-x
sn_head_x:      data    1
sn_head_y:      data    1
sn_tail_xy:
sn_tail_x:      data    1
sn_tail_y:      data    1
prng_seed:      data    1               ; Has to be set non-zero on startup
stack:          data    STACK_SIZE
