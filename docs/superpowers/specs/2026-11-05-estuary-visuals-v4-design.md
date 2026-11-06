# estuary visuals v4: richer, more reactive

The user's brief was "make the visuals more robust". Asked what that meant, they chose two things: **richer scenes** and **more reactive**. Code sturdiness and long-term evolution were the options they did not pick.

This builds on v3 (`2026-11-04-estuary-visuals-v3-design.md`), which stays binding: the twelve themes and their order, the character rules, the 35% lit cap, no level 15 over wide areas, and every test.

## Richer scenes
Each of the twelve places gets more layers and more life within its own identity. Guidance:
- **Depth.** Each scene has a far layer, a middle and a near layer that move at different rates with the current (parallax).
- **Life.** Small natural things that come and go on their own: a heron, a fish jump, a drifting leaf, a passing cloud, a ripple from an insect. Each theme should have 2–3 such "incidents" that fit its place. They happen rarely, slowly and quietly, and never at the same time.
- **Light.** The bloom acts like daylight: as it rises the scene warms and brightens subtly, and as it falls it cools. Reflections on water should match what is above them.
- **Texture.** Dithered gradients, silhouettes and surface patterns should look hand-made rather than ruled. Break up straight scanline rows (v3 had some fence-like skies) with irregular, noise-driven dither.
- Keep it calm. More detail must not mean more motion everywhere. Most of the screen stays still or slow; activity concentrates where the music is.

## More reactive
Every theme must respond **visibly and distinctly** to each of these inputs. Distinctly means you can tell which input caused the change:
- **Notes:** per slot and per pitch. Where the note lands on screen follows its pitch, and the slot changes what kind of mark it makes.
- **Chord changes:** a visible, eased change of colour or arrangement when the chord moves. The chord's notes are represented in the scene: bands, pads, stones, stars, etc.
- **The bar pulse:** a very gentle breath on the bar, not a flash.
- **Bloom:** light and density.
- **Swell:** a scene-wide event, such as water rising, fog thickening or wind.
- **Moment:** a rare, special, eased event unique to each theme.
- **Engine polls:**
  - `out_amp` drives overall energy and movement.
  - `out_lo` drives heave, sway and large slow forms.
  - `out_mid` drives the mid-scale features. v3 barely uses it: give it a clear role in every theme.
  - `out_hi` drives glitter, shimmer and fine detail.
  - `nat_amp` drives the field-recording layer, such as water noise, rain density, wind and birds.

The response should be proportional and eased, never a switch. Use the existing envelope followers.

## Constraints
- Same API, file layout (`lib/visuals.lua` and `lib/vis/<name>.lua`), `include()` loading, no globals, locals before use.
- **Budget.** Per-frame draw calls at most 1100 for any theme in any scenario (the v3 test budget). Prefer cheap techniques: wide rects, precomputed silhouettes and dither masks built once at init or on theme switch, no per-frame table allocation in hot loops. Report the per-theme peaks. Lua CPU per frame matters on the Pi as much as rect count, so measure frame time in the headless run and keep it within about 1.3× v3's.
- Every incident and reactive object is capped and cleared on theme switch and `VIS.init`.
- Never name the artist who inspired estuary, and never write device names, IPs or key paths, in any repo file.

## Tests
Extend `test/unit_visuals.lua`:
- **Reactivity matrix.** For every theme, and for each input (note, chord change, bar, bloom ramp, swell, moment, `out_amp`, `out_lo`, `out_mid`, `out_hi`, `nat_amp`), changing that input alone, from a fixed seeded state, changes the picture by more than a clear threshold. Set it well above v3's koi `out_hi` margin of 0.011 against 0.01. Also check that notes in different slots leave different marks.
- **Pitch mapping.** A low note and a high note in the same slot land in measurably different places.
- **Incidents.** Over a long run (e.g. 20 simulated minutes), each theme shows at least 2 distinct incident types, never two at once, and each is eased in and out (the onset test still passes).
- All v3 tests still pass: lit ratio, non-blank silence, continuity, onsets, NaN, budget, variable dt, speed.

Run SNAP and look at a contact sheet with still, mid and loud columns, plus one frame per theme mid-incident.

## Docs
- README visuals section: what each place shows and what moves it, input by input in a compact form. Describe it; no "won't do" sections.
- `docs/v1-followups.md`: a v4 device-check section.
- Update the omigod estuary page's theme captions and OLED demo port to match: `/Users/omneo/dev/omigod/public/works/estuary/index.html`. That is a separate repo; leave it uncommitted.
