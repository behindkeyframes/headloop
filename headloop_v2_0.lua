-- HeadLoop v2.0
-- 4-head looper + Tape Recorder
--
-- K2: Change active head (short press)
-- K2+K3: Change page (press/hold K2 press K3)
-- K3: Record
-- E1: Change param
-- E2/E3: Adjust val (coarse/fine)

local softcut = require("softcut")
local g = grid.connect()
local mg = util.file_exists(_path.code .. "midigrid") and include "midigrid/lib/mg_128" or nil
local midi_device = nil

-- Constants
local MAX_LOOP_TIME = 60
local BUFFER_1 = 1
local BUFFER_2 = 2
local MAIN_VOICE = 1
local TAPE_VOICE = 6
local NUM_HEADS = 4
local WAVEFORM_SAMPLES = 512

-- MIDI CC mapping for parameters (default values)
local midi_cc_map = {
  -- Head parameters (CC 1-32)
  head_volume = {1, 2, 3, 4},      -- CC 1-4 for heads 1-4 volume
  head_pitch = {5, 6, 7, 8},       -- CC 5-8 for heads 1-4 pitch
  head_pan = {9, 10, 11, 12},      -- CC 9-12 for heads 1-4 pan
  head_filter_lp_hp = {13, 14, 15, 16},  -- CC 13-16 for heads 1-4 LP/HP filter
  head_filter_bp = {17, 18, 19, 20},     -- CC 17-20 for heads 1-4 BP filter
  head_filter_q = {21, 22, 23, 24},      -- CC 21-24 for heads 1-4 filter Q
  head_start = {25, 26, 27, 28},   -- CC 25-28 for heads 1-4 start
  head_end = {29, 30, 31, 32},     -- CC 29-32 for heads 1-4 end
  
  -- Tape parameters (CC 33-40)
  tape_send = {33, 34, 35, 36},    -- CC 33-36 for tape sends 1-4
  tape_volume = 37,                 -- CC 37 for tape volume
  tape_pitch = 38,                  -- CC 38 for tape pitch
  
  -- Global parameters (CC 41-48)
  reverb_send = 41,                 -- CC 41 for reverb send
  reverb_mix = 42,                  -- CC 42 for reverb mix
  tape_wobble = 43,                 -- CC 43 for tape wobble
  tape_saturation = 44,             -- CC 44 for tape saturation
  tape_hiss = 45,                   -- CC 45 for tape hiss
  tape_age = 46,                    -- CC 46 for tape age
  loop_fade_in = 47,                -- CC 47 for loop fade in
  loop_fade_out = 48,               -- CC 48 for loop fade out
}

-- MIDI Note mapping for actions (default values)
local midi_note_map = {
  -- Main loop actions (notes 36-47 / C1-B1)
  rec_main = 36,                    -- C1: Record/Stop Main
  overdub_main = 37,                -- C#1: Overdub Main
  clear_main = 38,                  -- D1: Clear Main
  
  -- Head mutes (notes 40-43)
  mute_head_1 = 40,                 -- E1: Mute Head 1
  mute_head_2 = 41,                 -- F1: Mute Head 2
  mute_head_3 = 42,                 -- F#1: Mute Head 3
  mute_head_4 = 43,                 -- G1: Mute Head 4
  
  -- Head reverse (notes 44-47)
  reverse_head_1 = 44,              -- G#1: Reverse Head 1
  reverse_head_2 = 45,              -- A1: Reverse Head 2
  reverse_head_3 = 46,              -- A#1: Reverse Head 3
  reverse_head_4 = 47,              -- B1: Reverse Head 4
  
  -- Tape actions (notes 48-55 / C2-G#2)
  rec_tape = 48,                    -- C2: Record/Stop Tape
  overdub_tape = 49,                -- C#2: Overdub Tape
  clear_tape = 50,                  -- D2: Clear Tape
  reverse_tape = 51,                -- D#2: Reverse Tape
  mute_tape = 52,                   -- E2: Mute Tape
  
  -- Head selection (notes 60-63 / C3-D#3)
  select_head_1 = 60,               -- C3: Select Head 1
  select_head_2 = 61,               -- C#3: Select Head 2
  select_head_3 = 62,               -- D3: Select Head 3
  select_head_4 = 63,               -- D#3: Select Head 4
}

-- State
local recording = false
local loop_length = 0
local loop_exists = false
local active_head = 1
local active_param = 1
local rec_time = 0
local grid_device = nil
local k2_pressed = false
local k3_pressed = false
local k2_press_time = 0
local k3_press_time = 0
local k3_double_click_time = 0
local k3_double_click_threshold = 0.3
local pitch_mode = 1
local screen_page = 1

-- v2.7 OPTIMIZATION: Grid redraw throttling
local last_grid_redraw_time = 0
local grid_redraw_interval = 0.05  -- 20 FPS (50ms between redraws)

-- Waveform data
local waveform_data = {}
local tape_waveform_data = {}
local waveform_rendering = false
local tape_waveform_rendering = false

-- Message system
local message_text = ""
local message_time = 0
local message_duration = 2

-- Tape state
local tape_recording = false
local tape_overdubbing = false
local tape_playing = false
local tape_exists = false
local tape_position = 0
local tape_length_recorded = 0
local tape_buffer_start = 5
local tape_reverse = false
local tape_muted = false
local current_page = 1
local tape_page_param = 1
local tape_clock = nil

-- Tape FX state
local wobble_phase = 0
local wobble_freq = 0.5
local wobble_amount = 0
local tape_age_counter = 0

-- Crossfade state for Main loop
local loop_fade_in_time = 0.01  -- Default fade-in time in seconds
local loop_fade_out_time = 0.01  -- Default fade-out time in seconds

-- LFOs
local lfos = {}
for i = 1, 4 do
  lfos[i] = {
    phase = 0,
    value = 0,
    shape = 1,
    speed = 0.5,
    depth = 0,
    destination = 1,
    random_target = 0,
    random_current = 0
  }
end

-- LFO destinations
local lfo_destinations = {
  "None",
  "Vol 1", "Vol 2", "Vol 3", "Vol 4",
  "Pan 1", "Pan 2", "Pan 3", "Pan 4",
  "Start 1", "Start 2", "Start 3", "Start 4",
  "End 1", "End 2", "End 3", "End 4",
  "Pitch 1", "Pitch 2", "Pitch 3", "Pitch 4"
}

-- Parameters list
local params_list = {
  {name = "volume", min = 0, max = 2, default = 1.0},
  {name = "pitch", min = -24, max = 24, default = 0},
  {name = "pan", min = -1, max = 1, default = 0},
  {name = "filter_lp_hp", min = -1, max = 1, default = 0},
  {name = "filter_bp", min = 0, max = 1, default = 0},
  {name = "filter_q", min = 0.1, max = 4, default = 0.5},
  {name = "start", min = 0, max = 1, default = 0.0},
  {name = "end", min = 0, max = 1, default = 1.0},
}

-- Heads
local heads = {}
for i = 1, NUM_HEADS do
  heads[i] = {
    voice = i + 1,
    enabled = true,
    muted = false,
    reverse = false,
    volume = 1.0,
    pitch = 0,
    rate = 1.0,
    pan = (i - 2.5) * 0.4,
    filter_lp_hp = 0,
    filter_bp = 0,
    filter_q = 0.5,
    filter_freq = 12000,
    start = 0.0,
    ending = 1.0,
    position = 0.0
  }
end

-- Apply crossfade times to heads
function apply_loop_crossfade()
  if loop_exists then
    -- softcut.fade_time gère automatiquement le crossfade au point de bouclage
    -- Il crée une enveloppe qui fait un fade-out avant la fin et un fade-in après le début
    -- On utilise la valeur maximale des deux pour s'assurer qu'il y a assez de temps
    local fade_duration = math.max(loop_fade_in_time, loop_fade_out_time)
    
    for i = 1, NUM_HEADS do
      -- fade_time définit la durée du crossfade au point de bouclage
      softcut.fade_time(heads[i].voice, fade_duration)
      
      -- phase_offset définit où commence le crossfade avant la fin de la boucle
      -- Si loop_fade_out_time est différent de loop_fade_in_time, ajuster le offset
      local offset = -loop_fade_out_time
      softcut.phase_offset(heads[i].voice, offset)
    end
  end
end

-- Pitch functions
function pitch_to_rate(pitch_value)
  if pitch_mode == 2 then
    return 2 ^ pitch_value
  else
    return 2 ^ (pitch_value / 12)
  end
end

function get_pitch_range()
  if pitch_mode == 2 then
    return -2, 2
  else
    return -24, 24
  end
end

-- Message system
function show_message(text, duration)
  message_text = text
  message_time = util.time()
  message_duration = duration or 2
  redraw()
end

-- Waveform rendering
function render_waveform()
  if loop_length <= 0 then return end
  if waveform_rendering then return end
  waveform_rendering = true
  softcut.render_buffer(BUFFER_1, 0, loop_length, WAVEFORM_SAMPLES)
end

function render_tape_waveform()
  if tape_length_recorded <= 0 then return end
  if tape_waveform_rendering then return end
  tape_waveform_rendering = true
  softcut.render_buffer(2, tape_buffer_start, tape_length_recorded, WAVEFORM_SAMPLES)
end

function waveform_rendered(ch, start, dur, samples)
  if type(samples) == "table" then
    if ch == BUFFER_1 then
      waveform_data = samples
      waveform_rendering = false
    elseif ch == 2 then
      tape_waveform_data = samples
      tape_waveform_rendering = false
    end
    redraw()
  else
    waveform_rendering = false
    tape_waveform_rendering = false
  end
end

-- Position update - v2.7 OPTIMIZED with throttling
function update_positions(voice, position)
  -- Correct head index calculation (voice 2-5 → heads 1-4)
  if voice >= (MAIN_VOICE + 1) and voice <= (MAIN_VOICE + NUM_HEADS) then
    local head_index = voice - MAIN_VOICE  -- Correct: voice 2→head 1, voice 3→head 2, etc.
    
    -- Validate loop_length before normalization
    if loop_length > 0 then
      local normalized_pos = (position / loop_length)
      
      -- Clamp normalized position to [0, 1]
      normalized_pos = math.max(0, math.min(1, normalized_pos))
      heads[head_index].position = normalized_pos
      
      -- v2.7 OPTIMIZATION: Throttled grid redraw (20 FPS max)
      if grid_device then
        grid_redraw_throttled()
      end
    end
  elseif voice == TAPE_VOICE then
    if tape_length_recorded > 0 then
      tape_position = (position - tape_buffer_start) / tape_length_recorded
      tape_position = util.clamp(tape_position, 0, 1)
      if grid_device then
        grid_redraw_throttled()
      end
    end
  end
end

-- v2.7 OPTIMIZATION: Throttled grid redraw function
function grid_redraw_throttled()
  local current_time = util.time()
  if current_time - last_grid_redraw_time >= grid_redraw_interval then
    last_grid_redraw_time = current_time
    grid_redraw()
  end
end

-- Grid functions
function grid_redraw()
  if not grid_device then return end
  grid_device:all(0)

  if current_page == 1 then
    for i = 1, math.min(8, #params_list) do
      grid_device:led(i, 1, i == active_param and 15 or 4)
    end
    for i = 1, NUM_HEADS do
      grid_device:led(i, 2, i == active_head and 15 or 4)
    end
    grid_device:led(5, 2, recording and not loop_exists and 15 or 4)
    grid_device:led(6, 2, recording and loop_exists and 15 or loop_exists and 8 or 2)
    grid_device:led(7, 2, loop_exists and 10 or 2)
    grid_device:led(8, 2, 6)
    
    -- v2.7 OPTIMIZED: Simplified head position display (no trail effect)
    if loop_exists and loop_length > 0 then
      for i = 1, NUM_HEADS do
        local row = 2 + i  -- Row 3 for head 1, row 4 for head 2, etc.
        
        -- Clear entire row first
        for col = 1, 16 do
          grid_device:led(col, row, 0)
        end
        
        -- Validate position before displaying
        if heads[i].position and heads[i].position >= 0 and heads[i].position <= 1 then
          -- Calculate column position (1-16)
          local position_normalized = heads[i].position
          local pos_col = util.clamp(math.floor(position_normalized * 15.999) + 1, 1, 16)
          
          -- Determine brightness based on head state
          local brightness
          if heads[i].muted then
            brightness = 4  -- Dimmed if muted
          elseif i == active_head then
            brightness = 15  -- Very bright if active head
          else
            brightness = 10  -- Normal brightness
          end
          
          -- Single LED at current position (no trail effect)
          grid_device:led(pos_col, row, brightness)
        end
      end
    end
    
    for i = 1, NUM_HEADS do
      local brightness = heads[i].muted and 4 or 15
      if i == active_head then brightness = heads[i].muted and 8 or 15 end
      grid_device:led(i, 7, brightness)
    end
    for i = 1, NUM_HEADS do
      local brightness = heads[i].reverse and 15 or 4
      if i == active_head then brightness = heads[i].reverse and 15 or 8 end
      grid_device:led(i, 8, brightness)
    end
    grid_device:led(8, 8, 8)
  elseif current_page == 2 then
    for i = 1, 4 do
      local level = params:get("tape_send_" .. i)
      local brightness = util.round(level * 15)
      grid_device:led(i, 1, brightness)
    end
    local vol = params:get("tape_volume")
    grid_device:led(1, 2, util.round(vol * 15))
    grid_device:led(2, 2, tape_exists and 10 or 2)
    grid_device:led(3, 2, tape_recording and not tape_overdubbing and 15 or 4)
    grid_device:led(4, 2, tape_overdubbing and 15 or tape_exists and 8 or 2)
    grid_device:led(5, 2, tape_exists and 10 or 2)
    grid_device:led(6, 2, tape_reverse and 15 or 4)
    grid_device:led(7, 2, tape_muted and 4 or 15)
    
    -- v2.7 OPTIMIZED: Simplified tape position display (no trail effect)
    if tape_exists then
      -- Clear rows 3-6 first
      for row = 3, 6 do
        for col = 1, 16 do
          grid_device:led(col, row, 0)
        end
      end
      
      -- Calculate column position (1-16)
      local pos_col = util.clamp(math.floor(tape_position * 15.999) + 1, 1, 16)
      
      -- Determine brightness
      local brightness = tape_muted and 4 or 12
      
      -- Display on all 4 rows for better tape visibility (single LED per row)
      for row = 3, 6 do
        grid_device:led(pos_col, row, brightness)
      end
    end
    
    if tape_recording then
      for i = 1, 8 do
        grid_device:led(i, 7, (i % 2 == 0) and 8 or 4)
      end
    elseif tape_playing then
      for i = 1, 8 do
        grid_device:led(i, 7, 4)
      end
    end
    grid_device:led(1, 8, 8)
  end
  grid_device:refresh()
end

function grid_key(x, y, z)
  if z == 0 then return end
  if current_page == 1 then
    if y == 1 then
      active_param = util.clamp(x, 1, #params_list)
      redraw()
      grid_redraw()
    elseif y == 2 then
      if x >= 1 and x <= NUM_HEADS then
        active_head = x
        show_message("Head " .. active_head, 1)
        redraw()
        grid_redraw()
      elseif x == 5 then
        toggle_record()
      elseif x == 6 then
        if loop_exists then toggle_overdub() end
      elseif x == 7 then
        if loop_exists then clear_loop() end
      elseif x == 8 then
        reset_all_heads()
      end
    elseif y == 7 then
      if x >= 1 and x <= NUM_HEADS then
        toggle_mute(x)
      end
    elseif y == 8 then
      if x >= 1 and x <= NUM_HEADS then
        toggle_reverse(x)
      elseif x == 8 then
        current_page = 2
        screen_page = 2
        show_message("Tape Page", 1)
        grid_redraw()
        redraw()
      end
    end
  elseif current_page == 2 then
    if y == 1 then
      if x >= 1 and x <= 4 then
        local current = params:get("tape_send_" .. x)
        local new_value = (current + 0.1) % 1.1
        params:set("tape_send_" .. x, new_value)
        show_message(string.format("Send %d: %.2f", x, new_value), 1)
        grid_redraw()
        redraw()
      end
    elseif y == 2 then
      if x == 1 then
        local current = params:get("tape_volume")
        local new_value = (current + 0.2) % 2.1
        params:set("tape_volume", new_value)
        show_message(string.format("Volume: %.2f", new_value), 1)
        grid_redraw()
        redraw()
      elseif x == 3 then
        tape_toggle_record()
      elseif x == 4 then
        if tape_exists then tape_toggle_overdub() end
      elseif x == 5 then
        if tape_exists then tape_clear() end
      elseif x == 6 then
        tape_toggle_reverse()
      elseif x == 7 then
        tape_toggle_mute()
      end
    elseif y == 8 then
      if x == 1 then
        current_page = 1
        screen_page = 1
        show_message("Main Page", 1)
        grid_redraw()
        redraw()
      end
    end
  end
end

function init_grid()
  if g.device then
    grid_device = g
  elseif mg then
    grid_device = mg
  else
    return
  end
  grid_device.key = grid_key
  clock.run(function()
    clock.sleep(0.5)
    grid_redraw()
  end)
end

-- MIDI functions
function midi_event(data)
  local msg = midi.to_msg(data)
  
  -- Handle CC messages
  if msg.type == "cc" then
    handle_midi_cc(msg.cc, msg.val)
  
  -- Handle Note On messages
  elseif msg.type == "note_on" then
    handle_midi_note(msg.note, true)
  
  -- Handle Note Off messages
  elseif msg.type == "note_off" then
    handle_midi_note(msg.note, false)
  end
end

function handle_midi_cc(cc, val)
  local normalized = val / 127  -- Normalize to 0-1
  
  -- Head parameters
  for i = 1, NUM_HEADS do
    if cc == midi_cc_map.head_volume[i] then
      heads[i].volume = normalized * 2  -- 0-2 range
      update_head(i)
      return
    elseif cc == midi_cc_map.head_pitch[i] then
      local pitch_min, pitch_max = get_pitch_range()
      heads[i].pitch = util.linlin(0, 1, pitch_min, pitch_max, normalized)
      update_head(i)
      return
    elseif cc == midi_cc_map.head_pan[i] then
      heads[i].pan = util.linlin(0, 1, -1, 1, normalized)
      update_head(i)
      return
    elseif cc == midi_cc_map.head_filter_lp_hp[i] then
      heads[i].filter_lp_hp = util.linlin(0, 1, -1, 1, normalized)
      update_head(i)
      return
    elseif cc == midi_cc_map.head_filter_bp[i] then
      heads[i].filter_bp = normalized
      update_head(i)
      return
    elseif cc == midi_cc_map.head_filter_q[i] then
      heads[i].filter_q = util.linlin(0, 1, 0.1, 4, normalized)
      update_head(i)
      return
    elseif cc == midi_cc_map.head_start[i] then
      heads[i].start = normalized
      update_head(i)
      return
    elseif cc == midi_cc_map.head_end[i] then
      heads[i].ending = normalized
      update_head(i)
      return
    end
  end
  
  -- Tape parameters
  for i = 1, 4 do
    if cc == midi_cc_map.tape_send[i] then
      params:set("tape_send_" .. i, normalized)
      return
    end
  end
  
  if cc == midi_cc_map.tape_volume then
    params:set("tape_volume", normalized * 2)  -- 0-2 range
  elseif cc == midi_cc_map.tape_pitch then
    params:set("tape_pitch", util.linlin(0, 1, -24, 24, normalized))
  
  -- Global parameters
  elseif cc == midi_cc_map.reverb_send then
    params:set("reverb_send", normalized)
  elseif cc == midi_cc_map.reverb_mix then
    params:set("reverb_mix", normalized)
  elseif cc == midi_cc_map.tape_wobble then
    params:set("tape_wobble", normalized)
  elseif cc == midi_cc_map.tape_saturation then
    params:set("tape_saturation", normalized)
  elseif cc == midi_cc_map.tape_hiss then
    params:set("tape_hiss", normalized * 0.3)  -- 0-0.3 range
  elseif cc == midi_cc_map.tape_age then
    params:set("tape_age", normalized)
  elseif cc == midi_cc_map.loop_fade_in then
    params:set("loop_fade_in", util.linexp(0, 1, 0.001, 0.5, math.max(normalized, 0.001)))
  elseif cc == midi_cc_map.loop_fade_out then
    params:set("loop_fade_out", util.linexp(0, 1, 0.001, 0.5, math.max(normalized, 0.001)))
  end
  
  redraw()
end

function handle_midi_note(note, on)
  if not on then return end  -- Only respond to note on
  
  -- Main loop actions
  if note == midi_note_map.rec_main then
    toggle_record()
  elseif note == midi_note_map.overdub_main then
    if loop_exists then toggle_overdub() end
  elseif note == midi_note_map.clear_main then
    if loop_exists then clear_loop() end
  
  -- Head mutes
  elseif note == midi_note_map.mute_head_1 then
    toggle_mute(1)
  elseif note == midi_note_map.mute_head_2 then
    toggle_mute(2)
  elseif note == midi_note_map.mute_head_3 then
    toggle_mute(3)
  elseif note == midi_note_map.mute_head_4 then
    toggle_mute(4)
  
  -- Head reverse
  elseif note == midi_note_map.reverse_head_1 then
    toggle_reverse(1)
  elseif note == midi_note_map.reverse_head_2 then
    toggle_reverse(2)
  elseif note == midi_note_map.reverse_head_3 then
    toggle_reverse(3)
  elseif note == midi_note_map.reverse_head_4 then
    toggle_reverse(4)
  
  -- Tape actions
  elseif note == midi_note_map.rec_tape then
    tape_toggle_record()
  elseif note == midi_note_map.overdub_tape then
    if tape_exists then tape_toggle_overdub() end
  elseif note == midi_note_map.clear_tape then
    if tape_exists then tape_clear() end
  elseif note == midi_note_map.reverse_tape then
    tape_toggle_reverse()
  elseif note == midi_note_map.mute_tape then
    tape_toggle_mute()
  
  -- Head selection
  elseif note == midi_note_map.select_head_1 then
    active_head = 1
    show_message("Head 1", 1)
    grid_redraw()
  elseif note == midi_note_map.select_head_2 then
    active_head = 2
    show_message("Head 2", 1)
    grid_redraw()
  elseif note == midi_note_map.select_head_3 then
    active_head = 3
    show_message("Head 3", 1)
    grid_redraw()
  elseif note == midi_note_map.select_head_4 then
    active_head = 4
    show_message("Head 4", 1)
    grid_redraw()
  end
end

-- Toggle functions
function toggle_mute(head)
  heads[head].muted = not heads[head].muted
  update_head(head)
  
  -- MODIFICATION 2: Vérifier si toutes les têtes sont mutées
  check_all_heads_muted()
  
  show_message("Head " .. head .. " " .. (heads[head].muted and "MUTED" or "UNMUTED"), 1)
  grid_redraw()
end

-- MODIFICATION 2: Nouvelle fonction pour vérifier si toutes les têtes sont mutées
function check_all_heads_muted()
  if not loop_exists then return end
  
  local all_muted = true
  for i = 1, NUM_HEADS do
    if not heads[i].muted then
      all_muted = false
      break
    end
  end
  
  -- Si toutes les têtes sont mutées, muter aussi MAIN_VOICE
  if all_muted then
    softcut.level(MAIN_VOICE, 0)
  end
end

function toggle_reverse(head)
  heads[head].reverse = not heads[head].reverse
  update_head(head)
  show_message("Head " .. head .. " " .. (heads[head].reverse and "REVERSE" or "FORWARD"), 1)
  grid_redraw()
end

function reset_all_heads()
  for i = 1, NUM_HEADS do
    softcut.position(heads[i].voice, 0)
    heads[i].position = 0
  end
  show_message("All heads reset", 1)
  grid_redraw()
end

-- Apply global tape FX to a specific voice
function apply_tape_fx_to_voice(voice)
  local sat = params:get("tape_saturation")
  local hiss = params:get("tape_hiss")
  
  -- Determine filter frequency based on both effects
  local fc = 12000  -- Default neutral
  
  if sat > 0 and hiss == 0 then
    -- Pure saturation: LP filter to cut highs
    fc = util.linexp(0.01, 1, 20000, 800, math.max(sat, 0.01))
    local wet = sat * 0.6
    softcut.pre_filter_lp(voice, wet)
    softcut.pre_filter_hp(voice, 0)
    softcut.pre_filter_fc(voice, fc)
    softcut.pre_filter_dry(voice, 1.0 - (wet * 0.5))
  elseif hiss > 0 and sat == 0 then
    -- Pure hiss: HP filter to boost highs
    fc = util.linexp(0.01, 0.3, 8000, 14000, math.max(hiss, 0.01))
    local wet = hiss * 0.4
    softcut.pre_filter_hp(voice, wet)
    softcut.pre_filter_lp(voice, 0)
    softcut.pre_filter_fc(voice, fc)
    softcut.pre_filter_dry(voice, 1.0)
  elseif sat > 0 and hiss > 0 then
    -- Both active: balance between LP and HP
    -- Saturation dominates the low end, hiss adds highs
    fc = 10000  -- Middle ground
    local sat_wet = sat * 0.4  -- Reduced to avoid conflict
    local hiss_wet = hiss * 0.3
    softcut.pre_filter_lp(voice, sat_wet)
    softcut.pre_filter_hp(voice, hiss_wet)
    softcut.pre_filter_fc(voice, fc)
    softcut.pre_filter_dry(voice, 1.0 - (sat_wet * 0.3))
  else
    -- No effects active: full dry, reset all pre_filters
    softcut.pre_filter_dry(voice, 1.0)
    softcut.pre_filter_lp(voice, 0)
    softcut.pre_filter_hp(voice, 0)
    softcut.pre_filter_fc(voice, 12000)
  end
end

-- FIXED: Update head with corrected filter implementation
function update_head(head_idx)
  local h = heads[head_idx]
  local v = h.voice
  if loop_exists then
    softcut.level(v, h.muted and 0 or h.volume)
    softcut.pan(v, h.pan)
    
    -- Apply global tape FX first
    apply_tape_fx_to_voice(v)
    
    -- FIXED: Proper filter implementation
    -- LP = turn LEFT (negative values), HP = turn RIGHT (positive values)
    if h.filter_bp > 0.1 then
      -- Band-pass filter active
      local wet = util.linlin(0.1, 1, 0.3, 1.0, h.filter_bp)
      softcut.post_filter_dry(v, 1.0 - wet)
      softcut.post_filter_lp(v, 0)
      softcut.post_filter_hp(v, 0)
      softcut.post_filter_bp(v, wet)
      local freq = util.linexp(0.1, 1, 200, 8000, h.filter_bp)
      softcut.post_filter_fc(v, freq)
      softcut.post_filter_rq(v, h.filter_q)
    elseif h.filter_lp_hp < -0.1 then
      -- Low-pass filter active (turn LEFT, negative values)
      -- LP range: 13 kHz (at -0.1) → 90 Hz (at -1.0)
      local wet = util.linlin(-1, -0.1, 1.0, 0.3, h.filter_lp_hp)
      softcut.post_filter_dry(v, 1.0 - wet)
      softcut.post_filter_hp(v, 0)
      softcut.post_filter_bp(v, 0)
      softcut.post_filter_lp(v, wet)
      local freq = util.linexp(-1, -0.1, 90, 13000, h.filter_lp_hp)
      softcut.post_filter_fc(v, freq)
      softcut.post_filter_rq(v, h.filter_q)
    elseif h.filter_lp_hp > 0.1 then
      -- High-pass filter active (turn RIGHT, positive values)
      -- HP range: 51 Hz (at 0.1) → 8 kHz (at 1.0)
      local wet = util.linlin(0.1, 1, 0.3, 1.0, h.filter_lp_hp)
      softcut.post_filter_dry(v, 1.0 - wet)
      softcut.post_filter_lp(v, 0)
      softcut.post_filter_bp(v, 0)
      softcut.post_filter_hp(v, wet)
      local freq = util.linexp(0.1, 1, 51, 8000, h.filter_lp_hp)
      softcut.post_filter_fc(v, freq)
      softcut.post_filter_rq(v, h.filter_q)
    else
      -- No filter, full dry signal
      softcut.post_filter_dry(v, 1.0)
      softcut.post_filter_lp(v, 0)
      softcut.post_filter_hp(v, 0)
      softcut.post_filter_bp(v, 0)
    end
    
    h.rate = pitch_to_rate(h.pitch)
    local final_rate = h.reverse and -h.rate or h.rate
    softcut.rate(v, final_rate)
    local start_pos = h.start * loop_length
    local end_pos = h.ending * loop_length
    softcut.loop_start(v, start_pos)
    softcut.loop_end(v, end_pos)
  end
end

-- Recording functions
function toggle_record()
  if recording then
    stop_recording()
  elseif not loop_exists then
    start_recording()
  else
    show_message("Use OVERDUB, not REC", 1)
  end
end

function start_recording()
  if loop_exists then
    show_message("ERROR: Loop exists, use OVERDUB", 2)
    return
  end
  if tape_recording or tape_playing then
    if tape_recording then
      if tape_overdubbing then
        stop_tape_overdub()
      else
        stop_tape_recording()
      end
    end
    tape_playing = false
  end
  softcut.buffer(1, BUFFER_1)
  softcut.loop_start(1, 0)
  softcut.loop_end(1, MAX_LOOP_TIME)
  softcut.loop(1, 0)
  softcut.pre_level(1, 0)
  softcut.rec_level(1, 1)
  -- MODIFICATION 2: MAIN_VOICE level reste à 0 (pas de lecture)
  softcut.level(1, 0)
  recording = true
  rec_time = util.time()
  loop_length = 0
  softcut.rec(1, 1)
  -- MODIFICATION 2: Play activé pour l'enregistrement mais level à 0
  softcut.play(1, 1)
  softcut.position(1, 0)
  for i = 1, NUM_HEADS do
    softcut.play(heads[i].voice, 0)
  end
  show_message("RECORDING", 2)
  grid_redraw()
  redraw()
end

function stop_recording()
  if recording and not loop_exists then
    recording = false
    loop_length = util.clamp(util.time() - rec_time, 0.1, MAX_LOOP_TIME)
    softcut.rec(1, 0)
    -- MODIFICATION 2: Désactiver la lecture de MAIN_VOICE après l'enregistrement
    softcut.play(1, 0)
    softcut.loop(1, 1)
    softcut.loop_end(1, loop_length)
    loop_exists = true
    
    -- Appliquer le crossfade à la nouvelle boucle
    apply_loop_crossfade()
    
    for i = 1, NUM_HEADS do
      local v = heads[i].voice
      heads[i].start = 0.0
      heads[i].ending = 1.0
      heads[i].pitch = 0
      heads[i].rate = 1.0
      heads[i].muted = false
      heads[i].reverse = false
      heads[i].volume = 1.0
      heads[i].pan = (i - 2.5) * 0.4
      heads[i].filter_lp_hp = 0
      heads[i].filter_bp = 0
      heads[i].filter_q = 0.5
      softcut.loop(v, 1)
      softcut.loop_start(v, 0)
      softcut.loop_end(v, loop_length)
      softcut.position(v, 0)
      update_head(i)
      -- Apply global tape FX
      apply_tape_fx_to_voice(v)
      softcut.play(v, 1)
    end
    clock.run(function()
      clock.sleep(0.1)
      render_waveform()
    end)
    show_message("Loop saved: " .. string.format("%.1fs", loop_length), 2)
  elseif recording and loop_exists then
    recording = false
    softcut.rec_level(1, 0.0)
    softcut.pre_level(1, 1.0)
    -- MODIFICATION 2: Désactiver la lecture de MAIN_VOICE après overdub
    softcut.play(1, 0)
    clock.run(function()
      clock.sleep(0.1)
      render_waveform()
    end)
    show_message("Overdub stopped", 1)
  end
  grid_redraw()
  redraw()
end

function toggle_overdub()
  if loop_exists then
    if recording then
      stop_recording()
    else
      recording = true
      softcut.rec(1, 1)
      -- MODIFICATION 2: Play activé pour overdub mais level reste à 0
      softcut.play(1, 1)
      softcut.level(1, 0)
      local overdub_level = params:get("overdub_level")
      local feedback = params:get("overdub_feedback")
      softcut.rec_level(1, overdub_level)
      softcut.pre_level(1, feedback)
      softcut.loop(1, 1)
      softcut.loop_start(1, 0)
      softcut.loop_end(1, loop_length)
      show_message("OVERDUBBING", 2)
      grid_redraw()
      redraw()
    end
  end
end

function clear_loop()
  if loop_exists then
    local fade_time = params:get("clear_fade_time")
    show_message("Clearing loop...", fade_time)

    for i = 1, NUM_HEADS do
      softcut.level_slew_time(heads[i].voice, fade_time)
      softcut.level(heads[i].voice, 0)
    end

    -- MODIFICATION 2: Assurer que MAIN_VOICE est bien désactivée
    softcut.level_slew_time(MAIN_VOICE, fade_time)
    softcut.level(MAIN_VOICE, 0)

    clock.run(function()
      clock.sleep(fade_time)

      for i = 1, NUM_HEADS do
        softcut.play(heads[i].voice, 0)
        softcut.rec(heads[i].voice, 0)
        heads[i].position = 0
      end

      -- MODIFICATION 2: Désactiver complètement MAIN_VOICE
      softcut.play(MAIN_VOICE, 0)
      softcut.rec(MAIN_VOICE, 0)

      for i = 1, NUM_HEADS do
        local v = heads[i].voice
        softcut.pre_level(v, 0)
        softcut.rec_level(v, 0)
        softcut.loop_start(v, 0)
        softcut.loop_end(v, MAX_LOOP_TIME)
        softcut.loop(v, 0)
        heads[i].start = 0.0
        heads[i].ending = 1.0
        heads[i].pitch = 0
        heads[i].rate = 1.0
        heads[i].muted = false
        heads[i].reverse = false
        heads[i].volume = 1.0
        heads[i].pan = (i - 2.5) * 0.4
        heads[i].filter_lp_hp = 0
        heads[i].filter_bp = 0
        heads[i].filter_q = 0.5
      end

      softcut.pre_level(MAIN_VOICE, 0)
      softcut.rec_level(MAIN_VOICE, 0)
      softcut.loop_start(MAIN_VOICE, 0)
      softcut.loop_end(MAIN_VOICE, MAX_LOOP_TIME)
      softcut.loop(MAIN_VOICE, 0)

      softcut.buffer_clear_region(BUFFER_1, 0, loop_length)

      loop_exists = false
      loop_length = 0
      recording = false
      waveform_data = {}

      for i = 1, NUM_HEADS do
        softcut.level_slew_time(heads[i].voice, 0.05)
      end
      softcut.level_slew_time(MAIN_VOICE, 0.1)

      show_message("Loop cleared", 2)
      grid_redraw()
      redraw()
    end)
  end
end

-- Tape functions
function tape_toggle_record()
  if tape_recording then
    stop_tape_recording()
  elseif not tape_exists then
    start_tape_recording()
  else
    show_message("Use TAPE OVERDUB, not REC", 1)
  end
end

function start_tape_recording()
  if tape_exists then
    show_message("ERROR: Tape exists, use OVERDUB", 2)
    return
  end
  if recording then
    stop_recording()
  end
  softcut.buffer(TAPE_VOICE, BUFFER_2)
  softcut.loop_start(TAPE_VOICE, tape_buffer_start)
  softcut.loop_end(TAPE_VOICE, tape_buffer_start + MAX_LOOP_TIME)
  softcut.loop(TAPE_VOICE, 0)
  softcut.pre_level(TAPE_VOICE, 0)
  softcut.rec_level(TAPE_VOICE, 1)
  softcut.level(TAPE_VOICE, 1.0)
  
  -- MODIFICATION 1: Configuration des tape sends (uniquement des heads vers la tape)
  -- PAS de level_input_cut pour TAPE_VOICE (pas d'enregistrement direct du signal IN)
  for i = 1, NUM_HEADS do
    local send = params:get("tape_send_" .. i)
    softcut.level_cut_cut(heads[i].voice, TAPE_VOICE, send)
  end
  
  tape_recording = true
  rec_time = util.time()
  softcut.rec(TAPE_VOICE, 1)
  softcut.play(TAPE_VOICE, 1)
  softcut.position(TAPE_VOICE, tape_buffer_start)
  show_message("TAPE REC", 2)
  grid_redraw()
  redraw()
end

function stop_tape_recording()
  if tape_recording and not tape_exists then
    tape_length_recorded = util.clamp(util.time() - rec_time, 0.1, MAX_LOOP_TIME)
    softcut.rec(TAPE_VOICE, 0)
    softcut.loop(TAPE_VOICE, 1)
    softcut.loop_end(TAPE_VOICE, tape_buffer_start + tape_length_recorded)
    softcut.position(TAPE_VOICE, tape_buffer_start)
    softcut.play(TAPE_VOICE, 1)
    tape_exists = true
    tape_recording = false
    tape_playing = true
    
    -- Apply global tape FX to tape voice
    apply_tape_fx_to_voice(TAPE_VOICE)
    
    clock.run(function()
      clock.sleep(0.1)
      render_tape_waveform()
    end)
    show_message("Tape saved: " .. string.format("%.1fs", tape_length_recorded), 2)
  elseif tape_recording and tape_exists then
    tape_recording = false
    tape_overdubbing = false
    softcut.rec(TAPE_VOICE, 0)
    softcut.rec_level(TAPE_VOICE, 0.0)
    softcut.pre_level(TAPE_VOICE, 1.0)
    tape_playing = true
    softcut.play(TAPE_VOICE, 1)
    clock.run(function()
      clock.sleep(0.1)
      render_tape_waveform()
    end)
    show_message("Tape overdub stopped", 1)
  end
  grid_redraw()
  redraw()
end

function tape_toggle_overdub()
  if tape_exists then
    if tape_overdubbing then
      stop_tape_recording()
    else
      tape_recording = true
      tape_overdubbing = true
      softcut.rec(TAPE_VOICE, 1)
      softcut.play(TAPE_VOICE, 1)
      local overdub_level = params:get("overdub_level")
      local feedback = params:get("overdub_feedback")
      softcut.rec_level(TAPE_VOICE, overdub_level)
      softcut.pre_level(TAPE_VOICE, feedback)
      show_message("TAPE OVERDUB", 2)
      grid_redraw()
      redraw()
    end
  end
end

function stop_tape_overdub()
  tape_recording = false
  tape_overdubbing = false
  softcut.rec(TAPE_VOICE, 0)
  softcut.rec_level(TAPE_VOICE, 0)
  softcut.pre_level(TAPE_VOICE, 1)
end

function tape_clear()
  if tape_exists then
    local fade_time = 1
    show_message("Clearing tape...", fade_time)

    softcut.level_slew_time(TAPE_VOICE, fade_time)
    softcut.level(TAPE_VOICE, 0)

    clock.run(function()
      clock.sleep(fade_time)

      softcut.play(TAPE_VOICE, 0)
      softcut.rec(TAPE_VOICE, 0)

      softcut.pre_level(TAPE_VOICE, 0)
      softcut.rec_level(TAPE_VOICE, 0)
      softcut.loop_start(TAPE_VOICE, 0)
      softcut.loop_end(TAPE_VOICE, MAX_LOOP_TIME)
      softcut.loop(TAPE_VOICE, 0)

      for i = 1, NUM_HEADS do
        softcut.level_cut_cut(heads[i].voice, TAPE_VOICE, 0)
      end

      softcut.buffer_clear_region(BUFFER_2, tape_buffer_start, tape_length_recorded)

      tape_exists = false
      tape_length_recorded = 0
      tape_recording = false
      tape_overdubbing = false
      tape_playing = false
      tape_position = 0
      tape_waveform_data = {}

      softcut.level_slew_time(TAPE_VOICE, 0.1)

      show_message("Tape cleared", 2)
      grid_redraw()
      redraw()
    end)
  end
end

function tape_toggle_reverse()
  tape_reverse = not tape_reverse
  local pitch = params:get("tape_pitch")
  local rate_multiplier = 2 ^ (pitch / 12)
  local rate = (tape_reverse and -1 or 1) * rate_multiplier
  softcut.rate(TAPE_VOICE, rate)
  show_message("Tape " .. (tape_reverse and "REVERSE" or "FORWARD"), 1)
  grid_redraw()
  redraw()
end

function tape_toggle_mute()
  tape_muted = not tape_muted
  softcut.level_slew_time(TAPE_VOICE, 1.0)
  local volume = tape_muted and 0 or params:get("tape_volume")
  softcut.level(TAPE_VOICE, volume)
  clock.run(function()
    clock.sleep(1.1)
    softcut.level_slew_time(TAPE_VOICE, 0.1)
  end)
  show_message("Tape " .. (tape_muted and "MUTED" or "UNMUTED"), 1)
  grid_redraw()
  redraw()
end

-- FIXED: Tape FX processing - affects ALL output voices (global mix)
function update_tape_fx()
  local wobble = params:get("tape_wobble")
  local age = params:get("tape_age")
  
  -- Wobble: modulate pitch of ALL voices with LFO
  if wobble > 0 then
    wobble_phase = wobble_phase + (wobble_freq / 30)
    if wobble_phase >= 1 then 
      wobble_phase = wobble_phase - 1
      wobble_freq = 0.3 + math.random() * 0.4  -- Random LFO frequency
    end
    wobble_amount = math.sin(wobble_phase * math.pi * 2) * wobble * 0.05
    
    -- Apply wobble to all playback heads
    if loop_exists then
      for i = 1, NUM_HEADS do
        local h = heads[i]
        if not h.muted then
          local base_rate = h.rate
          local wobbled_rate = base_rate * (1 + wobble_amount)
          local final_rate = h.reverse and -wobbled_rate or wobbled_rate
          softcut.rate(h.voice, final_rate)
        end
      end
    end
    
    -- Apply wobble to tape
    if tape_exists and tape_playing then
      local base_pitch = params:get("tape_pitch")
      local modulated_pitch = base_pitch + (wobble_amount * 12)
      local rate_multiplier = 2 ^ (modulated_pitch / 12)
      local current_direction = tape_reverse and -1 or 1
      softcut.rate(TAPE_VOICE, rate_multiplier * current_direction)
    end
  end
  
  -- Age: random dropouts affecting ALL voices
  if age > 0 then
    tape_age_counter = tape_age_counter + 1
    if tape_age_counter > 30 then
      tape_age_counter = 0
      if math.random() < (age * 0.1) then
        -- Brief dropout on all voices
        local dropout_duration = 0.02 + math.random() * 0.05
        
        -- Store current levels and mute all
        local stored_levels = {}
        for i = 1, NUM_HEADS do
          if loop_exists and not heads[i].muted then
            stored_levels[i] = heads[i].volume
            softcut.level_slew_time(heads[i].voice, 0.01)
            softcut.level(heads[i].voice, 0)
          end
        end
        if tape_exists and tape_playing and not tape_muted then
          stored_levels[TAPE_VOICE] = params:get("tape_volume")
          softcut.level_slew_time(TAPE_VOICE, 0.01)
          softcut.level(TAPE_VOICE, 0)
        end
        
        -- Restore levels after dropout
        clock.run(function()
          clock.sleep(dropout_duration)
          for i = 1, NUM_HEADS do
            if stored_levels[i] then
              softcut.level_slew_time(heads[i].voice, 0.05)
              softcut.level(heads[i].voice, stored_levels[i])
            end
          end
          if stored_levels[TAPE_VOICE] then
            softcut.level_slew_time(TAPE_VOICE, 0.05)
            softcut.level(TAPE_VOICE, stored_levels[TAPE_VOICE])
          end
        end)
      end
    end
  end
end

-- Parameter updates
function update_head_param(head, param_name, value)
  local h = heads[head]
  if param_name == "end" then
    h.ending = value
  else
    h[param_name] = value
  end
  update_head(head)
  redraw()
end

-- Encoder
function enc(n, d)
  if screen_page == 1 then
    if n == 1 then
      active_param = util.clamp(active_param + d, 1, #params_list)
      redraw()
      grid_redraw()
    elseif n == 2 or n == 3 then
      local param = params_list[active_param]
      local h = heads[active_head]
      local current = param.name == "end" and h.ending or h[param.name]
      local delta = n == 2 and 0.1 or 0.01
      local new_value
      if param.name == "pitch" then
        new_value = util.clamp(current + d, param.min, param.max)
        new_value = math.floor(new_value + 0.5)
      else
        new_value = util.clamp(current + d * delta * (param.max - param.min), param.min, param.max)
      end
      update_head_param(active_head, param.name, new_value)
    end
  elseif screen_page == 2 then
    if n == 1 then
      tape_page_param = util.clamp(tape_page_param + d, 1, 8)
      redraw()
    elseif n == 2 or n == 3 then
      local delta = n == 2 and 1 or 0.1
      if tape_page_param == 6 then
        local current_pitch = params:get("tape_pitch")
        params:set("tape_pitch", util.clamp(current_pitch + d * delta, -24, 24))
      elseif tape_page_param == 5 then
        local current_volume = params:get("tape_volume")
        params:set("tape_volume", util.clamp(current_volume + d * delta, 0, 2))
      elseif tape_page_param == 7 then
        if d ~= 0 then tape_toggle_reverse() end
      elseif tape_page_param == 8 then
        if d ~= 0 then tape_toggle_mute() end
      elseif tape_page_param >= 1 and tape_page_param <= 4 then
        local current = params:get("tape_send_" .. tape_page_param)
        params:set("tape_send_" .. tape_page_param, util.clamp(current + d * delta, 0, 1))
      end
      redraw()
      grid_redraw()
    end
  end
end

-- Keys
function key(n, z)
  if n == 2 then
    k2_pressed = (z == 1)
    if z == 1 then
      k2_press_time = util.time()
    else
      local k2_duration = util.time() - k2_press_time
      if k3_pressed and k2_duration < 0.5 then
        screen_page = screen_page == 1 and 2 or 1
        show_message(screen_page == 1 and "Main Page" or "Tape Page", 1)
        redraw()
      elseif not k3_pressed and k2_duration < 0.3 and screen_page == 1 then
        active_head = (active_head % NUM_HEADS) + 1
        show_message("Head " .. active_head, 1)
        redraw()
        grid_redraw()
      end
    end
  elseif n == 3 then
    k3_pressed = (z == 1)
    if z == 1 then
      k3_press_time = util.time()
    else
      local press_duration = util.time() - k3_press_time
      if k2_pressed and press_duration < 0.5 then
        screen_page = screen_page == 1 and 2 or 1
        show_message(screen_page == 1 and "Main Page" or "Tape Page", 1)
        redraw()
      elseif not k2_pressed then
        if press_duration > 1.0 then
          if screen_page == 1 then
            clear_loop()
          else
            tape_clear()
          end
        elseif util.time() - k3_double_click_time < k3_double_click_threshold then
          if screen_page == 1 then
            toggle_overdub()
          else
            tape_toggle_overdub()
          end
          k3_double_click_time = 0
        else
          if screen_page == 1 then
            toggle_record()
          else
            tape_toggle_record()
          end
          k3_double_click_time = util.time()
        end
      end
    end
  end
end

-- Draw waveform
function draw_waveform(data, x, y, w, h, positions)
  if #data == 0 then return end
  screen.level(2)
  screen.rect(x, y, w, h)
  screen.stroke()
  screen.level(3)
  local center_y = y + h / 2
  screen.move(x, center_y)
  screen.line(x + w, center_y)
  screen.stroke()
  screen.level(6)
  for i = 1, #data do
    local sample_x = x + ((i - 1) / (#data - 1)) * w
    local sample_amp = data[i] * (h / 2)
    local sample_y = center_y - sample_amp
    if i == 1 then
      screen.move(sample_x, sample_y)
    else
      screen.line(sample_x, sample_y)
    end
  end
  screen.stroke()
  if positions and loop_exists then
    for i = 1, NUM_HEADS do
      if heads[i].enabled and not heads[i].muted then
        local head_x = x + heads[i].position * w
        screen.level(i == active_head and 15 or 8)
        screen.move(head_x, y)
        screen.line(head_x, y + h)
        screen.stroke()
        -- Afficher le numéro de la tête au-dessus du marqueur
        -- Utiliser temporairement font_size 8 pour les numéros
        local current_size = 8  -- Taille par défaut
        screen.move(head_x, y - 2)
        screen.text_center(tostring(i))
      end
    end
  end
end

-- Redraw
function redraw()
  screen.clear()
  if util.time() - message_time < message_duration then
    screen.level(15)
    screen.move(64, 8)
    screen.font_size(8)
    screen.text_center(message_text)
  end
  if screen_page == 1 then
    draw_main_page()
  else
    draw_tape_page()
  end
  screen.update()
end

function draw_main_page()
  local h = heads[active_head]
  
  -- Réinitialiser la taille de police par défaut
  screen.font_size(8)
  
  screen.level(15)
  screen.move(0, 10)
  screen.text("H" .. active_head)
  screen.move(12, 10)
  if loop_exists then
    local rec_status = recording and " OD" or ""
    screen.text(string.format("%.1fs%s", loop_length, rec_status))
  else
    -- Afficher le temps d'enregistrement en cours
    if recording then
      local elapsed = util.time() - rec_time
      screen.text(string.format("REC %.1fs", elapsed))
    else
      screen.text("---")
    end
  end
  -- Waveform à 15px de hauteur
  if loop_exists and #waveform_data > 0 then
    draw_waveform(waveform_data, 2, 14, 124, 15, true)
  else
    screen.level(2)
    screen.rect(2, 14, 124, 15)
    screen.stroke()
    screen.level(4)
    screen.move(64, 22)  -- Recentré verticalement (14 + 15/2 ≈ 22)
    if loop_exists then
      screen.text_center("rendering...")
    else
      screen.text_center("no loop")
    end
  end
  
  -- Paramètres avec police 8px (7.5px n'est pas supporté)
  screen.font_size(8)
  local y_start = 36  -- Baissé de 2px (était 34)
  local line_height = 9
  local col1_x = 2
  local col2_x = 66
  local display_params = {
    {name = "VOL", value = string.format("%.2f", h.volume)},
    {name = "PIT", value = string.format("%+d", h.pitch)},
    {name = "PAN", value = string.format("%.2f", h.pan)},
    {name = "LP/HP", value = string.format("%.2f", h.filter_lp_hp)},
    {name = "BP", value = string.format("%.2f", h.filter_bp)},
    {name = "Q", value = string.format("%.2f", h.filter_q)},
    {name = "START", value = string.format("%.2f", h.start)},
    {name = "END", value = string.format("%.2f", h.ending)},
  }
  for i = 1, 4 do
    local y = y_start + (i - 1) * line_height
    local param_index = i
    local param = display_params[param_index]
    if param_index == active_param then
      screen.level(15)
      screen.rect(col1_x - 2, y - 8, 58, line_height)  -- Réduit de 2px (était line_height + 2)
      screen.fill()
      screen.level(0)
    else
      screen.level(8)
    end
    screen.move(col1_x, y)
    screen.text(param.name)
    if param_index == active_param then
      screen.level(0)
    else
      screen.level(15)
    end
    screen.move(col1_x + 32, y)
    screen.text(param.value)
    param_index = i + 4
    param = display_params[param_index]
    if param_index == active_param then
      screen.level(15)
      screen.rect(col2_x - 2, y - 8, 58, line_height)  -- Réduit de 2px (était line_height + 2)
      screen.fill()
      screen.level(0)
    else
      screen.level(8)
    end
    screen.move(col2_x, y)
    screen.text(param.name)
    if param_index == active_param then
      screen.level(0)
    else
      screen.level(15)
    end
    screen.move(col2_x + 32, y)
    screen.text(param.value)
  end
end

function draw_tape_page()
  -- Réinitialiser la taille de police par défaut
  screen.font_size(8)
  
  screen.level(15)
  screen.move(0, 10)
  screen.text("TAPE")
  if tape_exists then
    local status = ""
    if tape_recording then
      status = tape_overdubbing and " OD" or " REC"
    elseif tape_playing then
      status = " PLAY"
    end
    screen.text(string.format(" %.1fs%s", tape_length_recorded, status))
  else
    -- Afficher le temps d'enregistrement en cours pour la tape
    if tape_recording then
      local elapsed = util.time() - rec_time
      screen.text(string.format(" REC %.1fs", elapsed))
    else
      screen.text(" ---")
    end
  end
  
  -- Waveform à 15px de hauteur
  if tape_exists and #tape_waveform_data > 0 then
    draw_waveform(tape_waveform_data, 2, 14, 124, 15, false)
    local head_x = 2 + (tape_position * 124)
    screen.level(15)
    screen.move(head_x, 14)
    screen.line(head_x, 29)  -- Ajusté pour la nouvelle hauteur
    screen.stroke()
  else
    screen.level(2)
    screen.rect(2, 14, 124, 15)
    screen.stroke()
    screen.level(4)
    screen.move(64, 22)  -- Recentré verticalement (14 + 15/2 ≈ 22)
    if tape_exists then
      screen.text_center("rendering...")
    else
      screen.text_center("no tape")
    end
  end
  
  -- Paramètres avec police 8px (7.5px n'est pas supporté)
  screen.font_size(8)
  local y_start = 36  -- Baissé de 2px (était 34)
  local line_height = 9
  local col1_x = 2
  local col2_x = 66
  local tape_params = {
    {name = "S1", value = string.format("%.2f", params:get("tape_send_1"))},
    {name = "S2", value = string.format("%.2f", params:get("tape_send_2"))},
    {name = "S3", value = string.format("%.2f", params:get("tape_send_3"))},
    {name = "S4", value = string.format("%.2f", params:get("tape_send_4"))},
    {name = "VOL", value = string.format("%.2f", params:get("tape_volume"))},
    {name = "PIT", value = string.format("%+d", params:get("tape_pitch"))},
    {name = "REV", value = tape_reverse and "ON" or "OFF"},
    {name = "MUT", value = tape_muted and "ON" or "OFF"}
  }
  for i = 1, 4 do
    local y = y_start + (i - 1) * line_height
    local param_index = i
    local param = tape_params[param_index]
    if param_index == tape_page_param then
      screen.level(15)
      screen.rect(col1_x - 2, y - 8, 58, line_height)  -- Réduit de 2px (était line_height + 2)
      screen.fill()
      screen.level(0)
    else
      screen.level(8)
    end
    screen.move(col1_x, y)
    screen.text(param.name)
    if param_index == tape_page_param then
      screen.level(0)
    else
      screen.level(15)
    end
    screen.move(col1_x + 20, y)
    screen.text(param.value)
    param_index = i + 4
    param = tape_params[param_index]
    if param_index == tape_page_param then
      screen.level(15)
      screen.rect(col2_x - 2, y - 8, 58, line_height)  -- Réduit de 2px (était line_height + 2)
      screen.fill()
      screen.level(0)
    else
      screen.level(8)
    end
    screen.move(col2_x, y)
    screen.text(param.name)
    if param_index == tape_page_param then
      screen.level(0)
    else
      screen.level(15)
    end
    screen.move(col2_x + 20, y)
    screen.text(param.value)
  end
end

-- Softcut setup
function init_softcut()
  -- FIXED: Enable reverb engine
  audio.level_adc_cut(1)
  audio.level_eng_cut(1)
  audio.rev_on()  -- Enable reverb
  audio.level_cut_rev(0)  -- Start with no send
  audio.level_monitor(0.3)  -- Default reverb mix
  
  -- MODIFICATION 2: MAIN_VOICE initialisée avec play = 0 et level = 0
  softcut.enable(MAIN_VOICE, 1)
  softcut.buffer(MAIN_VOICE, BUFFER_1)
  softcut.level(MAIN_VOICE, 0)  -- Level à 0 (pas de lecture)
  softcut.level_input_cut(1, MAIN_VOICE, 1.0)
  softcut.level_input_cut(2, MAIN_VOICE, 1.0)
  softcut.pan(MAIN_VOICE, 0)
  softcut.rate(MAIN_VOICE, 1)
  softcut.loop(MAIN_VOICE, 1)
  softcut.loop_start(MAIN_VOICE, 0)
  softcut.loop_end(MAIN_VOICE, MAX_LOOP_TIME)
  softcut.position(MAIN_VOICE, 0)
  softcut.play(MAIN_VOICE, 0)  -- Play désactivé au départ
  softcut.rec(MAIN_VOICE, 0)
  softcut.rec_level(MAIN_VOICE, 1.0)
  softcut.pre_level(MAIN_VOICE, 0.0)
  softcut.fade_time(MAIN_VOICE, 0.1)
  
  for i = 1, NUM_HEADS do
    local voice = i + 1
    softcut.enable(voice, 1)
    softcut.buffer(voice, BUFFER_1)
    softcut.level(voice, heads[i].volume)
    softcut.pan(voice, heads[i].pan)
    softcut.rate(voice, 1.0)
    softcut.loop(voice, 1)
    softcut.loop_start(voice, 0)
    softcut.loop_end(voice, MAX_LOOP_TIME)
    softcut.position(voice, 0)
    softcut.play(voice, 0)
    softcut.rec(voice, 0)
    softcut.fade_time(voice, 0.05)
    
    -- Initialiser les pre_filter (utilisés par tape FX)
    softcut.pre_filter_dry(voice, 1.0)
    softcut.pre_filter_lp(voice, 0)
    softcut.pre_filter_hp(voice, 0)
    softcut.pre_filter_fc(voice, 12000)
    
    -- Initialiser les post_filter (utilisés par les filtres des heads)
    softcut.post_filter_dry(voice, 1.0)
    softcut.post_filter_lp(voice, 0)
    softcut.post_filter_hp(voice, 0)
    softcut.post_filter_bp(voice, 0)
    softcut.post_filter_fc(voice, 12000)
    softcut.post_filter_rq(voice, 0.5)
  end
  
  -- MODIFICATION 1: TAPE_VOICE configurée sans level_input_cut
  -- (enregistre uniquement les heads via level_cut_cut)
  softcut.enable(TAPE_VOICE, 1)
  softcut.buffer(TAPE_VOICE, BUFFER_2)
  softcut.level(TAPE_VOICE, 1.0)
  -- PAS de softcut.level_input_cut pour TAPE_VOICE
  -- La tape enregistrera uniquement via les level_cut_cut des heads
  softcut.pan(TAPE_VOICE, 0)
  softcut.rate(TAPE_VOICE, 1)
  softcut.loop(TAPE_VOICE, 1)
  softcut.loop_start(TAPE_VOICE, tape_buffer_start)
  softcut.loop_end(TAPE_VOICE, tape_buffer_start + MAX_LOOP_TIME)
  softcut.position(TAPE_VOICE, tape_buffer_start)
  softcut.play(TAPE_VOICE, 0)
  softcut.rec(TAPE_VOICE, 0)
  softcut.rec_level(TAPE_VOICE, 0)
  softcut.pre_level(TAPE_VOICE, 0)
  softcut.fade_time(TAPE_VOICE, 0.1)
  
  softcut.event_phase(update_positions)
  for i = 1, NUM_HEADS do
    softcut.phase_quant(heads[i].voice, 0.02)
  end
  softcut.phase_quant(MAIN_VOICE, 0.02)
  softcut.phase_quant(TAPE_VOICE, 0.02)
  softcut.poll_start_phase()
  softcut.event_render(waveform_rendered)
end

-- Parameters
function init_params()
  params:add_option("pitch_mode", "Pitch Mode", {"Semitones", "Octaves"}, 1)
  params:set_action("pitch_mode", function(x)
    pitch_mode = x
    show_message(x == 1 and "Semitones" or "Octaves", 1)
  end)
  
  -- FIXED: Reverb with proper implementation
  params:add_separator("Reverb")
  params:add_control("reverb_send", "Reverb Send", controlspec.new(0, 1, "lin", 0.01, 0, ""))
  params:set_action("reverb_send", function(x)
    audio.level_cut_rev(x)
  end)
  
  params:add_control("reverb_mix", "Reverb Mix", controlspec.new(0, 1, "lin", 0.01, 0.3, ""))
  params:set_action("reverb_mix", function(x)
    audio.level_monitor(x)
  end)
  
  params:add_separator("Recording")
  params:add_control("overdub_level", "Overdub Level", controlspec.new(0, 1, "lin", 0.01, 0.7, ""))
  params:add_control("overdub_feedback", "Overdub Feedback", controlspec.new(0, 1, "lin", 0.01, 0.9, ""))
  params:add_control("clear_fade_time", "Clear Fade Time", controlspec.new(0.1, 5, "lin", 0.1, 1, "s"))
  
  -- Loop Crossfade parameters
  params:add_control("loop_fade_in", "Loop Fade In", controlspec.new(0.001, 0.5, "exp", 0.001, 0.01, "s"))
  params:set_action("loop_fade_in", function(x)
    loop_fade_in_time = x
    apply_loop_crossfade()
  end)
  
  params:add_control("loop_fade_out", "Loop Fade Out", controlspec.new(0.001, 0.5, "exp", 0.001, 0.01, "s"))
  params:set_action("loop_fade_out", function(x)
    loop_fade_out_time = x
    apply_loop_crossfade()
  end)
  
  params:add_separator("Tape")
  for i = 1, 4 do
    params:add_control("tape_send_" .. i, "Tape Send " .. i, controlspec.new(0, 1, "lin", 0.01, 0, ""))
    params:set_action("tape_send_" .. i, function(x)
      softcut.level_cut_cut(heads[i].voice, TAPE_VOICE, x)
      grid_redraw()
    end)
  end
  params:add_control("tape_volume", "Tape Volume", controlspec.new(0, 2, "lin", 0.01, 1, ""))
  params:set_action("tape_volume", function(x)
    if not tape_muted then
      softcut.level(TAPE_VOICE, x)
    end
    grid_redraw()
  end)
  params:add_control("tape_pitch", "Tape Pitch", controlspec.new(-24, 24, "lin", 1, 0, "st"))
  params:set_action("tape_pitch", function(x)
    local rate_multiplier = 2 ^ (x / 12)
    local current_direction = tape_reverse and -1 or 1
    softcut.rate(TAPE_VOICE, rate_multiplier * current_direction)
    grid_redraw()
  end)
  
  -- ADDED: Tape FX parameters
  params:add_separator("Tape FX")
  params:add_control("tape_wobble", "WOBB - Wow/Flutter", controlspec.new(0, 1, "lin", 0.01, 0, ""))
  
  params:add_control("tape_saturation", "SAT - Saturation", controlspec.new(0, 1, "lin", 0.01, 0, ""))
  params:set_action("tape_saturation", function(x)
    -- FIXED: Apply saturation to ALL output voices (global)
    for i = 1, NUM_HEADS do
      if loop_exists then
        apply_tape_fx_to_voice(heads[i].voice)
      end
    end
    if tape_exists then
      apply_tape_fx_to_voice(TAPE_VOICE)
    end
  end)
  
  params:add_control("tape_hiss", "HISS - Tape Noise", controlspec.new(0, 0.3, "lin", 0.01, 0, ""))
  params:set_action("tape_hiss", function(x)
    -- FIXED: Apply hiss to ALL output voices (global)
    for i = 1, NUM_HEADS do
      if loop_exists then
        apply_tape_fx_to_voice(heads[i].voice)
      end
    end
    if tape_exists then
      apply_tape_fx_to_voice(TAPE_VOICE)
    end
  end)
  
  params:add_control("tape_age", "AGE - Dropouts", controlspec.new(0, 1, "lin", 0.01, 0, ""))
  
  params:add_separator("LFOs")
  for i = 1, 4 do
    params:add_separator("LFO " .. i)
    params:add_option("lfo_" .. i .. "_shape", "LFO " .. i .. " Shape", {"Sine", "Random"}, 1)
    params:add_control("lfo_" .. i .. "_speed", "LFO " .. i .. " Speed", controlspec.new(0.1, 10, "exp", 0.1, 1, "Hz"))
    params:add_control("lfo_" .. i .. "_depth", "LFO " .. i .. " Depth", controlspec.new(0, 1, "lin", 0.01, 0, ""))
    params:add_option("lfo_" .. i .. "_dest", "LFO " .. i .. " Destination", lfo_destinations, 1)
  end
  params:add_separator("MIDI")
  params:add_number("midi_device", "MIDI Device", 1, 4, 1)
  params:set_action("midi_device", function(x)
    if midi_device then
      midi_device.event = nil  -- Disconnect previous device
    end
    midi_device = midi.connect(x)
    midi_device.event = midi_event  -- Connect event handler
    show_message("MIDI device " .. x, 1)
  end)
  
  params:add_separator("MIDI Learn")
  params:add_trigger("midi_panic", "MIDI Panic (Reset All)")
  params:set_action("midi_panic", function()
    -- Reset all heads to default
    for i = 1, NUM_HEADS do
      heads[i].volume = 1.0
      heads[i].pitch = 0
      heads[i].pan = (i - 2.5) * 0.4
      heads[i].filter_lp_hp = 0
      heads[i].filter_bp = 0
      heads[i].filter_q = 0.5
      heads[i].start = 0.0
      heads[i].ending = 1.0
      update_head(i)
    end
    show_message("MIDI Panic - All Reset", 2)
  end)
  
  params:bang()
end

-- Init
function init()
  init_softcut()
  init_params()
  init_grid()
  
  -- ADDED: Tape FX update clock
  tape_clock = clock.run(function()
    while true do
      clock.sleep(1/30)
      update_tape_fx()
      redraw()
    end
  end)
end

-- Cleanup
function cleanup()
  if tape_clock then
    clock.cancel(tape_clock)
  end
  for i = 1, 6 do
    softcut.play(i, 0)
    softcut.rec(i, 0)
  end
  clock.sleep(0.05)
  for i = 1, 6 do
    pcall(function() softcut.enable(i, 0) end)
  end
end
