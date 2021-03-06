
;==============================================================================
;
; MUSIC
;
; Samuel Volk, March 2019
;
; Just plays music. My attempt at a Gameboy sound 'engine' in hopes that it
; might be used for other GameBoy projects of mine.
;
;==============================================================================

.INCLUDE "gb_hardware.i"
.INCLUDE "header.i"
.INCLUDE "songs.i"

;==============================================================================
; INTERRUPTS
;==============================================================================

.BANK 0
.ORG $00    ; Reset $00
    jp $100
.ORG $08    ; Reset $08
    jp $100
.ORG $10    ; Reset $10
    jp $100
.ORG $18    ; Reset $18
    jp $100
.ORG $20    ; Reset $20
    jp $100
.ORG $28    ; Reset $28	- Copy Data routine
CopyData:
    pop hl  ; pop return address off stack
    push bc

    ; get number of bytes to copy
    ; hl contains the address of the bytes following the rst call
    ldi a, (hl)
    ld b, a
    ldi a, (hl)
    ld c, a

-   ldi a, (hl)	; start transfering data
    ld (de), a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, -

    ; all done
    pop bc
    jp hl
    reti

.ORG $30    ; Reset $30
    ;jp $100	; is overwritten above
.ORG $38    ; Reset $38
    ;jp $100	; is overwritten above
.ORG $40    ; Vblank IRQ Vector
    reti
.ORG $48    ; LCD IRQ Vector
    reti
.ORG $50    ; Timer IRQ Vector
    reti
.ORG $58    ; Serial IRQ Vector
    reti
.ORG $60    ; Joypad IRQ Vector
    reti

.ORG $100   ; Code Execution Start
    nop
    jp Start

;==============================================================================
; SUBROUTINES
;==============================================================================
.BANK 0
.SECTION "Subroutines" FREE

; Init Subroutines
BlankSprites:
    ld hl, $8000
    ld bc, 4080
-   ld a, 0
    ldi (hl), a
    dec bc
    ld a, b
    or c
    jp nz, -
    ret

BlankOAM:
    ld hl, $C100
    ld bc, 160	; entries
-   ld a, 0
    ldi (hl), a
    dec bc
    ld a, b
    or c
    jp nz, -
    ret

BlankWRAM:
    ld hl, $C000    ; WRAM
    ld bc, $2000    ; counter
-   ld a, 0
    ldi (hl), a
    dec bc
    ld a, b
    or c
    jp nz, -
    ret

LoadTiles:
    ld hl, Tiles
    ld de, $8000
    ld bc, TileCount
-   ldi a, (hl)
    ld (de), a
    inc de
    dec bc
    ld a, b
    or c
    jp nz, -
    ret

MoveData:
    ;hl  source
    ;de  destination
    ;bc  length/size
-   ldi a, (hl)
    ld (de), a
    inc de
    dec bc
    ld a, b
    or c
    jp nz, -
    ret

BlankMap:
    ld hl, $9800
    ld bc, 1024
-   ld a, 0
    ldi (hl), a
    dec bc
    ld a, b
    or c
    jp nz, -
    ret

LoadMap:
    ld hl, Tiles
    ld de, $9800
    ld bc, TileCount
-   ldi a, (hl)
    ld (de), a
    inc de
    dec bc
    ld a, b
    or c
    jp nz, -
    ret

ScreenOn:
    ldh a, (R_LCDC)
    or %01000000
    ldh (R_LCDC), a
    ret

ScreenOff:
    ld a, 0
    ldh (R_LCDC), a
    ret

DMACopy:
    ; https://exez.in/gameboy-dma
    ld de, $FF80    ; destination of HRAM for DMA routine
    rst $28
    .DB $00, $0D    ; assembled DMA subroutine length
		    ; then assembled DMA subroutine
    .DB $F5, $3E, $C1, $EA, $46, $FF, $3E, $28, $3D, $20, $FD, $F1, $D9
    ret

.ENDS

.SECTION "BankRoutines" FREE
BankMode:
    ; a	    bank mode - $00 ROM, $01 RAM
    ld hl, $6000
    ld (hl), a
    ret

RAMEnable:
    ; a	    enable/disable
    ld hl, $0000
    ld (hl), a
    ret

SwitchBank:
    ; a	    new bank
    ld hl, $2000
    ld (hl), a
    ret
.ENDS

;==============================================================================
; START
;==============================================================================
.BANK 0
.ORG $150
Start:
    di
    ld sp, $FFFE    ; setup stack

    ; wait for vblank
-   ld a, (LY)
    cp $91
    jr nz, -
    ; turn screen off
    call ScreenOff

    ; no sound needed
    xor a
    ldh (R_NR52), a

    call BlankWRAM
    call BlankOAM
    call BlankSprites
    call BlankMap


    ; load palette
    ld a, %11100100	; bg
    ldh (R_BGP), a
    ld a, %00011011	; obj
    ldh (R_OBP0), a

    call DMACopy ; set up DMA subroutine

    ; switch banks
    ld a, 3
    call SwitchBank

    ; Load waveform
    ld hl, WaveRamp
    call LoadWaveform

    ; select interrupts to enable
    ld a, %00000001
    ldh (R_IE), a

    ; setup screen
    ld a, %10010011
    ldh (R_LCDC), a

    ei

    ld hl, Song_MaryLamb
    call LoadMusic

    ; setup sound
    ld a, %10000000
    ldh (R_NR52), a
    ld a, %01110111 ; full volume
    ldh (R_NR50), a
    ld a, %11011110
    ldh (R_NR51), a

MainLoop:
    halt    ; wait for vblank
    nop

    call $FF80 ; DMA routine in HRAM

    call UpdateMusic

    jp MainLoop


;==============================================================================
; DATA
;==============================================================================
.BANK 0
.SECTION "Data" FREE

.DEFINE TileCount   0
Tiles:
.DB $00

.ENDS

; vim: filetype=wla
