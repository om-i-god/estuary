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

## Sounds v2: on-device listening checks
Engine change: run SYSTEM > RESTART once before loading. The Mac checks (`test/sc/run.sh`) measure every voice and pad character alone and render one demo per palette; these are what only the device and ears can settle.
- Balance by ear: RMS matching is within 1 dB on the Mac, but the percussive voices (marimba, kalimba, celesta) peak about 10 dB above the sustained ones (flute, glass, sine). Listen for mallets poking out of the mix, or flute and glass sinking under the pad. Tune the per-voice GAIN constants in `lib/Engine_Estuary.sc`, then re-run `test/sc/run.sh` (it fails past 3 dB).
- Pads: the five characters sit within about 1.2 dB RMS. Strings and air peak a few dB higher than warm. Check that they don't swallow the motifs at high bloom, and check the air pad's breath at low chords.
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
