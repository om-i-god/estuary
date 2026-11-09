-- estuary / anti-goal rule checker
-- fed by the sim: R.on_note for every sounded motif note, R.on_bar once a bar.
-- R.report() -> ok, failures.  the rules are the spec's two anti-goals:
-- never busy (<= 3 motifs at once, nothing faster than an 8th, one eighth
-- pair per motif, avoid notes short and never last) and never dark (no rubs,
-- no dim/aug, minor-quality chords only in warm voicings, no moment on a swell).
-- also: chord pcs inside the mode (b3/b6 only on the borrowed iv), no
-- tritone, no b9 over the chord root, small singable motif leaps and span,
-- no semitone between the pedal and the chord, cycles of 7-15 whole beats
-- (odd beats unless the motif fits the bar of a meter off 4/4), no held
-- melody note a semitone right above a pad note, and no two motifs holding
-- a semitone apart for more than a beat.

local T = include("lib/theory")

local R = {}

local EPS = 1e-6
local fails, seen = {}, {}
local cur                          -- the live state table (S)
local ends, last_on, run, last_motif, hist = {}, {}, {}, {}, {}   -- per slot: note end, last onset, 8th-gap run
local line = {}                    -- per slot: the cycle being sung {m, key, idx, last, lo, hi}
local last_midi = {}               -- per slot: the latest note
local pedal                        -- the sounding pedal {midi, till} (beats), or nil
local now = 0                      -- latest time seen (beats)
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

-- the pedal the sim heard start (midi, sustain in beats), or nil = released
function R.on_pedal(t, midi, dur)
  now = math.max(now, t)
  pedal = midi and {midi = midi, till = t + dur} or nil
  if cur then R.check_live(cur) end
end

local function event_index(m, ev)
  for i, e in ipairs(m and m.events or {}) do if e == ev then return i end end
end

function R.on_note(t, slot, midi, dur, ev)
  R.stats.notes = R.stats.notes + 1
  now = math.max(now, t)
  if cur then R.check_live(cur) end

  -- never more than 3 slots sounding at the same instant (by note duration)
  local n = 1
  for s, e in pairs(ends) do
    if s ~= slot and e > t + EPS then n = n + 1 end
  end
  R.stats.max_overlap = math.max(R.stats.max_overlap, n)
  if n > 3 then fail("busy", string.format("%d slots sounding at beat %.1f", n, t)) end
  -- two motifs a semitone apart for more than a beat is a held rub
  for s, e in pairs(ends) do
    if s ~= slot and e > t + EPS and math.abs((last_midi[s] or -99) - midi) == 1
       and math.min(e, t + dur) - t > 1 + EPS then
      fail("motif rub", string.format("slots %d and %d hold %d / %d together at beat %.1f", s, slot, last_midi[s], midi, t))
    end
  end
  ends[slot] = t + dur
  last_midi[slot] = midi

  -- a retired motif's replacement starts a fresh run (its first note may land
  -- an 8th after the old motif's last; that gap belongs to neither)
  local mo = cur and cur.motifs and cur.motifs[slot]
  if mo ~= last_motif[slot] then run[slot] = 0; last_on[slot] = nil; last_motif[slot] = mo end

  -- onsets: nothing closer than an 8th; eighths only as the single pair.
  -- `t` comes from the sim's own sync accounting (not the step counter), so a
  -- wrong clock division shows up here. a {1,1} pair makes two consecutive
  -- 0.5-beat gaps (three onsets); a third in a row means two adjacent pairs,
  -- and the structural check in on_bar (<= 2 eighth notes per motif) backs it.
  if last_on[slot] then
    local gap = t - last_on[slot]
    if gap < 0.5 - EPS then
      fail("fast", string.format("slot %d onsets %.2f beats apart at beat %.1f", slot, gap, t))
    end
    if math.abs(gap - 0.5) < EPS then
      run[slot] = (run[slot] or 0) + 1
      if run[slot] == 1 then R.stats.pairs = R.stats.pairs + 1 end
      if run[slot] >= 3 then
        local d = {}
        for _, e in ipairs(cur and cur.motifs and cur.motifs[slot] and cur.motifs[slot].events or {}) do
          d[#d + 1] = (sounding(e) and "n" or "r") .. e.dur
        end
        fail("run", "slot " .. slot .. " ran eighths at beat " .. t .. " motif " .. table.concat(d, " ") .. " recent " .. table.concat(hist[slot], " "))
      end
    else
      run[slot] = 0
    end
  end
  last_on[slot] = t
  hist[slot] = hist[slot] or {}
  table.insert(hist[slot], string.format("%.1f/%d", t, ev.dur))
  if #hist[slot] > 6 then table.remove(hist[slot], 1) end

  -- small, singable lines: within one cycle under one chord, adjacent sung
  -- notes are <= an octave apart and the whole cycle spans <= 16 semitones
  local mo2 = cur and cur.motifs and cur.motifs[slot]
  local idx = event_index(mo2, ev)
  if mo2 and idx then
    local key = table.concat(cur.chord or {}, ",")
    local l = line[slot]
    if not l or l.m ~= mo2 or l.key ~= key or idx <= l.idx then
      line[slot] = {m = mo2, key = key, idx = idx, last = midi, lo = midi, hi = midi}
    else
      local adjacent = true
      for i = l.idx + 1, idx - 1 do if sounding(mo2.events[i]) then adjacent = false end end
      if adjacent and math.abs(midi - l.last) > 12 then
        fail("leap", string.format("slot %d leaps %d -> %d at beat %.1f chord {%s}", slot, l.last, midi, t, key))
      end
      l.idx, l.last = idx, midi
      l.lo, l.hi = math.min(l.lo, midi), math.max(l.hi, midi)
      if l.hi - l.lo > 16 then
        fail("span", string.format("slot %d cycle spans %d-%d at beat %.1f chord {%s}", slot, l.lo, l.hi, t, key))
      end
    end
  end

  -- register-exact avoid: a held melody note a semitone right above a pad
  -- note (the root over a maj7 with the 7th on top)
  if dur > 1 + EPS then
    for _, c in ipairs(cur and cur.chord or {}) do
      if c == midi - 1 or c == midi + 1 then
        fail("avoid reg", string.format("note %d held %.1f beats right over chord note %d (slot %d) chord {%s}",
          midi, dur, c, slot, table.concat(cur.chord, " ")))
      end
    end
  end

  -- avoid notes: a semitone over a chord pc, itself not in the chord
  local pcs = chord_pcs()
  local pc = midi % 12
  if not pcs[pc] and pcs[(pc - 1) % 12] then
    R.stats.avoid = R.stats.avoid + 1
    if dur > 1 + EPS then
      fail("avoid long", string.format("avoid note %d lasts %.1f beats (slot %d) chord {%s} mode %s root %s ev tone=%s pass=%s",
        midi, dur, slot, table.concat(cur.chord or {}, " "), tostring(cur.mode), tostring(cur.root_pc), tostring(ev.tone), tostring(ev.pass)))
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

-- chord and nature checks against the live state. run every bar AND on every
-- note, so a hand retarget replaced before the next bar sample is still seen.
function R.check_live(S)
  local bar = S.track_bar
  -- chord: no rub, no dim / aug, minor only warm
  if S.chord then
    if T.has_rub(S.chord) then
      fail("rub", string.format("semitone rub in chord {%s} at bar %d", table.concat(S.chord, " "), bar))
    end
    -- the voiced notes themselves: no dim or aug triad hiding in the stack
    local pcs = {}
    for _, n in ipairs(S.chord) do pcs[n % 12] = true end
    for pc in pairs(pcs) do
      if pcs[(pc + 3) % 12] and pcs[(pc + 6) % 12] and not pcs[(pc + 7) % 12] then
        fail("dark", "diminished triad in the voiced notes {" .. table.concat(S.chord, " ") .. "} at bar " .. bar)
      end
      if pcs[(pc + 4) % 12] and pcs[(pc + 8) % 12] and not pcs[(pc + 7) % 12] then
        fail("dark", "augmented triad in the voiced notes {" .. table.concat(S.chord, " ") .. "} at bar " .. bar)
      end
    end
    local q = S.chord_borrowed and "min" or T.quality(S.mode, S.chord_degree)
    if q == "dim" or q == "aug" then
      fail("dark", q .. " triad on degree " .. tostring(S.chord_degree) .. " at bar " .. bar)
    end
    if q == "min" and not warm(S.chord_voicing) then
      fail("cold minor", string.format("%s chord %s in voicing %s at bar %d",
        S.chord_borrowed and "borrowed" or "minor", tostring(S.chord_label), tostring(S.chord_voicing), bar))
    end
    local notes = table.concat(S.chord, " ")
    -- every pitch class from the mode; b3 / b6 only for the borrowed iv
    -- (and while a morph is still leaving it)
    local root = S.root_pc or 0
    local md = T.MODES[S.mode or 1]
    local allowed = {}
    for _, st in ipairs(md.steps) do allowed[(root + st) % 12] = true end
    if S.chord_borrowed or S.chord_borrow_tail then
      allowed[(root + 3) % 12], allowed[(root + 8) % 12] = true, true
    end
    for pc in pairs(pcs) do
      if not allowed[pc] then
        fail("mode", string.format("pc %d outside %s on %d in {%s} at bar %d", pc, md.name, root, notes, bar))
      end
      if pcs[(pc + 6) % 12] then
        fail("tritone", string.format("tritone in {%s} (%s %s) at bar %d", notes, tostring(S.chord_label), md.name, bar))
      end
    end
    if S.chord_root_pc and pcs[(root + S.chord_root_pc + 1) % 12] then
      fail("b9", string.format("b9 over the root of %s in {%s} (%s) at bar %d", tostring(S.chord_label), notes, md.name, bar))
    end
    -- the sounding pedal: no semitone against the chord, in the bass or
    -- within the octave above it
    if pedal and now < pedal.till then
      for _, c in ipairs(S.chord) do
        local d = c - pedal.midi
        if d == 1 or d == -1 or d == 6 or d == 11 then
          fail("pedal", string.format("pedal %d against chord note %d in {%s} at bar %d", pedal.midi, c, notes, bar))
        end
      end
    end
  end

  -- nature: a passing moment never overlaps a swell
  if S.moment_active and S.nature_state and S.nature_state ~= "idle" then
    fail("moment+swell", "moment active during a " .. S.nature_state .. " swell at bar " .. bar)
  end

end

function R.on_bar(S, t)
  cur = S
  if t then now = math.max(now, t) end
  R.stats.bars = R.stats.bars + 1
  local bar = S.track_bar

  R.check_live(S)

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
    -- a phasing cycle is an odd number of beats; a bar-fitting one (meters
    -- off 4/4) whole bars, still whole beats
    if m.cycle % 2 ~= 0 then
      fail("cycle", "motif " .. i .. " cycle of " .. m.cycle .. " eighths is not whole beats")
    elseif not m.fit and m.cycle % 4 ~= 2 then
      fail("cycle", "motif " .. i .. " cycle of " .. m.cycle .. " eighths is not an odd number of beats")
    end
    if m.cycle < 14 then fail("short cycle", "motif " .. i .. " cycle of " .. m.cycle .. " eighths is under 7 beats") end
    if m.cycle > 30 then fail("long cycle", "motif " .. i .. " cycle of " .. m.cycle .. " eighths is over 15 beats") end
  end
end

function R.report()
  return #fails == 0, fails
end

return R
