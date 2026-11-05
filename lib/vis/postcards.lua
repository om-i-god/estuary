-- postcards: four small windows onto the same estuary from four spots along
-- it: a sandy shore, open water, a reed bank and the rocks at the mouth.
-- water level and chop come from the shared current and the sound; the
-- light in each window is its motif's recent notes: the last note hangs in
-- that window's sky at its pitch, its path on the water below. a caption
-- under each window shows where its motif is in its cycle
return function(K)
  local M = {}
  local put, A, clamp = K.put, K.A, K.clamp

  local CARD_W, CARD_H, CARD_Y = 26, 34, 8
  local SPOT = {0, 37, 74, 111}           -- where along the water each window looks
  local card_wl = {0, 0, 0, 0}

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

  local function sample(u, v)
    local i = math.floor(u * 4) + 1
    return 6 + (i - 1) * 31 + 2 + v * (CARD_W - 5), card_wl[i]
  end

  -- what stands in each window, drawn over its water. x0, y0: the window;
  -- wl: its water line; lit: its light
  local DECOR = {
    -- a sandy shore sloping up from the left, the wash running up it
    function(x0, y0, wl, lit, T)
      local reach = 2 + 2 * math.sin(T * 0.8) + 3 * A[K.AMP]
      for r = 0, 6 do
        local y = math.floor(wl) + 1 + r
        local w = math.floor(14 - r * 2 + (r == 0 and reach or 0))
        if y < y0 + CARD_H - 1 and w > 0 then
          put(r == 0 and 3 + lit * 2 or 1 + (r % 2), x0 + 1, y, math.min(w + r * 3, CARD_W - 2), 1)
        end
      end
      put(4 + lit * 2, x0 + 1 + math.min(CARD_W - 3, 11 + reach), math.floor(wl) + 1, 2, 1)   -- foam
    end,
    -- open water: nothing between you and the line but a far sail
    function(x0, y0, wl, lit, T)
      local sx = x0 + 4 + ((T * 0.6 + 7) % (CARD_W - 8))
      put(2 + lit, sx, wl - 3, 1, 3); put(2 + lit, sx + 1, wl - 2, 1, 2)
    end,
    -- a reed bank: stems in front of the water, leaning with the current
    function(x0, y0, wl, lit, T)
      for k = 0, 4 do
        local bx = x0 + 3 + k * 5 + (k % 2)
        local h = 13 + (k * 7) % 6
        local lean = (K.cur_u * 0.25 + math.sin(T * 0.9 + k * 1.7) * 0.8 + K.heave(bx) * 0.2)
        local yb = y0 + CARD_H - 2
        for s = 0, h - 1, 2 do
          local u = s / h
          put(2 + lit, bx + lean * u * u * 3, yb - s - 1, 1, 2)
        end
        put(4 + lit * 2, bx + lean * 3, yb - h - 2, 1, 3)
      end
    end,
    -- rocks at the mouth, dark against the water, the swell breaking
    -- white round them
    function(x0, y0, wl, lit, T)
      for _, r in ipairs(ROCKS) do
        local cx, hw = r[1], r[2]
        for c = (cx - hw) // 2, (cx + hw - 1) // 2 do
          local t = ROCKP[c]
          if t < 99 then put(2 + lit * 2, c * 2, t, 2, 1) end
        end
        local b = 0.5 + 0.5 * math.sin(T * 1.6 + cx)
        put(2 + b * (2 + 3 * A[K.HI]), math.max(x0 + 1, cx - hw - 2), math.floor(wl) + 1, 2, 1)
        put(2 + (1 - b) * (2 + 3 * A[K.HI]), math.min(x0 + CARD_W - 3, cx + hw), math.floor(wl) + 1, 2, 1)
      end
    end,
  }

  function M.draw(S)
    local T = K.T
    local sub = K.substep(S)
    local step = tonumber(S.step) or 0
    local chop = 0.7 + 0.8 * K.energy + 0.5 * A[K.NAT]
    for i = 1, 4 do
      local x0, y0 = 6 + (i - 1) * 31, CARD_Y
      local m = K.motif(S, i)
      local on = K.sounding(S, i)
      local f, glow = K.slot_flash[i], K.slot_glow[i]
      -- the frame
      local edge = (on and 3 or 2) + f * 5
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
      local sx = u and (x0 + 4 + u * 17)
      local lit = glow * 0.8 + f
      -- the sky: a glow over the line, warmer with the bloom and the light
      local sky = 1.2 + 1.2 * K.bloom + lit
      local rocky = i == 4
      K.gradient(y0 + 2, math.floor(wl) - 1, function(y)
        local d = (wl - y) / 12
        return d < 1 and sky * (1 - d) ^ 1.5 or 0
      end, rocky and ROCKP or nil, x0 + 1, x0 + CARD_W - 1)
      for c = 0, 11 do
        local xx = x0 + 1 + c * 2
        local vx = sp + c * 2
        local y = wl + chop * math.sin(vx * 0.33 - T * 1.5 + K.drift_x * 0.15) + 0.4 * math.sin(vx * 0.12 + T * 0.6)
        y = clamp(y, y0 + 3, y0 + CARD_H - 3)
        local near = sx and math.max(0, 1 - math.abs(xx - sx) / 6) or 0
        local sparkle = A[K.HI] * 2.5 * math.max(0, math.sin(vx * 1.3 + T * 8))
        if not (rocky and in_rock(xx, y)) then put((on and 3 or 2) + near * lit * 5 + sparkle, xx, y, 2, 1) end
      end
      for r = 1, 5 do
        local yy = math.floor(wl + 1 + r * 2.5)
        if yy < y0 + CARD_H - 1 then
          local off = (K.drift_x * (0.8 + 0.4 * r) + sp) % 7
          for xx = x0 + 1 + off, x0 + CARD_W - 4, 7 do
            if not (rocky and (in_rock(xx, yy) or in_rock(xx + 2, yy))) then put(on and 1.5 or 1, xx, yy, 3, 1) end
          end
        end
      end
      -- the light: the slot's last note hangs in this window's sky at its
      -- pitch, its path on the water below
      if sx and lit > 0.04 then
        local sy = y0 + 3 + (1 - u) * math.max(1, wl - y0 - 7)
        put(2 + lit * 6, sx, sy, 2, 2)
        for yy = math.floor(wl) + 2, y0 + CARD_H - 3, 2 do
          local fl = 0.5 + 0.5 * math.sin(T * 4 + yy * 1.7 + i)
          local w = 1 + math.floor(fl * 2.5 + A[K.HI] * 2)
          put(lit * 4 * fl, sx + 1 - w / 2, yy, w, 1)
        end
      end
      DECOR[i](x0, y0, wl, math.min(1, lit), T)
      -- caption: where the motif is in its cycle
      local capy = y0 + CARD_H + 3
      put(on and 2 or 1, x0 + 1, capy, CARD_W - 2, 1)
      if on and m then
        local ph = ((step + sub) % m.cycle) / m.cycle
        put(6, x0 + 1 + ph * (CARD_W - 3), capy - 1, 1, 3)
      end
    end
    K.glitter(sample)
  end

  return M
end
