-- mist: morning fog on the estuary. a faint far shore and a pale sun sit
-- behind banks of mist that drift with the current over still water, a few
-- reed stalks standing close by. the chord lies in the fog as four denser
-- layers, higher for higher tones, centred across by pitch, that drift to
-- their new heights when it changes. the fog thickens with out_lo and the
-- water sounds, and a swell rolls more in; out_mid draws its banks out into
-- long tendrils; the bloom brightens and thins it; it breathes on the bar.
-- each note opens a small clear patch at its pitch and shows what stands
-- in the water there, by motif: a post, a buoy with its slow light, a
-- moored boat, a post with a cormorant drying its wings. out_hi sparkles on
-- the still water; the water sounds lap at the near edge. a passing moment
-- lets the sun break through for a while, thinning the fog round it. now
-- and then a rowing boat crosses far off, a swan glides by, or geese pass
-- over, heard more than seen
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, floor = math.sin, math.floor

  M.incidents = {{"rowboat", 26}, {"swan", 22}, {"geese", 12}}

  local WL = 38
  local CLEAR_MAX = 6
  local clears

  -- the far shore: a low line of land with a few trees, very faint
  local trees = K.crowns(23, 9, WL - 2, 2, 7, 3, 6)
  local shore = K.profile(function(x) return math.min(trees(x), WL - 2 + 0.6 * sin(x * 0.2)) end)
  local shore_l = K.bake(function(rec)
    for c = 0, 63 do
      local t = floor(shore[c] + 0.5)
      if t < WL then rec(1.2, c * 2, t, 2, WL - t) end
    end
  end)
  -- reed stalks close by, bottom right: {x, height, phase}
  local NEAR = {{112, 16, 0.3}, {116, 12, 1.7}, {119, 19, 2.9}, {123, 14, 4.1}, {126, 10, 5.2}}

  function M.init() clears = {} end
  function M.clear() clears = {} end

  function M.note(slot, midi)
    local x = K.px(midi)
    clears[#clears + 1] = {x = x, y = WL + 4 + (1 - K.pu(midi)) * 12, t0 = K.T, slot = slot}
    if #clears > CLEAR_MAX then table.remove(clears, 1) end
  end

  -- each kind of thing opens its own shape of clear patch: half width, half height
  local SHAPE = {{13, 15}, {22, 8}, {26, 10}, {15, 17}}

  -- how open the fog is at a point (0 = as thick as it is, 1 = clear)
  local function openness(x, y)
    local o = 0
    for _, c in ipairs(clears) do
      local age = K.T - c.t0
      local a = ease(age / 0.8) * (1 - ease((age - 4) / 3))
      if a > 0 then
        local sh = SHAPE[c.slot] or SHAPE[1]
        local dx, dy = (x - c.x) / sh[1], (y - c.y + 6) / sh[2]
        local d = dx * dx + dy * dy
        if d < 1.6 then o = math.max(o, a * (1 - d) * 0.8 + 0.2 * a * (1.6 - d) / 1.6) end
      end
    end
    return o
  end

  local function sample(u, v) return u * 127, WL + 3 + v * 22 end

  -- the chord's layers: tone i -> centre x, y, presence
  local LY = {{0, 0, 0}, {0, 0, 0}, {0, 0, 0}, {0, 0, 0}}

  function M.draw()
    local T = K.T
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local hi, mid, nat, lo = A[K.HI], A[K.MID], A[K.NAT], A[K.LO]
    -- the sun after a moment: eases in over ~1.5 s, out over the last 3.5
    local age = K.moment_age
    local sun = ease(clamp(age / 1.5, 0, 1)) * ease(clamp((14 - age) / 3.5, 0, 1))
    -- density: thicker with out_lo and the water sounds, a swell rolls more in,
    -- the bloom thins it a little, the sun burns it back while it shines
    local dens = clamp(0.3 + 0.4 * lo + 0.3 * nat + 0.35 * sw - 0.25 * sun - 0.1 * bloom, 0.12, 0.75)
    -- the sun: a pale disc behind the fog, high to the right; when a moment
    -- passes it comes through brighter, with a glow round it
    local sx, sy = 92 + 4 * sin(T * 0.02), 13
    local sl = 1.5 + bloom * 1.2 + sun * 5
    for dy = -4, 4 do
      local hw = floor(math.sqrt(20 - dy * dy) + 0.5)
      put(sl - (math.abs(dy) > 3 and 0.5 or 0), sx - hw, sy + dy, 2 * hw, 1)
    end
    if sun > 0.05 then
      for r = 1, 3 do
        local y0 = sy - 4 - r * 2
        put(sun * (2.5 - r * 0.6), sx - 6 - r * 3, sy + 6 + r * 2, 12 + r * 6, 1)
        put(sun * (2.5 - r * 0.6), sx - 5 - r * 2, y0, 10 + r * 4, 1)
      end
      -- its path on the water
      for y = WL + 2, 62, 2 do
        local fl = 0.5 + 0.5 * sin(T * 2 + y * 1.7)
        put(sun * (2 + 2 * fl), sx - 2 - fl * 3, y, 4 + fl * 6, 1)
      end
    end
    -- the far shore, and its reflection, very faint
    K.blit(shore_l, 1 + 0.3 * bloom)
    for d = 2, 8, 2 do
      K.streaks(1, WL + d, 7, 10, K.drift_x * 0.3 + d * 3, function(x) return WL - d < K.at(shore, x) + 2 end)
    end
    put(1.5 + breath, 0, WL, 128, 1)
    -- still water: long faint streaks, the light lying on it, sparkling
    -- with out_hi
    for y = WL + 3, 63, 3 do
      local d = (y - WL) / 26
      K.streaks(1 + bloom * 0.6 + d * 0.5 + breath, y, 8 + d * 10, 30 + d * 10, K.drift_x * (0.2 + d * 0.4) + y * 7.1, nil,
        function(x) return K.heave(x + y) * 0.5, hi * 4.5 * math.max(0, sin(x * 0.7 + y + T * 4)) end)
    end
    -- the water sounds lap at the near edge
    if nat > 0.03 then
      for r = 0, 1 do
        local y = 60 + r * 2
        for x = (K.drift_x + r * 5 + T * 2) % 9 - 9, 127, 9 do
          local w = sin(x * 0.4 + T * 1.8 + r)
          if w > 0.2 then put(nat * (2 + 2 * w), x, y + (w > 0.7 and -1 or 0), 4, 1) end
        end
      end
    end
    -- the posts, buoys and boats a note shows through the fog
    for i = #clears, 1, -1 do
      local c = clears[i]
      local cage = T - c.t0
      local a = ease(cage / 0.8) * (1 - ease((cage - 4) / 3))
      if cage > 7 then table.remove(clears, i)
      elseif a > 0.02 then
        local lv = 6.5 * a
        local bob = K.heave(c.x) * 0.4
        if c.slot == 2 then
          -- a buoy, its slow light, the light lying on the water
          local blink = math.max(0, sin(K.NOW * 2))
          put(lv, c.x - 1, c.y - 4 + bob, 3, 3)
          put(lv * 0.8, c.x, c.y - 6 + bob, 1, 2)
          put(lv + 3 * a * blink, c.x, c.y - 7 + bob, 1, 1)
          put(2.5 * a * blink, c.x - 2, c.y - 8 + bob, 5, 3)
          for d = 1, 4 do put(3 * a * blink * (1 - d / 5), c.x - 1, c.y + d * 2, 3, 1) end
        elseif c.slot == 3 then
          -- a moored boat
          put(lv, c.x - 6, c.y - 2 + bob, 13, 1); put(lv * 0.8, c.x - 5, c.y - 1 + bob, 11, 1)
          put(lv * 0.7, c.x - 1, c.y - 9 + bob, 1, 7)
        elseif c.slot == 4 then
          -- a low rock with a cormorant on it, drying its wings
          put(lv * 0.8, c.x - 4, c.y - 2, 9, 2); put(lv * 0.7, c.x - 2, c.y - 3, 5, 1)
          put(lv * 1.1, c.x - 1, c.y - 7, 3, 4)
          local wing = 3 + sin(K.NOW * 0.8)
          put(lv * 0.9, c.x - 1 - wing, c.y - 8, wing, 1); put(lv * 0.9, c.x + 2, c.y - 8, wing, 1)
          put(lv * 0.7, c.x - 1 - wing, c.y - 7, 2, 1); put(lv * 0.7, c.x + wing, c.y - 7, 2, 1)
          put(lv, c.x, c.y - 10, 1, 3)
        else
          -- a pair of mooring posts
          put(lv, c.x - 2, c.y - 11, 2, 11); put(lv * 0.8, c.x + 3, c.y - 8, 2, 8)
          put(lv * 0.7, c.x - 3, c.y - 11, 4, 1)
          for d = 1, 5 do put(lv * 0.3, c.x - 2 + K.heave(c.x + d) * 0.6, c.y + d * 1.5, 2, 1) end
        end
        for k = 1, 4 do put(lv * 0.4, c.x - 1 + sin(T * 2 + k) * 0.8, c.y + k * 2 - 1, 3, 1) end
        -- the clear patch lets the light through onto the water round it
        put(2.5 * a, c.x - 8, c.y + 1, 17, 1)
      end
    end
    -- incidents that sit under the fog
    local inc = K.inc
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "rowboat" then
        -- a rowing boat crosses far off, the oars dipping
        local x = -12 + u * 152
        local y = WL + 3
        local row = sin(inc.age * 1.8)
        put(4 * e, x - 5, y, 11, 1); put(3.5 * e, x - 1, y - 3, 2, 3)
        put(3 * e, x - 4 + row * 2, y + 1, 1, 1); put(3 * e, x + 4 + row * 2, y + 1, 1, 1)
        for d = 2, 6, 2 do put(2 * e, x - 4 + K.heave(x + d) * 0.5, y + d, 9, 1) end
      elseif inc.name == "swan" then
        -- a swan glides by, its neck curved, its wake spreading
        local dir = inc.s > 0.5 and 1 or -1
        local x = dir > 0 and (-10 + u * 148) or (138 - u * 148)
        local y = WL + 12 + inc.s2 * 6
        put(6 * e, x - 4, y - 2, 8, 2); put(5 * e, x - 3 * dir - (dir > 0 and 1 or 0), y - 3, 3, 1)
        put(6 * e, x + 3 * dir, y - 6, 1, 4); put(6 * e, x + 3 * dir + (dir > 0 and 0 or -1), y - 7, 2, 1)
        for k = 1, 5 do
          put(2.5 * e * (1 - k / 6), x - dir * (4 + k * 3), y + k * 0.5, 2, 1)
          put(2.5 * e * (1 - k / 6), x - dir * (4 + k * 3), y - 1 - k * 0.3, 2, 1)
        end
      end
    end
    -- the fog: drifting banks of long dashes, rows staggered; each row's
    -- dashes are kept where a slow noise across the bank says the fog is
    -- thick enough, and left out round a clear patch. the chord's layers
    -- make it denser and brighter at their heights
    for i = 1, 4 do
      local m, p = K.chord_at(i)
      local L = LY[i]
      if m then
        L[1], L[2], L[3] = K.cx(m), clamp(4 + (76 - m) / 40 * 44, 4, 56), p
      else
        L[3] = 0
      end
    end
    local dx = K.drift_x
    local any = #clears > 0
    local gap = 10
    local wmul = 1 + 0.9 * mid
    for y = 2, 61, 2 do
      local band = 0.6 + 0.4 * sin(y * 0.19 + T * 0.05) + 0.3 * sin(y * 0.07 - T * 0.03)
      local lay, layx = 0, 64
      for i = 1, 4 do
        local L = LY[i]
        local d = math.abs(y - L[2])
        if L[3] > 0 and d < 4 then
          local v = (1 - d / 4) * L[3]
          if v > lay then lay, layx = v, L[1] end
        end
      end
      band = band + 0.5 * lay
      local off = dx * (0.8 + 0.3 * sin(y)) + y * 5.3 + T * 0.8
      -- each wisp keeps its own length and place as it drifts: drawn by
      -- hand, not ruled
      local k = -floor(off / gap) + y * 17
      for x0 = (off % gap) - gap, 127, gap do
        local h = (((k * 2654435761) >> 8) & 0xff) / 255
        k = k + 1
        local x = x0 + (h - 0.5) * 5
        local n = sin(x * 0.045 + y * 0.11 - dx * 0.02 + T * 0.04) + 0.6 * sin(x * 0.11 - y * 0.23 + T * 0.09)
        local thick = (n * 0.5 + 0.5) * band
        if lay > 0 then thick = thick + 0.4 * lay * math.max(0, 1 - math.abs(x - layx) / 40) end
        if thick > 1.05 - dens then
          local o = any and openness(x + 3, y) or 0
          if o < 0.45 then
            -- (the fog round a clear patch is lit by the light coming through)
            local l = (1 + (thick > 1.3 - dens * 0.5 and 1 or 0) + bloom * 0.6 + breath * 1.8 + lay * (0.6 + 1.2 * K.chord_glow)
              + o * 7) * (1 - o)
            put(l, x, y + (h > 0.85 and 1 or 0), clamp(floor((2 + (thick - 1.05 + dens) * 5) * wmul * (0.6 + 0.8 * h)), 1, 9), 1)
          end
        end
      end
    end
    -- reed stalks close by, in front of the fog
    for _, r in ipairs(NEAR) do
      local x0, h = r[1], r[2]
      local lean = sin(T * 0.5 + r[3]) * (0.5 + 0.8 * K.energy) + K.heave(x0) * 0.4
      for s = 0, h - 1, 3 do
        local uu = s / h
        put(2.5, x0 + lean * uu * uu, 63 - s - 3, 1, 3)
      end
      put(3, x0 + lean, 63 - h - 3, 1, 3)
    end
    -- geese pass over, above the fog
    if inc and inc.name == "geese" then
      local e, u = inc.e, inc.u
      for k = 0, 6 do
        local side = (k % 2 == 0) and 1 or -1
        local rank = (k + 1) // 2
        local x, y = 140 - u * 160 + rank * 6, 8 + side * rank * 2.2 + sin(u * 4) * 2
        K.bird(x, y, 5 * e, sin(K.NOW * 3.5 + k), 2)
      end
    end
    K.glitter(sample, 20)
  end

  M.init()
  return M
end
