-- horizon: open water to a low sun. the sky glows down to the waterline,
-- brighter as the bloom opens, with a dark headland on the left. the
-- waterline is a layered wave whose height and roughness follow out_lo and
-- the water level, rising with a swell. the chord voices as soft bands under
-- it, refracted by the same wave; the sun's path glitters down the water
-- with out_hi. a passing moment crosses the sky as a bird
return function(K)
  local M = {}
  local put, A, clamp = K.put, K.A, K.clamp

  local STARS = {{9, 5}, {30, 11}, {47, 3}, {71, 8}, {92, 4}, {108, 12}, {120, 6}, {18, 17}, {84, 15}}
  local hz_line = 40

  -- the headland: fixed in the world, so a rising sea covers its foot
  local head = K.profile(function(x)
    if x > 56 then return 99 end
    local u = x / 56
    return 23 + 16 * u ^ 1.8 - 3 * math.sin(u * 6) * (1 - u) + 0.7 * math.sin(x * 1.3)
  end)

  -- the layered wave: a long swell (out_lo), a chop and a ripple (the water
  -- level, out of the nature bus)
  local function wave(x)
    local T = K.T
    return (0.5 + 2.2 * A[K.LO]) * math.sin(x * 0.05 - T * 0.5 + K.drift_x * 0.02)
      + (0.3 + 1.1 * A[K.NAT]) * math.sin(x * 0.16 + T * 1.1)
      + (0.15 + 0.6 * A[K.NAT]) * math.sin(x * 0.39 - T * 1.9)
  end

  local function sample(u, v) return u * 127, hz_line + 3 + v * (60 - hz_line) end

  function M.draw(S)
    local T = K.T
    local yw = 40 - K.sw_disp * 12 - A[K.LO] * 1.5 - A[K.NAT] * 2.5
    hz_line = yw
    local bloom = K.bloom
    -- the sun sits low on the line, a little to the right
    local sx = 88 + 6 * math.sin(T * 0.011)
    local sr = 6
    local sun = 4.5 + 2.5 * bloom
    -- sky: a glow over the line, wider and brighter round the sun and as the
    -- bloom opens; a few far lights above it while the bloom is low
    local glow = 1.5 + 1.1 * bloom
    local top = math.floor(yw) - 1
    local function sky(y) local u = (yw - y) / 22; return u < 1 and glow * (1 - u) ^ 2.2 or 0 end
    K.gradient(0, top, sky, head)
    for y = top - 8, top do
      local h = (top - y)
      local w = math.floor((30 - h * 3) * (0.8 + 0.4 * bloom))
      if w > 0 then put(sky(y) + 0.8, sx - w, y, 2 * w, 1) end
    end
    -- the headland's rim catches the light; scrub on its back
    for c = 0, 27 do
      local t = head[c]
      if t < yw - 1 then
        put(1.2 + 0.8 * bloom, c * 2, t, 2, 1)
        if c % 3 == 1 and t + 4 < yw - 2 then put(1, c * 2, t + 3 + c % 2, 2, 1) end
      end
    end
    for i, s in ipairs(STARS) do
      if s[2] < yw - 14 then put((1.6 - bloom) * (1.2 + 0.8 * math.sin(T * 0.6 + i * 2.1)), s[1], s[2], 1, 1) end
    end
    -- the sun's disc, its foot under the line
    for dy = 0, sr - 1 do
      local hw = math.floor(math.sqrt(sr * sr - dy * dy) + 0.5)
      local y = math.floor(yw) - 1 - dy
      put(sun + (dy > sr - 3 and 0 or 0.5), sx - hw, y, 2 * hw, 1)
    end
    -- a passing moment: a bird crossing the sky
    local mdur = 13.2
    if K.moment_age < mdur then
      local f = K.moment_age / mdur
      local x = 10 + f * 108
      local y = 10 + math.sin(f * 6) * 3
      local lv = 5 * math.sin(f * math.pi)
      local flap = math.sin(K.NOW * 5) > 0 and 1 or 0
      put(lv, x, y, 1, 1); put(lv, x + 1, y - flap, 1, 1); put(lv, x - 1, y - flap, 1, 1)
      put(lv, x + 2, y - 1 + flap, 1, 1); put(lv, x - 2, y - 1 + flap, 1, 1)
    end
    -- the headland's foot in the water: its dark reflection, edged by glow
    for d = 2, 7, 2 do
      local y = yw + d
      K.streaks(glow * 0.7, y, 7, 9, K.drift_x * 0.4 + d * 3,
        function(x) return x < 56 and yw - d < K.at(head, x) end)
    end
    -- the back swell: only its crests show, just above the line
    for x = 54, 126, 3 do
      local w2 = math.sin(x * 0.09 - T * 0.8 + 2 + K.drift_x * 0.03)
      if w2 > 0.4 then put(1 + w2 * (1 + A[K.LO]), x, yw - 2 + wave(x) * 0.5, 3, 1) end
    end
    -- the waterline: crests brighter
    for x = 0, 126, 2 do
      local w = wave(x)
      local sparkle = A[K.HI] * 2.5 * math.max(0, math.sin(x * 1.1 - T * 6))
      put(3 + clamp(-w * 0.6, -1, 1.5) + K.bar_pulse * 2 + sparkle, x, yw + w, 2, 1)
    end
    -- chord voices: soft bands under the line, lower notes deeper, refracted
    -- by the same wave
    local c = K.chord(S)
    local pad = type(S.gain) == "table" and tonumber(S.gain.pad) or 0.5
    local base = 2 + clamp(pad, 0, 1) * 2.5
    local low_y = yw + 4
    for i = 1, #c do
      local m = c[i]
      local y = clamp(yw + 5 + (84 - m) * 0.3 + i * 0.5, yw + 4, 61)
      local cx = 64 + (i - 2.5) * 15 + math.sin(T * 0.25 + i * 1.7) * 5
      local w = 22 + i * 4 + K.sw_disp * 8
      for x = 0, 126, 2 do
        local d = (x - cx) / w
        local v = math.exp(-d * d)
        if v > 0.15 then
          local sh = 0.75 + 0.25 * math.sin(T * 0.8 + x * 0.1 + i * 2)
          put((base + 1) * v * sh + K.bar_pulse * v, x, y + wave(x + i * 9) * 0.6, 2, 1)
        end
      end
      if y > low_y then low_y = y end
    end
    -- the sun's path: broken glints down the water under it, wider and
    -- quicker with out_hi
    local hi = A[K.HI]
    for yy = math.floor(yw) + 2, 62, 2 do
      local depth = (yy - yw) / (64 - yw)
      local fl = 0.5 + 0.5 * math.sin(T * (2.5 + 5 * hi) + yy * 1.9) * math.sin(T * 1.3 + yy * 0.7)
      if fl > 0.3 then
        local wd = 1 + math.floor((2 + 6 * depth) * (0.5 + hi) * fl + 0.5)
        local l = (1.5 + 3 * hi + 1.5 * bloom) * fl * (1 - 0.4 * depth)
        put(l, sx + wave(yy * 3) * 1.5 + math.sin(yy * 2.3 + T) * (1 + 2 * depth) - wd / 2, yy, wd, 1)
      end
    end
    -- far water texture under it all
    K.surface(0, math.floor(yw) + 9, 128, 64, 1, 11, 4)
    K.glitter(sample)
  end

  return M
end
