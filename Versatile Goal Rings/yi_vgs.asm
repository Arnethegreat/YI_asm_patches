; Versatile Goal Rings Patch
; Makes Goal Ring cutscene more flexible in use and less intrusive to the player.
; It can now be spawned from left or right and entered from any direction!
; However there is no other Yoshi that Baby Mario gets handed to
; But this makes it much more safe to use at arbitrary locations and prevents accidental softlocks

;--------
; CONFIG
;--------

; Select 0 for regular Player Yoshi at goal ring - the player is frozen at specified amount of frames at goal ring
; And moves afterwards with specified input and speed (or none)
; Select 1 for Goal Yoshi sprite at goal ring - The Player Yoshi is hidden off screen
; This was the first iteration but it has the problem of Baby Mario being gone suddenly but is included here anyways
!GOAL_RING_MODE = 1


; Separate Goal Ring state countdown. this controls the countdown before state 3 
; Basically a Timer before the !GOAL_RING_END_DELAY timer starts - it also determines when the G O A L ! sprite is spawned.
; In mode 0, Yoshi remains frozen for this interval
; in mode 1, this controls the countdown before state 3 only
!GOAL_RING_ROULETTE_FRAMES = $0030
; When GOAL_RING_ROULETTE_FRAMES reaches this value, the G O A L ! sprite is spawned. Keep it less than !GOAL_RING_ROULETTE_FRAMES to have it spawn
!GOAL_RING_GOAL_SPAWN = $002F 

; Flower-select roulette timer values.
; Vanilla Initial = $6000
; Vanilla Decrement = $0046
; Set the initial value and per-frame decrement together for tick speed and total spin duration
; Large Initial values make the roulette spin FASTER and a larger decrement runs the timer down faster.
!GOAL_FLOWER_TIMER_INITIAL = $6000
!GOAL_FLOWER_TIMER_DECREMENT = $0046

; Goal End delay in frames after the !GOAL_RING_ROULETTE_FRAMES is done.
; Change this to make it level ending start/end sooner. 
!GOAL_RING_END_DELAY = $0180

; Mode 0 only. Player input is $0200 for left or $0100 for right, $0000 for standing still.
; X speed is signed; $0000 starts from rest and accelerates normally.
!MODE0_RUN_INPUT = $0200
!MODE0_INITIAL_X_SPEED = $0000

;----------------------------------------------------
;----------------------------------------------------
;----------------------------------------------------


; Prevent the goal ring to write to camera boundary value - this removes the jerk and allows it to spawn from other direction smoothly
; orignally:   STA !s_cam_x_right_boundary               ; $02A8FC |
org $02A8FC
    NOP #3

; The goal-entry code stores the current BG1 camera in $0C23 and enables X autoscroll.
; Set the right boundary to that same camera position to lock it in place.
org $02A973
    LDA $0C23
    NOP #4

; Sign change near the actual goal ring entry makes it possible to enter goal ring from distance when it spawns
; have to hijack the entry code to make it work properly
org $02A911
    autoclean JML goal_ring_entry

; Set normal cutscene Yoshi state and do not set egg-throw state
; This removes the egg-pump animation
org $02A943
    LDA #$0002

org $02A949
    LDA #$0000

; Preserve the player's facing direction on entry. Sprite facing uses the opposite format from player ofc
; Later invert it when setting Goal Yoshi sprite facing.
org $02A952
    NOP #3

if !GOAL_RING_MODE == 1
    ; Convert player-direction to sprite-direction, then resume.
    org $02AABE
        autoclean JML goal_ring_facing_copy
        NOP #2
endif

if !GOAL_RING_MODE == 0
    ; Do not spawn Goal Yoshi sprite or change the real player's coordinates/color.
    org $02AAA0
        autoclean JML no_goal_yoshi_sprite
        fillbyte $EA
        fill $05
endif

; This is the Goal Ring's roulette countdown before state 3.
org $02AA9A
    LDA #!GOAL_RING_ROULETTE_FRAMES

; What GOAL_RING_ROULETTE_FRAMES value is used to spawn the G O A L ! sprite
org $02AB78
  CMP #!GOAL_RING_GOAL_SPAWN

; Initialize and decrement the flower-select roulette timer.
org $02A5E6
    LDA #!GOAL_FLOWER_TIMER_INITIAL

org $02A7CE
    SBC #!GOAL_FLOWER_TIMER_DECREMENT

if !GOAL_RING_MODE == 1
    ; Freeze real Yoshi after the Goal Yoshi sprite spawn and set him off-screen
    ; Setting $61AE skips the player's per-frame movement update.
    org $02AB05
        JML goal_ring_freeze_player
endif

; Skip only the Yoshi at Goal despawn - the following code still despawns the ring.
; In mode 1 this leaves goal yoshi sprite alive for the normal level transition.
org $02AC3F
    JMP $AC48
    fillbyte $EA
    fill $06

; At the end of mode 0's freeze timer, start the Yoshi running sequence and begin the level-end timer
; Mode 1 keeps the original state transition.
if !GOAL_RING_MODE == 0
    org $02AB6B
        autoclean JML mode0_start_run
        fillbyte $EA
        fill $09
else
    org $02AB6D
        LDA #!GOAL_RING_END_DELAY
endif

; Bypass the $60DE == 2 launch block. The zero-timer initialization above
; still runs; all nonzero timer values proceed to the camera step.
org $02AB0C
    BRA camera_hook

; Keep $0C23 unchanged; the autoscroll hold the camera in both modes
org $02AB56
camera_hook:
    JSL camera_step_hijack
    fillbyte $EA
    fill $0A

; State normally waits for Baby Mario to land
; Let the existing timer expire without starting or waiting for that sequence.
org $02ABAB
if !GOAL_RING_MODE == 0
    autoclean JML mode0_do_run_input
    fillbyte $EA
    fill $01
else
    BRA goal_ring_timer_entry
    fillbyte $EA
    fill $03
endif

org $02ABF8
goal_ring_timer_entry:

; End of timer, remove stock behavior
; The player remains in the cutscene state at the ring.
org $02AC0A
    STZ $617A
    fillbyte $EA
    fill $03

; Keep goal entry autoscroll through the end timer and retain the same camera boundary
; Instead of setting it to Yoshi's position.
org $02AC10
    NOP #3

org $02AC19
    LDA $0C23
    NOP #4

; Keep player X speed at zero rather setting it to positive speed (yoshi leaving cutscene)
org $02AC23
    STZ $60B4
    fillbyte $EA
    fill $0B

; Set the normal level-clear flag the timer, without waiting for player screen-X >= $00F0.
org $02AC31
    LDA #$00F0


; awful crappy hijack code :>
freespacebyte $FF
freecode

; unused as of now - earlier test
camera_step_hijack:
    RTL

goal_ring_entry:
    BCC .no_crossing
    BMI .negative_offset
    CMP #$0041
    BCS .no_crossing
    JML $02A916

    .negative_offset
    CMP #$FFC0
    BCC .no_crossing
    JML $02A916

    .no_crossing
    JML $02A915

if !GOAL_RING_MODE == 0
    no_goal_yoshi_sprite:
        LDA #$0001
        STA $61AE
        STZ $60B4
        STZ $60C0
        STZ $6162
        STZ $6168
        JML $02AB56

    mode0_start_run:
        INC $18,x
        LDA #!GOAL_RING_END_DELAY
        STA $7A96,x
        LDA #!MODE0_RUN_INPUT
        STA $617A
        LDA #!MODE0_INITIAL_X_SPEED
        STA $60B4
        LDA #$0001
        STA $60C0
        STZ $61AE
        JML $02AB91

    mode0_do_run_input:
        LDA #!MODE0_RUN_INPUT
        STA $617A
        JML $02ABF8

endif

if !GOAL_RING_MODE == 1

    goal_ring_freeze_player:
        LDX $12
        LDA #$0001
        STA $61AE
        JML $02AB56

    goal_ring_facing_copy:
        LDA $60C4
        EOR #$0002
        STA $7400,y
        JML $02AAC4
   
endif
