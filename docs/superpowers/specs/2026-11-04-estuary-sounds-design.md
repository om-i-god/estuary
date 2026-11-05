# estuary sounds v2: design

The user's brief: "lets improve the sounds of the synths. more variety but still fitting within parameters of [the music estuary is modelled on]". That music is late-80s Japanese environmental music: soft FM electric piano and bells, sine tones, marimba and vibraphone, glassy digital pads, gentle analog strings, all through warm reverb and echo. It is unhurried and bright, with lots of air.

Public files must not name the artist who inspired estuary. Describe the style instead, for example "80s environmental music".

## Intent
estuary has four motif voices (rhodes, bell, sine, marimba), one pad and one pedal. Each is a simple 2-op or modal sketch, and every track uses the same pad. v2 does two things:
1. **Better.** Each sound gets richer and more alive, the way the hardware of that era sounded (DX/TX-style FM, early digital, soft analog). Examples: velocity and brightness shaping, gentle stereo, small natural variation per note.
2. **More variety.** More voices and several pad characters. A track picks a coherent **palette** of sounds, so tracks differ from one another while each still sounds like one record.

## Character rules (hard; failing them fails the project)
- Nothing dark, nothing harsh, nothing busy:
  - no saturation or distortion
  - no detune wide enough to beat sourly; only slow chorus-like movement is allowed
  - no growl, and no noise louder than a breath
  - no aggressive attacks: a click-free onset of at least ~3 ms everywhere, softer on pads
- Everything sits in the existing mix: the same buses, the same sends (echo, verb), the same `motif_level`/`pad_level`/`pedal_level` tweaks.
- Loudness matched. At the same velocity and brightness, every motif voice measures within ±3 dB RMS of the others over its whole note, and every pad character within ±3 dB of the others. Brightness changes timbre, not just volume.
- CPU: the norns is a Raspberry Pi. Keep each motif voice at about the cost of today's marimba (DynKlank, 3 modes) or less. Keep each pad at most about 2× today's pad. No FFT, no convolution. A few DelayC/AllpassC taps for chorus are fine.

## The voices
Keep the four existing names and their identities, improved. Add new voices so there are at least eight in total. Directions (the builder makes the calls):
- **rhodes**: the DX "E.PIANO 1" family. Two FM pairs (a tine and a body), velocity-scaled index, a gentle stereo tremolo, a slightly faster decay at high notes.
- **bell**: a glassy DX/TX bell. Inharmonic ratios, a long tail, a soft strike.
- **sine**: a pure tone with a breathy onset. A very slow vibrato after a delay.
- **marimba**: a warmer, rounder wood. Keep the modal approach and add a soft mallet.
- New, in the same world:
  - **vibes**: a vibraphone with a slow motor tremolo
  - **celesta**: a music-box/celesta, small, high and sweet
  - **kalimba**: a thumb piano, a soft pluck with a short inharmonic shimmer
  - **flute**: a soft breathy pan flute or ocarina, filtered noise breath kept quiet, held notes allowed
  - **glass**: a glass harmonica, a slow swell with a pure core
  - The builder may swap or add others that fit: a soft koto-like pluck, harp, or a choir "ooh". Each must pass the character rules.

## The pad characters (`pad sound` param)
Replace the single pad with at least four characters. Every one keeps the existing crossfade contract (gate, `atk`, `rel`, `pad_xfade`, `padBus`):
- **warm**: today's pad, improved
- **strings**: soft analog strings, saw-ish through a gentle LPF with slow chorus
- **glass**: a digital FM pad with a gentle bell-like shimmer
- **air**: a breathy choir/vowel pad, or filtered noise with resonant partials, very soft
- optionally **organ**: soft sine drawbars

The pedal stays a low pure tone, may gain a little warmth (a soft 2nd harmonic), and gets the same click-free onset.

## Palettes and variety
- A **palette** is a coherent set:
  - one voice for each of the 4 motif slots
  - one pad character
  - optionally small per-palette send and brightness tilts
- Define about 6–10 hand-picked palettes, each a plausible single record, e.g. "rhodes + bell + sine + vibes over warm", "marimba + kalimba + celesta + flute over air".
- On each **new track**, the script picks a palette (seeded, never the same as last time) when the `palette` param is on `auto`. The user can pin a palette by name instead.
- The per-motif `voice` param (currently `auto, rhodes, bell, sine, marimba`) gains the new voices. `auto` now means "from the palette". The `pad sound` param is `auto` (from the palette) or a named character.
- Saved psets must not break. Keep the existing option order and add new options after it, so stored indices keep pointing at the same voices.
- The MIDI out paths are unchanged.

## Engine interface
- The `note` command keeps its signature (`voice, midi, vel, dur, pan, bright, send`); the voice index range grows.
- The pad character is set by a new command or a `tweak` key; the builder chooses. A change applies on the next pad voicing (crossfaded), never as a cut.
- No `t_`-prefixed args that collide with plain-named args. No new `.sc` files outside `lib/`. Use `Mix()`, not `Mix.ar([...])`. Note the BEQ naming quirks if used: `BLowShelf`, `BHiShelf`.
- The engine changes need SYSTEM > RESTART on the device. Say so in the README.

## Tests
- `test/sc/run.scd` (via `test/sc/run.sh`, if sclang is available on this machine):
  - fire every voice and every pad character
  - report the per-voice and per-pad RMS
  - check the ±3 dB loudness match
  - check no NaN and no clipping
  - render a short demo WAV per palette for a human to listen to
- Lua: unit tests for palette choice: seeded, never repeats back-to-back, honours a pinned palette, and the voice and pad params map to the right engine indices. Add the old-pset index compatibility as a test.
- The 900-bar sim and `test/rules.lua` must still pass; the music rules are unchanged. `luac -p` on every Lua file.

## Docs
README: describe the voices, the pad characters, palettes and the new params, saying what they sound like. Never name the artist. Add on-device listening checks to `docs/v1-followups.md`: balance, CPU, any voice that sounds off.

## Left to the builder
The exact synthesis per voice, the ratios and envelopes, the palette list and its names, and whether to use a new engine command or a `tweak` key for the pad character.
