-- postcards: four small windows onto the same estuary from four spots along
-- it: a sandy shore, open water, a reed bank and the rocks at the mouth.
-- each holds a far line of hills, a sky with a cloud drifting slowly
-- across, the water and something close by. the chord sets the hills: each
-- window's far line stands at the height of one chord tone and glides when
-- the chord moves. the light in each window is its motif's recent notes:
-- the last note hangs in that window's sky at its pitch, its path on the
-- water below, and the window answers in its own way (a wash runs up the
-- sand, a sail catches the light, a reed head glows, spray leaps off the
-- rocks). water level and chop come from the shared current and the sound;
-- out_mid raises whitecaps in every window, out_hi sparkles, the water
-- sounds push the wash, the reeds and the spray. the frames breathe on the
-- bar. a moment sends one bird through all four windows in turn; now and
-- then a cloud passes over them all, a boat crosses the open water, or a
-- heron stands in the reeds. a caption under each window shows where its
-- motif is in its cycle
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, floor = math.sin, math.floor

  M.incidents = {{"cloud", 20}, {"boat", 18}, {"heron", 16}}

  local CARD_W, CARD_H, CARD_Y = 26, 34, 8
  local SPOT = {0, 37, 74, 111}           -- where along the water each window looks
  local card_wl = {0, 0, 0, 0}
  local cf, cu = {0, 0, 0, 0}, {}
  local ans = {-99, -99, -99, -99}        -- when each window last answered a note

  function M.clear() cf, cu, ans = {0, 0, 0, 0}, {}, {-99, -99, -99, -99} end

  -- the rocks in the fourth window stand still while the water moves round
  -- them: {centre x, half width, height above the resting water}
  local R0 = 6 + 3 * 31
  local ROCKS = {{R0 + 8, 6, 7}, {R0 + 19, 4, 4}}
  local ROCKP = K.profile(function(x)
    for _, r in ipairs(ROCKS) do
      local d = (x + 1 - r[1]) / r[2]
      if d > -1 and d < 1 then return CARD_Y + 20 - r[3] * math.sqrt(1 - d * d) ^ 0.7 end
    end
    return 99
  end)
  local function in_rock(x, y) return y >= K.at(ROCKP, x) and y < CARD_Y + 22 end

  -- each window's hills: a fixed ragged line, raised and lowered whole
  local HILL = {}
  for i = 1, 4 do
    local h = {}
    for c = 0, 12 do h[c] = 1.6 * sin(c * 0.9 + i * 2) + 1.2 * K.hash(c + i * 13, 31) end
    HILL[i] = h
  end
  local hill_y = {0, 0, 0, 0}

  local function sample(u, v)
    local i = floor(u * 4) + 1
    return 6 + (i - 1) * 31 + 2 + v * (CARD_W - 5), card_wl[i]
  end

  local ans_u = {0.5, 0.5, 0.5, 0.5}
  function M.note(slot, midi)
    ans[slot] = K.T
    ans_u[slot] = K.pu(midi)
  end

  -- what stands in each window, drawn over its water. x0, y0: the window;
  -- wl: its water line; lit: its light; a: how freshly it answered a note
  local DECOR = {
    -- a sandy shore sloping up from the left, the wash running up it
    function(x0, y0, wl, lit, T, a, ax)
      local reach = 2 + 2 * sin(T * 0.8) + 3 * A[K.AMP] + 4 * A[K.NAT]
      for r = 0, 6 do
        local y = floor(wl) + 1 + r
        local w = floor(14 - r * 2 + (r == 0 and reach or 0))
        if y < y0 + CARD_H - 1 and w > 0 then
          put(r == 0 and 3 + lit * 2 or 1 + (r % 2), x0 + 1, y, math.min(w + r * 3, CARD_W - 2), 1)
        end
      end
      local fx = x0 + 1 + math.min(CARD_W - 4, 11 + reach)
      put(4 + lit * 2, fx, floor(wl) + 1, 2, 1)   -- foam
      if a > 0.05 then
        -- a wave breaks at the note's place: a white crest and its spray
        put(6 * a, ax - 3, floor(wl) - 1, 7, 1); put(4 * a, ax - 2, floor(wl) - 2, 2, 1); put(4 * a, ax + 2, floor(wl) - 3, 1, 1)
        put(3 * a, ax - 4, floor(wl) + 2, 9, 1)
      end
    end,
    -- open water: nothing between you and the line but a far sail
    function(x0, y0, wl, lit, T, a, ax)
      local sx = x0 + 4 + (CARD_W - 9) * (0.5 + 0.5 * sin(T * 0.05 + 1))
      local l = 2 + lit
      put(l, sx, wl - 4, 1, 4); put(l * 0.8, sx + 1, wl - 3, 1, 3); put(l * 0.6, sx + 2, wl - 1, 1, 1)
      if a > 0.05 then
        -- a gull dips to the water at the note's place
        K.bird(ax, wl - 3 - 4 * (1 - a), 6 * a, sin(K.NOW * 6), 1)
        put(3 * a, ax - 3, wl + 1, 7, 1); put(2 * a, ax - 2, wl + 3, 5, 1)
      end
    end,
    -- a reed bank: stems in front of the water, leaning with the current
    -- and the wind
    function(x0, y0, wl, lit, T, a, ax)
      local kn = clamp(floor((ax - x0 - 3) / 5 + 0.5), 0, 4)
      for k = 0, 4 do
        local bx = x0 + 3 + k * 5 + (k % 2)
        local h = 13 + (k * 7) % 6
        local lean = (K.cur_u * 0.25 + sin(T * 0.9 + k * 1.7) * (0.8 + 1.2 * A[K.NAT]) + K.heave(bx) * 0.2)
        local yb = y0 + CARD_H - 2
        for s = 0, h - 1, 2 do
          local u = s / h
          put(2 + lit, bx + lean * u * u * 3, yb - s - 1, 1, 2)
        end
        put(4 + lit * 2 + (k == kn and 7 * a or 0), bx + lean * 3, yb - h - 2, 1, 3)
        if k == kn and a > 0.05 then
          -- the head glows and sheds a few seeds
          put(4 * a, bx + lean * 3 - 1, yb - h - 1, 3, 1)
          for j = 1, 3 do put(3 * a, bx + lean * 3 + j * 2 * (1 - a) * 3, yb - h - 3 - j - (1 - a) * 4, 1, 1) end
        end
      end
    end,
    -- rocks at the mouth, dark against the water, the swell breaking
    -- white round them, spray with the water sounds and a note
    function(x0, y0, wl, lit, T, a, ax)
      for _, r in ipairs(ROCKS) do
        local cx, hw = r[1], r[2]
        for c = (cx - hw) // 2, (cx + hw - 1) // 2 do
          local t = ROCKP[c]
          if t < 99 then put(2 + lit * 2, c * 2, t, 2, 1) end
        end
        local b = 0.5 + 0.5 * sin(T * 1.6 + cx)
        put(2 + b * (2 + 3 * A[K.HI]), math.max(x0 + 1, cx - hw - 2), floor(wl) + 1, 2, 1)
        put(2 + (1 - b) * (2 + 3 * A[K.HI]), math.min(x0 + CARD_W - 3, cx + hw), floor(wl) + 1, 2, 1)
      end
      local sp = A[K.NAT] * (0.5 + 0.5 * sin(T * 1.6 + 2))
      for j = 0, 1 do
        local s = j == 0 and sp or a
        if s > 0.05 then
          local cx = j == 0 and ROCKS[1][1] or ax
          for k = -2, 2 do
            put(5.5 * s, cx + k * 2.5, floor(wl) - 2 - (2 - math.abs(k)) * 2.5 * s, 1, 1)
          end
          put(3.5 * s, cx - 4, floor(wl) + 1, 9, 1)
        end
      end
    end,
  }

  function M.draw(S)
    local T = K.T
    local sub = K.substep(S)
    local step = tonumber(S.step) or 0
    local mid, hi = A[K.MID], A[K.HI]
    local chop = 0.7 + 0.8 * K.energy + 0.5 * A[K.NAT]
    local breath = K.breath
    local inc = K.inc
    -- the moment's bird and the incident cloud move along the whole estuary:
    -- x along the four windows' strip
    local bird_x = K.moment_age < 12 and (-4 + K.moment_age / 12 * 136) or nil
    local bird_e = bird_x and ease(K.moment_age / 1) * ease((12 - K.moment_age) / 1.5) or 0
    local cloud_x = inc and inc.name == "cloud" and (-20 + inc.u * 168) or nil
    for i = 1, 4 do
      local x0, y0 = 6 + (i - 1) * 31, CARD_Y
      local m = K.motif(S, i)
      local on = K.sounding(S, i)
      -- each window's light eases up and down, and glides to a new pitch
      cf[i] = K.follow(cf[i], K.slot_flash[i], 0.25, K.DT)
      local f, glow = cf[i], K.slot_glow[i]
      local a = 0
      local age = T - ans[i]
      if age < 3 then a = ease(age / 0.2) * (1 - ease((age - 0.4) / 2.6)) end
      -- the frame
      local edge = (on and 3 or 2) + f * 5 + breath * 1.5
      put(edge, x0, y0, CARD_W, 1)
      put(edge, x0, y0 + CARD_H - 1, CARD_W, 1)
      put(edge, x0, y0, 1, CARD_H)
      put(edge, x0 + CARD_W - 1, y0, 1, CARD_H)
      -- the water in this window: the shared heave at this spot, raised by a
      -- swell, with chop from the sound and the water level
      local sp = SPOT[i]
      local wl = y0 + 19 - K.sw_disp * 5 + K.heave(sp + 13) * 0.7
      card_wl[i] = wl
      local lm = K.slot_last[i]
      local u = lm and clamp((lm - 55) / 36, 0, 1)
      if u then cu[i] = cu[i] and K.follow(cu[i], u, 0.3, K.DT) or u end
      u = cu[i]
      local sx = u and (x0 + 4 + u * 17)
      local lit = glow * 0.8 + f
      -- the sky: a glow over the line, warmer with the bloom and the light
      local pass = bird_x and bird_e * clamp(1 - math.abs(bird_x - (x0 + 13)) / 30, 0, 1) or 0
      local sky = 1.2 + 1.3 * K.bloom + lit + breath * 0.8 + pass * 2
      local rocky = i == 4
      K.gradient(y0 + 2, floor(wl) - 1, function(y)
        local d = (wl - y) / 12
        return d < 1 and sky * (1 - d) ^ 1.5 or 0
      end, rocky and ROCKP or nil, x0 + 1, x0 + CARD_W - 1)
      -- the chord's hills: this window's far line at its tone's height
      local cm, cp = K.chord_at(i)
      if cm then
        hill_y[i] = clamp(wl - 2 - (cm - 36) / 40 * 9, y0 + 4, wl - 1)
        local hl = (1.6 + 0.8 * K.bloom + 2 * K.chord_glow) * cp
        local h = HILL[i]
        for c = 0, 11 do
          local top = floor(hill_y[i] - h[c] + 0.5)
          local xx = x0 + 1 + c * 2
          if top < wl - 1 and not (rocky and in_rock(xx, top)) then
            put(hl, xx, top, 2, 1)
            if wl - 1 - top > 1 then put(hl * 0.4, xx + (c % 2), top + 1, 1, floor(wl) - top - 1) end
          end
        end
      end
      -- a cloud drifting slowly across this window's sky
      local cx = x0 + 1 + ((T * 0.6 + K.drift_x * 0.1 + i * 9) % (CARD_W + 10)) - 8
      local cy = y0 + 4 + (i % 2) * 2
      local cl = 1.2 + 1.2 * K.bloom
      for r = 0, 1 do
        local a0, a1 = math.max(x0 + 1, cx + r * 2), math.min(x0 + CARD_W - 1, cx + 9 - r * 3)
        if a1 > a0 then put(cl + (r == 0 and 0.8 or 0), a0, cy + r, a1 - a0, 1) end
      end
      for c = 0, 11 do
        local xx = x0 + 1 + c * 2
        local vx = sp + c * 2
        local y = wl + chop * sin(vx * 0.33 - T * 1.5 + K.drift_x * 0.15) + 0.4 * sin(vx * 0.12 + T * 0.6)
        y = clamp(y, y0 + 3, y0 + CARD_H - 3)
        local near = sx and math.max(0, 1 - math.abs(xx - sx) / 6) or 0
        local sparkle = hi * 6 * math.max(0, sin(vx * 1.3 + T * 8))
        if not (rocky and in_rock(xx, y)) then put((on and 3 or 2) + near * lit * 5 + sparkle, xx, y, 2, 1) end
      end
      for r = 1, 5 do
        local yy = floor(wl + 1 + r * 2.5)
        if yy < y0 + CARD_H - 1 then
          local off = (K.drift_x * (0.8 + 0.4 * r) + sp) % 7
          for xx = x0 + 1 + off, x0 + CARD_W - 4, 7 do
            if not (rocky and (in_rock(xx, yy) or in_rock(xx + 2, yy))) then
              -- whitecaps with out_mid: some dashes lift and brighten
              local cap = mid * math.max(0, sin(xx * 0.9 + r * 2.1 + T * 1.7))
              local gl = hi * 4.5 * math.max(0, sin(xx * 1.7 + r * 3.3 + T * 9))
              put((on and 1.5 or 1) + cap * 3.5 + gl, xx, yy - (cap > 0.5 and 1 or 0), 3 + floor(A[K.NAT] * 2.5), 1)
            end
          end
        end
      end
      -- the light: the slot's last note hangs in this window's sky at its
      -- pitch, its path on the water below
      if sx and lit > 0.04 then
        local sy = y0 + 3 + (1 - u) * math.max(1, wl - y0 - 7)
        local ll = math.min(1, lit * 4) * 2 + lit * 6
        put(ll, sx, sy, 2, 2)
        put(ll * 0.4, sx - 1, sy, 4, 2); put(ll * 0.4, sx, sy - 1, 2, 4)
        for yy = floor(wl) + 2, y0 + CARD_H - 3, 2 do
          local fl = 0.5 + 0.5 * sin(T * 4 + yy * 1.7 + i)
          local w = 1 + floor(fl * 2.5 + hi * 2)
          put(lit * 4 * fl, sx + 1 - w / 2, yy, w, 1)
        end
      end
      DECOR[i](x0, y0, wl, math.min(1, lit), T, a, x0 + 3 + ans_u[i] * (CARD_W - 8))
      -- the moment's bird, seen through each window as it passes
      if bird_x and bird_x >= x0 + 2 and bird_x < x0 + CARD_W - 2 then
        local by = y0 + 8 + sin(bird_x * 0.1) * 2
        K.bird(bird_x, by, 7 * bird_e, sin(K.NOW * 4), 2)
        put(4 * bird_e, x0 + 1, by + 6, CARD_W - 2, 1)          -- its window brightens as it passes
        K.bird(bird_x, wl + (wl - by) * 0.5 + 2, 2.5 * bird_e, -sin(K.NOW * 4), 1)
      end
      if cloud_x then
        -- the passing cloud: a soft grey bank, its shade on the water
        local a0, a1 = math.max(x0 + 1, cloud_x - 12), math.min(x0 + CARD_W - 1, cloud_x + 12)
        if a1 > a0 then
          for r = 0, 2 do put((r == 0 and 3.2 or 2.2) * inc.e, a0, y0 + 3 + r, a1 - a0, 1) end
          put(1.5 * inc.e, a0, floor(wl) + 3, a1 - a0, 1)
        end
      end
      -- caption: where the motif is in its cycle
      local capy = y0 + CARD_H + 3
      put(on and 2 or 1, x0 + 1, capy, CARD_W - 2, 1)
      if on and m then
        local ph = ((step + sub) % m.cycle) / m.cycle
        put(6, x0 + 1 + ph * (CARD_W - 3), capy - 1, 1, 3)
      end
    end
    -- incidents in one window
    if inc and inc.name == "boat" then
      local x0, wl = 6 + 31, card_wl[2]
      local bx = x0 + 3 + inc.u * (CARD_W - 11)
      local e = inc.e
      put(4.5 * e, bx, wl - 1, 7, 1); put(3.5 * e, bx + 1, wl, 5, 1)
      for k = 0, 3 do put((5 - k * 0.6) * e, bx + 3 + k, wl - 9 + k * 2, 1, 8 - k * 2) end
      put(3.5 * e, bx + 2, wl - 6, 1, 5)
      put(2.5 * e, bx - 3, wl + 1, 4, 1)
      for d = 2, 6, 2 do put(2 * e, bx + 1, wl + d, 4, 1) end
    elseif inc and inc.name == "heron" then
      local x0, y0 = 6 + 2 * 31, CARD_Y
      local e = inc.e
      local hx = x0 + 15
      local wl = card_wl[3]
      if inc.u < 0.75 then
        -- standing in the shallows: legs, body, the long neck, stabbing now
        -- and then
        local stab = (inc.age % 4 > 3.4) and 2 or 0
        put(4 * e, hx, wl - 1, 1, 3); put(4 * e, hx + 2, wl - 1, 1, 3)
        put(5 * e, hx - 1, wl - 4, 5, 2)
        put(5 * e, hx + 3, wl - 7 + stab, 1, 3)
        put(5.5 * e, hx + 4, wl - 7 + stab, 2, 1)
      else
        local f = (inc.u - 0.75) / 0.25
        K.bird(hx + f * 14, wl - 5 - f * 14, 5 * e, sin(K.NOW * 3), 2)
      end
    end
    K.glitter(sample)
  end

  return M
end
