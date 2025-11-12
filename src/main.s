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
  
  ; APU/PPU無効化
  LDA #$00
  STA PPUCTRL
  STA PPUMASK
  STA $4010
  STA $4015
  STX $4017
  
  ; RAM初期化 (カウンターを$0000-$0001までクリア)
  LDA #$00
  STA COUNTER_LO
  STA COUNTER_HI

  ; PPUウォームアップ待機
  BIT PPUSTATUS
WaitVBlank1:
  BIT PPUSTATUS
  BPL WaitVBlank1
WaitVBlank2:
  BIT PPUSTATUS
  BPL WaitVBlank2

  ; PPU初期化
  JSR InitPPU

  ; NMI有効化、画面表示ON
  LDA #%10010000  ; NMI有効 (VBlank), BGパターン $0000
  STA PPUCTRL
  LDA #%00011110  ; BG/Sprite表示ON, 画面端クリップOFF
  STA PPUMASK

  CLI            ; 割り込み許可

MainLoop:
  JMP MainLoop   ; メインループはここで待機 (処理はNMIで行う)

.segment "CODE"

; --- PPU初期化ルーチン ---
InitPPU:
  ; パレットを読み込む
  LDA PPUSTATUS
  LDA #$3F
  STA PPUADDR
  LDA #$00
  STA PPUADDR
  
  LDX #$03
LoadPaletteLoop:
  LDA Palette, X
  STA PPUDATA
  DEX
  BPL LoadPaletteLoop
  
  ; 固定テキスト ("AB:") をネームテーブルに書き込む
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
  .byte $0F, $00, $10, $30 ; BG0(黒), BG1(濃灰), BG2(灰), BG3(白)
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
  AND #%00000011      ; AまたはBが押されているか (ビット0=A, ビット1=B)
  BEQ SkipInc         ; 押されていなければスキップ
  
  LDA CONTROLLER1_PREV
  AND #%00000011      ; 前回、AまたはBが押されていたか
  BNE SkipInc         ; 押されていたら (押しっぱなし) スキップ
  
  ; AまたはBが「押された瞬間」
  ; カウンター (16bit) をインクリメント
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
  BNE SkipInc ; HIが3じゃなければスキップ
  LDA COUNTER_LO
  CMP #$E8
  BNE SkipInc ; LOがE8じゃなければスキップ
  
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
  LDA #$63 ; "AB:" の直後 ($2060=A, $2061=B, $2062=:)
  STA PPUADDR
  LDA DEC_BUFFER_100  ; 100の位
  STA PPUDATA
  LDA DEC_BUFFER_10   ; 10の位
  STA PPUDATA
  LDA DEC_BUFFER_1   ; 1の位
  STA PPUDATA
  
  RTS

; サブルーチン: 16ビット値 (A:Lo, X:Hi) を 10進数3桁 (0-999) に変換
; 入力: A (Lo), X (Hi)
; 出力: DEC_BUFFER_100, DEC_BUFFER_10, DEC_BUFFER_1
; 破壊: Y, ZP_VALUE_LO, ZP_VALUE_HI
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
  TAY            ; LoをYに一時保存
  LDA ZP_VALUE_HI
  SBC #$00
  BCC Dec_Set100 ; 借り発生 (引けなかった)
  
  ; 引けたので値を更新
  STA ZP_VALUE_HI
  TYA
  STA ZP_VALUE_LO
  JMP Dec_Loop100

Dec_Set100:
  ; 引けなかったので、カウンターYを100の位にセット
  STY DEC_BUFFER_100
  
  LDY #$FF
Dec_Loop10:
  INY
  ; 10 ($0A) を引く
  LDA ZP_VALUE_LO
  SEC
  SBC #$0A
  BCS Dec_Loop10_Update ; 引けた
  BCC Dec_Set10       ; 引けなかった
  
Dec_Loop10_Update:
  STA ZP_VALUE_LO
  JMP Dec_Loop10
  
Dec_Set10:
  ; 引けなかったので、カウンターYを10の位にセット
  STY DEC_BUFFER_10
  
  LDA ZP_VALUE_LO   ; 残りが1の位
  STA DEC_BUFFER_1
  RTS

.segment "VECTORS"
.word NMI_Handler
.word RESET
.word 0
