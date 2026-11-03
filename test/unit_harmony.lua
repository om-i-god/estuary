local T = include("lib/theory")
local H = include("lib/harmony")

local function warm(v)
  for _, w in ipairs(T.WARM_MINOR) do if w == v then return true end end
  return false
end

local function fresh(seed, mode)
  math.randomseed(seed)
  local S = {root_pc = seed % 12, mode = mode, harmony = 3, voicing = H.AUTO,
             bloom = 0, section = "arrival"}
  H.new_prog(S)
  H.retarget(S, true)
  return S
end

local function bright(S, ctx)
  local q = T.quality(S.mode, S.chord_degree)
  assert(q == "maj" or q == "min", ctx .. " quality " .. q)
  assert(S.chord_voicing, ctx .. " no voicing")
  if q == "min" then
    assert(warm(S.chord_voicing), ctx .. " cold minor voicing " .. S.chord_voicing)
  end
  assert(#S.chord == 4, ctx .. " size")
  assert(not T.has_rub(S.chord), ctx .. " rub " .. table.concat(S.chord, ","))
end

-- 400 bars, bloom 0 -> 1 -> 0, calling the hooks like the main script
local function run(seed, mode, each)
  local S = fresh(seed, mode)
  local secs = {"arrival", "bloom", "tide", "return", "settling"}
  for bar = 1, 400 do
    S.bloom = 1 - math.abs((bar - 200) / 200)
    S.section = secs[(bar // 80) % 5 + 1]
    if bar % 16 == 1 then
      H.phrase(S)
      if (bar // 16) % 5 == 4 then H.next_prog(S) end
    end
    H.bar(S, (bar - 1) % 8 + 1)
    each(S, bar)
  end
  return S
end

test("chords stay bright", function()
  for seed = 1, 200 do
    for mode = 1, #T.MODES do
      run(seed, mode, function(S, bar)
        bright(S, ("s%d m%d b%d"):format(seed, mode, bar))
      end)
    end
  end
end)

test("slow", function()
  for seed = 1, 200 do
    for mode = 1, #T.MODES do
      local runs, cur, n = {}, nil, 0
      run(seed, mode, function(S)
        if S.chord_degree == cur then n = n + 1
        else
          if cur then runs[#runs + 1] = n end
          cur, n = S.chord_degree, 1
        end
      end)
      for _, r in ipairs(runs) do
        assert(r >= 8, ("s%d m%d run of %d bars"):format(seed, mode, r))
      end
    end
  end
end)

test("iv is rare", function()
  local seen = 0
  for seed = 1, 200 do
    for mode = 1, #T.MODES do
      local count, prev = 0, false
      local S = run(seed, mode, function(S)
        local b = S.chord_borrowed and true or false
        if b and not prev then count = count + 1 end
        prev = b
      end)
      seen = seen + count
      local cap = math.ceil(S.h.loops / 4)
      assert(count <= cap, ("s%d m%d iv %d > %d (loops %d)"):format(seed, mode, count, cap, S.h.loops))
    end
  end
  assert(seen > 0, "iv never appears")
end)

test("hand key/mode change", function()
  for seed = 1, 200 do
    for mode = 1, #T.MODES do
      local S = fresh(seed, mode)
      S.bloom = (seed % 10) / 10
      for bar = 1, 20 + seed % 30 do H.bar(S, (bar - 1) % 8 + 1) end
      S.mode, S.root_pc = (mode % 6) + 1, 7
      if seed % 2 == 0 then S.mode = 2 end
      H.retarget(S)
      bright(S, ("s%d m%d retarget"):format(seed, mode))
      for bar = 1, 64 do
        H.bar(S, (bar - 1) % 8 + 1)
        bright(S, ("s%d m%d after-change b%d"):format(seed, mode, bar))
      end
    end
  end
end)

test("pedal and publish", function()
  local S = fresh(3, 1)
  S.section = "arrival"; H.bar(S, 1)
  assert(S.pedal_pc == 0, "tonic pedal in arrival")
  S.section = "bloom"; H.bar(S, 2)
  assert(S.pedal_pc == S.chord_root_pc, "root pedal in bloom")
  assert(S.chord_label and S.chord_root_pc and S.chord_degree)
end)
