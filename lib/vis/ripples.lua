-- ripples: a still pond under a far bank, the sky lying in it. the chord
-- hangs as four wisps of cloud (across by pitch, higher for higher tones)
-- that glide when it changes, and the pond holds them. each note drops a
-- ring where its pitch is, in its motif's band (further bands are further
-- away, so their rings are smaller); the motif decides the kind of drop: a
-- ring, a double ring, a ring with a bounced droplet, a little cluster.
-- rings drift with the current, glow where they cross and bend the
-- reflection as they pass; echoes follow at the echo time. ring brightness
-- rides out_amp, the heave out_lo, a band of wavelets in the middle water
-- out_mid, sparkle on the reflections out_hi, and water boatmen dimple the
-- surface with the water sounds. the bar breathes light into the sky's
-- reflection; a swell lifts the water up the bank in slow broad bands; a
-- moment sends a cat's paw of wind across the pond. now and then a fish
-- rises, a heron passes low, or a leaf drops from the tall tree
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, cos, floor = math.sin, math.cos, math.floor

  M.incidents = {{"fish", 9}, {"heron", 14}, {"leaf", 16}}

  local ECHO_BEATS = {0.5, 1, 1.5, 2}     -- same order as the echo time param
  local RING_MAX, RING_R = 16, 28
  local DIMPLE_MAX = 6
  local WL = 16                           -- the far waterline
  local rings, pending, live, nl = {}, {}, {}, 0
  local dimples, dimple_acc = {}, 0
  local drops = {}                        -- slot 3's bounced droplets
  local pads

  function M.clear()
    rings, pending, live, nl = {}, {}, {}, 0
    dimples, dimple_acc, drops = {}, 0, {}
  end

  function M.init()
    M.clear()
    pads = {{x = 30, y = 37, ph = 0.3}, {x = 92, y = 52, ph = 2.1}}
  end

  -- the far bank: a soft tree line, one taller tree to the left
  local trees = K.crowns(5, 14, WL, 2, 6, 4, 8)
  local bank = K.profile(function(x)
    local tall = 9 * math.max(0, 1 - math.abs(x - 22) / 7) ^ 0.6
    return math.min(trees(x), WL - 1 - tall) - 0.6 * sin(x * 0.9)
  end)
  -- the trees' texture: a few lit leaves on the crowns, baked once
  local leaves = K.bake(function(rec)
    for c = 0, 63 do
      local t = bank[c]
      for y = floor(t) + 1, WL - 2, 2 do
        if K.hash(c * 64 + y, 11) < 0.22 then rec(1, c * 2 + (y % 2), y, 1, 1) end
      end
    end
  end)

  -- near reeds in the bottom-left corner, close enough to sway at the
  -- current's full rate: {x, height, phase}
  local NEAR = {{2, 15, 0.2}, {5, 11, 1.9}, {8, 17, 3.1}, {11, 9, 4.4}, {124, 12, 0.9}, {121, 8, 2.6}}

  -- the cat's paw's roughness: fixed scatter round its centre
  local PAW = {}
  for k = 1, 44 do PAW[#PAW + 1] = (K.hash(k, 15) - 0.5) * 44; PAW[#PAW + 1] = 8 + K.hash(k, 16) * 40 end

  local WV = {}
  for k = 1, 14 do WV[k], WV[k + 14] = K.hash(k, 13), K.hash(k, 14) end

  local function slot_y(slot) return 21 + (slot - 1) * 11 end
  -- nearer water is bigger: rings scale with their distance down the pond
  local function persp(y) return 0.5 + 0.5 * clamp((y - WL) / 50, 0, 1) end

  local function add_ring(x, y, lvl, kind, delay)
    rings[#rings + 1] = {x = x, y = y, t0 = K.T + (delay or 0), lvl = lvl, a0 = K.rnd() * K.TAU,
      rad = 0, lv = 0, kind = kind or 1}
    while #rings > RING_MAX do table.remove(rings, 1) end
  end

  function M.note(slot, midi)
    local x, y = K.px(midi), slot_y(slot)
    -- the motif decides the kind of drop
    if slot == 2 then
      add_ring(x, y, 1, 2); add_ring(x, y, 0.6, 2, 0.35)
    elseif slot == 3 then
      add_ring(x, y, 1, 3)
      drops[#drops + 1] = {x = x, y = y, t0 = K.T}
      if #drops > 4 then table.remove(drops, 1) end
    elseif slot == 4 then
      add_ring(x - 3, y, 0.7, 4); add_ring(x + 3, y + 1, 0.6, 4, 0.12); add_ring(x, y - 1, 0.5, 4, 0.25)
    else
      add_ring(x, y, 1, 1)
    end
    -- echoes: one every echo time, each the feedback quieter; they land where
    -- the current has carried the spot by then
    local fb, div = K.echo()
    local tempo = K.S and tonumber(K.S.tempo) or 72
    local beat = 60 / clamp(tempo or 72, 20, 300)
    local delay = (ECHO_BEATS[div] or 1.5) * beat
    local lvl, k = fb, 1
    while lvl > 0.2 and k <= 3 do
      pending[#pending + 1] = {at = (K.NOW or 0) + k * delay, x = x, y = y, lvl = lvl}
      lvl = lvl * fb
      k = k + 1
    end
    while #pending > 24 do table.remove(pending, 1) end
  end

  -- how far the live rings push the water sideways at a point (and how
  -- much they stir it): a ring's front shoves what it passes. the rings
  -- that reach a row are listed once per row
  local cand, nc, cand_y = {}, 0, nil
  local function refract(x, y)
    if y ~= cand_y then
      cand_y, nc = y, 0
      for i = 1, nl do
        local r = live[i]
        local ey = (y - r.y) / 0.42
        if ey < r.rad + 3 and ey > -r.rad - 3 then nc = nc + 1; cand[nc] = r end
      end
    end
    local dx, stir = 0, 0
    for i = 1, nc do
      local r = cand[i]
      local ex = x - r.x
      if ex < r.rad + 3 and ex > -r.rad - 3 then
        local ey = (y - r.y) / 0.42
        local f = math.sqrt(ex * ex + ey * ey) - r.rad
        if f > -3 and f < 3 then
          local s = (1 - math.abs(f) / 3) * r.lv / 8
          dx = dx + (ex >= 0 and 1 or -1) * s * 2.5
          stir = stir + s
        end
      end
    end
    return dx, stir
  end

  local function sample(u, v) return u * 127, WL + 3 + v * 46 end

  -- the chord's clouds: tone i -> x, y, presence (gliding with the chord)
  local CL = {{0, 0, 0}, {0, 0, 0}, {0, 0, 0}, {0, 0, 0}}
  local function clouds()
    local par = K.drift_x * 0.08
    for i = 1, 4 do
      local m, p = K.chord_at(i)
      local c = CL[i]
      if m then
        c[1] = (K.cx(m) + par + 6 * sin(K.T * 0.03 + i)) % 140 - 6
        c[2] = clamp(2 + (76 - m) / 40 * 10, 2, 12)
        c[3] = p
      else
        c[3] = 0
      end
    end
  end
  -- how much cloud is over column x at sky row y
  local function cloud_at(x, y)
    local v = 0
    for i = 1, 4 do
      local c = CL[i]
      if c[3] > 0 then
        local dx, dy = (x - c[1]) / (11 + i * 2), (y - c[2]) / 1.8
        local d = dx * dx + dy * dy
        if d < 1 then v = v + (1 - d) * c[3] end
      end
    end
    return v
  end

  function M.draw(S)
    local T, DTS = K.T, K.DTS
    local hi, mid, nat = A[K.HI], A[K.MID], A[K.NAT]
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    -- a swell lifts the water up the bank
    local wl = WL - floor(sw * 3 + 0.5)
    -- rings first: they move, and the reflection reads them
    for i = #pending, 1, -1 do
      local p = pending[i]
      local u, v = K.flow(p.x, p.y)
      p.x, p.y = p.x + u * DTS, p.y + v * DTS * 0.42
      if K.NOW >= p.at then
        add_ring(p.x, p.y, p.lvl)
        table.remove(pending, i)
      end
    end
    local amp = 0.55 + 0.65 * A[K.AMP]
    local speed = 7 + 4 * A[K.AMP]
    nl = 0
    for i = #rings, 1, -1 do
      local r = rings[i]
      local age = T - r.t0
      local sc = persp(r.y)
      local rad = math.max(0, age) * speed * sc
      local life = rad / (RING_R * sc * (r.kind == 4 and 0.4 or 1))
      if life >= 1 or r.x < -RING_R or r.x > 128 + RING_R then
        table.remove(rings, i)
      elseif age > 0 then
        local u, v = K.flow(r.x, r.y)
        r.x, r.y = r.x + u * DTS, clamp(r.y + v * DTS * 0.42, wl + 4, 62)
        r.rad, r.lv = rad, 8 * r.lvl * (1 - life) ^ 1.4 * amp * ease(age / 0.18)
        if r.lv >= 0.5 and rad >= 1 then nl = nl + 1; live[nl] = r end
      end
    end

    cand_y = nil
    -- the sky: a glow down to the bank, brighter and warmer as the bloom
    -- opens; the chord's clouds lie across it
    clouds()
    local sky = 1.2 + 1.1 * bloom
    local function skylv(y) return sky * (0.12 + 1.5 * (y / WL) ^ 2) end
    for y = 0, wl - 1 do
      local v = skylv(y) + breath * 1.3 * (y / WL) ^ 2
      K.dither_row(v, y, bank)
      -- a row a cloud crosses: lit a little more under each wisp
      for i = 1, 4 do
          local c = CL[i]
          local dy = math.abs(y - c[2])
          if c[3] > 0 and dy < 2 then
            local hw = (11 + i * 2) * (1 - dy * 0.35)
            local l = (v + 1.6 + 0.8 * bloom + 1.5 * K.chord_glow) * c[3]
            local w = hw * 2 * (0.7 + 0.3 * K.hash(i * 9 + y, 12))
            put(l, c[1] - hw, y, w, 1)
            -- the lit top edge of the wisp
            if y < c[2] then put(l + 1, c[1] - hw * 0.6, y, w * 0.5, 1) end
          end
      end
    end
    K.blit(leaves, 1 + 0.6 * bloom)
    put(1 + K.bar_pulse + breath, 0, wl, 128, 1)
    -- the bank, the sky and its clouds lie in the water: the sky's glow comes
    -- back below the trees' reflection, then long pale streaks thin out
    -- toward you; rings bend and stir them, out_hi sparkles on them
    local function nudge(x, y)
      local dx, stir = 0, 0
      if nl > 0 then dx, stir = refract(x, y) end
      local sp = hi * 2.5 * math.max(0, sin(x * 0.9 + y * 1.3 + T * 6))
      return dx + K.heave(x) * 0.3, stir * 4 + sp
    end
    -- (the reflection stays where it is; a rising swell floods the bank's
    -- foot above it)
    local paw = K.moment_age < 12 and (-20 + K.moment_age * 14) or nil
    local pawe = paw and ease(K.moment_age / 1.2) * (1 - ease((K.moment_age - 8) / 4)) or 0
    local function nudge2(x, y)
      local dx, dl = nudge(x, y)
      if paw and math.abs(x - paw) < 24 then
        local f = (1 - math.abs(x - paw) / 24) * pawe
        dx, dl = dx + f * 3 * sin(y * 2.1 + T * 7), dl - f * 1.5
      end
      return dx, dl
    end
    for y = wl + 1, WL, 2 do
      K.streaks(sw * 1.6, y, 9, 13, K.drift_x * 0.3 + y * 5.1, nil, nudge2)
    end
    for d = 1, 28 do
      local y = WL + d
      local near = d < WL
      if (near and d % 2 == 1) or (not near and d % (2 + (d - WL) // 4) == 0) then
        local keep = near and function(x) return WL - d < K.at(bank, x) end or nil
        local l = near and skylv(WL - d) * 0.75 or sky * 0.9 * (1 - (d - WL) / 16)
        l = l + breath * 1.4 * (1 - d / 28)
        local w, gap = near and 8 or (4 + d // 5), near and 15 or (13 + d)
        K.streaks(l, y, w, gap, K.drift_x * (0.3 + d * 0.02) + d * 7.3 + sin(T * 0.3 + d) * 2, keep, nudge2)
      end
    end
    -- the clouds' reflections: soft broken dashes under each wisp
    for i = 1, 4 do
      local c = CL[i]
      if c[3] > 0.05 then
        local ry = WL + (WL - c[2]) + 1
        local l = (1.2 + 0.8 * bloom + 1.2 * K.chord_glow) * c[3]
        for k = -1, 1 do
          local y = ry + k * 2
          local hw = (9 + i * 2) * (1 - math.abs(k) * 0.3)
          K.streaks(l, y, 4, 6, c[1] + k * 2 + i * 3, function(x) return math.abs(x - c[1]) < hw end, nudge2)
        end
      end
    end
    K.surface(0, 42 - floor(nat * 6), 128, 63, 1 + nat * 1.2, 9 - floor(nat * 2), 5 - floor(nat * 1.5))
    -- a swell rolls slow broad bands of light down the pond
    if sw > 0.03 then
      for b = 0, 2 do
        local y = wl + 4 + ((T * 4 + b * 15) % 45)
        local l = sw * (1.2 + 0.5 * sin(T + b))
        for x = (K.drift_x * 0.5 + b * 11) % 12 - 12, 127, 12 do put(l, x, y, 8, 1) end
      end
    end
    -- out_mid: a band of wavelets across the middle water, more and brighter
    -- as the mid range fills
    local nw = floor(mid * 14 + 0.5)
    for k = 1, nw do
      local wx = (WV[k] * 140 + K.drift_x * 0.5 + 6 * sin(T * 0.4 + k)) % 136 - 4
      local wy = 30 + 14 * WV[k + 14] + K.heave(wx) * 0.4
      local l = 1 + 2.2 * mid * (0.6 + 0.4 * sin(T * 1.3 + k * 2))
      put(l, wx - 2, wy, 5, 1); put(l * 0.8, wx, wy - 1, 1, 1)
    end
    -- a sounding motif's band glints faintly along its row
    for s = 1, 4 do
      if K.sounding(S, s) then
        local y = slot_y(s)
        for x = K.drift_x % 8, 127, 8 do put(2, x, y + K.heave(x) * 0.35, 1, 1) end
      end
    end

    -- the rings
    for i = 1, nl do
      local r = live[i]
      local rad, lv = r.rad, r.lv
      local ry = rad * 0.42
      local n = math.max(6, floor(K.TAU * rad * 0.4))
      for k = 0, n - 1 do
        local a = r.a0 + k / n * K.TAU
        local x = r.x + cos(a) * rad
        local y = r.y + sin(a) * ry + K.heave(x) * 0.35
        if x >= 0 and x < 128 and y > wl and y < 64 then put(lv, x, y, 1, 1) end
      end
    end
    -- where two rings cross (circles once the 0.42 squash is undone), the
    -- crossing glows softly
    local glows = 0
    for i = 1, nl - 1 do
      local a = live[i]
      for j = i + 1, nl do
        local b = live[j]
        local dx, dy = b.x - a.x, (b.y - a.y) / 0.42
        local d2 = dx * dx + dy * dy
        local d = math.sqrt(d2)
        if glows < 24 and d > 0.5 and d < a.rad + b.rad and d > math.abs(a.rad - b.rad) then
          local l = (a.rad * a.rad - b.rad * b.rad + d2) / (2 * d)
          local h = math.sqrt(math.max(0, a.rad * a.rad - l * l))
          local mx, my = a.x + dx * l / d, a.y / 0.42 + dy * l / d
          local lv = math.min(a.lv, b.lv) * 0.8 + 1
          for sgn = -1, 1, 2 do
            local x, y = mx + sgn * dy * h / d, (my - sgn * dx * h / d) * 0.42
            y = y + K.heave(x) * 0.35
            if x >= 0 and x < 127 and y > wl and y < 64 then put(lv, x, y, 2, 1); glows = glows + 1 end
          end
        end
      end
    end
    -- slot 3's droplets bounce up from the ring's middle and fall back
    for i = #drops, 1, -1 do
      local d = drops[i]
      local age = T - d.t0
      if age > 0.9 then table.remove(drops, i)
      else
        local h = 9 * sin(math.pi * age / 0.9) * persp(d.y)
        put(7 * (1 - age / 0.9) * ease(age / 0.08), d.x, d.y - h, 1, 1)
      end
    end
    -- water boatmen: tiny dimples, as many as the water sounds
    dimple_acc = dimple_acc + nat * 6 * DTS
    while dimple_acc >= 1 do
      dimple_acc = dimple_acc - 1
      if #dimples < DIMPLE_MAX then
        dimples[#dimples + 1] = {x = 4 + K.rnd() * 120, y = wl + 6 + K.rnd() * 40, t0 = T}
      end
    end
    for i = #dimples, 1, -1 do
      local d = dimples[i]
      local age = T - d.t0
      if age > 1.4 then table.remove(dimples, i)
      else
        local l = (3 + nat * 2) * (1 - age / 1.4) * ease(age / 0.15)
        K.ring(d.x, d.y, 1 + age * 3, 0.45, l, 8)
      end
    end

    -- lily pads: carried slowly by the current, bobbing on the heave and
    -- lifted a pixel as a ring's front passes under them
    for i, p in ipairs(pads) do
      local u = K.flow(p.x, p.y)
      p.x = p.x + u * DTS * 0.35
      if p.x > 140 then p.x = -12 elseif p.x < -12 then p.x = 140 end
      local stir = 0
      if nl > 0 then local _; _, stir = refract(p.x, p.y) end
      local y = p.y + K.heave(p.x) * 0.5 + 0.5 * sin(T * 0.9 + p.ph) - math.min(1.5, stir * 2)
      local x = p.x + sin(T * 0.4 + p.ph) * 0.8
      local l = 3 + math.min(2, stir * 3) + 0.6 * bloom
      put(l, x - 2, y - 1, 5, 1)
      put(l, x - 4, y, 4, 1); put(l, x + 2, y, 3, 1)       -- the notch
      put(l, x - 3, y + 1, 7, 1)
      put(l + 1.5, x - 3, y - 1, 1, 1)                      -- a lit rim
      if i == 1 then put(4 + 3 * bloom, x - 1, y - 2, 2, 1) end -- a bud
    end
    -- the near reeds at the corners: dark stems close to you, swaying fully
    for _, r in ipairs(NEAR) do
      local x0, h = r[1], r[2]
      local lean = (K.flow(x0, 60) * 0.5 + sin(T * 0.8 + r[3]) * (0.8 + 1.5 * K.energy) + K.heave(x0) * 0.6)
      for s = 0, h - 1, 3 do
        local u = s / h
        put(2.5, x0 + lean * u * u, 63 - s - 3, 1, 3)
      end
      put(3.5, x0 + lean, 63 - h - 2, 1, 2)
    end

    -- a moment: a cat's paw of wind runs across the pond, roughening it
    local ma = K.moment_age
    if ma < 12 then
      local e = ease(ma / 1.2) * (1 - ease((ma - 8) / 4))
      local cx = -20 + ma * 14
      for k = 1, #PAW, 2 do
        local x = cx + PAW[k]
        local f = 1 - math.abs(x - cx) / 22
        if f > 0 and x >= 0 and x < 127 then
          put(e * f * (2.5 + 1.5 * sin(T * 9 + k)), x + sin(T * 5 + k) * 1.5, wl + PAW[k + 1], 2, 1)
        end
      end
    end

    -- incidents
    local inc = K.inc
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "fish" then
        -- a fish rises: a silver arc out of the water and back, then rings
        -- (twice: it comes back for another fly)
        for j = 0, 1 do
          local fx, fy = 30 + inc.s * 64 + j * 9, 36 + inc.s2 * 14 + j * 3
          local t0 = 1.5 + j * 3.2
          local a = clamp((inc.age - t0) / 1.3, 0, 1)
          if a > 0 and a < 1 then
            local x, y = fx - 6 + a * 12, fy - 8 * sin(math.pi * a) * persp(fy)
            put(9 * e, x, y, 2, 1); put(5 * e, x - 1 - (a > 0.5 and -2 or 0), y + 1, 1, 1)
            put(3 * e, x, fy, 2, 1)
          end
          for k = 0, 2 do
            local age = inc.age - t0 - 1.3 - k * 0.5
            if age > 0 and age < 4 then
              K.ring(fx + 6, fy, 2 + age * 5 * persp(fy), 0.42, 6 * e * (1 - age / 4) * ease(age / 0.2), 22, 0, wl, 64)
            end
          end
        end
      elseif inc.name == "heron" then
        -- a heron passes low over the pond, its reflection under it
        local dir = inc.s > 0.5 and 1 or -1
        local x = dir > 0 and (-12 + u * 152) or (140 - u * 152)
        local y = 6 + 3 * sin(u * 3) + inc.s2 * 3
        local flap = sin(K.T * 2.6)
        K.bird(x, y, 5 * e, flap, 2)
        put(4 * e, x + dir * 2, y - 1, 2, 1)                 -- the head, tucked
        local ry = wl + (wl - y) + 2
        K.bird(x + K.heave(x) * 0.5, ry, 2.5 * e, -flap, 2)
      else
        -- leaves drop from the tall tree one by one, land, and the current
        -- takes them
        for j = 0, 2 do
          local lx0, ly0 = 20 + j * 3, WL - 9 + j
          local age = inc.age - j * 2.2
          local fall = clamp(age / 3.5, 0, 1)
          local land = 22 + ((inc.s + j * 0.37) % 1) * 14
          if age > 0 then
            local x, y
            if fall < 1 then
              x = lx0 + 5 * sin(fall * 7 + j) + fall * 6
              y = ly0 + fall * land
            else
              local t = age - 3.5
              x = lx0 + 6 + t * (2.5 + K.cur_u * 0.6)
              y = ly0 + land + K.heave(x) * 0.5
              if t < 3 then K.ring(lx0 + 6, ly0 + land, 1.5 + t * 4, 0.42, 4.5 * e * (1 - t / 3), 16) end
            end
            local tilt = fall < 1 and (sin(fall * 14 + j) > 0 and 1 or -1) or 0
            put(7 * e, x - 1, y, 3, 1); put(4.5 * e, x + tilt, y - 1, 2, 1); put(3.5 * e, x + 2, y + 1, 1, 1)
          end
        end
      end
    end
    K.glitter(sample)
  end

  M.init()
  return M
end
