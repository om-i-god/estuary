-- estuary / harmony
-- where the chords go: slow, bright, voice-led. a progression is a short loop
-- of steps ({deg, bars}) that holds each chord 8-32 bars (twice that when
-- bloom is low). each new chord is voice-led from the last (fewest
-- semitones moved); in "drifting" it then morphs in one voice at a time, and
-- every in-between chord is rub-free too. the only borrowed colour is a soft
-- minor iv, played once for its full step. no bass line: a pedal note holds
-- the tonic through the calm sections.
--
-- out: S.chord (4 midi notes, low -> high), S.chord_voicing (the T.VOICINGS
-- index actually used), S.chord_root_pc, S.chord_degree, S.chord_label,
-- S.chord_borrowed (true on the minor iv), S.pedal_pc (semitones over the
-- key root).
--
-- "simple" is the plain behaviour: the seed's pair (S.pair, S.harm_bars
-- each), one voicing.

local T = include("lib/theory")

local H = {}

H.NAMES = {"simple", "rich", "drifting"}
H.AUTO  = #T.VOICINGS + 1      -- the voicing param's last option: colour by bloom

local MIN_HOLD = 8             -- bars; no chord ever moves sooner

local function pick(t) return t[math.random(#t)] end

-- loops of scale degrees. dim / aug triads are filtered at pick time (the
-- quality follows the mode), so one list serves every mode.
local PROGS = {
  {1, 4}, {1, 6, 4}, {1, 3, 4}, {4, 1}, {1, 4, 6, 4}, {1, 5, 4}, {1, 6, 4, 5}, {1},
}
-- each mode's signature moves get extra tickets
local FLAVOUR = {
  [2] = {{1, 2}, {1, 2, 1, 5}},          -- lydian: the II
  [3] = {{1, 7}, {1, 7, 4, 1}},          -- mixolydian: bVII
  [6] = {{1, 4}, {1, 4, 1, 7}},          -- dorian
}
-- bars per chord, by chord count: every chord holds 8-32 bars
local LENS = {
  [1] = {{16}, {24}, {32}},
  [2] = {{8, 8}, {16, 8}, {16, 16}, {24, 8}, {32, 16}},
  [3] = {{8, 8, 16}, {16, 8, 8}, {16, 16, 16}},
  [4] = {{8, 8, 8, 8}, {16, 8, 16, 8}},
}
-- voicing colours by bloom (indices into T.VOICINGS)
local COLOUR = {
  low  = {6, 5, 4},       -- open, quartal, sus2
  mid  = {2, 3, 7},       -- add9, 6/9, rootless9
  high = {1, 3, 2},       -- maj7, 6/9, add9
}
-- sections where the pedal holds the tonic (track + set names)
local PEDAL_SECTIONS = {arrival = true, settling = true, tide = true, trough = true, swell = true}
local ROMAN = {[0] = "I", "bII", "II", "bIII", "III", "IV", "#IV", "V", "bVI", "VI", "bVII", "VII"}

-- minor iv chord tones (semitones over the iv root) per warm voicing
local MINOR_IV = {
  [1] = {0, 3, 7, 10},     -- m7
  [7] = {3, 7, 10, 14},    -- rootless m9
  [6] = {0, 7, 14, 19},    -- open 5th + 9
}

local function warm_minor(v)
  for _, w in ipairs(T.WARM_MINOR) do if w == v then return true end end
  return false
end

-- a dark sound hiding in the voiced pitch classes: a dim or aug triad (a
-- rootless 9th on a dominant reads as a m7b5 stack), any tritone (a dom7, a
-- lydian #4 against the root), or a b9 over the chord's root (`root`, a pc)
local function dark_stack(notes, root)
  local pcs = {}
  for _, n in ipairs(notes) do pcs[n % 12] = true end
  for pc in pairs(pcs) do
    if pcs[(pc + 6) % 12] then return true end
    if not pcs[(pc + 7) % 12] then
      if pcs[(pc + 3) % 12] and pcs[(pc + 6) % 12] then return true end
      if pcs[(pc + 4) % 12] and pcs[(pc + 8) % 12] then return true end
    end
  end
  if root and pcs[(root + 1) % 12] then return true end
  return false
end

-- is this step safe in `mode`? never a dim / aug triad
local function valid(mode, st)
  if st.minor then return T.quality(mode, 4) == "maj" end
  local q = T.quality(mode, st.deg)
  return q == "maj" or q == "min"
end

local function step_quality(mode, st)
  return st.minor and "min" or T.quality(mode, st.deg)
end

-- may this step wear colour `col`? minor chords only in warm voicings, and
-- one whose 9th is flat (iii in ionian) only as the plain m7
local function colour_ok(mode, st, col)
  if step_quality(mode, st) ~= "min" then return true end
  if not warm_minor(col) then return false end
  return col == 1 or st.minor or not T.b9_degree(mode, st.deg)
end

local function prog_valid(mode, prog)
  for _, st in ipairs(prog) do
    if not valid(mode, st) then return false end
  end
  return true
end

------------------------------------------------------------------------
-- building progressions
------------------------------------------------------------------------

local function build(S)
  local h = S.h
  local steps = {}
  if S.harmony == 1 then
    for i, d in ipairs(S.pair or {1, 4}) do steps[i] = {deg = d, bars = S.harm_bars or MIN_HOLD} end
    if not prog_valid(S.mode, steps) then steps = {{deg = 1, bars = S.harm_bars or MIN_HOLD}} end
    return steps
  end
  local pool = {}
  local function add(p, n)
    if not prog_valid(S.mode, (function()
      local t = {}
      for i, d in ipairs(p) do t[i] = {deg = d} end
      return t
    end)()) then return end
    for _ = 1, n do pool[#pool + 1] = p end
  end
  for _, p in ipairs(PROGS) do add(p, 1) end
  for _, p in ipairs(FLAVOUR[S.mode] or {}) do add(p, 2) end
  local degs = pick(pool)
  local lens = pick(LENS[#degs])
  for i, d in ipairs(degs) do steps[i] = {deg = d, bars = lens[i]} end
  -- now and then the loop ends on the soft minor iv (adoption enforces
  -- the 1-in-4-loops limit)
  if math.random() < 0.3 and T.quality(S.mode, 4) == "maj" then
    steps[#steps + 1] = {deg = 4, bars = pick({8, 8, 16}), minor = true, borrowed = true}
  end
  return steps
end

------------------------------------------------------------------------
-- voicing
------------------------------------------------------------------------

-- lift the upper note of any semitone pair (and any double) an octave
local function tidy(c)
  table.sort(c)
  for _ = 1, 16 do
    local fixed = true
    for i = 1, #c - 1 do
      if c[i + 1] - c[i] <= 1 then
        c[i + 1] = c[i + 1] + 12
        table.sort(c)
        fixed = false
        break
      end
    end
    if fixed then break end
  end
  return c
end

-- voice leading: give each of the previous chord's voices one of the new
-- chord's notes (every assignment, each in the octave just below or above
-- that voice) and keep the one that moves least, stays in the stab's
-- register (A2..A5), doesn't drift far from around D4 and leaves no
-- semitone rub. the colour's notes all survive; only their octave placement
-- changes.
local PERMS = {}
do
  local function perm(a, n)
    if n == 1 then PERMS[#PERMS + 1] = {a[1], a[2], a[3], a[4]}; return end
    for i = 1, n do
      a[i], a[n] = a[n], a[i]
      perm(a, n - 1)
      a[i], a[n] = a[n], a[i]
    end
  end
  perm({1, 2, 3, 4}, 4)
end

local function lead(prev, raw)
  local best, best_cost
  local c = {}
  for _, p in ipairs(PERMS) do
    for mask = 0, 15 do
      local cost = 0
      for v = 1, 4 do
        local pc = raw[p[v]] % 12
        local below = prev[v] - ((prev[v] - pc) % 12)       -- nearest at or below
        local up = (mask >> (v - 1)) & 1 == 1
        c[v] = (up and below ~= prev[v]) and below + 12 or below
        cost = cost + math.abs(c[v] - prev[v])
      end
      local s1, s2, s3, s4 = c[1], c[2], c[3], c[4]
      local lo, hi = math.min(s1, s2, s3, s4), math.max(s1, s2, s3, s4)
      if lo >= 45 and hi <= 81 and s1 ~= s2 and s1 ~= s3 and s1 ~= s4
         and s2 ~= s3 and s2 ~= s4 and s3 ~= s4 and not T.has_rub(c) then
        cost = cost + math.abs((lo + hi) / 2 - 62) * 0.25
        if not best_cost or cost < best_cost then best, best_cost = {s1, s2, s3, s4}, cost end
      end
    end
  end
  return best or raw
end

local function publish(S)
  local v = S.h.voices
  local c = {v[1], v[2], v[3], v[4]}
  table.sort(c)
  S.chord = c
  S.chord_changed = true
  -- a morph away from the borrowed iv still holds its b3 / b6 for a while
  S.chord_borrow_tail = S.h.borrow_tail or false
end

-- the pedal: tonic in the calm sections, else the chord's root
local function set_pedal(S)
  local h = S.h
  if not h.label then return end
  h.pedal = PEDAL_SECTIONS[S.section] and S.harmony ~= 1 or false
  S.pedal_pc = h.pedal and 0 or h.root_pc
  local label = h.label
  if h.pedal and h.root_pc ~= 0 then label = label .. "/" .. (h.minor_tonic and "i" or "I") end
  S.chord_label = label
end

-- bars the current step lasts at this bloom: calm doubles it (cap 64)
local function need(S)
  local st = S.h.prog[S.h.i]
  if S.harmony == 1 then return st.bars end
  if (S.bloom or 0) < 0.25 then return math.min(64, st.bars * 2) end
  return st.bars
end

-- a new step: pick its colour. minor-quality chords only get warm voicings.
local function begin_step(S)
  local h = S.h
  local st = h.prog[h.i]
  local minor = step_quality(S.mode, st) == "min"
  local b = S.bloom or 0
  if S.voicing == H.AUTO then
    if minor then h.colour = pick(T.WARM_MINOR)
    elseif S.harmony == 1 then h.colour = 1
    else h.colour = pick(b < 0.4 and COLOUR.low or b < 0.75 and COLOUR.mid or COLOUR.high) end
  else
    h.colour = S.voicing
  end
  if not colour_ok(S.mode, st, h.colour) then h.colour = 1 end
  h.held = 0
end

-- move the next voice(s) of a morph; take a move that leaves no rub and
-- doesn't land on a note another voice holds. if none exists, finish the
-- morph in one go (the target itself is rub-free).
local function morph(S)
  local h = S.h
  for _ = 1, h.per_bar do
    if #h.queue == 0 then break end
    local pick_i
    for qi, mv in ipairs(h.queue) do
      local t, clash = {}, false
      for vi = 1, 4 do
        t[vi] = vi == mv[1] and mv[2] or h.voices[vi]
        if vi ~= mv[1] and h.voices[vi] == mv[2] then clash = true end
      end
      if not clash and not T.has_rub(t) and not dark_stack(t, h.root_abs) then pick_i = qi; break end
    end
    if pick_i then
      local mv = table.remove(h.queue, pick_i)
      h.voices[mv[1]] = mv[2]
    else
      for _, mv in ipairs(h.queue) do h.voices[mv[1]] = mv[2] end
      h.queue = {}
    end
  end
  if #h.queue == 0 then h.borrow_tail = false end
  publish(S)
end

-- the minor iv in the current mode, as raw midi notes
local function minor_iv_notes(base, mode, colour)
  local r = T.degree(base, mode, 4)
  local c = {}
  for i, off in ipairs(MINOR_IV[colour] or MINOR_IV[1]) do
    local n = r + off
    while n - base > 19 do n = n - 12 end
    c[i] = n
  end
  return c
end

------------------------------------------------------------------------
-- progression bookkeeping
------------------------------------------------------------------------

-- a loop (re)starts: count it; a borrowed iv is only kept if it's been 4+
-- loops since the last one
local function start_loop(h)
  h.loops = (h.loops or 0) + 1
  for i = #h.prog, 1, -1 do
    local st = h.prog[i]
    if st.borrowed then
      if h.iv_loop and h.loops - h.iv_loop < 4 then
        table.remove(h.prog, i)
      else
        h.iv_loop = h.loops
      end
    end
  end
end

-- the borrowed iv is played once, then dropped from the loop
local function leave_step(h)
  local st = h.prog[h.i]
  if st.borrowed then
    table.remove(h.prog, h.i)
    h.i = h.i - 1
  end
end

local function advance(S)
  local h = S.h
  leave_step(h)
  h.i = h.i + 1
  if h.i > #h.prog then h.i = 1; start_loop(h) end
end

local function adopt(S)
  local h = S.h
  h.prog, h.next, h.i = h.next, nil, 1
  start_loop(h)
end

------------------------------------------------------------------------
-- api
------------------------------------------------------------------------

-- fresh progression from step 1 (new track, harmony mode change). call
-- H.retarget after it to sound the chord.
function H.new_prog(S)
  S.h = S.h or {}
  local h = S.h
  h.prog, h.next = build(S), nil
  h.i, h.queue, h.per_bar = 1, {}, 1
  start_loop(h)
  begin_step(S)
end

-- a new progression lands when the current chord has finished its hold
function H.next_prog(S)
  if S.h then S.h.next = build(S) end
end

-- sound the current step. drifting morphs into it unless `instant`. a hand
-- key / mode change lands here: if the mode makes this step a dim / aug
-- chord the loop is rebuilt, and a cold voicing on a minor chord goes m7.
function H.retarget(S, instant)
  local h = S.h
  if not h or not h.prog then return end
  if not prog_valid(S.mode, h.prog) then
    h.prog, h.i, h.queue = build(S), 1, {}
    h.next = nil
    start_loop(h)
    begin_step(S)
  end
  local st = h.prog[h.i]
  if not colour_ok(S.mode, st, h.colour or 1) then h.colour = 1 end
  local colour = h.colour or 1
  local base = 48 + S.root_pc
  h.root_abs = (S.root_pc + T.degree(0, S.mode, st.deg)) % 12
  local function voice_raw(col)
    return st.minor and minor_iv_notes(base, S.mode, col) or T.chord(base, S.mode, st.deg, col)
  end
  local raw = voice_raw(colour)
  -- never a dim / aug triad, tritone or b9 in the stack: fall back to a
  -- plain colour
  if dark_stack(raw, h.root_abs) then
    for _, col in ipairs({2, 3, 1, 4}) do
      local r = voice_raw(col)
      if not dark_stack(r, h.root_abs) and colour_ok(S.mode, st, col) then
        colour, raw = col, r
        break
      end
    end
    h.colour = colour
  end
  tidy(raw)
  local target = (S.harmony == 1 or not h.voices) and raw or lead(h.voices, raw)
  local morphing = S.harmony == 3 and h.voices and not instant
  h.borrow_tail = morphing and (S.chord_borrowed and not st.borrowed) or false

  if morphing then
    -- lead() kept each voice's slot: queue the ones that move
    h.queue = {}
    for vi = 1, 4 do
      if h.voices[vi] ~= target[vi] then h.queue[#h.queue + 1] = {vi, target[vi]} end
    end
    for k = #h.queue, 2, -1 do
      local j = math.random(k)
      h.queue[k], h.queue[j] = h.queue[j], h.queue[k]
    end
    -- spread over the first ~60% of the chord; the first move is now
    local span = math.max(1, math.floor(need(S) * 0.6))
    h.per_bar = math.max(1, math.ceil(#h.queue / span))
    morph(S)
  else
    h.voices = {target[1], target[2], target[3], target[4]}
    h.queue = {}
    publish(S)
  end

  -- root, label
  h.root_pc = T.degree(0, S.mode, st.deg) % 12
  local third = st.minor and 3 or (T.degree(0, S.mode, st.deg + 2) - T.degree(0, S.mode, st.deg)) % 12
  local name = ROMAN[h.root_pc]
  h.label = third == 3 and name:lower() or name
  h.minor_tonic = (T.MODES[S.mode].steps[3] == 3)
  S.chord_root_pc  = h.root_pc
  S.chord_degree   = st.deg
  S.chord_voicing  = colour
  S.chord_borrowed = st.borrowed and true or false
  set_pedal(S)
end

-- phrase start: a queued progression may land now if the chord has held
-- its minimum; otherwise it waits for the end of the step
function H.phrase(S)
  local h = S.h
  if not h or not h.prog then return end
  if h.next and h.held >= MIN_HOLD then
    adopt(S)
    begin_step(S)
    H.retarget(S)
  end
end

-- once a bar, after the bloom is known. `bar_in_block` is unused: chords
-- are on their own slow clock.
function H.bar(S, bar_in_block)
  local h = S.h
  if not h or not h.prog then return end

  if h.held >= need(S) then
    if h.next then adopt(S) else advance(S) end
    begin_step(S)
    H.retarget(S)
  elseif #h.queue > 0 then
    morph(S)
  end
  -- the section may have changed: pedal follows it
  local pedal = PEDAL_SECTIONS[S.section] and S.harmony ~= 1 or false
  if pedal ~= h.pedal then set_pedal(S) end
  h.held = h.held + 1
end

return H
