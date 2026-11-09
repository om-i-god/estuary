-- pod: the open sea from a headland on a bright day, a pod of whales
-- passing far out. a high pale sky with long clouds, the far line of the
-- horizon, the sea's swell coming in, and the headland's grassy shoulder
-- close by in the corner. the chord is four sun paths on the sea, glints
-- running from the far line toward you across by pitch, brighter as the
-- chord holds them, sliding to their new places when it moves. a note is a
-- whale at its pitch's place along the horizon, by motif: a spout (the
-- first), a fluke lifting and sinking (the second), two spouts together
-- (the third), a long back rolling over in a glint (the fourth). out_lo is
-- the swell, out_amp how fast it comes in, out_mid the wind's cat's paws
-- on the water, out_hi the glitter, and the water sounds are whitecaps on
-- the crests and spray at the headland's foot. the bloom is the day: the
-- sky and the sea's sheen brighten; the bar breathes in the sheen; a swell
-- is a set of big rollers coming in and breaking white against the rocks.
-- a passing moment sends a line of dolphins arcing through the near
-- water. now and then a whale breaches far out, a sailboat crosses, or
-- gannets fold and dive
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, cos, floor, abs = math.sin, math.cos, math.floor, math.abs

  M.incidents = {{"breach", 16}, {"sail", 24}, {"gannets", 14}}

  local HZ = 22                           -- the horizon
  local MARK_MAX = 4
  local marks
  local roll = 0                          -- the swell's run, integrated

  -- the headland's shoulder in the bottom-left corner: its top, smooth
  local function head_top(x)
    if x > 57 then return 99 end
    local u = math.max(0, x) / 57
    return 40 + 24 * u ^ 1.7 + 1.2 * sin(x * 0.37) - 2 * (1 - u)
  end
  local head = K.profile(head_top)
  -- a dithered mass of turf and rock under a lit lip; the lip shares its
  -- light between the two rows it lies across, so the edge never steps
  local headland = K.bake(function(rec)
    local k = 0
    for x = 0, 57 do
      local t = head_top(x)
      if t < 64 then
        local ti = floor(t)
        local f = t - ti
        rec(3.8 * (1 - f) + 0.3 * K.hash(x, 1701), x, ti, 1, 1)
        rec(3.8 * f + 2.2 * (1 - f), x, ti + 1, 1, 1)
        rec(2, x, ti + 2, 1, 1)
      end
    end
    for y = 40, 63 do
      local x = 0
      while x < 58 do
        k = k + 1
        local len = 1 + floor(2 * K.hash(k, 1702))
        local t = head_top(x)
        if y > t + 2.5 and K.hash(k, 1703) < 0.26 - (y - t) * 0.004 then
          rec(K.hash(k, 1704) < 0.3 and 1.8 or 1.1, x, y, math.min(len, 58 - x), 1 + (K.hash(k, 1705) < 0.4 and 1 or 0))
        end
        x = x + len
      end
    end
  end)
  -- the sea's rows stop at the headland
  local F_y = 0
  local function keep_sea(x) return head_top(x) > F_y + 1 end
  -- grass along the headland's edge, close by: {x, height, phase}
  local GRASS = {}
  for k = 1, 9 do
    local x = 1 + (k - 1) * 5.6 + 2 * K.hash(k, 1705)
    GRASS[k] = {x, 3 + 5 * K.hash(k, 1706), K.hash(k, 1707) * 6}
  end
  -- the long clouds, baked and slid slowly round
  local clouds = K.bake(function(rec)
    for k = 1, 5 do
      local cx, cy, w = 128 * K.hash(k, 1708), 3 + 12 * K.hash(k, 1709), 20 + 24 * K.hash(k, 1710)
      rec(1.5, cx - w * 0.5, cy, w, 1)
      rec(2.2, cx - w * 0.3, cy, w * 0.5, 1)
      rec(1, cx - w * 0.35, cy + 1, w * 0.7, 1)
    end
  end)
  local GLINT = K.scatter(72, 2, HZ + 2, 126, 62, 1711)
  -- the pod: whales surfacing now and then along the far line {x, phase}
  local POD = {{30, 0.1}, {44, 0.5}, {58, 0.3}, {75, 0.8}, {90, 0.65}}

  function M.init() marks, roll = {}, 0 end
  function M.clear() marks = {} end

  function M.note(slot, midi)
    K.cap_add(marks, {slot = slot, x = K.px(midi), t0 = K.T}, MARK_MAX)
  end

  local function sample(u, v) return 48 + u * 78, HZ + 2 + v * 38 end

  -- a whale's spout at sx on the far line y, s its light
  -- (a low plume far off: a puff of mist that rises a few pixels,
  -- spreads and drifts downwind as it thins)
  local function spout(sx, y, s, age)
    local m = ease(age / 1.2)
    local h = 2 + 4 * m
    local dx = age * 1.6
    for q = 0, 8 do
      local a = q * 0.7 + age * 0.8
      local r = 0.8 + 2.4 * m * (0.6 + 0.4 * (q % 3) / 2)
      put(s * (8.5 - q * 0.35) * (1 - 0.25 * m), sx + dx * (0.4 + q * 0.08) + cos(a) * r, y - 1 - h * (0.3 + 0.08 * q) - sin(a) * r * 0.5, 2, 1)
    end
  end

  local F_sky = 1
  local function sky(y) return F_sky * (0.08 + 0.28 * (y / HZ) ^ 1.6) end

  -- a row of the sea: its depth 0 (far line) .. 1 (near), and the swell
  local function rowy(k) return HZ + 1 + (k * 0.55) ^ 1.45 end

  function M.draw()
    local T = K.T
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local hi, mid, nat, lo, amp = A[K.HI], A[K.MID], A[K.NAT], A[K.LO], A[K.AMP]
    roll = roll + K.DTS * (2 + 4 * amp + 2.5 * sw)
    -- the sky, paler toward the far line, the clouds drifting
    F_sky = 0.8 + 0.4 * bloom + 0.5 * breath
    K.gradient(0, HZ - 1, sky)
    K.blit(clouds, 1 + 0.6 * bloom, K.drift_x * 0.05 + T * 0.3, true, true)
    K.streaks(2.6 + bloom + breath, HZ, 12, 13, 3)
    -- the sea: swell lines coming in, closer together far off, heaving
    -- with out_lo; whitecaps on their crests with the water sounds
    for k = 1, 22 do
      local y = rowy(k)
      if y > 63 then break end
      local d = (y - HZ) / 42
      -- (the near water a little sparser: every third row from the
      -- thirteenth on is left out)
      if not (k > 12 and k % 3 == 0) then
      local hv = K.heave(k * 13) * (0.3 + 1.2 * lo) * d
      local yy = y + hv
      local off = roll * (0.3 + 0.9 * d) + k * 17.3 + K.drift_x * 0.2
      local l = 1.2 + 0.7 * bloom + 1.2 * breath * (1 - d * 0.5)
      F_y = yy
      K.streaks(l, yy, 2 + d * 4, 15 + floor(d * 18), off, keep_sea, nil, 0, 128)
      if nat > 0.02 then
        local caps = sin(k * 1.7 + roll * 0.2)
        if caps > 0 then
          -- (each cap keeps its own small offset as it rides along)
          local c = K.ramp(caps, 0, 0.5) * nat
          local o = off * 1.3
          local n0 = -floor(o / 23)
          for x = o % 23, 127, 23 do
            local cx = x + (K.hash(n0 + k * 31, 1712) - 0.5) * 4
            if head_top(cx) > yy + 1 then put(c * (5 + 3 * d), cx, yy - 1, 1 + floor(d * 2), 1) end
            n0 = n0 + 1
          end
        end
      end
      end
    end
    -- out_mid: cat's paws, small patches of wind-roughened water
    if mid > 0.02 then
      for k = 0, 8 do
        local cx = (k * 37 + T * (2 + k % 3)) % 150 - 10
        local cy = HZ + 5 + (k * 13) % 34
        for q = 0, 5 do
          local px_ = cx + q * 3 - 6
          if head_top(px_) > cy + 2 then put(mid * (4 + 4.5 * sin(T * 3 + q + k)), px_, cy + (q % 2), 2, 1) end
        end
      end
    end
    -- the chord: four sun paths from the far line toward you
    for i = 1, 4 do
      local m, p = K.chord_at(i)
      if m and p > 0.02 then
        local x0 = K.cx(m)
        local l = (2.5 + 3.5 * K.chord_glow + 1.2 * bloom + breath) * p
        for k = 1, 18 do
          local y = rowy(k)
          if y > 63 then break end
          local d = (y - HZ) / 42
          local f = 0.55 + 0.45 * sin(T * (1.5 + i * 0.3) + k * 1.9 + i)
          local hw = 1 + d * 3
          local sx = x0 - hw + sin(k * 2.1 + T * 0.7) * d * 3
          if head_top(sx) > y + 2 and head_top(sx + hw * 2) > y + 2 then
            K.dash(l * f * (1.1 - d * 0.5) + K.bj(k + i * 32) * 0.4, sx, y + 1, floor(hw * 2))
          end
        end
      end
    end
    K.twinkle(GLINT, hi, 13)
    -- the pod far out: backs rising now and then along the far line
    for k, w in ipairs(POD) do
      local ph = (T * 0.05 + w[2]) % 1
      if ph < 0.18 then
        local a = ph / 0.18
        local e = sin(math.pi * a)
        local x = w[1] + K.drift_x * 0.02 + a * 4
        put(3.5 * e, x - 2, HZ + 1 - e, 5, 1)
        put(2.5 * e, x - 1, HZ - e * 1.5, 2, 1)
      end
    end
    -- the headland and its grass, close by
    K.blit(headland, 1 + 0.4 * bloom)
    for k, g in ipairs(GRASS) do
      local base = K.at(head, g[1])
      local lean = sin(T * 0.8 + g[3]) * (0.5 + 2 * nat) + K.heave(g[1]) * 0.4 + 1
      put(2.6 + bloom + K.bj(k) * 0.4, g[1], base - g[2] * 0.5, 1, g[2] * 0.5 + 1)
      put(2.8 + bloom, g[1] + lean, base - g[2], 1, g[2] * 0.5)
    end
    -- spray at the headland's foot: the water sounds, and a swell's rollers
    -- breaking white against the rocks
    local br = nat * 0.6 + sw
    if br > 0.02 then
      for q = 0, 11 do
        local ph = (T * (0.7 + 0.1 * (q % 4)) + q * 0.19) % 1
        local x = 38 + q * 1.6 + ph * 6
        local y = K.at(head, x - 6) - 1 - sin(math.pi * ph) * (4 + 8 * sw)
        put(br * 6 * sin(math.pi * ph), x, y, 2, 1)
      end
    end
    if sw > 0.02 then
      -- the set of big rollers coming in
      for b = 0, 2 do
        local ph = ((T * 7 + b * 13) % 40) / 40
        local y = HZ + 6 + ph * 40
        local d = (y - HZ) / 42
        if y < 63 then
          -- (each roller rises out of the far water and sinks into the near:
          -- it never jumps back to the top)
          local l = sw * (2.5 + 2 * d) * sin(math.pi * ph)
          for x = (K.drift_x * 0.4 + b * 11) % 14 - 14, 127, 14 do
            -- (shared between the rows it lies across: it rolls in, never hops)
            if K.at(head, x) > y then K.vshare(l, x, floor(y), 8, y - floor(y)) end
          end
        end
      end
    end
    -- the notes: whales along the far line at their pitch
    for i = #marks, 1, -1 do
      local mk = marks[i]
      local age = T - mk.t0
      local cf, done = K.cap_fade(mk)
      if age > 5 or done then table.remove(marks, i)
      else
        local e = ease(age / 0.3) * (1 - ease((age - 2.5) / 2.5)) * cf
        local x = mk.x
        local y = HZ + 1
        put(6 * e, x - 5, y, 11, 1)                         -- its back
        if mk.slot == 1 then
          spout(x, y, e, age)
        elseif mk.slot == 2 then
          local lift = sin(math.pi * clamp(age / 3, 0, 1))
          -- (a broad tail rising out and sinking, water streaming off it)
          put(7 * e, x - 1, y - 1 - lift * 5, 3, 1 + lift * 4)
          put(9 * e * lift, x - 5, y - 2 - lift * 5, 4, 1); put(9 * e * lift, x + 2, y - 2 - lift * 5, 4, 1)
          put(6 * e * lift, x - 6, y - 3 - lift * 5, 2, 1); put(6 * e * lift, x + 5, y - 3 - lift * 5, 2, 1)
          for q = -2, 2 do put(4 * e * lift, x + q * 2, y - 1 - lift * (2 + (q % 2)), 1, 1) end
        elseif mk.slot == 3 then
          spout(x - 6, y, e, age); spout(x + 6, y, e * 0.9, age + 0.4)
          put(7 * e, x - 9, y, 19, 1); put(4 * e, x - 7, y + 1, 15, 1)
        else
          local a = clamp(age / 2.5, 0, 1)
          for q = 0, 6 do
            local u = q / 6
            put(7 * e * sin(math.pi * u), x - 6 + q * 2 + a * 4, y - sin(math.pi * u) * 2 * sin(math.pi * a), 2, 1)
          end
        end
        -- its light lying on the water toward you
        for d = 1, 7 do put(5.5 * e * (1 - d / 8), x - 2 - d * 0.3, y + d * 2, 5 + d * 0.6, 1) end
      end
    end
    -- the moment: dolphins arcing through the near water in a line
    local ma = K.moment_age
    if ma < 14 then
      local e = ease(ma / 2) * (1 - ease((ma - 9) / 5))
      for k = 0, 8 do
        local x = 150 - ma * 11 + k * 9
        local a = ((ma * 0.9 + k * 0.23) % 1)
        local y = 50 + k * 1.5 - sin(math.pi * a) * 5
        if a < 0.7 and x > 44 and x < 128 then
          -- (each glides at a fraction of a pixel, its back sharing its
          -- light between the rows it arcs across)
          local yi = floor(y)
          local fy = y - yi
          K.dash(7.5 * e * (1 - fy), x - 4, yi, 8, 2); K.dash(7.5 * e * fy, x - 4, yi + 1, 8, 2)
          K.dash(6.5 * e, x - 1, yi - 2, 2, 2)
          K.dash(5.5 * e, x + 3, yi + 1, 3, 1)
        end
        local ra = a - 0.7
        if ra > 0 then K.ring(x, 52 + k * 1.5, 1 + ra * 8, 0.3, 5 * e * (1 - ra / 0.3), 10) end
      end
    end
    -- incidents
    local inc = K.inc
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "breach" then
        -- a whale rises slowly out of the sea far off and falls back
        local x = 50 + inc.s * 50
        local a = clamp((inc.age - 3) / 5, 0, 1)
        local h = sin(math.pi * a) * 9
        if a > 0 and a < 1 then
          local ae = ease(a / 0.15) * ease((1 - a) / 0.15)
          for q = 0, floor(h * 1.3) + 1 do put((8 - q * 0.25) * e * ae * clamp(h * 1.3 - q + 1, 0, 1), x - 2 + q * 0.3, HZ + 1 - q, 5, 1) end
          put(9 * e * ae, x - 3 + h * 0.4, HZ - h * 1.3, 6, 2)
        end
        if a > 0.5 then
          local s = (a - 0.5) * 2
          for q = -3, 3 do put(6 * e * (1 - s * 0.6), x + q * 2 * (1 + s), HZ - sin(math.pi * s) * (4 - abs(q)), 1, 1) end
        end
        if a >= 1 then
          local ra = inc.age - 8
          if ra < 4 then K.ring(x, HZ + 2, 2 + ra * 4, 0.25, 5 * e * (1 - ra / 4), 16) end
        end
      elseif inc.name == "sail" then
        -- a sailboat crosses, its sail catching the sun
        local x = 140 - u * 100
        local y = HZ + 6 + inc.s * 4
        for q = 0, 4 do put((8.5 - q * 0.6) * e, x + q, y - 9 + q * 2, 1, 9 - q * 2) end
        put(6 * e, x - 4, y, 10, 1)
        for d = 1, 3 do put(2.5 * e, x - 3 + K.heave(x + d) * 0.4, y + d * 1.5, 8, 1) end
      else
        -- gannets wheel over the water, fold and dive, splashes after
        for k = 0, 4 do
          local t = inc.age - k * 1.6
          local x = 60 + k * 11 + inc.s * 10
          local dive = clamp((t - 2) / 0.8, 0, 1)
          if t > 0 and dive < 1 then
            local y = 10 + sin(t * 1.3 + k) * 3 + dive * dive * (HZ + 14)
            -- (it folds: the wheeling bird and the diving dart crossfade)
            local fold = ease(dive / 0.25)
            local ge = e * ease(t / 0.6)
            if fold < 1 then K.bird(x + sin(t + k) * 6, y, 9 * ge * (1 - fold), sin(K.NOW * 5 + k), 2) end
            -- (and the dart fades into its splash)
            local de = ge * fold * (1 - ease((dive - 0.75) / 0.25))
            if fold > 0 then put(9 * de, x, y - 2, 1, 3); put(6 * de, x - 1, y - 3, 3, 1) end
          end
          local ra = t - 2.8
          if ra > 0 and ra < 2.5 then
            put(9 * e * (1 - ra / 2.5) * ease(ra / 0.2), x - 1, HZ + 12 - ra * 3, 3, 2 + ra)
            K.ring(x, HZ + 14, 2 + ra * 5, 0.3, 7 * e * (1 - ra / 2.5) * ease(ra / 0.2), 14)
          end
        end
      end
    end
    K.glitter(sample, 32)
  end

  M.init()
  return M
end
