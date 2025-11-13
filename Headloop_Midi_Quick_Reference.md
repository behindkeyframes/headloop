# HeadLoop MIDI - Quick Reference Card

## MIDI CC Map (Continuous Controllers)

### HEAD PARAMETERS
```
┌─────────────────────────────────────────────────────────────────┐
│                    HEAD 1  HEAD 2  HEAD 3  HEAD 4               │
├─────────────────────────────────────────────────────────────────┤
│ Volume           │   CC 1   CC 2   CC 3   CC 4                  │
│ Pitch            │   CC 5   CC 6   CC 7   CC 8                  │
│ Pan              │   CC 9   CC 10  CC 11  CC 12                 │
│ Filter LP/HP     │   CC 13  CC 14  CC 15  CC 16                 │
│ Filter BP        │   CC 17  CC 18  CC 19  CC 20                 │
│ Filter Q         │   CC 21  CC 22  CC 23  CC 24                 │
│ Start Point      │   CC 25  CC 26  CC 27  CC 28                 │
│ End Point        │   CC 29  CC 30  CC 31  CC 32                 │
└─────────────────────────────────────────────────────────────────┘
```

### TAPE PARAMETERS
```
┌─────────────────────────────────────────────────────────────────┐
│ Tape Send 1      │   CC 33                                      │
│ Tape Send 2      │   CC 34                                      │
│ Tape Send 3      │   CC 35                                      │
│ Tape Send 4      │   CC 36                                      │
│ Tape Volume      │   CC 37                                      │
│ Tape Pitch       │   CC 38                                      │
└─────────────────────────────────────────────────────────────────┘
```

### GLOBAL PARAMETERS
```
┌─────────────────────────────────────────────────────────────────┐
│ Reverb Send      │   CC 41                                      │
│ Reverb Mix       │   CC 42                                      │
│ Tape Wobble      │   CC 43                                      │
│ Tape Saturation  │   CC 44                                      │
│ Tape Hiss        │   CC 45                                      │
│ Tape Age         │   CC 46                                      │
│ Loop Fade In     │   CC 47                                      │
│ Loop Fade Out    │   CC 48                                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## MIDI NOTE Map

### KEYBOARD LAYOUT
```
┌───────────────────────────────────────────────────────────────────┐
│                        OCTAVE 0 (C1-B1)                           │
├───────────────────────────────────────────────────────────────────┤
│                                                                   │
│  C1   C#1   D1   D#1   E1   F1   F#1   G1   G#1   A1   A#1   B1  │
│  36   37    38   39    40   41   42    43   44    45   46    47  │
│  │    │     │    │     │    │    │     │    │     │    │     │   │
│  REC  OVD  CLR  ---   MT1  MT2  MT3   MT4  RV1   RV2  RV3   RV4  │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────┐
│                        OCTAVE 1 (C2-G#2)                          │
├───────────────────────────────────────────────────────────────────┤
│                                                                   │
│  C2   C#2   D2   D#2   E2   F2   F#2   G2   G#2                  │
│  48   49    50   51    52   53   54    55   56                   │
│  │    │     │    │     │    │    │     │    │                    │
│  REC  OVD  CLR  REV   MUT  ---  ---   ---  ---                   │
│ TAPE TAPE TAPE TAPE  TAPE                                        │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────┐
│                        OCTAVE 2 (C3-D#3)                          │
├───────────────────────────────────────────────────────────────────┤
│                                                                   │
│  C3   C#3   D3   D#3                                              │
│  60   61    62   63                                               │
│  │    │     │    │                                                │
│ SEL1 SEL2  SEL3 SEL4                                              │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

### ACTION TABLE
```
┌─────────┬──────┬──────────────────────────────────────────────┐
│ NOTE    │ NAME │ ACTION                                       │
├─────────┼──────┼──────────────────────────────────────────────┤
│ MAIN LOOP ACTIONS                                             │
├─────────┼──────┼──────────────────────────────────────────────┤
│ 36 (C1) │ REC  │ Record/Stop Main Loop                        │
│ 37 (C#1)│ OVD  │ Overdub Main Loop (if exists)                │
│ 38 (D1) │ CLR  │ Clear Main Loop (if exists)                  │
├─────────┼──────┼──────────────────────────────────────────────┤
│ HEAD MUTES                                                    │
├─────────┼──────┼──────────────────────────────────────────────┤
│ 40 (E1) │ MT1  │ Toggle Mute Head 1                           │
│ 41 (F1) │ MT2  │ Toggle Mute Head 2                           │
│ 42 (F#1)│ MT3  │ Toggle Mute Head 3                           │
│ 43 (G1) │ MT4  │ Toggle Mute Head 4                           │
├─────────┼──────┼──────────────────────────────────────────────┤
│ HEAD REVERSE                                                  │
├─────────┼──────┼──────────────────────────────────────────────┤
│ 44 (G#1)│ RV1  │ Toggle Reverse Head 1                        │
│ 45 (A1) │ RV2  │ Toggle Reverse Head 2                        │
│ 46 (A#1)│ RV3  │ Toggle Reverse Head 3                        │
│ 47 (B1) │ RV4  │ Toggle Reverse Head 4                        │
├─────────┼──────┼──────────────────────────────────────────────┤
│ TAPE ACTIONS                                                  │
├─────────┼──────┼──────────────────────────────────────────────┤
│ 48 (C2) │ REC  │ Record/Stop Tape                             │
│ 49 (C#2)│ OVD  │ Overdub Tape (if exists)                     │
│ 50 (D2) │ CLR  │ Clear Tape (if exists)                       │
│ 51 (D#2)│ REV  │ Toggle Reverse Tape                          │
│ 52 (E2) │ MUT  │ Toggle Mute Tape                             │
├─────────┼──────┼──────────────────────────────────────────────┤
│ HEAD SELECTION                                                │
├─────────┼──────┼──────────────────────────────────────────────┤
│ 60 (C3) │ SEL1 │ Select Head 1 for editing                    │
│ 61 (C#3)│ SEL2 │ Select Head 2 for editing                    │
│ 62 (D3) │ SEL3 │ Select Head 3 for editing                    │
│ 63 (D#3)│ SEL4 │ Select Head 4 for editing                    │
└─────────┴──────┴──────────────────────────────────────────────┘
```

---

## PAD CONTROLLER LAYOUT (16 Pads)

```
┌────────────────────────────────────────────────────┐
│         RECOMMENDED 16-PAD LAYOUT                  │
├────────────────────────────────────────────────────┤
│                                                    │
│   ROW 1:  [REC] [OVD] [CLR] [---]                 │
│           (36)  (37)  (38)  (39)                  │
│                                                    │
│   ROW 2:  [MT1] [MT2] [MT3] [MT4]                 │
│           (40)  (41)  (42)  (43)                  │
│                                                    │
│   ROW 3:  [RV1] [RV2] [RV3] [RV4]                 │
│           (44)  (45)  (46)  (47)                  │
│                                                    │
│   ROW 4:  [REC] [OVD] [CLR] [REV]                 │
│          TAPE   TAPE  TAPE  TAPE                  │
│           (48)  (49)  (50)  (51)                  │
│                                                    │
└────────────────────────────────────────────────────┘

LEGEND:
  REC = Record        MT = Mute
  OVD = Overdub       RV = Reverse
  CLR = Clear         SEL = Select
```

---

## FADER/KNOB LAYOUT (8 Controls)

```
┌────────────────────────────────────────────────────┐
│         RECOMMENDED 8-FADER LAYOUT                 │
├────────────────────────────────────────────────────┤
│                                                    │
│   OPTION A (Volumes & Pitches):                   │
│   ┌──┬──┬──┬──┬──┬──┬──┬──┐                      │
│   │ 1│ 2│ 3│ 4│ 5│ 6│ 7│ 8│                      │
│   └──┴──┴──┴──┴──┴──┴──┴──┘                      │
│    VOL VOL VOL VOL PIT PIT PIT PIT               │
│    H1  H2  H3  H4  H1  H2  H3  H4                │
│                                                    │
│   OPTION B (Volumes & Tape Sends):                │
│   ┌──┬──┬──┬──┬──┬──┬──┬──┐                      │
│   │ 1│ 2│ 3│ 4│33│34│35│36│                      │
│   └──┴──┴──┴──┴──┴──┴──┴──┘                      │
│    VOL VOL VOL VOL SND SND SND SND               │
│    H1  H2  H3  H4  TP1 TP2 TP3 TP4               │
│                                                    │
│   OPTION C (Volumes & Filters):                   │
│   ┌──┬──┬──┬──┬──┬──┬──┬──┐                      │
│   │ 1│ 2│ 3│ 4│13│14│15│16│                      │
│   └──┴──┴──┴──┴──┴──┴──┴──┘                      │
│    VOL VOL VOL VOL FLT FLT FLT FLT               │
│    H1  H2  H3  H4  H1  H2  H3  H4                │
│                                                    │
└────────────────────────────────────────────────────┘
```

---

## QUICK START

### 1. Connect MIDI Device
```
PARAMS → MIDI → MIDI Device → Select 1-4
```

### 2. Essential CCs
```
CC 1-4   : Head Volumes (most used)
CC 13-16 : Head Filters (creative)
CC 33-36 : Tape Sends (routing)
```

### 3. Essential Notes
```
Note 36 (C1)   : Start/Stop recording
Notes 40-43    : Mute/Unmute heads
Note 48 (C2)   : Start/Stop tape
```

### 4. Emergency Reset
```
PARAMS → MIDI Learn → MIDI Panic
```

---

## VALUE RANGES

```
┌──────────────────┬─────────────┬───────────────────┐
│ PARAMETER        │ MIDI (0-127)│ ACTUAL RANGE      │
├──────────────────┼─────────────┼───────────────────┤
│ Volume           │ 0-127       │ 0.0 - 2.0         │
│ Pitch            │ 0-127       │ -24st to +24st    │
│ Pan              │ 0-127       │ -1.0 (L) to +1.0 (R) │
│ Filter LP/HP     │ 0-127       │ -1.0 (LP) to +1.0 (HP) │
│ Filter BP        │ 0-127       │ 0.0 to 1.0        │
│ Filter Q         │ 0-127       │ 0.1 to 4.0        │
│ Start/End        │ 0-127       │ 0.0 to 1.0        │
│ Tape Sends       │ 0-127       │ 0.0 to 1.0        │
│ Reverb           │ 0-127       │ 0.0 to 1.0        │
│ Tape FX          │ 0-127       │ 0.0 to 1.0        │
│ Fade In/Out      │ 0-127       │ 0.001s to 0.5s    │
└──────────────────┴─────────────┴───────────────────┘
```

---
