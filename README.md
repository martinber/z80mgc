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
- Frogger
- Brick breaker
- Tanks

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

Game timimg
-----------

I don't have a timer chip like the z80 CTC. So I can count in software the amount of NMI.
The interrupt happens at falling edge so there is no problem on leaving it for a long time sending a
NMI signal.

The counter will be 8 bit. The value 255 could be equivalent to approx 2s so in that case I should
call NMI at approx 128Hz.

- The 555, apparently I can reach around 100kHz. So I can give this as NMI.
- I could use binary counters. If I have a clock of 6MHz, after 16 bits of counters I would have
  91.55Hz. I also could give the 8 most significative digits in an input port.

Design ideas
------------

- Leave a clock input so I can drive it slowly clock by clock
- Header for future IO
- Headers to Data, Address and EEPROMs pins so I can write them without taking them out
- Add LEDs to
  - 8 bit bus
  - MREQ
  - IOREQ
  - WR
  - RD
  - NMI
  - 16 bit address
  - ROM1 CE
  - ROM2 CE
  - RAM CE
  - LCD Enable
  - Each IO enable



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

- Composive video with EEPROMs?

I considered adding sound:

- SN76489

Other timer options:

- Z80 CTC
