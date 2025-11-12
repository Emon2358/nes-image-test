/*
 * main.c - NES Rapid Fire Measurement (A/B)
 * Measures A or B button presses over 10 seconds (600 frames).
 * Fixed version: Replaced floating point operations.
 */

#include <nes.h>
#include <conio.h>
#include <stdio.h>

#define GAME_DURATION_FRAMES (60 * 10)

const unsigned char palette[16] = {
  0x0f, 0x00, 0x16, 0x12,
  0x0f, 0x0f, 0x0f, 0x0f,
  0x0f, 0x0f, 0x0f, 0x0f,
  0x0f, 0x0f, 0x0f, 0x0f
};

// Global variables
static unsigned int press_count;
static unsigned int timer;
static unsigned char last_pad_state;
static char buffer[32];

void main(void) {
  // Local variable (C89 style: declare at top)
  unsigned char pad;

  // --- Initialization ---
  ppu_off();
  pal_bg(palette);
  clrscr();

  gotoxy(8, 8);
  cprintf("RENSHA MEASUREMENT");
  gotoxy(4, 12);
  cprintf("PRESS A OR B BUTTON START!");
  gotoxy(4, 20);
  cprintf("COUNT: 0");
  gotoxy(20, 20);
  cprintf("TIME: 10");

  ppu_on_all();

  press_count = 0;
  timer = GAME_DURATION_FRAMES;
  last_pad_state = 0;
  
  // --- Wait for Start Loop ---
  while (1) {
    ppu_wait_nmi();
    pad = pad_poll(0);
    
    if ((pad & (PAD_A | PAD_B)) && !(last_pad_state & (PAD_A | PAD_B))) {
      break;
    }
    last_pad_state = pad;
  }
  
  // Clear screen for measurement
  ppu_off();
  clrscr();
  gotoxy(4, 12);
  cprintf("MEASURING...");
  gotoxy(4, 20);
  cprintf("COUNT: 0");
  ppu_on_all();

  // --- Main Game Loop (10 seconds) ---
  while (timer > 0) {
    ppu_wait_nmi();
    timer--;
    pad = pad_poll(0);

    // Check for edge trigger (A or B)
    if ((pad & (PAD_A | PAD_B)) && !(last_pad_state & (PAD_A | PAD_B))) {
      press_count++;
      
      gotoxy(11, 20);
      sprintf(buffer, "%d", press_count);
      cprintf(buffer);
    }
    
    // Update timer display every second
    if (timer % 60 == 0) {
      gotoxy(20, 20);
      sprintf(buffer, "TIME: %d ", timer / 60);
      cprintf(buffer);
    }

    last_pad_state = pad;
  }

  // --- Result Display ---
  ppu_off();
  clrscr();
  
  gotoxy(10, 10);
  sprintf(buffer, "FINISH!");
  cprintf(buffer);
  
  gotoxy(8, 14);
  sprintf(buffer, "TOTAL: %d HITS", press_count);
  cprintf(buffer);
  
  // Display HPS (Hits Per Second) using integer math
  gotoxy(5, 16);
  {
    // e.g., if press_count = 163
    unsigned int hps_integer = press_count / 10; // 16
    unsigned int hps_fraction = press_count % 10; // 3
    
    // Create string " (16.3 HITS/SECOND)"
    sprintf(buffer, "(%d.%d HITS/SECOND)", hps_integer, hps_fraction);
    cprintf(buffer);
  }
  
  ppu_on_all();

  // Infinite loop
  while (1);
}
