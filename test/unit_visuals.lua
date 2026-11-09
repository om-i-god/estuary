-- visuals: every theme x {silence, mid, peak, swell} drawn headless into the
-- raster stand-in (test/raster.lua), 20 fps of virtual time. each run checks
-- the lit-pixel ratio, that silence is never blank, the frame-to-frame
-- change, NaN / inf reaching the screen, level-15 area and the draw-call
-- budget. then: ramping out_hi / out_lo changes every theme, a theme switch
-- eases, and bad input (nil / NaN / out-of-range audio, short chords, no
-- motifs, a tempo change mid-frame) draws cleanly; out-of-range audio draws
-- exactly as the clamped value would; a jittery frame rate tells the same
-- story as a steady one; the speed param scales the motion.
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

-- the six v2 themes first, in their old order (saved psets keep pointing at
-- the same theme), then the six v3 ones, then the ten v5 ones
local NAMES = {"ripples", "horizon", "postcards", "rain", "tide", "drift",
  "reeds", "koi", "kelp", "fireflies", "mist", "flock",
  "brook", "rockpool", "dew", "cascade", "mangrove", "aurora", "shoal", "paddies",
  "echo bridge", "confluence"}

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
  local t = 0
  for f = 1, opts.frames or 400 do
    local dt = opts.dt and opts.dt(f) or 1 / FPS
    t = t + dt
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
    if opts.switch_every and f % opts.switch_every == 0 then th = th % #NAMES + 1 end
    if opts.at then opts.at(f, VIS, S) end
    screen.clear()
    RAST.reset_ops()
    VIS.draw(th, S, dt)
    local lit, l15, sum = lit_stats()
    local cur = copybuf()
    st.bad = st.bad + RAST.bad
    if t > 1 then                               -- past the first second
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
  st.t = t
  st.ops_mean = st.ops_sum / st.n
  st.lit_mean = st.lit_sum / st.n
  st.diff_mean = st.diff_sum / math.max(1, st.n - 1)
  return st, VIS
end

local SCENS = {"silence", "mid", "peak", "swell"}

-- bounds (see the visuals v2 / v3 reports for where they come from)
local OPS_BUDGET = 1100       -- draw calls per frame, any theme, any scenario (v2 peaked at 748: ~1.5x)
local LIT_MAX = 0.35          -- never more than ~35% of the screen lit
local LIT_MIN_SILENT = 0.01   -- silence is never blank (~80 pixels)
local LIT_MIN_LIVE = 0.04     -- with music, a scene, not a near-empty screen
local DIFF_MAX = 0.35         -- mean |level change| per pixel, frame to frame
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
      assert(st.lit_min > (sc == "silence" and LIT_MIN_SILENT or LIT_MIN_LIVE),
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
  for th = 1, #NAMES do
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
  for th = 1, #NAMES do
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
test("visuals names: v2 order first, then the v3 and v5 themes", function()
  env()
  local VIS = include("lib/visuals")
  assert(#VIS.names == #NAMES, #VIS.names .. " themes")
  for i, n in ipairs(NAMES) do assert(VIS.names[i] == n, i .. ": " .. tostring(VIS.names[i])) end
end)

-- out-of-range audio draws exactly what the clamped value draws. VIS.audio
-- clamps on arrival, so today this cannot fail: it guards against a theme
-- ever reading raw poll values
test("visuals out-of-range audio == clamped", function()
  for th = 1, #NAMES do
    local over = run(th, "mid", {frames = 80, keep = true, audio = function(t)
      local w = math.sin(t * 3)
      return {out_amp = 5, out_lo = -3, out_mid = w * 4, out_hi = 1.5, nat_amp = -0.2}
    end})
    local clamped = run(th, "mid", {frames = 80, keep = true, audio = function(t)
      local w = math.sin(t * 3)
      return {out_amp = 1, out_lo = 0, out_mid = math.max(0, math.min(1, w * 4)), out_hi = 1, nat_amp = 0}
    end})
    for i = 1, 80 do
      assert(bufdiff(over.frames[i], clamped.frames[i]) == 0, NAMES[th] .. ": frame " .. i .. " differs")
    end
  end
end)

-- frame-rate independence (coarse): with a jittery frame rate (25 to 60 ms
-- per frame) a theme lights about as much of the screen as at a steady 20
-- fps, draws nothing bad, and stays inside the same frame-to-frame bound.
-- it does not compare the pictures themselves
test("visuals variable dt", function()
  for th = 1, #NAMES do
    local steady = run(th, "mid", {frames = 240})
    local jit = run(th, "mid", {frames = 240, dt = function(f)
      return ({0.025, 0.06, 0.04, 0.03, 0.055, 0.045})[f % 6 + 1]
    end})
    if REPORT then
      print(string.format("vardt %-10s lit %.3f / %.3f  diff %.3f / %.3f  bad %d",
        NAMES[th], steady.lit_mean, jit.lit_mean, steady.diff_max, jit.diff_max, jit.bad))
    end
    assert(jit.bad == 0, NAMES[th] .. ": bad draw values with a jittery dt")
    local r = jit.lit_mean / steady.lit_mean
    assert(r > 0.75 and r < 1.33, string.format("%s: lit %.3f at jittery dt vs %.3f steady", NAMES[th], jit.lit_mean, steady.lit_mean))
    -- longer frames move further, but stay inside the same jump bound
    assert(jit.diff_max <= DIFF_MAX, string.format("%s: jump %.3f at jittery dt", NAMES[th], jit.diff_max))
  end
end)

-- the speed param scales the motion: speed 9 moves more per frame than speed 1
test("visuals speed param scales motion", function()
  for th = 1, #NAMES do
    local function moved(sp)
      env(); PV.vis_speed = sp
      local VIS = include("lib/visuals"); VIS.init()
      local S = mkS(); SCEN.silence.setup(S)
      local prev, d = nil, 0
      for f = 1, 100 do
        screen.clear(); VIS.draw(th, S, 1 / FPS)
        local c = copybuf()
        if prev and f > 40 then d = d + bufdiff(prev, c) end
        prev = c
      end
      return d
    end
    local slow, fast = moved(1), moved(9)
    if REPORT then print(string.format("speed %-10s 1: %.3f  9: %.3f", NAMES[th], slow, fast)) end
    assert(fast > slow * 1.5, string.format("%s: speed 9 moves %.3f vs speed 1 %.3f", NAMES[th], fast, slow))
  end
end)

-- onsets ease in: a moment and a note fired mid-run never jump the picture
-- more than ~3x a typical frame's change
test("visuals onsets ease in", function()
  local ON = 140
  for th = 1, #NAMES do
    local st = run(th, "mid", {frames = 200, keep = true, at = function(f, VIS)
      if f == ON then VIS.event("moment", "passing"); VIS.event("note", 2, 72, 1.5) end
    end})
    local d = {}
    for i = 100, ON - 1 do d[#d + 1] = bufdiff(st.frames[i - 1], st.frames[i]) end
    table.sort(d)
    local med = d[#d // 2 + 1]
    local onset = 0
    for i = ON, ON + 4 do onset = math.max(onset, bufdiff(st.frames[i - 1], st.frames[i])) end
    if REPORT then print(string.format("onset %-10s median %.4f onset %.4f", NAMES[th], med, onset)) end
    assert(onset <= 3 * math.max(med, 0.01), string.format("%s: onset jump %.4f vs median %.4f", NAMES[th], onset, med))
  end
end)

------------------------------------------------------------------------
-- v4: the reactivity matrix, pitch mapping and incidents
------------------------------------------------------------------------

-- a controlled scene for the matrix: steady ears, a steady bloom, the
-- motif clock running, and nothing else unless the variant adds it. every
-- variant changes exactly one input from the base run
local RF = 200                    -- frames per matrix run (10 s)
local BASE_EARS = {out_amp = 0.3, out_lo = 0.3, out_mid = 0.3, out_hi = 0.3, nat_amp = 0.3}
local function react_run(th, v)
  v = v or {}
  env()
  local VIS = include("lib/visuals")
  VIS.init()
  local S = mkS()
  S.bloom = 0.5; S.section = "flow"
  S.sounding = {true, false, true, false}
  S.gain.motif1, S.gain.motif3 = 0.7, 0.6
  local frames, t, next_step = {}, 0, 0
  for f = 1, RF do
    t = t + 1 / FPS
    while t >= next_step do
      S.step = S.step + 1
      if v.bar and S.step % 8 == 0 then VIS.event("bar", S) end
      next_step = next_step + 60 / S.tempo / 2
    end
    if v.note and f >= 60 and f % 10 == 0 then VIS.event("note", v.slot or 1, v.midi or 67, 1.2) end
    if v.chord and f == 60 then S.chord = CHORDS[3]; VIS.event("chord", S) end
    if v.chord2 and f == 60 then S.chord = CHORDS[3]; VIS.event("chord", S) end
    if v.chord2 and f == 72 then S.chord = {43, 50, 59}; VIS.event("chord", S) end
    if v.bloom and f >= 40 then S.bloom = math.min(1, 0.5 + (f - 40) / 60 * 0.5) end
    if v.swell and f >= 40 and f % 8 == 0 then
      local lv = math.min(1, (f - 40) / 60)
      VIS.event("swell", lv < 1 and "rising" or "held", lv)
    end
    if v.moment and f == 60 then VIS.event("moment", "passing") end
    for name, x in pairs(BASE_EARS) do VIS.audio(name, (v.ear == name) and 0.9 or x) end
    screen.clear()
    VIS.draw(th, S, 1 / FPS)
    frames[f] = copybuf()
  end
  return frames
end

local function mean_diff(a, b, f0)
  local d = 0
  for i = f0, RF do d = d + bufdiff(a[i], b[i]) end
  return d / (RF - f0 + 1)
end

-- where a change sits on screen: the centroid of |a - b| over the frames,
-- counting only pixels where b also differs from c (what the two runs
-- share, the part of the response that does not depend on pitch, cancels)
local function centroid(a, b, f0, c)
  local sx, sy, sw = 0, 0, 0
  for i = f0, RF do
    local fa, fb, fc = a[i], b[i], c[i]
    for p = 0, 8191 do
      local d = math.abs(fa[p] - fb[p])
      if d > 0 and fb[p] ~= fc[p] then sx, sy, sw = sx + (p % 128) * d, sy + (p // 128) * d, sw + d end
    end
  end
  if sw == 0 then return 64, 32, 0 end
  return sx / sw, sy / sw, sw
end

-- each input alone must move the picture by more than this (mean |level
-- change| per pixel over the frames after the input changes). v3's
-- weakest response, koi out_hi, cleared 0.01 by 0.011
local REACT_MIN = 0.03
local INPUTS = {
  {"note", {note = true}, 61}, {"chord", {chord = true}, 61}, {"bar", {bar = true}, 21},
  {"bloom", {bloom = true}, 41}, {"swell", {swell = true}, 41}, {"moment", {moment = true}, 61},
  {"out_amp", {ear = "out_amp"}, 21}, {"out_lo", {ear = "out_lo"}, 21}, {"out_mid", {ear = "out_mid"}, 21},
  {"out_hi", {ear = "out_hi"}, 21}, {"nat_amp", {ear = "nat_amp"}, 21},
}
local MATRIX = {}                 -- theme -> input -> margin, for the report

for th, name in ipairs(NAMES) do
  test("visuals " .. name .. " reactivity matrix", function()
    local base = react_run(th)
    local again = react_run(th)
    assert(mean_diff(base, again, 1) == 0, "two identical runs differ")
    local row, low, fails = {}, math.huge, {}
    for _, inp in ipairs(INPUTS) do
      local d = mean_diff(base, react_run(th, inp[2]), inp[3])
      row[inp[1]] = d
      low = math.min(low, d)
      if d <= REACT_MIN then fails[#fails + 1] = string.format("%s %.4f", inp[1], d) end
    end
    MATRIX[name] = row
    if REPORT then
      local s = {}
      for _, inp in ipairs(INPUTS) do s[#s + 1] = string.format("%s %.3f", inp[1], row[inp[1]]) end
      print(string.format("matrix %-10s low %.3f | %s", name, low, table.concat(s, "  ")))
    end
    assert(#fails == 0, "barely reacts to: " .. table.concat(fails, ", "))
  end)
end

-- notes in different slots leave different marks; a low and a high note in
-- the same slot land in different places
for th, name in ipairs(NAMES) do
  test("visuals " .. name .. " slots and pitch", function()
    local base = react_run(th)
    local by = {}
    for s = 1, 4 do by[s] = react_run(th, {note = true, slot = s, midi = 67}) end
    local lowpair = math.huge
    for a = 1, 3 do
      for b = a + 1, 4 do
        local d = mean_diff(by[a], by[b], 61)
        lowpair = math.min(lowpair, d)
        assert(d > REACT_MIN * 0.5, string.format("slots %d and %d look alike: %.4f", a, b, d))
      end
    end
    local far = math.huge
    for _, s in ipairs({1, 3}) do
      local lo = react_run(th, {note = true, slot = s, midi = 57})
      local hi = react_run(th, {note = true, slot = s, midi = 86})
      local lx, ly = centroid(base, lo, 61, hi)
      local hx, hy = centroid(base, hi, 61, lo)
      local d = math.sqrt((lx - hx) ^ 2 + (ly - hy) ^ 2)
      far = math.min(far, d)
      assert(d > 12, string.format("slot %d: low and high notes land %.1f px apart", s, d))
    end
    if REPORT then print(string.format("pitch %-10s slot pairs >= %.3f  low/high >= %.1f px", name, lowpair, far)) end
  end)
end

-- incidents: over 20 simulated minutes each place shows at least two kinds
-- of small happening, one at a time, and rarely. drawn into a counting
-- screen (the raster is too slow for 20 minutes x 22); how they ease in and
-- out is measured on the picture by the test after the bar's
local NULLS = setmetatable({}, {__index = function() return function() end end})
for th, name in ipairs(NAMES) do
  test("visuals " .. name .. " incidents", function()
    env()
    local VIS = include("lib/visuals")
    VIS.init()
    assert(VIS._probe, "no incident probe")
    screen = NULLS
    local S = mkS(); SCEN.mid.setup(S)
    local DTI = 0.1
    local kinds, n, prev_name = {}, 0, nil
    local steps, k = 0, 0
    for f = 1, math.floor(20 * 60 / DTI) do
      steps = steps + DTI
      while steps >= 60 / S.tempo / 2 do
        steps = steps - 60 / S.tempo / 2
        S.step = S.step + 1
        if S.step % 8 == 0 then VIS.event("bar", S) end
        if math.random() < 0.3 then VIS.event("note", math.random(1, 4), 55 + math.random(0, 30), 1) end
        k = k + 1
        if k % 64 == 0 then S.chord = CHORDS[(k // 64) % 4 + 1]; VIS.event("chord", S) end
      end
      for nm, v in pairs(SCEN.mid.audio(f * DTI)) do VIS.audio(nm, v) end
      VIS.draw(th, S, DTI)
      local p = VIS._probe()
      assert(p.active <= 1, "two incidents at once")
      if p.incident and p.incident ~= prev_name then kinds[p.incident] = true; n = n + 1 end
      prev_name = p.incident
    end
    screen = RAST.screen
    local nk = 0
    for _ in pairs(kinds) do nk = nk + 1 end
    if REPORT then print(string.format("incidents %-10s %d kinds, %d in 20 min", name, nk, n)) end
    assert(nk >= 2, nk .. " kinds of incident in 20 minutes")
    assert(n <= 40, n .. " incidents in 20 minutes: not rare")
  end)
end

-- the bar breathes, it never blinks: the picture the bar adds (bar run
-- minus the same run without bars) never changes by more than ~35% of its
-- own peak in a single frame, so big shapes brighten a few rects at a time
local function step_ratio(base, var, f0)
  local peak, step = 0, 0
  local prev
  for i = f0, RF do
    local a, b = base[i], var[i]
    local d, cur = 0, {}
    for p = 0, 8191 do
      local x = b[p] - a[p]
      cur[p] = x
      d = d + math.abs(x)
    end
    peak = math.max(peak, d / 8192)
    if prev then
      local s = 0
      for p = 0, 8191 do s = s + math.abs(cur[p] - prev[p]) end
      step = math.max(step, s / 8192)
    end
    prev = cur
  end
  return step, peak
end
for th, name in ipairs(NAMES) do
  test("visuals " .. name .. " bar breathes, never blinks", function()
    local base = react_run(th)
    local step, peak = step_ratio(base, react_run(th, {bar = true}), 21)
    if REPORT then print(string.format("breath %-10s step %.4f peak %.4f ratio %.2f", name, step, peak, step / math.max(peak, 1e-9))) end
    assert(step <= 0.35 * peak, string.format("bar steps %.4f in one frame vs a peak of %.4f", step, peak))
  end)
end

-- a chord that moves again mid-glide carries on from where its tones are:
-- no tone jumps back or blinks out (the second chord has only three)
for th, name in ipairs(NAMES) do
  test("visuals " .. name .. " chord glides on mid-glide", function()
    local base = react_run(th)
    local step, peak = step_ratio(base, react_run(th, {chord2 = true}), 21)
    if REPORT then print(string.format("chord2 %-10s step %.4f peak %.4f ratio %.2f", name, step, peak, step / math.max(peak, 1e-9))) end
    assert(step <= 0.35 * peak, string.format("chord steps %.4f in one frame vs a peak of %.4f", step, peak))
  end)
end

-- no small happening at boot: the first waits even if VIS.init never runs
test("visuals no incident at boot", function()
  env()
  local V = include("lib/visuals")
  screen = NULLS
  for f = 1, 200 do
    V.draw(1 + f % #NAMES, mkS(), 1 / FPS)
    assert(not V._probe().incident, "an incident at frame " .. f)
  end
  screen = RAST.screen
end)

-- and each kind of incident can be seen and never pops: forced on, it
-- changes the picture clearly while it is fully there, and the light it adds
-- never jumps by more than ~25% of its peak in one frame (its parts ease in
-- and out, and swap shapes by crossfading)
-- and nothing pops while they last: the same run with and without a
-- moment and a note in each slot, compared frame by frame over the whole
-- moment (~16 s), in the steady scene the incidents use. what the events add to the picture may move and change,
-- but never jump by more than POP_K typical frames' change in one frame (a
-- light that wraps round, a band that steps a row, a mark drawn at full on
-- its first frame). POP_K is loose enough for wings beating and a school
-- re-forming, tight enough to catch a canopy lighting in one frame
local POP_K = 8
local function pop_step(a, b, f0, f1)
  local worst, wf = 0, f0
  for f = f0 + 1, f1 do
    local fa, fb, pa, pb = a[f], b[f], a[f - 1], b[f - 1]
    local s = 0
    for p = 0, 8191 do
      local x = (fa[p] - fb[p]) - (pa[p] - pb[p])
      s = s + (x < 0 and -x or x)
    end
    s = s / 8192
    if s > worst then worst, wf = s, f end
  end
  return worst, wf
end
local function frame_median(fr, f0, f1)
  local d = {}
  for i = f0, f1 do d[#d + 1] = bufdiff(fr[i - 1], fr[i]) end
  table.sort(d)
  return d[#d // 2 + 1]
end
local IF = 640                    -- frames per incident run (32 s: the longest is ~30)
local function inc_run(th, k, at)
  env()
  local V = include("lib/visuals"); V.init()
  local S = mkS(); S.bloom = 0.5; S.section = "flow"
  S.sounding = {true, false, true, false}
  S.gain.motif1, S.gain.motif3 = 0.7, 0.6
  local frames, full = {}, {}
  local t, next_step = 0, 0
  for f = 1, IF do
    t = t + 1 / FPS
    while t >= next_step do S.step = S.step + 1; next_step = next_step + 60 / S.tempo / 2 end
    if k and f == 20 then V._incident(k) end
    if at then at(f, V) end
    for nm, x in pairs(BASE_EARS) do V.audio(nm, x) end
    screen.clear(); V.draw(th, S, 1 / FPS)
    frames[f] = copybuf()
    local p = V._probe()
    full[f] = p.incident ~= nil and p.env > 0.9
  end
  return frames, full, V
end
local INC_SEEN = 0.015
for th, name in ipairs(NAMES) do
  test("visuals " .. name .. " incidents show", function()
    local base, _, V = inc_run(th)
    local bmed = frame_median(base, 22, IF)
    local list = V._probe().kinds
    assert(list and #list >= 2, "fewer than 2 kinds of incident")
    local fails = {}
    for i = 1, #list do
      local frames, full = inc_run(th, i)
      local d, n = 0, 0
      -- (the incident's light on screen, frame by frame: a moving creature
      -- keeps it steady, a part that appears, vanishes or swaps all at once
      -- makes it jump)
      local peak, step, prev = 0, 0, nil
      for f = 21, IF do
        local a, b = base[f], frames[f]
        local s = 0
        for p = 0, 8191 do s = s + math.abs(b[p] - a[p]) end
        s = s / 8192
        peak = math.max(peak, s)
        if full[f] then d, n = d + s, n + 1 end
        if prev then step = math.max(step, math.abs(s - prev)) end
        prev = s
      end
      local seen = d / math.max(1, n)
      -- (and nothing in it jumps from one frame to the next: see POP_K)
      local pstep, pf = pop_step(frames, base, 21, IF)
      if pstep > POP_K * math.max(bmed, 0.01) then fails[#fails + 1] = string.format("%s jumps %.4f at frame %d (median %.4f)", list[i], pstep, pf, bmed) end
      if REPORT then print(string.format("incshow %-10s %-10s seen %.4f step %.4f peak %.4f ratio %.2f", name, list[i], seen, step, peak, step / math.max(peak, 1e-9))) end
      if seen <= INC_SEEN then fails[#fails + 1] = string.format("%s barely shows (%.4f)", list[i], seen) end
      if step > 0.25 * peak then fails[#fails + 1] = string.format("%s pops (%.4f in a frame vs a peak of %.4f)", list[i], step, peak) end
    end
    assert(#fails == 0, table.concat(fails, "; "))
  end)
end

for th, name in ipairs(NAMES) do
  test("visuals " .. name .. " moment and notes never pop", function()
    local ON = 40
    local quiet = inc_run(th)
    local ev = inc_run(th, nil, function(f, V)
      if f == ON then V.event("moment", "passing") end
      for s = 1, 4 do if f == ON + 10 + s * 20 then V.event("note", s, 60 + s * 5, 1.5) end end
    end)
    local med = frame_median(quiet, 22, IF)
    local step, f = pop_step(ev, quiet, ON - 1, IF)
    if REPORT then print(string.format("pop %-10s median %.4f worst %.4f at +%d (x%.1f)", name, med, step, f - ON, step / math.max(med, 0.01))) end
    assert(step <= POP_K * math.max(med, 0.01), string.format("a %.4f jump %d frames after the moment vs a median of %.4f", step, f - ON, med))
  end)
end

-- for ad-hoc scripts (contact sheets, per-frame diffs): dofile this file
-- with test() stubbed and call VIS_HARNESS.run(theme, scenario, {keep = true})
VIS_HARNESS = {run = run, bufdiff = bufdiff, react_run = react_run}
