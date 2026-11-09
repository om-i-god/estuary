-- rockpool: a tide pool at low tide, seen from above. the sea runs along
-- the top beyond a rim of wet rock; inside, a sandy floor with pebbles,
-- weed trailing from the rim and anemones on the rocks. the chord is four
-- starfish on the floor, across by pitch, bigger for lower tones, each
-- turning slowly and creeping to its new place when the chord moves. the
-- anemones open as out_lo rises and close as it falls, and the weed sways
-- with the heave; out_mid sends cat's paws of ripples across the pool,
-- out_amp keeps its surface moving, out_hi glints on the wet rim, and the
-- water sounds are the sea breaking beyond it. a note at its pitch: a
-- shrimp flicks backwards (the first motif), a small crab scuttles
-- sideways (the second), a goby darts (the third), a few fry scatter (the
-- fourth). the bloom is the sky lying in the pool; the bar breathes in it;
-- a swell refills the pool from its rim, foam spilling in. a passing moment
-- sets a net of sunlight rippling over the floor. now and then a hermit
-- crab crosses, a wave slops in over the rim, or a gull's shadow passes
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, cos, floor, abs = math.sin, math.cos, math.floor, math.abs

  M.incidents = {{"hermit", 20}, {"slop", 10}, {"gull", 9}}

  local CX, CY, RX, RY = 64, 37, 57, 23
  local MARK_MAX = 5
  local marks
  local spin = {0, 0, 0, 0}               -- each starfish's slow turn
  local SF_Y = {46, 30, 52, 38}           -- the starfish's rows
  local SF = {}                           -- the starfish this frame
  for i = 1, 4 do SF[i] = {0, 0, 0, 0} end

  -- the pool's outline: inside(x, y), worked out once into row spans
  local function inside(x, y)
    local dx, dy = (x - CX) / RX, (y - CY) / RY
    local a = math.atan(dy, dx)
    local r = 1 + 0.07 * sin(3 * a + 1) + 0.05 * sin(7 * a + 2) + 0.03 * sin(13 * a)
    return dx * dx + dy * dy < r * r
  end
  local PL, PR = {}, {}                   -- row y -> pool span [PL, PR)
  for y = 0, 63 do
    local l, r
    for x = 0, 127 do
      if inside(x + 0.5, y + 0.5) then l = l or x; r = x + 1 end
    end
    PL[y], PR[y] = l, r
  end
  local PTOP, PBOT = 63, 0
  for y = 0, 63 do if PL[y] then PTOP = math.min(PTOP, y); PBOT = math.max(PBOT, y) end end

  -- the rock round the pool, baked once: brushed strokes, barnacles, and
  -- its wet edge lit where it meets the water
  local rock = K.bake(function(rec)
    -- (a run of row y from a to b, cut where it would cross the pool)
    local function run(l, y, a, b)
      if y < 4 or y > 63 then return end
      a, b = math.max(0, floor(a)), math.min(128, floor(b))
      local pl, pr = PL[y], PR[y]
      if pl then
        if a < pl then rec(l, a, y, math.min(b, pl - 1) - a, 1) end
        if b > pr + 1 then rec(l, math.max(a, pr + 1), y, b - math.max(a, pr + 1), 1) end
      elseif b > a then
        rec(l, a, y, b - a, 1)
      end
    end
    -- boulders round the pool: a lit crown, a few strokes on their flanks,
    -- dark cracks between
    local k = 0
    for b = 1, 38 do
      local a = b / 38 * K.TAU + 0.3 * K.hash(b, 301)
      local d = 1.12 + 0.5 * K.hash(b, 302)
      local bx, by = CX + cos(a) * RX * d, CY + sin(a) * RY * d * 1.05
      local rx, ry = 4 + 5 * K.hash(b, 303), 2.5 + 3 * K.hash(b, 304)
      if by > 3 and by < 68 then
        for dy = -floor(ry), floor(ry) do
          local hw = rx * math.sqrt(1 - (dy / (ry + 0.6)) ^ 2)
          if dy == -floor(ry) then
            run(2 + 0.6 * K.hash(b, 305), by + dy, bx - hw, bx + hw)
          elseif dy < 0 then
            -- (its shoulders, lit on the left)
            run(1.7, by + dy, bx - hw, bx - hw + 2)
            run(1.2, by + dy, bx + hw - 1, bx + hw)
          else
            k = k + 1
            if K.hash(k, 306) < 0.3 then
              local s0 = bx - hw + 2 * hw * K.hash(k, 307)
              run(1, by + dy, s0, s0 + 1 + 3 * K.hash(k, 308))
            end
          end
        end
      end
    end
    -- barnacles
    for b = 1, 40 do
      local x, y = floor(128 * K.hash(b, 309)), 5 + floor(58 * K.hash(b, 310))
      if not inside(x, y) and not inside(x, y + 3) and not inside(x, y - 3) then rec(1.6, x, y, 1, 1) end
    end
  end)
  local rim = K.bake(function(rec)
    for y = PTOP, PBOT do
      local l, r = PL[y], PR[y]
      local ul, ur = PL[y - 1], PR[y - 1]
      local dl, dr = PL[y + 1], PR[y + 1]
      rec(2.4, l - 1, y, 2, 1); rec(2, r - 1, y, 2, 1)
      -- the long edges at the top and bottom of the pool
      if not ul then rec(2.6, l, y - 1, r - l, 1)
      else
        if ul > l then rec(2.6, l, y - 1, ul - l, 1) end
        if ur < r then rec(2.6, ur, y - 1, r - ur, 1) end
      end
      if not dl then rec(2, l, y + 1, r - l, 1)
      else
        if dl > l then rec(2, l, y + 1, dl - l, 1) end
        if dr < r then rec(2, dr, y + 1, r - dr, 1) end
      end
    end
  end)
  -- the floor: sand and pebbles, faint under the water
  local sand = K.bake(function(rec)
    for k = 1, 34 do
      local y = PTOP + 2 + floor((PBOT - PTOP - 4) * K.hash(k, 305))
      local l, r = PL[y], PR[y]
      if l then
        local x = l + 2 + (r - l - 4) * K.hash(k, 306)
        local w = K.hash(k, 307) < 0.3 and 3 or 1
        rec(1, x, y, w, 1)
        if w == 3 then rec(1, x + 1, y + 1, 1, 1) end
      end
    end
  end)
  -- anemones on the rock at the pool's edge: {x, y, size, phase}
  local ANEM = {{14, 30, 4, 0.3}, {31, 52, 3, 1.9}, {99, 19, 3.5, 3.1}, {114, 42, 4, 4.4}, {72, 57, 3, 5.2}}
  -- weed trailing in from the rim: {x, y, dir x, dir y, length, phase}
  local WEED = {{22, 18, 0.8, 0.6, 16, 0.4}, {50, 15, 0.2, 1, 12, 2.2}, {86, 58, -0.3, -1, 14, 1.3},
    {118, 30, -1, 0.2, 13, 3.7}, {8, 44, 1, -0.2, 10, 5}}
  local RIMGLINT = {}
  for k = 1, 50 do
    local y = PTOP + floor((PBOT - PTOP) * K.hash(k, 308))
    if PL[y] then
      RIMGLINT[#RIMGLINT + 1] = K.hash(k, 309) < 0.5 and PL[y] - 2 or PR[y]
      RIMGLINT[#RIMGLINT + 1] = y
    end
  end

  function M.init() marks = {}; for i = 1, 4 do spin[i] = i * 1.3 end end
  function M.clear() marks = {} end

  -- a point inside the pool for a note: across by pitch, its height by pitch
  local function place(midi)
    local x = K.px(midi)
    local y = clamp(floor(52 - K.pu(midi) * 28), PTOP + 3, PBOT - 3)
    local l, r = PL[y], PR[y]
    if l then x = clamp(x, l + 4, r - 5) end
    return x, y
  end

  function M.note(slot, midi)
    local x, y = place(midi)
    K.cap_add(marks, {slot = slot, x = x, y = y, t0 = K.T, dir = (K.rnd() < 0.5) and -1 or 1}, MARK_MAX)
  end

  local function sample(u, v)
    local y = floor(PTOP + 2 + v * (PBOT - PTOP - 4))
    local l, r = PL[y], PR[y]
    if not l then return nil end
    return l + u * (r - l - 1), y
  end

  -- a starfish from above: five arms from a small centre
  local function star(x, y, r, a, l)
    -- a raised centre, five arms tapering to bright tips, a bead of light
    -- along each (its texture)
    put(l + 1, x - 1, y - 1, 3, 3)
    put(l + 2, x, y, 1, 1)
    for k = 0, 4 do
      local aa = a + k * K.TAU / 5
      local ca, sa = cos(aa), sin(aa)
      for j = 1, floor(r) do
        local w = j < r * 0.55 and 2 or 1
        put(l * (1 - j / (r + 3)), x + ca * (j + 1) - (w - 1) * 0.5, y + sa * (j + 1) * 0.85 - (w - 1) * 0.5, w, w)
      end
      put(l * 0.9 + 1, x + ca * (r + 1.5), y + sa * (r + 1.5) * 0.85, 1, 1)
    end
  end

  function M.draw()
    local T = K.T
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local hi, mid, nat, lo = A[K.HI], A[K.MID], A[K.NAT], A[K.LO]
    -- the sea beyond the rim: long swells sliding along, breaking white as
    -- the water sounds rise
    for y = 0, 3 do
      local gap = 15 + y * 3
      local off = K.drift_x * (0.8 + y * 0.2) + T * (2 + y) + y * 11
      for x = off % gap - gap, 127, gap do
        local w = sin(x * 0.07 + y - T * 0.9)
        put(1.4 + 0.5 * bloom + (w > 0.1 and nat * 7 * (w - 0.1) or 0) + K.bj(x + y * 40), x, y + (w > 0.6 and 1 or 0), 6 + floor(nat * 5), 1)
      end
    end
    K.blit(rock, 1 + 0.35 * bloom)
    -- spray thrown up over the top rim as the sea breaks
    if nat > 0.03 then
      for k = 1, 16 do
        local x = (k * 8 + 3 * K.hash(k, 311) + T * 3) % 128
        local u = (T * (0.5 + 0.3 * K.hash(k, 312)) + K.hash(k, 313)) % 1
        local y = 4 + u * 7
        if not PL[floor(y)] or x < PL[floor(y)] or x > PR[floor(y)] then
          put(nat * (6 - 4 * u) * (0.4 + 0.6 * K.hash(k, 314)), x, y, 2, 1)
        end
      end
    end
    K.blit(rim, 1 + 0.4 * bloom + 0.9 * breath - 0.3 * sw)
    K.twinkle(RIMGLINT, hi, 12)
    -- the sky lying in the pool: a soft sheen, brighter with the daylight
    -- and breathing on the bar
    local sheen = 0.1 + 0.25 * bloom + 0.55 * breath + 0.2 * sw
    for y = PTOP + 1, PBOT - 1, 1 do
      local u = (y - PTOP) / (PBOT - PTOP)
      local v = math.min(0.6, sheen * math.max(0, 1 - abs(u - 0.35) * 2.6))
      if v > 0.05 then
        local hw = 34 * (1 - abs(u - 0.35) * 1.6)
        local c = 58 + 10 * u
        K.dither_row(v, y, nil, math.max(PL[y] + 1, floor(c - hw)), math.min(PR[y] - 1, floor(c + hw)))
      end
    end
    K.blit(sand, 1 + 0.6 * bloom, sin(T * 0.6) * (0.5 + 1.2 * A[K.AMP]))
    -- the surface: faint ripples, and cat's paws of wind crossing it with
    -- out_mid
    local row = 0
    for y = PTOP + 2, PBOT - 2, 4 do
      row = row + 1
      local gap = 11 + row % 3 * 2
      local o = K.drift_x * 0.5 + T * (1 + 3 * A[K.AMP]) + row * 5
      local l0, r0 = PL[y] + 2, PR[y] - 3
      local k = -floor(o / gap) + row * 23
      if k ~= k or k > 1e9 or k < -1e9 then k = 0 end
      for x = l0 + o % gap, r0, gap do
        k = k + 1
        local paw = sin(x * 0.06 - T * 0.7 + row * 0.9) * sin(T * 0.23 + row)
        local w = sin(x * 0.17 + y * 0.5 - T * 0.8)
        local gl = sin(x * 0.31 - y * 0.7 + T * 1.7)
        local l = (w > 0.2 and 1.2 or 0) + (paw > 0.2 and mid * 4.5 * paw or 0) + 0.5 * K.energy + (gl > 0.4 and hi * 7 * (gl - 0.4) or 0)
        if l > 0.6 then put(l + K.bj(k), x, y + K.heave(x) * 0.3, 2 + floor(mid * 3 * math.max(0, paw)), 1) end
      end
    end
    -- the weed, swaying with the heave
    for i, w in ipairs(WEED) do
      local nx, ny = -w[4], w[3]
      for j = 1, w[5], 2 do
        local u = j / w[5]
        local sway = (K.heave(w[1] + j * 3) * 1.3 + sin(T * 0.8 + w[6] + j * 0.3) * (0.6 + 0.8 * A[K.AMP])) * u
        local x, y = w[1] + w[3] * j + nx * sway, w[2] + w[4] * j + ny * sway
        put((2.4 + 0.6 * bloom) * (1 - u * 0.35) + K.bj(i * 20 + j), x, y, 2, 2)
      end
    end
    -- anemones: tentacles opening with out_lo
    for i, a in ipairs(ANEM) do
      local open = clamp(0.25 + lo * 0.95 + 0.15 * sin(T * 0.3 + a[4]), 0.15, 1.2)
      local x, y = a[1], a[2]
      -- (a fleshy column, a ring of tentacles round its mouth, each with a
      -- brighter tip)
      put(3.5 + bloom, x - 1, y - 1, 3, 3)
      put(1.5, x, y, 1, 1)
      local n = 7
      local r = a[3] * open + 1
      for k = 0, n - 1 do
        local aa = k / n * K.TAU + a[4] + sin(T * 1.2 + k) * 0.15
        local ca, sa = cos(aa), sin(aa)
        put(2.8 + 2 * open + K.bj(i * 8 + k) * 0.5, x + ca * r * 0.4, y + sa * r * 0.4, 1, 1)
        if a[3] >= 4 then put(2.5 + 2 * open, x + ca * r * 0.7, y + sa * r * 0.7, 1, 1) end
        put(2 + 2.5 * open + hi * 4 * math.max(0, sin(T * 3.7 + k * 2.1 + i)), x + ca * r, y + sa * r, 1, 1)
      end
    end
    -- the starfish (the chord): turning slowly, creeping to their places
    for i = 1, 4 do
      local m, p = K.chord_at(i)
      local s = SF[i]
      spin[i] = spin[i] + K.DTS * 0.05 * (i % 2 == 0 and 1 or -1)
      if m and p > 0.02 then
        local x = clamp(K.cx(m), 18, 110)
        local y = SF_Y[i] + (60 - m) * 0.12
        local r = clamp(4.5 + (64 - m) * 0.1, 3.5, 7) * (0.5 + 0.5 * p)
        star(x, y, r, spin[i], (3 + 0.8 * bloom + 2.4 * K.chord_glow) * p)
        -- wet, its arms glint with out_hi
        local g = hi * 6 * math.max(0, sin(T * 3.3 + i * 1.9))
        if g > 0.5 then put(g, x + cos(spin[i]) * r, y + sin(spin[i]) * r * 0.85, 2, 1); put(g * 0.8, x - 1, y - 2, 1, 1) end
      end
    end
    -- the notes: small creatures darting
    for i = #marks, 1, -1 do
      local mk = marks[i]
      local age = T - mk.t0
      local cf, done = K.cap_fade(mk)
      if age > 4.5 or done then table.remove(marks, i)
      else
        local e = ease(age / 0.15) * (1 - ease((age - 2) / 2.5)) * cf
        -- (the sand it stirs as it goes)
        put(2.5 * e, mk.x - 3, mk.y + 3, 7, 1)
        local go = 1 - math.exp(-age * 2.5)
        local x, y, d = mk.x, mk.y, mk.dir
        if mk.slot == 1 then
          -- a shrimp flicks backwards: a curled, segmented body, a fanned
          -- tail, long feelers trailing forward
          local sx = x - d * go * 12
          for q = 0, 4 do put((8.5 - q * 0.6) * e, sx + d * (2 - q), y + (q >= 3 and 1 or 0), 1, 2 - (q == 4 and 1 or 0)) end
          put(6 * e, sx - d * 3, y + 2, 1, 1); put(6 * e, sx - d * 4, y + 1, 1, 1); put(6 * e, sx - d * 4, y + 3, 1, 1)
          put(9.5 * e, sx + d * 2, y, 1, 1)                     -- its eye
          for q = 1, 5 do put((5 - q * 0.5) * e, sx + d * (2 + q), y - q * 0.6, 1, 1) end
          for q = 1, 4 do put((4.5 - q * 0.5) * e, sx + d * (2 + q), y + 1 + q * 0.4, 1, 1) end
        elseif mk.slot == 2 then
          -- a small crab scuttles sideways: a rounded shell, two raised
          -- claws, three legs a side stepping
          local cx = x + d * go * 10
          local leg = sin(K.NOW * 16) > 0 and 1 or 0
          put(8.5 * e, cx - 2, y - 2, 5, 1); put(8.5 * e, cx - 3, y - 1, 7, 2); put(7 * e, cx - 2, y + 1, 5, 1)
          put(10 * e, cx - 1, y - 2, 1, 1); put(10 * e, cx + 1, y - 2, 1, 1)      -- eyes
          put(7.5 * e, cx - 5, y - 4, 2, 2); put(7.5 * e, cx + 4, y - 4, 2, 2)    -- claws
          put(6 * e, cx - 4, y - 2, 1, 1); put(6 * e, cx + 4, y - 2, 1, 1)
          for q = 0, 2 do
            local l = (q + leg) % 2
            put(5.5 * e, cx - 5, y - 1 + q + l * 0.5, 2, 1); put(5.5 * e, cx + 4, y - 1 + q + (1 - l) * 0.5, 2, 1)
          end
        elseif mk.slot == 3 then
          -- a goby darts off, a puff of sand behind it: blunt head, eye,
          -- two fins on its back, a tail
          local gx = x + d * go * 18
          put(8.5 * e, gx - 3, y, 7, 2); put(9 * e, gx + d * 3 - (d < 0 and 1 or 0), y, 2, 2)
          put(10 * e, gx + d * 3, y, 1, 1)
          put(6.5 * e, gx - d, y - 1, 2, 1); put(6.5 * e, gx - d * 3, y - 1, 1, 1)
          put(6 * e, gx - d * 5 - (d > 0 and 1 or 0), y - 1, 2, 4)
          K.ring(x, y + 1, 1 + age * 3, 0.6, 4 * e * (1 - go), 10)
        else
          -- a few fry scatter, each a tiny body and a dark eye
          for j = 0, 3 do
            local a = j * 1.6 + d
            local fx, fy = x + cos(a) * go * 9, y + sin(a) * go * 5
            put(8 * e, fx, fy, 3, 1); put(4 * e, fx - cos(a) * 3, fy, 2, 1)
            put(10 * e, fx + cos(a) * 1.5 + 0.5, fy, 1, 1)
          end
        end
      end
    end
    -- a swell refills the pool from its rim: foam spilling in over the edge
    -- and running down into the water
    if sw > 0.03 then
      for k = 0, 17 do
        local u = (T * 0.25 + k / 18) % 1
        local a = k / 18 * K.TAU + 0.2
        local ex, ey = CX + cos(a) * RX * 1.02, CY + sin(a) * RY * 1.04
        local x, y = ex + (CX - ex) * u * 0.35 * sw, ey + (CY - ey) * u * 0.35 * sw
        put(sw * (5.5 - 3 * u) + K.bj(k), x - 2, y, 4, 1)
        put(sw * (3 - 2 * u), x - 1, y + 1, 3, 1)
      end
    end
    -- the moment: a net of sunlight rippling over the floor
    local ma = K.moment_age
    if ma < 14 then
      local e = ease(ma / 2.5) * (1 - ease((ma - 9) / 5))
      for y = PTOP + 3, PBOT - 3, 4 do
        local l0, r0 = PL[y] + 2, PR[y] - 3
        for x = l0, r0, 5 do
          local c = sin(x * 0.21 + y * 0.13 + ma * 1.3) + sin(x * 0.09 - y * 0.27 - ma * 0.9)
          if abs(c) < 0.4 then put(e * (4.5 + 2 * (0.4 - abs(c)) * 3), x, y + (floor(x / 5) % 2), 4, 1) end
        end
      end
    end
    -- incidents
    local inc = K.inc
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "hermit" then
        -- a hermit crab hauls its shell across the floor, stopping to look
        local walk = u + 0.04 * sin(inc.age * 0.9)
        local x = 22 + inc.s * 10 + walk * 72
        local y = 44 + inc.s2 * 8 + sin(u * 4) * 2
        local leg = sin(K.NOW * 9) > 0 and 1 or 0
        -- the shell: a whorl
        put(6.5 * e, x - 3, y - 3, 6, 5); put(8.5 * e, x - 2, y - 2, 3, 2); put(5 * e, x - 1, y - 4, 3, 1)
        put(9 * e, x, y - 1, 1, 1)
        put(7 * e, x + 3, y - 1, 2, 2); put(6 * e, x + 5, y - 2, 1, 1)
        put(6 * e, x + 2, y + 2, 1, 1 + leg); put(6 * e, x + 4, y + 2, 1, 2 - leg)
        put(2.5 * e, x - 3, y + 3, 7, 1)
      elseif inc.name == "slop" then
        -- a wave slops in over the top rim and spreads down the pool
        local reach = sin(math.pi * clamp(inc.age / inc.dur, 0, 1))
        local x0 = 30 + inc.s * 40
        for j = 0, 9 do
          local y = PTOP - 3 + j * 2.4 * reach
          local hw = 8 + j * 2.2 * reach
          local l = e * (6 - j * 0.45) * (0.7 + 0.3 * sin(inc.age * 3 + j))
          -- (dashes on a fixed 5 px grid round x0, fading at the ends: the
          -- sheet widens without its dashes jumping)
          for x = floor((x0 - hw) / 5) * 5, x0 + hw, 5 do
            local fe = clamp((hw - abs(x - x0)) / 5, 0, 1)
            if fe > 0 then put((l + K.bj(j * 13 + x)) * fe, x + sin(j + inc.age * 2) * 1.5, y, 3, 1) end
          end
        end
      else
        -- a gull's shadow glides over the pool: a long soft wing shape
        local x = -30 + u * 190
        local y = 26 + inc.s * 16 + sin(u * 3) * 4
        local flap = sin(inc.age * 2.5) * 1.2
        for j = -16, 16, 2 do
          local t = abs(j) / 16
          local yy = y + (t * t) * 4 * (1 + flap * 0.3) - t * 2
          put(3.2 * e * (1 - t * 0.3), x + j, yy, 2, 2 - (t > 0.7 and 1 or 0))
        end
        put(3.5 * e, x - 2, y - 2, 5, 5); put(3.2 * e, x - 1, y + 3, 3, 2)
      end
    end
    K.glitter(sample, 18)
  end

  M.init()
  return M
end
