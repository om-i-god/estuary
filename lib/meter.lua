-- estuary / meter
-- the time signature: how many 8ths make a bar, where the bar leans, and
-- which motif cycles fit it. 4/4 is the plain bar: no lean, the motifs keep
-- their odd phasing cycles only.
--
-- the option list only grows at the end: stored psets keep their meter.

local MT = {}

-- lean: 8th position in the bar (0 = the downbeat) -> velocity factor
MT.METERS = {
  {name = "3/4", bar = 6,  lean = {[0] = 1.08}},
  {name = "4/4", bar = 8},
  {name = "5/4", bar = 10, lean = {[0] = 1.08, [6] = 1.04}},             -- 3+2 beats
  {name = "6/8", bar = 6,  lean = {[0] = 1.08, [3] = 1.04}},             -- 3+3 eighths
  {name = "7/8", bar = 7,  lean = {[0] = 1.08, [2] = 1.04, [4] = 1.04}}, -- 2+2+3 eighths
}
MT.DEFAULT = 2
MT.NAMES = {}
for i, m in ipairs(MT.METERS) do MT.NAMES[i] = m.name end

local function get(i) return MT.METERS[i or MT.DEFAULT] or MT.METERS[MT.DEFAULT] end

-- 8ths per bar
function MT.bar8(i) return get(i).bar end

-- beats per bar (7/8 is 3.5)
function MT.beats(i) return get(i).bar / 2 end

function MT.name(i) return get(i).name end

-- the velocity factor for a note starting on 8th `pos` of the bar, nil when
-- it leans not at all (always nil at 4/4, so 4/4 is untouched)
function MT.lean(i, pos)
  local l = get(i).lean
  return l and l[pos]
end

return MT
