/*
 * main.c - NES連射測定プログラム (A/Bボタン対応版)
 * 10秒間（600フレーム）のAまたはBボタン押下回数を測定します。
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

// グローバル変数
static unsigned int press_count;
static unsigned int timer;
static unsigned char last_pad_state;
static char buffer[32];

// メイン関数
void main(void) {
  // 【修正】C89規格に準拠するため、ローカル変数を関数の先頭で宣言
  unsigned char pad;

  // --- 初期化 ---
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
  
  // スタート待ちループ
  while (1) {
    ppu_wait_nmi();
    
    // 【修正】宣言済みの変数に代入する
    pad = pad_poll(0);
    
    if ((pad & (PAD_A | PAD_B)) && !(last_pad_state & (PAD_A | PAD_B))) {
      break;
    }
    last_pad_state = pad;
  }
  
  ppu_off();
  clrscr();
  gotoxy(4, 12);
  cprintf("MEASURING...");
  gotoxy(4, 20);
  cprintf("COUNT: 0");
  ppu_on_all();


  // --- メインゲームループ (10秒間) ---
  while (timer > 0) {
    ppu_wait_nmi();
    timer--;

    // 【修正】宣言済みの変数に代入する
    pad = pad_poll(0);

    if ((pad & (PAD_A | PAD_B)) && !(last_pad_state & (PAD_A | PAD_B))) {
      press_count++;
      
      gotoxy(11, 20);
      sprintf(buffer, "%d", press_count);
      cprintf(buffer);
    }
    
    if (timer % 60 == 0) {
      gotoxy(20, 20);
      sprintf(buffer, "TIME: %d ", timer / 60);
      cprintf(buffer);
    }

    last_pad_state = pad;
  }

  // --- 結果表示 ---
  ppu_off();
  clrscr();
  
  gotoxy(10, 10);
  sprintf(buffer, "FINISH!");
  cprintf(buffer);
  
  gotoxy(8, 14);
  sprintf(buffer, "TOTAL: %d HITS", press_count);
  cprintf(buffer);
  
  gotoxy(5, 16);
  sprintf(buffer, "(%.1f HITS/SECOND)", (float)press_count / 10.0);
  cprintf(buffer);
  
  ppu_on_all();

  // 無限ループで停止
  while (1);
}
