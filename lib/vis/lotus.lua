-- lotus: a lotus pond seen from just above the water. a soft far bank lies
-- along the top with the sky in the water below it, and the pond is
-- strewn with round leaves, small and flat far off, broad close by, a few
-- buds standing up between them. the chord is the four largest leaves
-- catching the light: each lit along its rim at a place set by its tone
-- (further round for a higher tone), the light sliding round when the
-- chord moves. a note opens a flower on the water at its pitch, by motif:
-- a bud (the first), a half-open cup (the second), a full flower (the
-- third), a full flower that lets a petal drift off (the fourth). out_lo
-- rocks the leaves on the water, out_mid sets small ripples running
-- between them, out_amp keeps the reflections moving, out_hi glints as dew
-- on the leaves, and the water sounds are dragonfly wings shimmering over
-- the pond and small rings where things touch the water. the bloom is
-- daylight on the pond; the bar breathes in the sky's reflection; a swell
-- is a breeze that lifts the leaves' edges and runs light across them. a
-- passing moment opens every standing bud for a while. now and then a frog
-- leaps from leaf to leaf, a dragonfly settles on a bud, or a petal falls
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, cos, floor, abs = math.sin, math.cos, math.floor, math.abs

  M.incidents = {{"frog", 14}, {"dragonfly", 16}, {"petal", 18}}

  local BANK = 10                         -- the far bank's foot
  local MARK_MAX = 6
  local OPEN_TO = {0.1, 0.55, 1, 1}      -- how far each motif's flower opens
  local marks

  -- the far bank: a soft line of trees, baked once
  local trees = K.crowns(1501, 12, BANK, 3, 7, 5, 9)
  local bprof = K.profile(function(x) return trees(x) end)
  local bank = K.bake(function(rec)
    for c = 0, 63 do
      local t = floor(bprof[c] + 0.5)
      if t < BANK then
        rec(1.6, c * 2, t, 2, 1)
        for y = t + 2, BANK - 1, 2 do
          if K.hash(c * 64 + y, 1502) < 0.3 then rec(1, c * 2 + (y // 2) % 2, y, 1, 1) end
        end
      end
    end
  end)
  -- the leaves: {x, y, radius, phase}; nearer (lower) is bigger. the four
  -- largest (1..4) carry the chord
  local LEAF = {
    {22, 50, 9.5, 0.3}, {58, 56, 10.5, 1.7}, {94, 49, 9.5, 3.1}, {118, 58, 8, 4.4},
    {8, 34, 5.5, 0.9}, {40, 38, 6, 2.2}, {75, 36, 6, 5.1}, {105, 33, 5.5, 1.4},
    {28, 24, 4, 3.8}, {60, 22, 4, 0.6}, {88, 25, 4.5, 2.7}, {116, 21, 3.5, 4.9},
    {12, 18, 2.5, 1.1}, {47, 16, 2.5, 5.6},
  }
  -- buds standing up between the leaves: {x, y, height}
  local BUD = {{36, 45, 6}, {78, 44, 7}, {103, 40, 5}, {14, 40, 5}, {66, 30, 4}}
  local DEW = {}
  for k = 1, 12 do
    local L = LEAF[k]
    for q = 1, 8 do
      DEW[#DEW + 1] = floor(L[1] + (K.hash(k * 8 + q, 1503) - 0.5) * L[3] * 1.4)
      DEW[#DEW + 1] = floor(L[2] + (K.hash(k * 8 + q, 1504) - 0.5) * L[3] * 0.5)
    end
  end
  local WING = K.scatter(48, 4, 14, 124, 50, 1505)

  function M.init() marks = {} end
  function M.clear() marks = {} end

  function M.note(slot, midi)
    local x = K.px(midi)
    local y = 46 - K.pu(midi) * 20
    K.cap_add(marks, {slot = slot, x = x, y = y, t0 = K.T}, MARK_MAX)
  end

  local function sample(u, v) return 4 + u * 120, BANK + 3 + v * 50 end

  -- a leaf from just above the water: a flattened disc with a thin slit to
  -- its stem, lit along its far rim; lift raises its near edge (a breeze)
  local function leaf(x, y, r, l, lift, dir)
    local ry = r * 0.42
    local rows = math.max(1, floor(ry + 0.5))
    for dy = -rows, rows do
      local hw = r * math.sqrt(math.max(0, 1 - (dy / (ry + 0.5)) ^ 2))
      if hw >= 0.5 then
        local ll = l * (dy == -rows and 1.25 or (dy > 0 and 0.85 + 0.3 * lift or 1))
        local sx = floor(x + dir * 1.2 * dy)
        if dy <= 0 and dy > -rows and sx > x - hw + 1 and sx < x + hw - 1 then
          put(ll, x - hw, y + dy, sx - (x - hw), 1)
          put(ll, sx + 1, y + dy, x + hw - sx - 1, 1)
        else
          put(ll, x - hw, y + dy, hw * 2, 1)
        end
      end
    end
  end

  -- a flower opening on the water: o = 0 bud .. 1 full
  local function flower(x, y, o, l)
    if l < 0.3 then return end
    l = math.min(l, 10.5)
    -- its stem and the pad of water round it
    put(l * 0.35, x - 3, y + 1, 7, 1)
    if o < 0.35 then
      -- a bud: a closed point standing up
      put(l * 0.8, x - 1, y - 3, 3, 3); put(l, x, y - 5, 1, 2)
    elseif o < 0.75 then
      -- a cup: petals parted, a lit heart
      put(l * 0.8, x - 3, y - 3, 2, 3); put(l * 0.8, x + 2, y - 3, 2, 3)
      put(l * 0.9, x - 1, y - 2, 3, 2); put(l, x, y - 4, 1, 2)
      put(l * 0.6, x - 4, y - 4, 1, 1); put(l * 0.6, x + 4, y - 4, 1, 1)
    else
      -- full: petals spread round a bright heart
      for q = 0, 7 do
        local a = q / 8 * K.TAU
        put(l * (0.7 + 0.2 * (q % 2)), x + cos(a) * 4, y - 2 + sin(a) * 2, 2, 1)
      end
      put(l * 0.85, x - 2, y - 3, 5, 2)
      put(math.min(12, l * 1.2), x, y - 3, 1, 1)
    end
  end

  local F_sky = 1
  local function water(y) return F_sky * math.max(0, 1 - (y - BANK) / 13) ^ 1.5 end

  function M.draw()
    local T = K.T
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local hi, mid, nat, lo, amp = A[K.HI], A[K.MID], A[K.NAT], A[K.LO], A[K.AMP]
    -- the sky's band above the bank, and lying in the water under it
    for y = 0, BANK - 1 do K.dither_row((0.15 + 0.22 * bloom + 0.4 * breath) * (0.4 + y / BANK * 0.6), y, bprof) end
    K.blit(bank, 1 + 0.4 * bloom)
    F_sky = 0.3 + 0.25 * bloom + 0.6 * breath
    K.gradient(BANK + 1, BANK + 12, water)
    -- the water: slow reflected streaks, moving with out_amp
    for y = BANK + 3, 63, 5 do
      local d = (y - BANK) / 54
      K.streaks(1.1 + 0.5 * bloom + 0.8 * breath * (1 - d), y, 4 + d * 6, 13 + floor(d * 8), K.drift_x * (0.2 + d * 0.5) + y * 6.7 + T * (1.4 + 1.6 * amp))
    end
    K.surface(0, BANK + 14, 128, 64, 1, 16, 6, 2, nat * 0.5)
    -- out_mid: small ripples running between the leaves
    if mid > 0.02 then
      for k = 0, 21 do
        local x = (k * 23 + T * (4 + k % 3)) % 136 - 4
        local y = 16 + (k * 11) % 46
        local f = 0.5 + 0.5 * sin(T * 1.7 + k)
        K.dash(mid * (3.5 + 5 * f), x, y + K.heave(x) * 0.4, 5)
        put(mid * 2.5 * f, x + 1, y + 1, 3, 1)
      end
    end
    -- the leaves, far to near, rocking on the water with out_lo; a swell's
    -- breeze lifts their edges and runs light across them
    local ma = K.moment_age
    for k = #LEAF, 1, -1 do
      local L = LEAF[k]
      local bob = sin(T * 0.7 + L[4]) * (0.5 + 1.4 * lo) + K.heave(L[1]) * 0.5
      local tilt = sw * (0.6 + 0.4 * sin(T * 1.3 + L[4]))
      local run = sw > 0.02 and sw * 3 * math.max(0, sin(L[1] * 0.08 - T * 2.2)) or 0
      local l = (1.6 + 0.9 * bloom + 0.9 * breath + 0.35 * L[3] / 6 + run) * (k <= 4 and 1.15 or 1)
      -- (the four largest catch the light as high as their tone)
      if k <= 4 then
        local m, p = K.chord_at(k)
        if m then l = l + (0.6 + 2.6 * clamp((m - 36) / 40, 0, 1) + 1.4 * K.chord_glow) * p end
      end
      leaf(L[1] + sin(T * 0.4 + L[4]) * lo, L[2] + bob - tilt, L[3], l + K.bj(k * 9) * 0.3, tilt, k % 2 == 0 and 1 or -1)
      -- (and the chord's light along the rim of the four largest)
      if k <= 4 then
        local m, p = K.chord_at(k)
        if m and p > 0.02 then
          local a = math.pi * (1.05 + 0.9 * clamp((m - 36) / 40, 0, 1))
          local cl = (4 + 3 * K.chord_glow + 1.2 * breath) * p
          for q = -2, 2 do
            local aa = a + q * 0.18
            K.dash(cl * (1 - abs(q) * 0.22), L[1] + cos(aa) * L[3] - 1, L[2] + bob - tilt + sin(aa) * L[3] * 0.42, 3)
          end
        end
      end
    end
    K.twinkle(DEW, hi, 13)
    -- the buds standing between the leaves (the moment opens them all)
    local open = ma < 16 and ease(ma / 3) * (1 - ease((ma - 11) / 5)) or 0
    for k, b in ipairs(BUD) do
      local sway = sin(T * 0.6 + k) * (0.3 + 1.2 * lo)
      local x, y = b[1] + sway * 0.5, b[2]
      put(2.2 + 0.6 * bloom, x, y - b[3], 1, b[3])
      if open > 0.02 then
        flower(x + sway * 0.5, y - b[3] + 1, open, (5 + 3 * bloom) * (0.4 + 0.6 * open))
      end
      if open < 0.98 then
        local bl = (3.6 + 1.2 * bloom) * (1 - open)
        put(bl, x - 1 + sway * 0.5, y - b[3] - 3, 3, 3); put(bl * 1.2, x + sway * 0.5, y - b[3] - 5, 1, 2)
      end
    end
    -- the water sounds: dragonfly wings shimmering over the pond, small
    -- rings where things touch the water
    if nat > 0.02 then
      for i = 1, #WING, 2 do
        local w = sin(T * 6.3 + i * 1.7) * sin(T * 1.9 + i)
        if w > 0 then put(nat * 15 * w, WING[i], WING[i + 1], 3, 1) end
      end
      for k = 0, 3 do
        local ph = (T * 0.5 + k * 0.29) % 1
        K.ring(16 + k * 31 + 8 * sin(k * 2.3), 30 + (k * 9) % 26, 1 + ph * 6, 0.42, nat * 5 * (1 - ph) * ease(ph / 0.1), 12)
      end
    end
    -- the notes: flowers opening on the water at their pitch
    for i = #marks, 1, -1 do
      local mk = marks[i]
      local age = T - mk.t0
      local cf, done = K.cap_fade(mk)
      if age > 6 or done then table.remove(marks, i)
      else
        local e = ease(age / 0.4) * (1 - ease((age - 3.5) / 2.5)) * cf
        local want = OPEN_TO[mk.slot] or 1
        local o = want * ease(age / 1.4)
        flower(mk.x, mk.y, o, (9 + 2 * bloom) * e)
        flower(mk.x + 1, mk.y, o, (6 + bloom) * e)
        if mk.slot == 1 then
          -- a bud pushing up: its stem shivers, no ring
          put(9 * e, mk.x, mk.y - 1, 1, 5)
          put(6 * e, mk.x - 2, mk.y + 1, 5, 1)
          K.ring(mk.x, mk.y + 1, 2 + age * 1.5, 0.42, 8.5 * e * math.max(0, 1 - age / 3), 10)
        elseif mk.slot == 2 then
          K.ring(mk.x, mk.y + 1, 3 + age * 3, 0.42, 7 * e * math.max(0, 1 - age / 3), 16)
        elseif mk.slot == 3 then
          K.ring(mk.x, mk.y + 1, 4 + age * 6, 0.42, 7 * e * math.max(0, 1 - age / 3), 20)
          K.ring(mk.x, mk.y + 1, 2 + age * 3, 0.42, 5 * e * math.max(0, 1 - age / 3), 12)
          put(11 * e, mk.x, mk.y - 3, 1, 1)
        end
        if mk.slot == 4 then
          -- petals drift off on the water, a wide ring under them
          for q = 0, 2 do
            local a = math.max(0, age - 0.4 - q * 0.3)
            put(8 * e, mk.x + 4 + a * (4 + q), mk.y - 1 + sin(a * 2 + q) * 1.5 + a * (0.8 - q * 0.6), 2, 1)
          end
          K.ring(mk.x, mk.y + 1, 5 + age * 6, 0.42, 5 * e * math.max(0, 1 - age / 3), 20)
        end
      end
    end
    -- incidents
    local inc = K.inc
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "frog" then
        -- a frog sits on a leaf, then leaps to the next
        local A1, A2 = LEAF[1 + floor(inc.s * 4) % 4], LEAF[1 + (floor(inc.s * 4) + 1) % 4]
        local hop = clamp((inc.age - 0.45 * inc.dur) / 1.2, 0, 1)
        local h = ease(hop)
        local x = A1[1] + (A2[1] - A1[1]) * h
        local y = A1[2] - 2 + (A2[2] - A1[2]) * h - sin(math.pi * hop) * 10
        local thr = 0.5 + 0.5 * sin(K.T * 3)
        put(9 * e, x - 4, y - 3, 9, 4); put(8 * e, x - 5, y, 1, 2); put(8 * e, x + 5, y, 1, 2)
        put(10 * e, x - 2, y - 4, 1, 1); put(10 * e, x + 2, y - 4, 1, 1)
        put((5 + 2 * thr) * e, x - 2, y + 1, 5, 1)
        if hop >= 1 then
          local ra = inc.age - 0.45 * inc.dur - 1.2
          if ra < 3 then K.ring(A2[1], A2[2], 4 + ra * 5, 0.42, 6 * e * (1 - ra / 3) * ease(ra / 0.3), 18) end
        end
      elseif inc.name == "dragonfly" then
        -- a dragonfly darts in over the water and settles on a bud
        local b = BUD[1 + floor(inc.s * #BUD) % #BUD]
        local bx, by = b[1], b[2] - b[3] - 5
        local land = clamp(inc.age / 4, 0, 1)
        local x = bx + (1 - ease(land)) * (60 * (inc.s2 - 0.5)) + sin(inc.age * 3) * 3 * (1 - land)
        local y = by - (1 - ease(land)) * 12
        put(9 * e, x - 4, y, 9, 1)
        local wing = land < 1 and (sin(K.NOW * 30) > 0 and 1 or 0) or 0
        local wl = (6 + 3 * hi) * e
        put(wl, x - 3, y - 1 - wing, 3, 1); put(wl, x + 1, y - 1 - wing, 3, 1)
        put(wl * 0.8, x - 3, y + 1, 3, 1); put(wl * 0.8, x + 1, y + 1, 3, 1)
      else
        -- a petal falls from a bud's flower and floats away, a ring under it
        local b = BUD[1 + floor(inc.s * #BUD) % #BUD]
        local f = clamp(inc.age / 4, 0, 1)
        local x = b[1] + 3 + f * 8 + sin(inc.age * 2.5) * 2 * (1 - f) + math.max(0, inc.age - 4) * 2
        local y = b[2] - b[3] - 3 + f * (b[3] + 4)
        -- (a broad pale petal, turning as it falls, its shadow on the water)
        local tw = sin(inc.age * 2.5)
        put(10 * e, x - 3, y, 7, 2); put(8 * e, x - 2 + tw, y - 1, 4, 1)
        put(4 * e, x - 3, b[2] + 2, 7, 1)
        if f >= 1 then
          local ra = inc.age - 4
          if ra < 4 then
            K.ring(x, b[2] + 1, 2 + ra * 4, 0.42, 6 * e * (1 - ra / 4) * ease(ra / 0.3), 16)
          end
        end
      end
    end
    K.glitter(sample, 36)
  end

  M.init()
  return M
end
