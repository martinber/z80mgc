#target ROM

STACK_SIZE:     equ     32 ; in bytes
; Screen size in characters/tiles
SCR_W:          equ     20
SCR_H:          equ     4
; Possible time values
TILE_EMPTY:     equ     0x00
TILE_SN_U:      equ     0x01 ; Snake body moving up
TILE_SN_D:      equ     0x02
TILE_SN_L:      equ     0x03
TILE_SN_R:      equ     0x04
TILE_FOOD:      equ     0x05

#code ROM_CODE, 0x0000

start:
        ld      SP, stack+STACK_SIZE
        call    disp_clear
        ld      A, (0x05)
_start_loop:
        inc     A                       ; Loop if we dont reach 10
        cp      10
        jr      NZ, _start_loop
        halt

disp_clear:
        ld      HL, field               ; Init HL to memory location
        ld      A, 0                    ; Init count to 0
_disp_clear_loop:
        cp      SCR_W*SCR_H             ; Return if A reached end
        ret     Z
        ld      (HL), TILE_EMPTY        ; Clear memory address
        inc     HL                      ; Go to next tile
        inc     A                       ; Count
        jr      _disp_clear_loop        ; Loop

; Characters used to display each thing
disp_empty:     ds      ' '
disp_sn_u:      ds      '1'
disp_sn_d:      ds      '1'
disp_sn_l:      ds      '-'
disp_sn_r:      ds      '-'
disp_food:      ds      'O'

#data RAM_DATA, 0x8000

field:          data    SCR_W*SCR_H
sn_head_x:      data    1
sn_head_y:      data    1
sn_tail_x:      data    1
sn_tail_y:      data    1
stack:          data    STACK_SIZE
