-- palettes: the per-track choice, pinning, and the param -> engine index maps
local P = include("lib/palettes")

-- the engine's lists, read from the .sc (the `note` voice arg and the
-- `pad_sound` tweak index are positions in these)
local function engine_list(name)
  local f = assert(io.open("lib/Engine_Estuary.sc"))
  local src = f:read("a")
  f:close()
  local body = assert(src:match(name .. " = %[(.-)%];"), "no " .. name .. " in the engine")
  local t = {}
  for d in body:gmatch("\\([%w_]+)") do t[#t + 1] = d end
  return t
end

local function eq(a, b, what)
  assert(a == b, (what or "") .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end

test("palettes: engine voice list matches VOICES, in order", function()
  local defs = engine_list("voiceDefs")
  eq(#defs, #P.VOICES, "voice count")
  for i, v in ipairs(P.VOICES) do eq(defs[i], "est_" .. v, "voice " .. i) end
  assert(#P.VOICES >= 8, "at least 8 voices")
end)

test("palettes: engine pad list matches PADS, in order", function()
  local defs = engine_list("padDefs")
  eq(#defs, #P.PADS, "pad count")
  for i, v in ipairs(P.PADS) do eq(defs[i], "est_pad_" .. v, "pad " .. i) end
  assert(#P.PADS >= 4, "at least 4 pads")
end)

test("palettes: old psets keep their voices (option order only grows)", function()
  -- v0.1 stored motifN_voice as an index into {auto, rhodes, bell, sine, marimba}
  local old = {"auto", "rhodes", "bell", "sine", "marimba"}
  local now = {"auto", table.unpack(P.VOICES)}
  for i, n in ipairs(old) do eq(now[i], n, "option " .. i) end
  local defs = engine_list("voiceDefs")
  for i = 2, 5 do
    local idx = P.motif_voice(i, 1, 1)
    eq(idx, i - 1, "engine index for option " .. i)
    eq(defs[idx], "est_" .. old[i], "engine def for option " .. i)
  end
  -- the script builds its option list from VOICES with auto first
  local f = assert(io.open("estuary.lua"))
  local src = f:read("a")
  f:close()
  assert(src:find('VOICE_NAMES%s*=%s*{"auto", table.unpack%(PAL.VOICES%)}'), "estuary.lua VOICE_NAMES not built from PAL.VOICES")
  assert(src:find('PAD_NAMES%s*=%s*{"auto", table.unpack%(PAL.PADS%)}'), "estuary.lua PAD_NAMES not built from PAL.PADS")
end)

test("palettes: every palette is well formed", function()
  assert(#P.PALETTES >= 16 and #P.PALETTES <= 26, "16-26 palettes")
  local names, used_v, used_p = {}, {}, {}
  for i, p in ipairs(P.PALETTES) do
    assert(not names[p.name], "duplicate palette " .. p.name)
    names[p.name] = true
    eq(P.NAMES[i], p.name, "NAMES")
    eq(#p.voices, 4, p.name .. " voices")
    for _, v in ipairs(p.voices) do used_v[v] = true; P.voice_index(v) end
    used_p[p.pad] = true
    P.pad_index(p.pad)
    assert(math.abs(p.bright) <= 0.15, p.name .. " bright tilt too big")
    assert(p.send >= 0.8 and p.send <= 1.25, p.name .. " send tilt too big")
  end
  for _, v in ipairs(P.VOICES) do assert(used_v[v], "no palette uses voice " .. v) end
  for _, v in ipairs(P.PADS) do assert(used_p[v], "no palette uses pad " .. v) end
end)

test("palettes: auto voice follows the palette's slot, a named one wins", function()
  for pi, p in ipairs(P.PALETTES) do
    for slot = 1, 4 do
      eq(P.motif_voice(1, pi, slot), P.voice_index(p.voices[slot]), p.name .. " slot " .. slot)
      eq(P.motif_voice(1 + 7, pi, slot), 7, "named voice")
    end
    eq(P.pad_sound(1, pi), P.pad_index(p.pad), p.name .. " pad")
    eq(P.pad_sound(3, pi), 2, "named pad")
  end
  -- no palette yet: the first one, never an error
  eq(P.motif_voice(1, nil, 2), P.voice_index(P.PALETTES[1].voices[2]), "nil palette")
  eq(P.pad_sound(1, nil), P.pad_index(P.PALETTES[1].pad), "nil palette pad")
end)

test("palettes: choice is seeded and leaves math.random alone", function()
  for seed = 1, 200 do
    eq(P.for_track({}, seed), P.for_track({}, seed), "same seed")
    eq(P.for_track({palette = 3}, seed), P.for_track({palette = 3}, seed), "same seed + last")
  end
  math.randomseed(42)
  local a = {math.random(), math.random()}
  math.randomseed(42)
  P.for_track({}, 99)
  local b = {math.random(), math.random()}
  eq(a[1], b[1], "random stream"); eq(a[2], b[2], "random stream")
end)

test("palettes: a new track never repeats the last palette, and all appear", function()
  local S, seen, prev = {}, {}, nil
  for k = 1, 3000 do
    local seed = ((k * 7919) % 9999) + 1
    local pal = P.for_track(S, seed)
    assert(pal >= 1 and pal <= #P.PALETTES, "range")
    if prev and seed ~= S.prev_seed then assert(pal ~= prev, "repeat at track " .. k) end
    S.prev_seed = seed
    seen[pal] = (seen[pal] or 0) + 1
    prev = pal
  end
  for i = 1, #P.PALETTES do
    assert((seen[i] or 0) > 3000 / #P.PALETTES / 3, "palette " .. i .. " rarely chosen: " .. tostring(seen[i]))
  end
  -- even the worst case: every seed, from every last palette
  for seed = 1, 9999, 13 do
    for last = 1, #P.PALETTES do assert(P.for_track({palette = last}, seed) ~= last, "repeated the last palette") end
  end
end)

test("palettes: rebuilding the same seed keeps the palette", function()
  local S = {}
  local a = P.for_track(S, 500)
  eq(P.for_track(S, 500), a, "rebuild")
  assert(P.for_track(S, 501) ~= a, "a new seed moves on")
end)

test("palettes: a pinned palette is honoured on every new track", function()
  local S = {palette_pin = 4}
  for seed = 1, 300 do eq(P.for_track(S, seed), 4, "pinned") end
  -- back to auto: the next new track picks again, not the pinned one
  S.palette_pin = 0
  assert(P.for_track(S, 301) ~= 4, "auto after a pin repeated it")
end)

test("palettes: back to auto after a pin, a rebuild picks afresh", function()
  local S = {}
  P.pin(S, 1 + 4)                  -- pin palette 4
  eq(P.for_track(S, 500), 4, "pinned")
  eq(P.for_track(S, 500), 4, "pinned rebuild")
  P.pin(S, 1)                      -- auto
  assert(P.for_track(S, 500) ~= 4, "rebuild after unpinning kept the pinned palette")
  local a = S.palette
  eq(P.for_track(S, 500), a, "a later rebuild keeps the auto pick")
  -- pinning applies at once
  P.pin(S, 1 + 2)
  eq(S.palette, 2, "pin is immediate")
end)

test("palettes: the conductor picks one per new track", function()
  _path = {audio = "/audio/"}
  util = {scandir = function() return {} end}
  engine = setmetatable({}, {__index = function() return function() end end})
  local C = include("lib/conductor")
  local S = {root_pc = 0, mode = 1, harmony = 3, voicing = 7, bloom = 0, mode_play = 1,
             phrase_len = 16, tempo = 72, track_minutes = 12, moment_freq = 2, end_action = 2,
             gain = {}, muted = {}, soloed = {}}
  C.new_track(S, 11, false)
  local first = S.palette
  assert(first, "no palette")
  C.new_track(S, 12, false)
  assert(S.palette ~= first, "same palette twice")
  S.palette_pin = 2
  C.new_track(S, 13, false)
  eq(S.palette, 2, "pinned")
end)

test("palettes: v2 psets keep their voices, pads and palettes (lists only grow)", function()
  -- sounds v2 stored these option indices; v3 appends after them
  local v2_voices = {"auto", "rhodes", "bell", "sine", "marimba", "vibes", "celesta", "kalimba", "flute", "glass"}
  local v2_pads = {"auto", "warm", "strings", "glass", "air", "organ"}
  local v2_pals = {"auto", "harbor", "shallows", "glasshouse", "morning", "riverbank", "tidepool", "veranda", "mist", "atrium"}
  local nv = {"auto", table.unpack(P.VOICES)}
  local np = {"auto", table.unpack(P.PADS)}
  local nl = {"auto", table.unpack(P.NAMES)}
  for i, n in ipairs(v2_voices) do eq(nv[i], n, "voice option " .. i) end
  for i, n in ipairs(v2_pads) do eq(np[i], n, "pad option " .. i) end
  for i, n in ipairs(v2_pals) do eq(nl[i], n, "palette option " .. i) end
  local defs, pdefs = engine_list("voiceDefs"), engine_list("padDefs")
  for i = 2, #v2_voices do eq(defs[P.motif_voice(i, 1, 1)], "est_" .. v2_voices[i], "engine voice for option " .. i) end
  for i = 2, #v2_pads do eq(pdefs[P.pad_sound(i, 1)], "est_pad_" .. v2_pads[i], "engine pad for option " .. i) end
  -- a pinned v2 palette is still the same record
  local S = {}
  P.pin(S, 1 + 3)
  eq(P.NAMES[P.for_track(S, 77)], "glasshouse", "pinned v2 palette")
end)

test("palettes: v3 adds the new voices, pads and palettes, none named like a visual theme", function()
  for _, v in ipairs({"harp", "koto", "choir", "glock", "piano", "dulcimer", "steelpan", "guitar", "horn"}) do P.voice_index(v) end
  for _, v in ipairs({"shimmer", "tape", "reed"}) do P.pad_index(v) end
  assert(#P.VOICES >= 18, "at least 18 voices")
  local themes = {"ripples", "horizon", "postcards", "rain", "tide", "drift", "reeds", "koi", "kelp", "fireflies",
                  "mist", "flock", "brook", "rockpool", "dew", "cascade", "mangrove", "aurora", "shoal", "paddies"}
  local clash = {}
  for _, t in ipairs(themes) do clash[t] = true end
  for i = 10, #P.PALETTES do
    assert(not clash[P.PALETTES[i].name], "palette " .. P.PALETTES[i].name .. " is a visual theme's name")
  end
  -- every new voice is in at least four palettes, so a run of tracks hears it
  local count = {}
  for _, p in ipairs(P.PALETTES) do for _, v in ipairs(p.voices) do count[v] = (count[v] or 0) + 1 end end
  for i = 10, #P.VOICES do assert((count[P.VOICES[i]] or 0) >= 4, P.VOICES[i] .. " in fewer than 4 palettes") end
end)

test("palettes: every palette comes round once a round (three full rounds), every voice soon", function()
  local n = #P.PALETTES
  for start = 1, 40 do
    local S, prev = {}, nil
    for round = 1, 3 do
      local seen, voices = {}, {}
      for k = 1, n do
        local pal = P.for_track(S, start * 1000 + round * 100 + k)
        assert(not seen[pal], "palette " .. pal .. " twice in round " .. round .. " (start " .. start .. ")")
        assert(pal ~= prev, "back to back across round " .. round)
        seen[pal], prev = true, pal
        for _, v in ipairs(P.PALETTES[pal].voices) do voices[v] = true end
        if k == 10 and round == 1 then
          for _, v in ipairs(P.VOICES) do assert(voices[v], v .. " not heard in 10 tracks (start " .. start .. ")") end
        end
      end
      for i = 1, n do assert(seen[i], "palette " .. i .. " skipped in round " .. round .. " (start " .. start .. ")") end
    end
  end
end)

test("palettes: the same history and seeds give the same palettes", function()
  local a, b = {}, {}
  for k = 1, 50 do eq(P.for_track(a, k * 31), P.for_track(b, k * 31), "track " .. k) end
end)

test("palettes: react params map to the engine (depth clamped, source 1-4)", function()
  eq(P.react(0), 0, "react 0"); eq(P.react(0.5), 0.5, "react 0.5"); eq(P.react(1), 1, "react 1")
  eq(P.react(-1), 0, "react low"); eq(P.react(3), 1, "react high"); eq(P.react(nil), 0, "react nil")
  eq(#P.REACT_SOURCES, 4, "four sources")
  local want = {water = 1, room = 2, self = 3, all = 4}
  for i, n in ipairs(P.REACT_SOURCES) do eq(P.react_src(i), want[n], n) end
  eq(P.react_src(0), 1, "src low"); eq(P.react_src(9), 4, "src high"); eq(P.react_src(nil), 4, "src nil = all")
  -- the engine knows the tweak keys, and the script sends them
  local f = assert(io.open("lib/Engine_Estuary.sc"))
  local src = f:read("a")
  f:close()
  assert(src:find("\\react %-> %[\\react, \\react%]"), "engine: no react tweak")
  assert(src:find("\\react_src %-> %[\\react, \\src%]"), "engine: no react_src tweak")
  f = assert(io.open("estuary.lua"))
  local es = f:read("a")
  f:close()
  assert(es:find('params:add_control%("react", "react", controlspec.new%(0, 1, "lin", 0.01, 0.5%)%)'), "react param")
  assert(es:find('params:add_option%("react_src", "react source", PAL.REACT_SOURCES, #PAL.REACT_SOURCES%)'), "react source param")
  assert(es:find('tweak%("react", PAL.react%(v%)%)') and es:find('tweak%("react_src", PAL.react_src%(v%)%)'), "react tweaks")
end)

test("palettes: v4 adds ocarina, bowl, musicbox, chime, hum, bowed and six palettes after v3's", function()
  -- v3 psets: every voice, pad and palette option keeps its index
  local v3_voices = {"rhodes", "bell", "sine", "marimba", "vibes", "celesta", "kalimba", "flute", "glass",
                     "harp", "koto", "choir", "glock", "piano", "dulcimer", "steelpan", "guitar", "horn"}
  local v3_pads = {"warm", "strings", "glass", "air", "organ", "shimmer", "tape", "reed"}
  local v3_pals = {"harbor", "shallows", "glasshouse", "morning", "riverbank", "tidepool", "veranda", "mist", "atrium",
                   "lantern", "teahouse", "chapel", "orchard", "parlour", "lagoon", "boathouse", "sandbar", "promenade",
                   "cloister", "courtyard"}
  for i, n in ipairs(v3_voices) do eq(P.VOICES[i], n, "voice " .. i) end
  for i, n in ipairs(v3_pads) do eq(P.PADS[i], n, "pad " .. i) end
  for i, n in ipairs(v3_pals) do eq(P.NAMES[i], n, "palette " .. i) end
  local new_v = {"ocarina", "bowl", "musicbox", "chime"}
  for k, n in ipairs(new_v) do eq(P.VOICES[18 + k], n, "new voice " .. k) end
  eq(P.PADS[9], "hum", "pad 9"); eq(P.PADS[10], "bowed", "pad 10")
  eq(#P.VOICES, 22, "22 voices"); eq(#P.PADS, 10, "10 pads"); eq(#P.PALETTES, 26, "26 palettes")
  local new_p = {"pavilion", "conservatory", "observatory", "arboretum", "aquarium", "gallery"}
  for k, n in ipairs(new_p) do eq(P.NAMES[20 + k], n, "new palette " .. k) end
  -- no palette added since v3 is named like a place (all twenty-eight)
  local places = {"ripples", "horizon", "postcards", "rain", "tide", "drift", "reeds", "koi", "kelp", "fireflies",
                  "mist", "flock", "brook", "rockpool", "dew", "cascade", "mangrove", "aurora", "shoal", "paddies",
                  "echo bridge", "echo_bridge", "confluence", "delta", "onsen", "lotus", "glacier", "pod", "wellspring"}
  for _, t in ipairs(places) do
    for i = 10, #P.PALETTES do assert(P.NAMES[i] ~= t, "palette " .. t .. " is a place's name") end
  end
  -- each new voice in at least four palettes, each new pad in at least one
  local vc, pc = {}, {}
  for _, p in ipairs(P.PALETTES) do
    for _, v in ipairs(p.voices) do vc[v] = (vc[v] or 0) + 1 end
    pc[p.pad] = (pc[p.pad] or 0) + 1
  end
  for _, v in ipairs(new_v) do assert((vc[v] or 0) >= 4, v .. " in fewer than 4 palettes") end
  assert(pc.hum and pc.bowed, "a new pad in no palette")
  -- the param -> engine maps reach the new sounds, and pinning works
  local defs, pdefs = engine_list("voiceDefs"), engine_list("padDefs")
  for k, n in ipairs(new_v) do eq(defs[P.motif_voice(1 + 18 + k, 1, 1)], "est_" .. n, "voice option " .. n) end
  eq(pdefs[P.pad_sound(1 + 9, 1)], "est_pad_hum", "pad option hum")
  eq(pdefs[P.pad_sound(1 + 10, 1)], "est_pad_bowed", "pad option bowed")
  for k = 21, 26 do
    local S = {}
    P.pin(S, 1 + k)
    eq(S.palette, k, "pin " .. k .. " immediate")
    for seed = 1, 20 do eq(P.for_track(S, seed), k, "pinned " .. P.NAMES[k]) end
    for slot = 1, 4 do eq(defs[P.motif_voice(1, k, slot)], "est_" .. P.PALETTES[k].voices[slot], "slot " .. slot) end
    eq(pdefs[P.pad_sound(1, k)], "est_pad_" .. P.PALETTES[k].pad, P.NAMES[k] .. " pad")
  end
end)

test("palettes: adding a release keeps the earlier palettes' run (an old seed's first tracks sound the same)", function()
  -- the draw with only the v3 palettes, against the draw with all of them:
  -- the same palettes, track for track, until the v3 palettes have brought
  -- every v3 voice round (where the old draw began its next sweep)
  local all = P.PALETTES
  local old = {}
  for i = 1, 20 do old[i] = all[i] end
  local v3n = 18
  local checked = 0
  for start = 1, 200 do
    local seeds = {}
    for k = 1, 30 do seeds[k] = start * 7919 + k * 104729 end
    P.PALETTES = old
    local So, oldrun, cover = {}, {}, nil
    local heard = {}
    for k = 1, 30 do
      oldrun[k] = P.for_track(So, seeds[k])
      for _, v in ipairs(old[oldrun[k]].voices) do heard[v] = true end
      local n = 0
      for _ in pairs(heard) do n = n + 1 end
      if not cover and n == v3n then cover = k end
    end
    P.PALETTES = all
    local Sn = {}
    for k = 1, cover do
      eq(P.for_track(Sn, seeds[k]), oldrun[k], "start " .. start .. " track " .. k)
      checked = checked + 1
    end
    -- and the new release follows at once: the next track is one of its palettes
    local nxt = P.for_track(Sn, seeds[cover + 1])
    assert(nxt > 20, "start " .. start .. ": no v4 palette straight after the v3 sweep (got " .. nxt .. ")")
  end
  P.PALETTES = all
  assert(checked > 200 * 4, "too few tracks compared")
end)
