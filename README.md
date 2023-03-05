z80mgc
======

z80 minimal game console

Specs:

- CPU: Z80 CMOS at ???? MHz
- ROM: 16384 bytes (2 x 28C64 EEPROM)
- RAM: 32768 bytes (1 x 71256 RAM)
- Screen: 128x64 px LCD for text and graphics (ST7920 driver)
- Input: 8 buttons, read by polling

Games:

- Snake

Clock speed
-----------

- RAM is 71256 SA25TPG. Therefore is 25ns access time: Data is valid 25ns after OE and CS are set.
- RAM is 28C64 25P. Therefore I think it is 250ns access time: Data is valid 250ns after OE and CS are set.
- CPU is Z84C0006TPG. Therefore is 6.17MHz, equivalent to 166ns per clock. It waits memory for 2
  clock cycles (this time is shortened a bit because of the logic gates I use to select memory).
- LCD takes 1.6ms for clearing and 72 µs (72000ns) for each of the other instructions. So I can do
  around 13800 instructions per second. When writing make the E pulse at least 160ns long (CPU does
  this for around 2 clock cycles) and leave the data for 20ns after disabling (CPU does this for
  around half a clock cycle). When reading, data is valid 260ns after enabled (CPU waits for around
  2 clock cycles)
- Logic gates have around 10ns propagation time.
- The snake game was doing around 150 instructions per game loop. If I consider 4 clocks per
  instruction, I can run it at 60fps if the clock is at around 36kHz?

So apparently I can run at full clock speed, where I would be close to reaching the limit of LCD
read times. I have to wait LCD after each instruction.

Other ideas
-----------

Other display options I considered:

- LCD with HD44780: http://6502.org/mini-projects/optrexlcd/lcd.htm

- LCD with ST7920, allows graphics

- LCD with KS0108, allows graphics

- Nokia 5110

- ILI9163C display

- Something with AD722

- Yamaha V9958, Yamaha V9938, Yamaha V9959, Yamaha V9990, Motorola 6845, Motorola 6847, TMS9918

- Text only OSD chips: MAX7456

- Text only: Intel 8275 CRTC together with Intel 8257 DMA controller

- Composite video: http://www.cpuville.com/Projects/Standalone-Z80-computer/Standalone-Z80-home.html

- Composite video with a microcontroller

- Composite video with ICs: https://www.chrismcovell.com/dottorikun.html#schematic

I considered adding sound:

- SN76489

Other timer options:

- Z80 CTC
