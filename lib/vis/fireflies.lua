-- fireflies: a marsh at dusk. the last light glows over a dark tree line,
-- warmer as the bloom opens, a first few stars above; reeds stand at the
-- water's edge, and the still water below holds the glow. fireflies drift
-- on the current, a few always faintly there; each note lights one at its
-- pitch, and it glows and fades slowly. every firefly shows again, dimmer
-- and wavering, in the water
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease

  local WL = 45
  local FLY_MAX = 20
  local AMBIENT = 7
  local flies

  local STARS = {{12, 3}, {37, 8}, {58, 2}, {83, 6}, {104, 3}, {121, 9}, {25, 13}, {70, 11}}

  local trees = K.crowns(17, 14, WL, 8, 18, 5, 10)
  local sky_prof = K.profile(function(x)
    return math.min(trees(x), WL - 24 + math.abs(x - 96) * 1.6) + 0.5 * math.sin(x * 1.3)
  end)

  function M.init()
    flies = {}
    for k = 1, AMBIENT do
      flies[k] = {x = 8 + (k - 1) * 17 + 6 * K.hash(k, 71), y = 24 + 18 * K.hash(k, 72),
        ph = K.hash(k, 73) * 6, amb = true, t0 = -99, pk = 0}
    end
  end

  function M.clear()
    for i = #flies, 1, -1 do if not flies[i].amb then table.remove(flies, i) end end
  end

  function M.note(slot, midi)
    -- a note lights a firefly at its pitch: an ambient one nearby if there
    -- is one, otherwise a new one
    local x = K.px(midi)
    local f
    for _, a in ipairs(flies) do
      if math.abs(a.x - x) < 6 and K.T - a.t0 > 2 then f = a; break end
    end
    if not f then
      if #flies >= FLY_MAX then
        for i, a in ipairs(flies) do if not a.amb then table.remove(flies, i); break end end
      end
      f = {x = x, y = 18 + K.rnd() * 24, ph = K.rnd() * 6, amb = false}
      flies[#flies + 1] = f
    end
    f.t0, f.pk = K.T, 7 + 3 * (1 - (slot - 1) / 4)
  end

  local function sample(u, v) return u * 127, WL + 2 + v * 14 end

  function M.draw()
    local T, DTS = K.T, K.DTS
    local bloom = K.bloom
    -- the sky: the last light low over the trees, stars higher up
    local glow = 1.9 + 1.2 * bloom
    local function sky(y) return glow * clamp(1 - (34 - y) / 18, 0, 1) ^ 1.6 end
    K.gradient(10, WL - 1, sky, sky_prof)
    for i, s in ipairs(STARS) do
      put((1.5 - bloom * 0.6) * (1.1 + 0.6 * math.sin(T * 0.5 + i * 2.3)), s[1], s[2], 1, 1)
    end
    -- reeds at the water's edge, faint against the dark trees
    for k = 0, 13 do
      local x = k * 9.3 + 4 * K.hash(k, 74)
      for j = 0, 2 do
        local h = 3 + 4 * K.hash(k * 3 + j, 75)
        local lean = (K.flow(x, WL) * 0.2 + math.sin(T * 0.6 + k + j) * 0.5 + K.heave(x) * 0.4) + (j - 1)
        put(1, x + j, WL - h * 0.5, 1, h * 0.5)
        put(1, x + j + lean, WL - h, 1, h * 0.5)
      end
    end
    put(1.5 + bloom, 0, WL, 128, 1)
    -- the water: the glow lies in it below the trees' reflection
    for d = 1, 18 do
      if d % 2 == 0 or d < 3 then
        local keep = function(x) return WL - d * 1.2 < K.at(sky_prof, x) end
        local l = sky(WL - d * 1.2) * 0.7
        K.streaks(l, WL + d, 6 + d % 4, 9 + d % 3, K.drift_x * (0.3 + d * 0.03) + d * 4.7, keep,
          function(x) return K.heave(x + d * 3) * (0.3 + d * 0.06), 0 end)
      end
    end
    -- the fireflies
    for i = #flies, 1, -1 do
      local f = flies[i]
      local u, v = K.flow(f.x, f.y)
      f.x = f.x + (u * 0.35 + math.sin(T * 0.4 + f.ph) * 1.2) * DTS
      f.y = clamp(f.y + (v * 0.3 + math.sin(T * 0.53 + f.ph * 2) * 1.0) * DTS, 14, WL - 3)
      if f.x > 131 then f.x = -3 elseif f.x < -3 then f.x = 131 end
      local age = T - f.t0
      local lit = 0
      if age < 6 then lit = f.pk * ease(age / 0.5) * (1 - ease((age - 1) / 5)) end
      local base = f.amb and (1.5 + 1.2 * (0.5 + 0.5 * math.sin(T * 0.8 + f.ph))) or 0
      local lv = math.max(base, lit)
      if not f.amb and age >= 6 then
        table.remove(flies, i)
      elseif lv >= 0.5 then
        put(lv, f.x, f.y, 1, 1)
        if lv > 5 then
          local h = lv * 0.25
          put(h, f.x - 1, f.y, 1, 1); put(h, f.x + 1, f.y, 1, 1)
          put(h, f.x, f.y - 1, 1, 1); put(h, f.x, f.y + 1, 1, 1)
        end
        -- the reflection, below the edge, wavering
        local ry = WL + (WL - f.y) * 0.55 + 1
        if ry < 63 then
          local rx = f.x + K.heave(f.x + ry) * 0.6 + math.sin(T * 3 + ry) * 0.6
          put(lv * 0.4, rx, ry, 1, 1)
          if lv > 4 then put(lv * 0.2, rx, ry + 1, 1, 1) end
        end
      end
    end
    K.glitter(sample, 10)
  end

  M.init()
  return M
end
