#target ROM

STACK_SIZE:     equ     32 ; in bytes
; Screen size in characters/tiles
FIELD_W:        equ     20
FIELD_H:        equ     4
FIELD_WH:       equ     20*4
; Mask of bits necessary to represend field size
FIELD_W_MASK:   equ     0b00011111
FIELD_H_MASK:   equ     0b00000011
FIELD_WH_MASK:  equ     0b01111111
; Buttom map.
; In the hardware, each one of this bits will be set if the button is pressed and an IN instruction
; is executed
; The number corresponds to the bit that has to be checked with BIT
BUTTON_U:       equ     0 ; 0b00000001, Up
BUTTON_D:       equ     1 ; 0b00000010, Down
BUTTON_L:       equ     2 ; 0b00000100, Left
BUTTON_R:       equ     3 ; 0b00001000, Right
; Possible tile values
TILE_EMPTY:     equ     0x00
TILE_SN_U:      equ     0x01 ; Snake body moving up
TILE_SN_D:      equ     0x02
TILE_SN_L:      equ     0x03
TILE_SN_R:      equ     0x04
TILE_FOOD:      equ     0x05


#code ROM_CODE, 0x0000

start:
        ld      A, 255
        ld      (prng_seed), A          ; This will be updated each time the prng is run
reset:
        ld      SP, stack+STACK_SIZE
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
        inc     (HL)
        inc     (HL)
        ld      A, TILE_SN_R            ; Write worm to field, pointing right
        ld      (field), A
        ld      (field+1), A
        ld      (field+2), A
        ld      (field+3), A
        ld      (field+4), A
        call    put_food                ; Put food
        jp      main_loop               ; Start game loop


.org    0x0066
nmi:
        retn


main_loop:
; Read input and set direction
        in      A, 0                    ; Load button states in B
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
        cp      TILE_EMPTY
        jr      Z, _move_tail           ; Just move the tail normally
        cp      TILE_FOOD
        call    Z, put_food             ; If it was food, put food
        jr      Z, _move_tail_end       ; If it was food, dont move the tail, so the sname grows
        jp      reset                   ; Else it was a part of the snake, then reset the game
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
        ld      HL, field               ; Load field addr in HL and sum A
        ld      B, 0
        ld      C, A
        add     HL, BC
        ld      A, (HL)                 ; Read tile in that position
        cp      TILE_EMPTY              ; If non empty, retry
        jr      NZ, put_food
        ld      (HL), TILE_FOOD         ; Place food in tile
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
; Will calculate A <- field + (sn_head_x) + (sn_head_y) * FIELD_W
set_tile:
        ld      HL, field               ; Set HL to start of field
        ld      D, 0                    ; Put X in DE and add
        ld      E, C
        add     HL, DE
        ld      C, A                    ; Save value to store in C
        ld      A, B                    ; Jump Y pos is zero
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
; Affects:
; - A
; - DE
; - BC
; - HL
; Will calculate A <- field + (sn_head_x) + (sn_head_y) * FIELD_W
get_tile:
        ld      HL, field               ; Set HL to start of field
        ld      D, 0                    ; Put X in DE and add
        ld      E, C
        add     HL, DE
        ld      A, B                    ; Jump Y pos is zero
        or      A
        jp      Z, _get_tile_value
        ld      DE, FIELD_W
_get_tile_loop:
        add     HL, DE                  ; Add FIELD_W for each Y, decrementing B each time (Y pos)
        djnz    _get_tile_loop
_get_tile_value:
        ld      A, (HL)
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
        ld      DE, (sn_tail_xy)        ; Load tail coordinates and add them
        add     D
        add     E
        rl      A                       ; Rotate carry into byte
        ld      (prng_seed), A          ; Save back for next run
        ret


; Args:
; - None
; Ret:
; - A: Random number from 0 to FIELD_W
; Affects:
; - BC
; random_x:
;         call    random_byte             ; Get random byte in A
;         or      FIELD_W_MASK            ; Mask bits as a first approximation to shorten the value
;         cp      FIELD_W                 ; Check if smaller than field width
;         ret     C                       ; If smaller than width, return
;         sub     FIELD_W                 ; Else substract and return
;         ret
; random_y:
;         call    random_byte
;         or      FIELD_H_MASK
;         cp      FIELD_H
;         ret     C
;         sub     FIELD_H
;         ret


; Args:
; - None
; Ret:
; - H: Random number from 0 to FIELD_H
; - L: Random number from 0 to FIELD_W
; Affects:
; - A
; - DE
; random_xy:
;         call    random_byte             ; Get random byte in A
;         and     FIELD_W_MASK            ; Mask bits as a first approximation to shorten the value
;         cp      FIELD_W                 ; Check if smaller than field width
;         jr      C, _random_xy_save_x    ; If smaller than width, continue
;         sub     FIELD_W                 ; Else substract FIELD_H
; _random_xy_save_x:
;         ld      L, A                    ; Save X in L
;         call    random_byte             ; Now same for Y
;         and     FIELD_H_MASK
;         cp      FIELD_H
;         jr      C, _random_xy_save_y
;         sub     FIELD_H
; _random_xy_save_y:
;         ld      H, A                    ; Save Y in H
;         ret


; Args:
; - None
; Ret:
; - A: Offset of tile memory location
; Affects:
; - DE
; For now, a byte is enough, but if the field were bigger I should make this 16-bit
random_tile:
        call    random_byte             ; Get random byte in A
        and     FIELD_WH_MASK           ; Mask bits as a first approximation to shorten the value
        cp      FIELD_WH                ; Check if smaller than field width * height
        ret     C                       ; If smaller than width * height, return
        sub     FIELD_WH                ; Else substract size
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
