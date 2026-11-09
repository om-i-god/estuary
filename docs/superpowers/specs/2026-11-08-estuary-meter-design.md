# estuary meter: choosing a time signature

The user asked: "can we add the ability to manipulate time signature also? I want to be able to select 5/4".

## Today
The main loop steps every 8th note (`clock.sync(1/2)`). A bar is fixed at 8 steps (`S.step % 8`), which is 4/4: `bar_sec = beat_sec * 4`, the start syncs to 4 beats, and resume rounds to 8 steps.

Motif cycles are 7, 9, 11, 13 or 15 beats (`CYCLES = {14,18,22,26,30}` eighths, "2 x odd beats"). They phase gently against the bar on purpose. The chords, pad crossfade, phrases, nature, theme cycle, grid row 1 and MIDI/crow bar output all run once per bar.

## What to build
- **A `meter` param** in the PLAY or SET group:
  - options 3/4, 4/4, 5/4, 6/8, 7/8, with 4/4 as the default, at index 2
  - append-only from now on, so psets stay stable
  - also on the PARAMS screen and saved in psets
- **Bar length in 8ths:**

  | meter | 8ths | grouping |
  |---|---|---|
  | 3/4 | 6 | |
  | 4/4 | 8 | |
  | 5/4 | 10 | 3+2 beats |
  | 6/8 | 6 | 3+3 eighths |
  | 7/8 | 7 | 2+2+3 eighths |

  Every place that assumes 8 steps or 4 beats per bar uses the current bar length instead: the bar test in `play_step`, `bar_sec`, the start sync (sync to the bar's length in beats), resume rounding, and the visuals' `bar_sec` (already read from S).

  Anything counted in bars (phrases, harmony holds, track length in bars, the theme cycle every 8 bars) stays counted in bars. Track length is set in minutes, and the bar count must follow the bar's real duration.
- **Changing the meter during play** takes effect at the next barline and never cuts a note. The step counter re-anchors so the new bar starts cleanly.
- **The feel.** 5/4 should be audible, not just a moved barline:
  - **Gentle downbeat lean.** Notes landing on the bar's first step get a slight velocity lift, about +8%. Notes landing on the secondary group start get about +4%: beat 4 in 5/4 (3+2), the 4th eighth in 6/8, and the 3rd and 5th eighths in 7/8. Anything subtler is acceptable, and nothing more than that. The rule checker's velocity and busy limits still apply.
  - **Motif cycles that fit the meter.** When the meter is not 4/4, newly generated motifs may draw from extra cycle lengths that relate to the bar. In 5/4, for example, that means 10 or 15 beats (2 or 3 bars). Cycles are whole beats only, at least 7 beats and no more than 15. About half of new motifs use a bar-related cycle; the rest keep the odd phasing cycles. Mutations must preserve the cycle class (bar-fitting or phasing) and still respect the minimum.
  - The builder chooses the exact sets per meter.
- **4/4 stays exactly as now.** At 4/4 every seed's note stream (notes, pad, pedal, timings) must be byte-identical to main's. The new cycle draw must not consume `math.random` at 4/4. Test this against main the way the sounds work did.
- **Screen and grid:**
  - The screen's play page shows the meter next to the tempo (or wherever it fits).
  - Grid row 1 still shows the phrase position in bars.
  - The visuals' bar breath follows the real bar.
- **Outputs:** MIDI and crow bar outputs fire on the new barline. Clock pulses are unchanged, since they're beats.

## Tests
- Unit tests:
  - bar length per meter
  - a meter change lands on the next barline
  - the downbeat and group-start lean values
  - cycle sets per meter (all ≥7 beats, ≤15, whole beats)
  - mutation keeps the class
  - 4/4 identical to main for several seeds (`git show main:...` or a recorded fixture)
- The sim takes `METER=5/4` (and the others). `lua test/sim.lua 900 2 4` passes `RULES ok` in every meter.
- Bars per track are counted correctly against minutes.
- `luac -p` on every file. The full unit suite passes.

## Docs
- README: what `meter` does and what you hear: the lilt, phrases still in bars, changes landing on the barline.
- `docs/v1-followups.md`: listening checks per meter.
- Never write device names, IPs or key paths, or the name of the artist who inspired estuary.
