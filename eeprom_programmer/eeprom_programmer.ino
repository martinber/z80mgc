// Taken from https://github.com/beneater/eeprom-programmer
//
// Copyright (c) 2017-2023 Ben Eater, Martin Bernardi
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.


#include "incbin.h"
#include <CRC32.h>

#define EEPROM_SIZE 8192

INCBIN(Bin, "/home/mbernardi/documents/repos/other/z80mgc/out/main.bin");
// INCBIN(Bin, "/home/mbernardi/desktop/zero");
// INCBIN will create these global variables:
//  const unsigned char gBinData[];              // Pointer to the data
//  const unsigned char *const gBinEnd;          // Pointer to the end of the data
//  const unsigned int gBinSize;                 // Size of the data in bytes

#define OUTPUT_EN A0
#define WRITE_EN 10
#define DISABLED 9 // Tied to VCC in circuit
#define SHIFT_DATA 6 // SER
#define SHIFT_LATCH 7 // RCLK
#define SHIFT_CLK 8 // SRCLK

const byte EEPROM_DATA[] = { // Pins connected to D0, D1, D2, etc.
  2,
  3,
  4,
  A5,
  A4,
  A3,
  A2,
  A1,
};

const int ADDR_ORDER[] = { // Order in which address bits should enter the shift register
  1 << 3,  // QH -> A3
  1 << 2,  // QG -> A2
  1 << 1,  // QF -> A1
  1 << 0,  // QE -> A0
  1 << 9,  // QD -> A9
  1 << 11, // QC -> A11
  1 << 10, // QB -> A10
  0,       // QA -> Not connected 

  1 << 14, // QH -> A14 (normally not available in EEPROM)
  1 << 8,  // QG -> A8
  1 << 13, // QF -> A13 (if jumper is connected)
  1 << 12, // QE -> A12
  1 << 7,  // QD -> A7
  1 << 6,  // QC -> A6
  1 << 5,  // QB -> A5
  1 << 4,  // QA -> A4
};

CRC32 WRITE_CRC;
CRC32 READ_CRC;

/*
 * Output the address bits and outputEnable signal using shift registers.
 */
void setAddress(int address) {

  for (int i = 0; i < 16; i++) {
    digitalWrite(SHIFT_DATA, (address & ADDR_ORDER[i]) != 0);
    digitalWrite(SHIFT_CLK, HIGH);
    digitalWrite(SHIFT_CLK, LOW);
  }

  digitalWrite(SHIFT_LATCH, LOW);
  digitalWrite(SHIFT_LATCH, HIGH);
  digitalWrite(SHIFT_LATCH, LOW);
}


/*
 * Read a byte from the EEPROM at the specified address.
 */
byte readEEPROM(int address) {
  for (int i = 0; i < 8; i++) {
    pinMode(EEPROM_DATA[i], INPUT);
  }
  setAddress(address);
  digitalWrite(OUTPUT_EN, LOW); // Enable out

  byte data = 0;
  for (int i = 7; i >= 0; i--) {
    data = (data << 1) + digitalRead(EEPROM_DATA[i]);
  }
  return data;
}


/*
 * Write a byte to the EEPROM at the specified address.
 */
void writeEEPROM(int address, byte data) {
  setAddress(address);
  digitalWrite(OUTPUT_EN, HIGH); // Disable out
  for (int i = 0; i < 8; i++) {
    pinMode(EEPROM_DATA[i], OUTPUT);
  }

  for (int i = 0; i < 8; i++) {
     digitalWrite(EEPROM_DATA[i], data & 1);
     data = data >> 1;
  }

  digitalWrite(WRITE_EN, LOW);
  delayMicroseconds(1);
  digitalWrite(WRITE_EN, HIGH);
  delay(10);
}


/*
 * Read the contents of the EEPROM and print them to the serial monitor.
 */
void printContents() {
  for (int base = 0; base < EEPROM_SIZE; base += 16) {
    byte data[16];
    for (int offset = 0; offset <= 15; offset += 1) {
      data[offset] = readEEPROM(base + offset);
      if (base + offset < gBinSize) {
        READ_CRC.update(data[offset]);
      }
    }

    char buf[80];
    sprintf(buf, "%03x:  %02x %02x %02x %02x %02x %02x %02x %02x   %02x %02x %02x %02x %02x %02x %02x %02x",
            base, data[0], data[1], data[2], data[3], data[4], data[5], data[6], data[7],
            data[8], data[9], data[10], data[11], data[12], data[13], data[14], data[15]);

    Serial.println(buf);
  }
}


void setup() {
  pinMode(SHIFT_DATA, OUTPUT);
  pinMode(SHIFT_CLK, OUTPUT);
  pinMode(SHIFT_LATCH, OUTPUT);
  pinMode(DISABLED, INPUT);
  for (int i = 0; i < 8; i++) {
    pinMode(EEPROM_DATA[i], INPUT);
  }
  digitalWrite(WRITE_EN, HIGH);
  pinMode(WRITE_EN, OUTPUT);
  digitalWrite(OUTPUT_EN, HIGH);
  pinMode(OUTPUT_EN, OUTPUT);
  Serial.begin(57600);

  // Erase entire EEPROM
  Serial.print("Erasing EEPROM");
  for (int address = 0; address < EEPROM_SIZE; address += 1) {
    writeEEPROM(address, 0x00);

    if (address % 64 == 0) {
      Serial.print(".");
    }
  }
  Serial.println(" done");


  // Program data bytes
  Serial.print("Programming EEPROM");
  PGM_P pgm_data = reinterpret_cast<PGM_P>(gBinData);
  for (int address = 0; address < gBinSize; address += 1) {
    byte data = pgm_read_byte(pgm_data++);
    WRITE_CRC.update(data);
    writeEEPROM(address, data);

    if (address % 64 == 0) {
      Serial.print(".");
    }
  }
  
  // Read and print out the contents of the EERPROM
  Serial.println("Reading EEPROM");
  printContents();

  Serial.println("CRC32 of data written:");
  Serial.println(WRITE_CRC.finalize());
  Serial.println("CRC32 of data read back:");
  Serial.println(READ_CRC.finalize());
}


void loop() {
  // put your main code here, to run repeatedly:

}
