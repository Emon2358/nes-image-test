; RAMの定義
COUNTER_LO = $0000 ; 合計カウンター 16bit (下位)
COUNTER_HI = $0001 ; 合計カウンター 16bit (上位)
CONTROLLER1 = $0002 ; コントローラー1の現在の状態
CONTROLLER1_PREV = $0003 ; 前回の状態

; 10進数変換バッファ
DEC_BUFFER_100 = $0010 ; 10進数変換用 (100の位)
DEC_BUFFER_10  = $0011 ; (10の位)
DEC_BUFFER_1   = $0012 ; (1の位)

; ゼロページ (高速アクセス用)
ZP_VALUE_LO = $F0
ZP_VALUE_HI = $F1
ZP_ADDR_LO  = $F2
ZP_ADDR_HI  = $F3
ZP_COUNTER  = $F4

; PPUレジスタ
PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
OAMDATA   = $2004
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007

.segment "STARTUP"
.org $C000

RESET:
  SEI            ; 割り込み禁止
  CLD            ; 10進モード解除
  LDX #$FF
  TXS            ; スタックポインタ初期化
  
  ; APU/PPU無効化 (画面が真っ黒になるのを防ぐため、まずPPUを完全に止める)
  LDA #$00
  STA PPUCTRL   ; NMI無効
  STA PPUMASK   ; 描画OFF
  STA $4010
  STA $4015
  STX $4017
  
  ; RAM初期化
  LDA #$00
  STA COUNTER_LO
  STA COUNTER_HI

  ; PPUウォームアップ待機 (PPUが安定するまでVBlankを2回待つ)
  BIT PPUSTATUS
WaitVBlank1:
  BIT PPUSTATUS
  BPL WaitVBlank1
WaitVBlank2:
  BIT PPUSTATUS
  BPL WaitVBlank2

  ; --- ここからが重要な初期化シーケンス ---
  
  ; 1. VRAM (ネームテーブル $2000-$2FFF) を $00 でクリア
  LDA #$20
  STA ZP_ADDR_HI
  LDA #$00
  STA ZP_ADDR_LO
  
  STA PPUADDR     ; $2000 をセット (ZP_ADDR_HI は既に $20)
  STA PPUADDR
  
  LDX #$04        ; 4つのネームテーブル ($400 * 4 = $1000 バイト)
ClearVRAM_Loop:
  LDA #$00        ; $00 (黒タイル) を
  LDY #$00        ; 256回
ClearVRAM_Inner:
  STA PPUDATA     ; VRAMに書き込む
  INY
  BNE ClearVRAM_Inner
  ; (ここまでで $100 バイト = 256 バイト書き込んだ)
  
  INX             ; Xをデクリメント (4回ループ用だが、ここではインクリメントで実装)
  CPX #$10        ; $1000 バイト書き込んだか？ (16回 * 256バイト)
  BNE ClearVRAM_Inner ; (注: この実装は $1000 バイト (4KB) をクリアします)
  
  ; (簡易版: $2000-$23FF の 1KB (1024バイト) だけクリアする場合)
  ; LDX #$04
  ; ClearVRAM_Loop:
  ;   LDA #$00
  ;   LDY #$00
  ; ClearVRAM_Inner:
  ;   STA PPUDATA
  ;   INY
  ;   BNE ClearVRAM_Inner
  ; DEX
  ; BNE ClearVRAM_Loop
  
  ; 2. パレットを読み込む
  JSR LoadPaletteData
  
  ; 3. 固定テキスト ("AB:") をネームテーブルに書き込む
  JSR LoadTextData

  ; PPU初期化完了

  ; 4. PPUを有効化
  LDA #$00        ; スクロール位置をリセット
  STA PPUSCROLL
  STA PPUSCROLL
  
  LDA #%10010000  ; NMI有効 (VBlank), BGパターン $0000
  STA PPUCTRL
  LDA #%00011110  ; BG/Sprite表示ON
  STA PPUMASK

  CLI            ; 割り込み許可

MainLoop:
  JMP MainLoop   ; メインループはここで待機 (処理はNMIで行う)

.segment "CODE"

; --- PPU初期化ルーチン (サブルーチン化) ---
LoadPaletteData:
  LDA PPUSTATUS   ; PPUラッチをクリア
  LDA #$3F
  STA PPUADDR
  LDA #$00
  STA PPUADDR     ; $3F00 から書き込み開始
  
  LDX #$00
LoadPaletteLoop:
  CPX #$04        ; 4バイト書き込む
  BEQ PaletteDone
  LDA Palette, X
  STA PPUDATA
  INX
  JMP LoadPaletteLoop
PaletteDone:
  RTS

LoadTextData:
  LDA PPUSTATUS
  LDA #$20 ; ネームテーブルアドレス $2060 (5行目あたり)
  STA PPUADDR
  LDA #$60 
  STA PPUADDR
  
  LDX #$00
LoadTextLoop:
  LDA TextData, X
  BEQ TextDone     ; $00 (終端) なら終了
  STA PPUDATA
  INX
  JMP LoadTextLoop
TextDone:
  RTS

; --- 固定データ ---
Palette:
  ; $3F00(背景), $3F01(文字), $3F02(予備1), $3F03(予備2)
  .byte $0F, $30, $10, $00 ; BG0(黒), BG1(白), BG2(灰), BG3(濃灰)
TextData:
  ; "AB:   " (A=$0A, B=$0B, :=$10)
  .byte $0A, $0B, $10, $20, $20, $20
  .byte $00 ; 終端

; --- NMI (VBlankごと) ---
NMI_Handler:
  PHA            ; Aレジスタをスタックに保存
  TXA
  PHA            ; Xレジスタをスタックに保存
  TYA
  PHA            ; Yレジスタをスタックに保存
  
  JSR ReadController1
  JSR UpdateCounters
  JSR UpdateDisplay

  PLA
  TAY            ; Yレジスタを復元
  PLA
  TAX            ; Xレジスタを復元
  PLA            ; Aレジスタを復元
  RTI            ; 割り込みから復帰

; --- コントローラー読み取り ---
ReadController1:
  LDA CONTROLLER1
  STA CONTROLLER1_PREV

  LDA #$01
  STA $4016
  LDA #$00
  STA $4016
  STA CONTROLLER1     ; $0002をクリア

  LDX #$08
ReadLoop:
  LDA $4016
  LSR A
  ROL CONTROLLER1
  DEX
  BNE ReadLoop
  RTS

; --- カウンター更新 (A/B 合計) ---
UpdateCounters:
  LDA CONTROLLER1
  AND #%00000011      ; AまたはBが押されているか
  BEQ SkipInc         ; 押されていなければスキップ
  
  LDA CONTROLLER1_PREV
  AND #%00000011      ; 前回、AまたはBが押されていたか
  BNE SkipInc         ; 押されていたら (押しっぱなし) スキップ
  
  ; AまたはBが「押された瞬間」
  LDA COUNTER_LO
  CLC
  ADC #1
  STA COUNTER_LO
  LDA COUNTER_HI
  ADC #0
  STA COUNTER_HI
  
  ; 999を超えたかチェック (1000 == $03E8)
  LDA COUNTER_HI
  CMP #$03
  BNE SkipInc 
  LDA COUNTER_LO
  CMP #$E8
  BNE SkipInc 
  
  ; 1000になったので0に戻す
  LDA #$00
  STA COUNTER_LO
  STA COUNTER_HI

SkipInc:
  RTS

; --- 画面表示更新 ---
UpdateDisplay:
  ; 合計カウンター ($0000/$0001) を $2063 に10進数3桁で表示
  LDA COUNTER_LO
  LDX COUNTER_HI
  JSR WriteDecValue   ; $10-$12 に変換
  
  LDA #$20
  STA PPUADDR
  LDA #$63 ; "AB:" の直後
  STA PPUADDR
  LDA DEC_BUFFER_100  ; 100の位
  STA PPUDATA
  LDA DEC_BUFFER_10   ; 10の位
  STA PPUDATA
  LDA DEC_BUFFER_1   ; 1の位
  STA PPUDATA
  
  RTS

; サブルーチン: 16ビット値 (A:Lo, X:Hi) を 10進数3桁 (0-999) に変換
WriteDecValue:
  STX ZP_VALUE_HI
  STA ZP_VALUE_LO
  
  LDY #$FF
Dec_Loop100:
  INY
  ; 100 ($0064) を引く
  LDA ZP_VALUE_LO
  SEC
  SBC #$64
  TAY            
  LDA ZP_VALUE_HI
  SBC #$00
  BCC Dec_Set100 
  
  STA ZP_VALUE_HI
  TYA
  STA ZP_VALUE_LO
  JMP Dec_Loop100

Dec_Set100:
  STY DEC_BUFFER_100
  
  LDY #$FF
Dec_Loop10:
  INY
  ; 10 ($0A) を引く
  LDA ZP_VALUE_LO
  SEC
  SBC #$0A
  BCS Dec_Loop10_Update 
  BCC Dec_Set10       
  
Dec_Loop10_Update:
  STA ZP_VALUE_LO
  JMP Dec_Loop10
  
Dec_Set10:
  STY DEC_BUFFER_10
  
  LDA ZP_VALUE_LO   
  STA DEC_BUFFER_1
  RTS

.segment "VECTORS"
.word NMI_Handler
.word RESET
.word 0
