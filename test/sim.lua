-- headless sim: stubs the norns APIs estuary touches, drives the 8th-note
-- clock for a number of bars and checks the anti-goal rules (test/rules.lua).
-- run from repo root:  lua test/sim.lua [bars] [play_mode] [minutes] [tempo]
-- env: AUDIO=<dir>  real sample folders (default: a fake tree with some files)
--      MUTES=1      random mute / solo presses every bar
--      HKEY=1       random hand key / mode changes every ~40 bars
--      MIDI=1       motif_out=midi, all motifs on one channel (ch 3)
--      MIDI=2       motif_out=both, one channel per motif; gates + velocity checked
--      OUTS=1       pad/pedal midi, crow (lead pitch/gate, bloom, pedal pitch), CC out, transport
--      OUTS=2       crow chord root + pedal gate instead
--      LISTEN=1     fake KeyTrack feed (E minor, G major, silence, D minor)
--      GRID=1       random grid presses every bar
--      SNAP=dir     after the run, draw each theme into a real raster and write dir/<n>_<name>.pgm;
--                   asserts each frame has >= 40 lit pixels and none repeats another

local BARS    = tonumber(arg[1]) or 300
local PMODE   = tonumber(arg[2]) or 1
local MINUTES = tonumber(arg[3]) or 0
local TEMPO   = tonumber(arg[4]) or 72

calls = {}
LOADS = {}
-- engine stub: every command's arg count is checked against the format
-- string in lib/Engine_Estuary.sc
local FMT = {}
do
  local f = assert(io.open("lib/Engine_Estuary.sc"))
  local src = f:read("a")
  f:close()
  for name, fmt in src:gmatch('addCommand%(\\([%w_]+), "(%w*)"') do FMT[name] = fmt end
  -- tweak keys the engine knows: fxMap entries (\key -> ...)
  TWEAKS = {}
  for k in src:gmatch('\\([%w_]+) %->') do TWEAKS[k] = true end
end
TWV = {}   -- last value sent per tweak key
engine = setmetatable({}, {__index = function(_, k)
  if k == "name" then return nil end
  return function(...)
    local fmt = FMT[k]
    if not fmt then error("engine has no command '" .. k .. "'", 2) end
    local n = select("#", ...)
    if n ~= #fmt then error(string.format("engine.%s: %d args, engine wants %d (%s)", k, n, #fmt, fmt), 2) end
    for i = 1, n do
      local v, t = select(i, ...), fmt:sub(i, i)
      if (t == "f" or t == "i") and (type(v) ~= "number" or v ~= v) then error("engine." .. k .. " arg " .. i .. " not a number", 2) end
      if t == "s" and type(v) ~= "string" then error("engine." .. k .. " arg " .. i .. " not a string", 2) end
    end
    if k == "note" then
      local _, _, _, dur_s = ...
      local b = 60 / TEMPO
      assert(dur_s >= 0.05 and dur_s <= 4 * b + 1e-6, "note dur " .. dur_s .. " s out of range at " .. TEMPO .. " bpm")
    elseif k == "pedal" then
      local _, _, dur_s = ...
      assert(dur_s <= 18 * 60 / TEMPO + 1e-6, "pedal dur " .. dur_s .. " s too long")
    end
    if k == "tweak" then
      local key, val = ...
      if key == "echo_time" then
        local beats = val / (60 / TEMPO)
        local ok = false
        for _, d in ipairs({0.5, 1, 1.5, 2}) do if math.abs(beats - d) < 1e-6 then ok = true end end
        assert(ok and val <= 3.5, "echo_time " .. val .. " s is not a clean division at " .. TEMPO .. " bpm")
      end
      if not TWEAKS[key] then error("engine.tweak: unknown key '" .. key .. "'", 2) end
      TWV[key] = val
    end
    if k == "nature_load" then LOADS[(...)] = (LOADS[(...)] or 0) + 1 end
    calls[k] = (calls[k] or 0) + 1
  end
end})

-- SEED=n pins init's math.randomseed(os.time()) so a failing run replays
if os.getenv("SEED") then
  local seed = tonumber(os.getenv("SEED"))
  os.time = function() return seed end
end

function include(p) return dofile(p .. ".lua") end

-- params ---------------------------------------------------------------
local P = {order = {}, defs = {}}
params = {}
local function add(id, def) def.id = id; P.defs[id] = def; table.insert(P.order, id) end
function params:add_separator() end
function params:add_option(id, _, opts, d) add(id, {v = d, lo = 1, hi = #opts, opts = opts}) end
function params:add_number(id, _, lo, hi, d) add(id, {v = d, lo = lo, hi = hi}) end
function params:add_control(id, _, spec) add(id, {v = spec.default, lo = spec.min, hi = spec.max, f = true}) end
function params:add_file(id, _, d) add(id, {v = d}) end
function params:add_trigger(id) add(id, {v = 0, trig = true}) end
function params:set_action(id, fn) P.defs[id].action = fn end
function params:get(id)
  if id == "clock_tempo" then return TEMPO end
  return P.defs[id].v
end
function params:string(id) local d = P.defs[id]; return d.opts and d.opts[d.v] or tostring(d.v) end
function params:set(id, v, silent)
  if id == "clock_tempo" then return end
  local d = P.defs[id]; d.v = v
  if not silent and d.action then d.action(v) end
end
function params:delta(id, n)
  if id == "clock_tempo" then return end
  local d = P.defs[id]
  if d.trig then return end
  params:set(id, math.max(d.lo, math.min(d.hi, d.v + n * (d.f and 0.01 or 1))))
end
function params:lookup_param(id) return {name = id} end
function params:bang()
  for _, id in ipairs(P.order) do
    local d = P.defs[id]
    if d.action and not d.trig then d.action(d.v) end
  end
end
controlspec = {new = function(min, max, _, _, default) return {min = min, max = max, default = default} end}

-- clock ------------------------------------------------------------------
local threads, nid = {}, 0
clock = {transport = {}}
-- like norns, a new coroutine runs at once up to its first sync / sleep
local cur_id
function clock.run(f)
  nid = nid + 1
  local id = nid
  threads[id] = coroutine.create(f)
  local prev = cur_id
  cur_id = id
  local ok, err = coroutine.resume(threads[id])
  cur_id = prev
  if not ok then error("thread " .. id .. ": " .. tostring(err)) end
  return id
end
function clock.cancel(id) threads[id] = nil end
-- sync records its division per thread: the step clock must wait for a bar
-- (sync 4) once, then only ever sync(1/2). STEP_BEATS is the beats it has
-- advanced since, and is what the rules use as time.
VT = 0   -- virtual seconds, advanced one 8th per drive tick
SYNCS = {}          -- thread id -> {first = arg, n = count, odd = bad arg}
STEP_BEATS = 0
function clock.sync(d)
  local r = SYNCS[cur_id] or {n = 0, odd = nil}
  SYNCS[cur_id] = r
  r.n = r.n + 1
  if r.n == 1 then
    r.first = d
  elseif r.first == 4 then
    if d ~= 1 / 2 then r.odd = d end
    STEP_BEATS = STEP_BEATS + d
  end
  coroutine.yield()
end
WAKE = {}           -- thread id -> virtual time it may resume
function clock.sleep(d) WAKE[cur_id] = VT + (d or 0); coroutine.yield("sleep") end
function clock.get_beat_sec() return 60 / TEMPO end
function clock.get_tempo() return TEMPO end

-- misc -------------------------------------------------------------------
MIDI_CH, MIDI_HELD, MIDI_PEAK = {}, {}, 0
local midi_dev = {
  note_on = function(_, n, v, ch)
    assert(n >= 0 and n <= 127 and v >= 1 and v <= 127 and ch >= 1 and ch <= 16, "bad midi note_on")
    calls.midi_on = (calls.midi_on or 0) + 1
    MIDI_CH[ch] = (MIDI_CH[ch] or 0) + 1
    local k = ch .. ":" .. n
    assert(not MIDI_HELD[k], "note_on for a note still held " .. k)
    MIDI_HELD[k] = true
    if ch == 1 then
      local c = 0
      for key in pairs(MIDI_HELD) do if key:match("^1:") then c = c + 1 end end
      PEDAL_PEAK = math.max(PEDAL_PEAK or 0, c)
    end
    if MIDI_HOOK then MIDI_HOOK(n, v, ch) end
    local c = 0
    for key in pairs(MIDI_HELD) do if tonumber(key:match("^(%d+):")) >= 3 then c = c + 1 end end
    MIDI_PEAK = math.max(MIDI_PEAK, c)
  end,
  note_off = function(_, n, _, ch)
    calls.midi_off = (calls.midi_off or 0) + 1
    MIDI_HELD[ch .. ":" .. n] = nil
  end,
  cc = function(_, num, val, ch)
    assert(num >= 0 and num <= 127 and val >= 0 and val <= 127 and ch >= 1 and ch <= 16, "cc out of range")
    calls.midi_cc = (calls.midi_cc or 0) + 1
  end,
  start = function() calls.midi_start = (calls.midi_start or 0) + 1 end,
  stop = function() calls.midi_stop = (calls.midi_stop or 0) + 1 end,
}
midi = {vports = {{name = "fake synth"}}, connect = function() return midi_dev end}
polls = {}
poll = {set = function(name, fn)
  polls[name] = fn
  return {start = function() end}
end}
local function crow_out(n)
  return setmetatable({slew = 0}, {
    __newindex = function(t, k, v)
      if k == "volts" then
        assert(type(v) == "number" and v > -5.1 and v < 10.1, "crow volts out of range: " .. tostring(v))
        calls["crow" .. n .. "_v"] = (calls["crow" .. n .. "_v"] or 0) + 1
      end
      rawset(t, k, v)
    end,
  })
end
crow = {connected = function() return true end,
        output = {crow_out(1), crow_out(2), crow_out(3), crow_out(4)}}
grid_dev = {cols = 16, rows = 8, leds = 0}
function grid_dev:all() end
function grid_dev:led(x, y, l)
  assert(x >= 1 and x <= 16 and y >= 1 and y <= 8 and l >= 0 and l <= 15, "bad led " .. x .. "," .. y .. "," .. l)
  self.leds = self.leds + 1
end
function grid_dev:refresh() calls.grid_refresh = (calls.grid_refresh or 0) + 1 end
grid = {connect = function() return grid_dev end}
screen = setmetatable({text_extents = function() return 20, 6 end},
  {__index = function() return function() end end})
-- sample folders: a fake tree with a few files, or AUDIO=<dir> for real ones
local AUDIO = os.getenv("AUDIO")
_path = {audio = AUDIO and (AUDIO:gsub("/?$", "/")) or "/fake/audio/", data = "/nonexistent/"}
util = {
  time = function() return VT end,
  file_exists = function() return false end,
  make_dir = function() end,
  scandir = function(dir)
    if AUDIO then
      local out = {}
      local p = io.popen('ls -1 "' .. dir .. '" 2>/dev/null')
      for l in p:lines() do out[#out + 1] = l end
      p:close()
      return out
    end
    if dir:match("/estuary/%a+/$") then return {"a.wav", "b.wav", "c.aif"} end
    return {}
  end,
}
_menu = {mode = false}
-- SNAP=dir: a real raster behind the screen stub so the themes can be looked at
local SNAP = os.getenv("SNAP")
local RAST
if SNAP then RAST = dofile("test/raster.lua"); screen = RAST.screen end

local R = include("test/rules")
dofile("estuary.lua")
init()
if MINUTES > 0 then params:set("track_minutes", MINUTES) end
params:set("play_mode", PMODE)

local MIDIM, OUTSM = tonumber(os.getenv("MIDI") or ""), tonumber(os.getenv("OUTS") or "")
local LISTEN, GRID = os.getenv("LISTEN"), os.getenv("GRID")
if MIDIM then
  params:set("motif_dev", 2)
  params:set("motif_out", MIDIM == 2 and 3 or 2)
  if MIDIM == 2 then params:set("motif_lanes", 6) end        -- own channel each
end
if OUTSM then
  params:set("pad_dev", 2); params:set("pad_out", 3)
  params:set("pedal_dev", 2); params:set("pedal_out", 2)
  params:set("transport_dev", 2)
  params:set("cc_dev", 2); params:set("cc_bloom", 20); params:set("cc_tone", 21); params:set("cc_phrase", 22)
  if OUTSM == 2 then
    params:set("crow_1", 4); params:set("crow_2", 7)          -- chord root, pedal gate
  else
    params:set("crow_1", 2); params:set("crow_2", 3)          -- lead pitch, lead gate
    params:set("crow_3", 5); params:set("crow_4", 6)          -- bloom, pedal pitch
  end
end
if LISTEN then params:set("listen_on", 2) end
-- fake KeyTrack feed by bar: E minor (16), G major (7 -> rel. E minor),
-- silence, then D minor (14)
local function feed(bar)
  if bar < 24 then return 16, 0.1
  elseif bar < 48 then return 7, 0.1
  elseif bar < 60 then return 0, 0.0001
  else return 14, 0.1 end
end

local function getS()
  for j = 1, 60 do
    local name, val = debug.getupvalue(key, j)
    if not name then break end
    if name == "S" then return val end
  end
end
local S = getS()
assert(S, "can't reach S through key()")
R.attach(S)
local notes_by = {0, 0, 0, 0}
S.probe = function(slot, midi, ev, dur_beats)
  notes_by[slot] = notes_by[slot] + 1
  R.on_note(STEP_BEATS, slot, midi, dur_beats, ev)
end
-- the pedal as heard: midi (nil = released) and its sustain in beats; the
-- engine's release tail adds 30%
S.pedal_probe = function(midi, dur_beats)
  R.on_pedal(STEP_BEATS, midi, (dur_beats or 0) * 1.3)
end

-- one channel per motif: a motif the conductor thinned (gain <= 0.02) or a hand
-- mute sends no midi at all, and velocity is vel x gain (vel <= 0.8)
if MIDIM == 2 then
  MIDI_HOOK = function(_, v, ch)
    if ch < 3 or ch > 6 then return end
    local k = "motif" .. (ch - 2)
    local g = S.gain[k] or 0
    assert(g > 0.02 and not S.muted[k], "midi note from a thinned / muted " .. k .. " gain " .. g)
    assert(v <= 127 * 0.8 * g + 1.5, string.format("midi velocity %d too loud for %s gain %.2f", v, k, g))
    MIDI_GATED = (MIDI_GATED or 0) + 1
  end
end

-- K2+K3 = play
key(2, 1); key(3, 1); key(3, 0); key(2, 0)
assert(S.playing, "K2+K3 didn't start")

-- grid: a step press that would leave the motif with < 3 notes (or no rest)
-- is refused; one that keeps the shape is taken
do
  local function snap(m)
    local t = {}
    for _, e in ipairs(m.events) do t[#t + 1] = (e.tone or "-") .. "/" .. (e.pass or "-") .. "/" .. e.dur end
    return m.cycle .. ":" .. table.concat(t, " ")
  end
  local m = S.motifs[1]
  m.events = {{dur = 2, tone = 1}, {dur = 2, tone = 2}, {dur = 2, tone = 3}, {dur = 2}, {dur = 6}}
  m.cycle = 14
  local before = snap(m)
  grid_dev.key(2, 4, 1); grid_dev.key(2, 4, 0)       -- sounding step: would leave 2 notes
  assert(snap(m) == before, "grid press left a motif with 2 notes: " .. snap(m))
  grid_dev.key(14, 4, 1)                              -- no such step
  assert(snap(m) == before, "press past the last event changed the motif")
  grid_dev.key(4, 4, 1); grid_dev.key(4, 4, 0)       -- a rest -> note: 4 notes, 1 rest left
  assert(m.events[4].tone and not m.events[4].pass and snap(m):match("^14:"), "rest -> note refused: " .. snap(m))
  grid_dev.key(5, 4, 1); grid_dev.key(5, 4, 0)       -- last rest -> note: no rest left, refused
  assert(not m.events[5].tone, "grid press removed the last rest")
  grid_dev.key(4, 4, 1); grid_dev.key(4, 4, 0)       -- back to a rest
  assert(snap(m) == before, "note -> rest didn't restore the motif: " .. snap(m))
  grid_dev.key(15, 4, 1)                              -- mute motif 1
  assert(S.muted.motif1, "grid col 15 didn't mute"); grid_dev.key(15, 4, 1)
  assert(not S.muted.motif1, "grid col 15 didn't unmute")
end

-- drive: resume every live thread once per 8th. the step clock waits a bar
-- then ticks; note-off / draw threads come and go.
PEAK_THREADS = 0
local function tick_all()
  VT = VT + 60 / TEMPO / 2
  if LISTEN and polls.in_key then
    local k, a = feed(S.track_bar)
    if math.random() < 0.15 then k = math.random(0, 23) end    -- tracker noise
    polls.in_key(k); polls.in_amp(a)
  end
  -- sleepers (note-offs) wake before the step clock, as they would if their
  -- time had come first; a sleeper wakes once its virtual time has passed
  local order, live = {}, 0
  for id, co in pairs(threads) do
    if coroutine.status(co) == "dead" then threads[id] = nil
    else
      live = live + 1
      order[#order + 1] = id
    end
  end
  PEAK_THREADS = math.max(PEAK_THREADS, live)
  table.sort(order, function(a, b)
    local wa, wb = WAKE[a] and 0 or 1, WAKE[b] and 0 or 1
    if wa ~= wb then return wa < wb end
    return a < b
  end)
  for _, id in ipairs(order) do
    local co = threads[id]
    if co and (not WAKE[id] or WAKE[id] <= VT + 1e-9) then
      WAKE[id] = nil
      cur_id = id
      local ok, err = coroutine.resume(co)
      if not ok then error("thread " .. id .. ": " .. tostring(err)) end
    end
  end
end

-- hand-driven stress: mutes / solos through the parts page, key / mode moves
local MUTES, HKEY = os.getenv("MUTES"), os.getenv("HKEY")
if MUTES then
  key(1, 1); enc(2, 10); key(1, 0)        -- parts page is last
end
local function hands(bar)
  if MUTES then
    key(1, 0)
    enc(2, math.random(-6, 6))
    if math.random() < 0.7 then
      if math.random() < 0.6 then key(2, 1); key(2, 0) else key(3, 1); key(3, 0) end
    end
  end
  if GRID then
    for _ = 1, 3 do
      local x, y = math.random(1, 16), math.random(1, 8)
      if not (y == 8 and (x == 16 or x == 14)) then grid_dev.key(x, y, 1) end
    end
  end
  if HKEY and bar % 40 == 20 then
    key(2, 1); enc(2, math.random(-7, 7)); enc(3, math.random(-3, 3)); key(2, 0)
  end
end

local bars_seen, steps = 0, 0
local max_bars_between = 0
while bars_seen < BARS do
  tick_all()
  steps = steps + 1
  assert(steps < BARS * 8 + 64, "clock stalled")
  if not S.playing then print("stopped at bar", S.track_bar); break end
  if S.step % 8 == 1 and S.step // 8 > bars_seen then
    bars_seen = S.step // 8
    R.on_bar(S, STEP_BEATS)
    hands(bars_seen)
    if bars_seen % 100 == 0 then
      local g = {}
      for _, k in ipairs({"motif1", "motif2", "motif3", "motif4", "pad", "pedal"}) do
        g[#g + 1] = string.format("%s=%.2f", k:gsub("motif", "m"), S.gain[k] or 0)
      end
      print(string.format("bar %5d  %-9s bloom=%.2f %-6s %s  nature=%s  seed=%s",
        bars_seen, S.section, S.bloom, tostring(S.chord_label), table.concat(g, " "),
        tostring(S.nature_state), tostring(S.seed)))
    end
  end
end

-- visuals: every theme into the raster (overlay off), with a tide running so
-- the swell-driven themes have something to show; each frame must carry
-- >= 40 lit pixels and differ from every other theme's
if SNAP then
  assert(os.execute("mkdir -p '" .. SNAP .. "'"))
  local names = P.defs.theme.opts
  assert(#names == 6, "expected 6 themes, got " .. #names)
  params:set("hud", 3)
  key(3, 1); key(3, 0)                                    -- bring the tide in
  local seen = {}
  for th = 1, #names do
    params:set("theme", th)
    local file = string.format("%s/%s.pgm", SNAP, names[th])
    -- the frame with the most content above the bottom rows (a ground line or
    -- splashes alone must not pass) is the one kept, from the last 3 ticks
    local best = -1
    for i = 1, 48 do
      tick_all(); steps = steps + 1
      for k = 1, 8 do
        redraw()
        if i > 45 then
          local c = 0
          for y = 0, 57 do for x = 0, 127 do if (RAST.buf[y * 128 + x] or 0) > 0 then c = c + 1 end end end
          if c > best then best = c; RAST.snap(file) end
        end
      end
    end
    local lit = best
    assert(lit >= 40, names[th] .. ": only " .. lit .. " lit pixels above the ground rows")
    local f = assert(io.open(file, "rb")); local data = f:read("a"); f:close()
    assert(lit >= 40, names[th] .. ": only " .. lit .. " lit pixels")
    for o, d in pairs(seen) do assert(d ~= data, names[th] .. " is identical to " .. o) end
    seen[names[th]] = data
    print(string.format("snap %-9s lit pixels %d", names[th], lit))
  end
  params:set("hud", 1)
end
-- the theme cycle moves on its edges
for c = 2, 3 do
  if S.playing then
    params:set("vis_cycle", c)
    local t0, moved = params:get("theme"), false
    for i = 1, 8 * 40 do tick_all(); steps = steps + 1; if params:get("theme") ~= t0 then moved = true end end
    assert(moved, "theme cycle " .. c .. " never moved")
  end
end
params:set("vis_cycle", 1)

local keys = {}
for k in pairs(calls) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do print(string.format("  %-12s %d", k, calls[k])) end
print(string.format("notes per slot: %d %d %d %d;  max sounding at once: %d;  8th pairs: %d;  avoid notes: %d",
  notes_by[1], notes_by[2], notes_by[3], notes_by[4], R.stats.max_overlap, R.stats.pairs, R.stats.avoid))
print(string.format("swells: %d  moments: %d", LOADS[2] or 0, LOADS[3] or 0))
if AUDIO then
  local f = include("lib/nature").scan()
  print(string.format("scan: water=%d birds=%d wind=%d room=%d",
    #f.water, #f.birds, #f.wind, #f.room))
end

local extra = {}
-- a pad must not fade back in while stopped (stop, then rebuild / seed change)
if S.playing then
  key(2, 1); key(3, 1); key(3, 0); key(2, 0)
  P.defs.rebuild.action()
  params:set("seed", 123)
  if TWV.pad_level ~= 0 then extra[#extra + 1] = "pad_level " .. tostring(TWV.pad_level) .. " while stopped" end
end
do
  local found = false
  for _, r in pairs(SYNCS) do
    if r.first == 4 then
      found = true
      if r.odd then extra[#extra + 1] = "step clock synced to " .. r.odd .. " instead of 1/2" end
    end
  end
  if not found then extra[#extra + 1] = "step clock never waited for a bar with sync(4)" end
  -- one tick per 8th: virtual beats advanced match the ticks driven
  if math.abs(STEP_BEATS - (steps - 1) * 0.5) > 1.01 then
    extra[#extra + 1] = string.format("step clock advanced %.1f beats in %d ticks", STEP_BEATS, steps)
  end
end
if not AUDIO and BARS >= 600 and not MUTES then
  if (LOADS[2] or 0) == 0 then extra[#extra + 1] = "no water swell in " .. BARS .. " bars" end
  if (LOADS[3] or 0) == 0 then extra[#extra + 1] = "no passing moment in " .. BARS .. " bars" end
end
assert(PEAK_THREADS <= 64, "live threads peaked at " .. PEAK_THREADS)
if MIDIM then
  if (calls.midi_on or 0) == 0 then extra[#extra + 1] = "no midi notes" end
  if MIDIM == 1 then
    if (MIDI_CH[3] or 0) == 0 then extra[#extra + 1] = "no midi note-ons on ch 3" end
    if (calls.note or 0) > 0 then extra[#extra + 1] = "engine.note called with motif_out=midi" end
  else
    if (calls.note or 0) == 0 then extra[#extra + 1] = "motif_out=both made no internal notes" end
    if (MIDI_GATED or 0) == 0 then extra[#extra + 1] = "gate hook never ran" end
  end
  if MIDI_PEAK > 3 then extra[#extra + 1] = "peak concurrent midi motif notes " .. MIDI_PEAK end
  print(string.format("midi: %d note-ons, peak concurrent %d, peak live threads %d", calls.midi_on or 0, MIDI_PEAK, PEAK_THREADS))
end
if OUTSM then
  if calls.midi_start ~= 1 then extra[#extra + 1] = "midi start sent " .. tostring(calls.midi_start) .. " times" end
  if (calls.midi_cc or 0) == 0 then extra[#extra + 1] = "no cc out" end
  if (calls.crow1_v or 0) == 0 then extra[#extra + 1] = "crow out 1 never moved" end
  if (calls.midi_on or 0) == 0 then extra[#extra + 1] = "no pad / pedal midi" end
  if (PEDAL_PEAK or 0) > 1 then extra[#extra + 1] = "pedal midi stacked: " .. PEDAL_PEAK .. " notes held on ch 1" end
  if (MIDI_CH[1] or 0) == 0 then extra[#extra + 1] = "pedal never sent midi on ch 1" end
  if (MIDI_CH[2] or 0) < 4 then extra[#extra + 1] = "pad never sent midi on ch 2" end
end
if LISTEN and BARS >= 90 and not HKEY then
  local T = include("lib/theory")
  local want = T.root_for(2, S.mode)
  if S.root_pc ~= want then extra[#extra + 1] = "listen: root ended on " .. S.root_pc .. ", wanted " .. want end
end
if notes_by[1] + notes_by[2] + notes_by[3] + notes_by[4] == 0 then extra[#extra + 1] = "no notes played" end
if OUTSM and S.playing == false and (calls.midi_stop or 0) ~= 1 then extra[#extra + 1] = "midi stop sent " .. tostring(calls.midi_stop) .. " times" end
if MIDIM then
  for k in pairs(MIDI_HELD) do if tonumber(k:match("^(%d+):")) >= 3 then extra[#extra + 1] = "midi note " .. k .. " left hanging after stop" end end
end
local ok, fails = R.report()
for _, f in ipairs(extra) do fails[#fails + 1] = f; ok = false end
if ok then
  print("RULES ok")
else
  print("RULES FAILED")
  for _, f in ipairs(fails) do print("  " .. f) end
  os.exit(1)
end
