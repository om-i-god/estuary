# estuary v1: follow-ups

Built 2026-11-03. These are open items left after the final review.

## Check on the device (by ear or eye)
- Voice timbre: rhodes, bell, marimba, pad warmth. Listen for the allpass ringing metallic.
- The pedal release: the engine fades the old pedal over 2 s, and the rules stop watching it at once. When the pedal moves because it had no clean spot under the new chord, a brief rub may be audible. Fix by shortening that release to about 0.5 s.
- The pedal re-striking the same note every 4 bars: the overlap may swell or dip.
- Lydian II over the tonic pedal: it now drops an octave (or rests) instead of sitting a bare tritone below. Check it still sounds lydian.
- Motif registers (about MIDI 55–89, two registers) and the balance between the four slots.
- Placeholder levels: the quiet room tones are normalised to -3 dBFS like the rest, so they may need lowering in params. lake_shore has a faint cleat clang; songbirds_forest_brook has distant sheep.
- Visuals: CPU per theme.
- KeyTrack / LISTEN on real input; Link and MIDI clock sync.

## Code and tests
- The test `run.scd` doesn't check that a moment's old buffer survives a swap while its one-shot is still playing, or that a stale load is dropped.
- The "swap still works after a rotate" unit test is vacuous. Hand-build a motif with tones {1,2,3,5} (wrap leap 4) and assert every swap keeps the wrap at 3 or less.
- Smaller deferred items:
  - fetch script edge cases: CC0 grep not anchored to the license block; a clip under 2 s gets a negative fade start
  - push_audio aborts if a folder is missing
  - same MIDI channel for pad and pedal
  - set_bloom clamp
  - grid columns 15 and up
  - harmony morph double-step

## Visuals v2
- On the device:
  - Tune the 5 analysis gain constants in the engine so the visuals' 0..1 levels track the real output.
  - Check CPU, tide especially.
  - Below brightness 5, the faintest textures round to black.
- Tests:
  - Tighten the continuity bound (DIFF_MAX 0.5 against an observed max of about 0.25) and the minimum lit ratio for non-silent scenes.
  - Add a variable-dt run for frame-rate independence, and a speed-param test.
  - Assert that out-of-range audio behaves like the clamped value.

## Visuals v3
Built 2026-11-04: twelve themes, each in `lib/vis/<name>.lua`. The v2 test follow-ups above are done: a jittery-dt run, a speed-param test, out-of-range audio drawing exactly as the clamped value, the continuity bound tightened to 0.35 and a 4% lit floor for any scene with music.
- On the device:
  - CPU per theme, and whether `include` of twelve files at load is quick enough. The heaviest by draw calls are tide (peak) and kelp; reeds is the heaviest at rest.
  - The dim levels carry the atmosphere now (sky glows, far shores, fog). Check they still read below brightness 5, where level 1 rounds to black, and that the dithered skies don't shimmer or band on the real panel.
  - Whether the scanline skies read as skies at arm's length, and whether the silhouettes (tree lines, headland, reeds) are clear enough at the default brightness.
  - flock: that the boids settle into a calm flock on the real frame rate, not a jittery one.
  - mist: that the fog density follows the tuned out_lo / nat_amp gains (it was tuned against the sim's fake polls).
  - The theme name on the screen with K1 held: the longest is "fireflies 10/12".

## Visuals v4
Built 2026-11-05/06 (`docs/superpowers/specs/2026-11-05-estuary-visuals-v4-design.md`): every place gets a far, middle and near layer, three rare small happenings, the chord in the scene, slot-shaped note marks, a bar breath, a role for every poll and its own moment. The kit adds the hand-made stroke dither, baked static layers, the chord glide and the incident scheduler. Headless, Lua time per frame is about 1.1x v3 across the twelve (fireflies, ripples and koi run 1.3-1.4x at peak, postcards and reeds about 1.3x), and the peak draw calls are 700-1000 per frame (kelp and tide highest, under the 1100 budget).
- On the device:
  - CPU and frame rate per theme at a busy peak (three motifs, a swell, a moment, the polls high), especially kelp, tide, reeds and koi, which draw the most rects. If one drops frames, the first things to thin are the twinkle scatters (koi, kelp, flock) and the per-column work in tide.
  - The stroke dither: whether skies, sand and fog read as soft, hand-made texture on the real panel or as noise, and whether the strokes shimmer as the bloom moves (they should change a few at a time, never crawl).
  - The bar breath: a slow swell of light on each bar. Check it reads as breathing and never as a blink, at brightness 5 and 15.
  - Incidents: one every minute or two, three kinds per place, each easing in and out over about three seconds. Check they are noticed but never steal the picture, and that none is too small to see at arm's length (the warbler in reeds, the strider in drift and the dragonfly in koi are the smallest).
  - Lit area: several places sit at 32-35% lit at a full peak (rain, kelp, fireflies, flock, horizon). Check that peaks still feel calm, not busy, especially rain with drizzle, drops, a squall and the rainbow together.
  - The chord: that a chord change is visible but eased in every place (clouds, bands, hills, swells, pools, stars, swarms, fog layers, pads, shafts), and that the glide (about three seconds) suits the music's harmonic rhythm.
  - out_mid now has a clear job in every place; its gains were tuned against the sim's fake polls. Check it reads on real material (pad-heavy versus motif-heavy palettes).
  - Theme switch: the fade out is now 0.45 s (was 0.3) because the brighter scenes made the old cut too sharp.

## Sounds v2: on-device listening checks
Engine change: run SYSTEM > RESTART once before loading. The Mac checks (`test/sc/run.sh`) measure every voice and pad character alone and render one demo per palette; these are what only the device and ears can settle.
- Balance by ear: RMS matching is within about 0.6 dB on the Mac, but the percussive voices (marimba, kalimba, celesta) still peak about 9-11 dB above the sustained ones (flute, glass), even with their softened mallets (5 ms onsets, longer and rounder decays). Listen for mallets poking out of the mix, or flute and glass sinking under the pad. Tune the per-voice GAIN constants in `lib/Engine_Estuary.sc`, then re-run `test/sc/run.sh` (it fails past 3 dB).
- Pads: the five characters sit within about 2 dB RMS (it varies by a few tenths between runs, from their slow random drift). Strings and air peak a few dB higher than warm. Check that they don't swallow the motifs at high bloom, and check the air pad's breath at low chords.
- CPU: Mac NRT timings put the motif voices at about 0.8-1.3x the cost of the v1 marimba, and the pads at or under the v1 pad. Check the norns CPU readout on a busy stretch (three motifs, a pad crossfade, pedal, a swell) with each palette, especially shallows, mist and glasshouse.
- Voices that may sound off:
  - the rhodes tine ping at high bright on the top notes (glassy or harsh?)
  - the bell's slow stereo turn (seasick?)
  - the kalimba shimmer (too metallic?)
  - the vibes tremolo rate (3.4-4 Hz)
  - the flute and sine breath (should be barely there)
  - the glass swell on short notes (does it speak?)
- Palettes: play a few `new track`s in each mode. Each palette should feel like one record, and none should feel dark, busy or harsh. Check that pinning a palette in PARAMS > SOUND changes the sounds straight away and the pad on its next voicing.
- The pedal's slow level swell (0.11 Hz, plus or minus 4%): it should not read as a wobble.
- Old psets: load a pset saved with v1 and confirm the motif voices it chose (rhodes / bell / sine / marimba) still play.
