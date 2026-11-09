-- koi: a garden pond seen from above, stones round its rim, its gravel bed
-- faint under the water and a maple branch reaching over one corner. each
-- motif is a fish swimming a slow loop at its own cycle length (one loop
-- every four cycles), its body bending as it swims and a wake fading behind
-- it (longer and brighter with out_mid); a quiet motif's fish sinks deeper
-- and dims. a note makes its fish flick its tail and leaves a ring on the
-- water at the note's pitch, across the pond, level with the fish; each
-- fish rings the water its own way. the chord floats as lily pads, one per
-- tone, bigger for lower notes, drifting toward their tone's place across
-- the pond when the chord moves. out_lo rocks the pads and rolls broad slow
-- light across the water; out_hi glints on the pad rims; the water sounds
-- are a little stream running in at the corner. the bar breathes on the
-- surface; a swell raises the water over the rim stones; a passing moment
-- lets blossom fall on the pond. now and then a frog hops off a pad, a
-- maple leaf drifts across, or a dragonfly darts over the water
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, cos, floor = math.sin, math.cos, math.floor

  M.incidents = {{"frog", 12}, {"leaf", 20}, {"dragonfly", 12}}

  local RING_MAX = 8
  local stone_body, stone_edge
  local GLINTS = K.scatter(72, 4, 7, 124, 57, 63)
  local rings, flick, pads, stones, petals
  local onf = {0, 0, 0, 0}                -- each motif sounding, eased

  function M.init()
    rings, flick, petals = {}, {0, 0, 0, 0}, {}
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
      local w = 4 + floor(5 * K.hash(k, 53))
      stones[#stones + 1] = {x = x, w = w, top = true, h = 2 + floor(2 * K.hash(k, 54)), lv = 1.5 + K.hash(k, 55)}
      x = x + w + 1
    end
    x = -3
    while x < 130 do
      k = k + 1
      local w = 4 + floor(6 * K.hash(k, 53))
      stones[#stones + 1] = {x = x, w = w, top = false, h = 2 + floor(3 * K.hash(k, 54)), lv = 1.5 + K.hash(k, 55)}
      x = x + w + 1
    end
    -- the stones never move: baked, their bodies and their lit inner edges
    stone_body = K.bake(function(rec)
      for _, st in ipairs(stones) do
        local y0 = st.top and 0 or 64 - st.h
        for r = 0, st.h - 1 do
          local inset = (st.top and r == st.h - 1 or (not st.top and r == 0))
          if not inset then rec(st.lv, st.x, y0 + r, st.w, 1) end
        end
      end
    end)
    stone_edge = K.bake(function(rec)
      for _, st in ipairs(stones) do
        rec(st.lv + 0.8, st.x + 1, st.top and st.h - 1 or 64 - st.h, st.w - 2, 1)
      end
    end)
  end

  function M.clear() rings, petals = {}, {}; flick = {0, 0, 0, 0}; onf = {0, 0, 0, 0} end

  -- the gravel bed, baked once: a sparse dim stipple, a sunken stone
  local bed = K.bake(function(rec)
    for y = 8, 56, 3 do
      for x = (y * 7) % 5, 127, 5 do
        local h = K.hash(x * 64 + y, 56)
        if h < 0.11 then rec(1, x + floor(h * 18), y + (h < 0.1 and 1 or 0), 1 + (h < 0.05 and 1 or 0), 1) end
      end
    end
    for dy = -2, 2 do rec(1, 96 - (3 - math.abs(dy)) * 2, 44 + dy, (3 - math.abs(dy)) * 4 + 2, 1) end
  end)
  -- the maple branch over the top-right corner: leaves in clusters
  local BRANCH = {}
  for k = 1, 9 do
    BRANCH[k] = {x = 104 + k * 2.6 + 3 * K.hash(k, 57), y = 2 + k * 1.1 + 4 * K.hash(k, 58), ph = K.hash(k, 59) * 6}
  end

  -- fish i's loop: a slow figure of its own, theta 0..2pi
  local function path(i, th)
    local a = th + i * 1.3
    return 64 + (40 - i * 3) * sin(a), 31 + (13 + i * 1.5) * sin(2 * a + i * 0.7) * (i % 2 == 0 and 1 or -1)
  end

  local fish_xy = {}

  function M.note(slot, midi)
    flick[slot] = 1
    local p = fish_xy[slot]
    -- the ring lands at the note's pitch, level with its fish
    -- (when the pond holds as many rings as it can, the oldest fades quickly)
    K.cap_add(rings, {x = K.px(midi), y = p and p[2] or (14 + slot * 8), t0 = K.T, kind = slot}, RING_MAX)
  end

  local function sample(u, v) return 4 + u * 120, 7 + v * 50 end

  -- a lily pad from above: a disc with a thin slit running from its middle
  -- out to the rim (on a slant, its own way round: a leaf, not a mouth),
  -- a lit rim
  local function pad(x, y, r, l, rim, dir)
    if r < 1 then return end
    local rows = floor(r * 0.8)
    for dy = -rows, rows do
      local hw = math.sqrt(math.max(0, r * r - (dy / 0.8) ^ 2))
      local ll = math.abs(dy) == rows and l + rim or l
      local a, b = x - hw, x + hw + 1
      if dy <= 0 and dy > -rows then
        -- (the slit crosses this row one pixel wide)
        local sx = floor(x - dir * dy * 1.3 + (dir > 0 and 0.5 or -0.5))
        if sx > a and sx < b - 1 then
          put(ll, a, y + dy, sx - a, 1)
          put(ll, sx + 1, y + dy, b - sx - 1, 1)
        else
          put(ll, a, y + dy, b - a, 1)
        end
      else
        put(ll, a, y + dy, b - a, 1)
      end
    end
  end

  function M.draw(S)
    local T, DTS = K.T, K.DTS
    local hi, mid, nat, lo = A[K.HI], A[K.MID], A[K.NAT], A[K.LO]
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    K.blit(bed, 1 + 0.4 * bloom)
    -- (a raised pond covers the stones' inner edges)
    K.blit(stone_body, 1 + 0.3 * bloom + 0.5 * breath)
    K.blit(stone_edge, (1 + 0.3 * bloom + 0.7 * breath) * (1 - 0.4 * clamp((sw - 0.3) / 0.7, 0, 1)))
    -- the water: sky light moving faintly on it, breathing on the bar; out_lo
    -- rolls broad slow bands of light across
    K.surface(0, 6, 128, 58, 1 + breath * 2.6 + 0.3 * bloom + nat * 1.2, 14, 6, 3, nat * 0.5)
    K.twinkle(GLINTS, hi, 10.5)
    if lo > 0.05 then
      for b = 0, 1 do
        local bx = (T * 6 + b * 64 + K.drift_x * 0.3) % 170 - 20
        -- (each row's stroke its own length and place: a soft band of
        -- light, not a ruled stack)
        for y = 8, 56, 4 do
          local h = K.hash(y + b * 64, 64)
          local x = bx + sin(y * 0.15 + T * 0.3) * 6 + (h - 0.5) * 6
          put(lo * 2.2 * (0.8 + 0.4 * h), x, y + (b + y // 4) % 2, 9 + 9 * K.hash(y + b * 64, 65), 1)
        end
      end
    end
    -- a swell raises the water: the rim is lapped
    if sw > 0.05 then
      for x = (K.drift_x * 0.5) % 9 - 9, 127, 9 do
        put(sw * 2.5, x, 5 + sin(x * 0.3 + T) * 0.8, 5, 1); put(sw * 2.5, x + 3, 58 + sin(x * 0.3 - T) * 0.8, 5, 1)
      end
    end
    -- the stream running in at the bottom-left corner: as much as the
    -- water sounds bring
    if nat > 0.03 then
      for k = 0, 6 do
        local u = ((T * 0.6 + k / 7) % 1)
        local x, y = 2 + u * 34, 57 - u * 12
        put(nat * (5 - u * 3), x + sin(T * 3 + k) * 1.5, y, 3, 1)
        put(nat * (3 - u * 2), x + 2 + sin(T * 2.4 + k) * 1.5, y + 2, 2, 1)
      end
      for k = 0, 1 do
        local rr = (T * 4 + k * 5) % 10
        K.ring(22, 50, 3 + rr, 0.6, nat * 4 * (1 - rr / 10), 16)
      end
    end
    -- pads: one per chord tone, sized by its register, drifting toward the
    -- tone's place across the pond, carried by the current, rocking on out_lo
    for i, p in ipairs(pads) do
      local m, pr = K.chord_at(i)
      p.want = m and clamp(3 + (72 - m) * 0.12, 3, 6.5) * pr or 0
      p.r = K.follow(p.r, p.want, 1.5, K.DT)
      local u, v = K.flow(p.x, p.y)
      if m then p.x = K.follow(p.x, K.cx(m), 2.5, K.DT) end
      p.x = p.x + u * DTS * 0.3
      p.y = clamp(p.y + v * DTS * 0.3, 12, 50)
      local rock = lo * 1.5 * sin(T * 0.9 + p.ph)
      local qx, qy = p.x + rock, p.y + lo * sin(T * 0.7 + p.ph)
      pad(qx, qy, p.r, 2 + 0.8 * bloom + 1.2 * K.chord_glow, 1, i % 2 == 0 and 1 or -1)
      put(2 + 7 * hi * math.max(0, sin(T * 5 + i * 2)), qx - p.r * 0.7, qy - p.r * 0.6, 3, 1)   -- light on its rim
      local fl = ease((bloom - 0.3) / 0.25)                      -- a flower as the bloom opens
      if i == 1 and p.r > 3 and fl > 0.02 then put((4 + 3 * bloom) * fl, qx - 1, qy - 1, 2, 2) end
    end
    -- rings where the notes landed, each fish its own way
    for i = #rings, 1, -1 do
      local r = rings[i]
      local age = T - r.t0
      local cf, done = K.cap_fade(r)
      if age > 3.2 or done then table.remove(rings, i)
      else
        local rad = 1.5 + age * 5.5
        local lv = 8.5 * (1 - age / 3.2) * ease(age / 0.15) * (0.6 + 0.6 * A[K.AMP]) * cf
        local n = math.max(8, floor(rad * 1.8))
        K.ring(r.x, r.y, rad, 0.9, lv, n)
        if r.kind == 2 then K.ring(r.x, r.y, rad * 0.55, 0.9, lv * 0.8, math.max(6, n // 2)) end
        if r.kind == 3 and age < 1.6 then
          for k = 0, 2 do put(lv * 1.2, r.x - 2 + k * 2, r.y - age * 3 - k, 1, 1) end
        end
        if r.kind == 4 and age < 0.5 then put(lv * 1.5, r.x, r.y - 3 * sin(math.pi * age / 0.5), 1, 1) end
      end
    end
    -- the fish
    local step = tonumber(S.step) or 0
    local sub = K.substep(S)
    for i = 1, 4 do
      flick[i] = flick[i] * math.exp(-K.DT / 0.5)
      local m = K.motif(S, i)
      if m then
        -- (a fish rises and brightens as its motif comes in, and sinks
        -- as it goes, over a second)
        onf[i] = K.follow(onf[i], K.sounding(S, i) and 1 or 0, 0.7, K.DT)
        local on = onf[i]
        local th = ((step + sub) % (m.cycle * 4)) / (m.cycle * 4) * K.TAU
        local d = 0.034
        local lv = 2.5 + 4 * on + (3 + 0.5 * on) * K.slot_flash[i]
        local sw_ = (0.6 + 0.4 * on) * (0.5 + 1.5 * flick[i] + 0.6 * K.energy)
        local px_, py_ = path(i, th)
        fish_xy[i] = fish_xy[i] or {}
        fish_xy[i][1], fish_xy[i][2] = px_, py_
        -- the wake: two fading lines opening behind it, longer with out_mid
        -- (the wake lengthens smoothly: its far end fades with the mid)
        local wl = 22 + mid * 22
        for k = 13, wl + 3, 3 do
          local wx, wy = path(i, th - k * d)
          local sx, sy = path(i, th - k * d - 0.01)
          local nx, ny = wy - sy, sx - wx
          local nn = math.max(1e-6, math.sqrt(nx * nx + ny * ny))
          local l = ((0.9 + 0.9 * on) * (1 + 2.8 * mid) * math.max(0, 1 - (k - 13) / (wl - 10)) + hi * 1.5) * clamp((wl + 3 - k) / 3, 0, 1)
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
          local wig = sin(T * (4 + 6 * flick[i]) - k * 0.7) * sw_ * (k / 11) ^ 1.6 * 1.6
          bx, by = bx + nx * wig, by + ny * wig
          local spot = (((k + i) % 4 < 2) and 1.5 or 0) + hi * 2.5 * math.max(0, sin(T * 2.5 + k * 1.3 + i))
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
    -- the maple branch over the corner, close to you, swaying
    for _, b in ipairs(BRANCH) do
      local sway = sin(T * 0.6 + b.ph) * (0.6 + 1.2 * nat) + K.heave(b.x) * 0.3
      put(2.5 + bloom, b.x + sway, b.y, 3, 2)
      put(1.5 + bloom, b.x + sway - 1, b.y + 2, 2, 1)
    end
    -- the moment: blossom falls on the pond, drifting down and floating
    local ma = K.moment_age
    if ma < 14 then
      local e = ease(ma / 1.5) * (1 - ease((ma - 9) / 5))
      for k = 1, 20 do
        local t0 = K.hash(k, 60) * 4
        local age = ma - t0
        if age > 0 then
          local x0 = 20 + K.hash(k, 61) * 90
          local fall = math.min(1, age / 3)
          local x = x0 + sin(age * 2 + k) * 2 * (1 - fall) + math.max(0, age - 3) * (1 + K.cur_u * 0.3)
          local y = 6 + K.hash(k, 62) * 44
          local l = e * (fall < 1 and 6 - fall * 2 or 4)
          put(l, x, y - (1 - fall) * 6, 2, 2)
          if fall >= 1 and age < 5 then K.ring(x, y, 1.5 + (age - 3) * 3, 0.9, 3.5 * e, 10) end
        end
      end
    end
    -- incidents
    local inc = K.inc
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "frog" then
        -- a frog sits on a pad, then hops into the water
        local p = pads[1 + floor(inc.s * 4) % 4]
        local hop = clamp((inc.age - inc.dur * 0.55) / 0.8, 0, 1)
        local fx = p.x + hop * 12
        local fy = p.y - 1 - sin(math.pi * hop) * 5
        -- (it slips under as it lands: the frog fades over the end of the hop
        -- while the rings ease up)
        local fe = e * (1 - ease((hop - 0.6) / 0.4))
        if fe > 0.01 then
          -- it breathes, its throat pulsing
          local thr = 0.5 + 0.5 * sin(K.T * 3)
          put(8 * fe, fx - 3, fy - 2, 7, 3); put(7 * fe, fx - 4, fy, 1, 2); put(7 * fe, fx + 4, fy, 1, 2)
          put(9 * fe, fx - 1, fy - 3, 1, 1); put(9 * fe, fx + 1, fy - 3, 1, 1)
          put((4.5 + thr * 2) * fe, fx - 1, fy + 1, 3, 1)
        end
        local age = inc.age - inc.dur * 0.55 - 0.6
        if age > 0 then
          local re = e * ease(age / 0.4) * math.max(0, 1 - age / 3.5)
          K.ring(p.x + 12, p.y - 1, 1.5 + age * 6, 0.9, 7 * re, 20)
          K.ring(p.x + 12, p.y - 1, 1 + age * 3.5, 0.9, 5 * re, 12)
        end
      elseif inc.name == "leaf" then
        -- a maple leaf drifts across on the current, turning
        local x = -8 + u * 144
        local y = 24 + sin(u * 3 + inc.s * 6) * 12
        local a = u * 4
        put(5 * e, x - 1, y - 1, 3, 3)
        for k = 0, 4 do
          local aa = a + k * K.TAU / 5
          put(7.5 * e, x + cos(aa) * 3, y + sin(aa) * 3, 2, 2)
        end
        put(9 * e, x, y, 1, 1)
        put(2 * e, x - 2, y + 5, 6, 1)                      -- its shadow
      else
        -- a dragonfly darts across in hops and hovers over a pad
        local hops = floor(inc.age / 2)
        local f = ease(clamp((inc.age % 2) / 0.4, 0, 1))
        local x = 10 + inc.s * 20 + (hops + f) * 14
        local y = 16 + sin(hops * 2.1 + inc.s2 * 6) * 10
        put(9 * e, x - 4, y, 9, 1)
        local wing = sin(K.NOW * 30) > 0 and 1 or 0
        put(6.5 * e, x - 3, y - 1 - wing, 3, 1); put(6.5 * e, x + 1, y - 1 - wing, 3, 1)
        put(6.5 * e, x - 3, y + 1 + wing, 3, 1); put(6.5 * e, x + 1, y + 1 + wing, 3, 1)
        put(2.5 * e, x - 3, y + 6, 7, 1)                    -- its shadow on the water
      end
    end
    K.glitter(sample, 12)
  end

  M.init()
  return M
end
