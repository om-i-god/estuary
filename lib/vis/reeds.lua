-- reeds: a reed bed at the water's edge, in silhouette against an evening
-- glow, in three layers: a dim far bank, a middle bed, and a few tall reeds
-- close by with seed heads. every stem sways with the current and the heave,
-- and sound bends them further; a swell sends a slow wave of bending across
-- the bed. a note makes the reed nearest its pitch nod, and a longer one
-- sends a dragonfly hovering past at that column. the water below holds the
-- glow and the stems' broken reflections
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease

  local WL = 50                           -- the water's edge
  local FLY_MAX = 3
  local layers, nods, flies

  -- three layers, far to near: count, height range, level, sway, width
  local LAYERS = {
    {n = 22, h0 = 9, h1 = 16, lv = 1.5, sway = 0.5, w = 1, seed = 31},
    {n = 14, h0 = 14, h1 = 26, lv = 2.5, sway = 0.8, w = 1, seed = 32},
    {n = 6, h0 = 28, h1 = 42, lv = 4, sway = 1.1, w = 2, seed = 33},
  }

  -- the far bank: a low dark mass of reeds, its top ragged
  local bank = K.profile(function(x)
    return WL - 3 - 3 * K.hash(x // 2, 41) - 2 * math.max(0, math.sin(x * 0.06 + 1)) - 2 * K.hash(x // 7, 42)
  end)

  function M.init()
    layers, nods, flies = {}, {}, {}
    for li, L in ipairs(LAYERS) do
      local r = {}
      for k = 1, L.n do
        local u = (k - 1 + 0.15 + 0.7 * K.hash(k, L.seed)) / L.n
        r[k] = {x = -4 + u * 136, h = L.h0 + (L.h1 - L.h0) * K.hash(k, L.seed + 7),
          ph = K.hash(k, L.seed + 9) * 6, head = K.hash(k, L.seed + 11) > (li == 3 and 0.2 or 0.6)}
      end
      layers[li] = r
    end
  end

  function M.clear() nods, flies = {}, {} end

  function M.note(slot, midi, dur)
    local x = K.px(midi)
    -- the nearest reed of the middle or near layer nods
    local best, bd
    for li = 2, 3 do
      for k, r in ipairs(layers[li]) do
        local d = math.abs(r.x - x)
        if not bd or d < bd then best, bd = li * 100 + k, d end
      end
    end
    if best then nods[best] = K.T end
    if (tonumber(dur) or 0) > 1.1 and #flies < FLY_MAX then
      flies[#flies + 1] = {x = x, y = 14 + K.rnd() * 14, t0 = K.T, dir = K.rnd() < 0.5 and -1 or 1, ph = K.rnd() * 6}
    end
  end

  -- how far a reed's tip leans (px), from everything that moves it
  local function lean(r, L, key)
    local T = K.T
    local u = K.flow(r.x, WL - r.h)
    local wave = K.sw_disp * 3 * math.sin(r.x * 0.05 - T * 1.1)
    local l = (u * 0.3 + math.sin(T * 0.7 + r.ph) * (0.6 + 1.3 * K.energy) + K.heave(r.x) * 0.3 + wave) * L.sway
    local n = nods[key]
    if n then
      local age = T - n
      if age > 3 then nods[key] = nil
      else l = l + 4 * math.sin(age * 5) * math.exp(-age * 1.3) * ease(age / 0.1) end
    end
    return l
  end

  local function stem(r, L, key, base_l)
    local l = lean(r, L, key)
    local h = r.h
    local seg = L.w == 2 and 2 or 3
    local tx, ty
    for s = 0, h - 1, seg do
      local u = s / h
      local x = r.x + l * u * u
      put(base_l, x, WL - s - seg, L.w, seg)
      tx, ty = x, WL - s - seg
    end
    -- a long blade leaving the near reeds partway up, arching out and over
    if L.w == 2 then
      local by = WL - h * 0.45
      local dir = r.ph > 3 and 1 or -1
      for k = 1, 6 do
        local bx = r.x + l * 0.2 + dir * (k * 1.5 + 0.5) + l * 0.1 * k
        put(base_l * 0.8, bx, by - k * 1.7 + (k * k) * 0.1, 2, 1)
      end
    end
    if r.head and tx then
      put(base_l + 1, tx + (L.w == 2 and 0 or 0), ty - 4, L.w == 2 and 2 or 1, L.w == 2 and 5 or 3)
      if L.w == 2 then put(base_l, tx + l * 0.12 + 0.5, ty - 7, 1, 3) end
    end
    return l
  end

  local function sample(u, v) return u * 127, WL + 2 + v * 11 end

  function M.draw(S)
    local T = K.T
    -- the glow behind the bed, brighter with the bloom
    local glow = 0.75 + 0.7 * K.bloom
    K.gradient(16, WL - 1, function(y) local u = (WL - y) / 26; return glow * (1 - u) ^ 1.6 end, bank)
    for c = 0, 63 do
      local t = math.floor(bank[c] + 0.5)
      put(1, c * 2, t, 2, 1)
      for y = t + 2 + c % 3, WL - 1, 3 do put(1, c * 2, y, 2, 1) end
    end
    -- the water: the glow comes back, broken by the current
    for d = 2, 13, 2 do
      local y = WL + d
      local l = (glow + 0.6) * (1 - d / 16)
      K.streaks(l, y, 3 + (d * 7) % 4, 14 + d % 3, K.drift_x * (0.4 + d * 0.05) + d * 7, nil,
        function(x) return K.heave(x + d * 5) * 0.4, 0 end)
    end
    put(2 + K.bar_pulse, 0, WL, 128, 1)
    -- the far bank, the middle bed, the near reeds: further is dimmer
    for li, L in ipairs(LAYERS) do
      local lv = L.lv * (0.8 + 0.3 * K.bloom)
      for k, r in ipairs(layers[li]) do
        local l = stem(r, L, li * 100 + k, lv)
        -- the near reeds' reflections, broken in the water
        if li == 3 then
          for d = 2, 10, 3 do put(lv * 0.5, r.x - l * 0.08 * d + K.heave(r.x + d) * 0.6, WL + d, 2, 2) end
        end
      end
    end
    -- dragonflies: hover at their column, drift on, wings a-shimmer
    for i = #flies, 1, -1 do
      local f = flies[i]
      local age = T - f.t0
      if age > 6 then table.remove(flies, i)
      else
        local a = ease(age / 0.6) * ease((6 - age) / 1)
        local x = f.x + f.dir * (math.max(0, age - 2) ^ 1.4) * 6 + math.sin(age * 2.3 + f.ph) * 1.5
        local y = f.y + math.sin(age * 1.7 + f.ph) * 2
        local lv = 7 * a
        put(lv, x, y, 4, 1)
        local wing = math.sin(K.NOW * 30 + f.ph) > 0 and 1 or 0
        put(lv * 0.6 + A[K.HI] * 3, x + 1, y - 1 - wing, 1, 1)
        put(lv * 0.6 + A[K.HI] * 3, x + 2, y - 1 - (1 - wing), 1, 1)
        put(lv * 0.5, x + 1, y + 1, 2, 1)
      end
    end
    K.glitter(sample, 14)
  end

  M.init()
  return M
end
