.segment "STARTUP"
.org $C000

RESET:
  ; PPUとAPUを初期化 (簡単のため無効化のみ)
  SEI            ; 割り込み禁止
  CLD            ; 10進モード解除
  LDX #$40
  STX $4017      ; APUフレームIRQ無効化
  LDX #$00
  STX $4010      ; DMC無効化
  TXA
  STA $4015      ; 全APUチャンネル無効化

  ; RAMをゼロクリア
  LDA #$00
  STA $0000      ; Aボタンカウンター
  STA $0001      ; Bボタンカウンター
  
  ; PPUウォームアップ待機 (VBlankを2回待つ)
  LDX #$02
WaitVBlank:
  BIT $2002
  BPL WaitVBlank
  DEX
  BNE WaitVBlank

  ; メインループ
NMI:
  JMP NMI        ; 無限ループ (本来はここでNMIを待つ)


.segment "CODE"

; --- NMI (Non-Maskable Interrupt) ---
; VBlank（画面描画の合間）ごとに呼ばれる
NMI_Handler:
  ; ... (PPU更新処理など) ...
  
  JSR ReadController1 ; コントローラー1を読む
  JSR UpdateCounters  ; カウンターを更新

  RTI            ; 割り込みから復帰

; --- コントローラー読み取り ---
; $0002 にボタン状態を保存 (8ビット)
; $0003 に前回のボタン状態を保存
ReadController1:
  LDA $0002           ; 前回のボタン状態を
  STA $0003           ; $0003 へ移動

  LDA #$01
  STA $4016           ; コントローラーストロボ (ラッチ)
  LDA #$00
  STA $4016

  LDX #$08            ; 8回ループ (8ボタン)
ReadLoop:
  LDA $4016           ; $4016から1ビット読み込む
  LSR A               ; 読み取ったデータ (D0) をキャリーへ
  ROL $0002           ; $0002 (ボタン状態) にキャリーを左から詰める
  DEX
  BNE ReadLoop
  
  RTS

; --- カウンター更新ロジック ---
; $0000: Aボタンの累計回数 (256回まで)
; $0001: Bボタンの累計回数 (256回まで)
UpdateCounters:
  LDA $0002           ; 現在のボタン状態
  AND #%00000001      ; Aボタン (ビット0)
  BEQ SkipA           ; 押されていなければスキップ
  
  ; Aが押されている
  LDA $0003           ; 前回のボタン状態
  AND #%00000001      ; 前回のAボタン
  BNE SkipA           ; 前回も押されていたら (押しっぱなし) スキップ
  
  ; Aが「押された瞬間」
  INC $0000           ; Aカウンターをインクリメント

SkipA:
  LDA $0002           ; 現在のボタン状態
  AND #%00000010      ; Bボタン (ビット1)
  BEQ SkipB           ; 押されていなければスキップ
  
  ; Bが押されている
  LDA $0003           ; 前回のボタン状態
  AND #%00000010      ; 前回のBボタン
  BNE SkipB           ; 前回も押されていたら (押しっぱなし) スキップ

  ; Bが「押された瞬間」
  INC $0001           ; Bカウンターをインクリメント
  
SkipB:
  RTS

.segment "VECTORS"
; 割り込みベクタ (CPUがどこに飛ぶかの定義)
.word NMI_Handler  ; NMI (VBlank)
.word RESET        ; RESET (電源ON時)
.word 0            ; IRQ (未使用)
