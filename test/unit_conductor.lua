local T = include("lib/theory")
local M = include("lib/motifs")

local starts   -- swell starts: {bar=, cycle=}
local S

local function setup(seed, mode_play, extra)
  _path = {audio = "/audio/"}
  local files = {
    ["/audio/estuary/water/"] = {"a.wav"}, ["/audio/estuary/birds/"] = {"b.wav"},
    ["/audio/estuary/wind/"] = {"w.wav"}, ["/audio/estuary/room/"] = {"r.wav"},
  }
  util = {scandir = function(d) return files[d] end}
  starts = {}
  engine = setmetatable({
    nature_load = function(slot) if slot == 2 then starts[#starts + 1] = {bar = S.track_bar, cycle = S.cycle} end end,
  }, {__index = function() return function() end end})
  local C = include("lib/conductor")
  S = {root_pc = seed % 12, mode = 1, harmony = 3, voicing = 7, bloom = 0,
       mode_play = mode_play, phrase_len = 16, tempo = 72, track_minutes = 12,
       moment_freq = 2, end_action = 2, gain = {}, muted = {}, soloed = {}}
  for k, v in pairs(extra or {}) do S[k] = v end
  C.new_track(S, seed, false)
  return C
end

local function nsounding()
  local n = 0
  for i = 1, 4 do if S.sounding[i] then n = n + 1 end end
  return n
end

local function audible()
  local n = 0
  for i = 1, 4 do
    if not S.muted["motif" .. i] and (S.gain["motif" .. i] or 0) > 0.02 then n = n + 1 end
  end
  return n
end

local function step_motifs()
  for i = 1, 4 do
    if S.sounding[i] then for _ = 1, 8 do M.step(S.motifs[i]) end end
  end
end

local function run(C, bars, each)
  for b = 1, bars do
    local r = C.bar(S)
    step_motifs()
    if each then each(b, r) end
    if r == "stop" then return b end
  end
  return bars
end

for _, mp in ipairs({1, 2}) do
  test("cap holds mode " .. mp, function()
    local maxn = 0
    for seed = 1, 20 do
      local C = setup(seed, mp)
      run(C, 3000, function(b)
        local n = nsounding()
        maxn = math.max(maxn, n)
        assert(S.cap >= 1 and S.cap <= 3, "cap " .. tostring(S.cap))
        assert(n <= S.cap, string.format("seed %d bar %d sounding %d cap %d", seed, b, n, S.cap))
        assert(audible() <= 3, string.format("seed %d bar %d audible %d", seed, b, audible()))
        local st = C.N.state
        if st == "rising" or st == "held" or S.track_bar < S.breathe_until then
          assert(n <= 1, string.format("seed %d bar %d busy %d under swell/breathe", seed, b, n))
        end
        for k, g in pairs(S.gain) do assert(g >= 0 and g <= 1, k) end
        if b % 400 == 0 then C.breathe(S) end
      end)
    end
    assert(maxn >= 2, "never reached two motifs: " .. maxn)
  end)

  test("mutes cannot exceed cap mode " .. mp, function()
    local parts = {"motif1", "motif2", "motif3", "motif4", "pad", "pedal"}
    for seed = 1, 20 do
      local C = setup(seed, mp)
      run(C, 3000, function(b)
        assert(nsounding() <= 3 and nsounding() <= S.cap, "seed " .. seed .. " bar " .. b)
        assert(audible() <= 3, string.format("seed %d bar %d audible %d", seed, b, audible()))
        for i = 1, 4 do
          if S.muted["motif" .. i] then assert(not S.sounding[i], "muted sounding") end
        end
        local p = parts[math.random(#parts)]
        local r = math.random()
        if r < 0.3 then S.muted[p] = true elseif r < 0.6 then S.muted[p] = nil
        elseif r < 0.75 then S.soloed[p] = true elseif r < 0.9 then S.soloed[p] = nil
        else S.muted = {}; S.soloed = {} end
      end)
    end
  end)
end

test("track arc", function()
  for seed = 1, 20 do
    local C = setup(seed, 2, {end_action = 1})
    local order, seen = {}, {}
    local n = run(C, 5000, function()
      if not seen[S.section] then seen[S.section] = true; order[#order + 1] = S.section end
    end)
    assert(n == 216, "length " .. n)
    assert(table.concat(order, ",") == "arrival,bloom,tide,return,settling", table.concat(order, ","))
    assert(S.bloom <= 0.05, "end bloom " .. S.bloom)
    assert(#starts == 1, "swells " .. #starts)
  end
end)

test("track tempo scales length", function()
  local C = setup(3, 2, {end_action = 1, tempo = 100, track_minutes = 6})
  assert(run(C, 5000) == 150)
end)

test("set swells per cycle", function()
  for seed = 1, 20 do
    local C = setup(seed, 1)
    local cyc_bars = {}
    run(C, 3000, function() cyc_bars[S.cycle] = S.cycle_bars end)
    local per = {}
    for _, s in ipairs(starts) do per[s.cycle] = (per[s.cycle] or 0) + 1 end
    local done = 0
    for c = 1, S.cycle - 1 do
      done = done + 1
      assert(per[c] == 1 or per[c] == 2, string.format("seed %d cycle %d swells %s", seed, c, tostring(per[c])))
    end
    assert(done >= 1, "no completed cycle")
    -- troughs reach the floor, bloom stays in range
  end
end)

test("set bloom reaches trough and stays in range", function()
  local C = setup(5, 1)
  local lo, hi = 1, 0
  run(C, 3000, function()
    lo = math.min(lo, S.bloom); hi = math.max(hi, S.bloom)
    assert(S.section == "trough" or S.section == "swell", S.section)
  end)
  assert(lo <= 0.1 and lo >= 0.05 - 1e-9, "lo " .. lo)
  assert(hi > 0.8, "hi " .. hi)
end)

test("swell_change moves the music; no key move while following", function()
  local C = setup(2, 1, {listen_follow = true})
  local root = S.root_pc
  for _ = 1, 60 do
    S.swell_change = true
    C.bar(S)
    assert(S.swell_change == false or S.swell_change == nil)
    assert(S.root_pc == root, "key moved while following")
  end
  S.listen_follow = false
  local moved = false
  for _ = 1, 200 do
    S.swell_change = true
    C.bar(S)
    if S.root_pc ~= root then moved = true end
  end
  assert(moved, "never moved key")
end)

test("scheduled swell retries while a moment runs, gives up with no water", function()
  local C = setup(4, 2)
  local calls, n = 0, nil
  local real = C.N.swell
  C.N.swell = function(s) calls = calls + 1; if calls < 3 then return false, "moment running" end return real(s) end
  C.pending_swell(S)
  for _ = 1, 5 do C.bar(S) end
  assert(calls == 3 and #starts == 1, "calls " .. calls .. " starts " .. #starts)
  -- no water
  files = nil
  local C2 = setup(4, 2)
  util.scandir = function() return {} end
  C2.pending_swell(S)
  for _ = 1, 5 do C2.bar(S) end
  assert(#starts == 0)
  local ok, msg = C2.tide(S)
  assert(ok == false and msg == "no water")
end)

test("breathe and nudge", function()
  local C = setup(6, 2)
  C.bar(S)
  C.breathe(S)
  assert(S.breathe_until == S.track_bar + 8)
  local b = S.bloom
  C.nudge(S, 0.2)
  C.bar(S)
  assert(S.bloom > b - 0.05)
end)

test("solo of a fourth slot while three sound keeps <= 3 audible", function()
  local C = setup(9, 1)
  S.bloom = 0.9
  for i = 1, 3 do S.sounding[i] = true; S.gain["motif" .. i] = 1 end
  S.soloed.motif4 = true
  for _ = 1, 20 do
    C.bar(S)
    assert(audible() <= 3, "audible " .. audible())
  end
  assert((S.gain.motif4 or 0) >= 0 )
end)
