-- estuary / outs
-- everything that leaves norns besides the internal engine: midi notes per
-- part (internal / midi / both), midi transport, crow cv, midi cc.
-- ancestor: gradient's lib/outs.lua (+ the midi_note helper from gradient.lua).
--
-- the main script gates first (thinning, mutes), then calls O.note: a part
-- the conductor has silenced sends nothing here either. `vel` is 0..1 and
-- already carries the part's gain (vel x gain); midi velocity is that x 127.
--
-- crow: pitches are 1V/oct with C3 (midi 48) at 0V, gates are 8V, bloom is
-- 0-5V.

local O = {}

O.OUT_NAMES  = {"internal", "midi", "both"}
O.LANE_NAMES = {"all (one ch)", "motif 1", "motif 2", "motif 3", "motif 4", "own ch each"}
O.CROW_NAMES = {"off", "lead pitch", "lead gate", "chord root", "bloom", "pedal pitch", "pedal gate"}
-- crow assignment -> {kind, "pitch"|"gate"}
local CROW_FOR = {[2] = {"motif", "pitch"}, [3] = {"motif", "gate"}, [4] = {"pad", "pitch"},
                  [6] = {"pedal", "pitch"}, [7] = {"pedal", "gate"}}
local KINDS = {"motif", "pad", "pedal"}
local DEFAULT_CH = {motif = 3, pad = 2, pedal = 1}
local GAP = 0.95            -- a note lets go a hair early so a repeat re-strikes

local devs = {}             -- "motif"/"pad"/"pedal"/"transport"/"cc" -> midi device
local hanging = {}          -- "ch:note" -> {dev, ch, note, id, kind, slot}
local note_id = 0
local gate_id = {0, 0, 0, 0}
local cc_last = {}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function crow_ok()
  return crow ~= nil and (crow.connected == nil or crow.connected())
end

local function crow_mode(n) return params:get("crow_" .. n) end

------------------------------------------------------------------------
-- midi notes
------------------------------------------------------------------------

local function off(key)
  local h = hanging[key]
  if h then
    h.dev:note_off(h.note, 0, h.ch)
    hanging[key] = nil
  end
end

-- release everything a kind holds (nil = every kind); slot narrows a motif
function O.release(kind, slot)
  for key, h in pairs(hanging) do
    if (not kind or h.kind == kind) and (not slot or h.slot == slot) then off(key) end
  end
end

function O.all_off()
  O.release()
  for _, kind in ipairs(KINDS) do
    local dev = devs[kind]
    if dev then
      local ch = params:get(kind .. "_ch")
      local n = (kind == "motif" and params:get("motif_lanes") == 6) and 3 or 0
      for c = ch, math.min(16, ch + n) do dev:cc(123, 0, c) end
    end
  end
end

function O.held(kind)
  for _, h in pairs(hanging) do
    if h.kind == kind then return true end
  end
  return false
end

-- where does a note of `kind` (from motif `slot`) go? -> internal, midi.
-- a part routed to midi with no device keeps sounding inside; a motif the
-- lane pick leaves out of midi keeps sounding on norns.
function O.route(kind, slot)
  local out = params:get(kind .. "_out")
  local midi_on = out >= 2 and devs[kind] ~= nil
  if midi_on and kind == "motif" then
    local lanes = params:get("motif_lanes")
    if lanes >= 2 and lanes <= 5 and lanes - 1 ~= slot then midi_on = false end
  end
  local internal = out ~= 2 or not midi_on
  return internal, midi_on
end

local function channel(kind, slot)
  local ch = params:get(kind .. "_ch")
  if kind == "motif" and params:get("motif_lanes") == 6 then ch = ch + (slot or 1) - 1 end
  return clamp(ch, 1, 16)
end

local function midi_note(kind, note, vel, dur, slot)
  local dev = devs[kind]
  local ch  = channel(kind, slot)
  local key = ch .. ":" .. note
  off(key)                                  -- a repeat re-strikes
  -- a motif is one voice: its new note ends its last (a motif that was just
  -- rewritten can't ring on under its replacement)
  if kind == "motif" then O.release("motif", slot) end
  -- the pedal is one low voice too: a new pedal note ends the old one
  if kind == "pedal" then O.release("pedal") end
  note_id = note_id + 1
  local id = note_id
  dev:note_on(note, clamp(math.floor(vel * 127), 1, 127), ch)
  hanging[key] = {dev = dev, ch = ch, note = note, id = id, kind = kind, slot = slot}
  if dur then                               -- no dur = held until released
    clock.run(function()
      clock.sleep(dur * GAP)
      if hanging[key] and hanging[key].id == id then off(key) end
    end)
  end
end

------------------------------------------------------------------------
-- crow
------------------------------------------------------------------------

local function crow_assign(n, m)
  if not crow_ok() then return end
  local o = crow.output[n]
  o.slew  = 0
  o.volts = 0
  if m == 5 then o.slew = 0.5 end
end

local function crow_note(kind, note, dur, slot)
  if not crow_ok() then return end
  if kind == "motif" then
    local lane = params:get("crow_lead_lane")
    if lane > 0 and lane ~= slot then return end
  end
  local volts = clamp((note - 48) / 12 + params:get("crow_oct"), -5, 10)
  for n = 1, 4 do
    local f = CROW_FOR[crow_mode(n)]
    if f and f[1] == kind then
      if f[2] == "pitch" then
        crow.output[n].slew  = params:get("crow_slew")
        crow.output[n].volts = volts
      else
        gate_id[n] = gate_id[n] + 1
        local id = gate_id[n]
        crow.output[n].volts = 8
        clock.run(function()
          clock.sleep(math.max(0.01, dur or 0.1))
          if gate_id[n] == id then crow.output[n].volts = 0 end
        end)
      end
    end
  end
end

-- one note of `kind`: midi if routed, crow if assigned. dur in seconds (nil
-- holds a midi note until O.release); pad notes come one by one, slot = the
-- voice 1..4 (crow's chord root takes voice 1 only).
function O.note(kind, note, dur, slot, vel)
  local _, to_midi = O.route(kind, kind == "motif" and slot or nil)
  if to_midi then midi_note(kind, note, vel or 0.6, dur, slot) end
  if kind ~= "pad" or slot == 1 then crow_note(kind, note, dur, slot) end
end

------------------------------------------------------------------------
-- params
------------------------------------------------------------------------

function O.setup_params(vport_names, vport_ids)
  local function dev_param(key, id, name, after)
    params:add_option(id, name, vport_names, 1)
    params:set_action(id, function(v)
      if after then after() end
      local pid = vport_ids[v]
      devs[key] = (pid and pid > 0) and midi.connect(pid) or nil
    end)
  end

  for _, kind in ipairs(KINDS) do
    params:add_separator(string.upper(kind) .. " OUT")
    params:add_option(kind .. "_out", "output", O.OUT_NAMES, 1)
    params:set_action(kind .. "_out", function() O.all_off() end)
    dev_param(kind, kind .. "_dev", "midi device", O.all_off)
    params:add_number(kind .. "_ch", "midi channel", 1, 16, DEFAULT_CH[kind])
    if kind == "motif" then
      params:add_option("motif_lanes", "motifs to midi", O.LANE_NAMES, 1)
      params:set_action("motif_lanes", function() O.all_off() end)
    end
  end

  params:add_separator("SYNC OUT")
  dev_param("transport", "transport_dev", "midi start/stop to")
  -- clock pulses themselves come from PARAMS > CLOCK > midi out

  params:add_separator("CROW")
  for n = 1, 4 do
    params:add_option("crow_" .. n, "out " .. n, O.CROW_NAMES, 1)
    params:set_action("crow_" .. n, function(m) crow_assign(n, m) end)
  end
  params:add_number("crow_lead_lane", "lead motif (0 = any)", 0, 4, 0)
  params:add_control("crow_slew", "pitch slew", controlspec.new(0, 0.5, "lin", 0.005, 0, "s"))
  params:add_number("crow_oct", "pitch octave", -3, 3, 0)

  params:add_separator("CC OUT")
  dev_param("cc", "cc_dev", "midi device")
  params:add_number("cc_ch", "channel", 1, 16, 16)
  -- 0 = off
  params:add_number("cc_bloom", "bloom cc", 0, 127, 0)
  params:add_number("cc_tone", "tone cc", 0, 127, 0)
  params:add_number("cc_phrase", "phrase pulse cc", 0, 127, 0)
end

------------------------------------------------------------------------
-- transport
------------------------------------------------------------------------

function O.start()
  if devs.transport then devs.transport:start() end
end

function O.stop()
  O.all_off()
  if devs.transport then devs.transport:stop() end
  if crow_ok() then
    for n = 1, 4 do
      local f = CROW_FOR[crow_mode(n)]
      if f and f[2] == "gate" then crow.output[n].volts = 0 end
    end
  end
end

------------------------------------------------------------------------
-- once a bar: bloom cv + ccs
------------------------------------------------------------------------

local function cc(num, val)
  if num == 0 or not devs.cc then return end
  val = clamp(math.floor(val + 0.5), 0, 127)
  if cc_last[num] == val then return end
  cc_last[num] = val
  devs.cc:cc(num, val, params:get("cc_ch"))
end

function O.bar(S, phrase_start)
  if crow_ok() then
    for n = 1, 4 do
      if crow_mode(n) == 5 then crow.output[n].volts = clamp(S.bloom, 0, 1) * 5 end
    end
  end
  cc(params:get("cc_bloom"), clamp(S.bloom, 0, 1) * 127)
  cc(params:get("cc_tone"), params:get("tone") * 1.27)
  local pc = params:get("cc_phrase")
  if pc > 0 and devs.cc then cc(pc, phrase_start and 127 or 0) end
end

return O
