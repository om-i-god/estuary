local T = include("lib/theory")
local M = include("lib/motifs")

local function sounding(e) return e.tone ~= nil or e.pass ~= nil end

local function check_shape(m, ctx)
  local n, rests, total, ones = 0, 0, 0, 0
  local last_s
  for i, e in ipairs(m.events) do
    assert(e.dur >= 1, ctx .. " dur<1")
    total = total + e.dur
    if sounding(e) then n = n + 1; last_s = i else rests = rests + 1 end
    if sounding(e) and e.dur == 1 then ones = ones + 1 end
  end
  assert(n >= 3 and n <= 7, ctx .. " sounding " .. n)
  assert(rests >= 1, ctx .. " no rest")
  assert(#m.events <= 14, ctx .. " events " .. #m.events)
  assert(total == m.cycle, ctx .. " cycle sum")
  assert(m.cycle % 2 == 0 and (m.cycle // 2) % 2 == 1, ctx .. " cycle " .. m.cycle)
  assert(ones <= 2, ctx .. " pairs")
  -- passing: short, never first or last sounding
  local first_s
  for i, e in ipairs(m.events) do if sounding(e) then first_s = first_s or i end end
  for i, e in ipairs(m.events) do
    if e.pass then
      assert(e.dur <= 2, ctx .. " pass long")
      assert(i ~= first_s and i ~= last_s, ctx .. " pass at edge")
      assert(e.tone == nil, ctx .. " pass+tone")
    end
    if e.tone then assert(e.tone >= 1 and e.tone <= 6, ctx .. " tone range") end
  end
end

local function copy(m)
  local c = {}
  for i, e in ipairs(m.events) do c[i] = {dur = e.dur, tone = e.tone, pass = e.pass} end
  return c
end
local function same(a, b) return a.dur == b.dur and a.tone == b.tone and a.pass == b.pass end

test("motif shape over 1000 seeds", function()
  for seed = 1, 1000 do
    math.randomseed(seed)
    local m = M.new((seed % 4) + 1)
    check_shape(m, "seed " .. seed)
    assert(m.intro == 2 and m.pos == 1 and m.left == 0)
    assert(m.voice >= 1 and m.voice <= 4)
  end
end)

test("motion is mostly stepwise, leaps <= 3, tones within 5 rungs", function()
  local steps, moves = 0, 0
  for seed = 1, 1000 do
    math.randomseed(seed)
    local m = M.new((seed % 4) + 1)
    local prev
    for _, e in ipairs(m.events) do
      if e.tone then
        if prev then
          local d = math.abs(e.tone - prev)
          assert(d <= 3, "leap " .. d)
          moves = moves + 1
          if d == 1 then steps = steps + 1 end
        end
        prev = e.tone
      end
    end
  end
  assert(steps / moves >= 0.7, "stepwise " .. steps / moves)
end)

-- a random bright chord in the pad's register
local function pad_chord(root_pc)
  while true do
    local mode = math.random(#T.MODES)
    local deg = math.random(7)
    local q = T.quality(mode, deg)
    if q == "maj" or q == "min" then
      return T.chord(48 + root_pc, mode, deg, math.random(#T.VOICINGS)), mode
    end
  end
end

-- in pitch, not indices: a cycle sung over one chord spans <= 16 semitones
-- and most moves are a chord tone away (<= 5 semitones)
test("realised motifs are small and singable", function()
  local small, moves, worst = 0, 0, 0
  for seed = 1, 1000 do
    math.randomseed(seed)
    local m = M.new((seed % 4) + 1)
    local root = seed % 12
    for _ = 1, 20 do
      local chord, mode = pad_chord(root)
      m.last_note = nil
      local lo, hi, prev
      for _, e in ipairs(m.events) do
        local midi = M.realize(m, e, chord, mode, root)
        if midi then
          lo, hi = math.min(lo or midi, midi), math.max(hi or midi, midi)
          if prev then
            moves = moves + 1
            if math.abs(midi - prev) <= 5 then small = small + 1 end
            assert(math.abs(midi - prev) <= 12, ("seed %d leap %d -> %d"):format(seed, prev, midi))
          end
          prev = midi
        end
      end
      worst = math.max(worst, hi - lo)
      assert(hi - lo <= 16, ("seed %d span %d chord %s"):format(seed, hi - lo, table.concat(chord, ",")))
    end
  end
  assert(small / moves >= 0.8, "small moves " .. small / moves)
  print(("     small moves %.2f, widest cycle %d semitones"):format(small / moves, worst))
end)

test("mutate is one change and shape survives 50 mutations", function()
  for seed = 1, 1000 do
    math.randomseed(seed)
    local m = M.new((seed % 4) + 1)
    for k = 1, 50 do
      local before = copy(m)
      local kind = M.mutate(m)
      local n = #before
      assert(#m.events == n, "len changed")
      local diff = {}
      for i = 1, n do if not same(before[i], m.events[i]) then diff[#diff + 1] = i end end
      if kind == "rotate" then
        for i = 1, n do assert(same(m.events[i], before[(i % n) + 1]), "not a rotation") end
      elseif kind == "swap" then
        assert(#diff == 1, "swap diffs " .. #diff)
        local a, b = before[diff[1]], m.events[diff[1]]
        assert(a.tone and b.tone and math.abs(a.tone - b.tone) == 1 and a.dur == b.dur)
      elseif kind == "rest" then
        assert(#diff == 1, "rest diffs " .. #diff)
        local a, b = before[diff[1]], m.events[diff[1]]
        assert(not sounding(a) and not sounding(b) and a.dur ~= b.dur)
      elseif kind == nil then
        assert(#diff == 0, "nil mutation changed " .. #diff)
      else
        error("kind " .. tostring(kind))
      end
      check_shape(m, "seed " .. seed .. " mut " .. k)
    end
  end
end)

local function rand_chord(root_pc)
  while true do
    local mode = math.random(#T.MODES)
    local deg = math.random(7)
    local q = T.quality(mode, deg)
    if q == "maj" or q == "min" then
      return T.chord(60 + root_pc, mode, deg, math.random(#T.VOICINGS)), mode
    end
  end
end

local function walk(m, chord, mode, root, fn)
  m.last_note = nil
  local last_s
  for i, e in ipairs(m.events) do if sounding(e) then last_s = i end end
  for i, e in ipairs(m.events) do
    if sounding(e) then
      local midi = M.realize(m, e, chord, mode, root)
      assert(midi >= 55 and midi <= 91, "range " .. midi)
      fn(e, midi, i == last_s)
    else
      assert(M.realize(m, e, chord, mode, root) == nil)
    end
  end
end

test("avoid notes only on short non-final passing events", function()
  for seed = 1, 200 do
    math.randomseed(seed)
    local m = M.new((seed % 4) + 1)
    local root = seed % 12
    for _ = 1, 50 do
      local chord, mode = rand_chord(root)
      local cpcs = {}
      for _, n in ipairs(chord) do cpcs[n % 12] = true end
      walk(m, chord, mode, root, function(e, midi, is_last)
        local pc = midi % 12
        if not cpcs[pc] and cpcs[(pc - 1) % 12] then
          assert(e.pass and e.dur <= 2 and not is_last, "avoid note on seed " .. seed)
        end
      end)
    end
  end
end)

test("pentatonic modes keep to melody (+ passing only on pass events)", function()
  for seed = 1, 300 do
    math.randomseed(seed)
    local m = M.new((seed % 4) + 1)
    local root = seed % 12
    for mode = 4, 5 do
      for _ = 1, 30 do
        local chord
        repeat
          local deg, v = math.random(7), math.random(#T.VOICINGS)
          local q = T.quality(mode, deg)
          if q == "maj" or q == "min" then chord = T.chord(60 + root, mode, deg, v) end
        until chord
        walk(m, chord, mode, root, function(e, midi)
          local rel = (midi - root) % 12
          local melody = rel == 0 or rel == 2 or rel == 4 or rel == 7 or rel == 9
          if mode == 4 then assert(melody, "mode4 rel " .. rel)
          elseif not melody then
            assert((rel == 5 or rel == 11) and e.pass, "mode5 rel " .. rel)
          end
        end)
      end
    end
  end
end)

test("step fires each event on its onset, once per 8th", function()
  math.randomseed(7)
  local m = M.new(1)
  local count, seen = 0, 0
  for _ = 1, m.cycle * 3 do
    local ev = M.step(m)
    if ev then seen = seen + 1 end
  end
  assert(seen == #m.events * 3, "seen " .. seen)
end)

test("toggle keeps the shape rules and the cycle; refuses what would break them", function()
  math.randomseed(11)
  local took, refused = 0, 0
  for trial = 1, 200 do
    local m = M.new(trial % 4 + 1)
    local cycle = m.cycle
    for _ = 1, 40 do
      local i = math.random(1, #m.events)
      if M.toggle(m, i) then took = took + 1 else refused = refused + 1 end
      check_shape(m, "toggle")
      assert(m.cycle == cycle, "cycle moved")
      for _, e in ipairs(m.events) do
        if e.dur > 4 then assert(not sounding(e) or e.dur <= 8, "long note") end
      end
    end
  end
  assert(took > 0 and refused > 0, "took " .. took .. " refused " .. refused)
  -- exactly 3 notes: a sounding step can't go
  local m = {events = {{dur = 2, tone = 1}, {dur = 2, tone = 2}, {dur = 2, tone = 3}, {dur = 2}, {dur = 6}}, cycle = 14}
  assert(not M.toggle(m, 1) and m.events[1].tone == 1)
  assert(M.toggle(m, 4) and m.events[4].tone == 3 and not m.events[4].pass)
  assert(not M.toggle(m, 5) and not m.events[5].tone, "last rest must stay")
end)

-- index distance between consecutive tones, the loop's seam included
local function cyclic_leap(m)
  local first, prev, mx = nil, nil, 0
  for _, e in ipairs(m.events) do
    if e.tone then
      if prev then mx = math.max(mx, math.abs(e.tone - prev)) end
      first = first or e.tone; prev = e.tone
    end
  end
  return math.max(mx, math.abs(first - prev))
end

test("200 mutations keep the seam small and the cycle >= 7 beats", function()
  for seed = 1, 1000 do
    math.randomseed(seed)
    local m = M.new((seed % 4) + 1)
    assert(cyclic_leap(m) <= 3, "new motif seam " .. cyclic_leap(m))
    for k = 1, 200 do
      M.mutate(m)
      assert(cyclic_leap(m) <= 3, ("seed %d mut %d seam leap %d"):format(seed, k, cyclic_leap(m)))
      assert(m.cycle >= 14, ("seed %d mut %d cycle %d"):format(seed, k, m.cycle))
    end
  end
end)

test("a swap still works after a rotate", function()
  local swaps = 0
  for seed = 1, 300 do
    math.randomseed(seed)
    local m = M.new((seed % 4) + 1)
    -- rotate by hand until the old seam sits inside the list
    local n = #m.events
    local r = {}
    for i = 1, n do r[i] = m.events[(i % n) + 1] end
    m.events = r
    local tries = 0
    repeat
      tries = tries + 1
      local kind = M.mutate(m)
      if kind == "swap" then swaps = swaps + 1 end
    until kind == "swap" or tries > 20
  end
  assert(swaps >= 280, "swaps after rotate " .. swaps)
end)

test("a held tone never sits a semitone right over a pad note", function()
  local moved = 0
  for seed = 1, 1000 do
    math.randomseed(seed)
    local m = M.new((seed % 4) + 1)
    local root = seed % 12
    for _ = 1, 20 do
      local chord, mode = pad_chord(root)
      m.last_note = nil
      for _, e in ipairs(m.events) do
        local midi = M.realize(m, e, chord, mode, root)
        if midi and e.dur > 2 then
          for _, c in ipairs(chord) do
            assert(c ~= midi - 1, ("seed %d: %d held over %d in {%s}"):format(seed, midi, c, table.concat(chord, ",")))
          end
        end
      end
    end
  end
end)
