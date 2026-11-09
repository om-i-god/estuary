-- delta: a braided river delta seen from high above at golden hour. silver
-- channels split and rejoin across pale sandbars on their way to the sea,
-- which lies along the right side under a thin strip of gold sky on the
-- far line; a few wisps of cloud drift below you, faster than the ground.
-- the chord is the four main channels: each shines as bright as its tone
-- is high, the light gliding to its new level when the chord moves. a note
-- is light running down a channel from its pitch's column toward the sea,
-- each motif in its own channel and its own way: a single pulse (the
-- first), a pair (the second), a long streak (the third), a pulse that
-- fans out into glints where it meets the sea (the fourth). out_amp sets
-- how fast the water's shimmer runs downstream, out_lo heaves the sea's
-- swell lines, out_mid ruffles the channels with small ripples, out_hi
-- glitters on the sea, and the water sounds are the shimmer of the
-- shallows along the sandbars' edges. the bloom is the low sun: the sea's
-- path, the sky and the channels warm with it; the bar breathes in the
-- water; a swell is the tide pushing back up the channels, the sea edge
-- coming in and a bright front running upstream. a passing moment sweeps
-- a band of sunlight across the whole delta. now and then a flock of
-- shorebirds wheels over, a cloud and its shadow cross, or a small boat
-- runs down a channel with its wake spreading
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, cos, floor, abs = math.sin, math.cos, math.floor, math.abs

  M.incidents = {{"birds", 14}, {"cloud", 22}, {"boat", 20}}

  local HZ = 6                            -- the far line
  local MARK_MAX = 8
  local marks
  local fp = 0                            -- how far the shimmer has run downstream (px)

  -- the coast: the sea lies to the right of it
  local function coast(y) return 94 + 7 * sin(y * 0.09 + 0.7) + 3 * sin(y * 0.27) end
  -- the channels: six braids across the sand, the four main ones (1..4)
  -- carrying the chord. each wanders and crosses its neighbours, which is
  -- what makes the delta braid
  local CH = {
    {16, 4, 0.045, 0.3, 1}, {29, 5, 0.038, 2.1, 1}, {41, 5, 0.05, 4.0, 1}, {53, 4, 0.042, 1.2, 1},
    {0, 0, 0.11, 0.4, 1, 1, 2}, {0, 0, 0.13, 2.5, 1, 3, 4}, {0, 0, 0.15, 4.4, 1, 2, 3},
  }
  -- (a braid, 5 to 7, leaves one main channel, wanders across the bar
  -- between it and the next and joins that one: the delta splits and
  -- rejoins)
  local ych
  ych = function(c, x)
    local h = CH[c]
    if h[6] then
      local t = 0.5 + 0.44 * sin(x * h[3] + h[4])
      t = t < 0 and 0 or (t > 1 and 1 or t)
      local a, b = ych(h[6], x), ych(h[7], x)
      return a + (b - a) * t
    end
    return h[1] + h[2] * sin(x * h[3] + h[4]) + 1.2 * sin(x * 0.13 + h[4] * 2)
  end
  -- the sandbars: a pale stipple over the land, thicker away from the
  -- water; baked once
  local sand = K.bake(function(rec)
    local k = 0
    for y = HZ + 2, 63 do
      local x = 0
      local cx = coast(y)
      while x < cx - 1 do
        k = k + 1
        local len = 1 + floor(3 * K.hash(k, 1301))
        local near = 99
        for c = 1, 7 do near = math.min(near, abs(y - ych(c, x))) end
        local d = 0.03 + 0.1 * clamp((near - 1.5) / 6, 0, 1) + 0.04 * sin(x * 0.07 + y * 0.3)
        if K.hash(k, 1302) < d then rec(K.hash(k, 1303) < 0.2 and 1.8 or 1, x, y, math.min(len, cx - x), 1) end
        x = x + len + 1 + floor(3 * K.hash(k, 1304))
      end
    end
  end)
  -- the shallows along the bars' edges, where the water sounds shimmer
  local SHALLOW = {}
  for k = 1, 64 do
    local c = 1 + (k - 1) % 7
    local x = 2 + 86 * K.hash(k, 1306)
    SHALLOW[#SHALLOW + 1] = x
    SHALLOW[#SHALLOW + 1] = ych(c, x) + (K.hash(k, 1307) < 0.5 and -2 or 2 + CH[c][5] - 1)
  end
  local SEAGLINT = {}
  for k = 1, 70 do
    local y = HZ + 2 + floor(55 * K.hash(k, 1308))
    SEAGLINT[#SEAGLINT + 1] = floor(coast(y) + 3 + (124 - coast(y)) * K.hash(k, 1309))
    SEAGLINT[#SEAGLINT + 1] = y
  end
  -- wisps of cloud below you, drifting over the ground: {x, y, length}
  local WISP = {}
  for k = 1, 3 do WISP[k] = {K.hash(k, 1310) * 160, 14 + 40 * K.hash(k, 1311), 14 + 12 * K.hash(k, 1312)} end

  function M.init() marks, fp = {}, 0 end
  function M.clear() marks = {} end

  function M.note(slot, midi)
    K.cap_add(marks, {slot = slot, x0 = math.min(K.px(midi), 86), t0 = K.T}, MARK_MAX)
  end

  local function sample(u, v)
    local y = HZ + 2 + v * 55
    local cx = coast(y)
    return cx + 3 + u * (124 - cx), y
  end

  -- a cloud's shadow over the ground (incident): how much light is left at x, y
  local SH_X, SH_Y, SH_E = -99, 0, 0
  local function shade(x, y)
    if SH_E <= 0 then return 1 end
    local dx, dy = (x - SH_X) / 22, (y - SH_Y) / 11
    local d = dx * dx + dy * dy
    if d >= 1 then return 1 end
    return 1 - 0.55 * SH_E * (1 - d)
  end

  -- the gold sky on the far line (its strength set each frame)
  local F_sky = 1
  local function sky(y) return F_sky * (0.15 + 0.35 * (y / HZ)) end

  function M.draw()
    local T = K.T
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local hi, mid, nat, lo, amp = A[K.HI], A[K.MID], A[K.NAT], A[K.LO], A[K.AMP]
    fp = fp + (3 + 9 * amp) * K.DTS
    local inc = K.inc
    if inc and inc.name == "cloud" then
      SH_X, SH_Y, SH_E = -30 + inc.u * 190, 22 + inc.s * 22, inc.e
    else
      SH_E = 0
    end
    -- the far line: a strip of gold sky over the open sea
    F_sky = 0.9 + 1.4 * bloom + 1.2 * breath
    K.gradient(0, HZ - 1, sky)
    K.hline(2 + 1.5 * bloom, HZ, 0, 128, 6)
    -- the sea, its edge coming in with a swell
    local push = sw * 10
    for y = HZ + 1, 63, 3 do
      local cx = coast(y) - push
      local d = (y - HZ) / 58
      local off = K.drift_x * (0.3 + d * 0.4) + y * 5.3 + T * 0.6
      -- (the swell lines heave with out_lo: their rows lean and gather)
      local yy = y + K.heave(y * 3) * (0.3 + 0.6 * lo)
      K.streaks((1.2 + 0.8 * bloom + 1.4 * breath) * (1.1 - d * 0.4), yy, 3 + d * 4, 12 + floor(d * 6), off, nil, nil, floor(cx) + 2, 128)
      -- the low sun's path lying across it, toward the far line
      local px = 108 + (y - HZ) * 0.18
      local pl = (1.5 + 4.5 * bloom + 1.5 * breath) * (1 - d * 0.6) * (0.75 + 0.25 * sin(T * 1.7 + y * 1.3))
      if px - 4 > cx then K.dash(pl, px - 3 + sin(T * 0.8 + y) * 1.2, y, 6) end
    end
    -- the coast's surf line, whiter with the water sounds and a swell
    for y = HZ + 1, 63, 2 do
      local cx = coast(y) - push
      put(2.4 + 5 * nat * (0.5 + 0.5 * sin(T * 2 + y)) + 2 * sw + K.bj(y) * 0.4, cx, y, 2, 2)
    end
    K.twinkle(SEAGLINT, hi, 14)
    -- the sandbars
    K.blit(sand, (1 + 0.5 * bloom) * (1 - 0.3 * SH_E) * (1 - 0.45 * sw))
    -- the channels: silver, the main four as bright as their tone, the
    -- shimmer running downstream; a swell brings a bright front up them
    local ma = K.moment_age
    local band = ma < 14 and ease(ma / 2) * (1 - ease((ma - 9) / 5)) or 0
    local bx = -30 + ma * 14
    local front = 96 - sw * 70
    for c = 1, 7 do
      local main = c <= 4
      local cl = 0
      if main then
        local m, p = K.chord_at(c)
        if m then cl = (1 + clamp((m - 36) / 40, 0, 1) * 4 + 2.5 * K.chord_glow) * p end
      end
      local base = (main and 3.4 or 2.8) + 0.9 * bloom + 1.3 * breath + 0.6 * amp + cl
      local w = CH[c][5]
      for x = 0, 93, 3 do
        local y = ych(c, x)
        local cx = coast(y) - push
        if x < cx - 1 then
          local sh = sin(x * 0.31 - fp * 0.31 + c * 1.7)
          local l = base + 1.3 * K.ramp(sh, 0.3, 0.9) + K.bj(x * 3 + c * 64) * 0.95
          -- the tide's front running upstream with a swell
          if sw > 0.02 then l = l + sw * 4 * math.max(0, 1 - abs(x - front) / 10) end
          -- the moment's band of sunlight
          if band > 0 then l = l + band * 5 * math.max(0, 1 - abs(x + y * 0.6 - bx) / 12) end
          l = math.min(12, l * shade(x, y))
          put(l, x, y, 3, w)
          -- (the main ones carry a soft second row where the light runs)
          if main then put(l * 0.45 * K.ramp(sh, -0.2, 0.6), x, floor(y) + 1, 3, 1) end
          -- (a swell widens the main ones by a fraction of a row)
          if main and sw > 0.02 then put(l * sw * 0.8, x, floor(y) - 1, 3, 1) end
        end
      end
    end
    -- out_mid: small ripples crossing the channels
    if mid > 0.02 then
      for k = 0, 27 do
        local c = 1 + k % 7
        local x = (k * 17 + fp * 0.8 + c * 11) % 92
        local y = ych(c, x)
        local f = 0.5 + 0.5 * sin(T * 2.3 + k * 1.9)
        K.dash(mid * (3.5 + 6 * f), x, y - 2, 1, CH[c][5] + 3)
      end
    end
    -- the water sounds: the shallows shimmer along the bars' edges
    if nat > 0.02 then
      for i = 1, #SHALLOW, 2 do
        local w = sin(T * 2.7 + i * 1.3) * sin(T * 1.1 + i * 0.7)
        if w > 0 then put(nat * 13 * w * shade(SHALLOW[i], SHALLOW[i + 1]), SHALLOW[i], SHALLOW[i + 1], 2, 1) end
      end
    end
    -- the moment: the band of sunlight lies on the sand too
    if band > 0 then
      for y = HZ + 2, 63, 3 do
        local x0 = bx - y * 0.6
        K.dither_row(band * 1.3, y, nil, math.max(0, floor(x0 - 5)), math.min(128, floor(x0 + 5)))
      end
    end
    -- the notes: light running down a channel toward the sea
    for i = #marks, 1, -1 do
      local mk = marks[i]
      local age = T - mk.t0
      local cf, done = K.cap_fade(mk)
      if age > 4 or done then table.remove(marks, i)
      else
        local e = ease(age / 0.2) * (1 - ease((age - 2.4) / 1.6)) * cf
        local c = mk.slot
        local x = mk.x0 + age * (9 + 6 * amp)
        local y = ych(c, x)
        local cx = coast(y) - push
        if x < cx then
          if mk.slot == 1 then
            K.dash(10 * e, x - 2, y - 1, 5, 3)
            for q = 1, 6 do put(7 * e * (1 - q / 7), x - 1 - q * 2, ych(c, x - q * 2) - 1, 2, 3) end
          elseif mk.slot == 2 then
            K.dash(9 * e, x - 2, y - 1, 4, 3)
            K.dash(8 * e, x - 10, ych(c, x - 8) - 1, 4, 3)
          elseif mk.slot == 3 then
            for q = 0, 9 do put(8.5 * e * (1 - q / 11), x - q * 2, ych(c, x - q * 2) - 1, 2, 3) end
          else
            K.dash(9 * e, x - 1, y - 2, 3, 4)
            K.ring(x, y, 2 + age * 2, 0.6, 5 * e, 10)
          end
        else
          -- reaching the sea it fans out into glints
          local s = x - cx
          for q = -2, 2 do
            put(7 * e * math.max(0, 1 - s / 30), cx + s * 0.6 + abs(q) * 2, y + q * (1 + s * 0.15), 2, 1)
          end
        end
      end
    end
    -- wisps of cloud below you, drifting faster than the ground
    for k, w in ipairs(WISP) do
      local x = (w[1] + K.drift_x * 0.6 + T * 2.2) % 170 - 30
      local y = w[2] + sin(T * 0.05 + k) * 2
      local l = 1.5 + 1.2 * bloom
      K.dash(l, x, y, w[3])
    end
    -- incidents
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "birds" then
        -- a flock of shorebirds wheeling over the sandbars
        local cx = -10 + u * 150
        local cy = 30 + inc.s * 14 + sin(u * 5) * 6
        for k = 0, 11 do
          local a = inc.age * 1.1 + k * 0.52
          local r = 6 + (k % 3) * 2.5
          local x, y = cx + cos(a) * r * 1.4, cy + sin(a) * r * 0.7
          K.bird(x, y, (6.5 + 2 * sin(a * 2)) * e, sin(K.NOW * 9 + k), 1)
        end
      elseif inc.name == "cloud" then
        -- a cloud drifting below you: a soft white mass, its shadow on
        -- the ground beside it
        local cx, cy = SH_X + 9, SH_Y - 7
        for dy = -6, 6 do
          local hw = 18 * math.sqrt(math.max(0, 1 - (dy / 7) ^ 2)) * (0.85 + 0.15 * sin(dy * 1.7 + inc.s * 6))
          if hw > 1 then K.dither_row(e * (2.6 - abs(dy) * 0.25), cy + dy, nil, math.max(0, floor(cx - hw)), math.min(128, floor(cx + hw))) end
        end
        K.hline(e * 4, cy - 6, math.max(0, floor(cx - 8)), math.min(128, floor(cx + 8)), 4)
      else
        -- a small boat running down a channel, its wake opening behind
        local c = 1 + floor(inc.s * 4) % 4
        local x = -6 + u * 100
        local y = ych(c, x)
        K.dash(10 * e, x - 2, y - 1, 5, 2)
        put(8 * e, x + 3, y, 1, 1)
        for q = 1, 12 do
          local wx = x - 2 - q * 2
          local wy = ych(c, wx)
          local l = 6.5 * e * (1 - q / 13)
          put(l, wx, wy - 1 - q * 0.5, 2, 1); put(l, wx, wy + 1 + q * 0.5, 2, 1)
        end
      end
    end
    K.glitter(sample, 22)
  end

  M.init()
  return M
end
