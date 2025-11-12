/*
 * main.c - NES連射測定プログラム
 * 10秒間（600フレーム）のAボタン押下回数を測定します。
 */

#include <nes.h>    // NES固有の関数やマクロ（PPU制御、パッド読み取りなど）
#include <conio.h>  // cprintf()などのコンソール入出力関数
#include <stdio.h>  // sprintf()用

// NESの画面は60FPS
#define GAME_DURATION_FRAMES (60 * 10) // 10秒

// パレットデータ（白、黒、赤、青）
const byte palette[16] = {
  0x0f, 0x00, 0x16, 0x12,
  0x0f, 0x0f, 0x0f, 0x0f,
  0x0f, 0x0f, 0x0f, 0x0f,
  0x0f, 0x0f, 0x0f, 0x0f
};

// グローバル変数
static unsigned int press_count; // ボタン押下回数
static unsigned int timer;       // 残り時間（フレーム）
static byte last_pad_state;      // 前フレームのパッド状態
static char buffer[32];          // 文字列描画用バッファ

// メイン関数
void main(void) {
  // --- 初期化 ---

  // 画面（PPU）をオフにする
  ppu_off();

  // パレットを設定
  pal_bg(palette);

  // 画面をクリア
  clrscr();

  // タイトルと説明を表示
  gotoxy(8, 8);
  cprintf("RENSHA MEASUREMENT");
  gotoxy(7, 12);
  cprintf("PRESS A BUTTON START!");
  gotoxy(4, 20);
  cprintf("COUNT: 0");
  gotoxy(20, 20);
  cprintf("TIME: 10");

  // 画面（PPU）をオンにする
  ppu_on_all();

  // 変数を初期化
  press_count = 0;
  timer = GAME_DURATION_FRAMES;
  last_pad_state = 0;
  
  // スタート待ちループ
  while (1) {
    ppu_wait_nmi(); // VBlank（画面描画の垂直帰線期間）まで待つ
    
    // パッド1の入力を読み取る
    byte pad = pad_poll(0);
    
    // Aボタンが押された瞬間にゲーム開始
    // (押されている AND 1フレーム前は押されていない)
    if ((pad & PAD_A) && !(last_pad_state & PAD_A)) {
      break;
    }
    last_pad_state = pad;
  }
  
  // スタート時の画面をクリア
  ppu_off();
  clrscr();
  gotoxy(4, 12);
  cprintf("MEASURING...");
  gotoxy(4, 20);
  cprintf("COUNT: 0");
  ppu_on_all();


  // --- メインゲームループ (10秒間) ---
  while (timer > 0) {
    // VBlankを待つ
    ppu_wait_nmi();
    
    // タイマーを減らす
    timer--;

    // パッド1の入力を読み取る
    byte pad = pad_poll(0);

    // Aボタンが押された「瞬間」を検出（連射測定のためエッジ検出）
    if ((pad & PAD_A) && !(last_pad_state & PAD_A)) {
      press_count++;
      
      // カウント数を更新
      gotoxy(11, 20);
      sprintf(buffer, "%d", press_count);
      cprintf(buffer);
    }
    
    // 1秒ごとに残り時間を更新
    if (timer % 60 == 0) {
      gotoxy(20, 20);
      sprintf(buffer, "TIME: %d ", timer / 60);
      cprintf(buffer);
    }

    // 現在のパッド状態を保存
    last_pad_state = pad;
  }

  // --- 結果表示 ---
  ppu_off();
  clrscr();
  
  // 最終結果を表示
  gotoxy(10, 10);
  sprintf(buffer, "FINISH!");
  cprintf(buffer);
  
  gotoxy(8, 14);
  sprintf(buffer, "TOTAL: %d HITS", press_count);
  cprintf(buffer);
  
  gotoxy(5, 16);
  // 1秒あたりの回数 (HPS: Hits Per Second)
  sprintf(buffer, "(%.1f HITS/SECOND)", (float)press_count / 10.0);
  cprintf(buffer);
  
  ppu_on_all();

  // 無限ループで停止
  while (1);
}
