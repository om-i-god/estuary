local T = include("lib/theory")

test("modes are the six bright ones", function()
  local want = {"ionian","lydian","mixolydian","major pentatonic","yoshimura","dorian"}
  assert(#T.MODES == 6, "count " .. #T.MODES)
  for i, n in ipairs(want) do assert(T.MODES[i].name == n, "mode " .. i) end
end)

test("no rubs anywhere", function()
  for m = 1, #T.MODES do
    for d = 1, 7 do
      local q = T.quality(m, d)
      if q ~= "dim" and q ~= "aug" then
        for v = 1, #T.VOICINGS do
          for base = 48, 59 do
            local c = T.chord(base, m, d, v)
            assert(#c == 4, "size")
            assert(not T.has_rub(c), ("rub m%d d%d v%d b%d: %s"):format(m, d, v, base, table.concat(c, ",")))
            for _, n in ipairs(c) do assert(n <= base + 31, "too high") end
          end
        end
      end
    end
  end
end)

test("maj7 spread", function()
  local c = T.chord(48, 1, 1, 1)
  for i = 1, 3 do
    local g = c[i+1] - c[i]
    assert(g ~= 1 and g ~= 11, "gap " .. g)
  end
end)

test("quality", function()
  assert(T.quality(1,7) == "dim")
  assert(T.quality(2,4) == "dim")
  assert(T.quality(1,6) == "min")
  assert(T.quality(6,4) == "maj")
end)

test("tables", function()
  assert(#T.VOICINGS == 7 and T.VOICINGS[7].name == "rootless9")
  assert(T.MODES[5].passing[1] == 5 and T.MODES[4].melody[5] == 9)
  assert(T.root_for(9, 2) == (9 + 8) % 12 and T.minor_of(T.root_for(9, 2), 2) == 9)
  assert(T.name(0, 1, true) == "C ion" or T.name(0, 1, true):sub(1,2) == "C ")
end)
