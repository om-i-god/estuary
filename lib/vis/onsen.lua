-- onsen: a hot spring among snowy rocks on a winter afternoon. a pale sky
-- and a low soft sun over a snowy slope with dark pines far behind, the
-- pool in front ringed by boulders capped with snow, a bare branch
-- reaching over it from the right, and steam rising off the water. the
-- chord is the warm light on the water: four soft patches across the pool
-- by pitch, brighter for higher tones, gliding when the chord moves. a note
-- is a drop falling from the branch at its pitch's place and rippling the
-- pool, by motif: a single drop (the first), two drops one after the other
-- (the second), a heavy drop throwing a little crown (the third), a slow
-- drip that leaves a ring lingering (the fourth). out_mid sets how high and
-- how much the steam rises and curls, out_amp how fast; out_lo rocks the
-- pool's surface and sways the branch; out_hi sparkles on the snow and the
-- water; the water sounds are the spring itself welling up in bubbles and
-- trickling in over the rocks. the bloom is the winter sun, warming the
-- sky, the snow and the steam; the bar breathes in the pool's light; a
-- swell is a gust that clears the steam, blowing snow off the rocks, and
-- then lets it gather again. a passing moment brings a gentle snowfall
-- that melts on the water. now and then snow slides off the branch, a
-- small bird lands on a rock, or a stone lantern by the pool is lit
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, cos, floor, abs = math.sin, math.cos, math.floor, math.abs

  M.incidents = {{"snowslide", 12}, {"bird", 16}, {"lantern", 24}}

  local PX, PY, PRX, PRY = 62, 45, 44, 11  -- the pool: centre, half width, half height
  local MARK_MAX = 8
  local marks
  local steam_t = 0                       -- the steam's rise, integrated

  -- the pool's edge on row y: its left and right
  local function pool(y)
    local d = (y - PY) / PRY
    if d <= -1 or d >= 1 then return nil end
    local hw = PRX * math.sqrt(1 - d * d)
    return PX - hw, PX + hw
  end
  -- the snowy slope behind, and the pines on it, baked once
  local slope = K.profile(function(x) return 22 - 7 * sin(x * 0.02 + 0.4) - 2 * sin(x * 0.09) end)
  local pines = K.bake(function(rec)
    for k = 1, 13 do
      local x = floor(4 + (k - 1) * 9.5 + 5 * K.hash(k, 1401))
      local base = K.at(slope, x) + 1
      local h = 6 + floor(6 * K.hash(k, 1402))
      for j = 0, h - 1 do
        local w = 1 + floor((j / h) * 2.5)
        rec(1.1 + 0.4 * K.hash(k * 16 + j, 1403), x - w + 1, base - h + j, w * 2 - 1, 1)
      end
    end
  end)
  -- the snowfield's texture and its lit crest
  local snow = K.bake(function(rec)
    for c = 0, 63 do
      local t = floor(slope[c] + 0.5)
      rec(2.4 + 0.5 * K.hash(c, 1404), c * 2, t, 2, 1)
      for y = t + 2, 33 do
        if K.hash(c * 64 + y, 1405) < 0.035 then rec(1.2, c * 2, y, 2, 1) end
      end
    end
  end)
  -- the boulders round the pool, each capped with snow: {x, y, half width, height}
  local ROCK = {}
  for k = 1, 14 do
    local a = (k - 0.5) / 14 * math.pi * 2 + 0.2 * K.hash(k, 1406)
    local x, y = PX + cos(a) * (PRX + 3), PY + sin(a) * (PRY + 3)
    ROCK[k] = {x, y, 4 + 4 * K.hash(k, 1407), 3 + 3 * K.hash(k, 1408)}
  end
  local rocks = K.bake(function(rec)
    for _, r in ipairs(ROCK) do
      local x, y, hw, h = r[1], r[2], r[3], r[4]
      -- (a rounded mass in hand-made strokes: thicker and lit toward its
      -- upper left, thinning to its foot, its outline soft)
      local q = 0
      for j = 0, h do
        local w = hw * math.sqrt(math.max(0, 1 - (j / (h + 1)) ^ 2))
        local yy = floor(y - j + h * 0.4)
        local xx = x - w
        while xx < x + w do
          q = q + 1
          local len = 2 + floor(3 * K.hash(q + floor(x) * 50, 1423))
          local u = (xx - (x - w)) / math.max(1, 2 * w)
          local dens = 0.25 + 0.4 * (j / (h + 1)) + 0.2 * (1 - u)
          if K.hash(q + floor(x) * 50, 1424) < dens then
            rec(1 + 0.8 * (1 - u) * (j / (h + 1)) + 0.3 * K.hash(q, 1425), xx, yy, math.min(len, x + w - xx), 1)
          end
          xx = xx + len
        end
      end
    end
  end)
  local caps = K.bake(function(rec)
    for k, r in ipairs(ROCK) do
      local x, y, hw, h = r[1], r[2], r[3], r[4]
      local top = y - h + h * 0.4
      rec(3.2 + 0.6 * K.hash(k, 1409), x - hw * 0.7, top - 1, hw * 1.4, 1)
      if K.hash(k, 1422) < 0.5 then rec(2.4, x - hw * 0.4 + K.hash(k, 1421) * 2, top - 2, hw * 0.6, 1) end
    end
  end)
  -- the branch over the pool from the right: points along it
  local BR = {}
  for k = 0, 40 do
    local u = k / 40
    BR[#BR + 1] = {128 - u * 104, 9 + u * 6 + 3 * sin(u * 3.5)}
  end
  local function branch_y(x)
    local u = clamp((128 - x) / 104, 0, 1)
    return 9 + u * 6 + 3 * sin(u * 3.5)
  end
  local SNOWGLINT = {}
  for k, r in ipairs(ROCK) do
    SNOWGLINT[#SNOWGLINT + 1] = floor(r[1] - r[3] * 0.5 + r[3] * K.hash(k, 1410))
    SNOWGLINT[#SNOWGLINT + 1] = floor(r[2] - r[4] + r[4] * 0.4 - 1)
  end
  for k = 1, 80 do
    local x = floor(128 * K.hash(k, 1411))
    SNOWGLINT[#SNOWGLINT + 1] = x; SNOWGLINT[#SNOWGLINT + 1] = floor(K.at(slope, x) + 1 + 6 * K.hash(k, 1412))
  end
  -- the steam's wisps: {x, phase, speed}
  local WISP = {}
  for k = 1, 16 do WISP[k] = {PX - PRX + 8 + (PRX * 2 - 16) * K.hash(k, 1413), K.hash(k, 1414), 0.7 + 0.6 * K.hash(k, 1415)} end
  local FLAKE = {}
  for k = 1, 46 do FLAKE[k] = {128 * K.hash(k, 1416), K.hash(k, 1417), 0.6 + 0.6 * K.hash(k, 1418)} end

  function M.init() marks, steam_t = {}, 0 end
  function M.clear() marks = {} end

  function M.note(slot, midi)
    local x = clamp(K.px(midi), PX - PRX + 6, PX + PRX - 6)
    local d = (x - PX) / PRX
    local y = PY + (1 - K.pu(midi) * 2) * PRY * 0.6 * math.sqrt(math.max(0, 1 - d * d))
    K.cap_add(marks, {slot = slot, x = x, y = y, t0 = K.T}, MARK_MAX)
  end

  local function sample(u, v)
    local y = PY - PRY + 2 + v * (PRY * 2 - 4)
    local l, r = pool(y)
    if not l then return nil end
    return l + 2 + u * (r - l - 4), y
  end

  -- one drop of a note: falling from the twig at by, then its ring
  local function drop(mk, age, e, by, fall, t0, sz, dx)
    local x, y = mk.x + (dx or 0), mk.y
    local a = (age - t0) / fall
    if a > 0 and a < 1 then
      local dy = by + (y - by) * a * a
      put(10 * e, x, dy, sz + 1, sz + 2)
      put(5 * e, x, dy - 3, 1, 3)
    elseif a >= 1 then
      local ra = (age - t0) - fall
      local rr = 1.5 + ra * (mk.slot == 4 and 2.5 or (mk.slot == 3 and 9 or 4))
      local life = mk.slot == 4 and 4 or 2.6
      if ra < life then
        K.ring(x, y, rr, 0.3, 11 * e * (1 - ra / life) * ease(ra / 0.12), 14, 0, PY - PRY, PY + PRY)
        if mk.slot ~= 2 then K.ring(x, y, rr * 0.6, 0.3, 6 * e * (1 - ra / life) * ease(ra / 0.12), 8, 0, PY - PRY, PY + PRY) end
      end
    end
  end

  -- the winter sky (its light set each frame)
  local F_sky = 1
  local function sky(y) return F_sky * (0.12 + 0.38 * (y / 24) ^ 1.5) end

  function M.draw()
    local T = K.T
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local hi, mid, nat, lo, amp = A[K.HI], A[K.MID], A[K.NAT], A[K.LO], A[K.AMP]
    steam_t = steam_t + K.DTS * (0.12 + 0.25 * amp)
    -- the pale winter sky and the low sun, warming with the bloom
    F_sky = 0.7 + 0.9 * bloom + 0.5 * breath
    K.gradient(0, 30, sky, slope)
    local sx, sy = 26, 7 + 3 * (1 - bloom)
    for dy = -3, 3 do
      local hw = math.sqrt(10 - dy * dy)
      K.dash(3.5 + 3 * bloom + K.bj(dy + 9) * 0.3, sx - hw, sy + dy, floor(hw * 2))
    end
    for dy = -7, 7 do
      local hw = 9 * math.sqrt(math.max(0, 1 - (dy / 8) ^ 2))
      K.dither_row((0.5 + 0.6 * bloom) * (1 - abs(dy) / 9), sy + dy, slope, floor(sx - hw), floor(sx + hw))
    end
    K.blit(snow, 1 + 0.4 * bloom)
    K.blit(pines, 1 + 0.2 * bloom, K.drift_x * 0.03)
    -- the pool: warm dark water, a glow on it breathing on the bar, the
    -- surface's slow lines rocking with out_lo
    local inc = K.inc
    local lant = (inc and inc.name == "lantern") and inc.e * ease(clamp((inc.age - 3) / 4, 0, 1)) or 0
    for y = PY - PRY + 1, PY + PRY - 1 do
      local l, r = pool(y)
      if l then
        local d = (y - PY) / PRY
        if y % 2 == 0 then K.dither_row((0.18 + 0.22 * bloom + 0.9 * breath) * (1 - abs(d) * 0.5), y, nil, floor(l + 1), floor(r)) end
        if (y - PY) % 5 == 0 and y > PY - 4 then
          local yy = y + K.heave(y * 4) * (0.3 + 0.8 * lo)
          K.streaks(1.4 + 0.6 * bloom + breath * 1.2, yy, 4, 12, K.drift_x * 0.2 + y * 7 + T * (0.6 + 1.5 * amp), nil, nil, floor(l + 2), floor(r - 1))
        end
      end
    end
    -- the chord: warm light lying on the water across the pool
    for i = 1, 4 do
      local m, p = K.chord_at(i)
      if m and p > 0.02 then
        local cx = PX - PRX + 8 + (K.cx(m) - 4) / 119 * (PRX * 2 - 16)
        local cy = PY - 4 + (i % 2) * 6
        local lv = (0.8 + clamp((m - 36) / 40, 0, 1) * 1.6 + 1.2 * K.chord_glow) * p
        for dy = -2, 2 do
          local hw = 9 * (1 - abs(dy) * 0.25)
          K.dither_row(lv * (1 - abs(dy) * 0.22), cy + dy, nil, math.max(0, floor(cx - hw)), math.min(128, floor(cx + hw)))
        end
        K.hline(lv * 2.2, cy, floor(cx - 4), floor(cx + 4), 3)
      end
    end
    -- the lantern's warm light lying long on the water
    if lant > 0.01 then
      for d = 0, 8 do put(lant * (5 - d * 0.4), 101 + sin(T * 1.4 + d) * 1.2, PY - 6 + d * 1.2, 4, 1) end
    end
    -- the spring welling up: bubbles in the pool and a trickle over the rocks
    if nat > 0.02 then
      for k = 0, 19 do
        local ph = (T * (0.8 + 0.3 * (k % 3)) + k * 0.37) % 1
        local x = PX - 34 + k * 3.5 + sin(T + k) * 1.5
        local y = PY + 6 - ph * 9 - (k % 3) * 2
        put(nat * 13 * sin(math.pi * ph), x, y, 2, 1)
        if k % 2 == 0 then K.ring(x, y + 1, 1 + ph * 3, 0.3, nat * 5 * (1 - ph) * ease(ph / 0.15), 8) end
      end
      for q = 0, 5 do
        local ph = (T * 1.4 + q / 6) % 1
        put(nat * (4 + 2 * sin(T * 3 + q)) * sin(math.pi * ph), 20 + ph * 6 + sin(q), PY - 4 + ph * 7, 2, 1)
      end
    end
    -- the rocks round the pool, their snow caps
    K.blit(rocks, 1 + 0.4 * bloom)
    K.blit(caps, 1 + 0.35 * bloom + 0.3 * breath)
    K.twinkle(SNOWGLINT, hi, 13)
    K.glitter(sample, 34)
    -- a gust (swell) blows snow off the rocks and clears the steam
    if sw > 0.03 then
      for k = 1, 14 do
        local r = ROCK[1 + k % #ROCK]
        local ph = (T * 0.9 + k * 0.13) % 1
        local x = r[1] + ph * 26 + K.hash(k, 1419) * 4
        local y = r[2] - r[4] + r[4] * 0.4 - 2 - ph * 6 + sin(T * 3 + k) * 1.5
        put(sw * 6 * sin(math.pi * ph), x, y, 1, 1)
      end
    end
    -- the notes: drops from the branch at their pitch, rings on the pool
    for i = #marks, 1, -1 do
      local mk = marks[i]
      local age = T - mk.t0
      local cf, done = K.cap_fade(mk)
      if age > 4.5 or done then table.remove(marks, i)
      else
        local e = ease(age / 0.15) * (1 - ease((age - 2.5) / 2)) * cf
        local x, y = mk.x, mk.y
        local by = branch_y(x) + 1
        local fall = mk.slot == 4 and 1.4 or 0.6
        if mk.slot == 1 then
          drop(mk, age, e, by, fall, 0, 1)
        elseif mk.slot == 2 then
          drop(mk, age, e, by, fall, 0, 1, -5); drop(mk, age, e, by, fall, 0.45, 1, 5)
        elseif mk.slot == 3 then
          drop(mk, age, e, by, fall, 0, 2)
          -- (and a column of spray thrown up where it lands)
          local ca2 = age - fall
          if ca2 > 0 and ca2 < 0.8 then put(8 * e * (1 - ca2 / 0.8), x, y - 7 * sin(math.pi * ca2 / 0.8), 2, 3) end
          local ca = age - fall
          if ca > 0 and ca < 0.5 then
            for q = -2, 2 do
              local u = ca / 0.5
              put(7 * e * (1 - u), x + q * 2 * (0.5 + u * 1.5), y - 1 - 4 * sin(math.pi * u) * (1 - abs(q) * 0.25), 1, 1)
            end
          end
        else
          drop(mk, age, e, by, fall, 0, 1)
          -- (the slow drip swells on the twig before it lets go)
          if age < fall * 0.5 then put(6 * e, x, by, 1, 1 + age * 3) end
        end
      end
    end
    -- the branch reaching over the pool, swaying with out_lo, snow along it
    local sway = sin(T * 0.5) * (0.3 + 1.6 * lo) + K.heave(100) * 0.3
    -- (the snow gone from the twig comes back as the happening eases out)
    local slide = (inc and inc.name == "snowslide") and ease(clamp((inc.age - 3) / 0.6, 0, 1)) * inc.e or 0
    for k, b in ipairs(BR) do
      local u = (128 - b[1]) / 104
      local y = b[2] + sway * u * u
      put(2.4 + 0.6 * bloom + K.bj(k) * 0.4, b[1], y, 3, 1)
      if k % 2 == 0 and not (slide > 0 and b[1] < 70 and b[1] > 46) then
        put(4 + bloom, b[1], y - 1, 3, 1)
      elseif k % 2 == 0 then
        put((4 + bloom) * (1 - slide), b[1], y - 1, 3, 1)
      end
      -- (a few twigs leaving it on a slant)
      if k % 9 == 4 then put(2.2, b[1] - 1, y - 1, 1, 1); put(2, b[1] - 2, y - 2, 1, 1); put(1.8, b[1] - 3, y - 3, 1, 1) end
    end
    -- the steam: wisps rising off the water and curling, as high and as
    -- many as out_mid lets them; a gust clears it and it gathers again
    -- (four soft columns: puffs welling up off the water, each widening
    -- and fading as it rises and curling more the higher it goes, over a
    -- faint haze lying on the pool)
    local clear = 1 - 0.85 * sw
    local tall = 18 + 16 * mid
    local hz = (0.35 + 0.35 * mid + 0.2 * bloom) * clear
    for y = PY - PRY - 3, PY - PRY + 3 do
      local l, r = pool(math.max(y, PY - PRY + 1))
      if l then K.dither_row(hz * (1 - math.abs(y - (PY - PRY)) / 5), y, nil, floor(l + 4), floor(r - 4)) end
    end
    for c = 1, 4 do
      local cx = PX - 27 + (c - 1) * 18 + 4 * sin(T * 0.07 + c)
      for j = 0, 6 do
        local u = (steam_t * (0.8 + 0.1 * c) + j / 7 + c * 0.17) % 1
        local r = 1.5 + 4 * u
        local x = cx + sin(u * 3 + T * 0.45 + c * 1.7) * (0.5 + 7 * u * u) * (0.6 + 0.8 * mid) + sw * 16 * u
        local y = PY - 3 - u * tall
        local l = (2.2 + 1.2 * mid + 0.6 * bloom) * (1 - u) ^ 0.9 * ease(u / 0.12) * clear
        if l > 0.15 then
          K.dot(l * 1.35, x, y - 0.5)
          K.dash(l, x - r, y + 0.5, floor(2 * r))
          K.dash(l * 0.6, x - r * 0.6, y + 1.5, floor(1.2 * r))
        end
      end
    end
    -- the moment: a gentle snowfall, melting on the water
    local ma = K.moment_age
    if ma < 16 then
      local e = ease(ma / 2.5) * (1 - ease((ma - 11) / 5))
      for k, f in ipairs(FLAKE) do
        local ph = (ma * 0.09 * f[3] + f[2]) % 1
        local x = (f[1] + sin(ma * 0.7 + k) * 4) % 128
        local y = ph * 60
        put(e * (6 + 4 * f[3]) * sin(math.pi * ph) ^ 0.5, x, y, 1 + (k % 3 == 0 and 1 or 0), 1)
      end
    end
    -- incidents
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "snowslide" then
        -- a clump of snow slides off the branch and falls in a soft puff
        -- (the clump on the twig and the falling snow crossfade; its
        -- ring eases up where it lands)
        local a = clamp((inc.age - 3) / 2.5, 0, 1)
        local go = ease(a / 0.15)
        if go < 1 then put(e * 6 * (1 - go), 50, branch_y(50) - 2, 22, 1) end
        if a > 0 then
          for q = 0, 6 do
            local x = 52 + q * 3 + a * 6
            local y = branch_y(x) + a * a * 28 + (q % 3)
            put(e * 7 * (1 - a * 0.6) * go, x, y, 2, 2)
          end
          if a > 0.6 then
            local p = (a - 0.6) / 0.4
            K.ring(62, PY - 3, 2 + p * 10, 0.3, e * 5 * (1 - p) * ease(p / 0.2), 18)
          end
        end
      elseif inc.name == "bird" then
        -- a small bird flies in, lands on a rock, and looks about
        local r = ROCK[1 + floor(inc.s * 5) % 5 + 9]
        local rx, ry = r[1], r[2] - r[4] + r[4] * 0.4 - 3
        -- (flying and perched crossfade over its last half second in)
        local land = clamp(inc.age / 3, 0, 1)
        local x, y = rx + (1 - ease(land)) * 50, ry - (1 - ease(land)) * 20
        local sit = ease((inc.age - 2.6) / 0.6)
        if sit < 1 then K.bird(x, y, 8 * e * (1 - sit), sin(K.NOW * 12), 1) end
        if sit > 0 then
          local look = ease((sin(inc.age * 0.9) - 0.2) / 0.3)
          local pe = e * sit
          put(8 * pe, x - 2, y - 2, 4, 3); put(8 * pe * (1 - look), x + 1, y - 4, 2, 2); put(8 * pe * look, x + 2, y - 4, 2, 2)
          put(6 * pe, x - 4, y - 1, 2, 1); put(5 * pe, x - 1, y + 1, 1, 1)
        end
      else
        -- a stone lantern by the pool, its light coming up warm
        local x, y = 101, PY - 13
        put(4 * e, x - 1, y + 2, 4, 6); put(4.5 * e, x - 3, y, 8, 2); put(4 * e, x - 1, y - 2, 4, 2)
        put(5 * e, x - 4, y + 8, 10, 1)
        put(lant * 9, x, y + 3, 2, 2)
        put(lant * 3, x - 2, y + 2, 6, 4)
      end
    end
  end

  M.init()
  return M
end
