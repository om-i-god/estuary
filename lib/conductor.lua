-- estuary / conductor
-- runs once per bar. owns the bloom arc (set or track), decides which
-- motifs sound (never more than three), fades parts over bars, mutates
-- material on phrase edges, starts water swells, and lets swells change
-- the music.

local T = include("lib/theory")
local H = include("lib/harmony")
local M = include("lib/motifs")
local N = include("lib/nature")
local PAL = include("lib/palettes")

local C = {}
C.N = N

-- shared state / constants (declared before any function that uses them)
local PARTS = {"motif1", "motif2", "motif3", "motif4", "pad", "pedal"}
local FADE_UP, FADE_DOWN = 0.2, 0.125     -- per bar: ~5 bars in, ~8 bars out
local MOMENT_P = {[0] = 0, [1] = 0.35, [2] = 0.7}

-- track mode arc: fractions of total length; bloom ramps e0 -> e1
C.SECTIONS = {
  {name = "arrival",  len = 0.15, e0 = 0.05, e1 = 0.30},
  {name = "bloom",    len = 0.25, e0 = 0.30, e1 = 0.85},
  {name = "tide",     len = 0.15, e0 = 0.50, e1 = 0.15, swell = true},
  {name = "return",   len = 0.25, e0 = 0.40, e1 = 0.75},
  {name = "settling", len = 0.20, e0 = 0.60, e1 = 0.00},
}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function pick(t) return t[math.random(#t)] end
local function plen(S) return S.phrase_len or 16 end
local function tempo(S) return S.tempo or 72 end

------------------------------------------------------------------------
-- set mode cycle
------------------------------------------------------------------------

-- slow swell: 0.05 at the trough, 0.95 at the crest
local function base_bloom(ph)
  return 0.05 + 0.9 * (0.5 - 0.5 * math.cos(ph * 2 * math.pi))
end

-- 1-2 swell bars per cycle, outside the top 20% of bloom, kept apart
local function schedule_swells(S)
  local n = S.cycle_bars
  local first, second = {}, {}
  for b = math.floor(n * 0.03), math.floor(n * 0.9) do
    if base_bloom(b / n) <= 0.8 then
      if b < n / 2 then first[#first + 1] = b else second[#second + 1] = b end
    end
  end
  local all = {}
  for _, t in ipairs({first, second}) do for _, b in ipairs(t) do all[#all + 1] = b end end
  if math.random() < 0.5 then
    S.swell_slots = {pick(all)}
  else
    S.swell_slots = {pick(first), pick(second)}
  end
end

local function start_cycle(S)
  S.cycle = (S.cycle or 0) + 1
  S.cycle_start = S.track_bar
  S.cycle_bars = math.floor(math.random(20, 40) * tempo(S) / 4)
  schedule_swells(S)
end

------------------------------------------------------------------------
-- track mode arc
------------------------------------------------------------------------

local function track_total(S)
  return math.max(48, math.floor((S.track_minutes or 12) * tempo(S) / 4))
end

local function track_section(S)
  local total = track_total(S)
  local start = 0
  for i, sec in ipairs(C.SECTIONS) do
    local len = math.floor(sec.len * total + 0.5)
    if i == #C.SECTIONS then len = total - start end
    if S.track_bar < start + len then
      return sec, (S.track_bar - start) / math.max(1, len - 1), total
    end
    start = start + len
  end
  return C.SECTIONS[#C.SECTIONS], 1, total
end

-- also publishes S.section / S.progress
local function base_energy(S)
  if S.mode_play == 2 then
    local sec, prog, total = track_section(S)
    S.section = sec.name
    S.progress = S.track_bar / total
    S.total_bars = total
    return sec.e0 + (sec.e1 - sec.e0) * clamp(prog, 0, 1)
  end
  local ph = ((S.track_bar - S.cycle_start) % S.cycle_bars) / S.cycle_bars
  S.walk = clamp((S.walk or 0) + (math.random() - 0.5) * 0.03, -0.1, 0.1)
  local e = clamp(base_bloom(ph) + S.walk, 0.05, 1)
  S.progress = ph
  S.section = e < 0.2 and "trough" or "swell"
  return e
end

------------------------------------------------------------------------
-- material
------------------------------------------------------------------------

local function retire(S, slot)
  S.motifs[slot] = M.new(slot)
  S.born[slot] = S.track_bar
end

-- the slot rotation will bring in next: the one resting longest (ties: the
-- lowest)
local function next_in(S)
  local best
  for i = 1, 4 do
    if not S.sounding[i] then
      if not best or S.rest_bars[i] > S.rest_bars[best] then best = i end
    end
  end
  return best
end

-- new track: seed drives the material; the key may move unless following
function C.new_track(S, seed, move_key)
  math.randomseed(seed)
  S.seed = seed
  PAL.for_track(S, seed)          -- leaves math.random alone
  S.gain, S.muted, S.soloed = {}, S.muted or {}, S.soloed or {}
  if move_key and not S.listen_follow then
    S.root_pc = (S.root_pc + pick({0, 5, 7, -5, 3})) % 12
  end
  S.motifs, S.born, S.sounding = {}, {}, {false, false, false, false}
  -- who enters first is the seed's: a small head start in rest
  S.rest_bars, S.on_bars = {0, 1, 2, 3}, {0, 0, 0, 0}
  for i = 4, 2, -1 do
    local j = math.random(i)
    S.rest_bars[i], S.rest_bars[j] = S.rest_bars[j], S.rest_bars[i]
  end
  S.track_bar, S.nudge, S.walk = 0, 0, 0
  S.breathe_until = 0
  S.swell_pending = false
  S.phrases_since_moment = 3
  S.cap = 1
  S.bloom = 0.05
  for i = 1, 4 do retire(S, i) end
  for _, k in ipairs(PARTS) do S.gain[k] = 0 end
  S.cycle = 0
  if S.mode_play ~= 2 then start_cycle(S) end
  S.section = (S.mode_play == 2) and "arrival" or "trough"
  H.new_prog(S)
  H.retarget(S, true)
end

------------------------------------------------------------------------
-- who plays
------------------------------------------------------------------------

local function compute_cap(S)
  local cap = S.bloom < 0.3 and 1 or (S.bloom < 0.6 and 2 or 3)
  -- a new motif being introduced (wanted or still heard) keeps it to two
  for i = 1, 4 do
    local heard = S.sounding[i] or (S.gain["motif" .. i] or 0) > 0.02
    if heard and S.motifs[i].intro > 0 then cap = math.min(cap, 2) end
  end
  if N.state == "rising" or N.state == "held" or S.track_bar < S.breathe_until then
    cap = 1
  end
  return clamp(cap, 1, 3)
end

-- hand mutes / solos decide which slots are eligible; the cap trims last.
-- the four slots take turns: the longest-rested comes in first, the
-- longest-sounding goes first, and at a phrase edge (`edge`) a full texture
-- hands one place to a slot that has rested two phrases (the newcomer waits
-- in fade() for the leaver's tail, so the cap holds)
local ROTATE_PHRASES = 2
function C.decide(S, edge)
  S.cap = compute_cap(S)
  local muted, soloed = S.muted or {}, S.soloed or {}
  local any_solo = next(soloed) ~= nil
  local function eligible(i)
    local k = "motif" .. i
    if muted[k] then return false end
    if any_solo then return soloed[k] == true end
    return true
  end

  local want = {false, false, false, false}
  local n = 0
  -- stability: keep what is already sounding
  for i = 1, 4 do
    if S.sounding[i] and eligible(i) then want[i] = true; n = n + 1 end
  end
  local function longest_on()
    local best
    for i = 1, 4 do
      if want[i] and (not best or S.on_bars[i] >= S.on_bars[best]) then best = i end
    end
    return best
  end
  -- rotate: a full texture gives the longest-sounding slot's place to one
  -- that has rested two phrases (the leaver has sounded two phrases too)
  if edge and n >= S.cap then
    local due = ROTATE_PHRASES * plen(S)
    local waiting = false
    for i = 1, 4 do
      if not want[i] and eligible(i) and S.rest_bars[i] >= due then waiting = true end
    end
    local out = longest_on()
    if waiting and out and S.on_bars[out] >= due then want[out] = false; n = n - 1 end
  end
  -- fill free capacity (longest rested first) at 4-bar edges, or when silent
  if S.track_bar % 4 == 0 or n == 0 then
    while n < S.cap do
      local best
      for i = 1, 4 do
        if not want[i] and eligible(i) and not S.sounding[i] then
          if not best or S.rest_bars[i] > S.rest_bars[best] then best = i end
        end
      end
      if not best then break end
      want[best] = true; n = n + 1
    end
  end
  -- enforce the cap last: drop the longest-sounding
  while n > S.cap do
    want[longest_on()] = false; n = n - 1
  end
  S.sounding = want

  -- pad and pedal ride the bloom; both thin under a swell
  local b = S.bloom
  local pad_want = b >= 0.15
  local pedal_want = b >= 0.45 and b <= 0.9
  local function ok(k)
    if muted[k] then return false end
    if any_solo then return soloed[k] == true end
    return true
  end
  local thin = (N.state ~= "idle") and 0.5 or 1
  S.target = S.target or {}
  for i = 1, 4 do S.target["motif" .. i] = want[i] and 1 or 0 end
  S.target.pad = (pad_want and ok("pad")) and thin or 0
  S.target.pedal = (pedal_want and ok("pedal")) and thin or 0
end

local function fade(S)
  local muted = S.muted or {}
  local audible = 0
  -- falling (and held) parts first; a muted part is silent at once. a motif
  -- heard last bar still counts: its last note (<= 4 beats) may ring on
  for _, k in ipairs(PARTS) do
    local g, t = S.gain[k] or 0, S.target[k] or 0
    local rang = g > 0.02
    if muted[k] then g = 0
    elseif t <= g then g = math.max(t, g - FADE_DOWN) end
    S.gain[k] = g
    if (g > 0.02 or rang) and k:sub(1, 5) == "motif" then audible = audible + 1 end
  end
  -- rising parts; a motif may leave silence only while fewer than three
  -- motifs are audible (fade tails count)
  for _, k in ipairs(PARTS) do
    local g, t = S.gain[k] or 0, S.target[k] or 0
    if t > g and not muted[k] then
      local is_motif = k:sub(1, 5) == "motif"
      if not is_motif or g > 0.02 or audible < 3 then
        local ng = math.min(t, g + FADE_UP)
        if is_motif and g <= 0.02 and ng > 0.02 then audible = audible + 1 end
        S.gain[k] = ng
      end
    end
  end
end

------------------------------------------------------------------------
-- material changes
------------------------------------------------------------------------

-- a rare retire takes the oldest resting motif, so the new one is
-- introduced when its turn comes rather than swapped in under a sounding one
function C.mutate(S)
  for i = 1, 4 do
    if S.sounding[i] and math.random() < 0.5 then M.mutate(S.motifs[i]) end
  end
  if math.random() < 0.08 then
    local oldest
    for i = 1, 4 do
      if not S.sounding[i] and (not oldest or S.born[i] < S.born[oldest]) then oldest = i end
    end
    if oldest then retire(S, oldest) end
  end
end

-- the grid's rewrite: a fresh motif in this slot
function C.rewrite(S, slot) retire(S, slot) end

-- a swell has turned the tide: one change to the music
local function swell_changed(S)
  local opts = {"motif", "prog"}
  if not S.listen_follow then opts[#opts + 1] = "key" end
  local what = pick(opts)
  if what == "motif" then
    -- the slot rotation brings in next, so the new motif is the next thing
    -- heard as the water recedes
    local slot = next_in(S)
    if slot then retire(S, slot) end
  elseif what == "prog" then
    H.next_prog(S)
  else
    S.root_pc = (S.root_pc + pick({5, 7, -5, -7})) % 12
    S.key_moved = true
    H.retarget(S, true)
  end
end

-- phrase edge: mutations, a chance of a passing moment
function C.phrase(S)
  C.decide(S, true)
  if not S.freeze then C.mutate(S) end
  S.phrases_since_moment = (S.phrases_since_moment or 3) + 1
  local p = MOMENT_P[S.moment_freq == nil and 1 or S.moment_freq] or 0
  if S.phrases_since_moment >= 3 and not S.swell_pending and S.track_bar > 0
     and math.random() < p and N.moment(S) then
    S.phrases_since_moment = 0
  end
end

------------------------------------------------------------------------
-- hands
------------------------------------------------------------------------

function C.breathe(S) S.breathe_until = S.track_bar + 8 end

function C.tide(S) return N.swell(S) end

function C.nudge(S, d) S.nudge = (S.nudge or 0) + d end

-- ask for a scheduled swell; retried each bar while a moment is running
function C.pending_swell(S) S.swell_pending = true end

------------------------------------------------------------------------
-- per-bar tick
------------------------------------------------------------------------

-- returns "stop" when a track finishes with end action = stop, "next" when
-- a fresh track begins
function C.bar(S)
  local P = plen(S)
  local bar_in_phrase = (S.track_bar % P) + 1

  -- nature first, so cap sees the swell's state
  N.bar(S)

  S.nudge = (S.nudge or 0) * 0.9
  if math.abs(S.nudge) < 0.01 then S.nudge = 0 end

  local prev_section = S.section
  local e = base_energy(S)
  S.bloom = clamp(e + S.nudge, 0, 1)

  -- scheduled swells
  if S.mode_play == 2 then
    if S.section == "tide" and prev_section ~= "tide" then C.pending_swell(S) end
  else
    local rel = S.track_bar - S.cycle_start
    for _, b in ipairs(S.swell_slots) do
      if rel == b then C.pending_swell(S) end
    end
  end
  if S.swell_pending then
    local ok, msg = N.swell(S)
    if ok or msg ~= "moment running" then S.swell_pending = false end
  end

  if S.swell_change then
    S.swell_change = false
    swell_changed(S)
  end

  if bar_in_phrase == 1 then
    C.phrase(S)
    if S.track_bar > 0 then H.phrase(S) end
  else
    C.decide(S)
  end
  H.bar(S, (S.track_bar % 8) + 1)
  fade(S)
  -- turns: bars each slot has been wanted / resting
  for i = 1, 4 do
    if S.sounding[i] then
      S.on_bars[i], S.rest_bars[i] = S.on_bars[i] + 1, 0
    else
      S.on_bars[i], S.rest_bars[i] = 0, S.rest_bars[i] + 1
    end
  end

  S.track_bar = S.track_bar + 1

  if S.mode_play == 2 then
    if S.track_bar >= (S.total_bars or math.huge) then
      if S.end_action == 1 then return "stop" end
      C.new_track(S, math.random(1, 9999), true)
      return "next"
    end
  elseif S.track_bar - S.cycle_start >= S.cycle_bars then
    start_cycle(S)
  end
end

return C
