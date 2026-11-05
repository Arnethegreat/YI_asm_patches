; makes PAL version into NTSC and now runs at 60 FPS :>

org $00FFD9
    db $01

org $108851
    LDA #$02
