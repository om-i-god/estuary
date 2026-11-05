# estuary visuals v3: design

The user's brief: "lets make even better visuals and more variety too all water and nature themed". This builds on visuals v2 (`2026-11-03-estuary-visuals-design.md`). Everything in that spec still holds unless this one changes it: the engine polls, shared physics, time-based motion, robustness rules and test matrix.

## Intent
Today's six themes are calm and correct, but they are mostly abstract: dotted ellipses, thin lines and a lot of empty black. At a glance they read as diagrams of water rather than water. v3 makes each theme a small *place*. You should be able to name what you are looking at (a reed bed, a pond, a kelp forest) and see it alive. The music moves it, and quiet still looks peaceful rather than empty.

Two goals:
1. **Better.** Each existing theme gets depth and a sense of place, while keeping its idea and name.
2. **More variety.** Six new themes, all water and nature: twelve in total.

## Character (unchanged rules, restated)
- Nothing busy and nothing dark. Calm, bright-feeling scenes. A dusk scene is fine; a threatening one is not.
- Soft greys with plenty of black. Nothing flashes the whole screen. No theme lights more than about 35% of pixels at peak, and nothing goes to level 15 across a wide area.
- Motion is slow and natural, eased, driven by time, never by frame count.
- Brightness and speed params still scale everything.
- **New:** a theme at mid activity should read as a scene, not a near-empty screen. Use the dim levels (1–4) for atmosphere: sky gradients by dithered rows, distant shore silhouettes, water texture. Save the brighter levels for what the music is doing.

## Making the existing six better (same names, same ideas)
These directions are guidance; the builder makes the calls.
- **ripples.** Add a still pond with a far bank and the sky reflected in it. Rings refract the reflection where they pass. Add a lily pad or two that bob on the rings.
- **horizon.** Add a dithered sky gradient that follows bloom, a sun or moon low on the horizon, and a distant headland silhouette. The sun's glitter path rides `out_hi`.
- **postcards.** Give each window its own place: shore, open water, reeds, rocks. One estuary seen from four spots, each lit by its slot.
- **rain.** Add a far tree line and a nearer bank. Drops ring the water. A misty band near the surface rises with `out_lo`.
- **tide.** Add sand texture, wet-sand sheen behind the retreating wash, and foam lace. A bird or two may stand at the edge.
- **drift.** Make the eddies read as water seen from above: leaves or petals carried in the eddies, trailing, with the phase lines kept as a faint shimmer.

## Six new themes
Each one must follow the music in a way you can see: notes, chord, bloom, swells, moments and the polls.
- **reeds.** A reed bed at the water's edge, in silhouette, with layered depth.
  - Stems sway with the shared current and heave; sound energy bends them further.
  - A note makes one reed nod, or sends a dragonfly hovering past at that pitch's column.
  - A swell moves a slow ripple of bending across the bed.
- **koi.** A pond seen from above.
  - Each sounding motif is a fish swimming a slow loop at its own cycle, with a body that bends as it swims and a fading wake.
  - A note makes its fish flick, leaving a ring where it surfaced.
  - The chord shows as a few lily pads drifting in the current.
- **kelp.** Underwater.
  - Kelp fronds rise from the bottom and sway with heave (`out_lo`).
  - Notes release bubbles that rise and wobble from the pitch's column.
  - `out_hi` adds shafts of light from the surface. The bloom brightens the water.
- **fireflies.** A marsh at dusk: a calm, warm, gentle scene.
  - A tree and reed line along the bottom.
  - Fireflies drift on the current; each note lights one at its pitch, and it glows and fades slowly.
  - Their reflections sit in the water below. The sky gradient follows bloom.
- **mist.** Morning fog on the estuary.
  - Banks of dithered mist drift with the current over still water and a faint far shore.
  - Density follows `out_lo` and `nat_amp`; a swell thickens it.
  - Notes open small clear patches or show a post or buoy through the fog. A moment lets the sun break through briefly.
- **flock.** Birds over the mudflats.
  - A small flock (≤ 24 birds) moves with simple boids-style rules. It turns with the tide direction and shifts its spread with energy.
  - Each motif note makes a few birds bank or catch the light.
  - A swell lifts the flock higher. Below, the mudflat channels shine with the water level.

## Structure
`lib/visuals.lua` is already about 900 lines; twelve themes in one file is too many. The proposed split:
- `lib/visuals.lua` keeps the public API (`VIS.names`, `VIS.init`, `VIS.audio`, `VIS.event`, `VIS.draw`), the shared physics, the helpers (`put`/`flush`, `flow`, `heave`, `surface`, `glitter`, `ease`, `rnd`, and so on) and dispatch.
- Each theme lives in `lib/vis/<name>.lua`, loaded with `include("lib/vis/<name>")` (never `require`). Each returns a table such as `{name=, draw=function(S) end, on_note=..., init=...}` and takes the shared kit (helpers plus a read-only view of the physics state) through an explicit argument or setter, not through globals.
- The builder may adjust this shape. The constraints: no new globals, locals declared before use, and the public API unchanged so `estuary.lua` needs no change beyond what the theme count implies.
- `VIS.names` order: the six existing themes first, in their current order, so saved psets keep pointing at the same theme. The six new ones follow.
- The theme-cycle param and K1+E1 already use `#VIS.names`. Confirm that, and make sure the screen label still fits.
- The headless test stubs must make `include` resolve `lib/vis/*`.

## Robustness and tests
- Extend the existing per-theme matrix (`test/unit_visuals.lua`: silence, mid, peak, swell × lit ratio, non-blank, bounded frame diff, no NaN, rect budget, audio-reactivity) to all twelve themes, and keep it passing.
- Raise the mid-activity minimum lit ratio so a theme cannot regress to near-empty. A floor of around 4% is the guide; the builder can set the final value from observed values.
- Pick up the v2 test follow-ups from `docs/v1-followups.md` while here:
  - a variable-dt run for frame-rate independence
  - a speed-param test
  - out-of-range audio behaving like the clamped value
  - a tightened continuity bound
- Budget: on the norns screen calls are the cost. Keep batched fills, and keep each theme's per-frame rect count within about 1.5× the heaviest v2 theme. Dithered fills are made from few wide rects, not per-pixel calls, where possible.
- `SNAP` writes still/mid/loud PGMs for every theme. Produce a contact sheet so a human can look.
- `lua test/unit_visuals.lua`, `lua test/unit.lua` (or whatever the existing unit runner is), the 900-bar sim and `luac -p` on every Lua file must all pass.

## Docs
- README: describe all twelve themes in the visuals section. Say what each looks like and what moves it.
- No device names, IPs or key paths anywhere in the repo.
- No references to the artist who inspired estuary.
- Add a v3 section to `docs/v1-followups.md` for checks only the device can answer, such as CPU and visibility at low brightness.

## Left to the builder
Exact shapes, constants, dithering technique, sprite designs and per-theme rect budgets, all within the above.
