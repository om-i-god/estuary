-- estuary / grid
-- a 16x8 performance surface. reads state, writes through the action table
-- the main script hands in (A). ancestor: gradient's lib/gridui.lua.
--
-- row 1    phrase: where we are in the phrase (8-bar blocks marked)
-- row 2    bloom: lit to the current level; press to pull it there
--          (it relaxes back over the next ~16 bars)
-- row 3    parts: 1 2 3 4 . P L . bed swell moment   (press = mute)
-- row 4-7  motif slots 1-4: one column per event, bright = a note, dim = a
--          rest, playhead brightest. press an event to flip note <-> rest
--          (refused if the motif would lose its 3-7 notes or its last rest).
--          col 15 = mute, col 16 = rewrite
-- row 8    actions: 1 breathe  2 mutate  3 tide  14 new track  16 play/stop

local GU = {}

GU.PARTS = {"motif1", "motif2", "motif3", "motif4", false, "pad", "pedal", false,
            "bed", "swell", "moment"}

local g, A
local flash = {}          -- "x,y" -> time of last press, for a press blink

function GU.init(actions)
  A = actions
  g = grid.connect()
  g.key = function(x, y, z) GU.key(x, y, z) end
end

local function cols() return (g and g.cols and g.cols > 0) and g.cols or 16 end

function GU.key(x, y, z)
  if z == 0 then return end
  local S = A.S
  flash[x .. "," .. y] = util.time()
  if y == 2 then
    A.set_bloom((x - 1) / (cols() - 1))
  elseif y == 3 then
    local k = GU.PARTS[x]
    if k then A.toggle_mute(k) end
  elseif y >= 4 and y <= 7 then
    local i = y - 3
    local m = S.motifs and S.motifs[i]
    if x == 16 then A.rewrite(i)
    elseif x == 15 then A.toggle_mute("motif" .. i)
    elseif m and x <= #m.events then A.toggle_step(i, x) end
  elseif y == 8 then
    local act = ({[1] = "breathe", [2] = "mutate", [3] = "tide", [14] = "fresh", [16] = "play"})[x]
    if act then A[act]() end
  end
end

function GU.redraw()
  if not g then return end
  local S = A.S
  local now = util.time()
  local w = cols()
  g:all(0)

  -- row 1: phrase position
  local P = S.phrase_len or 16
  local bar_in = S.track_bar % P
  local cells = math.min(w, P)
  local per = P / cells
  local cur = math.floor(bar_in / per) + 1
  for x = 1, cells do
    local edge = (((x - 1) * per) % 8) == 0
    g:led(x, 1, x == cur and (S.playing and 15 or 6) or (x < cur and 4 or (edge and 3 or 1)))
  end

  -- row 2: bloom
  local lit = math.floor(S.bloom * (w - 1) + 0.5) + 1
  for x = 1, w do
    g:led(x, 2, x <= lit and (x == lit and 12 or 5) or 1)
  end

  -- row 3: parts (nature parts light with their level)
  local m = S.muted or {}
  for x, k in ipairs(GU.PARTS) do
    if k then
      local on = S.gain[k]
      if on == nil then on = (S.nature_state ~= "idle" and k == "swell") and 1 or 0.5 end
      g:led(x, 3, m[k] and 2 or (4 + math.floor(on * 11)))
    end
  end

  -- rows 4-7: motif events
  for i = 1, 4 do
    local mo = S.motifs and S.motifs[i]
    if mo then
      local y = 3 + i
      local head = mo.pos - 1
      if head < 1 then head = #mo.events end
      for x, e in ipairs(mo.events) do
        local note = e.tone ~= nil or e.pass ~= nil
        local lvl = note and 8 or 2
        if x == head and S.playing and S.sounding[i] then lvl = note and 15 or 5 end
        g:led(x, y, lvl)
      end
      g:led(15, y, m["motif" .. i] and 2 or 6 + math.floor((S.gain["motif" .. i] or 0) * 6))
      g:led(16, y, 3)
    end
  end

  -- row 8: actions
  local lv = {[1] = 5, [2] = 5, [3] = (S.nature_state or "idle") ~= "idle" and 15 or 5,
              [14] = 3, [16] = S.playing and 12 or 4}
  for x, v in pairs(lv) do
    if x <= w then g:led(x, 8, v) end
  end

  -- press blink
  for key, t in pairs(flash) do
    if now - t < 0.12 then
      local x, y = key:match("(%d+),(%d+)")
      g:led(tonumber(x), tonumber(y), 15)
    else
      flash[key] = nil
    end
  end

  g:refresh()
end

return GU
