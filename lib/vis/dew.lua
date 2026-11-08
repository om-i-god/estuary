-- dew: a spider's web strung between two reeds at dawn, close up. behind
-- it the sky pales toward a low sun over a far reed bed, and the web
-- hangs in front: spokes out from the hub, the spiral round them, dew
-- beaded along every thread. the chord is the four anchor threads that hold
-- the web to the reeds, each tied higher for a higher tone, sliding to
-- their new places when the chord moves. a note lights one drop at its
-- pitch's place on the web, by motif: a drop that glows and trembles (the
-- first), a bead that runs down a spoke (the second), a drop that flares
-- into a star (the third), a run of beads along the spiral (the fourth).
-- out_lo sways the web on its threads, out_amp sets it trembling, out_mid
-- runs light round the spiral, out_hi makes the dew sparkle, and the water
-- sounds bring a low mist drifting through the reeds. the bloom is the sun
-- rising behind it, lighting the threads from behind; the bar breathes in
-- the glow; a swell is a breeze that billows the web and bends the reeds.
-- a passing moment sends a wave of light spiralling out through the dew.
-- now and then the spider adjusts a thread, a heavy drop falls, or a
-- damselfly settles on a reed
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, cos, floor, abs, sqrt = math.sin, math.cos, math.floor, math.abs, math.sqrt

  M.incidents = {{"spider", 18}, {"drop", 12}, {"damselfly", 16}}

  local HX, HY = 64, 27                   -- the hub
  local NS, R = 12, 26                    -- spokes, the web's radius
  local RINGS = {5, 9, 13, 17, 21, 25}
  local MARK_MAX = 6
  local RL, RR = 9, 119                   -- the two reeds the web hangs between
  local marks
  local sway_x, sway_y, trem = 0, 0, 0    -- the web's displacement this frame

  -- each spoke's angle (a little irregular: made by a spider) and length
  local SPK = {}
  for k = 1, NS do
    local a = (k - 1) / NS * K.TAU + (K.hash(k, 401) - 0.5) * 0.25
    SPK[k] = {cos(a), sin(a), R * (0.92 + 0.12 * K.hash(k, 402))}
  end
  -- the spiral: points along each ring between spokes, and the dew sites
  -- at the crossings: flat {radius-fraction, x offset, y offset, ...}
  local PTS, DEW = {}, {}
  for ri, r in ipairs(RINGS) do
    for k = 1, NS do
      local a, b = SPK[k], SPK[k % NS + 1]
      local rr = r * (0.97 + 0.06 * K.hash(ri * 16 + k, 403))
      local ax, ay = a[1] * rr, a[2] * rr * 0.92
      local bx, by = b[1] * rr, b[2] * rr * 0.92
      local n = math.max(1, floor(sqrt((bx - ax) ^ 2 + (by - ay) ^ 2) / 2.6))
      for j = 1, n - 1 do
        local u = j / n
        PTS[#PTS + 1], PTS[#PTS + 2], PTS[#PTS + 3] = rr / R, ax + (bx - ax) * u, ay + (by - ay) * u
      end
      DEW[#DEW + 1], DEW[#DEW + 2], DEW[#DEW + 3] = rr / R, ax, ay
    end
  end
  local NDEW = #DEW // 3
  -- the spokes as points
  local SPTS = {}
  for k = 1, NS do
    local s = SPK[k]
    for d = 2, s[3], 2.5 do SPTS[#SPTS + 1], SPTS[#SPTS + 2], SPTS[#SPTS + 3] = d / R, s[1] * d, s[2] * d * 0.92 end
  end
  -- the far reed bed along the bottom, and the far mist, baked once
  local bed = K.bake(function(rec)
    for k = 1, 46 do
      local x = floor(k * 2.8 + 2 * K.hash(k, 404))
      local h = 4 + floor(9 * K.hash(k, 405))
      rec(1 + 0.6 * K.hash(k, 406), x, 64 - h, 1, h)
      if K.hash(k, 407) < 0.3 then rec(1.4, x, 62 - h, 1, 2) end
    end
  end)
  -- the near reeds' leaves: {reed x, y, dir, length}
  local LEAF = {{RL, 44, 1, 9}, {RL, 20, 1, 7}, {RL + 2, 56, -1, 6}, {RR, 50, -1, 10}, {RR, 30, -1, 7}, {RR - 2, 12, 1, 5}}
  local MOTES = {}
  for k = 1, 6 do MOTES[k] = {K.hash(k, 409) * 140, 6 + 44 * K.hash(k, 410), 1.5 + 2 * K.hash(k, 411), K.hash(k, 412) * 6} end
  local SPARK = {}
  for i = 1, NDEW do SPARK[i] = K.hash(i, 408) end

  local function sample(u, v) return HX - 24 + u * 48, HY - 22 + v * 44 end

  function M.init() marks = {}; sway_x, sway_y, trem = 0, 0, 0 end
  function M.clear() marks = {} end

  -- where a point of the web is now: it sways most at the hub and least
  -- at its edge, where the threads hold it
  local function wx(f, x) return HX + x + (sway_x + trem) * (1 - 0.6 * f) end
  local function wy(f, y) return HY + y + sway_y * (1 - 0.6 * f) end

  -- the dew drop nearest a place on screen
  local function nearest(x, y)
    local best, bd = 1, 1e9
    for i = 1, NDEW do
      local j = i * 3 - 2
      local dx, dy = HX + DEW[j + 1] - x, HY + DEW[j + 2] - y
      local d = dx * dx + dy * dy * 2
      if d < bd then best, bd = i, d end
    end
    return best
  end

  -- the motifs light drops in their own bands of the web
  local BAND = {16, 34, 24, 42}
  function M.note(slot, midi)
    local x = HX + (K.px(midi) - 64) * 0.4
    local y = BAND[slot] - (K.pu(midi) - 0.5) * 8
    local i = nearest(x, y)
    K.cap_add(marks, {slot = slot, i = i, t0 = K.T, ph = K.rnd() * 6}, MARK_MAX)
  end

  -- the dawn sky, made once (its inputs set each frame)
  local F_glow, F_sun = 1, 56
  local function sky(y) local d = (F_sun - y) / 30; return F_glow * math.max(0, 1 - abs(d)) ^ 1.6 end

  -- a reed: a tall stem bending with the breeze, its leaves
  local function reed(x, lean, lv)
    for y = 0, 63, 3 do
      local u = 1 - y / 64
      put(lv + K.bj(x + y), x + lean * u * u, y, 2, 3)
    end
  end

  function M.draw()
    local T = K.T
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local hi, mid, nat, lo = A[K.HI], A[K.MID], A[K.NAT], A[K.LO]
    -- the web's motion: a slow sway (deeper with out_lo), a breeze with a
    -- swell, and a fine tremble with the sound
    sway_x = sin(T * 0.45) * (0.5 + 3 * lo) + sw * (5 + 2 * sin(T * 0.9)) + K.heave(HX) * 0.5
    sway_y = sin(T * 0.37 + 1) * (0.3 + 1.2 * lo) - sw * 2 * sin(T * 0.7)
    trem = sin(K.NOW * 23) * 0.6 * A[K.AMP]
    -- the sky: paling low down toward the sun, which rises with the bloom
    F_sun = 62 - 22 * bloom
    F_glow = 0.55 + 0.45 * bloom + 1.1 * breath + 0.3 * K.chord_glow
    -- (round the sun: each row's glow narrows and fades away from it)
    for y = floor(F_sun - 26), 63 do
      local dy = abs(y - F_sun)
      local v = sky(y) * 0.65
      if v > 0.05 then
        local hw = 58 - dy * 1.3
        local hi_ = 30 - dy * 0.9
        K.dither_row(v * 0.32, y, nil, floor(70 - hw), floor(70 - hi_))
        K.dither_row(v, y, nil, floor(70 - hi_), floor(70 + hi_))
        K.dither_row(v * 0.32, y, nil, floor(70 + hi_), floor(70 + hw))
      end
    end
    -- the sun, low behind the web, rising with the bloom
    local sl = 2 + 3 * bloom + breath * 1.2
    for dy = -4, 4 do
      local hw = floor(sqrt(20 - dy * dy) + 0.5)
      local y = F_sun + dy
      if y < 64 then put(sl + K.bj(dy + 20), 70 - hw, y, 2 * hw, 1) end
    end
    K.blit(bed, 1 + 0.4 * bloom, sin(T * 0.3) * (0.5 + 1.5 * nat))
    -- the low mist the water sounds bring, drifting through the reeds
    if nat > 0.03 then
      for y = 44, 60, 2 do
        local off = T * 3 + K.drift_x * 0.3 + y * 9
        for x = off % 19 - 19, 127, 19 do
          local w = sin(x * 0.05 + y * 0.4 - T * 0.2)
          if w > -0.2 then put(nat * (1.5 + 2 * (w + 0.2)) + K.bj(floor(x) + y), x, y, 7 + floor(4 * w), 1) end
        end
      end
    end
    -- motes drifting slowly through the low light
    for k, m in ipairs(MOTES) do
      local x = (m[1] + T * m[3] + K.drift_x * 0.2) % 140 - 6
      local y = m[2] + sin(T * 0.3 + m[4]) * 4
      put(2.2 + bloom * 1.5 + K.bj(k), x, y, 1, 1)
    end
    -- the near reeds the web hangs from, bending with the breeze
    local bend = sw * 3 + sin(T * 0.4) * (0.4 + 1.2 * lo)
    local rlv = 2.6 + 1.2 * bloom
    reed(RL, bend, rlv); reed(RR, bend * 0.8, rlv)
    for _, l in ipairs(LEAF) do
      local u = 1 - l[2] / 64
      local x0 = l[1] + bend * u * u
      for j = 1, l[4] do
        put(rlv * 0.85, x0 + l[3] * j, l[2] - j * 0.9 + (j * j) * 0.06 + sin(T * 0.8 + j * 0.3) * 0.3 * j / l[4], 1, 1)
      end
    end
    -- the anchor threads (the chord): from the web's frame to the reeds,
    -- tied higher for a higher tone
    local tl = 2 + 0.8 * bloom + 3 * K.chord_glow + 0.6 * breath
    for i = 1, 4 do
      local m, p = K.chord_at(i)
      if m and p > 0.02 then
        local left = i % 2 == 1
        local ay = clamp(58 - (m - 36) / 40 * 52, 3, 60)
        local s = SPK[left and (i == 1 and 6 or 8) or (i == 2 and 12 or 2)]
        local fx, fy = wx(1, s[1] * s[3]), wy(1, s[2] * s[3] * 0.92)
        local u0 = 1 - ay / 64
        local ax = (left and RL + 1 or RR) + (left and bend or bend * 0.8) * u0 * u0
        local dx, dy = ax - fx, ay - fy
        local n = floor(sqrt(dx * dx + dy * dy) / 3)
        for j = 1, n do
          local u = j / n
          put(tl * p + K.bj(i * 40 + j) * 0.5, fx + dx * u, fy + dy * u + sin(u * math.pi) * (1 + sw), 1, 1)
        end
        put((tl + 2) * p, ax - 1, ay - 1, 3, 2)
      end
    end
    -- the web: spokes and spiral as beaded silk, lit from behind by the sun
    local silk = 1.5 + 1.4 * bloom + 0.9 * breath + 1.6 * K.energy
    local ma = K.moment_age
    local wave = ma < 14 and ease(ma / 1.5) * (1 - ease((ma - 9) / 5)) or 0
    local front = (ma * 0.18) % 1.3
    for j = 1, #SPTS, 3 do
      local f = SPTS[j]
      local l = silk * (1 - 0.25 * f) + K.bj(j) * 0.6
      if wave > 0 then
        local d = abs(f - front)
        if d < 0.25 then l = l + wave * 6 * (1 - d / 0.25) end
      end
      put(l, wx(f, SPTS[j + 1]), wy(f, SPTS[j + 2]), 1, 1)
    end
    -- out_mid runs light round the spiral
    local run = T * 0.8
    for j = 1, #PTS, 3 do
      local f = PTS[j]
      local x, y = PTS[j + 1], PTS[j + 2]
      local l = silk * 0.9 + K.bj(j) * 0.6
      if mid > 0.05 then
        local a = math.atan(y, x)
        local g = sin(a * 2 - run * 3 + f * 9)
        if g > 0.2 then l = l + mid * 10 * (g - 0.2) end
      end
      local tw = sin(T * 2.9 + j * 0.37) * sin(T * 1.3 + j * 0.11)
      if tw > 0.4 then l = l + hi * 6 * (tw - 0.4) end
      if wave > 0 then
        local d = abs(f - front)
        if d < 0.25 then l = l + wave * 6 * (1 - d / 0.25) end
      end
      put(math.min(l, 12), wx(f, x), wy(f, y), 1, 1)
    end
    put(silk + 1.5, wx(0, -1), wy(0, -1), 3, 3)
    -- the dew at every crossing, sparkling with out_hi; a passing moment
    -- sends a wave of light spiralling out through it
    local dl = 2.4 + 1.5 * bloom + 0.8 * breath
    for i = 1, NDEW do
      local j = i * 3 - 2
      local f = DEW[j]
      local x, y = wx(f, DEW[j + 1]), wy(f, DEW[j + 2])
      local s = SPARK[i]
      local l = dl + K.bj(i) * 0.7
      if mid > 0.05 then
        local g = sin(math.atan(DEW[j + 2], DEW[j + 1]) * 2 - run * 3 + f * 9)
        if g > 0.2 then l = l + mid * 8 * (g - 0.2) end
      end
      local tw = sin(T * (2 + s * 2) + s * 40)
      if tw > 0.1 then l = l + hi * 8 * (tw - 0.1) end
      if wave > 0 then
        local d = abs(f - front)
        if d < 0.25 then l = l + wave * 8 * (1 - d / 0.25) end
      end
      l = math.min(l, 12)
      put(l, x, y, 1, 1)
      if l > 6 then put((l - 4) * 0.5, x - 1, y, 3, 1) end
    end
    -- the notes' drops
    for k = #marks, 1, -1 do
      local mk = marks[k]
      local age = T - mk.t0
      local cf, done = K.cap_fade(mk)
      if age > 5 or done then table.remove(marks, k)
      else
        local e = ease(age / 0.2) * (1 - ease((age - 2.2) / 2.8)) * cf
        local j = mk.i * 3 - 2
        local f = DEW[j]
        local x, y = wx(f, DEW[j + 1]), wy(f, DEW[j + 2])
        if mk.slot == 1 then
          -- the drop glows and trembles, a halo round it
          local tr = sin(age * 18 + mk.ph) * 0.6 * (1 - age / 4.5)
          put(10 * e, x - 1 + tr, y - 1, 2, 2)
          put(5 * e, x - 3 + tr, y - 1, 1, 2); put(5 * e, x + 2 + tr, y - 1, 1, 2)
          put(5 * e, x - 1 + tr, y - 3, 2, 1); put(5 * e, x - 1 + tr, y + 2, 2, 1)
          K.ring(x + tr, y, 4.5, 0.9, 5.5 * e, 12)
          K.ring(x + tr, y, 7, 0.9, 3.5 * e, 16)
        elseif mk.slot == 2 then
          -- a bead runs down the nearest spoke, catching the light
          local by = y + ease(age / 2.5) * 9
          put(9.5 * e, x - 1, by - 1, 3, 3)
          put(5 * e, x, by - 6, 1, 5)
          put(4 * e, x - 3, by, 1, 1); put(4 * e, x + 3, by, 1, 1)
          put(5.5 * e, x - 1, y - 1, 2, 2)
        elseif mk.slot == 3 then
          -- the drop flares into a star
          local r = 2 + 3.5 * ease(age / 0.6)
          put(10 * e, x - 1, y - 1, 2, 2)
          for d = 1, floor(r) do
            local l = 7 * e * (1 - d / (r + 1))
            put(l, x - 1 - d, y, 1, 1); put(l, x + d, y, 1, 1)
            put(l, x, y - 1 - d, 1, 1); put(l, x, y + d, 1, 1)
            put(l * 0.6, x - d, y - d, 1, 1); put(l * 0.6, x + d, y + d, 1, 1)
          end
        else
          -- a run of beads along the spiral lights in turn
          local n = 7
          for q = 0, n - 1 do
            local jj = ((mk.i + q - 1) % NDEW) * 3 + 1
            local ff = DEW[jj]
            local px_, py_ = wx(ff, DEW[jj + 1]), wy(ff, DEW[jj + 2])
            local lit = ease((age * 4 - q) / 1.5)
            put(8 * e * lit, px_ - 1, py_, 3, 1); put(5 * e * lit, px_, py_ - 1, 1, 3)
          end
        end
      end
    end
    K.glitter(sample, 24)
    -- incidents
    local inc = K.inc
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "spider" then
        -- the spider walks out along a spoke, tends a thread, walks back
        local s = SPK[1 + floor(inc.s * NS) % NS]
        local out = sin(math.pi * clamp(u * 1.15, 0, 1))
        local d = 2 + out * s[3] * 0.75
        local f = d / R
        local x, y = wx(f, s[1] * d), wy(f, s[2] * d * 0.92)
        local leg = sin(K.NOW * 6) > 0 and 1 or 0
        put(7.5 * e, x - 1, y - 1, 3, 3); put(6.5 * e, x - 1, y + 2, 3, 2)
        for q = -1, 1, 2 do
          put(5.5 * e, x + q * 2 - (q < 0 and 1 or 0), y - 2 + leg, 2, 1)
          put(5.5 * e, x + q * 3 - (q < 0 and 0 or 0), y - 1, 1, 1)
          put(5.5 * e, x + q * 2 - (q < 0 and 1 or 0), y + 2 - leg, 2, 1)
          put(5 * e, x + q * 3, y + 3, 1, 1)
        end
        -- (it plucks the thread now and then: a small shiver of light along it)
        local pl = math.max(0, sin(inc.age * 1.3)) ^ 6
        for q = 1, 4 do put(4 * e * pl, wx(f, s[1] * (d + q * 2.5)), wy(f, s[2] * (d + q * 2.5) * 0.92), 1, 1) end
      elseif inc.name == "drop" then
        -- a heavy drop gathers low on the web, swells, and falls
        local j = (1 + floor(inc.s * NS)) * 3 - 2 + 2 * NS * 3
        j = clamp(j, 1, #DEW - 2)
        local f = DEW[j]
        local x, y = wx(f, DEW[j + 1]), wy(f, DEW[j + 2]) + 2
        local fall = clamp((inc.age - 0.6 * inc.dur) / 1.8, 0, 1)
        local grow = ease(inc.age / (0.6 * inc.dur))
        local ge = e * (1 - ease(fall / 0.7))
        if ge > 0.01 then
          -- (it gathers the light round it as it swells)
          -- (a fixed shape whose light swells: it never jumps a size)
          local gl = ge * (0.5 + 0.5 * grow)
          put(8.5 * gl, x - 2, y, 4, 3); put(7 * gl, x - 1, y + 3, 2, 1)
          put(11 * gl, x - 1, y, 1, 1)
          K.ring(x, y + 1.5, 5, 0.9, 5 * gl, 16)
          for q = 1, 5 do put(5.5 * gl, x - 6 + q * 2, y - 1 - abs(q - 3) * 0.5, 1, 1) end
        end
        if fall > 0 then
          local fe = e * ease(fall / 0.4) * (1 - ease((fall - 0.4) / 0.6))
          local fy = y + 2 + fall * fall * 18
          put(9 * fe, x - 2, fy, 4, 3); put(5 * fe, x - 1, fy - 5, 2, 5)
        end
      else
        -- a damselfly comes in, settles on a reed, wings folded, and goes
        local left = inc.s < 0.5
        local px_ = left and RL + 3 or RR - 2
        local py_ = 18 + inc.s2 * 22
        local come = ease(clamp(inc.age / 3, 0, 1))
        local go = ease(clamp((inc.age - inc.dur + 3) / 3, 0, 1))
        local dir = left and 1 or -1
        local x = px_ + dir * (1 - come) * 40 + dir * go * 40
        local y = py_ - (1 - come) * 10 - go * 14
        local flying = (1 - come) + go
        put(8 * e, dir > 0 and x or x - 9, y, 10, 1)
        put(9 * e, x - dir, y - 1, 2, 2)
        local wing = flying > 0.05 and (sin(K.NOW * 28) > 0 and 1 or 0) or 0
        put(5.5 * e, x + dir * 2, y - 2 - wing, 4, 1); put(5.5 * e, x + dir * 2, y - 3 + wing, 4, 1)
      end
    end
  end

  M.init()
  return M
end
