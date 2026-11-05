-- mist: morning fog on the estuary. a faint far shore and a pale sun sit
-- behind banks of mist that drift with the current over still water. the
-- fog thickens with out_lo and the water sounds, and a swell rolls more in.
-- each note opens a small clear patch at its pitch, showing a post or a
-- buoy standing in the water there; a passing moment lets the sun break
-- through for a while, thinning the fog round it
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease

  local WL = 38
  local CLEAR_MAX = 6
  local clears

  -- the far shore: a low line of land with a few trees, very faint
  local trees = K.crowns(23, 9, WL - 2, 2, 7, 3, 6)
  local shore = K.profile(function(x) return math.min(trees(x), WL - 2 + 0.6 * math.sin(x * 0.2)) end)

  function M.init() clears = {} end
  function M.clear() clears = {} end

  function M.note(slot, midi)
    local x = K.px(midi)
    -- a post on the left half, a buoy on the right, at the note's column
    clears[#clears + 1] = {x = x, y = WL + 4 + ((midi or 60) % 5) * 3, t0 = K.T, buoy = x > 64, slot = slot}
    if #clears > CLEAR_MAX then table.remove(clears, 1) end
  end

  -- how open the fog is at a point (0 = as thick as it is, 1 = clear)
  local function openness(x, y)
    local o = 0
    for _, c in ipairs(clears) do
      local age = K.T - c.t0
      local a = ease(age / 0.8) * (1 - ease((age - 4) / 3))
      if a > 0 then
        local dx, dy = (x - c.x) / 11, (y - c.y + 6) / 9
        local d = dx * dx + dy * dy
        if d < 1 then o = math.max(o, a * (1 - d)) end
      end
    end
    return o
  end

  local function sample(u, v) return u * 127, WL + 3 + v * 22 end

  function M.draw()
    local T = K.T
    local bloom = K.bloom
    local sun = clamp(1 - K.moment_age / 14, 0, 1)
    sun = ease(math.min(sun * 4, 1)) * (sun > 0 and 1 or 0)
    -- density: thicker with out_lo and the water sounds, a swell rolls more in,
    -- the sun burns it back while it shines
    local dens = clamp(0.35 + 0.35 * A[K.LO] + 0.25 * A[K.NAT] + 0.35 * K.sw_disp - 0.25 * sun, 0.15, 0.8)
    -- the sun: a pale disc behind the fog, high to the right; when a moment
    -- passes it comes through brighter, with a glow round it
    local sx, sy = 92 + 4 * math.sin(T * 0.02), 13
    local sl = 1.5 + bloom * 0.8 + sun * 5
    for dy = -4, 4 do
      local hw = math.floor(math.sqrt(20 - dy * dy) + 0.5)
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
        local fl = 0.5 + 0.5 * math.sin(T * 2 + y * 1.7)
        put(sun * (2 + 2 * fl), sx - 2 - fl * 3, y, 4 + fl * 6, 1)
      end
    end
    -- the far shore, and its reflection, very faint
    for c = 0, 63 do
      local t = math.floor(shore[c] + 0.5)
      if t < WL then put(1.2, c * 2, t, 2, WL - t) end
    end
    for d = 2, 8, 2 do
      K.streaks(1, WL + d, 7, 10, K.drift_x * 0.3 + d * 3, function(x) return WL - d < K.at(shore, x) + 2 end)
    end
    put(1.5, 0, WL, 128, 1)
    -- still water: long faint streaks, the light lying on it
    for y = WL + 3, 63, 3 do
      local d = (y - WL) / 26
      K.streaks(1 + bloom * 0.6 + d * 0.5, y, 8 + d * 10, 30 + d * 10, K.drift_x * (0.2 + d * 0.4) + y * 7.1, nil,
        function(x) return K.heave(x + y) * 0.5, A[K.HI] * 1.5 * math.max(0, math.sin(x * 0.7 + y + T * 4)) end)
    end
    -- the posts and buoys a note shows through the fog
    for i = #clears, 1, -1 do
      local c = clears[i]
      local age = T - c.t0
      local a = ease(age / 0.8) * (1 - ease((age - 4) / 3))
      if age > 7 then table.remove(clears, i)
      elseif a > 0.02 then
        local lv = (4 + 2 * (1 - (c.slot - 1) / 4)) * a
        local bob = K.heave(c.x) * 0.4
        if c.buoy then
          put(lv, c.x - 1, c.y - 4 + bob, 3, 3)
          put(lv * 0.8, c.x, c.y - 6 + bob, 1, 2)
          put(lv + 2 * a * math.max(0, math.sin(K.NOW * 2)), c.x, c.y - 7 + bob, 1, 1)   -- a slow light
        else
          put(lv, c.x, c.y - 9, 2, 9)
          put(lv * 0.7, c.x - 1, c.y - 9, 4, 1)
        end
        for k = 1, 3 do put(lv * 0.35, c.x - 1 + math.sin(T * 2 + k) * 0.8, c.y + k * 2 - 1, 3, 1) end
      end
    end
    -- the fog: drifting banks of long dashes, rows staggered; each row's
    -- dashes are kept where a slow noise across the bank says the fog is
    -- thick enough, and left out round a clear patch
    local dx = K.drift_x
    for y = 2, 61, 2 do
      local band = 0.6 + 0.4 * math.sin(y * 0.19 + T * 0.05) + 0.3 * math.sin(y * 0.07 - T * 0.03)
      local gap = 10
      local off = dx * (0.8 + 0.3 * math.sin(y)) + y * 5.3 + T * 0.8
      for x = (off % gap) - gap, 127, gap do
        local n = math.sin(x * 0.045 + y * 0.11 - dx * 0.02 + T * 0.04) + 0.6 * math.sin(x * 0.11 - y * 0.23 + T * 0.09)
        local thick = (n * 0.5 + 0.5) * band
        if thick > 1.05 - dens then
          local o = openness(x + 3, y)
          if o < 0.4 then
            local l = (1 + (thick > 1.3 - dens * 0.5 and 1 or 0) + bloom * 0.5) * (1 - o)
            put(l, x, y, clamp(math.floor(2 + (thick - 1.05 + dens) * 6), 2, 7), 1)
          end
        end
      end
    end
    K.glitter(sample, 20)
  end

  M.init()
  return M
end
