-- ripples: a still pond under a far bank, the sky lying in it. each note
-- drops a ring where its pitch is, in its motif's band (further bands are
-- further away, so their rings are smaller); rings drift with the current,
-- glow where they cross and bend the reflection as they pass. echoes follow
-- at the echo time. ring brightness rides out_amp, so a reverb tail keeps
-- the surface alive. two lily pads bob on the rings
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease

  local ECHO_BEATS = {0.5, 1, 1.5, 2}     -- same order as the echo time param
  local RING_MAX, RING_R = 16, 28
  local WL = 16                           -- the far waterline
  local rings, pending, live, nl = {}, {}, {}, 0
  local pads
  function M.init()
    M.clear()
    pads = {{x = 30, y = 37, ph = 0.3}, {x = 92, y = 52, ph = 2.1}}
  end

  -- the far bank: a soft tree line, one taller tree to the left
  local trees = K.crowns(5, 14, WL, 2, 6, 4, 8)
  local bank = K.profile(function(x)
    local tall = 9 * math.max(0, 1 - math.abs(x - 22) / 7) ^ 0.6
    return math.min(trees(x), WL - 1 - tall) - 0.6 * math.sin(x * 0.9)
  end)

  local function slot_y(slot) return 21 + (slot - 1) * 11 end
  -- nearer water is bigger: rings scale with their distance down the pond
  local function persp(y) return 0.5 + 0.5 * clamp((y - WL) / 50, 0, 1) end

  local function add_ring(x, y, lvl)
    rings[#rings + 1] = {x = x, y = y, t0 = K.T, lvl = lvl, a0 = K.rnd() * K.TAU, rad = 0, lv = 0}
    if #rings > RING_MAX then table.remove(rings, 1) end
  end

  function M.clear() rings, pending, live, nl = {}, {}, {}, 0 end

  function M.note(slot, midi)
    local x, y = K.px(midi), slot_y(slot)
    add_ring(x, y, 1)
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
  -- much they stir it): a ring's front shoves what it passes
  local function refract(x, y)
    local dx, stir = 0, 0
    for i = 1, nl do
      local r = live[i]
      local ex, ey = x - r.x, (y - r.y) / 0.42
      local d = math.sqrt(ex * ex + ey * ey)
      local f = d - r.rad
      if f > -3 and f < 3 then
        local s = (1 - math.abs(f) / 3) * r.lv / 8
        dx = dx + (ex >= 0 and 1 or -1) * s * 2.5
        stir = stir + s
      end
    end
    return dx, stir
  end

  local function sample(u, v) return u * 127, WL + 3 + v * 46 end

  function M.draw(S)
    local T, DTS = K.T, K.DTS
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
    nl = 0
    for i = #rings, 1, -1 do
      local r = rings[i]
      local age = T - r.t0
      local sc = persp(r.y)
      local rad = age * 8.5 * sc
      local life = rad / (RING_R * sc)
      if life >= 1 or r.x < -RING_R or r.x > 128 + RING_R then
        table.remove(rings, i)
      else
        local u, v = K.flow(r.x, r.y)
        r.x, r.y = r.x + u * DTS, clamp(r.y + v * DTS * 0.42, WL + 4, 62)
        r.rad, r.lv = rad, 8 * r.lvl * (1 - life) ^ 1.4 * amp * ease(age / 0.18)
        if r.lv >= 0.5 and rad >= 1 then nl = nl + 1; live[nl] = r end
      end
    end

    -- the sky: a glow down to the bank, brighter as the bloom opens, the
    -- trees dark against it
    local sky = 1.2 + 0.9 * K.bloom
    local function skylv(y) return sky * (0.3 + 1.4 * (y / WL) ^ 2) end
    K.gradient(0, WL - 1, skylv, bank)
    put(1 + K.bar_pulse, 0, WL, 128, 1)
    -- the bank and the sky lie in the water: the sky's glow comes back
    -- below the trees' reflection, then long pale streaks thin out toward
    -- you; rings bend and stir them
    local function nudge(x, y)
      local dx, stir = refract(x, y)
      return dx + K.heave(x) * 0.3, stir * 4
    end
    for d = 1, 26 do
      local y = WL + d
      local near = d < WL
      if (near and d % 2 == 1) or (not near and d % (2 + (d - WL) // 4) == 0) then
        local keep = near and function(x) return WL - d < K.at(bank, x) end or nil
        local l = near and skylv(WL - d) * 0.75 or sky * 0.9 * (1 - (d - WL) / 16)
        local w, gap = near and 13 or (5 + d // 4), near and 15 or (13 + d)
        K.streaks(l, y, w, gap, K.drift_x * (0.3 + d * 0.02) + d * 7.3 + math.sin(K.T * 0.3 + d) * 2, keep, nudge)
      end
    end
    K.surface(0, 42, 128, 63, 1, 9, 5)
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
      local n = math.max(6, math.floor(K.TAU * rad * 0.4))
      for k = 0, n - 1 do
        local a = r.a0 + k / n * K.TAU
        local x = r.x + math.cos(a) * rad
        local y = r.y + math.sin(a) * ry + K.heave(x) * 0.35
        if x >= 0 and x < 128 and y > WL and y < 64 then put(lv, x, y, 1, 1) end
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
            if x >= 0 and x < 127 and y > WL and y < 64 then put(lv, x, y, 2, 1); glows = glows + 1 end
          end
        end
      end
    end

    -- lily pads: carried slowly by the current, bobbing on the heave and
    -- lifted a pixel as a ring's front passes under them
    for i, p in ipairs(pads) do
      local u = K.flow(p.x, p.y)
      p.x = p.x + u * DTS * 0.35
      if p.x > 140 then p.x = -12 elseif p.x < -12 then p.x = 140 end
      local _, stir = refract(p.x, p.y)
      local y = p.y + K.heave(p.x) * 0.4 + 0.5 * math.sin(T * 0.9 + p.ph) - math.min(1.5, stir * 2)
      local x = p.x + math.sin(T * 0.4 + p.ph) * 0.8
      local l = 3 + math.min(2, stir * 3)
      put(l, x - 2, y - 1, 5, 1)
      put(l, x - 4, y, 4, 1); put(l, x + 2, y, 3, 1)       -- the notch
      put(l, x - 3, y + 1, 7, 1)
      put(l + 1.5, x - 3, y - 1, 1, 1)                      -- a lit rim
      if i == 1 then put(4 + 3 * K.bloom, x - 1, y - 2, 2, 1) end -- a bud
    end
    K.glitter(sample)
  end

  M.init()
  return M
end
