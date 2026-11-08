-- estuary / palettes
-- a palette is one record's worth of sound: a voice for each of the four
-- motif slots, a pad character, and small tilts to brightness and sends.
-- each new track picks one (seeded, never the last one again) unless the
-- palette param pins it.
--
-- engine indices: the `note` command's voice arg is the position in VOICES,
-- the `pad_sound` tweak is the position in PADS. both lists only ever grow
-- at the end, so stored params keep pointing at the same sounds.
-- motif slots 2 and 4 sit an octave above slots 1 and 3 (motifs.lua), so
-- the small high voices go there.

local P = {}

-- keep in step with voiceDefs / padDefs in lib/Engine_Estuary.sc
P.VOICES = {"rhodes", "bell", "sine", "marimba", "vibes", "celesta", "kalimba", "flute", "glass", "harp", "koto", "choir", "glock", "piano", "dulcimer", "steelpan", "guitar", "horn"}
P.PADS = {"warm", "strings", "glass", "air", "organ", "shimmer", "tape", "reed"}

-- bright: added to each note's brightness; send: multiplies its echo/reverb send
P.PALETTES = {
  {name = "harbor", voices = {"rhodes", "bell", "sine", "vibes"}, pad = "warm", bright = 0.0, send = 1.0},
  {name = "shallows", voices = {"marimba", "celesta", "flute", "kalimba"}, pad = "air", bright = 0.05, send = 0.9},
  {name = "glasshouse", voices = {"sine", "glass", "rhodes", "bell"}, pad = "glass", bright = 0.05, send = 1.15},
  {name = "morning", voices = {"vibes", "celesta", "sine", "marimba"}, pad = "strings", bright = 0.1, send = 1.0},
  {name = "riverbank", voices = {"flute", "kalimba", "marimba", "celesta"}, pad = "warm", bright = 0.0, send = 0.95},
  {name = "tidepool", voices = {"kalimba", "glass", "marimba", "bell"}, pad = "organ", bright = 0.0, send = 1.1},
  {name = "veranda", voices = {"rhodes", "vibes", "flute", "celesta"}, pad = "strings", bright = -0.05, send = 1.0},
  {name = "mist", voices = {"sine", "glass", "flute", "bell"}, pad = "air", bright = -0.05, send = 1.2},
  {name = "atrium", voices = {"rhodes", "celesta", "vibes", "glass"}, pad = "organ", bright = 0.05, send = 1.05},
  -- sounds v3 (names never clash with a visual theme)
  {name = "lantern", voices = {"piano", "glock", "choir", "celesta"}, pad = "shimmer", bright = 0.05, send = 1.1},
  {name = "teahouse", voices = {"koto", "dulcimer", "flute", "glock"}, pad = "tape", bright = 0.0, send = 0.95},
  {name = "chapel", voices = {"choir", "bell", "harp", "glass"}, pad = "shimmer", bright = 0.0, send = 1.2},
  {name = "orchard", voices = {"harp", "glock", "guitar", "koto"}, pad = "reed", bright = 0.05, send = 0.95},
  {name = "parlour", voices = {"piano", "vibes", "horn", "celesta"}, pad = "tape", bright = -0.05, send = 1.0},
  {name = "lagoon", voices = {"steelpan", "harp", "piano", "glock"}, pad = "air", bright = 0.05, send = 1.15},
  {name = "boathouse", voices = {"guitar", "dulcimer", "piano", "harp"}, pad = "reed", bright = 0.0, send = 1.0},
  {name = "sandbar", voices = {"koto", "steelpan", "choir", "guitar"}, pad = "shimmer", bright = 0.05, send = 1.05},
  {name = "promenade", voices = {"horn", "steelpan", "rhodes", "dulcimer"}, pad = "strings", bright = 0.0, send = 1.0},
  {name = "cloister", voices = {"choir", "dulcimer", "horn", "bell"}, pad = "glass", bright = -0.05, send = 1.2},
  {name = "courtyard", voices = {"horn", "steelpan", "guitar", "koto"}, pad = "tape", bright = 0.0, send = 0.95},
}

-- what the sound listens to (PARAMS > SOUND > react source): the engine's
-- react_src index is the position here
P.REACT_SOURCES = {"water", "room", "self", "all"}

P.NAMES = {}
for i, p in ipairs(P.PALETTES) do P.NAMES[i] = p.name end

local function index_of(t, name)
  for i, v in ipairs(t) do if v == name then return i end end
  error("palettes: unknown name " .. tostring(name))
end

function P.voice_index(name) return index_of(P.VOICES, name) end
function P.pad_index(name) return index_of(P.PADS, name) end

-- a seeded pick that leaves math.random alone (the seed's music must not
-- change because a palette was chosen). never `last` again.
local function hash(seed)
  local h = (math.floor(seed or 1) * 2654435761) % 4294967296
  return (h ~ (h >> 13)) % 4294967296
end

function P.choose(seed, last)
  local n = #P.PALETTES
  local h = hash(seed)
  local i = (h % n) + 1
  if last and i == last and n > 1 then
    i = ((i - 1 + 1 + (h >> 8) % (n - 1)) % n) + 1
  end
  return i
end

-- a seeded draw from the bag of palettes not yet heard: every palette
-- comes round once before any comes again, and the bag is refilled without
-- the one playing, so none ever comes twice in a row. leaves math.random alone
local function draw(S, seed)
  local n = #P.PALETTES
  if n < 2 then return 1 end
  local bag = S.palette_bag or {}
  -- never the one playing (a pin may have set it while it was still in the bag)
  for j = #bag, 1, -1 do if bag[j] == S.palette then table.remove(bag, j) end end
  if #bag == 0 then
    for i = 1, n do if i ~= S.palette then bag[#bag + 1] = i end end
  end
  -- of those, the ones bringing the most voices not yet heard this round
  -- (so every voice comes round soon), then a seeded pick among them
  local heard = S.voices_heard or {}
  local best, top = {}, -1
  for j, pi in ipairs(bag) do
    local new = 0
    for _, v in ipairs(P.PALETTES[pi].voices) do if not heard[v] then new = new + 1 end end
    if new > top then best, top = {j}, new elseif new == top then best[#best + 1] = j end
  end
  local i = table.remove(bag, best[(hash(seed) % #best) + 1])
  for _, v in ipairs(P.PALETTES[i].voices) do heard[v] = true end
  local all = true
  for _, v in ipairs(P.VOICES) do if not heard[v] then all = false end end
  S.voices_heard = all and {} or heard
  S.palette_bag = bag
  return i
end

-- a new track's palette. pin: 0 = auto, else a palette index. rebuilding
-- the same seed (rebuild, a play-mode change) keeps the palette it had
function P.for_track(S, seed)
  local pin = S.palette_pin or 0
  if pin > 0 then
    S.palette = pin
  elseif not (S.palette and S.palette_seed == seed) then
    S.palette = draw(S, seed)
  end
  S.palette_seed = seed
  return S.palette
end

-- the palette param (1 auto, then PALETTES): pin one now, or go back to
-- auto. either way the next rebuild picks afresh (a palette chosen under a
-- pin is not that seed's own)
function P.pin(S, v)
  S.palette_pin = v - 1
  if v > 1 then S.palette = v - 1 end
  S.palette_seed = nil
end

-- the `motifN voice` param (1 auto, then VOICES) -> engine voice index
function P.motif_voice(v, palette, slot)
  if v and v > 1 then return v - 1 end
  local p = P.PALETTES[palette or 1] or P.PALETTES[1]
  return P.voice_index(p.voices[((slot - 1) % 4) + 1])
end

-- the `pad sound` param (1 auto, then PADS) -> engine pad_sound index
function P.pad_sound(v, palette)
  if v and v > 1 then return v - 1 end
  local p = P.PALETTES[palette or 1] or P.PALETTES[1]
  return P.pad_index(p.pad)
end

-- the `react` param (0..1) -> the engine's react depth, clamped
function P.react(v)
  return math.max(0, math.min(1, tonumber(v) or 0))
end

-- the `react source` param (an index into REACT_SOURCES) -> react_src
function P.react_src(v)
  return math.max(1, math.min(#P.REACT_SOURCES, math.floor(tonumber(v) or #P.REACT_SOURCES)))
end

-- the palette's tilts: brightness offset, send multiplier
function P.tilt(palette)
  local p = P.PALETTES[palette or 1] or P.PALETTES[1]
  return p.bright or 0, p.send or 1
end

return P
