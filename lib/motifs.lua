-- estuary / motifs
-- short odd-cycle phrases with rests; one-change mutation; chord-relative notes.
-- ancestor: gradient's lib/gen.lua lanes.

local T = include("lib/theory")

local M = {}

local DURS     = {2, 2, 2, 3, 4, 4, 6, 8}
local CYCLES   = {14, 18, 22, 26, 30}          -- eighths = 2 x odd beats
local MAX_EVTS = 14                            -- grid shows one event per column
local OCT_BASE = {0, 12, 0, 12}
local LO, HI   = 55, 91
local MAX_SPAN = 4                             -- tone indices: 5 rungs = one octave

local function pick(t) return t[math.random(#t)] end
local function sounding(e) return e.tone ~= nil or e.pass ~= nil end

-- first/last sounding indices of an event list
local function edges(ev)
  local f, l
  for i, e in ipairs(ev) do
    if sounding(e) then f = f or i; l = i end
  end
  return f, l
end

-- lowest and highest tone index
local function tone_range(ev)
  local lo, hi
  for _, e in ipairs(ev) do
    if e.tone then lo = math.min(lo or e.tone, e.tone); hi = math.max(hi or e.tone, e.tone) end
  end
  return lo or 1, hi or 1
end

-- passing events: never first/last sounding, always short, no tone
local function passes_ok(ev)
  local f, l = edges(ev)
  for i, e in ipairs(ev) do
    if e.pass and (i == f or i == l or e.dur > 2) then return false end
  end
  return true
end

local function gen_events()
  for _ = 1, 200 do
    local n = math.random(3, 7)
    local durs = {}
    local pair = math.random() < 0.3
    local pair_at = pair and math.random(1, n - 1) or nil
    local i = 1
    while i <= n do
      if pair_at == i then
        durs[#durs + 1] = 1; durs[#durs + 1] = 1; i = i + 2
      else
        durs[#durs + 1] = pick(DURS); i = i + 1
      end
    end
    while #durs > 7 do table.remove(durs) end
    local sum = 0
    for _, d in ipairs(durs) do sum = sum + d end
    local mid = math.random() < 0.5 and pick({2, 2, 3, 4}) or 0   -- optional inner rest
    local ok = {}
    for _, c in ipairs(CYCLES) do if c >= sum + mid + 2 then ok[#ok + 1] = c end end
    if #durs >= 3 and #ok > 0 then
      -- bias toward the shorter fits
      local cycle = ok[math.min(#ok, math.random(#ok) + (math.random() < 0.5 and 0 or 1))]
      local idx, leaps_left = math.random(2, 4), 0
      local moves = #durs - 1
      leaps_left = math.floor(0.3 * moves)
      local evs, rest_flags = {}, {}
      local rest_at = mid > 0 and math.random(2, #durs) or nil   -- before sounding #rest_at
      for k, d in ipairs(durs) do
        if rest_at == k then evs[#evs + 1] = {dur = mid}; rest_flags[#evs] = true end
        evs[#evs + 1] = {dur = d}
      end
      evs[#evs + 1] = {dur = cycle - sum - mid}                  -- trailing pad rest
      rest_flags[#evs] = true
      -- notes: mostly +-1, a few leaps <= 3; clamp 1..6
      local first = true
      local prev_pass = false
      local first_s, last_s
      for j in ipairs(evs) do
        if not rest_flags[j] then first_s = first_s or j; last_s = j end
      end
      for j, e in ipairs(evs) do
        if not rest_flags[j] then
          if j > first_s and j < last_s and e.dur <= 2 and not prev_pass
             and math.random() < 0.3 then
            e.pass = math.random() < 0.5 and 1 or -1
            prev_pass = true
          else
            prev_pass = false
            if first then
              first = false
            else
              local d = math.random() < 0.5 and 1 or -1
              local leap = leaps_left > 0 and math.random() < 0.4
              if leap then leaps_left = leaps_left - 1; d = d * math.random(2, 3) end
              if idx + d < 1 or idx + d > 6 then d = -d end
              if idx + d < 1 or idx + d > 6 then d = d > 0 and 1 or -1 end
              if idx + d < 1 or idx + d > 6 then d = -d end
              idx = idx + d
            end
            e.tone = idx
          end
        end
      end
      local lo, hi = tone_range(evs)
      if #evs <= MAX_EVTS and passes_ok(evs) and hi - lo <= MAX_SPAN then return evs, cycle end
    end
  end
  error("motif generation failed")
end

function M.new(slot)
  slot = slot or 1
  local evs, cycle = gen_events()
  local base = OCT_BASE[((slot - 1) % 4) + 1]
  local shift = math.random() < 0.25 and (base == 0 and 12 or -12) or 0
  local side = (slot % 2 == 0) and 1 or -1
  return {
    events = evs, cycle = cycle,
    oct   = base + shift,
    pan   = side * (0.2 + math.random() * 0.4),
    voice = ((slot - 1) % 4) + 1,
    bright = 0.3 + math.random() * 0.6,
    send   = 0.2 + math.random() * 0.6,
    pos = 1, left = 0, intro = 2,
  }
end

-- largest tone move in an event list
local function max_move(ev)
  local prev, mx = nil, 0
  for _, e in ipairs(ev) do
    if e.tone then
      if prev then mx = math.max(mx, math.abs(e.tone - prev)) end
      prev = e.tone
    end
  end
  return mx
end

local function steps_count(ev)
  local prev, n = nil, 0
  for _, e in ipairs(ev) do
    if e.tone then
      if prev and math.abs(e.tone - prev) == 1 then n = n + 1 end
      prev = e.tone
    end
  end
  return n
end

local function mut_swap(m)
  local ev, best, bs = m.events, {}, -1
  for i, e in ipairs(ev) do
    if e.tone then
      for _, d in ipairs({-1, 1}) do
        local t = e.tone + d
        if t >= 1 and t <= 6 then
          local old = e.tone
          e.tone = t
          local lo, hi = tone_range(ev)
          local s = (max_move(ev) <= 3 and hi - lo <= MAX_SPAN) and steps_count(ev) or -1
          e.tone = old
          if s >= 0 then
            if s > bs then best, bs = {}, s end
            if s == bs then best[#best + 1] = {i, t} end
          end
        end
      end
    end
  end
  if #best == 0 then return false end
  local c = pick(best)
  ev[c[1]].tone = c[2]
  return true
end

-- a rest grows/shrinks by 4 eighths (2 beats): the only step that keeps the
-- cycle an odd number of beats
local function mut_rest(m)
  local opts = {}
  for i, e in ipairs(m.events) do
    if not sounding(e) then
      if e.dur - 4 >= 2 then opts[#opts + 1] = {i, -4} end
      if m.cycle + 4 <= CYCLES[#CYCLES] then opts[#opts + 1] = {i, 4} end
    end
  end
  if #opts == 0 then return false end
  local c = pick(opts)
  m.events[c[1]].dur = m.events[c[1]].dur + c[2]
  m.cycle = m.cycle + c[2]
  return true
end

local function mut_rotate(m)
  local ev, n = m.events, #m.events
  local r = {}
  for i = 1, n do r[i] = ev[(i % n) + 1] end
  if not passes_ok(r) then return false end
  m.events = r
  return true
end

function M.mutate(m)
  local order = {"swap", "rest", "rotate"}
  for i = #order, 2, -1 do
    local j = math.random(i); order[i], order[j] = order[j], order[i]
  end
  local fns = {swap = mut_swap, rest = mut_rest, rotate = mut_rotate}
  for _, k in ipairs(order) do
    if fns[k](m) then return k end
  end
  return "swap"
end

-- flip event i between a note and a rest (the grid). refused (false) unless
-- the motif keeps 3-7 notes, at least one rest and the pass rules, and a new
-- note stays <= 4 beats. cycle length never changes (dur is untouched). a new
-- note takes the nearest earlier note's tone (else the next one's) and is
-- never a pass; a pass flipped to a rest just goes quiet.
function M.toggle(m, i)
  local ev = m.events
  local e = ev[i]
  if not e then return false end
  local was = {tone = e.tone, pass = e.pass}
  if sounding(e) then
    e.tone, e.pass = nil, nil
  else
    if e.dur > 8 then return false end
    local t
    for j = i - 1, 1, -1 do if ev[j].tone then t = ev[j].tone; break end end
    if not t then
      for j = i + 1, #ev do if ev[j].tone then t = ev[j].tone; break end end
    end
    if not t then return false end
    e.tone = t
  end
  local notes, rests = 0, 0
  for _, x in ipairs(ev) do
    if sounding(x) then notes = notes + 1 else rests = rests + 1 end
  end
  if notes >= 3 and notes <= 7 and rests >= 1 and passes_ok(ev) then return true end
  e.tone, e.pass = was.tone, was.pass
  return false
end

-- advance one 8th; returns the event (rest or note) that starts on it, else nil
function M.step(m)
  if m.left > 0 then m.left = m.left - 1; return nil end
  local ev = m.events[m.pos]
  m.left = ev.dur - 1
  m.pos = m.pos + 1
  if m.pos > #m.events then
    m.pos = 1
    m.last_note = nil
    if m.intro > 0 then m.intro = m.intro - 1 end
  end
  return ev
end

local function fold(n)
  while n < LO do n = n + 12 end
  while n > HI do n = n - 12 end
  return n
end

local function in_set(set, pc)
  for _, p in ipairs(set) do if p == pc then return true end end
  return false
end

-- nearest midi to `target` whose pc relative to root is in `set`, skipping
-- `skip`; ties go down
local function snap(target, set, root_pc, skip)
  for d = 0, 12 do
    for _, c in ipairs({target - d, target + d}) do
      if c ~= skip and in_set(set, (c - root_pc) % 12) then return c end
    end
  end
  return target
end

-- the pitch classes a motif sings over this chord: the chord's own pcs the
-- mode's melody allows, topped up to four from the mode (never a pc a
-- semitone over a chord pc), each filler set in the widest gap. ascending.
local function ladder_pcs(chord, md, root_pc)
  local allowed = md.melody or md.steps
  local cpc, pcs, have = {}, {}, {}
  for _, n in ipairs(chord) do cpc[n % 12] = true end
  for pc in pairs(cpc) do
    if in_set(allowed, (pc - root_pc) % 12) then pcs[#pcs + 1] = pc; have[pc] = true end
  end
  if #pcs == 0 then pcs[1] = root_pc % 12; have[root_pc % 12] = true end
  while #pcs < 4 do
    table.sort(pcs)
    local gaps = {}
    for i, a in ipairs(pcs) do
      local b = pcs[(i % #pcs) + 1]
      gaps[#gaps + 1] = {a, (b - a - 1) % 12 + 1}
    end
    table.sort(gaps, function(x, y) return x[2] > y[2] or (x[2] == y[2] and x[1] < y[1]) end)
    local add
    for _, g in ipairs(gaps) do
      local best, bd
      for k = 1, g[2] - 1 do
        local pc = (g[1] + k) % 12
        if in_set(allowed, (pc - root_pc) % 12) and not cpc[(pc - 1) % 12] and not have[pc] then
          local d = math.abs(k - g[2] / 2)
          if not bd or d < bd then best, bd = pc, d end
        end
      end
      if best then add = best; break end
    end
    if not add then break end
    pcs[#pcs + 1] = add; have[add] = true
  end
  table.sort(pcs)
  return pcs
end

-- ladder position i (1 = the first ladder note at or above `anchor`; may
-- run below 1 or past the top)
local function rung(pcs, anchor, i)
  local n = #pcs
  local base = anchor - (anchor % 12)
  local first = 1                           -- index of the first pc >= anchor's pc
  while first <= n and pcs[first] < anchor % 12 do first = first + 1 end
  local j = (first - 1) + (i - 1)
  return base + pcs[(j % n) + 1] + 12 * (j // n)
end


-- the next tone after event `ev` (cyclic), for a passing note's direction
local function next_tone(m, ev)
  local n, at = #m.events, nil
  for i, e in ipairs(m.events) do if e == ev then at = i end end
  if not at then return nil end
  for k = 1, n - 1 do
    local e = m.events[((at - 1 + k) % n) + 1]
    if e.tone then return e.tone end
  end
end

-- tone i is the i-th note of the chord's close-position ladder, laid out
-- from the motif's anchor (55 + its octave), so a step is the next chord
-- tone (2-5 semitones) and tones 1-6 sit inside about an octave and a half.
-- a passing note is one scale step from the
-- last note, toward the next tone.
function M.realize(m, ev, chord, mode, root_pc)
  if not sounding(ev) then return nil end
  local md = T.MODES[mode]
  local pcs = ladder_pcs(chord, md, root_pc)
  local anchor = LO + m.oct
  local midi
  if ev.tone then
    local i = ev.tone
    midi = rung(pcs, anchor, i)
  else
    local prev = m.last_note or rung(pcs, anchor, 1)
    local dir = ev.pass
    local nt = next_tone(m, ev)
    if nt then
      local target = rung(pcs, anchor, nt)
      if target > prev then dir = 1 elseif target < prev then dir = -1 end
    end
    if prev + dir < LO or prev + dir > HI then dir = -dir end
    local cand = prev + dir
    while not in_set(md.steps, (cand - root_pc) % 12) do cand = cand + dir end
    if md.melody then
      local allowed = {}
      for _, p in ipairs(md.melody) do allowed[#allowed + 1] = p end
      for _, p in ipairs(md.passing or {}) do allowed[#allowed + 1] = p end
      if not in_set(allowed, (cand - root_pc) % 12) then
        cand = snap(cand, allowed, root_pc, prev)
      end
    end
    midi = cand
  end
  midi = fold(midi)
  m.last_note = midi
  return midi
end

return M
