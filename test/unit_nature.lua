local calls
local files
local function setup(f)
  files = f or {}
  calls = {}
  _path = {audio = "/audio/"}
  util = {scandir = function(d) return files[d] end}
  engine = {
    nature_load = function(s, p) calls[#calls+1] = {"load", s, p} end,
    nature_play = function(s, l, f) calls[#calls+1] = {"play", s, l, f} end,
  }
  math.randomseed(7)
  return include("lib/nature"), {bar_sec = 3.3}
end
local function plays(slot)
  local n = 0
  for _, c in ipairs(calls) do if c[1] == "play" and c[2] == slot then n = n + 1 end end
  return n
end
local ALL = {
  ["/audio/estuary/water/"] = {"a.wav", "b.txt", "c.flac"},
  ["/audio/estuary/birds/"] = {"x.aif"},
  ["/audio/estuary/wind/"] = {"w.wav"},
  ["/audio/estuary/room/"] = {"r.wav"},
}

test("nature missing folders", function()
  local N, S = setup({})
  local r = N.scan()
  for _, k in ipairs({"water", "birds", "wind", "room"}) do assert(#r[k] == 0, k) end
  local ok, msg = N.swell(S)
  assert(ok == false and msg == "no water", tostring(msg))
  assert(N.moment(S) == false)
  N.start_bed()
  for _ = 1, 500 do N.bar(S) end
  assert(plays(2) == 0, "swell played")
  assert(N.state == "idle")
end)

test("nature scan filters extensions", function()
  local N = setup(ALL)
  local r = N.scan()
  assert(#r.water == 2 and r.water[1] == "/audio/estuary/water/a.wav")
end)

test("nature envelope", function()
  local N, S = setup(ALL)
  local ok = N.swell(S)
  assert(ok == true)
  assert(select(2, N.swell(S)) == "swell running")
  local order, last, bars, changes = {N.state}, N.state, 0, 0
  while N.state ~= "idle" do
    N.bar(S); bars = bars + 1
    if S.swell_change then changes = changes + 1; S.swell_change = nil end
    if N.state ~= last then order[#order+1] = N.state; last = N.state end
    assert(N.level >= 0 and N.level <= 1)
    assert(bars < 100)
  end
  assert(table.concat(order, ",") == "rising,held,falling,idle", table.concat(order, ","))
  assert(bars >= 20 and bars <= 40, "bars " .. bars)
  assert(changes == 1, "changes " .. changes)
  assert(N.level == 0)
end)

test("nature no overlap", function()
  local N, S = setup(ALL)
  for _ = 1, 2000 do
    local r = math.random()
    if r < 0.1 then N.moment(S) elseif r < 0.15 then N.swell(S) end
    N.bar(S)
    assert(not (N.moment_active and N.state ~= "idle"), "overlap")
  end
end)

test("nature moment lasts 4 bars", function()
  local N, S = setup(ALL)
  assert(N.moment(S) == true and N.moment_active)
  assert(N.moment(S) == false)
  for _ = 1, 3 do N.bar(S) end
  assert(N.moment_active)
  N.bar(S)
  assert(not N.moment_active)
end)
