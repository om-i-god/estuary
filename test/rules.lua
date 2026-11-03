-- estuary / anti-goal rule checker
-- fed by the sim: R.on_note for every sounded motif note, R.on_bar once a bar.
-- R.report() -> ok, failures.  the rules are the spec's two anti-goals:
-- never busy (<= 3 motifs at once, nothing faster than an 8th, one eighth
-- pair per motif, avoid notes short and never last) and never dark (no rubs,
-- no dim/aug, minor-quality chords only in warm voicings, no moment on a swell).

local T = include("lib/theory")

local R = {}

local EPS = 1e-6
local fails, seen = {}, {}
local cur                          -- the live state table (S)
local ends, last_on, run = {}, {}, {}   -- per slot: note end, last onset, 8th-gap run
R.stats = {notes = 0, bars = 0, max_overlap = 0, avoid = 0, pairs = 0}

local function fail(rule, detail)
  if not seen[rule] then
    seen[rule] = true
    fails[#fails + 1] = rule .. ": " .. detail
  end
end

local function sounding(e) return e.tone ~= nil or e.pass ~= nil end

-- the table holding the chord / motifs, so notes see the chord live
function R.attach(S) cur = S end

local function chord_pcs()
  local set = {}
  for _, n in ipairs(cur and cur.chord or {}) do set[n % 12] = true end
  return set
end

function R.on_note(t, slot, midi, dur, ev)
  R.stats.notes = R.stats.notes + 1

  -- never more than 3 slots sounding at the same instant (by note duration)
  local n = 1
  for s, e in pairs(ends) do
    if s ~= slot and e > t + EPS then n = n + 1 end
  end
  R.stats.max_overlap = math.max(R.stats.max_overlap, n)
  if n > 3 then fail("busy", string.format("%d slots sounding at beat %.1f", n, t)) end
  ends[slot] = t + dur

  -- onsets: nothing closer than an 8th; eighths only as the single pair
  if last_on[slot] then
    local gap = t - last_on[slot]
    if gap < 0.5 - EPS then
      fail("fast", string.format("slot %d onsets %.2f beats apart at beat %.1f", slot, gap, t))
    end
    if math.abs(gap - 0.5) < EPS then
      run[slot] = (run[slot] or 0) + 1
      if run[slot] == 1 then R.stats.pairs = R.stats.pairs + 1 end
      if run[slot] >= 3 then fail("run", "slot " .. slot .. " ran eighths at beat " .. t) end
    else
      run[slot] = 0
    end
  end
  last_on[slot] = t

  -- avoid notes: a semitone over a chord pc, itself not in the chord
  local pcs = chord_pcs()
  local pc = midi % 12
  if not pcs[pc] and pcs[(pc - 1) % 12] then
    R.stats.avoid = R.stats.avoid + 1
    if dur > 1 + EPS then
      fail("avoid long", string.format("avoid note %d lasts %.1f beats (slot %d)", midi, dur, slot))
    end
    local m = cur and cur.motifs and cur.motifs[slot]
    if m then
      local idx
      for i, e in ipairs(m.events) do if e == ev then idx = i end end
      local later = false
      if idx then
        for i = idx + 1, #m.events do if sounding(m.events[i]) then later = true end end
        if not later then fail("avoid last", "avoid note " .. midi .. " ends the cycle (slot " .. slot .. ")") end
      end
    end
  end
end

local function warm(v)
  for _, w in ipairs(T.WARM_MINOR) do if w == v then return true end end
  return false
end

function R.on_bar(S)
  cur = S
  R.stats.bars = R.stats.bars + 1
  local bar = S.track_bar

  -- chord: no rub, no dim / aug, minor only warm
  if S.chord then
    if T.has_rub(S.chord) then
      fail("rub", string.format("semitone rub in chord {%s} at bar %d", table.concat(S.chord, " "), bar))
    end
    local q = S.chord_borrowed and "min" or T.quality(S.mode, S.chord_degree)
    if q == "dim" or q == "aug" then
      fail("dark", q .. " triad on degree " .. tostring(S.chord_degree) .. " at bar " .. bar)
    end
    if q == "min" and not warm(S.chord_voicing) then
      fail("cold minor", string.format("%s chord %s in voicing %s at bar %d",
        S.chord_borrowed and "borrowed" or "minor", tostring(S.chord_label), tostring(S.chord_voicing), bar))
    end
  end

  -- nature: a passing moment never overlaps a swell
  if S.moment_active and S.nature_state and S.nature_state ~= "idle" then
    fail("moment+swell", "moment active during a " .. S.nature_state .. " swell at bar " .. bar)
  end

  -- at most 3 audible, unmuted motifs
  local audible = 0
  for i = 1, 4 do
    local k = "motif" .. i
    if (S.gain[k] or 0) > 0.02 and not (S.muted and S.muted[k]) then audible = audible + 1 end
  end
  if audible > 3 then fail("cap", audible .. " motifs audible at bar " .. bar) end

  -- every motif: 3-7 notes, at least one rest, no eighth run built in
  for i, m in ipairs(S.motifs or {}) do
    local notes, rests, ones = 0, 0, 0
    for _, e in ipairs(m.events) do
      if sounding(e) then notes = notes + 1; if e.dur == 1 then ones = ones + 1 end
      else rests = rests + 1 end
    end
    if notes < 3 or notes > 7 then fail("notes", "motif " .. i .. " has " .. notes .. " notes") end
    if rests < 1 then fail("rests", "motif " .. i .. " has no rest") end
    if ones > 2 then fail("pair", "motif " .. i .. " has " .. ones .. " eighth notes") end
    if m.cycle % 4 ~= 2 then fail("cycle", "motif " .. i .. " cycle of " .. m.cycle .. " eighths is not an odd number of beats") end
  end
end

function R.report()
  return #fails == 0, fails
end

return R
