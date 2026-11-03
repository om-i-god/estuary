-- the checker must be able to fail: feed test/rules.lua deliberately bad
-- input and assert each rule trips (and a clean feed does not).
-- run from repo root:  lua test/rules_selftest.lua
function include(p) return dofile(p .. ".lua") end

local function fresh()
  -- rules.lua keeps module state, so load a new copy per case
  local R = dofile("test/rules.lua")
  local ev = {tone = 1, dur = 2}
  local S = {
    chord = {48, 55, 62, 64}, mode = 1, chord_degree = 1, chord_voicing = 2, chord_label = "I",
    gain = {}, muted = {}, track_bar = 1,
    motifs = {{events = {{tone = 1, dur = 2}, {tone = 2, dur = 2}, {tone = 3, dur = 2}, {dur = 8}}, cycle = 14}},
  }
  R.attach(S)
  return R, S, ev
end

local n_fail = 0
local function expect(name, rule, setup)
  local R, S, ev = fresh()
  setup(R, S, ev)
  local ok, fails = R.report()
  local hit = false
  for _, f in ipairs(fails) do if f:sub(1, #rule) == rule then hit = true end end
  if rule == "" then hit = ok end
  print((hit and "ok   " or "FAIL ") .. name)
  if not hit then n_fail = n_fail + 1; for _, f in ipairs(fails) do print("     got: " .. f) end end
end

expect("clean feed passes", "", function(R, S, ev)
  R.on_note(0, 1, 62, 1, ev); R.on_note(1, 1, 64, 1, ev); R.on_bar(S)
end)
expect("fourth slot sounding", "busy", function(R, S, ev)
  for slot = 1, 4 do R.on_note(0, slot, 60 + slot, 4, ev) end
end)
expect("overlap by duration, not onset", "busy", function(R, S, ev)
  R.on_note(0, 1, 62, 4, ev); R.on_note(1, 2, 64, 4, ev); R.on_note(2, 3, 67, 4, ev)
  R.on_note(3, 4, 69, 1, ev)
end)
expect("onsets closer than an 8th", "fast", function(R, S, ev)
  R.on_note(0, 1, 62, 1, ev); R.on_note(0.25, 1, 64, 1, ev)
end)
expect("run of eighths (two adjacent pairs)", "run", function(R, S, ev)
  for i = 0, 3 do R.on_note(i * 0.5, 1, 62 + i, 0.5, ev) end
end)
expect("eighth notes beyond one pair in a motif", "pair", function(R, S, ev)
  S.motifs[1].events = {{tone = 1, dur = 1}, {tone = 2, dur = 1}, {tone = 3, dur = 1}, {tone = 4, dur = 2}, {dur = 4}}
  S.motifs[1].cycle = 14
  R.on_bar(S)
end)
expect("rub in the chord", "rub", function(R, S) S.chord = {48, 55, 62, 63}; R.on_bar(S) end)
expect("rub caught on a note, between bar samples", "rub", function(R, S, ev)
  S.chord = {48, 55, 62, 63}; R.on_note(0, 1, 62, 1, ev)
end)
expect("diminished chord degree", "dark", function(R, S) S.chord_degree = 7; R.on_bar(S) end)
expect("diminished triad in the voiced notes", "dark", function(R, S)
  S.chord = {47, 50, 53, 62}; R.on_bar(S)
end)
expect("borrowed minor in a cold voicing", "cold minor", function(R, S)
  S.chord_borrowed = true; S.chord_voicing = 2; R.on_bar(S)
end)
expect("borrowed minor in a warm voicing is fine", "", function(R, S)
  S.chord_borrowed = true; S.chord_voicing = 1; R.on_bar(S)
end)
expect("long avoid note", "avoid long", function(R, S, ev)
  R.on_note(0, 1, 65, 2, ev)           -- F over E in {C G D E}
end)
expect("avoid note ending a cycle", "avoid last", function(R, S, ev)
  S.motifs[1].events = {{tone = 1, dur = 2}, {tone = 2, dur = 2}, ev, {dur = 8}}
  R.on_note(0, 1, 65, 1, ev)
end)
expect("moment during a swell", "moment+swell", function(R, S)
  S.moment_active = true; S.nature_state = "held"; R.on_bar(S)
end)
expect("moment during a swell, seen on a note", "moment+swell", function(R, S, ev)
  S.moment_active = true; S.nature_state = "rising"; R.on_note(0, 1, 62, 1, ev)
end)
expect("fourth audible motif", "cap", function(R, S)
  for i = 1, 4 do S.gain["motif" .. i] = 1 end
  R.on_bar(S)
end)
expect("muted motif doesn't count", "", function(R, S)
  for i = 1, 4 do S.gain["motif" .. i] = 1 end
  S.muted.motif4 = true
  R.on_bar(S)
end)
expect("motif with no rest", "rests", function(R, S)
  S.motifs[1].events = {{tone = 1, dur = 2}, {tone = 2, dur = 2}, {tone = 3, dur = 2}}
  R.on_bar(S)
end)
expect("motif with too few notes", "notes", function(R, S)
  S.motifs[1].events = {{tone = 1, dur = 2}, {dur = 4}}
  R.on_bar(S)
end)
expect("even-beat cycle", "cycle", function(R, S) S.motifs[1].cycle = 16; R.on_bar(S) end)

print(n_fail == 0 and "SELFTEST ok" or (n_fail .. " SELFTEST FAILURES"))
os.exit(n_fail == 0 and 0 or 1)
