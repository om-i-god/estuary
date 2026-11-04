-- visuals: every theme x {silence, mid, peak, swell} drawn headless into the
-- raster stand-in (test/raster.lua), 20 fps of virtual time. each run checks
-- the lit-pixel ratio, that silence is never blank, the frame-to-frame
-- change, NaN / inf reaching the screen, level-15 area and the draw-call
-- budget. then: ramping out_hi / out_lo changes every theme, a theme switch
-- eases, and bad input (nil / NaN / out-of-range audio, short chords, no
-- motifs, a tempo change mid-frame) draws cleanly.
-- VISREPORT=1 prints the numbers per theme x scenario.
local RAST = dofile("test/raster.lua")
local REPORT = os.getenv("VISREPORT")
local FPS = 20
local PV = {}

local function env()
  screen = RAST.screen
  PV = {vis_brightness = 10, vis_speed = 3, echo_fb = 0.45, echo_div = 3}
  params = {get = function(_, id) return PV[id] end}
end

local function mkS()
  return {
    playing = true, step = 0, tempo = 72, bloom = 0, section = "rest",
    chord = {48, 55, 62, 64}, chord_label = "I",
    gain = {motif1 = 0, motif2 = 0, motif3 = 0, motif4 = 0, pad = 0.5, pedal = 0.5},
    muted = {}, sounding = {false, false, false, false},
    motifs = {{cycle = 7}, {cycle = 9}, {cycle = 11}, {cycle = 13}},
  }
end

local CHORDS = {{48, 55, 62, 64}, {45, 52, 60, 64}, {41, 48, 57, 64}, {43, 50, 59, 62}}

-- what each scenario does: setup(S), on_step(S, VIS, step), audio(t) -> table
local SCEN = {}
SCEN.silence = {
  setup = function(S) S.playing = false; S.gain.pad = 0; S.gain.pedal = 0 end,
  on_step = function() end,
  audio = nil,                                  -- no poll ever arrives
}
SCEN.mid = {
  setup = function(S)
    S.bloom = 0.5; S.section = "flow"
    S.sounding = {true, false, true, false}
    S.gain.motif1, S.gain.motif3 = 0.7, 0.6
  end,
  on_step = function(S, VIS, k)
    for i = 1, 4 do
      if S.sounding[i] and math.random() < 0.45 then
        VIS.event("note", i, 55 + math.random(0, 30), 0.4 + math.random() * 1.2)
      end
    end
    if k % 64 == 0 then S.chord = CHORDS[(k // 64) % 4 + 1]; VIS.event("chord", S) end
  end,
  audio = function(t)
    local w = 0.5 + 0.5 * math.sin(t * 0.7)
    return {out_amp = 0.35 + 0.1 * w, out_lo = 0.4, out_mid = 0.3 + 0.1 * w, out_hi = 0.25, nat_amp = 0.15}
  end,
}
SCEN.peak = {
  setup = function(S, VIS)
    S.bloom = 1; S.section = "bloom"
    S.sounding = {true, true, true, false}
    S.gain.motif1, S.gain.motif2, S.gain.motif3, S.gain.pad = 1, 1, 1, 1
    VIS.event("swell", "held", 1)
    VIS.event("moment", "passing")
  end,
  on_step = function(S, VIS, k)
    for i = 1, 4 do
      if S.sounding[i] then VIS.event("note", i, 55 + math.random(0, 36), 0.3 + math.random() * 2) end
    end
    if k % 8 == 0 then VIS.event("swell", "held", 1) end
    if k % 96 == 0 then VIS.event("moment", "passing") end
    if k % 32 == 0 then S.chord = CHORDS[(k // 32) % 4 + 1]; VIS.event("chord", S) end
  end,
  audio = function() return {out_amp = 1, out_lo = 1, out_mid = 1, out_hi = 1, nat_amp = 1} end,
}
-- a swell rises over ~6 s, holds ~6 s, falls ~6 s, over a light texture
SCEN.swell = {
  setup = function(S)
    S.bloom = 0.6; S.section = "flow"
    S.sounding = {false, true, false, true}
    S.gain.motif2, S.gain.motif4 = 0.6, 0.6
  end,
  on_step = function(S, VIS, k)
    local t = k * 60 / S.tempo / 2
    local st, lv = "idle", 0
    if t > 2 and t <= 8 then st, lv = "rising", (t - 2) / 6
    elseif t > 8 and t <= 14 then st, lv = "held", 1
    elseif t > 14 and t <= 20 then st, lv = "falling", 1 - (t - 14) / 6 end
    if k % 8 == 0 and (st ~= "idle" or t <= 21) then VIS.event("swell", st, lv) end
    for i = 1, 4 do
      if S.sounding[i] and math.random() < 0.3 then VIS.event("note", i, 60 + math.random(0, 24), 1) end
    end
  end,
  audio = function(t)
    local s = 0
    if t > 2 and t <= 8 then s = (t - 2) / 6 elseif t > 8 and t <= 14 then s = 1
    elseif t > 14 and t <= 20 then s = 1 - (t - 14) / 6 end
    return {out_amp = 0.3 + 0.4 * s, out_lo = 0.3 + 0.3 * s, out_mid = 0.3, out_hi = 0.2 + 0.5 * s, nat_amp = s}
  end,
}

local function lit_stats()
  local lit, l15, sum = 0, 0, 0
  local buf = RAST.buf
  for i = 0, 128 * 64 - 1 do
    local v = buf[i] or 0
    if v > 0 then lit = lit + 1; sum = sum + v end
    if v >= 15 then l15 = l15 + 1 end
  end
  return lit / 8192, l15, sum
end

local function copybuf()
  local c = {}
  for i = 0, 128 * 64 - 1 do c[i] = RAST.buf[i] or 0 end
  return c
end

local function bufdiff(a, b)
  local d = 0
  for i = 0, 128 * 64 - 1 do d = d + math.abs(a[i] - b[i]) end
  return d / 8192
end

-- run one theme through one scenario; opts: frames, seed, audio override
-- (function t -> table), switch_every (theme switch cadence), tempo_jitter
local function run(theme, scen, opts)
  opts = opts or {}
  env()
  local VIS = include("lib/visuals")
  VIS.init()
  math.randomseed(opts.seed or 11)
  local SC = SCEN[scen]
  local S = mkS()
  SC.setup(S, VIS)
  local audio = opts.audio or SC.audio
  local st = {ops_max = 0, ops_sum = 0, lit_min = 1, lit_max = 0, lit_sum = 0,
    diff_max = 0, diff_sum = 0, l15_max = 0, bad = 0, n = 0, frames = {}}
  local prev
  local next_step, k = 0, 0
  local th = theme
  for f = 1, opts.frames or 400 do
    local t = f / FPS
    while t >= next_step do
      SC.on_step(S, VIS, k)
      if S.playing then
        S.step = S.step + 1
        if S.step % 8 == 0 then VIS.event("bar", S) end
      end
      k = k + 1
      next_step = next_step + 60 / S.tempo / 2
    end
    if opts.tempo_jitter then S.tempo = (f % 2 == 0) and 40 or 200 end
    if audio and VIS.audio then
      for name, v in pairs(audio(t)) do VIS.audio(name, v) end
    end
    if opts.switch_every and f % opts.switch_every == 0 then th = th % 6 + 1 end
    screen.clear()
    RAST.reset_ops()
    VIS.draw(th, S, 1 / FPS)
    local lit, l15, sum = lit_stats()
    local cur = copybuf()
    st.bad = st.bad + RAST.bad
    if f > 20 then                              -- past the first second
      st.ops_max = math.max(st.ops_max, RAST.ops)
      st.ops_sum = st.ops_sum + RAST.ops
      st.lit_min = math.min(st.lit_min, lit)
      st.lit_max = math.max(st.lit_max, lit)
      st.lit_sum = st.lit_sum + lit
      st.l15_max = math.max(st.l15_max, l15)
      st.n = st.n + 1
      if prev then
        local d = bufdiff(prev, cur)
        st.diff_max = math.max(st.diff_max, d)
        st.diff_sum = st.diff_sum + d
      end
    end
    if opts.keep then st.frames[#st.frames + 1] = cur end
    prev = cur
  end
  st.ops_mean = st.ops_sum / st.n
  st.lit_mean = st.lit_sum / st.n
  st.diff_mean = st.diff_sum / math.max(1, st.n - 1)
  return st, VIS
end

local NAMES = {"ripples", "horizon", "postcards", "rain", "tide", "drift"}
local SCENS = {"silence", "mid", "peak", "swell"}

-- bounds (see the visuals v2 report for where they come from)
local OPS_BUDGET = 800        -- draw calls per frame, any theme, any scenario (v1 peaked at 1438)
local LIT_MAX = 0.35          -- never more than ~35% of the screen lit
local LIT_MIN_SILENT = 0.01   -- silence is never blank (~80 pixels)
local DIFF_MAX = 0.5          -- mean |level change| per pixel, frame to frame (v1: 0.31)
local L15_MAX = 8             -- level-15 pixels: a point at most, never an area

if REPORT then
  print(string.format("%-10s %-8s %7s %7s %7s %7s %7s %7s %5s %4s",
    "theme", "scen", "opsMax", "opsMean", "litMin", "litMean", "litMax", "diffMax", "l15", "bad"))
end

for th, name in ipairs(NAMES) do
  for _, sc in ipairs(SCENS) do
    test(string.format("visuals %s %s", name, sc), function()
      local st = run(th, sc)
      if REPORT then
        print(string.format("%-10s %-8s %7d %7.1f %7.3f %7.3f %7.3f %7.3f %5d %4d",
          name, sc, st.ops_max, st.ops_mean, st.lit_min, st.lit_mean, st.lit_max, st.diff_max, st.l15_max, st.bad))
      end
      assert(st.bad == 0, st.bad .. " NaN / inf coordinates or levels")
      assert(st.ops_max <= OPS_BUDGET, "draw calls " .. st.ops_max .. " > " .. OPS_BUDGET)
      assert(st.lit_max <= LIT_MAX, string.format("lit %.3f > %.2f", st.lit_max, LIT_MAX))
      assert(st.lit_min > (sc == "silence" and LIT_MIN_SILENT or 0.005),
        string.format("near blank: lit %.4f", st.lit_min))
      assert(st.diff_max <= DIFF_MAX, string.format("frame jump %.3f > %.2f", st.diff_max, DIFF_MAX))
      assert(st.l15_max <= L15_MAX, st.l15_max .. " pixels at level 15")
    end)
  end
end

-- silence still moves: consecutive frames are never all identical
for th, name in ipairs(NAMES) do
  test("visuals " .. name .. " moves at silence", function()
    local st = run(th, "silence", {frames = 120, keep = true})
    -- most frames differ from the one before (gentle, but never frozen)
    local moved = 0
    for i = 22, 120 do if bufdiff(st.frames[i - 1], st.frames[i]) > 0 then moved = moved + 1 end end
    if REPORT then print(string.format("still %-10s moved %d/99 meanDiff %.4f", name, moved, st.diff_mean)) end
    assert(moved >= 80, "frozen at silence: " .. moved .. " of 99 frames moved")
    assert(st.diff_mean > 0.0004, string.format("barely moving at silence: mean diff %.4f", st.diff_mean))
  end)
end

-- audio reactivity: identical runs are identical, and ramping out_hi or
-- out_lo (everything else held) changes the picture
local function paired(th, a, b)
  local A = run(th, "mid", {frames = 160, audio = a, keep = true})
  local Bs = run(th, "mid", {frames = 160, audio = b, keep = true})
  local d = 0
  for i = 21, 160 do d = d + bufdiff(A.frames[i], Bs.frames[i]) end
  return d / 140
end
local function with(over)
  return function(t)
    local v = SCEN.mid.audio(t)
    for k, x in pairs(over) do v[k] = x end
    return v
  end
end
for th, name in ipairs(NAMES) do
  test("visuals " .. name .. " reacts to out_hi and out_lo", function()
    local same = paired(th, with({}), with({}))
    assert(same == 0, "two identical runs differ: " .. same)
    local dhi = paired(th, with({out_hi = 0}), with({out_hi = 1}))
    local dlo = paired(th, with({out_lo = 0}), with({out_lo = 1}))
    if REPORT then print(string.format("react %-10s hi %.3f lo %.3f", name, dhi, dlo)) end
    assert(dhi > 0.01, string.format("out_hi barely changes it: %.4f", dhi))
    assert(dlo > 0.02, string.format("out_lo barely changes it: %.4f", dlo))
  end)
end

-- a theme switch eases through black rather than cutting
test("visuals theme switch eases", function()
  local st = run(1, "mid", {frames = 480, switch_every = 60})
  if REPORT then print(string.format("switch diffMax %.3f", st.diff_max)) end
  assert(st.diff_max <= DIFF_MAX * 0.6, string.format("theme switch jump %.3f", st.diff_max))
  assert(st.bad == 0)
end)

-- bad input: garbage audio, short / empty chords, no motifs, tempo flapping
test("visuals bad input", function()
  local junk = {nil, 0 / 0, -1, 5, math.huge, -math.huge, 0.5}
  for th = 1, 6 do
    local st, VIS = run(th, "peak", {frames = 60, tempo_jitter = true, audio = function(t)
      local v = junk[math.floor(t * FPS) % 7 + 1]
      return {out_amp = v, out_lo = v, out_mid = v, out_hi = v, nat_amp = v}
    end})
    assert(st.bad == 0, NAMES[th] .. ": " .. st.bad .. " bad draw values")
    if VIS.audio then
      VIS.audio("out_amp", nil); VIS.audio("nope", 1); VIS.audio("out_hi", "x")
    end
    for _, ch in ipairs({{}, {60}, {48, 55}, {48, 55, 62}}) do
      local S = mkS()
      S.chord = ch; S.motifs = nil; S.sounding = nil
      for f = 1, 10 do
        VIS.event("note", (f % 4) + 1, 60, 1)
        RAST.reset_ops(); screen.clear()
        VIS.draw(th, S, 1 / FPS)
        assert(RAST.bad == 0, NAMES[th] .. ": bad draw with chord of " .. #ch)
      end
      S.motifs = {}; S.sounding = {}; S.gain = {}; S.tempo = nil; S.step = nil
      VIS.draw(th, S, 1 / FPS)
      VIS.draw(th, S, 0)
      VIS.draw(th, S, 5)
    end
  end
end)

-- the brightness and speed params still scale everything
test("visuals brightness param scales", function()
  local lo, hi = 0, 0
  for th = 1, 6 do
    env()
    local VIS = include("lib/visuals"); VIS.init()
    local S = mkS(); SCEN.mid.setup(S)
    local function total(b)
      PV.vis_brightness = b
      local s = 0
      for f = 1, 40 do
        if VIS.audio then for n, v in pairs(SCEN.mid.audio(f / FPS)) do VIS.audio(n, v) end end
        screen.clear(); VIS.draw(th, S, 1 / FPS)
        local _, _, sum = lit_stats(); s = s + sum
      end
      return s
    end
    local a = total(3)
    local b = total(15)
    assert(b > a * 1.5, NAMES[th] .. string.format(": brightness 15 vs 3 = %d vs %d", b, a))
  end
end)
-- for ad-hoc scripts (contact sheets, per-frame diffs): dofile this file
-- with test() stubbed and call VIS_HARNESS.run(theme, scenario, {keep = true})
VIS_HARNESS = {run = run, bufdiff = bufdiff}
