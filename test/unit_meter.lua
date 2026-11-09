-- meter: bar lengths, the lean, motif cycles that fit the bar, bars per
-- track against minutes, a change landing on the barline, and 4/4 exactly
-- as it was
local MT = include("lib/meter")
local M = include("lib/motifs")

local function eq(a, b, what)
  assert(a == b, (what or "") .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end

local function idx(name)
  for i, n in ipairs(MT.NAMES) do if n == name then return i end end
  error("no meter " .. name)
end

local function sounding(e) return e.tone ~= nil or e.pass ~= nil end

test("meter: options in order, 4/4 the default (option list only grows)", function()
  local want = {"3/4", "4/4", "5/4", "6/8", "7/8"}
  for i, n in ipairs(want) do eq(MT.NAMES[i], n, "option " .. i) end
  eq(MT.DEFAULT, 2, "default")
  eq(MT.NAMES[MT.DEFAULT], "4/4", "default name")
  local f = assert(io.open("estuary.lua")); local src = f:read("a"); f:close()
  assert(src:find('params:add_option%("meter", "meter", MT.NAMES, MT.DEFAULT%)'), "meter param not built from MT.NAMES")
end)

test("meter: 8ths and beats per bar", function()
  local want = {["3/4"] = 6, ["4/4"] = 8, ["5/4"] = 10, ["6/8"] = 6, ["7/8"] = 7}
  for n, b in pairs(want) do
    eq(MT.bar8(idx(n)), b, n .. " 8ths")
    eq(MT.beats(idx(n)), b / 2, n .. " beats")
  end
  eq(MT.bar8(nil), 8, "no meter is 4/4")
end)

test("meter: the downbeat and group-start lean", function()
  local want = {
    ["3/4"] = {[0] = 1.08},
    ["4/4"] = {},
    ["5/4"] = {[0] = 1.08, [6] = 1.04},
    ["6/8"] = {[0] = 1.08, [3] = 1.04},
    ["7/8"] = {[0] = 1.08, [2] = 1.04, [4] = 1.04},
  }
  for n, w in pairs(want) do
    local i = idx(n)
    for pos = 0, MT.bar8(i) - 1 do
      eq(MT.lean(i, pos), w[pos], n .. " pos " .. pos)
      local l = MT.lean(i, pos)
      if l then assert(l > 1 and l <= 1.08 + 1e-9, n .. " lean " .. l) end
    end
  end
end)

test("meter: bar-fitting cycle sets (whole beats, 7-15 beats, whole bars)", function()
  assert(M.fit_cycles(8) == nil and M.fit_cycles(nil) == nil, "4/4 has no bar-fitting cycles")
  local want = {["3/4"] = {18, 24, 30}, ["5/4"] = {20, 30}, ["6/8"] = {18, 24, 30}, ["7/8"] = {14, 28}}
  for n, w in pairs(want) do
    local bar = MT.bar8(idx(n))
    local set, st = M.fit_cycles(bar)
    eq(table.concat(set, ","), table.concat(w, ","), n .. " set")
    for _, c in ipairs(set) do
      assert(c % 2 == 0 and c >= 14 and c <= 30, n .. " cycle " .. c)
      eq(c % bar, 0, n .. " whole bars " .. c)
      eq(c % st, 0, n .. " step " .. c)
    end
  end
end)

-- a motif's shape, any meter: 3-7 notes, a rest, sums to its cycle, and a
-- cycle of its class
local function check(m, bar8, ctx)
  local n, rests, total = 0, 0, 0
  for _, e in ipairs(m.events) do
    total = total + e.dur
    if sounding(e) then n = n + 1 else rests = rests + 1 end
  end
  assert(n >= 3 and n <= 7 and rests >= 1, ctx .. " shape")
  eq(total, m.cycle, ctx .. " cycle sum")
  assert(m.cycle % 2 == 0 and m.cycle >= 14 and m.cycle <= 30, ctx .. " cycle " .. m.cycle)
  if m.fit then
    local set = M.fit_cycles(bar8)
    local inset = false
    for _, c in ipairs(set) do if c == m.cycle then inset = true end end
    assert(inset, ctx .. " fit cycle " .. m.cycle .. " not whole bars")
  else
    eq(m.cycle % 4, 2, ctx .. " phasing cycle odd beats " .. m.cycle)
  end
end

test("meter: about half the new motifs fit the bar off 4/4; none at 4/4", function()
  for _, n in ipairs({"3/4", "4/4", "5/4", "6/8", "7/8"}) do
    local bar = MT.bar8(idx(n))
    local fit = 0
    for seed = 1, 600 do
      math.randomseed(seed)
      local m = M.new((seed % 4) + 1, bar)
      check(m, bar, n .. " seed " .. seed)
      if m.fit then fit = fit + 1 end
    end
    if bar == 8 then
      eq(fit, 0, "4/4 fits")
    else
      assert(fit >= 0.35 * 600 and fit <= 0.6 * 600, n .. ": " .. fit .. " of 600 fit the bar")
    end
    print(("     %s: %d of 600 new motifs fit the bar"):format(n, fit))
  end
end)

test("meter: at 4/4 a new motif draws exactly what it always did", function()
  for seed = 1, 300 do
    math.randomseed(seed)
    local a = M.new((seed % 4) + 1)
    local ra = math.random(1 << 30)
    math.randomseed(seed)
    local b = M.new((seed % 4) + 1, 8)
    local rb = math.random(1 << 30)
    eq(ra, rb, "random stream after seed " .. seed)
    eq(a.cycle, b.cycle, "cycle")
    eq(#a.events, #b.events, "events")
    assert(not b.fit and b.cstep == 4, "4/4 motif is phasing")
  end
end)

test("meter: 200 mutations keep the cycle's class and its range", function()
  for _, n in ipairs({"3/4", "4/4", "5/4", "6/8", "7/8"}) do
    local bar = MT.bar8(idx(n))
    local grew = 0
    for seed = 1, 300 do
      math.randomseed(seed)
      local m = M.new((seed % 4) + 1, bar)
      local fit, c0 = m.fit, m.cycle
      for k = 1, 200 do
        M.mutate(m)
        eq(m.fit, fit, n .. " class")
        check(m, bar, ("%s seed %d mut %d"):format(n, seed, k))
      end
      if m.cycle ~= c0 then grew = grew + 1 end
    end
    assert(grew > 30, n .. ": cycles never move under mutation (" .. grew .. ")")
  end
end)

test("meter: bars per track follow the bar's real duration", function()
  _path = {audio = "/audio/"}
  util = {scandir = function() return {} end}
  engine = setmetatable({}, {__index = function() return function() end end})
  local C = include("lib/conductor")
  for _, n in ipairs({"3/4", "4/4", "5/4", "6/8", "7/8"}) do
    for _, tempo in ipairs({60, 72, 96, 120}) do
      for _, mins in ipairs({6, 12, 30}) do
        local i = idx(n)
        local S = {tempo = tempo, track_minutes = mins, bar8 = MT.bar8(i)}
        local total = C.track_total(S)
        local sec = total * MT.beats(i) * 60 / tempo
        -- within one bar of the minutes asked (48 bars is the floor)
        if total > 48 then
          assert(sec <= mins * 60 + 1e-6 and sec > mins * 60 - MT.beats(i) * 60 / tempo - 1e-6,
            ("%s %d bpm %d min: %d bars = %.1f s"):format(n, tempo, mins, total, sec))
        end
        if n == "4/4" then eq(total, math.max(48, math.floor(mins * tempo / 4)), "4/4 bars") end
      end
    end
  end
end)

-- the sim with the stream tap; returns the stream text and the sim's last lines
local function sim_stream(seed, args, meter)
  local path = os.tmpname()
  local cmd = string.format("STREAM=%s SEED=%d %s lua -e 'dofile(\"test/stream_tap.lua\")' test/sim.lua %s 2>&1",
    path, seed, meter and ("METER=" .. meter) or "", args)
  local p = assert(io.popen(cmd)); local out = p:read("a"); p:close()
  local f = assert(io.open(path)); local s = f:read("a"); f:close()
  os.remove(path)
  return s, out
end

local function fnv(s)
  local h = 2166136261
  for i = 1, #s do h = ((h ~ s:byte(i)) * 16777619) & 0xffffffff end
  return h
end

test("meter: 4/4 replays main's engine stream exactly (several seeds, set and track)", function()
  local fix = dofile("test/fixtures/stream_4_4.lua")
  for _, r in ipairs(fix) do
    for _, meter in ipairs({false, "4/4"}) do
      local s, out = sim_stream(r.seed, r.args, meter or nil)
      assert(out:find("RULES ok"), "sim failed: " .. out:sub(-300))
      local n = select(2, s:gsub("\n", ""))
      local ctx = ("seed %d args %s%s"):format(r.seed, r.args, meter and " METER=4/4" or "")
      eq(n, r.lines, ctx .. " lines")
      eq(fnv(s), r.hash, ctx .. " hash")
    end
  end
end)

test("meter: a change lands on the next barline; every bar lasts its meter", function()
  -- the sim checks each bar's beats against its meter, that a change asked
  -- for mid-bar waits for the barline, and that it never outlives it
  for _, args in ipairs({"300", "300 2 4"}) do
    local p = assert(io.popen("METER=walk SEED=11 MIDI=2 lua test/sim.lua " .. args .. " 2>&1"))
    local out = p:read("a"); p:close()
    assert(out:find("RULES ok"), "walk sim failed: " .. out:sub(-400))
    local walked = tonumber(out:match("walked (%d+) times"))
    assert(walked and walked >= 5, "walk changed the meter " .. tostring(walked) .. " times")
  end
end)

test("meter: off 4/4 the stream leans, and stays inside the velocity ceiling", function()
  local s = sim_stream(5, "200", "5/4")
  local n, top = 0, 0
  for vel in s:gmatch("\nnote [%d.]+ %d+ [%d.]+ ([%d.e-]+)") do
    n = n + 1
    top = math.max(top, tonumber(vel))
  end
  assert(n > 50, "5/4 played " .. n .. " notes")
  assert(top <= 0.8 + 1e-9, "a leaned note at velocity " .. top)
  -- and 5/4 is a different piece from 4/4 (same seed)
  local s44 = sim_stream(5, "200", "4/4")
  assert(s ~= s44, "5/4 and 4/4 streams identical")
end)
