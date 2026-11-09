-- fireflies: a marsh at dusk. the last light glows over a dark tree line,
-- warmer as the bloom opens, a first few stars above; reeds stand at the
-- water's edge, cattails lean in close by, and the still water below holds
-- the glow. fireflies drift on the current, a few always faintly there,
-- and on every bar they glow up together, softly. the chord gathers them:
-- four small swarms hover across by the chord's pitches, higher for higher
-- tones, and drift to their new places when it changes. each note lights a
-- firefly at its pitch, and the motif decides how: a bright glow with a
-- halo, a double blink, a slow light trailing, or a frog's plop on the
-- water. out_mid sways the reeds and cattails, out_hi makes the fireflies
-- twinkle, the water sounds bring the frogs and crickets: rings on the
-- water, a shimmer in the grass. a swell lifts an evening mist off the
-- water; a passing moment lets the milky way show for a while. every
-- firefly shows again, dimmer and wavering, in the water. now and then a
-- bat flits over, an owl glides along the trees, or a little boat drifts by
-- with a lantern
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, cos, floor = math.sin, math.cos, math.floor

  M.incidents = {{"bat", 10}, {"owl", 12}, {"boat", 24}}

  local WL = 45
  local FLY_MAX = 18
  local AMBIENT = 12
  local PLOP_MAX = 6
  local flies, plops, plop_acc

  local STARS = {{12, 3}, {37, 8}, {58, 2}, {83, 6}, {104, 3}, {121, 9}, {25, 13}, {70, 11}}

  local trees = K.crowns(17, 14, WL, 8, 18, 5, 10)
  local sky_prof = K.profile(function(x)
    return math.min(trees(x), WL - 24 + math.abs(x - 96) * 1.6) + 0.5 * sin(x * 1.3)
  end)
  -- the milky way's stars, a band across the sky, baked once
  local milky = K.bake(function(rec)
    for k = 1, 90 do
      local u = K.hash(k, 77)
      local x = u * 128
      local y = 2 + u * 16 + (K.hash(k, 78) - 0.5) * 9
      if y < K.at(sky_prof, x) - 2 then rec(1 + 2 * K.hash(k, 79) ^ 3, x, y, 1, 1) end
    end
  end)
  -- the grass along the near edge, where the crickets are
  local GRASS = K.scatter(40, 0, 57, 128, 64, 80)
  -- faint stars out_hi brings out between the bright ones
  local FAINT = K.scatter(36, 2, 1, 126, 20, 81)
  -- the reeds at the water's edge: their feet stand still (baked), their
  -- tips sway
  -- (clumps of their own size at their own spacing, some only a stem or
  -- two: a reed edge, not a repeated stamp)
  local REED_X, REED_H = {}, {}
  do
    local x = 1
    for k = 0, 13 do
      REED_X[k] = x
      x = x + 5 + 9 * K.hash(k, 76)
      local n = 1 + floor(3 * K.hash(k, 82))
      for j = 0, 2 do REED_H[k * 3 + j] = j < n and (2.5 + 5.5 * K.hash(k * 3 + j, 75)) or 0 end
    end
  end
  local reed_feet = K.bake(function(rec)
    for k = 0, 13 do
      for j = 0, 2 do
        local h = REED_H[k * 3 + j]
        if h > 0 then rec(1, REED_X[k] + j * 1.5, WL - h * 0.5, 1, math.max(1, h * 0.5)) end
      end
    end
  end)
  -- cattails close by: {x, height, phase}
  local CATTAILS = {{4, 17, 0.4}, {9, 13, 2.1}, {120, 15, 1.2}, {125, 11, 3.3}}

  function M.init()
    flies, plops, plop_acc = {}, {}, 0
    for k = 1, AMBIENT do
      flies[k] = {x = 4 + (k - 1) * 10.5 + 6 * K.hash(k, 71), y = 24 + 18 * K.hash(k, 72),
        ph = K.hash(k, 73) * 6, amb = true, t0 = -99, pk = 0, n = (k * 5) % AMBIENT}
    end
  end

  function M.clear()
    for i = #flies, 1, -1 do if not flies[i].amb then table.remove(flies, i) end end
    plops, plop_acc = {}, 0
  end

  local function plop(x, y, lv)
    K.cap_add(plops, {x = x, y = y, t0 = K.T, lv = lv}, PLOP_MAX)
  end

  -- a new lit firefly; when as many as there can be are lit, the oldest one
  -- fades out quickly (eased) rather than going out at once
  local function lit_new(f)
    local live, oldest = 0, nil
    for _, a in ipairs(flies) do
      if not a.amb and not a.gone then live = live + 1; oldest = oldest or a end
    end
    if live >= FLY_MAX - AMBIENT and oldest then oldest.gone = K.T end
    flies[#flies + 1] = f
  end

  function M.note(slot, midi)
    local x = K.px(midi)
    if slot == 4 then
      -- a frog's plop on the water at the note's pitch
      plop(x, WL + 3 + (1 - K.pu(midi)) * 10, 6)
      return
    end
    -- a note lights a firefly at its pitch: an ambient one nearby if there
    -- is one, otherwise a new one
    local f
    for _, a in ipairs(flies) do
      if math.abs(a.x - x) < 6 and K.T - a.t0 > 2 then f = a; break end
    end
    if not f then
      f = {x = x, y = 18 + (1 - K.pu(midi)) * 20, ph = K.rnd() * 6, amb = false}
      lit_new(f)
    end
    f.t0, f.pk, f.kind = K.T, 11 + 2 * (1 - (slot - 1) / 4), slot
    if slot == 2 then
      -- a second answers it a little way off
      lit_new({x = x + 5, y = f.y - 3, ph = K.rnd() * 6, amb = false, t0 = K.T + 0.4, pk = f.pk, kind = 2})
    end
  end

  local function sample(u, v) return u * 127, WL + 2 + v * 14 end

  -- the sky and its reflection rows, made once (the light, the time and the
  -- row are set each frame)
  local F_glow, F_T, F_hi, F_lo, F_d = 1, 0, 0, 0, 1
  local function sky(y) return F_glow * clamp(1 - (34 - y) / 18, 0, 1) ^ 1.6 end
  local function keep_glow(x) return WL - F_d * 1.2 < K.at(sky_prof, x) end
  local function glow_nudge(x)
    local d, dl = F_d, 0
    if F_hi > 0.02 then dl = F_hi * 3.5 * math.max(0, sin(x * 0.9 + d * 1.7 + F_T * 5)) end
    if F_lo > 0.02 then dl = dl + F_lo * 1.6 * sin(x * 0.04 - F_T * 0.6 + d * 0.3) end
    return K.heave(x + d * 3) * (0.3 + d * 0.06), dl
  end

  -- how lit a note's firefly is, by the kind of light its motif makes
  local function lit_of(f, age)
    if age >= 6 then return 0 end
    if f.kind == 2 then
      -- a double blink
      local b = math.max(0, sin(math.pi * clamp(age / 0.6, 0, 1))) + math.max(0, sin(math.pi * clamp((age - 0.8) / 0.6, 0, 1)))
      return f.pk * b * (1 - ease((age - 1.5) / 2))
    elseif f.kind == 3 then
      -- a slow light, coming up and staying long as it climbs
      return f.pk * 0.85 * ease(age / 1.2) * (1 - ease((age - 2.5) / 3.5))
    end
    return f.pk * ease(age / 0.5) * (1 - ease((age - 1) / 5))
  end

  function M.draw()
    local T, DTS = K.T, K.DTS
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local hi, mid, nat = A[K.HI], A[K.MID], A[K.NAT]
    -- the sky: the last light low over the trees, stars higher up
    F_glow, F_T, F_hi, F_lo = 1.6 + 1.2 * bloom + 1.0 * breath + 0.8 * K.chord_glow, T, hi, A[K.LO]
    K.gradient(10, WL - 1, sky, sky_prof)
    for i, s in ipairs(STARS) do
      put((1.5 - bloom * 0.6) * (1.1 + 0.6 * sin(T * 0.5 + i * 2.3)) + hi * 2 * math.max(0, sin(T * 3 + i * 1.9)), s[1], s[2], 1, 1)
    end
    K.twinkle(FAINT, hi, 4)
    -- a passing moment: the milky way shows for a while
    local ma = K.moment_age
    if ma < 18 then
      local e = ease(ma / 3) * (1 - ease((ma - 12) / 6))
      K.blit(milky, 3 * e)
      for k = 0, 8 do
        local x = k * 16 + 4
        K.dither_row(0.9 * e, floor(3 + (x / 128) * 16 + sin(k) * 2), nil, x, x + 14)
        K.dither_row(0.6 * e, floor(4 + (x / 128) * 16 + sin(k) * 2), nil, x + 2, x + 12)
      end
    end
    -- reeds at the water's edge, faint against the dark trees, swaying with
    -- out_mid
    K.blit(reed_feet, 1 + mid)
    for k = 0, 13 do
      local x = REED_X[k]
      local base = K.flow(x, WL) * 0.2 + K.heave(x) * 0.4
      for j = 0, 2 do
        local h = REED_H[k * 3 + j]
        if h > 0 then
          local lean = base + sin(T * 0.6 + k + j) * (0.5 + 1.5 * mid) + (j - 1)
          put(1 + mid, x + j * 1.5 + lean, WL - h, 1, h * 0.5)
        end
      end
    end
    -- (the water's edge: broken strokes of the glow, not a rail)
    K.streaks(1.5 + bloom, WL, 12, 13, 5)
    -- the water: the glow lies in it below the trees' reflection
    for d = 1, 18 do
      if d % 2 == 0 or d < 3 then
        F_d = d
        local l = sky(WL - d * 1.2) * 0.7 + breath * 1.2
        K.streaks(l, WL + d, 6 + d % 4, 9 + d % 3, K.drift_x * (0.3 + d * 0.03) + d * 4.7, keep_glow, glow_nudge)
      end
    end
    -- a swell lifts an evening mist off the water
    if sw > 0.03 then
      for k = 0, 5 do
        local y = WL - 2 + k * 2 - floor(sw * 6)
        K.streaks(sw * (2.4 - k * 0.25), y, 6 + k, 19 + k * 2, K.drift_x * 0.6 + T * 1.5 + k * 11)
      end
    end
    -- frogs and crickets with the water sounds: plops on the water, a
    -- shimmer in the near grass
    plop_acc = plop_acc + nat * 4 * DTS
    if plop_acc >= 1 then plop_acc = plop_acc - 1; plop(4 + K.rnd() * 120, WL + 3 + K.rnd() * 14, 3.5 + nat * 2) end
    for i = #plops, 1, -1 do
      local p = plops[i]
      local age = T - p.t0
      local cf, done = K.cap_fade(p)
      if age > 2.5 or done then table.remove(plops, i)
      else
        local e = ease(age / 0.12) * (1 - age / 2.5) * cf
        K.ring(p.x, p.y, 1 + age * 5, 0.35, p.lv * e, 11, 0, WL, 64)
        if age < 0.3 then put(p.lv * 1.2, p.x, p.y - 2 - age * 6, 1, 1) end
      end
    end
    if nat > 0.03 then
      for i = 1, #GRASS, 2 do
        local w = sin(T * 3.1 + i * 1.9) * sin(T * 1.7 + i)
        local th = 0.3 - nat * 0.6
        if w > th then put((1.5 + 4 * nat * w) * K.ramp(w, th, th + 0.25), GRASS[i], GRASS[i + 1], 2, 1) end
      end
    end
    -- the chord's swarms: three dim fireflies circling each tone's place
    for i = 1, 4 do
      local m, p = K.chord_at(i)
      if m and p > 0.02 then
        local cx = K.cx(m)
        local cy = clamp(38 - (m - 36) / 40 * 22, 14, 40)
        for j = 0, 4 do
          local a = T * (0.5 + 0.1 * j) + j * 1.3 + i
          local x, y = cx + cos(a) * (3 + j * 1.6), cy + sin(a * 1.3) * (2 + j * 0.5)
          local l = p * (3.2 + 2 * K.chord_glow + 1.5 * breath) * (0.75 + 0.25 * sin(T * 1.7 + j * 2 + i))
          if j < 2 then put(l * 0.3, x - 1, y - 1, 3, 3) end
          put(l, x, y, 1, 1)
          local ry = WL + (WL - y) * 0.55 + 1
          if ry < 63 then put(l * 0.4, x + K.heave(x + ry) * 0.6, ry, 2, 1) end
        end
      end
    end
    -- the fireflies
    for i = #flies, 1, -1 do
      local f = flies[i]
      local u, v = K.flow(f.x, f.y)
      local spd = 0.7 + 0.8 * A[K.AMP]
      f.x = f.x + (u * 0.35 + sin(T * 0.4 + f.ph) * 1.2) * DTS * spd
      f.y = clamp(f.y + (v * 0.3 + sin(T * 0.53 + f.ph * 2) * 1.0) * DTS * spd, 14, WL - 3)
      if f.x > 131 then f.x = -3 elseif f.x < -3 then f.x = 131 end
      local age = T - f.t0
      local lit = f.amb and 0 or lit_of(f, age)
      if f.amb and age < 6 then lit = lit_of(f, age) end
      -- the ambient ones glow up together on the bar
      -- (out_amp wakes more of them)
      local awake = f.amb and clamp(3 + 11 * A[K.AMP] - f.n, 0, 1) or 0
      local base = f.amb and (1.5 + 1.2 * (0.5 + 0.5 * sin(T * 0.8 + f.ph)) + 2.5 * breath) * awake * (0.7 + 0.9 * A[K.AMP]) or 0
      local tw = hi * 2.5 * math.max(0, sin(T * 4 + f.ph * 5))
      local cf, done = K.cap_fade(f)
      local lv = (math.max(base, lit) + ((lit > 0.5 or f.amb) and tw or 0)) * cf
      if not f.amb and (age >= 6 or done) then
        table.remove(flies, i)
      elseif lv >= 0.5 then
        -- a soft glow round it, then the light itself
        -- (the halo and the cross grow with the light: neither switches on)
        local h1 = (lv - 2) * 0.3
        if h1 >= 0.5 then put(h1, f.x - 1, f.y - 1, 3, 3) end
        local h2 = (lv - 5.5) * 0.4
        if h2 >= 0.5 then put(h2, f.x - 2, f.y, 5, 1); put(h2, f.x, f.y - 2, 1, 5) end
        put(lv, f.x, f.y, 1, 1)
        -- a slow light climbs, trailing a long tail below it
        if f.kind == 3 and lit > 1 then
          f.y = f.y - DTS * 2.2
          for k = 1, 4 do put(lit * (0.6 - k * 0.1), f.x + sin(T * 1.3 + k) * 0.8, f.y + k * 2, 1, 2) end
        end
        -- the reflection, below the edge, wavering
        local ry = WL + (WL - f.y) * 0.55 + 1
        if ry < 63 then
          local rx = f.x + K.heave(f.x + ry) * 0.6 + sin(T * 3 + ry) * 0.6
          put(lv * 0.4, rx, ry, 1, 1)
          local h3 = (lv - 2.5) * 0.25
          if h3 >= 0.5 then put(h3, rx - 1, ry + 1, 3, 1) end
        end
      end
    end
    -- cattails close by, swaying with out_mid and the air
    for _, c in ipairs(CATTAILS) do
      local x0, h = c[1], c[2]
      local lean = sin(T * 0.7 + c[3]) * (0.6 + 1.6 * mid) + K.heave(x0) * 0.5
      for s = 0, h - 1, 3 do
        local u = s / h
        put(2 + K.bj(x0 + s) * 0.4, x0 + lean * u * u, 63 - s - 3, 1, 3)
      end
      put(3 + mid * 2 + bloom, x0 + lean - 0.5, 63 - h - 4, 2, 4)
      put(2, x0 + lean, 63 - h - 6, 1, 2)                 -- its spike
      -- and a leaf arching away from it
      local dir = x0 < 64 and 1 or -1
      for j = 1, 4 do put(1.8, x0 + dir * j + lean * 0.2 * j, 63 - h * 0.5 - j * 1.3 + j * j * 0.25, 1, 1) end
    end
    -- incidents
    local inc = K.inc
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "bat" then
        -- a bat flits over, jinking
        local x = -6 + u * 140
        local y = 12 + sin(u * 23) * 5 + sin(u * 7) * 4
        local flap = sin(K.NOW * 14)
        K.bird(x, y, 6 * e, flap, 2)
        put(5 * e, x - 1, y + 1, 3, 1)
      elseif inc.name == "owl" then
        -- an owl glides along the tree line, pale underneath
        local dir = inc.s > 0.5 and 1 or -1
        local x = dir > 0 and (-12 + u * 152) or (140 - u * 152)
        local y = K.at(sky_prof, clamp(x, 0, 127)) - 5 + sin(u * 5) * 2
        K.bird(x, y, 6.5 * e, sin(K.NOW * 1.6) * 0.6, 2)
        put(6 * e, x - 2, y + 1, 5, 1); put(4 * e, x - 1, y + 2, 3, 1)
      else
        -- a little boat drifts along the water, a lantern at its bow, its
        -- light lying long in the water
        local dir = inc.s > 0.5 and 1 or -1
        local x = dir > 0 and (-10 + u * 148) or (138 - u * 148)
        local y = WL + 4
        put(4.5 * e, x - 5, y, 11, 1); put(3.5 * e, x - 4, y + 1, 9, 1)
        put(3 * e, x - 1, y - 3, 1, 3)
        local fl = 0.8 + 0.2 * sin(K.NOW * 5)
        put(9 * e * fl, x + 4 * dir, y - 3, 1, 1)
        put(3.5 * e * fl, x + 3 * dir, y - 3, 3, 1); put(3.5 * e * fl, x + 4 * dir, y - 4, 1, 3)
        for d = 2, 14, 2 do
          put(4 * e * fl * (1 - d / 16), x + 4 * dir - 1 + sin(T * 3 + d) * 1.2, y + d * 0.6 + 1, 3, 1)
        end
      end
    end
    K.glitter(sample, 10)
  end

  M.init()
  return M
end
