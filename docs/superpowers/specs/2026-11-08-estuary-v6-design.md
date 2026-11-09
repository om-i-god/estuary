# estuary v6: more places, more records, every place polished

The user's brief: "add even more sound themes and visuals themes and polish all the visuals".

v6 builds on v4/v5 visuals (`2026-11-05-estuary-visuals-v4-design.md`, `2026-11-08-estuary-v5-design.md`), sounds v2/v3 and meter (`2026-11-08-estuary-meter-design.md`). Every rule in those specs still holds:
- character: nothing dark, nothing busy, nothing harsh
- the visual budgets (≤1100 draw calls, ≤35% lit, no level 15 over wide areas), the v4 test matrix, caps and frame-time limit
- loudness matching (voices ±3 dB, pads ±3 dB), the onset rule, the CPU ceilings
- react=0 still nulls; the music's notes are unchanged (rules, seeds, the 4/4 fixture `test/fixtures/stream_4_4.lua`)
- lists only grow at the end, so old psets keep their places and sounds
- no device names, IPs or key paths, and never the name of the artist who inspired estuary, in any repo file

Two independent streams, each on its own branch: **A. visuals** and **B. sounds**.

## A. Visuals

### A1. Polish every place (first, before adding new ones)
All 22 existing places get a polish pass. "Polish" here means each place looks finished and deliberate on a 128×64 16-level OLED, at rest and under music, and that no artefact breaks the calm. The builder works place by place from a written audit:

1. Render each place with SNAP (still, mid, loud, mid-incident, mid-moment, and a short sequence of consecutive frames) into the session scratchpad, convert to PNG at 4× scale, and look at them.
2. Write `docs/v6-polish-audit.md`: for each place, what reads well and a list of concrete defects found. Defects to look for:
   - **Flicker and shimmer that isn't asked for:** single pixels toggling frame to frame in still areas, dither patterns crawling, aliasing on slow-moving thin lines.
   - **Pops:** anything appearing, vanishing, jumping or wrapping without easing (incidents, marks, chord changes, theme-cycle edges, meter changes of bar length).
   - **Composition:** dead empty regions, cluttered regions, elements clipped awkwardly at the edges, a horizon or subject that sits badly, silhouettes that don't read as what they are.
   - **Tone:** muddy mid-greys where a place should feel airy, levels that are too uniform (flat) or too contrasty, bloom that doesn't read as daylight, reflections that don't match what's above them.
   - **Texture:** ruled-looking rows, repeated stamps that read as tiles, dither that looks mechanical.
   - **Motion:** stutter at 20 fps, things that move at the same rate across depth layers (broken parallax), motion everywhere when the scene should be mostly still.
   - **Reactivity legibility:** inputs whose effect is technically measurable but you can't see by eye.
3. Fix every defect, then re-render and record the after state in the audit (one line per fix).

Shared improvements belong in `lib/visuals.lua` where several places benefit (for example a better ordered/noise dither helper, a sub-pixel line or soft-dot helper that removes crawl, a shared easing for wraps).

New tests that make polish stick, run for every place (old and new):
- **Still-area stability:** with silence and no incident, after warm-up, the fraction of pixels whose level changes by ≥3 between consecutive frames is small (builder sets the threshold from the polished state, it must catch a deliberately injected crawling dither in a self-test).
- **No hard pops under input:** the existing onset test extended to chord changes, theme-cycle edges, and a meter change (bar length 8 → 10 → 7 eighths) mid-run.
- All v4 tests keep passing, including reactivity ≥0.03 for every input; polish must not reduce any place's reactivity below that.

### A2. Six new places (twenty-eight in total)
Append to `VIS.names` after `confluence`, in this order. Each meets the full v4 bar: parallax layers, three rare incidents, bloom as daylight, hand-made dither, every input reacting visibly and distinctly, the full test matrix. All are daylit or softly lit; none dark.
- **delta.** A braided river delta seen from high above at golden hour: silver channels splitting and rejoining across sandbars on the way to the sea. Notes are light running down a channel at their pitch's column; the chord is the main channels' brightness; `nat_amp` is the shimmer of the shallows; a swell is the tide pushing back up the channels. Incidents: a flock of shorebirds wheeling, a cloud shadow crossing, a small boat's wake.
- **onsen.** A hot spring among snowy rocks: a steaming pool, snow on the stones, a soft winter sun. Steam rises and curls with `out_mid`; notes are drops falling from an overhanging branch, rippling the pool at their pitch's place; the chord is the warm light on the water; a swell is a gust that clears the steam then lets it gather. Incidents: snow sliding off a branch, a bird landing on a rock, a lantern being lit at dusk (warm, not dark).
- **lotus.** A lotus pond from just above the water: round leaves, buds and flowers. Notes open a flower (slot picks bud, half-open, full); the chord is a set of the largest leaves catching light; `out_lo` rocks the leaves; `nat_amp` is dragonfly-wing shimmer and small rings. Incidents: a frog leaping between leaves, a dragonfly settling, a petal falling.
- **glacier.** A bright glacier face above a calm meltwater lake under a pale blue day. Notes are icicles dripping and meltwater runnels lighting; the chord is the ice's blue bands; `out_lo` is the lake's slow swell; a swell is a gentle calving that sends a soft wave across (eased, never a crash). Incidents: a drifting iceberg, a tern, sun breaking through cloud onto the ice.
- **pod.** The open sea from a headland on a bright day, with a pod of whales passing far out. Notes are spouts and fluke glints along the horizon at their pitch's place; the chord is sun paths on the sea; `out_lo` is the swell; `nat_amp` is whitecaps. Incidents: a breach (slow, eased), a sailboat, gannets diving.
- **wellspring.** A clear woodland spring seen from above: water welling up through sand, making small boiling sand-rings, with ferns and roots at the rim. Notes are sand-boils blooming at their pitch's place; slot picks the size; the chord is the light spots through the canopy; `out_mid` sways the ferns; `nat_amp` is leaf flicker. Incidents: a leaf spinning down onto the surface, a water strider skating, a newt.

All are stylised, no text. The K1 label fit must hold for the longest label, "wellspring 28/28".

### A3. Docs
README visuals section: the six new places, input by input, in the existing compact form. `docs/v1-followups.md`: a v6 device-check section (frame time on the Pi for the new places, how polish reads on the real panel).

## B. Sounds

### B1. More voices (appended to `P.VOICES` and the engine's voiceDefs, in this order)
Same late-80s soft-gear world; loudness-matched, click-free onset, within the CPU ceiling, nothing harsh.
- **ocarina.** A round, breathy vessel flute with a soft chiff.
- **bowl.** A singing-bowl strike with slow beating partials and a very long ring (bright, never ominous; keep partials consonant enough).
- **musicbox.** A tiny comb tine, soft and sweet, a little detuned per note.
- **chime.** A soft tubular/wind chime, rounder than bell.

### B2. More pads (appended to `P.PADS`)
- **hum.** A wordless closed-mouth choir pad, very soft.
- **bowed.** Bowed glass or bowed vibraphone: a slow swell with a pure, glassy sustain.

### B3. More palettes (sound themes)
Add six palettes, each a plausible single record built around the new sounds (mixing in older ones), bringing the total to 26. Names must not clash with any place name (including the six new ones). Use: **pavilion, conservatory, observatory, arboretum, aquarium, gallery**. The auto bag cycles all 26 and still never repeats back to back; pinning works for the new ones.

### B4. Tests
- `test/sc/run.sh` / `sounds.scd`: the new voices and pads loudness-matched, no NaN, no clipping, the onset rule, react null at 0, no runaway; palette demos rendered for the six new palettes into the session scratchpad.
- Lua: old pset indices unchanged; palette choice seeded and never back to back; the 900-bar sims (`900` and `900 2 4`) hear all 22 voices; rules selftest; the 4/4 fixture still byte-identical; `luac -p` on every file.

### B5. Docs
README: the new voices, pads and palettes. `docs/v1-followups.md`: a sounds v4 listening-check section (CPU with bowl and bowed on the Pi).
