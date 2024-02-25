#code WELCOME_ROM

N_GAMES:        equ     2               ; Max 16 supported

; Init
welcome_start::

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

        call    lcd_wait                ; Write line 1
        ld      A, LCD_BI_DD_ADDR | LCD_DD_ADDR_L1
        out     IO_LCD_W_INSTR, A

        ld      HL, welcome_msg
        call    print

        ld      A, 0                    ; Set first game as selected
        ld      (selected_game), A

        ld      A, 0b11111111           ; Set previous input as no button pressed
        ld      (prev_input), A

        jp      loop


; Keep looping

; Needs C to be unmodified
loop:

        ld      A, (prev_input)         ; Load previous button states in B
        ld      B, A
        in      A, IO_BUT_R             ; Load new states in A and C
        ld      C, A

        xor     B                       ; (old XOR new) AND old will have 1 in new button presses
        and     B
        ld      B, A                    ; Save this result in B

        ld      HL, selected_game       ; Store addr of selected_game in HL
        bit     BUTTON_D, B             ; Handle change of selected game
        call    NZ, next_game
        bit     BUTTON_U, B
        call    NZ, prev_game
        bit     BUTTON_A, B
        call    NZ, start_game

        ld      A, C                    ; Save button states for next frame
        ld      (prev_input), A

        ld      HL, games_names         ; Set HL to games_names + selected_game * 16
        ld      B, 0
        ld      A, (selected_game)
        ld      C, A
        sla     C
        sla     C
        sla     C
        sla     C
        add     HL, BC

        call    lcd_wait                ; Write line 3
        ld      A, LCD_BI_DD_ADDR | LCD_DD_ADDR_L3
        out     IO_LCD_W_INSTR, A

        call    print                   ; Print game name in HL

        halt
        jr      loop


; Args:
; - HL: address of variable selected_game
; Ret:
; Affects:
; - A
next_game:
        inc     (HL)                    ; Increment selected game
        ld      A, (HL)
        cp      N_GAMES                 ; Return if selected_game != N_GAMES
        ret     NZ
        ld      (HL), N_GAMES-1         ; Otherwise set it to N_GAMES-1
        ret


; Args:
; - HL: address of variable selected_game
; Ret:
; Affects:
prev_game:
        dec     (HL)
        ret     P                       ; Return if flag S is not set (result is positive)
        ld      (HL), 0
        ret


; Args:
; Ret:
; Affects:
; - Jumps to game, so it affects everything
start_game:
        ld      HL, games_addrs         ; Set HL to games_addrs + selected_game * 2
        ld      B, 0
        ld      A, (selected_game)
        ld      C, A
        sla     C
        add     HL, BC

        ld      A, (HL)                 ; Load (HL) into HL, can only be done by parts
        inc     HL
        ld      H, (HL)
        ld      L, A
        jp      (HL)                    ; Actual jump


welcome_msg:    defb    "==== z80mgc ====",0
games_names:    defb    " ",16," Snake       ",0    ; Required length: 15 chars + null. 16 is a >
                defb    " ",16," Bricks      ",0

games_addrs:    defw    snake_start
                defw    bricks_start

#data WELCOME_RAM, MAIN_RAM_end

prev_input:     data    1               ; Previous button states
selected_game:  data    1
