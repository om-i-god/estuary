-- glacier: a bright glacier face above a calm meltwater lake on a pale blue
-- day. a thin sky over the ice's broken crest of seracs, the face scored
-- with crevasses, and the lake below holding its reflection. the chord is
-- the ice's blue bands: four strata across the face, higher for a higher
-- tone, glowing as the chord holds them and drifting to their new heights
-- when it moves. a note at its pitch, by motif: an icicle dripping into
-- the lake (the first), a meltwater runnel lighting down the face (the
-- second), the sun glinting off a facet in a small star (the third), a
-- trickle ringing the lake at the face's foot (the fourth). out_mid sets
-- meltwater running down the face, out_amp how fast; out_lo is the lake's
-- slow swell, out_hi glints on the ice and the water, and the water
-- sounds lap and sparkle along the lake's edge. the bloom is the day: the
-- ice brightens and the sky pales; the bar breathes in the face; a swell
-- is a gentle calving, a slab easing off the face and a soft wave rolling
-- across the lake. a passing moment sweeps a band of sunlight up the ice.
-- now and then an iceberg drifts by, a tern hunts over the water, or the
-- sun breaks through cloud onto the ice
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, cos, floor, abs = math.sin, math.cos, math.floor, math.abs

  M.incidents = {{"iceberg", 24}, {"tern", 14}, {"sunbreak", 20}}

  local WL = 38                           -- the lake's surface (the face's foot)
  local MARK_MAX = 8
  local marks
  local melt = 0                          -- the meltwater's run, integrated

  -- the crest of seracs along the top of the face
  local crest = K.profile(function(x)
    return 9 + 2 * sin(x * 0.05 + 1) + 2.5 * K.hash(x // 3, 1601) + 1.5 * math.max(0, sin(x * 0.31)) - 1.5 * math.max(0, sin(x * 0.07 - 2)) ^ 4
  end)
  -- the face's texture: crevasses running down it, a few ledges, baked once
  local face = K.bake(function(rec)
    for k = 1, 18 do
      local x = floor(2 + 124 * K.hash(k, 1602))
      local y0 = floor(K.at(crest, x) + 1 + 4 * K.hash(k, 1603))
      local len = 5 + floor(16 * K.hash(k, 1604))
      local lean = K.hash(k, 1605) < 0.5 and -1 or 1
      -- (a crevasse: a slanting crack, its lip lit, fading as it runs)
      for j = 0, len - 1, 2 do
        if y0 + j < WL - 1 then rec((2.2 + 0.6 * K.hash(k * 32 + j, 1606)) * (1 - j / (len * 1.6)), x + floor(j * 0.35) * lean, y0 + j, 1, 2) end
      end
    end
    -- a few blocks standing proud of the face, lit on top
    for k = 1, 9 do
      local x, y = floor(128 * K.hash(k, 1607)), 13 + floor(18 * K.hash(k, 1608))
      local w = 3 + floor(5 * K.hash(k, 1609))
      rec(2.8, x, y, w, 1); rec(1.6, x, y + 1, 1, 2); rec(1.4, x + w - 1, y + 1, 1, 2)
    end
    -- the seracs' lit tops
    for c = 0, 63 do rec(3.4 + 0.8 * K.hash(c, 1610), c * 2, floor(crest[c] + 0.5), 2, 1) end
  end)
  -- the far mountains' snowy line behind the crest
  local far = K.profile(function(x) return 5 + 2.5 * sin(x * 0.04 + 2) + 1.5 * sin(x * 0.13) end)
  local ICE = K.scatter(80, 4, 12, 124, WL - 3, 1611)
  -- the runs of each row that lie under the crest
  local FACE_RUNS = {}
  for y = 6, WL - 1 do
    local r, run = {}, nil
    for c = 0, 64 do
      if c < 64 and y > crest[c] + 0.5 then run = run or c * 2
      elseif run then r[#r + 1], r[#r + 2] = run, c * 2; run = nil end
    end
    FACE_RUNS[y] = r
  end

  function M.init() marks, melt = {}, 0 end
  function M.clear() marks = {} end

  function M.note(slot, midi)
    K.cap_add(marks, {slot = slot, x = K.px(midi), u = K.pu(midi), t0 = K.T}, MARK_MAX)
  end

  local function sample(u, v)
    if v < 0.4 then return 4 + u * 120, 14 + v * 50 end
    return 4 + u * 120, WL + 2 + (v - 0.4) * 40
  end

  -- the light on the ice (its strength set each frame): brighter higher up
  local F_ice, F_sky = 1, 1
  local function ice(y) return F_ice * (0.17 - 0.07 * (y - 10) / (WL - 10)) end
  local function sky(y) return F_sky * (0.05 + 0.016 * y) end

  function M.draw()
    local T = K.T
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local hi, mid, nat, lo, amp = A[K.HI], A[K.MID], A[K.NAT], A[K.LO], A[K.AMP]
    melt = melt + K.DTS * (4 + 10 * amp)
    local inc = K.inc
    local sun = 0
    local sun_x = -99
    if inc and inc.name == "sunbreak" then sun, sun_x = inc.e, -20 + inc.u * 170 end
    -- the pale sky and the far mountains' snow behind the crest
    F_sky = 0.6 + 0.6 * bloom + 0.4 * breath
    K.gradient(0, 14, sky, crest)
    for c = 0, 63 do
      local t = floor(far[c] + 0.5)
      if t < crest[c] - 1 then put(1.8 + 0.8 * bloom + K.bj(c) * 0.3, c * 2, t, 2, 1) end
    end
    -- the face: a soft light over the ice, brighter with the day and the bar
    F_ice = 0.9 + 0.35 * bloom + 0.8 * breath + 0.8 * sun
    -- (only under the seracs: each row's runs below the crest, worked
    -- out once)
    for y = 6, WL - 1 do
      local r = FACE_RUNS[y]
      for q = 1, #r, 2 do K.dither_row(ice(y), y, nil, r[q], r[q + 1]) end
    end
    K.blit(face, 1 + 0.3 * bloom + 0.3 * breath)
    -- the chord: the ice's blue bands
    local ma = K.moment_age
    local sweep = ma < 14 and ease(ma / 2) * (1 - ease((ma - 9) / 5)) or 0
    local sy = WL - ma * 3.2
    for i = 1, 4 do
      local m, p = K.chord_at(i)
      if m and p > 0.02 then
        local y0 = WL - 4 - clamp((m - 36) / 40, 0, 1) * 20
        local l = (3.4 + 2.8 * K.chord_glow + 1.2 * breath) * p
        -- (a soft blue stratum round the band's bright seam)
        for dy = -1, 1 do
          local yy = floor(y0 + 0.5) + dy
          local r = FACE_RUNS[yy]
          if r then
            for q = 1, #r, 2 do K.dither_row(p * (0.5 + 0.25 * K.chord_glow) * (1 - abs(dy) / 2.5), yy, nil, r[q], r[q + 1]) end
          end
        end
        for x = 0, 126, 5 do
          local y = y0 + 1.5 * sin(x * 0.04 + i * 1.3) + (x - 64) * 0.03 * (i % 2 == 0 and 1 or -1)
          if y > K.at(crest, x) + 1 then
            -- (shared between rows: a band gliding to its new height slides)
            local yi = floor(y)
            K.vshare(l + K.bj(x * 3 + i * 40) * 0.95, x, yi, 4, y - yi)
          end
        end
      end
    end
    -- the moment: a band of sunlight sweeping up the face
    if sweep > 0 then
      for y = 10, WL - 1 do
        local d = abs(y - sy) / 3
        if d < 1 then
          local r = FACE_RUNS[y]
          if r then
            for q = 1, #r, 2 do K.dither_row(sweep * 0.5 * (1 - d * d), y, nil, r[q], r[q + 1]) end
          end
          -- (the ice it crosses glitters)
          for q = 0, 9 do
            local gx = (q * 13 + y * 7) % 128
            local w = sin(ma * 5 + q * 1.7 + y)
            if w > 0 then put(sweep * 13 * w * (1 - d * 0.7), gx, y, 3, 1) end
          end
        end
      end
    end
    -- the sun breaking through cloud onto the ice (incident)
    if sun > 0.01 then
      for y = 10, WL - 1, 1 do
        local hw = 26 + 4 * sin(y * 0.5)
        K.dither_row(sun * 1.6, y, nil, math.max(0, floor(sun_x - hw)), math.min(128, floor(sun_x + hw)))
      end
    end
    -- out_mid: meltwater running down the face
    if mid > 0.02 then
      local n = 3 + mid * 7
      for k = 1, math.min(10, floor(n) + 1) do
        local f = clamp(n - k + 1, 0, 1)
        local x = 6 + ((k * 37) % 116)
        local top = K.at(crest, x) + 3
        local ph = (melt * (0.6 + 0.08 * k) / (WL - top) + k * 0.27) % 1
        local y = top + ph * (WL - top - 2)
        -- (eased by its phase: it gathers at the top and fades at the foot,
        -- never jumping back up)
        local pe = sin(math.pi * ph) ^ 0.5
        put(mid * f * (5.5 + 4 * sin(math.pi * ph)) * pe, x, y, 2, 3)
        put(mid * f * 2 * pe, x, math.max(top, y - 7), 1, math.min(7, y - top))
      end
    end
    K.twinkle(ICE, hi, 13)
    -- a swell: a slab eases off the face, mist where it meets the water
    if sw > 0.02 then
      local slab = 64
      for q = 0, 5 do
        local y = 22 + q * 2 + sw * 12
        if y < WL then put(sw * 5, slab - 6 + q, y, 10, 2) end
      end
      for q = 0, 9 do
        local ph = (T * 0.6 + q * 0.11) % 1
        put(sw * 4 * sin(math.pi * ph), slab - 14 + q * 3, WL - 1 - ph * 7, 2, 1)
      end
    end
    -- the lake: the face lying in it, broken streaks rocking on out_lo's
    -- swell; a calving's wave rolling across
    put(3 + bloom + breath * 1.5, 0, WL, 128, 1)
    for y = WL + 1, 63, 5 do
      local d = (y - WL) / 26
      local yy = y + K.heave(y * 5) * (0.4 + 1.2 * lo)
      local l = (F_ice * 0.9 + 0.6) * (1 - d * 0.5)
      -- (shared between the two rows the swell lifts it across: a row
      -- rises and falls, never hops)
      local y0 = floor(yy)
      local fy = yy - y0
      local off = K.drift_x * (0.2 + d * 0.4) + y * 4.3 + T * (2.6 + 1.4 * amp)
      if fy < 0.9 then K.streaks(l * (1 - fy), y0, 5 - d * 2, 12 + floor(d * 5), off) end
      if fy > 0.1 then K.streaks(l * fy, y0 + 1, 5 - d * 2, 12 + floor(d * 5), off) end
    end
    if sw > 0.02 then
      for b = 0, 2 do
        local ph = ((T * 5 + b * 8) % 24) / 24
        local y = WL + 2 + ph * 24
        local l = sw * 3.2 * (1 - (y - WL) / 30) * sin(math.pi * ph)
        for x = (K.drift_x * 0.3 + b * 9) % 10 - 10, 127, 10 do put(l, x, y, 7, 1) end
      end
    end
    K.surface(0, WL + 2, 128, 64, 1, 12, 4, 2, 0.12 + nat * 0.4)
    -- the water sounds: lapping and sparkle along the lake's near edge
    if nat > 0.02 then
      for k = 0, 15 do
        local x = k * 8 + sin(T * 1.2 + k) * 2
        local f = 0.5 + 0.5 * sin(T * 2.1 + k * 1.7)
        put(nat * (3.5 + 6 * f), x, 61 - (k % 2), 4, 1)
        put(nat * 6 * f, x + 2, WL + 1 + (k % 3), 3, 1)
      end
    end
    -- the notes
    for i = #marks, 1, -1 do
      local mk = marks[i]
      local age = T - mk.t0
      local cf, done = K.cap_fade(mk)
      if age > 4.5 or done then table.remove(marks, i)
      else
        local e = ease(age / 0.15) * (1 - ease((age - 2.4) / 2.1)) * cf
        local x = mk.x
        if mk.slot == 1 then
          -- an icicle at the face's foot drips into the lake
          -- (a spike tapering down from the ice's lip, lit along one side)
          put(8 * e, x - 1, WL - 10, 3, 3); put(9 * e, x, WL - 7, 2, 3); put(9.5 * e, x, WL - 4, 1, 3)
          put(5 * e, x + 2, WL - 10, 1, 2)
          local a = (age % 1.6) / 0.5
          if a < 1 then put(10 * e * sin(math.pi * a) ^ 0.5, x, WL - 1 + a * 6, 1, 2) end
          local ra = (age % 1.6) - 0.5
          if ra > 0 then K.ring(x, WL + 6, 2 + ra * 7, 0.3, 8 * e * (1 - ra / 1.1) * ease(ra / 0.15), 16) end
        elseif mk.slot == 2 then
          -- a runnel lighting down the face at its pitch
          local top = K.at(crest, x) + 2
          local run = clamp(age / 1.2, 0, 1)
          put(8 * e, x, top, 1, (WL - top) * run)
          put(5 * e, x + 1, top, 1, (WL - top) * run)
          put(6 * e, x - 3, WL + 1, 7, 1)
        elseif mk.slot == 3 then
          -- the sun off a facet: a small star, higher for a higher note
          local y = WL - 6 - mk.u * 18
          local g = e * (0.6 + 0.4 * sin(age * 5))
          put(11 * g, x, y, 1, 1)
          put(7 * g, x - 3, y, 3, 1); put(7 * g, x + 1, y, 3, 1); put(7 * g, x, y - 3, 1, 3); put(7 * g, x, y + 1, 1, 3)
          put(4 * g, x - 2, y - 2, 1, 1); put(4 * g, x + 2, y - 2, 1, 1); put(4 * g, x - 2, y + 2, 1, 1); put(4 * g, x + 2, y + 2, 1, 1)
          put(3 * g, x, WL + (WL - y) * 0.5, 1, 2)
        else
          -- a trickle at the face's foot rings the lake
          K.ring(x, WL + 4, 2 + age * 5, 0.35, 8 * e, 20)
          K.ring(x, WL + 4, 1 + age * 2.6, 0.35, 6 * e, 12)
          put(6 * e, x, WL - 6, 1, 6)
        end
      end
    end
    -- incidents
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "iceberg" then
        -- an iceberg drifts slowly across the lake, its reflection under it
        local x = -24 + u * 176
        local y = WL + 9 + inc.s * 6
        for q = 0, 4 do
          local hw = 11 - q * 2 + (q == 2 and 1 or 0)
          put((6 + q * 0.5) * e, x - hw, y - q, hw * 2, 1)
        end
        put(9 * e, x - 3, y - 5, 5, 1)
        for d = 1, 3 do put(3 * e * (1 - d / 4), x - 9 + K.heave(x + d) * 0.5, y + d * 1.5, 18, 1) end
      elseif inc.name == "tern" then
        -- a tern hunting over the water, hovering, then a dive
        local x = 10 + u * 110
        local dive = clamp((inc.age - 0.6 * inc.dur) / 1.2, 0, 1)
        local y = WL - 15 + sin(inc.age * 1.7) * 2 + sin(math.pi * dive) * 9
        K.bird(x, y, 9 * e, sin(K.NOW * 3), 2)
        put(11 * e, x - 2, y, 5, 1)
        K.bird(x, WL + (WL - y) * 0.5 + 2, 3.5 * e, -sin(K.NOW * 9), 1)
        if dive > 0.5 then
          local ra = (dive - 0.5) * 2
          K.ring(x, WL + 3, 1 + ra * 6, 0.35, 6 * e * (1 - ra * 0.7) * ease(ra / 0.25), 12)
        end
      end
    end
    K.glitter(sample, 34)
  end

  M.init()
  return M
end
