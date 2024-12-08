; Constants and macros specific to the z80mgc hardware

; Framebuffer address offsets from fbuf start:
; 0x000 0x040 0x080 0x0C0 0x100 0x140 0x180 0x1C0 0x200 0x240 0x280 0x2C0 0x300 0x340 0x380 0x3C0
; 0x001 0x041 0x081 0x0C1 0x101 0x141 0x181 0x1C1 0x201 0x241 0x281 0x2C1 0x301 0x341 0x381 0x3C1
; 0x002 0x042 0x082 0x0C2 0x102 0x142 0x182 0x1C2 0x202 0x242 0x282 0x2C2 0x302 0x342 0x382 0x3C2
; ...
; 0x01D 0x05D 0x09D 0x0DD 0x11D 0x15D 0x19D 0x1DD 0x21D 0x25D 0x29D 0x2DD 0x31D 0x35D 0x39D 0x3DD
; 0x01E 0x05E 0x09E 0x0DE 0x11E 0x15E 0x19E 0x1DE 0x21E 0x25E 0x29E 0x2DE 0x31E 0x35E 0x39E 0x3DE
; 0x01F 0x05F 0x09F 0x0DF 0x11F 0x15F 0x19F 0x1DF 0x21F 0x25F 0x29F 0x2DF 0x31F 0x35F 0x39F 0x3DF
; 0x020 0x060 0x0A0 0x0E0 0x120 0x160 0x1A0 0x1E0 0x220 0x260 0x2A0 0x2E0 0x320 0x360 0x3A0 0x3E0
; 0x021 0x061 0x0A1 0x0E1 0x121 0x161 0x1A1 0x1E1 0x221 0x261 0x2A1 0x2E1 0x321 0x361 0x3A1 0x3E1
; 0x022 0x062 0x0A2 0x0E2 0x122 0x162 0x1A2 0x1E2 0x222 0x262 0x2A2 0x2E2 0x322 0x362 0x3A2 0x3E2
; ...
; 0x03D 0x07D 0x0BD 0x0FD 0x13D 0x17D 0x1BD 0x1FD 0x23D 0x27D 0x2BD 0x2FD 0x33D 0x37D 0x3BD 0x3FD
; 0x03E 0x07E 0x0BE 0x0FE 0x13E 0x17E 0x1BE 0x1FE 0x23E 0x27E 0x2BE 0x2FE 0x33E 0x37E 0x3BE 0x3FE
; 0x03F 0x07F 0x0BF 0x0FF 0x13F 0x17F 0x1BF 0x1FF 0x23F 0x27F 0x2BF 0x2FF 0x33F 0x37F 0x3BF 0x3FF

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
BUTTON_R:       equ     2 ; 0b00000100, Right
BUTTON_L:       equ     3 ; 0b00001000, Left
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


; Args:
; - C: Sprite height
; - DE: Framebuffer address where sprite should be copied
; - HL: Address of start of sprite data
; Affects:
; - BC
; - HL
; Returns:
; - DE: Framebuffer address of position just below where the sprite was copied
; - HL: Sprite address of position just below where the sprite data was located
; Draws into the framebuffer
copy_sprite:
        ld      B, 0                        ; Because BC will be the counter of bytes to copy
        ldir                                ; Copy (DE) <- (HL) until BC=0
        ret


; Args:
; - A: Y position of top of sprite in px from top of LCD
; - E: X position in tiles of 8px
; Ret:
; - DE: Framebuffer address where sprite should be copied
; Affects:
; - A
calc_fbuf_addr:
        ld      D, 0                        ; DE will point to framebuffer memory which is
                                            ; (fbuf+X*64+Y)

        sla     E                           ; Shift left DE 6 times to multiply X by 64
        sla     E                           ; Since X is at most 15, the first 4 shifts will never
        sla     E                           ; overflow, but the remaining 2 will use the carry to
        sla     E                           ; reach the high byte
        sla     E
        rl      D
        sla     E
        rl      D

        add     A, E                        ; Add Y to X*64 which is on DE
        ld      E, A                        ; See https://plutiedev.com/z80-add-8bit-to-16bit
        adc     A, D
        sub     E
        ld      D, A

        set     7, D                        ; Framebuffer is always at 0x8000, instead of adding
        ret                                 ; 0x8000 to DE I set bit 7 of D


; Args:
; - None
; Ret:
; - None
; Affects:
; - B
; - DE
; - HL
clr_fbuf:
        ld      BC, FBUF_SIZE           ; Amount of bytes to copy
        ld      HL, 0x8000              ; First byte of framebuffer
        ld      DE, 0x8001              ; Second byte of framebuffer
        ld      (HL), 0                 ; Clear fist byte of framebuffer
        ldir                            ; Copy from HL to DE, incrementing and stopping when BC
                                        ; reaches zero


; Args:
; - HL: Address of any byte of the fbuf. The line containing it will be drawn
; Affects:
; - A
; - BC
; - DE
; Returns:
; - HP: Address of next line, with X=0
disp_fbuf_line:
        ld      A, L                    ; Save in A the Y position in px which is L mod 64
        and     0b00111111

        ld      H, 0x80                 ; Framebuffer is always at 0x8000, so set address of HL
        ld      L, A                    ; At X = 0

        ld      B, 0                    ; Transform X and Y coords to LCD coords. B holds X which is
        cp      32                      ; always 0, except when Y > 32 in which case B has to be set
        jp      M, _disp_fbuf_line_jump ; to 8. C holds Y which is always between 0 and 32
        ld      B, 8
_disp_fbuf_line_jump:
        and     0b00011111
        ld      C, A

        ; ld      DE, HL                  ; Save in E the X position in px which is HL // 16
        ; sra     H
        ; srl     L
        ; sra     H
        ; srl     L
        ; srl     L
        ; srl     L

        call    lcd_wait
        ld      A, C                        ; Write Y address
        or      LCD_EI_GD_ADDR
        out     IO_LCD_W_INSTR, A
        call    lcd_wait
        ld      A, B                        ; Write X address
        or      LCD_EI_GD_ADDR
        out     IO_LCD_W_INSTR, A

        ld      DE, 64                      ; Offset between bytes of the same line

        ld      B, 16
_disp_fbuf_line_loop:
        call    lcd_wait                    ; Write 16 bytes until B=0
        ld      A, (HL)
        out     IO_LCD_W_MEM, A
        add     HL, DE                      ; Increment HL by 64 because of fbuf layout
        djnz    _disp_fbuf_line_loop

        ld      BC, -64*16+1                ; Move 1 line down
        add     HL, BC

        ret




; Args:
; - None
; Affects:
; - A
; - BC
; - DE
; - HL
; - IX
; - tmp_a
; Draws the entire framebuffer
disp_fbuf:

        ld      HL, fbuf                    ; Set HL to start of fbuf
        ld      DE, 64                      ; Offset between bytes of the same line

        ld      IX, tmp_a                   ; Store current Y address
        ld      (IX), 0

_disp_fbuf_2_lines:
        call    lcd_wait
        ld      A, (IX)                     ; Write Y address and increment
        or      LCD_EI_GD_ADDR
        out     IO_LCD_W_INSTR, A
        inc     (IX)
        call    lcd_wait
        ld      A, LCD_EI_GD_ADDR           ; Write X address = 0
        out     IO_LCD_W_INSTR, A

        ld      B, 16
_disp_fbuf_loop_even:
        call    lcd_wait                    ; Write 16 bytes until B=0
        ld      A, (HL)
        out     IO_LCD_W_MEM, A
        add     HL, DE                      ; Increment HL by 64 because of fbuf layout
        djnz    _disp_fbuf_loop_even

        ld      BC, -64*16+32               ; Move 32 lines down and continue with the odd line
        add     HL, BC

        ld      B, 16
_disp_fbuf_loop_odd:
        call    lcd_wait                    ; Write 16 bytes until B=0
        ld      A, (HL)
        out     IO_LCD_W_MEM, A
        add     HL, DE                      ; Increment HL by 64 because of fbuf layout
        djnz    _disp_fbuf_loop_odd

        ld      BC, -64*16-31               ; Move 32 lines down and continue with the odd line
        add     HL, BC

        bit     5, (IX)                     ; Check if we reached line 32
        jr      Z, _disp_fbuf_2_lines

        ret
