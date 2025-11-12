.segment "HEADER"
.byte "NES", $1A     ; iNES 1.0 magic number
.byte 1              ; 1 x 16KB PRG ROM
.byte 1              ; 1 x 8KB CHR ROM
.byte $01            ; Mapper 0 (NROM), Horizontal mirroring
.byte $00            ; Mapper 0
.byte 0, 0, 0, 0, 0, 0, 0, 0 ; 予約
