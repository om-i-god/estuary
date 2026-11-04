-- estuary / theory
-- bright modes, degree math, warm chord voicings (no rubs)

local T = {}

T.NOTE_NAMES = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}

-- all bright. `short` is for the screen. `rel` = semitones from the relative
-- natural minor's root to this mode's root: following an input heard as
-- A minor puts ionian on C, lydian on F, ... the same notes either way.
-- pentatonics use ionian `steps` so degree math stays seven-note; `melody`
-- is the pentatonic subset the motifs sing, `passing` are the
-- neighbour tones allowed only as passing notes.
T.MODES = {
  {name = "ionian",             short = "ion",  rel = 3,  steps = {0, 2, 4, 5, 7, 9, 11}},
  {name = "lydian",             short = "lyd",  rel = 8,  steps = {0, 2, 4, 6, 7, 9, 11}},
  {name = "mixolydian",         short = "mix",  rel = 10, steps = {0, 2, 4, 5, 7, 9, 10}},
  {name = "major pentatonic",   short = "pent", rel = 3,  steps = {0, 2, 4, 5, 7, 9, 11},
   melody = {0, 2, 4, 7, 9}},
  {name = "passing pentatonic", short = "pass", rel = 3,  steps = {0, 2, 4, 5, 7, 9, 11},
   melody = {0, 2, 4, 7, 9}, passing = {5, 11}},
  {name = "dorian",             short = "dor",  rel = 5,  steps = {0, 2, 3, 5, 7, 9, 10}},
}
T.MODE_NAMES = {}
for i, m in ipairs(T.MODES) do T.MODE_NAMES[i] = m.name end

-- the moods a new track or set modulation drifts between
T.MODE_POOL = {1, 1, 2, 2, 4, 5, 5, 3, 6}

-- root for `mode` that shares the notes of the natural minor on `minor_pc`
function T.root_for(minor_pc, mode)
  return (minor_pc + T.MODES[mode].rel) % 12
end

-- the natural-minor root whose notes `mode` on `pc` borrows
function T.minor_of(pc, mode)
  return (pc - T.MODES[mode].rel) % 12
end

-- stacked scale-degree offsets from the chord's own degree
T.VOICINGS = {
  {name = "maj7",      degs = {0, 2, 4, 6}},
  {name = "add9",      degs = {0, 2, 4, 8}},
  {name = "6/9",       degs = {0, 4, 5, 8}},
  {name = "sus2",      degs = {0, 1, 4, 7}},
  {name = "quartal",   degs = {2, 5, 8, 11}},  -- perfect 4ths over the chord (3-6-9-12)
  {name = "open",      degs = {0, 4, 8, 11}},   -- open 5th + 9
  {name = "rootless9", degs = {2, 4, 6, 8}},
}
T.VOICING_NAMES = {}
for i, v in ipairs(T.VOICINGS) do T.VOICING_NAMES[i] = v.name end

-- voicings allowed on minor-quality chords: maj7 (m7), rootless9 (m9), open
T.WARM_MINOR = {1, 7, 6}

-- a minor chord on `degree` whose diatonic 9th is a semitone over its root
-- (iii in ionian): only the plain m7 keeps that b9 out of the stack
function T.b9_degree(mode, degree)
  return (T.degree(0, mode, degree + 1) - T.degree(0, mode, degree)) % 12 == 1
end

-- midi note for scale degree d (1-based; may run past 7 or below 1)
function T.degree(base, mode, d)
  local steps = T.MODES[mode].steps
  local i     = d - 1
  local oct   = math.floor(i / 7)
  return base + steps[(i % 7) + 1] + 12 * oct
end

-- triad quality on `degree`: "maj" | "min" | "dim" | "aug"
function T.quality(mode, degree)
  local r  = T.degree(0, mode, degree)
  local th = (T.degree(0, mode, degree + 2) - r) % 12
  local fi = (T.degree(0, mode, degree + 4) - r) % 12
  if th == 4 and fi == 7 then return "maj" end
  if th == 3 and fi == 7 then return "min" end
  if th == 3 and fi == 6 then return "dim" end
  if th == 4 and fi == 8 then return "aug" end
  return "maj"
end

-- true if any adjacent pair (ascending) is one semitone apart
function T.has_rub(notes)
  local s = {}
  for i, n in ipairs(notes) do s[i] = n end
  table.sort(s)
  for i = 1, #s - 1 do
    if s[i + 1] - s[i] == 1 then return true end
  end
  return false
end

-- four notes for chord on `degree`, voiced from `base` (midi of key root),
-- ascending, with adjacent semitones spread out by lifting the upper note
function T.chord(base, mode, degree, voicing)
  local out = {}
  for i, off in ipairs(T.VOICINGS[voicing].degs) do
    out[i] = T.degree(base, mode, degree + off)
  end
  -- keep the stab in a narrow band: fold anything a 10th+ above base down
  for i = 1, 4 do
    while out[i] - base > 19 do out[i] = out[i] - 12 end
  end
  table.sort(out)
  -- unrub: lift the upper note of any semitone pair an octave
  for _ = 1, 16 do
    local fixed = true
    for i = 1, #out - 1 do
      if out[i + 1] - out[i] == 1 then
        out[i + 1] = out[i + 1] + 12
        table.sort(out)
        fixed = false
        break
      end
    end
    if fixed then break end
  end
  return out
end

function T.name(pc, mode, short)
  local m = T.MODES[mode]
  return T.NOTE_NAMES[(pc % 12) + 1] .. " " .. (short and m.short or m.name)
end

return T
