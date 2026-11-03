# estuary — design

*2026-11-02. A norns script, sibling to gradient (`~/dev/gradient`).*

## Intent

estuary plays a whole ambient set by itself, in the spirit of **Hiroshi Yoshimura**'s relaxing environmental music (*Music for Nine Postcards*, *Green*, *Air in Resort*). It uses small, singable melodies with a lot of air around them, bright consonant harmony, no drums, and the sound of water and nature woven in.

It's for **a set people sit and listen to**, not background for a room. So it needs a shape over time: a sparse arrival, slow blooming, a few moments that make people lean in, and a long settling.

The user lets it **ride mostly, with some steering similar to gradient**. Like gradient, it should be fully autonomous after you press play, with a small set of live controls for nudging it.

## Goals

- Endless **set mode**, plus a **track mode** of album-length pieces, both autonomous.
- Melodies that feel like Yoshimura: short motifs, repeated with slight variation, drifting in and out of alignment with each other.
- **Water swell**, the signature moment: a field recording rises up under the music, the music thins and softens, then the water recedes and the music returns subtly changed.
- The user's own **field recordings** drive the nature layer. Until they arrive, **CC0 placeholders from Freesound** fill in.
- Every melodic part has **internal / midi / both** output, as in gradient.
- gradient-style steering: encoder pages, K2/K3 actions, grid, PERFORM triggers for MIDI mapping.

## Anti-goals (hard rules; failing these fails the project even if everything works)

1. **Never busy.** Even at full bloom, no more than **3 motifs sound at once**. A motif is **3–7 notes with real rests**; silence is part of the phrase. Nothing faster than **8th notes**; most notes are quarters or slower. A mutation changes **one** thing at a time. No fills, runs, arpeggio flurries or ornaments.
2. **Never dark.** Only pleasant, relaxing modes (list below). Only warm chord colours: major, add9, 6/9, sus2, maj7 and quartal, plus **soft minor chords (vi, iii, dorian's i, a passing iv) when voiced open and warm** (m7, m9, m11-without-the-3rd-on-top, open 5th+9; never a bare close minor triad in the low-mid register). No minor-key dread, no dissonant clusters, no long-held semitone rubs. Timbres are soft and warm, with no grit, distortion, detuned menace or dub saturation. The echo and reverb are clean and spacious.

## Constraints

- Platform: **norns**, a Lua script plus its own SuperCollider engine `lib/Engine_Estuary.sc`. Runs on any norns; new engines need **SYSTEM > RESTART**.
- Load lib files with `include("lib/foo")`, not `require`.
- Never deploy test-only `.sc` files (a CroneEngine stub in dust → DUPLICATE ENGINES). Keep stubs non-`.sc` and rsync with `--exclude test`.
- SynthDef args must not collide after `t_` stripping (`t_gate` + `gate` = silent failure).
- Declare shared `local` state at the top of its section, before any handler references it.
- Clock: follow the norns clock, so Link and MIDI clock sync work from the system menu.

## Decided by the user

| topic | decision |
|---|---|
| reference | Hiroshi Yoshimura, relaxing works |
| use | a set people sit and listen to |
| hands | let it ride mostly, with gradient-like steering |
| the "moment" | a field-recording swell, "like water coming in" |
| modes | every option must be pleasant and relaxing |
| nature sounds | the user's own recordings; Claude sources placeholders |
| outputs | internal / midi / both per part, like gradient |
| wince list | busy melodies; anything dark-sounding |
| name | **estuary** |
| minor chords | soft minor chords allowed if voiced warm |

## Claude's calls (the user can overturn any of these)

### Architecture
Start from gradient's structure and re-voice it, rather than writing from scratch. Carry over the parts that fit the new world and **strip** what doesn't (kick, hats, rim, shaker, toms, pump, dub throws, fills, dusty kick, drop/break).

```
estuary.lua           main: params, screen, keys/encoders, clock loop
lib/Engine_Estuary.sc voices, nature-sample players, echo, reverb
lib/conductor.lua     bloom arc, part fades, motif mutation, water swells
lib/motifs.lua        (from gen.lua) motif generation + mutation
lib/harmony.lua       (from gradient) voice-leading, bright-only tables
lib/theory.lua        bright modes, chord shapes
lib/nature.lua        sample folders, picking, swell scheduling
lib/outs.lua          midi/crow/cc out (from gradient)
lib/listen.lua        input key-follow (from gradient), folded to bright modes
lib/gridui.lua        grid (re-laid out)
lib/visuals.lua       estuary's own themes
test/sim.lua          headless sim + rule checks (see Testing)
```

### Bloom (replaces gradient's energy)
One slow value, 0 to 1, called **bloom**. It controls:
- how many motifs are active (low bloom: 1; middle: 2; top: 3; **never more than 3**)
- how long the rests are (low bloom: long gaps, up to several bars of silence per motif cycle)
- pad presence (absent at the lowest bloom; a soft sustained chord as it rises)
- timbre brightness (a gentle filter opening; never harsh)
- a soft low pedal note at mid-to-high bloom only, a sine or a soft Rhodes low C. **No bass line.**

Parts fade over about 4–8 bars, much slower than gradient.

### Motifs (replace gradient's arp lanes)
- Up to **4 motif slots**, but the conductor allows at most 3 to sound. Each is a short melodic phrase: 3–7 notes plus rests, with an **odd total cycle length** in beats (e.g. 7, 9, 11, 13) so the motifs drift against each other the way tape loops do.
- Notes are written as **scale-degree / chord-tone indices**, so the motifs follow the harmony, as gradient's lanes do. They favour stepwise motion and small leaps, and sit in a singable range of about an octave.
- Rhythm uses quarters, halves, dotted values and occasional 8th pairs, never runs of 8ths.
- Each motif is assigned a voice (below) and a register, and the slots spread across registers.
- Mutation on phrase edges: **one** change per motif at most: swap one note, lengthen or shorten one rest, or rotate. Rarely, a motif is retired and a new one is written.
- Each new motif gets a short "introduction". It plays alone or with only one other motif for its first cycle or two, so the listener can hear it before the texture fills in.

### Harmony
- Reuse gradient's voice-leading engine and drifting morphs, but much slower: a chord holds for **8–32 bars**, and in calm stretches it can hold for minutes.
- Progressions: short loops of 2–4 chords that are gentle and mostly diatonic: I–IV, I–vi–IV, I–iii–IV, IV–I, I–II (lydian), I–bVII (mixolydian), i–IV (dorian). The only borrowed colour is a soft **IV→iv** now and then. Nothing outside that.
- Voicings: maj7, add9, 6/9, sus2, quartal, and open fifths with a 9th. Low bloom picks the most open shapes.
- **Semitone rule (Claude's call):** maj7 is always voiced **spread** (root and 7th never adjacent; the 7th sits above the root, a 9th or more away). In lydian, the #4 never sits directly next to the 5th in the chord. **Melody against chord:** a motif note a semitone above a chord tone (e.g. the 4th over I, or the root over a maj7 with the 7th on top) is an **avoid note**. It may only be a short, unaccented passing note (≤ one quarter at the current tempo) and never ends a phrase. The sim measures "passing" as ≤ 1 beat.

### Modes (pleasant only)
**ionian, lydian, mixolydian, major pentatonic, "Yoshimura" pentatonic** (major pentatonic plus the 4th and maj7 used only as passing tones), and **dorian** as the single soft-minor option. Nothing from gradient's dark list. New tracks mostly land on ionian, lydian or the pentatonics. Key changes on water swells move up or down a 4th or 5th.

### Voices (engine)
Four soft melodic voices, chosen per motif (auto by seed, or fixed per slot in SOUND):
- **rhodes**: an FM electric-piano tone with soft tines and slight tremolo
- **bell**: a gentle two-operator FM bell (a DX7 "glass" feel, not clangy)
- **sine**: a pure sine with a soft attack
- **marimba**: a soft mallet tone (a modal/resonant body)

Plus a **pad** (warm, slow-attack chord bed) and a **pedal** (a soft low sine). FX: a **clean stereo echo** (tempo-synced, filtered, no saturation; modest wow is allowed but kept subtle) and a **large soft reverb** (hall). There's no master pump or drive.

### Nature layer and the water swell
- Samples live on the norns in **`dust/audio/estuary/{water,birds,wind,room}/`**. The script scans the folders at load. Missing folders are fine, and their moments are simply skipped.
- **Always-on bed:** one file from `room` or `wind` at a low level, drifting slowly, in the same way as gradient's BED.
- **Water swell** (the big moment): a file from `water` fades up over ~8–16 bars to the front of the mix. While it's up, motifs thin to one (or none), the pad softens, and the filters close a little. Then the water recedes over ~8–16 bars, and the music returns **changed**: a new motif, a new progression, or a key move (a 4th/5th). It's used **1–2 times per set-mode cycle** and once in track mode at the "tide" section.
- **Passing moments** (small): a bird call or a wind gust from `birds`/`wind`, at most once every few phrases. They never stack with a water swell.
- Placeholders: about 8–12 **CC0** clips from Freesound. **Claude's call:** with no Freesound account, use the public HQ preview files (lossy, but fine for placeholders), converted with ffmpeg. Clips cover water/stream/shore, birdsong, wind and quiet room tone; they're trimmed, faded and normalized to −3 dBFS peaks, stored as 48 kHz WAV in `~/dev/estuary/audio/` (gitignored) and pushed to each norns with a separate `tools/push_audio.sh` rsync to `dust/audio/estuary/`. The repo holds `audio/SOURCES.md` (title, author, Freesound URL, license per file) and a `tools/fetch_placeholders.sh`. The repo does **not** commit large audio. The user's own recordings replace them by dropping files into the same folders.

### Arc
- **set (endless):** the bloom rises and settles over long cycles (roughly 20–40 minutes each), with a slow random walk on top. Each cycle has one or two water swells, and the deepest troughs can sit at bloom ~0.05 (one motif, lots of silence, water).
- **track:** a fixed arc over the track length (default **12 min**, range 6–30): *arrival* → *bloom* → *tide* (water swell) → *return* → *settling*. At the end it stops, or rolls into the next track with a new seed and a neighbouring key.
- **Tempo:** slow, default **72 BPM**, range 50–100. The phrase is 16 bars by default (options 8/16/32).

### Steering (my proposed mapping, modelled on gradient)
| input | action |
|---|---|
| K2 tap | **breathe**: thin to a single motif and the bed for the next 8 bars, then relax back |
| K3 tap | **tide**: start a water swell now (lands on the next bar) |
| K2+K3 | play / stop |
| hold K2 + E2/E3 | key / mode |
| hold K3 + E2/E3 | tempo / set ↔ track |
| hold K1 + E1 / E2 | visual theme / encoder page |

Encoder pages: **play** (bloom nudge · space (echo+reverb send) · tone), **nature** (bed level · swell level · moment frequency), **sound** (pad level · echo feedback · reverb size), **parts** (as in gradient: mute/solo strip). Every action is also a PERFORM trigger. The grid is re-laid out on gradient's model: phrase row, bloom row, parts row, motif rows 4–7, actions row 8.

### Outputs
- **internal / midi / both** for each of **motifs** (all on one channel, one motif, or one channel per motif, as in gradient's lanes), **pad/chords**, and **pedal**. The nature layer and FX stay internal.
- Carry over SYNC OUT (start/stop), CROW (lead pitch/gate, chord root, bloom as 0–5 V), and CC OUT (bloom, tone, phrase pulse) from gradient's `outs.lua`.
- Input key-follow (LISTEN) carries over, with its result folded onto the nearest bright mode.

### Visuals
estuary gets **its own themes**, ported from neither causeway nor gradient. There are about six, drawn from what the music is doing: e.g. **ripples** (each note drops a ring on still water), **horizon** (the chord as soft bands at the waterline, with the tide rising during a swell), **postcards** (each motif as a small framed card that lights when it plays), **rain** (notes as drops running down glass), **tide** (the bloom arc as a shoreline over time), **drift** (motif phase relationships as slowly orbiting points). Use gradient's `VIS.event`/`VIS.draw` pattern and its theme cycle/overlay params.

### Seeds
As in gradient: the seed fixes the material (motifs, progression, voice choices, the arc's dice), while moment-to-moment chance runs live.

## Testing (for the builder)
- `lua test/sim.lua` headless, as in gradient: checks the engine command arity against the `.sc` file, and **enforces the anti-goals as assertions** over a long run (e.g. 2 hours of set mode):
  - never more than 3 motifs sounding in any bar
  - no inter-onset interval within a motif shorter than an 8th
  - every motif has 3–7 notes and at least one rest
  - every chord's pitch classes come from the allowed modes, and its voicing is on the allowed list (minor chords only in their warm voicings); no semitone between adjacent upper voices held longer than a passing tone
  - water swells and passing moments never overlap
- `test/sc/run.sh` renders the real engine on the Mac (SuperCollider is installed), as in gradient.
- `SNAP=dir` renders each visual theme to a PGM for eyeballing.

## Left to the builder
Exact synthesis recipes, the exact probability tables, fade curves, grid button positions, sample-picking heuristics, screen layout details, the README, and the exact choice of placeholder clips (CC0 only). A local git repo at `~/dev/estuary`, with no GitHub remote until the user asks. An omigod site page is out of scope for v1.

## Out of scope for v1
Favourites/setlists, tape recording, tempo follow, an omigod works page, a GitHub remote.
