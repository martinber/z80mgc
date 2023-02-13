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

; Contents of address bus to send commands or read/write LCD memory
; Bits: (b7,b6,b5) = port, b1 = RW (read), b0: DI (memory)
LCD_W_CMD:      equ     0b10000000
LCD_R_CMD:      equ     0b10000010
LCD_W_MEM:      equ     0b10000001
LCD_R_MEM:      equ     0b10000011

; LCD commands. Only sets the first bit, OR should be used to set parameters
LCD_C_CLR:      equ     0b00000001 ; Clear
LCD_C_HOME:     equ     0b00000010 ; Move address counter to 0
LCD_C_DIR:      equ     0b00000100 ; Change text direction or enable screen shift
LCD_C_DISP:     equ     0b00001000 ; Display and cursor on/off
LCD_C_MV:       equ     0b00010000 ; Move cursor and shift display
LCD_C_OPT:      equ     0b00100000 ; Set options
LCD_C_CG_ADDR:  equ     0b01000000 ; Set CGRAM address
LCD_C_DD_ADDR:  equ     0b10000000 ; Set DDRAM address

; LCD parameters
LCD_P_8BIT:     equ     0b00010000 ; Set 8bit mode


#code ROM_CODE, 0x0000

start:
        jp      lcd_init


.org    0x0066
nmi:
        nop
        nop
        jp      lcd_init

lcd_init:
        ld      A, 0x34
        out     LCD_W_CMD, A

        ld      A, 0x0F
        out     LCD_W_CMD, A

        ld      A, 0x66
        out     LCD_W_MEM, A

        ld      A, 0x66
        out     LCD_W_MEM, A

        ld      A, 0x66
        out     LCD_W_MEM, A

        ld      A, 0x40
        out     LCD_W_MEM, A

        ld      A, 0x44
        out     LCD_W_MEM, A

        jp      lcd_init

#data RAM_DATA, 0x8000

ram_test:       data    1
stack:          data    STACK_SIZE
