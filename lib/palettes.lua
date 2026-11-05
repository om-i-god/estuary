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
P.VOICES = {"rhodes", "bell", "sine", "marimba", "vibes", "celesta", "kalimba", "flute", "glass"}
P.PADS = {"warm", "strings", "glass", "air", "organ"}

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
}

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
function P.choose(seed, last)
  local n = #P.PALETTES
  local h = (math.floor(seed or 1) * 2654435761) % 4294967296
  h = (h ~ (h >> 13)) % 4294967296
  local i = (h % n) + 1
  if last and i == last and n > 1 then
    i = ((i - 1 + 1 + (h >> 8) % (n - 1)) % n) + 1
  end
  return i
end

-- a new track's palette. pin: 0 = auto, else a palette index. rebuilding
-- the same seed (rebuild, a play-mode change) keeps the palette it had
function P.for_track(S, seed)
  local pin = S.palette_pin or 0
  if pin > 0 then
    S.palette = pin
  elseif not (S.palette and S.palette_seed == seed) then
    S.palette = P.choose(seed, S.palette)
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

-- the palette's tilts: brightness offset, send multiplier
function P.tilt(palette)
  local p = P.PALETTES[palette or 1] or P.PALETTES[1]
  return p.bright or 0, p.send or 1
end

return P
