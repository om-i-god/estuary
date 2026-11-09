-- brook: a stream running over stones, seen slightly from above, between a
-- far bank of grass at the top and a near bank close by at the bottom. the
-- bed lies still under the water, its pebbles wavering as the surface
-- moves; over it the streamlines run downstream (to the right), faster in
-- mid-stream than at the banks, bending round the stones, and they run
-- faster as the sound grows and with the current. the chord is the stones
-- themselves: four stones across by pitch, bigger for lower tones, each
-- with a pillow of water in front and a wake behind; when the chord moves
-- they shift slowly to their new places and the water finds its way round
-- them again. a note at its pitch: a small standing wave (the first
-- motif), a pebble glinting on the bed (the second), a boil welling up and
-- carried off (the third), a string of bubbles (the fourth). out_lo heaves
-- the surface and sways the near grass, out_mid lengthens and brightens
-- the wakes, out_hi glints on the water and the wet stones, and the water
-- sounds are white water: flecks of foam running off the stones and down
-- the stream. the bloom is daylight on the bed; the bar breathes in it; a
-- swell brings the water up the banks and over the stones. a passing
-- moment brings a shoal of minnows up the stream. now and then a dipper
-- bobs on the bank, a leaf boat rides the current, or a trout rises
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, floor, abs, exp = math.sin, math.floor, math.abs, math.exp

  M.incidents = {{"dipper", 18}, {"leaf", 20}, {"trout", 13}}

  local MARK_MAX = 8
  local marks
  local fp = 0                            -- how far the stream has run (px)
  local kick = {0, 0, 0, 0}               -- a note near a stone sets it glinting (eased up)
  local kick_to = {0, 0, 0, 0}            -- ...toward this, which a note sets and which decays
  local ST = {}                           -- the stones this frame (below)

  -- the banks: the far bank's lower edge, the near bank's upper edge
  local far_e = K.profile(function(x)
    return 9 + 1.8 * sin(x * 0.07 + 1) + 1.4 * K.hash(x // 6, 201) + 1.2 * math.max(0, sin(x * 0.19 - 2))
  end)
  local near_e = K.profile(function(x)
    return 55 + 1.8 * sin(x * 0.05 + 2) + 1.3 * K.hash(x // 5, 202) - 1.5 * math.max(0, sin(x * 0.13 + 0.5)) ^ 2
  end)
  -- the banks' grass, baked once: brushed strokes, thicker away from the
  -- water, and a broken lit line along the water's edge
  local banks = K.bake(function(rec)
    local k = 0
    local function strokes(y, x0, x1, dens, salt)
      local x = x0
      while x < x1 do
        k = k + 1
        local h = K.hash(k, salt)
        local len = 1 + floor(4 * K.hash(k, salt + 1))
        local d = dens(x)
        if h < d then rec(h < d * 0.2 and 2 or 1, x, y, math.min(len, x1 - x), 1) end
        x = x + len + 1 + floor(3 * K.hash(k, salt + 2))
      end
    end
    for y = 0, 13 do
      strokes(y, 0, 128, function(x)
        local e = K.at(far_e, x)
        if y >= e - 1 then return 0 end
        return 0.5 - 0.3 * (y / e) + 0.15 * sin(x * 0.09 + y * 0.4)
      end, 203)
    end
    for y = 51, 63 do
      strokes(y, 0, 128, function(x)
        local n = K.at(near_e, x)
        if y <= n + 1 then return 0 end
        return 0.2 + 0.3 * ((y - n) / 9) + 0.12 * sin(x * 0.07 - y * 0.5)
      end, 233)
    end
    for c = 0, 63 do
      local x = c * 2
      if K.hash(c, 230) < 0.75 then rec(1.6 + 0.8 * K.hash(c, 231), x, floor(far_e[c] + 0.5) - 1, 2, 1) end
      if K.hash(c, 232) < 0.8 then rec(1.6 + 0.8 * K.hash(c, 233), x, floor(near_e[c] + 0.5), 2, 1) end
    end
  end)
  -- tufts hanging over the far bank's edge
  local tufts = K.bake(function(rec)
    for k = 1, 22 do
      local x = floor(k * 5.8 + 4 * K.hash(k, 205))
      local e = K.at(far_e, x)
      rec(1.6, x, e, 1, 1 + floor(2 * K.hash(k, 206)))
    end
  end)
  -- the bed: pebbles lying still under the water
  local bed = K.bake(function(rec)
    for k = 1, 24 do
      local x, y = 2 + 124 * K.hash(k, 207), 15 + 36 * K.hash(k, 208)
      local w = 2 + floor(3 * K.hash(k, 209))
      rec(1, x, y, w, 1)
      if w > 2 then rec(1, x + 1, y + 1, w - 2 > 0 and w - 1 or 1, 1) end
    end
    for k = 1, 20 do rec(1, 2 + 124 * K.hash(k, 210), 14 + 38 * K.hash(k, 211), 1, 1) end
  end)
  -- near grass along the bottom, close to you: {x, height, phase}
  local GRASS = {}
  for k = 1, 10 do
    local left = k <= 5
    local x = left and (2 + (k - 1) * 4 + 3 * K.hash(k, 212)) or (104 + (k - 6) * 5 + 3 * K.hash(k, 212))
    GRASS[k] = {x, 6 + 8 * K.hash(k, 213), K.hash(k, 214) * 6, left and 1 or -1}
  end
  -- foam flecks running down the stream: {x0, y, kind}
  local FLECK = {}
  for k = 1, 40 do FLECK[k] = {140 * K.hash(k, 215), 15 + 36 * K.hash(k, 216), K.hash(k, 217)} end
  local WGLINT = K.scatter(30, 4, 16, 124, 50, 218)
  -- the minnows a moment brings: {dx, dy, phase}
  local SHOAL = {}
  for k = 1, 16 do SHOAL[k] = {(K.hash(k, 219) - 0.5) * 34, (K.hash(k, 220) - 0.5) * 16, K.hash(k, 221) * 6} end

  function M.init() marks, fp = {}, 0; for i = 1, 4 do kick[i], kick_to[i] = 0, 0 end end
  function M.clear() marks = {}; for i = 1, 4 do kick[i], kick_to[i] = 0, 0 end end

  local function y_of(midi) return 48 - K.pu(midi) * 30 end

  function M.note(slot, midi)
    local x = K.px(midi)
    -- every note sets the stone nearest its pitch glinting
    local best, bd
    for i = 1, 4 do
      local s = ST[i]
      if s[5] > 0.1 and (not bd or math.abs(s[1] - x) < bd) then best, bd = i, math.abs(s[1] - x) end
    end
    if best then kick_to[best] = 1 end
    K.cap_add(marks, {slot = slot, x = x, y = y_of(midi), t0 = K.T, fp0 = fp}, MARK_MAX)
  end

  -- the stones this frame: x, y, half width, half height, presence
  for i = 1, 4 do ST[i] = {0, 0, 0, 0, 0} end
  local STONE_Y = {25, 39, 31, 45}
  local function stones()
    for i = 1, 4 do
      local m, p = K.chord_at(i)
      local s = ST[i]
      if m and p > 0.02 then
        local rx = clamp(3.5 + (62 - m) * 0.14, 3, 7.5)
        s[1], s[2], s[3], s[4], s[5] = K.cx(m), STONE_Y[i] + (60 - m) * 0.08, rx, rx * 0.72, p
      else
        s[5] = 0
      end
    end
  end

  -- how far the water at (x, y) is pushed aside by the stones, and whether
  -- (x, y) is under one; and how deep in a stone's wake it is
  local function push(x, y)
    local d, wake = 0, 0
    for i = 1, 4 do
      local s = ST[i]
      local p = s[5]
      if p > 0.05 then
        local dx, dy = x - s[1], y - s[2]
        local rx, ry = s[3] * p, s[4] * p
        if dx > -rx * 3 and dx < rx * 3 and dy > -ry * 3.5 and dy < ry * 3.5 then
          local q = dx / (rx * 1.3)
          local f = 1 / (1 + q * q)
          local a = ry * 3 - abs(dy)
          if a > 0 then d = d + (dy >= 0 and 1 or -1) * a * 0.65 * f end
        end
        -- (the wake fades in behind the stone and out at its sides: no edge
        -- for a gliding stone to drag across the dashes)
        if dx > rx * 0.2 and dy > -ry * 1.6 and dy < ry * 1.6 then
          local w = (1 - (dx - rx * 0.5) / (rx * 4 + 14)) * math.min(1, (dx - rx * 0.2) / (rx * 0.8))
            * (1 - abs(dy) / (ry * 1.6)) * p
          if w > wake then wake = w end
        end
      end
    end
    return d, wake
  end
  -- how much of a dash shows at (x, y): none under a stone, fading in
  -- round its rim (never a switch, so a gliding stone never blinks them)
  local function clear_of(x, y)
    local c = 1
    for i = 1, 4 do
      local s = ST[i]
      local p = s[5]
      if p > 0.05 then
        local qx, qy = (x - s[1]) / (s[3] * p + 0.5), (y - s[2]) / (s[4] * p + 0.5)
        local q = qx * qx + qy * qy
        if q < 2.2 then
          local f = (q - 1) / 1.2
          if f < c then c = f end
        end
      end
    end
    return c > 0 and c or 0
  end

  -- sunlight through the leaves, lying in patches on the bed: {x, y, half width, phase}
  local DAPPLE = {}
  for k = 1, 8 do DAPPLE[k] = {8 + (k - 1) * 15 + 6 * K.hash(k, 224), 18 + 30 * K.hash(k, 225), 4 + 5 * K.hash(k, 226), K.hash(k, 227) * 6} end
  local function sample(u, v) return u * 127, 15 + v * 36 end

  local function stone(s, i, bloom, hi, sw)
    local x, y, rx, ry, p = s[1], s[2], s[3] * s[5], s[4] * s[5], s[5]
    if rx < 1.2 then return end
    local T = K.T
    local body = (2 + 0.9 * bloom) * (0.5 + 0.5 * p) * (1 - 0.35 * sw) + 1.6 * kick[i]
    local top = body + 1.6 + 2.2 * K.chord_glow + 1.2 * K.breath
    local rows = floor(ry + 0.5)
    for dy = -rows, rows do
      local hw = rx * math.sqrt(math.max(0, 1 - (dy / (ry + 0.5)) ^ 2)) * (0.85 + 0.25 * K.hash(i * 32 + dy, 228))
      if hw >= 0.5 then
        local l = (dy <= -rows + 1) and top or body
        -- (its edges share their light between columns, so a gliding
        -- stone slides smoothly instead of a column at a time)
        local lv = l + K.bj(i * 16 + dy) * 0.4
        local x0 = x - hw + (K.hash(i * 32 + dy, 229) - 0.5) * 1.2
        local x1 = x0 + 2 * hw + 1
        local a, b = math.ceil(x0), floor(x1)
        if b > a then put(lv, a, y + dy, b - a, 1) end
        put(lv * (a - x0), a - 1, y + dy, 1, 1)
        put(lv * (x1 - b), b, y + dy, 1, 1)
      end
    end
    -- its wet crown catching the light, glinting with out_hi, and with a
    -- note near it
    local kk = kick[i]
    put(math.min(12, top + 1 + hi * 5 * math.max(0, sin(T * 4.3 + i * 2)) + 4 * kk), x - rx * 0.4, y - rows, math.max(1, rx * 0.6), 1)
    if kk > 0.03 then
      put(6 * kk, x - rx * 0.4, y - rows + 1, math.max(1, rx * 1.2), 1)
      put(5 * kk, x - 1, y - rows - 3, 1, 2); put(5 * kk, x - 1, y - rows + 2, 1, 2)
      put(5 * kk, x - 4, y - rows, 2, 1); put(5 * kk, x + 2, y - rows, 2, 1)
    end
    -- the pillow of water piled in front of it
    local pl = 2.5 + 2 * K.energy + 3 * A[K.NAT] + 1.5 * sw
    for j = -2, 2 do
      local yy = y + j * ry * 0.55
      put(pl * (1 - abs(j) * 0.18) + K.bj(i * 8 + j), x - rx - 2 + abs(j) * rx * 0.25 + K.heave(x + j) * 0.3, yy, 2, 1)
    end
    -- the wake: two lines of riffles opening downstream, longer and
    -- brighter with out_mid
    local mid = A[K.MID]
    local n = 3 + floor(mid * 5 + 0.5)
    for k = 1, n do
      local f = sin(k * 1.7 - T * 5 + i)
      local l = (2.2 + 3.2 * mid) * (1 - k / (n + 1)) + (f > 0.4 and 1 or 0)
      local xx = x + rx + k * 3
      put(l, xx, y - ry - k * 0.8 + K.heave(xx) * 0.3, 2, 1)
      put(l, xx, y + ry + k * 0.8 + K.heave(xx) * 0.3, 2, 1)
    end
  end

  function M.draw()
    local T = K.T
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local hi, mid, nat, lo = A[K.HI], A[K.MID], A[K.NAT], A[K.LO]
    -- the stream runs downstream whatever the tide does: faster with the
    -- sound, the current and a swell
    local speed = 5 + 6 * A[K.AMP] + 0.5 * abs(K.cur_u) + 2.5 * sw
    fp = fp + speed * K.DTS
    stones()
    for i = 1, 4 do
      kick[i] = K.follow(kick[i], kick_to[i], 0.05, K.DT)
      kick_to[i] = kick_to[i] * math.exp(-K.DT / 1.3)
    end
    -- the bed, wavering under the moving surface, and the daylight on it
    local dl = 0.55 + 0.9 * bloom + 1.9 * breath + 1.6 * K.chord_glow
    for k, d in ipairs(DAPPLE) do
      local x = d[1] + sin(T * 0.13 + d[4]) * 4 + K.heave(d[1]) * 0.6
      local hw = d[3] * (0.8 + 0.2 * sin(T * 0.21 + d[4] * 2))
      for j = -2, 2 do
        local w = hw * (1 - abs(j) * 0.28)
        put(dl * (1 - abs(j) * 0.22) + K.bj(k * 8 + j), x - w + abs(j) * 0.7 * sin(d[4] + j), d[2] + j, 2 * w, 1)
      end
    end
    K.blit(bed, 1 + 0.5 * bloom, sin(T * 0.8) * (0.6 + 1.2 * lo))
    -- the banks, warming with the daylight
    K.blit(banks, 1 + 0.35 * bloom)
    K.blit(tufts, 1 + 0.4 * bloom + 0.6 * breath, sin(T * 0.6) * (0.5 + 1.5 * nat))
    -- a swell brings the water up: its edge laps over the banks
    if sw > 0.03 then
      for x = (fp * 0.3) % 7 - 7, 127, 7 do
        local fe = K.at(far_e, x + 2) - 1 - sw * 3 + sin(x * 0.3 + T) * 0.7
        local ne = K.at(near_e, x + 2) + sw * 3 + sin(x * 0.3 - T) * 0.7
        put(sw * 3.5 + K.bj(x), x, fe, 4, 1); put(sw * 3.5 + K.bj(x + 64), x + 3, ne, 4, 1)
      end
    end
    -- the streamlines: dashes riding downstream, faster mid-stream, bent
    -- round the stones and bright in their wakes
    local row = 0
    for y0 = 14, 52, 4 do
      row = row + 1
      local q = 1 - ((y0 - 33) / 21) ^ 2
      local gap = 12 + (row * 3) % 5 + floor((1 - q) * 9)
      local o = fp * (0.45 + 0.7 * q) + y0 * 7.3
      local k = -floor(o / gap) + row * 37
      if k ~= k or k > 1e9 or k < -1e9 then k = 0 end
      local base = 1.2 + 1.2 * q + 0.8 * K.energy + 0.5 * bloom + 1.7 * breath
      for x = o % gap - gap, 127, gap do
        local h = (((k * 2654435761) >> 7) & 0xffff) / 65536
        k = k + 1
        local len = 4 + floor(h * 7)
        local xc = x + len * 0.5
        local d, wake = push(xc, y0)
        -- (each dash rides the heave on its own phase, so a row never hops
        -- all at once)
        local hv = K.heave((k * 29) % 140) * 0.45
        local y = y0 + d + hv
        local w = sin(xc * 0.09 + y0 * 0.5 - T * 0.6) + 0.6 * sin(xc * 0.031 - y0 * 0.2 + T * 0.25)
        local cl = clear_of(xc, y)
        if w > -0.5 and cl > 0 and y > K.at(far_e, xc) + 1 and y < K.at(near_e, xc) - 1 then
          local l = base + h * 1.6 - 0.8 + (w > 0.9 and 0.8 or 0)
          -- (the light glancing off the moving water: out_hi)
          local gl = sin(xc * 0.23 + y0 * 1.3 - T * 1.1) * sin(xc * 0.071 - y0 * 0.4 + T * 0.4)
          if gl > 0.3 then l = l + hi * 5.5 * (gl - 0.3) * 1.6 end
          l = math.min(12, l * cl)
          if wake > 0 then l = l + wake * (1.5 + 3 * mid) end
          -- (round a stone the dash is pushed aside smoothly: its light is
          -- shared between the two rows it lies across, so it never hops)
          if d ~= 0 then
            local y0f = floor(y)
            local fy = y - y0f
            put(l * (1 - fy), x, y0f, len, 1)
            put(l * fy, x, y0f + 1, len, 1)
          else
            put(l, x, y, len, 1)
          end
        end
      end
    end
    -- the stones (the chord), their pillows and wakes
    for i = 1, 4 do stone(ST[i], i, bloom, hi, sw) end
    -- white water: flecks of foam running off the stones and down the
    -- stream, as many as the water sounds bring
    if nat > 0.02 then
      local nf = floor(#FLECK * clamp(nat * 0.8, 0, 0.75) + 0.5)
      for j = 1, nf do
        local f = FLECK[j]
        local x = (f[1] + fp * (1.1 + 0.4 * f[3])) % 140 - 6
        local y = f[2] + sin(T * 1.3 + j) * 0.8
        local cl = clear_of(x, y)
        if cl > 0 then put(cl * (2.2 + 3 * nat * f[3] + 1.2 * nat), x, y, 1 + floor(f[3] * 2.5), 1) end
      end
      for i = 1, 4 do
        local s = ST[i]
        if s[5] > 0.3 then
          for j = 1, 5 do
            local u = ((fp * 0.09 + j * 0.2 + i * 0.13) % 1)
            local x = s[1] + s[3] + 1 + u * 16
            local y = s[2] + (K.hash(j, 222 + i) - 0.5) * s[4] * 2.4
            put((3 + 5 * nat) * (1 - u), x, y, 2, 1)
          end
        end
      end
    end
    K.twinkle(WGLINT, hi, 8)
    -- the notes' marks
    for i = #marks, 1, -1 do
      local mk = marks[i]
      local age = T - mk.t0
      local cf, done = K.cap_fade(mk)
      if age > 4 or done then table.remove(marks, i)
      else
        local e = ease(age / 0.2) * (1 - ease((age - 1.6) / 2.4)) * cf
        local x, y = mk.x, mk.y
        if mk.slot == 1 then
          -- a small standing wave: crests stacked into the flow, shimmering,
          -- the water riffling on behind it
          for j = 0, 3 do
            local l = (9 - j * 1.6) * e * (0.85 + 0.15 * sin(T * 9 + j))
            put(l, x - j * 2, y - 2 - j, 3, 1); put(l, x - j * 2, y + 2 + j, 3, 1)
          end
          put(9 * e, x + 1, y - 1, 2, 3)
          for j = 1, 4 do
            local f = sin(j * 1.9 - T * 7)
            put(e * (5.5 - j * 0.9 + (f > 0 and 1.5 or 0)), x + 2 + j * 3, y - 1 + (j % 2) * 2, 2, 1)
          end
        elseif mk.slot == 2 then
          -- a pebble on the bed catches the light: a glint that pulses twice
          local g = e * (0.6 + 0.4 * sin(age * 7))
          put(10 * g, x, y, 2, 2)
          put(6 * g, x - 3, y, 2, 2); put(6 * g, x + 3, y, 2, 2)
          put(6 * g, x, y - 3, 2, 2); put(6 * g, x, y + 3, 2, 2)
          put(3.5 * g, x - 5, y + 1, 1, 1); put(3.5 * g, x + 6, y, 1, 1)
          put(3 * g, x - 3, y + 6, 8, 1)
        elseif mk.slot == 3 then
          -- a boil welling up, carried off downstream
          local cx = x + (fp - mk.fp0) * 0.5
          K.ring(cx, y, 1.5 + age * 2.8, 0.6, 8 * e, 16)
          K.ring(cx, y, 1 + age * 1.5, 0.6, 5.5 * e, 10)
          put(7 * e * (1 - age / 4), cx - 1, y, 3, 1)
        else
          -- a string of bubbles rising and drifting off
          local dx = (fp - mk.fp0) * 0.6
          for j = 0, 4 do
            local bx = x + dx - j * 4 + sin(age * 3 + j) * 1.2
            local by = y + (j % 2) * 2 - 1
            put(8 * e * (1 - j * 0.12), bx, by, 2, 1); put(5 * e, bx, by - 1, 1, 1); put(4 * e, bx + 1, by + 1, 1, 1)
          end
        end
      end
    end
    -- the near grass, close to you, arching over the water and swaying
    -- with the heave and the wind
    for _, g in ipairs(GRASS) do
      local lean = sin(T * 0.7 + g[3]) * (0.4 + 1.6 * nat) + K.heave(g[1]) * (0.6 + 0.8 * lo)
      local base = K.at(near_e, g[1]) + 5
      local lv = 2.6 + 0.9 * bloom + K.bj(g[1])
      local h, dir = g[2], g[4]
      -- (a blade in five pieces, arching out over the water)
      for j = 0, 4 do
        local u = j / 5
        put(lv * (1 - u * 0.3), g[1] + (dir * 7 + lean) * u * u, base - h * u - 3, 1 + (j >= 3 and 1 or 0), floor(h / 5) + 1)
      end
    end
    -- the moment: a shoal of minnows comes up the stream, holds against the
    -- current a while, flickering, and slips away
    local ma = K.moment_age
    if ma < 16 then
      local e = ease(ma / 2.5) * (1 - ease((ma - 11) / 5))
      local cx = 140 - 75 * ease(ma / 8) - math.max(0, ma - 11) * 8
      local cy = 33 + 4 * sin(ma * 0.4)
      for k, f in ipairs(SHOAL) do
        local x = cx + f[1] + sin(ma * 0.8 + f[3]) * 2
        local y = cy + f[2] + sin(ma * 0.8 + f[3] * 1.3) * 1.5
        local fl = math.max(0, sin(ma * 2.2 + f[3] * 2))
        put((7 + 3 * fl) * e, x, y, 4, 1); put(5 * e, x + 4, y - 1, 1, 3)
        put(3 * e, x + 1, y + 3, 4, 1)                    -- its shadow on the bed
      end
    end
    -- incidents
    local inc = K.inc
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "dipper" then
        -- a dipper on the bank's edge, bobbing, then off low up the stream
        local bx = 22 + inc.s * 70
        local by = K.at(near_e, bx) - 1
        local lift = clamp((inc.age - 0.72 * inc.dur) / 0.45, 0, 1)
        local pe, fe = e * (1 - lift), e * lift
        if pe > 0.01 then
          local bob = 1.2 * math.max(0, sin(inc.age * 4.5)) ^ 3
          put(6 * pe, bx - 2, by - 4 + bob, 6, 3); put(6 * pe, bx - 3, by - 6 + bob, 3, 2)
          put(9 * pe, bx - 3, by - 4 + bob, 2, 2)           -- the white bib
          put(5 * pe, bx + 3, by - 5 + bob, 2, 1)           -- the cocked tail
          put(5 * pe, bx - 1, by - 1, 1, 2); put(5 * pe, bx + 1, by - 1, 1, 2)
          put(2.5 * pe, bx - 3, by + 2, 8, 1)
        end
        if fe > 0.01 then
          local f = clamp((inc.age - 0.72 * inc.dur) / (0.28 * inc.dur), 0, 1)
          K.bird(bx - f * 90, by - 6 - sin(f * 3) * 4, 7 * fe, sin(K.NOW * 14), 2)
        end
      elseif inc.name == "leaf" then
        -- a leaf boat riding the current, turning round the stones
        local x = -6 + u * 140
        local y0 = 22 + inc.s * 18
        local d = push(x, y0)
        local y = y0 + d + K.heave(x) * 0.5
        local a = u * 7 + inc.s2 * 6
        local ca, sa = math.cos(a), sin(a)
        -- a leaf: points along its turning axis, broad in the middle, its
        -- stalk trailing; a small wake and its shadow on the bed
        for j = -4, 4 do
          local w = 1.6 * (1 - (j / 5) ^ 2)
          local px, py = x + ca * j, y + sa * j * 0.6
          put((8 - abs(j) * 0.4) * e, px - w * abs(sa) - 0.5, py - w * abs(ca) * 0.6, 1 + floor(w * abs(sa) * 2), 1 + floor(w * abs(ca) * 1.2))
        end
        put(6 * e, x - ca * 6, y - sa * 3.6, 1, 1)
        put(3 * e, x - 7, y - 3, 3, 1); put(3 * e, x - 7, y + 3, 3, 1)
        put(2.5 * e, x - 2, y + 5, 6, 1)
      else
        -- a trout holds under the surface facing upstream, then rises
        local tx, ty = 34 + inc.s * 50, 24 + inc.s2 * 16
        local rise = clamp((inc.age - 0.55 * inc.dur) / 0.6, 0, 1)
        local be = e * (1 - ease(rise))
        if be > 0.01 then
          local wag = sin(inc.age * 3) * 1.2
          put(5 * be, tx - 6, ty, 12, 2); put(5.5 * be, tx - 4, ty - 1, 7, 1); put(4.5 * be, tx - 4, ty + 2, 7, 1)
          put(3.5 * be, tx + 6, ty + wag * 0.5, 3, 2); put(3 * be, tx + 9, ty - 1 + wag, 2, 4)
          put(5.5 * be, tx - 6, ty, 2, 1)
        end
        local age = inc.age - 0.55 * inc.dur - 0.3
        if age > 0 then
          local re = e * ease(age / 0.4) * math.max(0, 1 - age / 4.5)
          local rx = tx - 6 + age * 5
          K.ring(rx, ty, 1.5 + age * 4, 0.6, 7.5 * re, 20)
          K.ring(rx, ty, 1 + age * 2.4, 0.6, 5 * re, 12)
        end
      end
    end
    K.glitter(sample, 14)
  end

  M.init()
  return M
end
