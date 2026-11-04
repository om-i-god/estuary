# estuary visuals v2: design

The user's brief: the themes should be "more interesting and audioreactive and robust within their themes", "moving naturally like an estuary". They handed the details to the builder ("just make em better").

## Intent
Someone glances at the screen during a set and sees water behaving like water. The screen is never still and never jumps. It swells, eddies and drifts, and the tide moves under everything. Sound adds force to that motion rather than switching things on and off. Each theme stays recognisably itself, whatever the music is doing.

## What changes

### 1. The engine listens to its own output (`lib/Engine_Estuary.sc`)
- Analyse the master mix after the reverb, before the limiter, so tails count. Write four control-rate values:
  - `out_amp`: overall level (Amplitude, attack ~0.05, release ~0.4)
  - `out_lo`: below ~250 Hz (pad and pedal)
  - `out_mid`: ~250 Hz–2.5 kHz (motif bodies)
  - `out_hi`: above ~2.5 kHz (bell and air, water hiss)
- Use cheap filters (LPF/BPF/HPF and Amplitude). Use no FFT; CPU matters on norns.
- Expose the four values as polls, plus `nat_amp`: the summed water/nature level, which the engine already measures per slot.
- Watch for `t_` arg collisions. Add no new `.sc` files under test/.
- The engine changes need SYSTEM > RESTART on the device.

### 2. A shared "estuary physics" layer in `lib/visuals.lua`
- **Inputs.** Poll values arrive through `VIS.audio(name, v)`, and each feeds an envelope follower with a fast-ish rise and a slow fall, so motion eases. Silent or missing polls (nil, NaN, never started) read as 0. Every theme must work with no audio data at all, as in the headless sim.
- **The current.** A slow flow field shared by all themes, built from a few drifting sine terms.
  - Its direction turns slowly with the tide: out while the bloom rises, back in while it falls.
  - A swell pushes it inland.
  - Sound energy raises its strength. `out_lo` adds a long, slow heave. `out_hi` adds fine glitter: a few short-lived bright points on the water surface.
- **Time.** The motion is time-based, not frame-count-based: the speed param scales real time, and motion stays smooth whatever the FPS.
- **Events.** Notes, chords, swells and moments still seed things, but they arrive eased: no full-brightness pop on the first frame.

### 3. The six themes: same names, same identities, deeper
- **ripples.** Rings drift with the current after they land and interfere softly where they overlap. A faint surface texture always moves: glitter from `out_hi`, slow undulation from `out_lo`. Echoes still follow the echo time. Ring brightness rides `out_amp`, so reverb tails keep the surface alive after a note.
- **horizon.**
  - The waterline is a layered wave: its height and roughness come from `out_lo` and `nat_amp`, and it rises during a swell.
  - The chord bands under it are refracted by that same wave. A reflection of the brightest band shimmers with `out_hi`.
  - The sky dims and brightens slowly with the bloom. A moment still crosses the sky.
- **postcards.**
  - The four frames become four small windows onto the same estuary from different spots. Each holds a tiny scene of water and horizon.
  - Water level and chop come from the shared current and audio. Light inside the frame comes from that slot's recent notes.
  - An empty slot's window still shows water, dimly.
- **rain.**
  - Notes still fall as drops from their pitch. Wind from the current slants them.
  - Ambient drizzle density follows `out_hi`, with 0 at silence.
  - The ground becomes a water surface. It undulates with `out_lo`, and drops make small spreading rings in it.
- **tide.**
  - The shoreline still holds the bloom history.
  - At the live edge, waves wash up the sand and draw back in a slow rhythm. Their reach follows `out_amp` and `nat_amp`.
  - Foam glitters with `out_hi`, and a swell floods the whole beach.
- **drift.**
  - The orbits become eddies: their shapes wobble with `out_lo` and they precess slowly with the current.
  - Points leave short fading trails.
  - Phase-alignment lines still join points, and they shimmer.

## Robustness
These are requirements; the tests pin them.
- **Silence.** Stopped, bed only, or no audio data: every theme still shows gentle motion and is never blank. The current and the faint surface keep moving.
- **Peak.** Full bloom, 3 motifs, a swell and a moment, with audio pinned at 1:
  - No theme lights more than about 35% of pixels.
  - Nothing goes to level 15 across a wide area.
  - Object counts stay capped, as now.
- **Continuity.** No jumps. Frame-to-frame change stays bounded at steady input, including across a theme switch and the start and end of a swell.
- **Bad input.**
  - nil, NaN, negative or above-1 audio values are clamped.
  - A chord of fewer than 4 notes, or none, works.
  - Missing motifs work.
  - A tempo change mid-frame works.
- **Budget.** Draw cost per frame stays within today's order of magnitude, measured as rect count per frame in the raster stand-in. Keep the batched-fill approach.
- **Character.** Soft greys and a lot of black. Nothing flashes the whole screen. Brightness and speed params still scale everything.

## Tests (headless; extend `test/raster.lua` and the sim GRID/SNAP paths)
For each theme × {silence, mid, peak, swell}, check:
- lit-pixel ratio within bounds
- non-blank at silence
- bounded frame-to-frame diff
- no NaN
- rect count under budget

An audio-reactivity check: ramping `out_hi` or `out_lo` measurably changes each theme. Run SNAP to write PGM frames for a human look.

## Left to the builder
Exact constants, shapes, curves and the drawing technique, within the above.
