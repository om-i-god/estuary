-- estuary
-- generative ambient set
-- press play and let it ride
--
-- small melodies, a lot of air,
-- bright chords, and the sound
-- of water coming in
--
-- E1-E3: the current page
--   play:   bloom nudge / space / tone
--   nature: bed / swell / moments
--   sound:  pad / echo fb / reverb
--   parts:  E2 pick  E3 level
-- K2 tap: breathe (thin out, then relax)
-- K3 tap: tide (bring the water in)
-- K2+K3: play / stop
-- hold K2: E2 key  E3 mode
-- hold K3: E2 bpm  E3 set/track
-- hold K1: E1 theme  E2 page
-- parts page: K2 mute  K3 solo
--
-- grid: row 1 phrase, row 2 bloom (press to pull it),
--   row 3 mute parts, rows 4-7 motifs (press an event: note <-> rest),
--   row 8 breathe / mutate / tide / new track / play
-- params > meter: 3/4 4/4 5/4 6/8 7/8,
--   from the next barline
-- params > LISTEN: follow the key of the audio input
-- params > MOTIF / PAD / PEDAL OUT: internal, midi or both
--
-- samples: dust/audio/estuary/
--   water/ birds/ wind/ room/
--
-- v0.1

engine.name = "Estuary"

local T   = include("lib/theory")
local M   = include("lib/motifs")
local H   = include("lib/harmony")
local C   = include("lib/conductor")
local N   = C.N                  -- the conductor's nature module (it has state)
local O   = include("lib/outs")
local L   = include("lib/listen")
local GU  = include("lib/gridui")
local PAL = include("lib/palettes")
local MT  = include("lib/meter")

local VIS = include("lib/visuals")

local ECHO_DIVS      = {0.5, 1, 1.5, 2}              -- in beats
local ECHO_DIV_NAMES = {"1/8", "1/4", "3/8", "1/2"}
-- option lists only grow at the end: stored psets keep their sounds
local VOICE_NAMES    = {"auto", table.unpack(PAL.VOICES)}   -- auto, rhodes, bell, sine, marimba, ...
local PAD_NAMES      = {"auto", table.unpack(PAL.PADS)}
local PALETTE_NAMES  = {"auto", table.unpack(PAL.NAMES)}
local MOMENT_NAMES   = {"off", "rare", "some"}       -- -> S.moment_freq 0 / 1 / 2
local PHRASES        = {8, 16, 32}

------------------------------------------------------------------------
-- state
------------------------------------------------------------------------

local S = {
  playing = false, step = 0, track_bar = 0,
  bloom = 0.05, nudge = 0,
  section = "-", progress = 0, total_bars = nil,
  root_pc = 0, mode = 1, voicing = H.AUTO, harmony = 3,
  mode_play = 1, track_minutes = 12, end_action = 2, phrase_len = 16,
  freeze = false, moment_freq = 1,
  tempo = 72, bar_sec = 60 / 72 * 4,
  -- the meter (MT index), its 8ths per bar, where the step clock is in the
  -- bar (0 = the downbeat), and a change waiting for the next barline
  meter = MT.DEFAULT, bar8 = 8, bar_pos = 0, meter_next = nil,
  chord = {48, 55, 62, 64}, chord_degree = 1, chord_label = "I",
  gain = {}, muted = {}, soloed = {},
}

local main_clock, draw_clock, listen_clock
local in_key, in_amp = nil, 0       -- the engine's key tracker, polled
local loop_gen = 0        -- bumps on each start; stale step loops exit
local ready = false       -- params:bang done and the first track exists
local k1, k2, k3 = false, false, false
local k2_used, k3_used = false, false
local k2_t, k3_t = 0, 0                    -- when K2 / K3 went down
local TAP = 0.4                            -- s: a longer hold is not a tap
local theme = 1
local vis_chord, vis_state, vis_moment   -- what the visuals were last told
local page  = 1
local msg, msg_t = nil, 0
local pedal_pc_last, pedal_beat = nil, -99 * 4   -- the sounding pedal (midi, nil = none), when struck (track beats)
local PEDAL_FLOOR = 28                       -- E1: nothing lower

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function flash(text)
  msg, msg_t = text, util.time()
end

-- VISUALS > theme cycle: a new random theme on a bar edge / phrase / track.
-- the music shares math.random, so the cycle turns the music's dice exactly
-- as it did when there were 22 places (a seed sounds the same however many
-- places there are); which place comes next is the visuals' own dice
local CYCLE_DICE_N = 22
local cycle_seed = 5
local dice_theme = 1                    -- the place the 22-place cycle would be on
local cycling = false
local function cycle_theme(edge)
  if params:get("vis_cycle") ~= edge or #VIS.names < 2 then return end
  local d = dice_theme
  repeat d = math.random(CYCLE_DICE_N) until d ~= dice_theme
  dice_theme = d
  cycle_seed = (cycle_seed * 1103515245 + 12345 + d) & 0x7fffffff
  local n = 1 + cycle_seed % (#VIS.names - 1)
  if n >= theme then n = n + 1 end
  cycling = true
  params:set("theme", n)
  cycling = false
end

------------------------------------------------------------------------
-- engine helpers
------------------------------------------------------------------------

local tweak_cache = {}
local function tweak(k, v)
  if tweak_cache[k] ~= v then
    tweak_cache[k] = v
    engine.tweak(k, v)
  end
end

-- every melodic note leaves through here. part is "motif1".."motif4",
-- "pad" (notes = 4 midi) or "pedal". each part goes to the internal engine,
-- midi, crow or any mix (outs.lua). callers have already gated by the
-- conductor's gain and the hand mutes, so a thinned part sends nothing to
-- midi either. vel is 0..1 and already carries the part's gain.
local PAD_VEL = 0.55

local function pad_midi(notes, g)
  O.release("pad")
  if g <= 0.02 or S.muted.pad then return end
  for i = 1, 4 do O.note("pad", notes[i], nil, i, PAD_VEL * g) end
end

local function emit(part, notes, vel, dur_beats, m)
  local dur_s = (dur_beats or 0) * clock.get_beat_sec()
  if part == "pad" then
    local internal = O.route("pad")
    if internal then
      -- the pad's character: the palette's, or the pinned one; it changes
      -- with this voicing (crossfaded), never as a cut
      tweak("pad_sound", PAL.pad_sound(params:get("pad_sound"), S.palette))
      engine.pad(notes[1], notes[2], notes[3], notes[4])
    end
    pad_midi(notes, S.gain.pad or 0)
  elseif part == "pedal" then
    local internal = O.route("pedal")
    if internal then engine.pedal(notes, vel, dur_s) end
    O.note("pedal", notes, dur_s, nil, vel)
  else
    local slot = tonumber(part:sub(6))
    local internal = O.route("motif", slot)
    if internal then
      local voice = PAL.motif_voice(params:get(part .. "_voice"), S.palette, slot)
      local tb, ts = PAL.tilt(S.palette)
      local bright = clamp(m.bright * (0.55 + 0.45 * S.bloom) + tb, 0, 1)
      local send = clamp(m.send * ts * params:get("space") / 50, 0, 1)
      engine.note(voice, notes, vel, dur_s, m.pan, bright, send)
    end
    O.note("motif", notes, dur_s, slot, vel)
  end
end

-- the pedal's register: the highest note of its pitch class at least a 4th
-- under the pad, low enough that no chord note sits a semitone from it (in
-- the bass, or a major 7th above it) or a bare tritone above it. the sounding pedal stays put while it
-- still clears. nil = the pedal rests under this chord.
local function pedal_clears(n, chord)
  for _, c in ipairs(chord) do
    local d = c - n
    if d == 1 or d == -1 or d == 6 or d == 11 then return false end
  end
  return true
end

local function place_pedal(pc, chord, cur)
  local top = chord[1] - 5
  if cur and cur % 12 == pc and cur <= top and pedal_clears(cur, chord) then return cur end
  local n = top - ((top - pc) % 12)
  while n >= PEDAL_FLOOR do
    if pedal_clears(n, chord) then return n end
    n = n - 12
  end
  return nil
end

-- let the sounding pedal go: the engine releases it over 2 s, midi now
local function pedal_off()
  if not pedal_pc_last then return end
  pedal_pc_last = nil
  engine.pedal(0, 0, 0)
  O.release("pedal")
  if S.pedal_probe then S.pedal_probe(nil) end
end

-- pedal: a soft low note under the chord at its gain; again when the pitch
-- moves, else again on the last barline before 16 beats have passed (four
-- bars of 4/4; counted in beats, so a meter change can't stretch the gap
-- past the 18-beat note). thinned, muted or with no
-- clean place under this chord, it lets go
local function pedal_follow()
  local g = S.muted.pedal and 0 or (S.gain.pedal or 0)
  local midi = S.playing and g > 0.02 and S.pedal_pc
    and place_pedal((S.root_pc + S.pedal_pc) % 12, S.chord, pedal_pc_last)
  if midi then
    local now = S.track_beats or 0
    if midi ~= pedal_pc_last or now - pedal_beat + S.bar8 / 2 > 16 then
      pedal_pc_last, pedal_beat = midi, now
      emit("pedal", midi, 0.7 * g, 4.5 * 4)
      if S.pedal_probe then S.pedal_probe(midi, 4.5 * 4) end
    end
  else
    pedal_off()
  end
end

------------------------------------------------------------------------
-- bar-rate macros: bloom + user knobs -> engine
------------------------------------------------------------------------

local function apply_bar()
  local beat  = clock.get_beat_sec()
  local tone  = params:get("tone") / 100
  local space = params:get("space") / 100
  -- a water swell closes the filters a little
  tweak("tone", tone * (1 - 0.25 * N.level))
  tweak("echo_time", ECHO_DIVS[params:get("echo_div")] * beat)
  -- at 1/8 a long feedback tail turns every note into a run of 8ths
  local div = params:get("echo_div")
  tweak("echo_fb", div == 1 and math.min(0.6, params:get("echo_fb")) or params:get("echo_fb"))
  tweak("echo_tone", 0.3 + tone * 0.5)
  tweak("verb_size", params:get("verb_size"))
  tweak("verb_send", 0.5 + space * 0.5)
  tweak("level", params:get("level"))
  tweak("motif_level", params:get("motif_level"))
  tweak("pedal_level", params:get("pedal_level"))
  tweak("pad_xfade", clamp(S.bar_sec * 1.5, 2, 10))
  -- the grid mutes the nature parts too
  tweak("bed_level", S.muted.bed and 0 or params:get("bed_level"))
  tweak("swell_level", S.muted.swell and 0 or params:get("swell_level"))
  tweak("moment_level", S.muted.moment and 0 or params:get("moment_level"))
  tweak("nature_tone", params:get("nature_tone"))

  -- pad: follows the bloom's gain; re-voiced (crossfaded) when the chord moves
  local muted = S.muted
  local pg = (muted.pad or not S.playing) and 0 or (S.gain.pad or 0)
  tweak("pad_level", params:get("pad_level") * pg)
  if S.chord_changed and S.playing then
    S.chord_changed = false
    emit("pad", S.chord)
  end
  -- a pad on midi follows the same thinning: let go when it's silenced,
  -- come back (same chord) when it returns
  local _, pad_to_midi = O.route("pad")
  if pad_to_midi then
    if S.playing and pg > 0.02 then
      if not O.held("pad") then pad_midi(S.chord, pg) end
    else
      O.release("pad")
    end
  end

  pedal_follow()
end

------------------------------------------------------------------------
-- one 8th step
------------------------------------------------------------------------

local start, stop, new_track

-- keep the key / seed / mode params in step with the music
local function sync_params()
  params:set("root", S.root_pc + 1, true)
  params:set("mode", S.mode, true)
  params:set("seed", S.seed or params:get("seed"), true)
end

local held = {}                   -- slot -> {midi, till (step)}: what each motif holds

local function step_motif(i)
  local m = S.motifs[i]
  local k = "motif" .. i
  local g = S.gain[k] or 0
  local audible = g > 0.02 and not S.muted[k]
  local ev = M.step(m, audible)   -- motifs that aren't sounding still step
  if not ev or not audible then return end
  local others = {}
  for j, h in pairs(held) do
    if j ~= i and h.till > S.step then others[#others + 1] = h.midi end
  end
  local midi = M.realize(m, ev, S.chord, S.mode, S.root_pc, others)
  if not midi then return end     -- a rest
  held[i] = {midi = midi, till = S.step + ev.dur}
  local dur_beats = ev.dur / 2
  local vel = (0.5 + 0.3 * m.bright) * g
  -- the meter's lean: a little more on the downbeat and the group starts,
  -- never past the part's ceiling (0.8 x gain). none at 4/4
  local lean = MT.lean(S.meter, S.bar_pos)
  if lean then vel = math.min(0.8 * g, vel * lean) end
  emit(k, midi, vel, dur_beats, m)
  if S.probe then S.probe(i, midi, ev, dur_beats, vel) end
  VIS.event("note", i, midi, dur_beats * clock.get_beat_sec())
end

-- a new meter takes over on a barline (or at once while stopped). the step
-- clock re-anchors: a stopped clock part-way through a bar rounds up to that
-- bar's end, so the new bar starts cleanly. notes already sounding ring on
local function apply_meter()
  local v = S.meter_next
  if not v then return end
  S.meter_next = nil
  if S.bar_pos ~= 0 then
    S.step = S.step + (S.bar8 - S.bar_pos)
    S.bar_pos = 0
  end
  S.meter, S.bar8 = v, MT.bar8(v)
end

local function play_step()
  local s = S.bar_pos

  if s == 0 then
    apply_meter()                 -- a waiting meter lands on this barline
    S.tempo = clock.get_tempo()
    S.bar_sec = clock.get_beat_sec() * S.bar8 / 2
    local r = C.bar(S)            -- also runs nature and harmony
    S.nature_state = N.state
    S.moment_active = N.moment_active
    if r == "stop" then
      stop(true)
      flash("track end")
      return
    end
    if r == "next" or S.key_moved then
      S.key_moved = false
      sync_params()
      flash(r == "next" and ("new track " .. S.seed) or T.name(S.root_pc, S.mode))
    end
    apply_bar()
    O.bar(S, (S.track_bar - 1) % S.phrase_len == 0)
    -- the picture follows the music: chord, water, passing moments, the bar
    if S.chord_label ~= vis_chord then vis_chord = S.chord_label; VIS.event("chord", S) end
    if N.state ~= vis_state or N.state ~= "idle" then
      vis_state = N.state
      VIS.event("swell", N.state, N.level)
    end
    if N.moment_active and not vis_moment then VIS.event("moment", "passing") end
    vis_moment = N.moment_active
    VIS.event("bar", S)
    if (S.track_bar - 1) % 8 == 0 then cycle_theme(2) end
    if (S.track_bar - 1) % S.phrase_len == 0 then cycle_theme(3) end
    if r == "next" then cycle_theme(4) end
  end

  for i = 1, 4 do step_motif(i) end
  S.step = S.step + 1
  S.bar_pos = (S.bar_pos + 1) % S.bar8
end

------------------------------------------------------------------------
-- transport
------------------------------------------------------------------------

local function loop(my)
  clock.sync(S.bar8 / 2)          -- start on a bar (in beats)
  if S.playing and my == loop_gen then O.start() end
  while true do
    if not S.playing or my ~= loop_gen then return end
    play_step()
    clock.sync(1 / 2)             -- an 8th
  end
end

start = function()
  if S.playing then return end
  -- a track that ended on "stop": play starts the next one (new seed, a
  -- neighbouring key), as "next track" would have
  if S.mode_play == 2 and S.total_bars and C.track_pos(S) >= S.total_bars then
    new_track(math.random(1, 9999), true)
    flash("new track " .. S.seed)
  end
  S.playing = true
  apply_meter()                   -- one chosen while stopped (or left waiting)
  if S.bar_pos ~= 0 then          -- resume on a bar
    S.step = S.step + (S.bar8 - S.bar_pos)
    S.bar_pos = 0
  end
  S.chord_changed = true          -- voice the pad
  pedal_pc_last = nil
  loop_gen = loop_gen + 1
  local my = loop_gen
  N.start_bed(S)
  main_clock = clock.run(function() loop(my) end)
  flash("play")
end

-- from_loop: called inside the step clock, which exits on its own once
-- S.playing is false (don't cancel the running coroutine from within)
stop = function(from_loop)
  local was = S.playing
  S.playing = false
  if main_clock and not from_loop then clock.cancel(main_clock) end
  main_clock = nil
  -- midi stop only once (cleanup after a stop just makes sure notes are off)
  if was then O.stop() else O.all_off() end
  pedal_off()
  -- water, bed and any passing moment go quiet with the music
  N.stop()
  tweak("pad_level", 0)
  flash("stop")
end

new_track = function(seed, move_key)
  C.new_track(S, seed, move_key)
  params:set("seed", seed, true)
  sync_params()
  apply_bar()
end

------------------------------------------------------------------------
-- controls
------------------------------------------------------------------------

local function toggle_play()
  if S.playing then stop() else start() end
end

local function breathe()
  C.breathe(S)
  C.decide(S)
  flash("breathe")
end

local function tide()
  local ok, why = C.tide(S)
  if ok then
    flash("tide")
  elseif why == "moment running" then
    C.pending_swell(S)            -- lands as soon as the moment is over
    flash("tide soon")
  else
    flash(why or "no water")
  end
end

local function mutate()
  C.mutate(S)
  flash("mutate")
end

local function fresh()
  S.mode = T.MODE_POOL[math.random(#T.MODE_POOL)]
  new_track(math.random(1, 9999), true)
  flash("new track " .. S.seed)
end

-- hand mutes and solos decide which parts are eligible; the conductor trims
local function toggle_mute(k)
  S.muted[k] = not S.muted[k] or nil
  C.decide(S)
  if k == "pedal" and S.muted.pedal then pedal_off() end   -- silent at once
  flash((S.muted[k] and "mute " or "unmute ") .. k)
end

local function toggle_solo(k)
  S.soloed[k] = not S.soloed[k] or nil
  C.decide(S)
  flash((S.soloed[k] and "solo " or "unsolo ") .. k)
end

-- grid-only actions
local function set_bloom(v)
  -- pull the bloom to v now; the nudge carries it, then relaxes over bars
  S.nudge = clamp(v - (S.bloom - (S.nudge or 0)), -0.6, 0.6)
  S.bloom = clamp(v, 0, 1)
  C.decide(S)
  flash(string.format("bloom %d", math.floor(S.bloom * 100 + 0.5)))
end

local function toggle_step(slot, x)
  if M.toggle(S.motifs[slot], x) then
    flash("motif " .. slot .. " step " .. x)
  else
    flash("keep 3-7 notes + a rest")
  end
end

local function rewrite(slot)
  C.rewrite(S, slot)
  flash("rewrite motif " .. slot)
end

-- listening: the engine's key tracker -> a steady key. the heard minor root
-- is folded into the current mode (T.root_for) and taken through the hand's
-- own instant path (the root param), never a morph
local function listen_loop()
  while true do
    clock.sleep(0.25)
    if S.listen_follow then
      local now  = util.time()
      local gate = 10 ^ (params:get("listen_gate") / 20)
      L.tick(in_key, in_amp, gate, now)
      local m = L.proposal(T.minor_of(S.root_pc, S.mode), params:get("listen_hold"), now)
      local pc = m and T.root_for(m, S.mode)
      if pc and pc ~= S.root_pc then
        params:set("root", pc + 1)
        flash("in key " .. T.name(S.root_pc, S.mode))
      end
    end
  end
end

local PART_KEYS  = {"motif1", "motif2", "motif3", "motif4", "pad", "pedal"}
local PART_GLYPH = {"1", "2", "3", "4", "P", "L"}
-- the level param each part's E3 turns on the parts page
local PART_LVL = {motif1 = "motif_level", motif2 = "motif_level", motif3 = "motif_level",
                  motif4 = "motif_level", pad = "pad_level", pedal = "pedal_level"}
local part_sel = 1

-- encoder pages: {param id, step multiplier}; "_bloom" is the nudge. the
-- parts page is its own thing: E2 picks a part, E3 its level, K2 mutes it,
-- K3 solos it
local PAGES = {
  {name = "play",   {"_bloom", 1},    {"space", 1},      {"tone", 1}},
  {name = "nature", {"bed_level", 1}, {"swell_level", 1}, {"moment_freq", 1}},
  {name = "sound",  {"pad_level", 1}, {"echo_fb", 1},    {"verb_size", 1}},
  {name = "parts",  {"_bloom", 1}},
}
local function on_parts() return PAGES[page].name == "parts" end

function key(n, z)
  if n == 1 then
    k1 = z == 1
  elseif n == 2 then
    if z == 1 then
      k2, k2_used, k2_t = true, false, util.time()
      if k3 then
        if S.playing then stop() else start() end
        k2_used, k3_used = true, true
      end
    else
      k2 = false
      -- a tap: quick, and no encoder turned while it was down
      if not k2_used and util.time() - k2_t <= TAP then
        if on_parts() then toggle_mute(PART_KEYS[part_sel]) else breathe() end
      end
    end
  elseif n == 3 then
    if z == 1 then
      k3, k3_used, k3_t = true, false, util.time()
      if k2 then
        if S.playing then stop() else start() end
        k2_used, k3_used = true, true
      end
    else
      k3 = false
      if not k3_used and util.time() - k3_t <= TAP then
        if on_parts() then toggle_solo(PART_KEYS[part_sel]) else tide() end
      end
    end
  end
end

function enc(n, d)
  if k1 and n == 1 then
    params:delta("theme", d)
  elseif k1 and n == 2 then
    page = clamp(page + d, 1, #PAGES)
    flash("page " .. PAGES[page].name)
  elseif k1 then
    return
  elseif k2 then
    k2_used = true
    if n == 2 then params:delta("root", d)
    elseif n == 3 then params:delta("mode", d) end
    flash(T.name(S.root_pc, S.mode))
  elseif k3 then
    k3_used = true
    if n == 2 then
      params:delta("clock_tempo", d)
      flash(math.floor(clock.get_tempo() + 0.5) .. " bpm")
    elseif n == 3 then
      params:delta("play_mode", d)
      flash(params:string("play_mode"))
    end
  elseif on_parts() and n > 1 then
    local k = PART_KEYS[part_sel]
    if n == 2 then
      part_sel = clamp(part_sel + d, 1, #PART_KEYS)
      k = PART_KEYS[part_sel]
      flash(k .. (S.soloed[k] and " solo" or (S.muted[k] and " muted" or "")))
    else
      params:delta(PART_LVL[k], d)
      flash(params:lookup_param(PART_LVL[k]).name .. " " .. params:string(PART_LVL[k]))
    end
  else
    local id, mult = PAGES[page][n][1], PAGES[page][n][2]
    if id == "_bloom" then
      C.nudge(S, d * 0.03)
      S.nudge = clamp(S.nudge, -0.6, 0.6)
      flash(string.format("bloom %+d", math.floor(S.nudge * 100 + 0.5)))
    else
      params:delta(id, d * mult)
      flash(params:lookup_param(id).name .. " " .. params:string(id))
    end
  end
end

------------------------------------------------------------------------
-- screen
------------------------------------------------------------------------

local function text_box(x, y, s, lvl, right)
  local w = screen.text_extents(s)
  local x0 = right and (x - w) or x
  screen.level(0)
  screen.rect(x0 - 1, y - 6, w + 2, 8)
  screen.fill()
  screen.level(lvl)
  screen.move(x0, y)
  screen.text(s)
end

local function draw_hud()
  -- overlay: 1 full, 2 minimal (key + chord), 3 off (hints and messages only)
  local hud = params:get("hud")

  -- top left: key and mode; held K1 shows the theme instead
  local top = T.name(S.root_pc, S.mode, true)
  if k1 then top = VIS.names[theme] .. " " .. theme .. "/" .. #VIS.names end
  if hud < 3 or k1 then text_box(1, 7, top, S.playing and 12 or 4) end
  -- second line: the chord (roman, "/I" = over a tonic pedal), then the page
  if not k1 and (hud < 3 or page ~= 1) then
    local sub = S.chord_label or ""
    if page ~= 1 then
      sub = sub .. "  " .. PAGES[page].name
    else
      -- the play page: the meter (and the one waiting for the barline)
      sub = sub .. "  " .. MT.name(S.meter)
      if S.meter_next and S.meter_next ~= S.meter then sub = sub .. ">" .. MT.name(S.meter_next) end
    end
    text_box(1, 15, sub, page ~= 1 and 6 or 5)
  end

  if hud == 1 then
    -- top right: the section, "~" while the water is in
    local sec = S.section or "-"
    if S.mode_play == 2 and S.total_bars then
      sec = sec .. " " .. math.floor(S.progress * 100) .. "%"
    end
    if N.state ~= "idle" then sec = sec .. " ~" end
    -- (held K1 shows the theme's name top left, up to "echo bridge 21/28"
    -- or "wellspring 28/28":
    -- the section steps aside so the two never overlap)
    if not k1 then text_box(127, 7, sec, S.playing and 8 or 3, true) end

    -- bottom: bloom bar + part lights
    screen.level(0)
    screen.rect(0, 55, 128, 9)
    screen.fill()
    screen.level(2)
    screen.rect(1, 59, 40, 3)
    screen.fill()
    local bw = math.floor(S.bloom * 40 + 0.5)
    if bw > 0 then
      screen.level(S.nudge ~= 0 and 15 or 10)
      screen.rect(1, 59, bw, 3)
      screen.fill()
    end
    for i, k in ipairs(PART_KEYS) do
      screen.level(math.floor(1 + (S.gain[k] or 0) * 13))
      screen.move(76 + (i - 1) * 9, 63)
      screen.text(PART_GLYPH[i])
    end
  end

  -- parts page: every part, the picked one underlined; muted dim,
  -- soloed boxed. drawn whatever the overlay setting
  if on_parts() then
    screen.level(0)
    screen.rect(0, 38, 128, 17)
    screen.fill()
    local any_solo = next(S.soloed) ~= nil
    for i, k in ipairs(PART_KEYS) do
      local x = 16 + (i - 1) * 16
      local on = S.gain[k] or 0
      local lvl = S.muted[k] and 2 or (any_solo and not S.soloed[k]) and 3 or math.floor(5 + on * 10)
      screen.level(lvl)
      screen.move(x, 48)
      screen.text(PART_GLYPH[i])
      if S.soloed[k] then
        screen.level(12)
        screen.rect(x - 2.5, 40.5, 9, 10)
        screen.stroke()
      end
      if i == part_sel then
        screen.level(15)
        screen.rect(x - 1, 52, 6, 1)
        screen.fill()
      end
    end
  end

  -- held-key hints, then transient messages
  local hint
  if k1 then hint = "E1 theme  E2 page: " .. PAGES[page].name
  elseif k2 and not k3 then hint = "E2 key  E3 mode"
  elseif k3 and not k2 then hint = "E2 bpm  E3 " .. params:string("play_mode") end
  if not hint and on_parts() and not (msg and util.time() - msg_t < 1.5) then
    text_box(64 - screen.text_extents("K2 mute  K3 solo") / 2, 34, "K2 mute  K3 solo", 4)
  end
  if hint then
    text_box(64 - screen.text_extents(hint) / 2, 34, hint, 15)
  elseif msg and util.time() - msg_t < 1.5 then
    text_box(64 - screen.text_extents(msg) / 2, 34, msg, 15)
  end

  if not S.playing then
    text_box(127, 52, "K2+K3 play", 4, true)
  end
end

function redraw()
  screen.clear()
  screen.aa(0)
  VIS.draw(theme, S)
  draw_hud()
  screen.update()
end

local function draw_loop()
  local frame = 0
  while true do
    clock.sleep(1 / 20)
    frame = frame + 1
    if frame % 4 == 0 then GU.redraw() end
    if not _menu.mode then redraw() end
  end
end

------------------------------------------------------------------------
-- params
------------------------------------------------------------------------

-- a key / mode / voicing change by hand re-voices the chord at once (pad
-- and pedal included); the
-- harmony module rebuilds a loop the new mode would turn dim or aug. the jump
-- is instant (no morph through the old key's notes, which the new key's
-- melody would rub against)
local function rekey()
  if not ready then return end
  H.retarget(S, true)
  -- the pad and the pedal follow now, not on the next bar
  if S.playing then
    S.chord_changed = false
    emit("pad", S.chord)
    pedal_follow()
  end
end

local function setup_params()
  local vport_names, vport_ids = {"none"}, {0}
  for i = 1, #midi.vports do
    local n = midi.vports[i].name
    if n ~= nil and n ~= "none" and n ~= "" then
      table.insert(vport_names, i .. ":" .. n)
      table.insert(vport_ids, i)
    end
  end

  params:add_separator("ESTUARY")
  params:add_option("play_mode", "play mode", {"set (endless)", "track"}, 1)
  params:set_action("play_mode", function(v)
    S.mode_play = v
    if ready then new_track(S.seed or 1, false) end   -- the arc restarts in the new mode
  end)
  params:add_option("phrase_len", "phrase length (bars)", {"8", "16", "32"}, 2)
  params:set_action("phrase_len", function(v) S.phrase_len = PHRASES[v] end)
  -- the time signature; lands on the next barline (at once while stopped)
  params:add_option("meter", "meter", MT.NAMES, MT.DEFAULT)
  params:set_action("meter", function(v)
    if v == S.meter and not S.meter_next then return end
    S.meter_next = v
    if not S.playing then
      apply_meter()
    elseif ready then
      flash("meter " .. MT.name(v) .. " next bar")
    end
  end)
  params:add_number("track_minutes", "track length (min)", 6, 30, 12)
  params:set_action("track_minutes", function(v) S.track_minutes = v end)
  params:add_option("track_end", "track end", {"stop", "next track"}, 2)
  params:set_action("track_end", function(v) S.end_action = v end)
  params:add_option("freeze", "freeze material", {"off", "on"}, 1)
  params:set_action("freeze", function(v) S.freeze = v == 2 end)
  params:add_number("seed", "seed", 1, 9999, 1)
  params:add_trigger("rebuild", "> rebuild from seed")
  params:set_action("rebuild", function()
    new_track(params:get("seed"), false)
    flash("seed " .. params:get("seed"))
  end)
  params:add_trigger("new_track", "> new random track")
  params:set_action("new_track", fresh)

  params:add_separator("PERFORM")
  for _, a in ipairs({{"play_stop", "> play / stop", toggle_play}, {"breathe", "> breathe", breathe},
                      {"tide", "> tide", tide}, {"mutate", "> mutate", mutate},
                      {"new_track_now", "> new track now", fresh}}) do
    params:add_trigger(a[1], a[2])
    params:set_action(a[1], a[3])
  end

  params:add_separator("KEY")
  params:add_option("root", "root", T.NOTE_NAMES, 1)
  params:set_action("root", function(v) S.root_pc = v - 1; rekey() end)
  params:add_option("mode", "mode", T.MODE_NAMES, 1)
  params:set_action("mode", function(v) S.mode = v; rekey() end)
  params:add_option("harmony", "harmony", H.NAMES, 3)
  params:set_action("harmony", function(v)
    S.harmony = v
    if ready then H.new_prog(S); H.retarget(S, true) end
  end)
  local vnames = {table.unpack(T.VOICING_NAMES)}
  vnames[H.AUTO] = "auto (bloom)"
  params:add_option("voicing", "chord voicing", vnames, H.AUTO)
  params:set_action("voicing", function(v)
    S.voicing = v
    if ready then H.new_prog(S); H.retarget(S, true) end
  end)

  params:add_separator("MIX")
  params:add_number("space", "space (echo + reverb)", 0, 100, 50)
  params:add_number("tone", "tone", 0, 100, 75)
  params:add_option("echo_div", "echo time", ECHO_DIV_NAMES, 3)
  params:add_control("echo_fb", "echo feedback", controlspec.new(0, 0.85, "lin", 0.01, 0.45))
  params:add_control("verb_size", "reverb size", controlspec.new(0, 1, "lin", 0.01, 0.9))
  params:add_control("level", "level", controlspec.new(0, 1, "lin", 0.01, 0.8))

  params:add_separator("NATURE")
  params:add_control("bed_level", "bed level", controlspec.new(0, 1, "lin", 0.01, 0.7))
  params:add_control("swell_level", "swell level", controlspec.new(0, 1, "lin", 0.01, 0.8))
  params:add_option("moment_freq", "moments", MOMENT_NAMES, 2)
  params:set_action("moment_freq", function(v) S.moment_freq = v - 1 end)
  params:add_control("moment_level", "moment level", controlspec.new(0, 1, "lin", 0.01, 0.7))
  params:add_control("nature_tone", "nature tone", controlspec.new(0, 1, "lin", 0.01, 0.7))

  params:add_separator("LEVELS")
  params:add_control("motif_level", "motif level", controlspec.new(0, 1, "lin", 0.01, 0.8))
  params:add_control("pad_level", "pad level", controlspec.new(0, 1, "lin", 0.01, 0.7))
  params:add_control("pedal_level", "pedal level", controlspec.new(0, 1, "lin", 0.01, 0.7))

  params:add_separator("SOUND")
  -- auto: each new track picks a palette (never the last one again)
  params:add_option("palette", "palette", PALETTE_NAMES, 1)
  params:set_action("palette", function(v)
    PAL.pin(S, v)                    -- now: next notes, next pad voicing
  end)
  params:add_option("pad_sound", "pad sound", PAD_NAMES, 1)
  for i = 1, 4 do
    params:add_option("motif" .. i .. "_voice", "motif " .. i .. " voice", VOICE_NAMES, 1)
  end
  -- everything listening: how far the water, the room (while listening)
  -- and the music itself move the tone and the space. the notes never
  -- change; 0 is the plain sound
  params:add_control("react", "react", controlspec.new(0, 1, "lin", 0.01, 0.5))
  params:set_action("react", function(v) tweak("react", PAL.react(v)) end)
  params:add_option("react_src", "react source", PAL.REACT_SOURCES, #PAL.REACT_SOURCES)
  params:set_action("react_src", function(v) tweak("react_src", PAL.react_src(v)) end)

  params:add_separator("LISTEN")
  params:add_option("listen_on", "follow input key", {"off", "on"}, 1)
  params:set_action("listen_on", function(v)
    S.listen_follow = v == 2        -- the conductor holds its own key moves while true
    L.reset()
    engine.listen(S.listen_follow and 1 or 0)
  end)
  params:add_number("listen_gate", "input gate (dB)", -70, -10, -45)
  params:add_number("listen_hold", "hold before move (s)", 2, 60, 10)

  O.setup_params(vport_names, vport_ids)
  -- back to the internal pad: voice it on the next bar, not the next chord
  params:set_action("pad_out", function()
    O.all_off()
    S.chord_changed = true
  end)

  params:add_separator("VISUALS")
  params:add_option("theme", "theme", VIS.names, 1)
  params:set_action("theme", function(v)
    theme = v
    -- (a place picked by hand is where the cycle's dice stand too)
    if not cycling then dice_theme = v end
  end)
  params:add_option("vis_cycle", "theme cycle", {"off", "every 8 bars", "every phrase", "each track"}, 1)
  params:add_option("hud", "overlay", {"full", "minimal", "off"}, 1)
  params:add_number("vis_speed",      "speed",      1, 10, 3)
  params:add_number("vis_brightness", "brightness", 1, 15, 10)
end

-- the first time the script ever loads, settle on 72 bpm; after that the
-- tempo is the user's
local function first_load_tempo()
  local dir = _path.data .. "estuary/"
  local mark = dir .. ".seen"
  if util.file_exists(mark) then return end
  params:set("clock_tempo", 72)
  util.make_dir(dir)
  local f = io.open(mark, "w")
  if f then f:write("1"); f:close() end
end

------------------------------------------------------------------------
-- lifecycle
------------------------------------------------------------------------

function init()
  setup_params()
  first_load_tempo()
  params:bang()

  math.randomseed(os.time())
  N.scan()
  new_track(math.random(1, 9999), false)
  ready = true

  local key_poll = poll.set("in_key", function(v) in_key = v end)
  key_poll.time = 1 / 4
  key_poll:start()
  local amp_poll = poll.set("in_amp", function(v) in_amp = v end)
  amp_poll.time = 1 / 4
  amp_poll:start()
  -- the engine's ears for the visuals: its own output, overall and in three
  -- bands, and the nature level (an engine from before these polls, not yet
  -- restarted, has none: the visuals then run on the music alone)
  for _, name in ipairs({"out_amp", "out_lo", "out_mid", "out_hi", "nat_amp"}) do
    local ok, p = pcall(poll.set, name, function(v) VIS.audio(name, v) end)
    if ok and p then
      p.time = 1 / 15
      p:start()
    end
  end
  listen_clock = clock.run(listen_loop)

  GU.init({
    S = S, set_bloom = set_bloom, toggle_mute = toggle_mute, toggle_step = toggle_step,
    rewrite = rewrite, breathe = breathe, mutate = mutate, tide = tide,
    fresh = fresh, play = toggle_play,
  })

  clock.transport.start = function() start() end
  clock.transport.stop  = function() stop() end

  draw_clock = clock.run(draw_loop)
end

function cleanup()
  stop()
  GU.cleanup()
  if draw_clock then clock.cancel(draw_clock) end
  if listen_clock then clock.cancel(listen_clock) end
end
