-- koi: a garden pond seen from above, stones round its rim. each motif is a
-- fish swimming a slow loop at its own cycle length (one loop every four
-- cycles), its body bending as it swims and a wake fading behind it; a
-- quiet motif's fish sinks deeper and dims. a note makes its fish flick its
-- tail and leaves a ring where it touched the surface. the chord floats as
-- lily pads drifting on the current, bigger for lower notes
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease

  local RING_MAX = 10
  local rings, flick, pads, stones

  function M.init()
    rings, flick = {}, {0, 0, 0, 0}
    pads = {}
    for i = 1, 4 do
      pads[i] = {x = 16 + (i - 1) * 31 + 6 * K.hash(i, 51), y = 14 + 36 * K.hash(i, 52), r = 0, want = 0, ph = i * 1.7}
    end
    -- stones along the top and bottom rims
    stones = {}
    local x = -2
    local k = 0
    while x < 130 do
      k = k + 1
      local w = 4 + math.floor(5 * K.hash(k, 53))
      stones[#stones + 1] = {x = x, w = w, top = true, h = 2 + math.floor(2 * K.hash(k, 54)), lv = 1.5 + K.hash(k, 55)}
      x = x + w + 1
    end
    x = -3
    while x < 130 do
      k = k + 1
      local w = 4 + math.floor(6 * K.hash(k, 53))
      stones[#stones + 1] = {x = x, w = w, top = false, h = 2 + math.floor(3 * K.hash(k, 54)), lv = 1.5 + K.hash(k, 55)}
      x = x + w + 1
    end
  end

  function M.clear() rings = {}; flick = {0, 0, 0, 0} end

  -- fish i's loop: a slow figure of its own, theta 0..2pi
  local function path(i, th)
    local a = th + i * 1.3
    return 64 + (40 - i * 3) * math.sin(a), 31 + (13 + i * 1.5) * math.sin(2 * a + i * 0.7) * (i % 2 == 0 and 1 or -1)
  end

  local fish_xy = {}

  function M.note(slot)
    local was = flick[slot]
    flick[slot] = 1
    local p = fish_xy[slot]
    if p and was < 0.35 then
      rings[#rings + 1] = {x = p[1], y = p[2], t0 = K.T}
      if #rings > RING_MAX then table.remove(rings, 1) end
    end
  end

  local function sample(u, v) return 4 + u * 120, 7 + v * 50 end

  local function stone(s)
    local y0 = s.top and 0 or 64 - s.h
    for r = 0, s.h - 1 do
      local inset = (s.top and r == s.h - 1 or (not s.top and r == 0)) and 1 or 0
      put(s.lv + (inset == 1 and 0.8 or 0), s.x + inset, y0 + r, s.w - 2 * inset, 1)
    end
  end

  -- a lily pad from above: a disc with a notch toward its stem, a lit rim
  local function pad(p, l)
    local r = p.r
    if r < 1 then return end
    local x, y = p.x, p.y
    local rows = math.floor(r * 0.8)
    for dy = -rows, rows do
      local hw = math.sqrt(math.max(0, r * r - (dy / 0.8) ^ 2))
      if dy == 0 then
        put(l, x - hw, y, hw * 1.25, 1)            -- the notch: a slit to the rim
      elseif math.abs(dy) == rows then
        put(l + 1, x - hw, y + dy, 2 * hw + 1, 1)
      else
        put(l, x - hw, y + dy, 2 * hw + 1, 1)
      end
    end
  end

  function M.draw(S)
    local T, DTS = K.T, K.DTS
    local hi = A[K.HI]
    for _, s in ipairs(stones) do stone(s) end
    -- the water: sky light moving faintly on it
    K.surface(0, 6, 128, 58, 1, 11, 5, 3)
    -- pads: grow toward the chord's size, drift on the current, turn back
    -- before the rim
    local c = K.chord(S)
    for i, p in ipairs(pads) do
      p.want = c[i] and clamp(3 + (72 - c[i]) * 0.12, 3, 6.5) or 0
      p.r = K.follow(p.r, p.want, 1.5, K.DT)
      local u, v = K.flow(p.x, p.y)
      p.x = p.x + u * DTS * 0.3
      p.y = clamp(p.y + v * DTS * 0.3, 10, 52)
      if p.x > 136 then p.x = -8 elseif p.x < -8 then p.x = 136 end
      pad(p, 2 + 0.8 * K.bloom)
      put(2 + 4 * hi * math.max(0, math.sin(T * 5 + i * 2)), p.x - p.r * 0.7, p.y - p.r * 0.6, 2, 1)   -- light on its rim
      if i == 1 and p.r > 3 then put(4 + 3 * K.bloom, p.x - 1, p.y - 1, 2, 2) end   -- a flower
    end
    -- rings where a fish touched the surface
    for i = #rings, 1, -1 do
      local r = rings[i]
      local age = T - r.t0
      if age > 2.2 then table.remove(rings, i)
      else
        local rad = 1.5 + age * 5
        local lv = 3.5 * (1 - age / 2.2) * ease(age / 0.15) * (0.6 + 0.6 * A[K.AMP])
        local n = math.max(8, math.floor(rad * 2.2))
        for k = 0, n - 1 do
          local a = k / n * K.TAU
          put(lv, r.x + math.cos(a) * rad, r.y + math.sin(a) * rad * 0.9, 1, 1)
        end
      end
    end
    -- the fish
    local step = tonumber(S.step) or 0
    local sub = K.substep(S)
    for i = 1, 4 do
      flick[i] = flick[i] * math.exp(-K.DT / 0.5)
      local m = K.motif(S, i)
      if m then
        local on = K.sounding(S, i)
        local th = ((step + sub) % (m.cycle * 4)) / (m.cycle * 4) * K.TAU
        local d = 0.034
        local lv = on and (6.5 + 3 * K.slot_flash[i]) or 2.5
        local sw = (on and 1 or 0.6) * (0.5 + 1.5 * flick[i] + 0.4 * K.energy)
        local px_, py_ = path(i, th)
        fish_xy[i] = fish_xy[i] or {}
        fish_xy[i][1], fish_xy[i][2] = px_, py_
        -- the wake: two fading lines opening behind it
        for k = 13, 25, 3 do
          local wx, wy = path(i, th - k * d)
          local sx, sy = path(i, th - k * d - 0.01)
          local nx, ny = wy - sy, sx - wx
          local nn = math.max(1e-6, math.sqrt(nx * nx + ny * ny))
          local l = (on and 1.8 or 0.9) * (1 - (k - 13) / 15) + hi * 0.8
          local o = 1 + (k - 13) * 0.3
          put(l, wx + nx / nn * o, wy + ny / nn * o, 1, 1)
          put(l, wx - nx / nn * o, wy - ny / nn * o, 1, 1)
        end
        -- the body: points back along the path, swaying more toward the
        -- tail; broad at the shoulders, patched like a koi
        for k = 0, 11 do
          local bx, by = path(i, th - k * d)
          local ax, ay = path(i, th - k * d - 0.01)
          local nx, ny = by - ay, ax - bx
          local nn = math.max(1e-6, math.sqrt(nx * nx + ny * ny))
          nx, ny = nx / nn, ny / nn
          local wig = math.sin(T * (4 + 6 * flick[i]) - k * 0.7) * sw * (k / 11) ^ 1.6 * 1.6
          bx, by = bx + nx * wig, by + ny * wig
          local spot = ((k + i) % 4 < 2) and 1.5 or 0
          if k <= 1 then
            put(lv - 0.5, bx - 1, by - 1, 3, 3)
          elseif k <= 6 then
            put(lv - k * 0.25 + spot, bx - 0.5, by - 0.5, 2, 2)
          elseif k < 11 then
            put(lv * 0.6, bx, by, 1, 1)
          else
            put(lv * 0.5, bx + nx * 1.5, by + ny * 1.5, 1, 1)
            put(lv * 0.5, bx - nx * 1.5, by - ny * 1.5, 1, 1)
            put(lv * 0.4, bx + nx * 2.4, by + ny * 2.4, 1, 1)
            put(lv * 0.4, bx - nx * 2.4, by - ny * 2.4, 1, 1)
          end
          if k == 3 then
            -- pectoral fins
            put(lv * 0.45, bx + nx * 2.6, by + ny * 2.6, 1, 1)
            put(lv * 0.45, bx - nx * 2.6, by - ny * 2.6, 1, 1)
          end
        end
      else
        fish_xy[i] = nil
      end
    end
    K.glitter(sample, 30)
  end

  M.init()
  return M
end
