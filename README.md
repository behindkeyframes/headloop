# HeadLoop v1.6

A 4-head looper with integrated tape recorder for Norns.

## Overview

HeadLoop is a multi-head looper that provides independent control over 4 playback heads with extensive sound-shaping capabilities. Each head can manipulate pitch, filters, panning, loop position, and effects sends independently. The integrated tape recorder allows you to capture the output of all heads for layered compositions.

## Features

### Core Looping
- **4 Independent Playback Heads** - Each with full parameter control
- **60-Second Loop Buffer** - Ample space for complex loops
- **Independent Head Control** - Volume, pitch, pan, start/end points per head
- **Overdub Support** - Layer multiple recordings with configurable feedback

### Tape Recorder
- **Integrated Tape System** - Record the output of all 4 heads
- **10-300 Second Tape Length** - Configurable recording time
- **Independent Send Levels** - Control how much each head sends to tape
- **Tape Overdub** - Layer additional material onto existing recordings
- **Reverse Playback** - Instant backwards tape effect
- **Tape Mute** - With 1-second fade to prevent clicks

### Sound Shaping
- **Dual Filter System**
  - Low-pass and high-pass filters (E2 control)
  - Band-pass filter with independent control (E3)
  - Adjustable resonance (Filter Q)
- **Pitch Shifting** - ±24 semitones or ±2 octaves mode
- **Stereo Panning** - Per-head positioning
- **Delay Effect** - Global delay with per-head send levels
- **Reverb** - Norns system reverb integration

### Tape FX
Tape simulation - minimal:
- **Wobble** - Wow and flutter simulation
- **Saturation** - Harmonic distortion
- **Age/Dropout** - Tape degradation effects

### Modulation
- **4 Independent LFOs**
  - Sine or Random waveforms
  - 0.01-20 Hz speed range
  - 21 modulation destinations including:
    - Volume, Pan, Pitch per head
    - Loop Start/End positions per head

### Control Options
- **Norns Interface** - Full control via keys and encoders
- **Grid Support** - Optional Monome Grid or Midigrid integration
- **Extensive MIDI Mapping**
  - 9 CCs for head parameters
  - 5 CCs for tape parameters
  - 5 MIDI notes for tape actions
  - All mappings user-configurable

## Requirements

- Norns (shield, hardware, or fates)
- Norns version 240424 or later recommended
- Optional: Monome Grid (128 or 64) or Midigrid
- Optional: MIDI controller

## Quick Start

### Basic Recording

1. **Record a Loop**
   - Press **K3** to start recording
   - Play your instrument/sound source
   - Press **K3** again to stop and begin playback

2. **Control Heads**
   - Press **K2** to select different heads (1-4)
   - Use **E1** to select parameters (volume, pitch, pan, filters, etc.)
   - Use **E2/E3** to adjust values (coarse/fine)

3. **Add Overdubs**
   - Double-click **K3** to start overdubbing
   - Double-click **K3** again to stop

4. **Clear Loop**
   - Long-press **K3** to clear the loop with a fade

### Using the Tape Recorder

1. Switch to Tape page: Press **K2+K3** together
2. Adjust tape send levels for each head using **E1** (select) and **E2/E3** (adjust)
3. Press **K3** to start tape recording
4. Press **K3** again to stop and play back
5. Double-click **K3** for tape overdub

## Controls

### Keys

- **K2 (short press)**: Change active head (1-4)
- **K2 + K3 (K2 press then K3)**: Switch screen page (Main ↔ Tape)

**K3 - Main Page:**
- **Click**: Record/Stop
- **Double-click**: Overdub
- **Long-press**: Clear loop (with fade)

**K3 - Tape Page:**
- **Click**: Tape record/stop
- **Double-click**: Tape overdub
- **Long-press**: Clear tape (3s fade)

## Head Parameters

Each head has 9 independent parameters:

| Parameter | Range | Description |
|-----------|-------|-------------|
| Volume | 0.00 - 2.00 | Output level |
| Pitch | ±24st / ±2oct | Pitch shift (mode selectable) |
| Pan | L to R | Stereo position |
| Filter LP/HP | HP/Off/LP | Low-pass or high-pass filter |
| Filter BP | 0.00 - 1.00 | Band-pass filter amount |
| Delay | 0.00 - 1.00 | Delay send level |
| Start | 0.00 - 1.00 | Loop start position |
| End | 0.00 - 1.00 | Loop end position |
| Filter Q | 0.10 - 4.00 | Filter resonance |

## Tape Parameters

| Parameter | Range | Description |
|-----------|-------|-------------|
| Send H1-H4 | 0.00 - 1.00 | Send level from each head to tape |
| Volume | 0.00 - 1.00 | Tape playback volume |
| Reverse | On/Off | Reverse tape playback |
| Mute | On/Off | Mute tape (1s fade) |

## MIDI Control

### Default CC Mapping - Head Parameters

| Parameter | Default CC |
|-----------|------------|
| Volume | CC 1 |
| Pitch | CC 2 |
| Pan | CC 3 |
| Filter LP/HP | CC 4 |
| Filter BP | CC 5 |
| Filter Q | CC 6 |
| Delay | CC 7 |
| Start | CC 8 |
| End | CC 9 |

### Default CC Mapping - Tape Parameters

| Parameter | Default CC |
|-----------|------------|
| Tape Send H1 | CC 10 |
| Tape Send H2 | CC 11 |
| Tape Send H3 | CC 12 |
| Tape Send H4 | CC 13 |
| Tape Volume | CC 14 |

### Default Note Mapping - Tape Actions

| Action | Default Note |
|--------|--------------|
| Tape Rec/Stop | C3 (60) |
| Tape Overdub | C#3 (61) |
| Tape Clear | D3 (62) |
| Tape Mute | D#3 (63) |
| Tape Reverse | E3 (64) |

*All MIDI mappings are configurable in the PARAMS menu*

## Parameters Menu

Access via **K1** on Norns:

### HeadLoop
- Pitch Mode (Semitones/Octaves)

### Reverb
- Enable/Disable
- Mix Level

### Delay
- Delay Time (0.01-2s)
- Feedback (0-0.95)
- Mix Level

### Overdub
- Overdub Level
- Overdub Feedback

### Clear Loop
- Clear Fade Time (0-5s)

### Tape FX
- Enable/Disable
- Wobble Amount
- Saturation Amount
- Age/Dropout Amount

### Tape Recorder
- Send Levels (H1-H4)
- Volume
- Length (10-300s)

### LFOs (1-4)
- Shape (Sine/Random)
- Speed (0.01-20 Hz)
- Depth (0-1)
- Destination (21 options)

### MIDI
- Device Selection
- CC Mappings
- Note Mappings

## Grid Layout

HeadLoop supports optional Monome Grid or Midigrid control. See the included **HeadLoop Grid Cheatsheet** for detailed grid workflow.

### Main Page (Grid Page 1)
- Row 1: Parameter selection
- Row 2: Head selection + transport controls
- Rows 3-6: Position display
- Row 7: Mute controls
- Row 8: Reverse controls + page switch

### Tape Page (Grid Page 2)
- Row 1: Send levels
- Row 2: Tape controls
- Rows 3-6: Tape position display
- Row 8: Return to main page

## Tips & Best Practices

- **Filter System**: BP filter takes priority when active. Use LP/HP for broad sweeps, BP for focused resonance.
- **Tape FX**: Start with subtle settings (0.1-0.3). Higher values create extreme effects.
- **LFO Modulation**: Use slow random LFOs on start/end positions for organic movement.
- **MIDI Performance**: Map frequently used parameters to your controller for expressive live performance.

## Known Issues

- Maximum 6 softcut voices means tape recorder uses voice 1 (cannot record main loop and tape simultaneously)
- Grid position display limited to 16 columns (grid resolution)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For questions, issues, or feature requests:
- Open an issue on GitHub
- Visit the [lines community](https://llllllll.co)


## Credits

Created for the Norns platform by EMHO

Special thanks to the Norns and lines community.

---

*HeadLoop v1.6 - A 4-head looper with tape recorder for Norns*
