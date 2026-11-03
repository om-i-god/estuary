-- nature: sample folders, water swell envelope, passing moments
local N = {}

-- state (declared before any function that uses it)
local ROOT = "estuary/"
local EXTS = {wav = true, aif = true, aiff = true, flac = true}
local found = {water = {}, birds = {}, wind = {}, room = {}}
local env = {n = 0, rise = 0, hold = 0, fall = 0}
local moment_left = 0
local mid_fired = false

N.state = "idle"
N.level = 0
N.moment_active = false

local function pick(t) return t[math.random(#t)] end
local function lv(S, k) return (S and S[k]) or 1 end
local function bar_sec(S) return (S and S.bar_sec) or (60 / 72 * 4) end

function N.scan()
  found = {}
  for _, k in ipairs({"water", "birds", "wind", "room"}) do
    local dir = _path.audio .. ROOT .. k .. "/"
    local names = (util and util.scandir and util.scandir(dir)) or {}
    local out = {}
    for _, n in ipairs(names) do
      n = tostring(n)
      -- dotfiles are never sound: a Mac copy leaves "._foo.wav" resource
      -- forks beside every file, and ".DS_Store"
      local ext = n:match("%.(%w+)$")
      if n:sub(1, 1) ~= "." and ext and EXTS[ext:lower()] then out[#out + 1] = dir .. n end
    end
    table.sort(out)
    found[k] = out
  end
  return found
end

function N.start_bed(S)
  if #found.wind == 0 and #found.room == 0 and #found.water == 0 then N.scan() end
  local src = #found.room > 0 and found.room or (#found.wind > 0 and found.wind or nil)
  if not src then return false end
  engine.nature_load(1, pick(src))
  engine.nature_play(1, 0.6 * lv(S, "bed_level"), 8)
  return true
end

function N.swell(S)
  if N.state ~= "idle" then return false, "swell running" end
  if moment_left > 0 then return false, "moment running" end
  if #found.water == 0 then N.scan() end
  if #found.water == 0 then return false, "no water" end
  env.n = 0
  env.rise = math.random(8, 16)
  env.hold = math.random(4, 8)
  env.fall = math.random(8, 16)
  mid_fired = false
  N.state = "rising"
  N.level = 0
  engine.nature_load(2, pick(found.water))
  engine.nature_play(2, lv(S, "swell_level"), env.rise * bar_sec(S))
  return true
end

function N.moment(S)
  if N.state ~= "idle" or moment_left > 0 then return false end
  local src = {}
  for _, t in ipairs({found.birds, found.wind}) do
    for _, p in ipairs(t) do src[#src + 1] = p end
  end
  if #src == 0 then N.scan(); for _, t in ipairs({found.birds, found.wind}) do
    for _, p in ipairs(t) do src[#src + 1] = p end end end
  if #src == 0 then return false end
  engine.nature_load(3, pick(src))
  engine.nature_play(3, lv(S, "moment_level"), 0.5)
  moment_left = 4
  N.moment_active = true
  return true
end

-- everything quiet now (transport stop): bed, water and any moment
function N.stop()
  engine.nature_play(1, 0, 3)
  engine.nature_play(2, 0, 2)
  engine.nature_play(3, 0, 1)
  N.state, N.level = "idle", 0
  moment_left, N.moment_active = 0, false
end

function N.bar(S)
  if moment_left > 0 then
    moment_left = moment_left - 1
    -- a moment is small: it fades out over its last bar, whatever the
    -- clip's length, so it is gone before a swell may start
    if moment_left == 1 then engine.nature_play(3, 0, bar_sec(S)) end
    if moment_left == 0 then N.moment_active = false end
  end
  if N.state == "idle" then return end
  env.n = env.n + 1
  if N.state == "rising" then
    N.level = math.min(1, env.n / env.rise)
    if env.n >= env.rise then N.state = "held"; env.n = 0; N.level = 1 end
  elseif N.state == "held" then
    if env.n >= env.hold then
      N.state = "falling"; env.n = 0
      engine.nature_play(2, 0, env.fall * bar_sec(S))
    end
  elseif N.state == "falling" then
    N.level = math.max(0, 1 - env.n / env.fall)
    if not mid_fired and env.n >= env.fall // 2 then
      mid_fired = true
      if S then S.swell_change = true end
    end
    if env.n >= env.fall then N.state = "idle"; N.level = 0 end
  end
end

return N
