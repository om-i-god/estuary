-- headless sim: stubs the norns APIs estuary touches, drives the 8th-note
-- clock for a number of bars and checks the anti-goal rules (test/rules.lua).
-- run from repo root:  lua test/sim.lua [bars] [play_mode] [minutes] [tempo]
-- env: AUDIO=<dir>  real sample folders (default: a fake tree with some files)
--      MUTES=1      random mute / solo presses every bar
--      HKEY=1       random hand key / mode changes every ~40 bars

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
function clock.run(f) nid = nid + 1; threads[nid] = coroutine.create(f); return nid end
function clock.cancel(id) threads[id] = nil end
-- sync records its division per thread: the step clock must wait for a bar
-- (sync 4) once, then only ever sync(1/2). STEP_BEATS is the beats it has
-- advanced since, and is what the rules use as time.
local cur_id
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
function clock.sleep() coroutine.yield("sleep") end
function clock.get_beat_sec() return 60 / TEMPO end
function clock.get_tempo() return TEMPO end

-- misc -------------------------------------------------------------------
midi = {vports = {{name = "fake synth"}}, connect = function() return {} end}
poll = {set = function() return {start = function() end} end}
screen = setmetatable({text_extents = function() return 20, 6 end},
  {__index = function() return function() end end})
-- sample folders: a fake tree with a few files, or AUDIO=<dir> for real ones
local AUDIO = os.getenv("AUDIO")
_path = {audio = AUDIO and (AUDIO:gsub("/?$", "/")) or "/fake/audio/", data = "/nonexistent/"}
VT = 0   -- virtual seconds, advanced one 8th per drive tick
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

local R = include("test/rules")
dofile("estuary.lua")
init()
if MINUTES > 0 then params:set("track_minutes", MINUTES) end
params:set("play_mode", PMODE)

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

-- K2+K3 = play
key(2, 1); key(3, 1); key(3, 0); key(2, 0)
assert(S.playing, "K2+K3 didn't start")

-- drive: resume every live thread once per 8th. the step clock waits a bar
-- then ticks; note-off / draw threads come and go.
local function tick_all()
  VT = VT + 60 / TEMPO / 2
  local live = 0
  for id, co in pairs(threads) do
    if coroutine.status(co) == "dead" then threads[id] = nil
    else
      live = live + 1
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
    R.on_bar(S)
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

local keys = {}
for k in pairs(calls) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do print(string.format("  %-12s %d", k, calls[k])) end
print(string.format("notes per slot: %d %d %d %d;  max sounding at once: %d;  8th pairs: %d;  avoid notes: %d",
  notes_by[1], notes_by[2], notes_by[3], notes_by[4], R.stats.max_overlap, R.stats.pairs, R.stats.avoid))
print(string.format("swells: %d  moments: %d", LOADS[2] or 0, LOADS[3] or 0))

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
if notes_by[1] + notes_by[2] + notes_by[3] + notes_by[4] == 0 then extra[#extra + 1] = "no notes played" end
local ok, fails = R.report()
for _, f in ipairs(extra) do fails[#fails + 1] = f; ok = false end
if ok then
  print("RULES ok")
else
  print("RULES FAILED")
  for _, f in ipairs(fails) do print("  " .. f) end
  os.exit(1)
end
