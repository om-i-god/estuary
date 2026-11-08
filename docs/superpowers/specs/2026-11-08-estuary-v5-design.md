# estuary v5: four more places, a wider sound, everything listening

The user's brief: "add four more visual themes and expand the sound even further. full audioreactivity on everything".

v5 builds on v4 visuals (`2026-11-05-estuary-visuals-v4-design.md`) and sounds v2 (`2026-11-04-estuary-sounds-design.md`). Every rule in those specs still holds:
- character: nothing dark, nothing busy, nothing harsh
- the visual budgets, tests and caps
- loudness matching
- the CPU ceilings
- old psets keep working, because lists only grow at the end
- no device names, IPs or key paths, and never the name of the artist who inspired estuary

There are two independent streams, each on its own branch.

## A. Visuals: four new places (sixteen in total)
Append these to `VIS.names` after `flock`, in this order. Each one meets the full v4 bar:
- parallax layers
- three rare incidents
- bloom as daylight
- hand-made dither
- every input reacting visibly and distinctly
- the v4 test matrix (reactivity, pitch mapping, incidents, onsets, bar breath, budget ≤1100 draw calls, frame time)

The four places:
- **brook.** A stream running over stones, seen slightly from above.
  - Streamlines bend around the stones, and the flow speed rides `out_amp` and the current.
  - Each note sets a stone glinting, or a small standing wave at its pitch's column.
  - The chord is the stones themselves: they rearrange slowly when the chord moves.
  - `nat_amp` adds white-water texture.
  - Incidents: a dipper bird, a leaf boat, a trout rising.
- **rockpool.** A tide pool at low tide, seen from above.
  - Anemones open and close with `out_lo`, and weed sways with heave.
  - Notes are small crabs or shrimp darting, a different creature per slot.
  - The chord is starfish.
  - A swell refills the pool from its rim.
  - Incidents: a hermit crab crossing, a wave slopping in, a gull's shadow.
- **dew.** A spider's web strung between reeds at dawn, close up.
  - Each note lights one dew drop at its pitch's place on the web, and it trembles and catches light.
  - `out_hi` adds sparkle and `out_lo` makes the web sway.
  - The chord is the four anchor threads.
  - Bloom is the sun rising behind it.
  - Incidents: the spider adjusting a thread, a drop falling, a damselfly.
- **cascade.** A small waterfall into a pool.
  - The falling sheet is textured by `out_mid` and `nat_amp`, with spray that rides `out_hi`.
  - Notes are bright fish or pebbles flashing in the pool.
  - The chord is the stepped ledges.
  - A swell swells the fall.
  - Incidents: a kingfisher, a rainbow in the spray (eased in and out), a log drifting past.

Update the README visuals section, the K1 label fit (the longest label is now "cascade 16/16"), and add a v5 device-check section to `docs/v1-followups.md`.

## B. Sound: wider, and listening

### More voices (appended to `P.VOICES` and the engine's voiceDefs)
Add at least five, in the same late-80s soft-gear world, each loudness-matched, with a click-free onset and within the CPU ceiling:
- **harp.** A soft plucked harp with a long ring.
- **koto.** A gentle koto-like pluck with a slight pitch bend on the attack. No twang harshness.
- **choir.** A soft "ooh" with a formant voice and a slow onset.
- **glock.** A small soft glockenspiel, rounder than the celesta.
- **piano.** A soft felt piano with hammer and string modes. Not a sample.
- Optionally more voices that fit, such as steel-string guitar harmonics or ocarina.

### More pad characters (appended to `P.PADS`)
Add at least three:
- **shimmer.** A slow octave-up halo.
- **tape.** Warm, with a very slow, gentle pitch drift of a few cents. No saturation, no wow you can hear as sour.
- **reed.** A soft accordion or harmonium-like pad, filtered and gentle.

### More palettes
Bring the total to about 16 by adding about 7 palettes that use the new sounds, each a plausible single record. Palette names may not clash with visual theme names: v2's "tidepool" and "mist" palettes stay, since stored indices must not move, so don't add more clashes.

### Everything listening (audio reactivity in the sound)
The music's notes stay exactly as they are; `test/rules.lua` and each seed's music are unchanged. What becomes reactive is timbre and space, driven by what the engine hears:
- **The water.** Loudness of the field recordings (`nat_amp`, already measured) gently opens the pad's filter and the motif brightness, and widens the reverb send. When water swells, the music brightens and breathes with it.
- **The room.** When live input listening is on, the input level (`in_amp`) gently tilts brightness and echo feedback, so the set leans into the room.
- **Itself.** The engine's own output energy (out_amp/out_lo) drives a slow, gentle ducking of the pad under busy motif passages (sidechain-like but very soft, around 2–3 dB at most), and opens the reverb in sparse passages.
- All of this is done with control-rate followers inside the engine, which is cheap: slow attack (≥0.3 s) and slow release (≥1.5 s). No audible pumping and no feedback runaway: the analysis feeding a modulation must be taken from a point the modulation cannot amplify without bound, or be clamped.
- New params in SOUND:
  - `react`: depth, 0..1, default about 0.5
  - `react source`: water / room / self / all, default all
  - At 0 everything sounds exactly as in v2.

### Tests
- `test/sc/run.sh` and `sounds.scd`:
  - Every new voice and pad loudness-matched (voices ±3 dB, pads ±3 dB).
  - No NaN and no clipping.
  - The onset rule.
  - Palette demos rendered for the new palettes into the session scratchpad.
  - A reactivity check: with react at 0.8, driving the nature level up measurably raises spectral brightness (e.g. an HPF-ed RMS ratio) and the reverb send. With react at 0 the output is unchanged versus v2 (null test within tolerance).
  - No runaway: 60 s with everything at max stays bounded.
- Lua: unit tests for the new param mappings and old-pset indices; palette choice still seeded and still never repeats back to back.
- The 900-bar sims (`900` and `900 2 4`, which must now hear all voices) and the rules selftest pass. `luac -p` on every file.

### Docs
README: the new voices, pads and palettes, and what react does (what you'll hear). Add a sounds v3 listening-check section to `docs/v1-followups.md`.

## Addendum (same day): four more places and four more voices
The user asked for "4 more places that were just as awesome and four more voices as well".

**Places:** these follow cascade, in this order, for twenty places in total. Each meets the same v4 bar.
- **mangrove.** Roots arch into tea-coloured water while the tide rises and falls among them. Notes are fish between the roots, and the chord is the roots catching light. Incidents: a heron, a mudskipper, a canoe.
- **aurora.** A calm fjord at night, with soft aurora curtains reflected in still water. Notes light rays, the chord is the curtain bands, and bloom sets the aurora's strength. Incidents: a shooting star, a seal, a lit cabin window.
- **shoal.** A silver school of fish under a pier (boids, at most 40). Notes flash fish as they catch the light, and the chord is light bands on the piles. Incidents: a ray, a turtle, the school splitting around a larger fish.
- **paddies.** Terraced rice paddies after rain, each terrace mirroring the sky. Notes ripple the terraces, the chord is the terrace light, and `nat_amp` is water trickling between them. Incidents: an egret, a distant hat moving along a path, frogs.

**Voices:** four more, on top of B's five, appended in this order. The palettes grow to about 18–20.
- **dulcimer.** A soft hammered dulcimer.
- **steelpan.** A mellow steelpan, never clangy.
- **guitar.** A nylon pluck or warm harmonics.
- **horn.** A soft 80s analog horn that swells slowly and never blares.

## Addendum 2: two San Antonio places
The user asked for "a theme called echo bridge based on the echo bridge in san antonio tx. and one called confluence based on confluence park". Both go after paddies, for 22 places in total, and both meet the same v4 bar.
- **echo bridge.** The concrete closed-spandrel deck arch of the Roosevelt Ave bridge over the San Antonio River, known for its acoustics and for music under it before sunset. The arch and its reflection make an ellipse, under a warm sunset. Each note rises as a soft arc under the arch and then repeats as fading copies at the echo-time setting. Reverb tails linger on the underside of the arch. Incidents: a heron through the arch, a kayak, cliff swallows.
- **confluence.** Confluence Park's concrete petal pavilions: paired hyperbolic-paraboloid petals that funnel rain to a cistern. Native plants grow around them, and San Pedro Creek meets the San Antonio River. Notes become droplets running down the petals into a glowing cistern pool whose level is the bloom. A swell is a rain shower. Incidents: a monarch butterfly, a great egret, a rain cloud.

Both are stylised, with no logos or text.
