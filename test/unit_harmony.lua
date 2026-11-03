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

-- no tritone, no b9 over the chord's root, every pc from the mode (b3 / b6
-- only on the borrowed iv or while a morph leaves it)
local function clean(S, ctx)
  local pcs = {}
  for _, n in ipairs(S.chord) do pcs[n % 12] = true end
  local allowed = {}
  for _, st in ipairs(T.MODES[S.mode].steps) do allowed[(S.root_pc + st) % 12] = true end
  if S.chord_borrowed or S.chord_borrow_tail then
    allowed[(S.root_pc + 3) % 12], allowed[(S.root_pc + 8) % 12] = true, true
  end
  local notes = table.concat(S.chord, ",")
  for pc in pairs(pcs) do
    assert(not pcs[(pc + 6) % 12], ctx .. " tritone " .. notes)
    assert(allowed[pc], ctx .. " pc " .. pc .. " outside mode " .. notes)
  end
  assert(not pcs[(S.root_pc + S.chord_root_pc + 1) % 12], ctx .. " b9 " .. notes)
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
  clean(S, ctx)
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
      H.retarget(S, true)             -- as the script's rekey(): an instant jump
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

test("every mode, degree and voicing: no tritone, no b9, in the mode", function()
  for mode = 1, #T.MODES do
    for root = 0, 11 do
      for col = 1, #T.VOICINGS do
        -- hand-set voicing through the real path (simple harmony, one chord)
        for deg = 1, 7 do
          local q = T.quality(mode, deg)
          if q == "maj" or q == "min" then
            local S = {root_pc = root, mode = mode, harmony = 1, voicing = col, pair = {deg},
                       harm_bars = 8, bloom = 0.5, section = "bloom"}
            H.new_prog(S)
            H.retarget(S, true)
            assert(S.chord_degree == deg)
            bright(S, ("hand m%d r%d d%d v%d"):format(mode, root, deg, col))
            -- and voice-led from another chord (drifting, instant)
            S.harmony = 3
            H.retarget(S, true)
            bright(S, ("led m%d r%d d%d v%d"):format(mode, root, deg, col))
          end
        end
        -- the borrowed iv, in any colour the auto picker could ask for
        if T.quality(mode, 4) == "maj" then
          local S = {root_pc = root, mode = mode, harmony = 3, voicing = col, bloom = 0.5, section = "bloom"}
          S.h = {prog = {{deg = 4, bars = 8, minor = true, borrowed = true}}, i = 1, queue = {},
                 per_bar = 1, colour = col, held = 0, loops = 1}
          H.retarget(S, true)
          assert(S.chord_borrowed)
          bright(S, ("iv m%d r%d v%d"):format(mode, root, col))
        end
      end
    end
  end
end)

test("iii in ionian is only ever the plain m7", function()
  for col = 1, #T.VOICINGS do
    local S = {root_pc = 0, mode = 1, harmony = 1, voicing = col, pair = {3}, harm_bars = 8, bloom = 0.5}
    H.new_prog(S)
    H.retarget(S, true)
    assert(S.chord_voicing == 1, "voicing " .. S.chord_voicing .. " from " .. col)
  end
  local q = T.chord(48, 1, 1, 5)
  assert(table.concat(q, ",") == "52,57,62,67", "quartal on I " .. table.concat(q, ","))
end)
