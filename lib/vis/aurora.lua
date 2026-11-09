-- aurora: a calm northern fjord at night. dark mountains stand either side
-- of still water, stars over them, and the aurora hangs in soft curtains
-- across the sky, lying again in the water below. the chord is the
-- curtains: four bands, each across by its tone's pitch and higher in the
-- sky for a higher tone, drifting to their new places when the chord
-- moves. the bloom is how strong the aurora burns; the bar breathes in it.
-- out_lo folds the curtains in long slow waves, out_mid ripples the folds
-- finer, out_amp sets how fast they drift, out_hi makes the rays shimmer,
-- and the water sounds lap at the shore and break up the reflection. a note
-- lights a ray at its pitch, by motif: one tall ray (the first), a pair
-- (the second), a ray that runs along the curtain (the third), a soft
-- pulsing patch (the fourth). a swell sends a wave of light rolling along
-- every curtain; a passing moment opens a corona overhead. now and then a
-- shooting star falls, a seal surfaces, or a cabin window lights on the
-- shore
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, cos, floor, abs = math.sin, math.cos, math.floor, math.abs

  M.incidents = {{"meteor", 8}, {"seal", 14}, {"cabin", 24}}

  local WL = 45                           -- the water's edge
  local MARK_MAX = 6
  local marks
  local ph = 0                            -- the curtains' drift

  -- the mountains either side, and the low far shore between them
  local hills = K.profile(function(x)
    local l = 22 + x * 0.42 + 3 * sin(x * 0.21) + 2 * K.hash(x // 4, 701)
    local r = 22 + (127 - x) * 0.45 + 3 * sin(x * 0.17 + 1) + 2 * K.hash(x // 4, 702)
    return math.min(l, r, WL - 2 - 1.5 * K.hash(x // 6, 703))
  end)
  local land = K.bake(function(rec)
    for c = 0, 63 do
      local t = floor(hills[c] + 0.5)
      rec(1.7, c * 2, t, 2, 1)
      for y = t + 2, WL - 1, 2 do
        if K.hash(c * 64 + y, 704) < 0.28 then rec(1, c * 2 + (y // 2) % 2, y, 1, 1) end
      end
    end
  end)
  local STARS = {}
  for k = 1, 34 do
    local x = floor(128 * K.hash(k, 705))
    local y = floor(2 + 30 * K.hash(k, 706))
    if y < K.at(hills, x) - 2 then STARS[#STARS + 1] = {x, y, K.hash(k, 707) * 6, 1 + K.hash(k, 708)} end
  end
  local CV = {}                           -- the curtains this frame: centre, height, presence
  for i = 1, 4 do CV[i] = {64, 20, 0} end

  function M.init() marks, ph = {}, 0 end
  function M.clear() marks = {} end

  function M.note(slot, midi)
    K.cap_add(marks, {slot = slot, x = K.px(midi), u = K.pu(midi), t0 = K.T}, MARK_MAX)
  end

  -- the base of the curtain nearest x (its fold), and how bright it is there
  local function fold(i, x)
    local c = CV[i]
    local lo, mid = A[K.LO], A[K.MID]
    return c[2] + (1.5 + 4 * lo) * sin(x * 0.045 + ph * 0.6 + i * 1.7) + (0.3 + 3.6 * mid) * sin(x * 0.19 - ph * 1.3 + i) + 4 * K.sw_disp
  end

  local function sample(u, v) return u * 127, 4 + v * 30 end
  -- a note's ray standing up from yb
  local function ray(x, yb, l, h)
    put(l, x, yb - h * 0.4, 2, h * 0.4 + 2)
    put(l * 0.6, x, yb - h, 2, h * 0.6)
    put(l * 0.3, x - 2, yb - h * 0.6, 6, h * 0.5)
  end

  function M.draw()
    local T = K.T
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local hi, mid, nat, lo = A[K.HI], A[K.MID], A[K.NAT], A[K.LO]
    ph = ph + K.DTS * (0.25 + 0.9 * A[K.AMP])
    local power = 0.45 + 0.9 * bloom + 0.8 * breath + 0.45 * sw
    -- stars, dimmer where the aurora burns
    for k, s in ipairs(STARS) do
      put((1.3 + 0.8 * sin(T * 0.9 + s[3])) * s[4] * (1.1 - 0.3 * bloom), s[1], s[2], 1, 1)
    end
    for i = 1, 4 do
      local m, p = K.chord_at(i)
      local c = CV[i]
      if m then c[1], c[2] = K.cx(m), clamp(30 - (m - 36) / 40 * 22, 8, 32) end
      c[3] = m and p or 0
    end
    -- the curtains: rays rising from a folding base, shimmering, the swell
    -- rolling a wave of light along them
    local wave = (T * 0.35) % 1.6 - 0.3
    for i = 1, 4 do
      local c = CV[i]
      local p = c[3]
      if p > 0.02 then
        local hw = 34 + 6 * sin(T * 0.07 + i)
        local x0 = floor((c[1] - hw) / 2) * 2
        for x = x0, c[1] + hw, 2 do
          local edge = 1 - abs(x - c[1]) / hw
          if edge > 0 and x >= 0 and x < 128 then
            local yb = fold(i, x)
            local sh = 1 + hi * 1.1 * sin(x * 0.7 - T * 4 + i * 2)
            local sv = sw * 3 * math.max(0, 1 - abs(x / 128 - wave) * 4)
            -- (the folds: where the curtain turns toward you it is brighter)
            local fo = 0.55 + 0.45 * sin(x * 0.13 + ph * 0.8 + i * 2.3) * sin(x * 0.05 - ph * 0.3 + i)
            local l = (2.4 + 1.8 * K.chord_glow + sv) * power * p * math.min(1, edge * 2.5) * sh * fo + K.bj(x + i * 64) * 0.5
            l = math.min(l, 11)
            local h = floor(5 + 7 * edge * fo + 3 * sin(x * 0.11 + ph + i))
            put(l, x, yb - 2, 1, 3)
            put(l * 0.6, x, yb - 2 - h * 0.5, 1, floor(h * 0.5))
            put(l * 0.35, x, yb - 2 - h, 1, floor(h * 0.5))
            -- and lying in the still water, broken
            if x % 4 == 0 then
              local ry = WL + (WL - yb) * 0.35
              local br = nat * 2 * sin(x * 0.3 + T * 2)
              put(l * 0.45, x + br, ry, 2, 1 + floor(h * 0.12))
            end
          end
        end
      end
    end
    K.blit(land, 1 + 0.25 * bloom)
    -- the water: faint streaks of the sky's light, the shore lapping
    for y = WL + 1, 63, 3 do
      local d = (y - WL) / 18
      K.streaks(1.2 + 0.6 * bloom + breath * 1.2, y, 5 + d * 6, 17, K.drift_x * (0.2 + d * 0.3) + y * 7, nil)
    end
    K.streaks(1.6 + bloom * 0.8 + nat * 3, WL, 6, 9, K.drift_x * 0.2 + T * nat * 3)
    if nat > 0.03 then
      for k = 0, 9 do
        local x = k * 13 + 4 + sin(T * 1.1 + k) * 3
        put(nat * (2.5 + 2 * math.max(0, sin(T * 2 + k))), x, WL + 1, 6, 1)
      end
    end
    -- the notes: rays lit at their pitch
    for k = #marks, 1, -1 do
      local mk = marks[k]
      local age = T - mk.t0
      local cf, done = K.cap_fade(mk)
      if age > 5.5 or done then table.remove(marks, k)
      else
        local e = ease(age / 0.3) * (1 - ease((age - 2.2) / 3.3)) * cf
        local yb = 34 - mk.u * 16
        if mk.slot == 1 then
          ray(mk.x, yb, 9 * e, 18)
        elseif mk.slot == 2 then
          ray(mk.x - 3, yb, 8 * e, 14); ray(mk.x + 3, yb, 8 * e, 16)
        elseif mk.slot == 3 then
          ray(mk.x + age * 8, yb, 8.5 * e, 15)
          put(3 * e, mk.x, yb, age * 8, 1)
        else
          local pu = 0.6 + 0.4 * sin(age * 4)
          for d = -4, 4, 2 do put(7 * e * pu * (1 - abs(d) / 6), mk.x + d, yb - 8, 2, 8) end
        end
        put(3.5 * e, mk.x - 1, WL + (WL - yb) * 0.35, 3, 2)
      end
    end
    -- the moment: a corona opens overhead, rays from one point
    local ma = K.moment_age
    if ma < 16 then
      local e = ease(ma / 3) * (1 - ease((ma - 10) / 6))
      for k = 0, 15 do
        local a = math.pi * (0.05 + 0.9 * k / 15)
        local fl = 0.7 + 0.3 * sin(ma * 1.5 + k * 1.9)
        for r = 6, 26, 4 do
          put(e * fl * (7 - r * 0.15), 64 + cos(a) * r * 1.8, 2 + sin(a) * r * 0.9, 2, 2)
        end
      end
    end
    -- incidents
    local inc = K.inc
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "meteor" then
        -- a shooting star slides down the sky, its trail fading
        local f = clamp((inc.age - 1.5) / 4, 0, 1)
        local x0, y0 = 15 + inc.s * 60, 3 + inc.s2 * 6
        local x, y = x0 + f * 44, y0 + f * 16
        local fe = e * ease(f / 0.25) * (1 - ease((f - 0.6) / 0.4))
        for q = 0, 11 do put(fe * (10 - q * 0.7), x - q * 2.8, y - q, 3, 1) end
        put(fe * 5, x - 1, y - 1, 3, 3)
        for d = 2, 8, 2 do put(fe * (4 - d * 0.3), x - 3 + sin(T * 2 + d), WL + (WL - y) * 0.35 + d, 6, 1) end
      elseif inc.name == "seal" then
        -- a seal's head surfaces, looks round, and sinks, rings spreading
        local x, y = 30 + inc.s * 60, WL + 6 + inc.s2 * 4
        local up = ease(clamp(inc.age / 2, 0, 1)) * (1 - ease((inc.age - inc.dur + 3) / 2))
        put(6 * e * up, x - 2, y - 3 * up, 5, 3); put(7 * e * up, x + 2, y - 2 * up - 1, 2, 2)
        put(8 * e * up, x + 1, y - 3 * up, 1, 1)
        K.ring(x, y + 1, 4 + sin(inc.age * 0.8) * 1.5, 0.3, 4.5 * e, 16, 0, WL, 64)
        K.ring(x, y + 1, 8 + sin(inc.age * 0.6) * 2, 0.3, 3 * e, 20, 0, WL, 64)
      else
        -- a cabin window lights on the far shore, its light lying in the water
        local x = 50 + inc.s * 30
        local y = floor(K.at(hills, x)) - 3
        put(2.4 * e, x - 4, y - 1, 9, 5)
        put(9 * e, x - 1, y + 1, 3, 2)
        put(3 * e, x - 3, y - 3, 7, 1)
        for d = 2, 14, 2 do put(e * (6 - d * 0.3), x - 1 + sin(T * 1.7 + d) * 1.5, WL + d, 3, 1) end
      end
    end
    K.glitter(sample, 10)
  end

  M.init()
  return M
end
