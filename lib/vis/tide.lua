-- tide: a beach seen from the dunes, the sea above, the sand below. the last
-- ~80 bars of bloom make the shoreline, scrolling smoothly to the left; at
-- the live edge, waves wash up the sand and draw back, as far as the sound
-- carries them, with a lace of foam at their front and a wet sheen left
-- behind as they retreat. a swell floods the beach. two small shore birds
-- keep just ahead of the wash, pecking
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease

  local hist = K.hist
  local foam = {}                         -- this frame's foam front
  local wet_y = {}                        -- per column: how far the last wash reached
  local birds

  function M.init()
    foam, wet_y = {}, {}
    birds = {{x = 104, y = 50, ph = 0.4}, {x = 116, y = 52, ph = 2.2}}
  end

  function M.clear() wet_y = {} end

  local function shore_y(b) return 52 - b * 30 end

  local live_pt = {bloom = 0, wet = 0}

  -- the shoreline's bloom and wetness at a column: the live bloom at the right
  -- edge, history to the left of it sliding along smoothly between bars, the
  -- oldest value held beyond it
  local function hist_at(x, scroll)
    local n = #hist
    local d = (127 - x) / (128 / K.HIST_N)          -- bars back from the edge
    local a, b, u
    if n == 0 then return live_pt.bloom, live_pt.wet end
    if d <= scroll then
      a, b, u = live_pt, hist[n], scroll > 0 and d / scroll or 0
    else
      local f = n - (d - scroll)
      if f <= 1 then return hist[1].bloom, hist[1].wet end
      local j = math.floor(f)
      a, b, u = hist[j], hist[j + 1] or hist[j], f - j
    end
    return a.bloom + (b.bloom - a.bloom) * u, a.wet + (b.wet - a.wet) * u
  end

  local function sample(u)
    local n = #foam
    if n == 0 then return nil end
    local p = foam[math.floor(u * n) + 1]
    return p[1] + 1, p[2]
  end

  -- the wash front at a column, for the birds
  local front = {}

  function M.draw(S)
    local T, NOW = K.T, K.NOW
    live_pt.bloom = K.bloom
    live_pt.wet = K.sw_state ~= "idle" and math.max(0.35, K.sw_level) or 0
    local scroll = clamp((NOW - K.bar_t) / K.bar_len, 0, 1)
    local nf = 0
    local cyc = T / 7.5 * K.TAU                      -- the waves' slow rhythm
    local reach0 = 4 + 8 * A[K.AMP] + 6 * A[K.NAT]
    local hi = A[K.HI]
    for x = 0, 126, 2 do
      local bl, wet = hist_at(x, scroll)
      local edge = ease((x - 40) / 76)               -- 0 to the left .. 1 at the live edge
      local yl = shore_y(bl) + K.heave(x) * 0.3 + edge * math.sin(T * 1.1 + x * 0.3) * 0.6
      -- the sea above the line: swell lines that run in toward the beach,
      -- brighter near it
      for yy = 3 + (x // 2) % 3, yl - 3, 4 do
        local near = 1 - (yl - yy) / 50
        local w = math.sin(x * 0.07 + yy * 0.55 - T * 0.9 + K.drift_x * 0.08) + 0.6 * math.sin(x * 0.03 - yy * 0.2 + T * 0.3)
        if w > 0.45 - 0.35 * near then
          put((w > 1.25 and 2 or 1) + near * 0.8 + hi * 2 * math.max(0, math.sin(x * 1.3 + yy * 2.1 + T * 8)), x, yy, 2, 1)
        end
      end
      -- waves wash up the sand and draw back, as far as the sound carries
      -- them; a swell floods the whole beach
      local ph = 0.5 - 0.5 * math.cos(cyc - x * 0.02)
      local reach = reach0 * ph * (0.8 + 0.2 * math.sin(x * 0.09 + T * 0.3)) * edge + K.sw_disp * 24
      local yf = math.min(62, yl + reach)
      front[x // 2] = yf
      put(5, x, yl, 2, 1)
      -- the damp strip the sea always keeps dark-bright just above the line
      if (x // 2) % 3 ~= 0 then put(1.5, x, yl - 2, 2, 1) end
      if wet > 0.02 then put(2 + wet * 3, x, yl - 1, 2, 1) end
      -- where the last wash reached: it creeps back up slowly as it drains
      local c = x // 2
      local wy = wet_y[c] or yf
      wy = math.max(yf, wy - K.DTS * 1.2)
      wet_y[c] = wy
      if reach > 1.5 then
        -- the sheet of water over the sand: sparse glossy dashes that slide
        for yy = math.floor(yl) + 2, yf - 2, 3 do
          local w = math.sin(x * 0.15 + yy * 0.5 - T * 1.2 + K.drift_x * 0.1)
            + 0.6 * math.sin(x * 0.07 - yy * 0.9 + T * 0.5)
          if w > 0.4 then put(w > 0.85 and 2.5 or 1.5, x, yy, 2, 1) end
        end
        -- the foam: a lace of two broken rows at the front, brighter as it
        -- runs up, glittering with out_hi
        local up = math.sin(cyc - x * 0.02) > 0
        local sparkle = hi * 3 * math.max(0, math.sin(x * 1.7 + T * 9))
        local lace = math.sin(x * 0.9 + T * 2.3 + math.sin(x * 0.31))
        put((up and 6 or 4) + sparkle, x + (lace > 0 and 1 or 0), yf, lace > 0.5 and 1 or 2, 1)
        if lace > -0.3 then put(up and 3 or 2, x, yf - 1 - (lace > 0.4 and 1 or 0), 1, 1) end
        nf = nf + 1
        foam[nf] = foam[nf] or {}
        foam[nf][1], foam[nf][2] = x, yf
      end
      -- the wet sheen the retreating wash leaves: a glossy band from the
      -- front back up to where the water reached, reflecting the light
      local ys = math.max(yl, yf)
      if wy > ys + 1.5 then
        local g = math.min(1, (wy - ys) / 6)
        for yy = math.floor(ys) + 2, wy, 2 do
          if ((x // 2) + yy) % 3 ~= 0 then put(1 + g * (1 + K.bloom) + hi * 1.5 * math.max(0, math.sin(x * 0.7 + yy + T * 5)), x, yy, 2, 1) end
        end
        ys = wy
      end
      if wet > 0.02 then
        -- (a flooded beach hides most of it)
        local deep = (2 + wet * 8) * (1 - 0.7 * K.sw_disp)
        for yy = math.floor(ys) + 1 + (x // 2) % 2, ys + 1 + deep, 2 do put(1 + wet * 2, x, yy, 2, 1) end
      end
      -- dry sand: a fixed stipple, ripple marks every few rows, so the beach
      -- stays put while the water moves
      for yy = 4 + ((x // 2) % 2) * 2, 62, 4 do
        if yy >= ys + 3 then
          local h = K.hash(x * 64 + yy, 7)
          if h < 0.32 then put(h < 0.06 and 2 or 1, x + (h < 0.2 and 1 or 0), yy + (h < 0.3 and 1 or 0), 1, 1) end
          if (yy // 4) % 3 == 0 and math.sin(x * 0.2 + yy * 0.4) > 0.2 then put(1, x, yy + 2, 2, 1) end
        end
      end
    end
    for k = nf + 1, #foam do foam[k] = nil end
    -- the birds keep a few pixels ahead of the wash on dry sand, run when it
    -- comes, and peck while it draws back
    for i, b in ipairs(birds) do
      local fy = front[math.floor(b.x) // 2] or 50
      local want = clamp(fy + 4, 10, 61)
      local run = want - b.y
      b.y = b.y + run * (1 - math.exp(-K.DT * (run > 0 and 6 or 1.5)))
      b.x = clamp(b.x + math.sin(T * 0.13 + b.ph) * K.DTS * 1.5, 92, 124)
      local peck = (math.abs(run) < 1 and math.sin(T * 2.2 + b.ph * 3) > 0.6) and 1 or 0
      local x, y = math.floor(b.x), math.floor(b.y)
      local lv = 4 + K.bloom * 2
      put(lv, x, y - 3, 3, 2)                        -- body
      put(lv, x + 3, y - 4 + peck, 1, 1)             -- head
      put(lv - 1, x + 4, y - 3 + peck * 2, 1, 1)     -- bill
      put(lv - 2, x + 1, y - 1, 1, 1)                -- legs
      put(lv - 2, x + 1 + ((run > 1 and math.sin(T * 14) > 0) and 1 or 0), y, 1, 1)
    end
    K.glitter(sample)
  end

  M.init()
  return M
end
