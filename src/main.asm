#target ROM

; Boot code for the console

; This file includes all the other sources and selects the game to start.
; Each game should (assuming the game is named snake):
; - Use #code SNAKE_ROM without address or size
; - Use #data SNAKE_RAM, MAIN_ROM_end so the address is after the reserved space for this main code,
;   and the address is the same as the other games use (we never run 2 games at the same time)
; - Have a global label named snake_start

STACK_SIZE:     equ     32 ; in bytes

#code BOOT_ROM, 0x0000, 0x0066

boot:
        ld      SP, stack+STACK_SIZE    ; Set stack
        jp      snake_start
        ; jp      bricks_start

#code MAIN_NMI, 0x066

nmi:
        retn

#data MAIN_RAM, 0x8000

stack:          data    STACK_SIZE

#include "z80mgc.asm"

#local
#include "snake.asm"
#endlocal

#local
#include "bricks.asm"
#endlocal
