-- horizon: open water to a low sun. the sky glows down to the waterline
-- and the sun climbs a little and the sky warms as the bloom opens, with a
-- dark headland on the left and long thin clouds drifting far off. the
-- waterline is a layered wave whose height and roughness follow out_lo and
-- the water sounds, rising with a swell; out_mid lifts the crests of the
-- swell behind it and the rollers coming in, out_hi glitters the sun's path,
-- the water sounds raise whitecaps. the chord lies as soft bands of light
-- under the line, one per tone, across by pitch, gliding when it changes.
-- notes catch the light at their pitch: a crest close in (the first motif),
-- a pair of wavelets further out (the second), a light in the sky (the
-- third), a far sail's glint on the line (the fourth). the bar breathes on
-- the line and round the sun; a passing moment sends a skein of geese
-- across. now and then a sail crosses the line, a cloud passes the sun, or
-- a porpoise rolls
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, floor, abs = math.sin, math.floor, math.abs

  M.incidents = {{"sail", 26}, {"cloud", 18}, {"porpoise", 10}}

  local STARS = {{9, 5}, {30, 11}, {47, 3}, {71, 8}, {92, 4}, {108, 12}, {120, 6}, {18, 17}, {84, 15}}
  local MARK_MAX = 8
  local hz_line = 40
  local marks = {}

  function M.clear() marks = {} end

  -- the headland: fixed in the world, so a rising sea covers its foot
  local head = K.profile(function(x)
    if x > 56 then return 99 end
    local u = x / 56
    return 23 + 16 * u ^ 1.8 - 3 * sin(u * 6) * (1 - u) + 0.7 * sin(x * 1.3)
  end)
  -- scrub and rock on the headland's back, baked once
  local scrub = K.bake(function(rec)
    for c = 0, 27 do
      local t = head[c]
      for y = floor(t) + 2, 38, 2 do
        if K.hash(c * 64 + y, 21) < 0.3 - (y - t) * 0.012 then rec(1, c * 2 + (y // 2) % 2, y, 1 + floor(2 * K.hash(c + y, 22)), 1) end
      end
    end
  end)
  -- the far clouds: long thin strokes, baked once and slid slowly round
  local clouds = K.bake(function(rec)
    for k = 1, 5 do
      local cx, cy, w = K.hash(k, 23) * 128, 6 + 14 * K.hash(k, 24), 18 + 22 * K.hash(k, 25)
      for r = 0, 2 do
        local hw = w * (1 - r * 0.3) * 0.5
        local x0 = cx - hw + (K.hash(k * 3 + r, 26) - 0.5) * 6
        rec(r == 0 and 1.6 or 1, x0, cy + r, hw * 2, 1)
        if r == 0 then rec(2.2, x0 + hw * 0.3, cy, hw * 0.8, 1) end
      end
    end
  end)

  -- the layered wave: a long swell (out_lo), a chop and a ripple (the water
  -- level, out of the nature bus; out_amp roughens it a little)
  local function wave(x)
    local T = K.T
    local chop = 0.3 + 1.1 * A[K.NAT] + 0.5 * A[K.AMP]
    return (0.5 + 2.2 * A[K.LO]) * sin(x * 0.05 - T * 0.5 + K.drift_x * 0.02)
      + chop * sin(x * 0.16 + T * 1.1)
      + (0.15 + 0.6 * A[K.NAT]) * sin(x * 0.39 - T * 1.9)
  end

  local function sample(u, v) return u * 127, hz_line + 3 + v * (60 - hz_line) end

  -- a note catches the light at its pitch; the motif decides what lights
  function M.note(slot, midi)
    marks[#marks + 1] = {slot = slot, x = K.px(midi), u = K.pu(midi), t0 = K.T}
    if #marks > MARK_MAX then
      -- (the oldest goes once it has nearly faded; till then a new note waits)
      if K.T - marks[1].t0 > 3.5 then table.remove(marks, 1) else marks[#marks] = nil end
    end
  end

  function M.draw(S)
    local T = K.T
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local hi, mid, nat, lo = A[K.HI], A[K.MID], A[K.NAT], A[K.LO]
    local yw = 40 - sw * 12 - lo * 1.5 - nat * 2.5
    hz_line = yw
    local inc = K.inc
    -- a cloud over the sun dims it and its path
    local shade = 0
    local cloud_x
    if inc and inc.name == "cloud" then
      cloud_x = -30 + inc.u * 190
      shade = inc.e * clamp(1 - abs(cloud_x - 88) / 26, 0, 1)
    end
    -- the sun sits low on the line, a little to the right, climbing a few
    -- px as the bloom opens
    local sx = 88 + 6 * sin(T * 0.011)
    local sr = 6
    local lift = floor(bloom * 5 + 0.5)
    local sun = (4.5 + 2.5 * bloom) * (1 - 0.45 * shade)
    -- sky: a glow over the line, wider and brighter round the sun and as the
    -- bloom opens; a few far lights above it while the bloom is low
    local glow = (1.5 + 1.2 * bloom) * (1 - 0.25 * shade)
    local top = floor(yw) - 1
    local reach = 18 + 3 * bloom
    local function sky(y) local u = (yw - y) / reach; return u < 1 and glow * (1 - u) ^ 2.2 or 0 end
    for y = 0, top do K.dither_row(sky(y) + breath * 1.8 * clamp(1 - (yw - y) / 14, 0, 1), y, head) end
    K.blit(clouds, 0.8 + 0.6 * bloom, K.drift_x * 0.05 + T * 0.35, true)
    for y = top - 8 - lift, top do
      local h = (top - y)
      local w = floor((30 - h * 3 + lift * 2) * (0.8 + 0.4 * bloom))
      if w > 0 then put(sky(y) + 0.8 + breath * 0.8, sx - w, y, 2 * w, 1) end
    end
    -- the headland's rim catches the light; scrub on its back
    for c = 0, 27 do
      local t = head[c]
      if t < yw - 1 then put(1.2 + 0.8 * bloom, c * 2, t, 2, 1) end
    end
    K.blit(scrub, 1 + 0.5 * bloom)
    for i, s in ipairs(STARS) do
      if s[2] < yw - 14 then put((1.6 - bloom) * (1.2 + 0.8 * sin(T * 0.6 + i * 2.1)), s[1], s[2], 1, 1) end
    end
    -- the sun's disc, its foot under the line until the bloom lifts it clear
    for dy = 0, sr - 1 do
      local hw = floor(math.sqrt(sr * sr - dy * dy) + 0.5)
      local y = floor(yw) - 1 - dy - lift
      put(sun + (dy > sr - 3 and 0 or 0.5), sx - hw, y, 2 * hw, 1)
    end
    for dy = 1, lift do
      local hw = floor(math.sqrt(math.max(0, sr * sr - (dy - 1) * (dy - 1))) + 0.5)
      put(sun, sx - hw, floor(yw) - 1 - lift + dy, 2 * hw, 1)
    end
    -- a passing moment: a skein of geese crossing the sky
    local mdur = 14
    if K.moment_age < mdur then
      local f = K.moment_age / mdur
      local e = ease(K.moment_age / 1.5) * ease((mdur - K.moment_age) / 2)
      local x0 = -14 + f * 150
      local y0 = 9 + sin(f * 5) * 2
      for k = 0, 8 do
        local side = (k % 2 == 0) and 1 or -1
        local rank = (k + 1) // 2
        local x, y = x0 - rank * 7, y0 + side * rank * 2.6
        local flap = sin(K.NOW * 3.5 + k * 0.7)
        K.bird(x, y, 6 * e, flap, 2)
        -- and in the water below
        K.bird(x + K.heave(x) * 0.6, yw + (yw - y) * 0.45 + 2, 2.5 * e, -flap, 1)
      end
    end
    -- the headland's foot in the water: its dark reflection, edged by glow
    for d = 2, 7, 2 do
      local y = yw + d
      K.streaks(glow * 0.7, y, 7, 9, K.drift_x * 0.4 + d * 3,
        function(x) return x < 56 and yw - d < K.at(head, x) end)
    end
    -- the swell behind the line: only its crests show, more and brighter
    -- with out_mid
    for x = 54, 126, 3 do
      local w2 = sin(x * 0.09 - T * 0.8 + 2 + K.drift_x * 0.03)
      if w2 > 0.75 - 0.6 * mid then put(1 + w2 * (1 + 2.2 * mid), x, yw - 2 + wave(x) * 0.5, 3, 1) end
    end
    -- the waterline: crests brighter, breathing with the bar
    for x = 0, 126, 2 do
      local w = wave(x)
      local sparkle = hi * 2.5 * math.max(0, sin(x * 1.1 - T * 6))
      put(3 + clamp(-w * 0.6, -1, 1.5) + K.bar_pulse + breath * 2.2 + sparkle, x, yw + w, 2, 1)
    end
    -- chord voices: soft bands of light under the line, one per tone, across
    -- by its pitch, lower notes deeper, refracted by the same wave; a new
    -- chord glides in and glows as it settles
    local pad = type(S.gain) == "table" and tonumber(S.gain.pad) or 0.5
    local base = 2 + clamp(pad, 0, 1) * 2.5 + 1.5 * K.chord_glow
    for i = 1, 4 do
      local m, p = K.chord_at(i)
      if m and p > 0.02 then
        local y = clamp(yw + 5 + (84 - m) * 0.3 + i * 0.5, yw + 4, 61)
        local cx = K.cx(m) + sin(T * 0.25 + i * 1.7) * 4
        local w = 14 + i * 3 + sw * 8
        for x = math.max(0, floor((cx - w * 1.4) / 2) * 2), math.min(126, cx + w * 1.4), 2 do
          local d = (x - cx) / w
          local v = math.exp(-d * d)
          if v > 0.3 then
            local sh = 0.75 + 0.25 * sin(T * 0.8 + x * 0.1 + i * 2)
            put(((base + 1) * v * sh + K.bar_pulse * v) * p, x, y + wave(x + i * 9) * 0.6, 2, 1)
          end
        end
      end
    end
    -- the sun's path: broken glints down the water under it, wider and
    -- quicker with out_hi, dimmed while a cloud is over the sun
    for yy = floor(yw) + 2, 62, 2 do
      local depth = (yy - yw) / (64 - yw)
      local fl = 0.5 + 0.5 * sin(T * (2.5 + 5 * hi) + yy * 1.9) * sin(T * 1.3 + yy * 0.7)
      if fl > 0.3 then
        local wd = 1 + floor((2 + 6 * depth) * (0.5 + hi) * fl + 0.5)
        local l = (1.5 + 6 * hi + 1.5 * bloom) * fl * (1 - 0.4 * depth) * (1 - 0.6 * shade)
        put(l, sx + wave(yy * 3) * 1.5 + sin(yy * 2.3 + T) * (1 + 2 * depth) - wd / 2, yy, wd, 1)
      end
    end
    -- the rollers coming in close: long crests sliding at the current's full
    -- rate, longer and brighter with out_mid; whitecaps on them with the
    -- water sounds
    for r = 0, 2 do
      local y = 52 + r * 4 + floor(K.heave(r * 40) * 0.6)
      if y > yw + 6 then
        local off = K.drift_x * (1 + r * 0.3) + r * 37 + T * (2 + r)
        local len = 5 + 9 * mid
        for x = (off % 31) - 31, 127, 31 do
          local h = K.hash(floor((x - off) / 31 + 0.5) + r * 17, 27)
          put(1.5 + 1.5 * mid + r * 0.3 + hi * 3.5 * math.max(0, sin(x * 0.7 + T * 7 + r)), x + h * 8, y, len * (0.6 + 0.6 * h), 1)
          if nat > 0.1 and h < nat * 0.8 then put(3 + 3 * nat, x + h * 8 + len * 0.3, y - 1, 2, 1) end
        end
      end
    end
    -- far water texture under it all
    K.surface(0, floor(yw) + 9, 128, 50, 1, 11, 4)
    -- the notes: where each lights follows its pitch; the motif decides what
    for i = #marks, 1, -1 do
      local mk = marks[i]
      local age = T - mk.t0
      if age > 4.5 then table.remove(marks, i)
      else
        local e = 1.15 * ease(age / 0.25) * (1 - ease((age - 1.2) / 3.3))
        local x = mk.x
        if mk.slot == 1 then
          -- a crest close in catches the light and breaks along, foam behind
          local y = 57 + wave(x) * 0.5
          local run = age * 4
          put(7 * e, x - 9 + run, y, 18, 1); put(4 * e, x - 7 + run * 0.7, y + 1, 14, 1)
          put(2.5 * e, x - 10 + run * 0.4, y + 3, 16, 1)
        elseif mk.slot == 2 then
          -- a pair of wavelets further out, rings of light opening
          local y = yw + 9 + (1 - mk.u) * 4 + wave(x) * 0.5
          local o = 2 + age * 2
          put(6 * e, x - o - 3, y, 4, 1); put(6 * e, x + o, y, 4, 1)
          put(3.5 * e, x - o - 1, y - 1, 2, 1); put(3.5 * e, x + o + 1, y - 1, 2, 1)
          put(2.5 * e, x - o, y + 2, 2 * o + 1, 1)
        elseif mk.slot == 3 then
          -- a light in the sky, higher for a higher note, its path below it
          local y = clamp(yw - 6 - mk.u * 24, 3, yw - 4)
          put(6.5 * e, x, y, 1, 1)
          put(3.5 * e, x - 1, y, 1, 1); put(3.5 * e, x + 1, y, 1, 1); put(3.5 * e, x, y - 1, 1, 1); put(3.5 * e, x, y + 1, 1, 1)
          put(1.8 * e, x - 3, y, 1, 1); put(1.8 * e, x + 3, y, 1, 1)
          for d = 3, 15, 3 do put(3.5 * e * (1 - d / 18), x - 1 + sin(T * 3 + d) * 1.2, yw + d, 3, 1) end
        else
          -- a far sail's glint on the line, and in the water
          x = x + age * 1.5
          put(7 * e, x, yw - 5, 1, 5); put(5 * e, x + 1, yw - 4, 1, 4); put(4 * e, x + 2, yw - 2, 1, 2)
          put(3 * e, x - 2, yw - 1, 6, 1)
          for d = 2, 10, 2 do put(3.5 * e * (1 - d / 12), x - 1 + K.heave(x + d) * 0.5, yw + d, 4, 1) end
        end
      end
    end
    -- incidents
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "sail" then
        local dir = inc.s > 0.5 and 1 or -1
        local x = dir > 0 and (58 + u * 78) or (134 - u * 78)
        local y = floor(yw) - 1
        -- a mainsail and a jib, a hull, and their light in the water
        for k = 0, 4 do put((5.5 - k * 0.5) * e, x + k * dir, y - 9 + k * 2, 1, 9 - k * 2) end
        for k = 1, 3 do put(4 * e, x - k * dir, y - 6 + k * 2, 1, 6 - k * 2) end
        put(3.5 * e, x - 4, y, 9, 1)
        for d = 2, 8, 2 do put(2.5 * e * (1 - d / 10), x - 2 + K.heave(x + d) * 0.4, y + d, 5, 1) end
      elseif inc.name == "cloud" then
        -- a soft grey cloud drifting past the sun, lit along its top
        local cy = floor(yw) - 11
        for r = 0, 3 do
          local hw = 15 - abs(r - 1.2) * 4
          put((r == 0 and 3.5 or 2.2) * e, cloud_x - hw + r * 2, cy + r, hw * 2, 1)
        end
      else
        -- a porpoise rolls: a dark curved back out of the water and in,
        -- twice, a little apart
        for j = 0, 2 do
          local a = clamp((inc.age - 1.5 - j * 2.6) / 1.8, 0, 1)
          local px = 16 + inc.s * 60 + j * 14 + a * 8
          local py = yw + 9 + inc.s2 * 6 + j
          if a > 0 and a < 1 then
            local h = 4 * sin(math.pi * a)
            -- the back, curving over, and the fin
            put(5 * e, px - 5, py - h + 1, 4, 1); put(5.5 * e, px - 2, py - h, 5, 1); put(5 * e, px + 3, py - h + 1, 3, 1)
            put(4 * e, px, py - h - 1, 2, 1); put(4.5 * e, px + 1, py - h - 2, 1, 1)
            put(3.5 * e, px - 6, py + 1, 14, 1)
          end
          local ra = inc.age - 1.5 - j * 2.6 - 1.8
          if ra > 0 and ra < 3 then K.ring(px + 2, py + 1, 2 + ra * 5, 0.3, 4 * e * (1 - ra / 3), 16, 0, yw + 1, 64) end
        end
      end
    end
    K.glitter(sample)
  end

  return M
end
