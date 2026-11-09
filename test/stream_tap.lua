-- engine stream tap for the sim: every engine command the script sends,
-- with the step clock's beat, written to $STREAM one per line. loaded ahead
-- of the sim so it works on any tree's sim (main's too):
--   STREAM=out.txt SEED=3 lua -e 'dofile("<repo>/test/stream_tap.lua")' test/sim.lua 300
-- the sim builds its own `engine` stub; the tap wraps it as it is assigned.

local path = assert(os.getenv("STREAM"), "set STREAM=<file>")
local out = assert(io.open(path, "w"))

local function fmt(v)
  if type(v) == "number" then
    if math.type and math.type(v) == "integer" then return tostring(v) end
    return string.format("%.17g", v)
  end
  return tostring(v)
end

local function wrap(stub)
  return setmetatable({}, {
    __index = function(_, k)
      local f = stub[k]
      if type(f) ~= "function" then return f end
      return function(...)
        local t = {k, string.format("%.3f", rawget(_G, "STEP_BEATS") or 0)}
        for i = 1, select("#", ...) do t[#t + 1] = fmt((select(i, ...))) end
        out:write(table.concat(t, " "), "\n")
        return f(...)
      end
    end,
    __newindex = function(_, k, v) stub[k] = v end,
  })
end

setmetatable(_G, {__newindex = function(t, k, v)
  if k == "engine" and type(v) == "table" then v = wrap(v) end
  rawset(t, k, v)
end})
