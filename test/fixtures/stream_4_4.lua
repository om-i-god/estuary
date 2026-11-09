-- the engine stream at 4/4 before meters existed (main at 167eff3): every
-- engine command the sim heard (notes, pad, pedal, nature, tweaks, with the
-- step clock's beat), recorded through test/stream_tap.lua as
--   STREAM=f SEED=<seed> lua -e 'dofile("test/stream_tap.lua")' test/sim.lua <args>
-- and hashed (32-bit FNV-1a over the whole file). 4/4 must replay it exactly.
return {
  {seed = 3, args = "300 1", lines = 1623, hash = 0xa53d0638},
  {seed = 3, args = "300 2 4", lines = 1498, hash = 0xa0eaf148},
  {seed = 3, args = "300 2 6 96", lines = 1490, hash = 0x20856ff7},
  {seed = 17, args = "300 1", lines = 1592, hash = 0x304a936f},
  {seed = 17, args = "300 2 4", lines = 1559, hash = 0x76a0a0f0},
  {seed = 17, args = "300 2 6 96", lines = 1288, hash = 0x3d972966},
  {seed = 404, args = "300 1", lines = 1329, hash = 0x4172c4f8},
  {seed = 404, args = "300 2 4", lines = 1481, hash = 0x68fc7192},
  {seed = 404, args = "300 2 6 96", lines = 1414, hash = 0x1d5b55af},
  {seed = 9001, args = "300 1", lines = 1283, hash = 0x48bb2e30},
  {seed = 9001, args = "300 2 4", lines = 1420, hash = 0x8a20c434},
  {seed = 9001, args = "300 2 6 96", lines = 1279, hash = 0xa587eb13},
}
