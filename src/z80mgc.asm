; Constants and macros specific to the z80mgc hardware

; IO addresses. Connections of each bit are:
; - (b7,b6,b5) selects the device.
; - b1 goes to LCD RW (low for write, high for read)
; - b0 goes to LCD DI (low for instruction, high for memory)
IO_BUT_R:           equ     0b10000000
IO_A:               equ     0b01000000
IO_B:               equ     0b11000000
IO_LCD_W_INSTR:     equ     0b00000000
IO_LCD_R_INSTR:     equ     0b00000010
IO_LCD_W_MEM:       equ     0b00000001
IO_LCD_R_MEM:       equ     0b00000011

; LCD basic instructions
LCD_BI_CLR:         equ     0b00000001  ; Clear
LCD_BI_HOME:        equ     0b00000010  ; Move address counter to 0
LCD_BI_DIR_L:       equ     0b00000100  ; Change text direction to left
LCD_BI_DIR_R:       equ     0b00000110  ; Change text direction to right
LCD_BI_DIR_L_SH:    equ     0b00000101  ; Change text direction to left w/shift
LCD_BI_DIR_R_SH:    equ     0b00000111  ; Change text direction to right w/shift
LCD_BI_OFF:         equ     0b00001000  ; Turn off display, cursor and blink
LCD_BI_ON:          equ     0b00001100  ; Turn on display without cursor
LCD_BI_ON_CUR:      equ     0b00001110  ; Turn on display with cursor
LCD_BI_ON_CUR_BL:   equ     0b00001111  ; Turn on display with cursor and blink
LCD_BI_MV_L:        equ     0b00010000  ; Move cursor left
LCD_BI_MV_R:        equ     0b00010100  ; Move cursor right
LCD_BI_MV_L_SH:     equ     0b00011000  ; Move cursor left and shift
LCD_BI_MV_R_SH:     equ     0b00011100  ; Move cursor right and shift
LCD_BI_SET_8_E:     equ     0b00110100  ; Set 8 bit extended mode
LCD_BI_SET_8_B:     equ     0b00110000  ; Set 8 bit basic mode
LCD_BI_SET_4_E:     equ     0b00100100  ; Set 4 bit extended mode
LCD_BI_SET_4_B:     equ     0b00100000  ; Set 4 bit basic mode
LCD_BI_CG_ADDR:     equ     0b01000000  ; Set CGRAM address, should OR the address. Should use
                                        ; LCD_EI_ADDR if LCD_EI_VSCR was set
LCD_BI_DD_ADDR:     equ     0b10000000  ; Set DDRAM address, should OR the address

; LCD extended instructions
LCD_EI_STANDBY:     equ     0b00000001  ; Clear
LCD_EI_ADDR:        equ     0b00000010  ; RAM address set mode (!SR). Use LCD_BI_CG_ADDR after
LCD_EI_VSCR:        equ     0b00000011  ; Vertical scroll position (SR) mode. Use LCD_EI_VSCR_A after
LCD_EI_REV_1:       equ     0b00000100  ; Reverse line 1
LCD_EI_REV_2:       equ     0b00000101  ; Reverse line 2
LCD_EI_REV_3:       equ     0b00000110  ; Reverse line 3
LCD_EI_REV_4:       equ     0b00000111  ; Reverse line 4
LCD_EI_SET_8_E:     equ     0b00110100  ; Set 8 bit extended mode
LCD_EI_SET_8_B:     equ     0b00110000  ; Set 8 bit basic mode
LCD_EI_SET_4_E:     equ     0b00100100  ; Set 4 bit extended mode
LCD_EI_SET_4_B:     equ     0b00100000  ; Set 4 bit basic mode
LCD_EI_SET_8_E_G:   equ     0b00110110  ; Set 8 bit extended mode with graphics
LCD_EI_SET_8_B_G:   equ     0b00110010  ; Set 8 bit basic mode with graphics
LCD_EI_SET_4_E_G:   equ     0b00100110  ; Set 4 bit extended mode with graphics
LCD_EI_SET_4_B_G:   equ     0b00100010  ; Set 4 bit basic mode with graphics

LCD_EI_VSCR_A:      equ     0b01000000  ; Set vertical scroll address, should OR the address
                                        ; Should set LCD_EI_VSCR first, otherwise it will modify
                                        ; unexisting IRAM?
LCD_EI_GD_ADDR:     equ     0b10000000  ; Set GDRAM address, should OR the address and call twice

; LCD constants
LCD_DD_ADDR_L1:     equ     0x00        ; First line DDRAM address
LCD_DD_ADDR_L2:     equ     0x10        ; Second line DDRAM address
LCD_DD_ADDR_L3:     equ     0x08        ; Third line DDRAM address
LCD_DD_ADDR_L4:     equ     0x18        ; Fourth line DDRAM address

LCD_DD_ADDR_B2:     equ     0x20        ; Offset to second LCD DDRAM buffer.When using second scroll
                                        ; bank for double buffering, first line is at 0x20 instead
                                        ; of 0x00

; Buttom map.
; In the hardware, each one of this bits will be set if the button is pressed and an IN instruction
; is executed
; The number corresponds to the bit that has to be checked with BIT, buttons are 0 when pressed
BUTTON_U:       equ     0 ; 0b00000001, Up
BUTTON_D:       equ     1 ; 0b00000010, Down
BUTTON_L:       equ     2 ; 0b00000100, Left
BUTTON_R:       equ     3 ; 0b00001000, Right
BUTTON_A:       equ     4 ; 0b00010000
BUTTON_B:       equ     5 ; 0b00100000
BUTTON_X:       equ     6 ; 0b01000000
BUTTON_Y:       equ     7 ; 0b10000000

#code Z80MGC_ROM

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
