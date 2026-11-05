# estuary

a generative ambient set for norns. press play and let it ride.

estuary plays small melodies, slow bright chords, a low pedal note and a lot of air, and every so often the sound of water comes in. it runs by itself for as long as you leave it. you can steer it, but you don't have to.

the melodies, pad and pedal can also go out over USB MIDI or crow, each one: **internal**, **midi**, or **both**.

---

## what you hear

**motifs.** four short phrases, each a handful of notes and rests with its own odd-length cycle, so they drift in and out of phase with each other. each note is a step on a ladder of the current chord's own tones laid out close together (in the pentatonic modes only the ones the pentatonic allows; when that leaves fewer than four, a mode tone fills the widest gap), so a step is the next chord tone up or down, a motif stays within about an octave, and the melody always sits inside the harmony. a note held longer than a beat never sits a semitone right above a pad note. now and then a quick neighbour tone passes between two notes. up to three motifs sound at once, and they fade in and out over several bars. the four take turns: the one that has rested longest comes in next, and when the texture is full, every couple of phrases the longest-playing one makes way for one that has rested two phrases. each motif has a voice: **rhodes**, **bell**, **sine** or **marimba** (set to **auto** and the seed picks).

**pad.** a four-note chord that crossfades slowly whenever the harmony moves. it opens up as the bloom rises.

**pedal.** a soft low note under the chord. it plays in the middle and upper bloom (not at the very top) and holds the key's tonic through the calm sections, so the chords move above it. it sits at least a 4th below the pad, never a semitone (or a major 7th) from a chord note or a bare tritone under one; when it can't sit clear of a chord, it rests.

**bloom.** everything hangs off one slow value from 0 to 1. at the very bottom one motif plays alone over the bed, with no pad. as it rises the pad fades in, a second and a third motif join, and the pedal arrives. the bloom decides who plays, how bright the notes are and how much echo and reverb they get.

**harmony.** one key and one mode, with chords that hold for 8 to 32 bars (twice that, up to 64, while the bloom is low). every new chord is voice-led: each voice moves to the nearest note of the next chord, and every voicing is spaced so no two notes sit a semitone apart. no chord ever carries a tritone or a flat 9th over its root; iii in ionian is always a plain m7. three ways to move (PARAMS > KEY > harmony):

- **simple:** a pair of chords alternating.
- **rich:** loops of two to four chords.
- **drifting** (default): rich, plus each chord morphs into the next one voice at a time, so the in-between chords are heard too.

chord voicing is set by the bloom when on **auto**: open (5th + 9th), quartal (stacked 4ths over the chord: C becomes E A D G) and sus2 shapes when it is low; add9, 6/9 and rootless m9 in the middle; maj7, 6/9 and add9 at the top. or pick one shape by hand. the screen shows the chord as a roman numeral, and `IV/I` means IV over a tonic pedal.

**modes.** six, all bright: ionian, lydian, mixolydian, major pentatonic, passing pentatonic (pentatonic with the 4th and 7th allowed as passing tones) and dorian. new tracks and key moves drift between them, favouring ionian, lydian and passing pentatonic. set the mode by hand (hold K2 + E3) to go anywhere.

**water.** a swell of water comes in: a recording from the `water` folder fades up over 8 to 16 bars, holds for 4 to 8, and fades away over 8 to 16. while it is in, one motif plays, the pad and pedal soften and the tone closes a little. halfway through the fade-out the music changes once: the next motif due to come in is rewritten (so the first motif heard as the water leaves is new), a new chord progression starts, or the key moves. swells arrive on their own once or twice per cycle, or when you press **tide**.

**moments.** a short recording from the `birds` or `wind` folder passes by, fading away within four bars, every few phrases. it never overlaps a swell. **moments** (PARAMS > NATURE) sets how often: off, rare or some.

**bed.** a recording from the `room` folder (or `wind` if there is no room) loops quietly under everything while it plays, fading in over a few seconds.

**two modes.**
- **set (endless):** the bloom swells and falls over a cycle of 20 to 40 minutes, with a slow random walk on top. the screen shows `trough` or `swell`. at the bottom of the cycle the music is nearly bare.
- **track:** a fixed arc over the track length (default 12 min): **arrival** → **bloom** → **tide** (with a water swell) → **return** → **settling**. the screen shows the section and how far through the track it is (`bloom 40%`). at the end it either stops or rolls into a new track with a new seed and sometimes a new key; after a stop, K2 + K3 starts that next track.

the first time estuary loads it sets the norns clock to 72 bpm; after that the tempo is yours.

---

## controls

| input | action |
|---|---|
| **E1 / E2 / E3** | the current page (below) |
| **K2 tap** | breathe: thin out to a single motif for 8 bars, then relax back |
| **K3 tap** | tide: bring the water in (if a moment is passing, the swell comes as soon as it is over) |
| **K2 + K3** | play / stop (starts on the next bar) |
| **hold K2** + E2 / E3 | key / mode |
| **hold K3** + E2 / E3 | tempo / set ↔ track |
| **hold K1** + E1 | visual theme |
| **hold K1** + E2 | encoder page |

a tap is a quick press: hold K2 or K3 longer than about half a second, or turn an encoder while it is down, and letting go does nothing.

**encoder pages**

| page | E1 | E2 | E3 |
|---|---|---|---|
| play | bloom nudge (relaxes back over a few bars) | space (echo + reverb) | tone |
| nature | bed level | swell level | moments (off / rare / some) |
| sound | pad level | echo feedback | reverb size |
| parts | bloom nudge | pick a part | that part's level |

the page name shows under the chord when you're off the play page.

**parts page.** a strip of every part (`1 2 3 4 P L`: the four motifs, the pad, the pedal) with the picked one underlined. here **K2** mutes / unmutes the picked part and **K3** solos it (soloed parts are boxed, and more than one can be soloed). K2 + K3 still plays / stops. a mute lands at once; the other parts keep their usual fades.

**actions.** besides breathe and tide, **mutate** changes the motifs now (each sounding motif has an even chance of one change, and rarely the oldest resting motif is replaced by a new one, heard when its turn comes) and **new track** starts a fresh seed and mode. all five actions are triggers in **PARAMS > PERFORM**, so you can map them to a MIDI controller (PARAMS > MAP).

## grid

| row | |
|---|---|
| 1 | phrase position (dim marks every 8 bars) |
| 2 | bloom: lit to the current level; press anywhere to pull it there (it relaxes back over the next bars) |
| 3 | parts: cols 1-4 motifs, 6 pad, 7 pedal, 9 bed, 10 swell, 11 moment. brightness = how loud; press to mute / unmute |
| 4-7 | motifs 1-4: one column per event, bright = a note, dim = a rest, with the playhead brightest. press an event to flip it between note and rest (a motif keeps 3 to 7 notes and at least one rest). col 15 mutes the motif, col 16 replaces it with a new one |
| 8 | 1 breathe · 2 mutate · 3 tide · 14 new track · 16 play / stop |

screen: key and mode top left with the chord below, section top right (with `~` while the water is in), the bloom bar bottom left and part lights bottom right (`1 2 3 4 P L`).

---

## params

- **ESTUARY:** play mode (set / track), phrase length (8, 16 or 32 bars), track length (6-30 min), track end (stop / next track), freeze material (stop mutations, the arc still runs), seed, rebuild from seed, new random track
- **PERFORM:** play / stop, breathe, tide, mutate, new track now
- **KEY:** root, mode, harmony (simple / rich / drifting), chord voicing (maj7, add9, 6/9, sus2, quartal, open, rootless9, or auto by bloom)
- **MIX:** space (echo + reverb), tone, echo time (1/8, 1/4, 3/8, 1/2), echo feedback (held to 0.6 at 1/8), reverb size, level
- **NATURE:** bed level, swell level, moments (off / rare / some), moment level, nature tone
- **LEVELS:** motif level, pad level, pedal level
- **SOUND:** motif 1-4 voice (auto, rhodes, bell, sine, marimba)
- **LISTEN:** follow input key, input gate (dB), hold before move (s)
- **MOTIF OUT / PAD OUT / PEDAL OUT:** output (internal / midi / both), midi device, midi channel (defaults: motifs ch 3, pad ch 2, pedal ch 1)
- **MOTIF OUT > motifs to midi:** all four on one channel, a single motif (for a mono synth: the others keep playing on norns), or each motif on its own channel. velocity follows the part's fade and the note length follows the note
- **SYNC OUT:** a midi device to send start / stop to, on the bar the music begins and when it stops. the clock itself comes from norns: **PARAMS > CLOCK > midi out**
- **CROW:** four outputs, each assignable to lead pitch, lead gate, chord root, bloom (0-5V), pedal pitch or pedal gate. pitches are 1V/oct with C3 at 0V, gates 8V. **lead motif** picks which motif drives the lead outputs (0 = any), **pitch slew** adds glide, **pitch octave** shifts every pitch output
- **CC OUT:** a midi device and channel (default 16) for the arc as CCs: bloom cc, tone cc, and a phrase pulse cc (127 on the first bar of each phrase, then 0). a cc number of 0 is off. sent once a bar, only when the value changes
- **VISUALS:**
  - **theme:** twelve quiet places, each drawn from what the music is doing and from what the engine hears of its own output. the same water runs under all of them. a slow current flows out to sea while the bloom rises and back in while it falls, and a swell pushes it inland. sound strengthens it, the low end adds a long slow heave, and the top end scatters a few short-lived glints across the water. dim greys make the atmosphere of each place (sky, far shores, mist, water texture), and the brighter levels are kept for what the music is doing. the picture keeps moving gently through silence, notes ease in, and a theme change fades through black.
    - **ripples:** a still pond under a dark tree line, the evening sky lying in the water. each note drops a ring where its pitch is, in its motif's band, smaller further away. the rings drift with the current, glow softly where they cross, bend the reflection as they pass and stay bright while the reverb tail rings. echoes follow at the echo time. two lily pads drift on the current and bob as rings pass under them; the sky glows brighter as the bloom opens.
    - **horizon:** open water to a low sun, a dark headland on the left. the sky glows over the line, brighter with the bloom, with a few far stars while it is low. the waterline is a layered wave whose height and roughness follow the low end and the water sounds, rising with a swell. the chord voices are soft bands beneath it, refracted by the same wave, and the sun throws a glittering path down the water that widens and quickens with the top end. a passing moment crosses the sky as a bird.
    - **postcards:** four windows onto the same estuary from four spots along it: a sandy shore with the wash running up it, open water with a far sail, a reed bank, and the rocks at the mouth with the swell breaking round them. each has its own small sky and water, with chop from the sound. a motif's notes light its window: the last note hangs in that sky at its pitch, with its path on the water, and the frame brightens. a caption under each window shows where its motif is in its cycle.
    - **rain:** soft rain over a far tree line under a pale sky, low cloud drifting over and a grassy bank coming down on the right. notes fall as drops from their pitch, long notes slowly, slanted by the wind of the current. a fine drizzle comes and goes with the top end. the water heaves with the low end and each drop rings it, and a band of mist over the water rises with the low end.
    - **tide:** a beach from the dunes, the sea above and the sand below. the last 80 bars of bloom make the shoreline, scrolling smoothly. at the live edge, waves wash up the sand and draw back, as far as the sound carries them, with a lace of foam at their front that glitters with the top end and a wet sheen left behind as they drain. a swell floods the whole beach. two small shore birds keep just ahead of the wash, running when it comes and pecking while it draws back.
    - **drift:** a pool seen from above between two grassy banks, turning in four slow eddies. each motif is a leaf carried round its eddy at its cycle length, a wake opening behind it, and petals ride the eddies more slowly. the eddies wobble with the low end and precess with the current, their paths a shimmer that runs round with the water. a shimmering dotted line joins two leaves when their phases line up.
    - **reeds:** a reed bed at the water's edge against an evening glow, in three layers: a low far bank, a middle bed and a few tall reeds close by with seed heads and long blades. every stem sways with the current and the heave, and sound bends them further; a swell sends a slow wave of bending across the bed. a note makes the reed nearest its pitch nod, and a longer note sends a dragonfly hovering past at that column. the water below holds the glow and the near reeds' broken reflections.
    - **koi:** a garden pond from above with stones round its rim. each motif is a fish swimming a slow loop of its own, one loop every four of its cycles, its body bending as it swims and a wake fading behind it; a quiet motif's fish sinks deeper and dims. a note makes its fish flick its tail and leaves a ring where it touched the surface. the chord floats as lily pads drifting on the current, bigger for lower notes, and one of them flowers as the bloom opens. light catches the pads' rims with the top end.
    - **kelp:** under the water in a kelp forest. the surface glows overhead, brighter as the bloom opens, the light fading with depth to a sandy floor. fronds rise from the floor and sway with the heave of the low end and the current, their blades turning with it. notes release bubbles that wobble up from the pitch's column, and the top end lets slanting shafts of light down from the surface. a small school of fish turns slowly in the middle water.
    - **fireflies:** a marsh at dusk. the last light glows over a dark tree line, warmer as the bloom opens, with a few first stars, reeds at the water's edge and the glow lying in the still water. a few fireflies always drift faintly on the current; each note lights one at its pitch, and it glows and fades slowly. every firefly shows again in the water, dimmer and wavering with the heave.
    - **mist:** morning fog on the estuary. a faint far shore and a pale sun sit behind banks of mist that drift with the current over still water. the fog thickens with the low end and the water sounds, and a swell rolls more in. each note opens a small clear patch at its pitch, showing a post or a buoy standing in the water there. a passing moment lets the sun break through for a while, thinning the fog and laying its path on the water.
    - **flock:** a flock of eighteen small waders over the mudflats, under a pale sky with a far shore. the flock keeps together by simple rules (stay close, match your neighbours, don't crowd), drifts the way the tide is turning, spreads wider as the sound grows and rises with a swell. each note makes a bird or two near its pitch bank and catch the light. below, channels wind across the mud and widen and shine as the water rises with the water sounds, a swell and the bloom.
  - **theme cycle:** off / every 8 bars / every phrase / each track; jumps to a random other theme
  - **overlay:** full / minimal (key and chord only) / off (just the picture, plus held-key hints and messages)
  - **speed, brightness**

**listening.** with **LISTEN > follow input key** on, estuary tracks the key of whatever is coming into the norns inputs. the engine runs SuperCollider's `KeyTrack`, and the script turns that into a decaying vote where a major key counts for its relative minor, since they share the same notes. estuary keeps the mode you're in and moves its root onto the heard notes: hearing A minor puts ionian on C, lydian on F, dorian on D. a new key has to lead the vote for **hold** seconds (default 10) with a clear share before estuary moves. quiet input below the **gate** (default -45 dB) doesn't vote, so the key holds through silence. while following, the music's own key moves (swell changes, next-track shifts) are left to the input.

**seeds.** a seed fixes a track's material: the motifs, the progression, the hold lengths. the moment-to-moment dice (which notes land, when mutations arrive) run live, so a rebuilt seed is the same track played a different night.

**clock.** estuary follows the norns clock, so Link / MIDI clock sync works from the system CLOCK menu, and transport start/stop is honoured.

---

## your own recordings

estuary reads sound files from four folders under `/home/we/dust/audio/estuary/`:

| folder | used for |
|---|---|
| `water/` | the swells (streams, shores, rain) |
| `birds/` | passing moments |
| `wind/` | passing moments, and the bed if there is no `room/` |
| `room/` | the bed: room tone, air |

drop in `.wav`, `.aif`, `.aiff` or `.flac` files (mono or stereo; extra channels are ignored). each file is loaded whole into memory, so keep them to 90 seconds or less. files starting with a dot (the `._` copies a Mac leaves behind) are skipped. each swell, moment and bed picks a file at random from its folder, so more files means more variety. the folders are read when the script loads, so reload the script after adding files.

the repo doesn't include audio. `tools/fetch_placeholders.sh` (needs ffmpeg) fetches a set of CC0 field recordings from Freesound into `audio/`; they are credited one by one in `audio/SOURCES.md`. they are there to get you started; replace them with your own.

## install

copy the folder to `~/dust/code/estuary/` on norns, without `test/`, `docs/`, `tools/` and `audio/`. it ships its own engine (`lib/Engine_Estuary.sc`), so after the first install, and after any update that touches the engine, run **SYSTEM > RESTART** before loading the script.

then put the recordings in place: run `tools/fetch_placeholders.sh` first if `audio/` is empty, then `tools/push_audio.sh <norns-host>` copies the four folders from `audio/` to `/home/we/dust/audio/estuary/`, or copy your own files there by hand.

## dev

- `lua test/unit.lua test/unit_*.lua` runs the unit tests (run from the repo root). `test/unit_visuals.lua` draws every theme through silence, a mid texture, a peak and a swell into the rasterizer, and checks how much of the screen is lit, frame-to-frame change, the draw-call budget, NaN, motion at silence, reaction to the top and low bands, and bad input. `VISREPORT=1` prints its numbers.
- `lua test/rules_selftest.lua` checks the music-rules checker itself.
- `lua test/sim.lua [bars] [mode 1=set 2=track] [minutes] [tempo]` runs the script headless against stubbed norns APIs, prints the arc every 100 bars, and ends with `RULES ok` or a list of rule violations (exit 1). examples: `lua test/sim.lua 2160 1` (two hours of set), `lua test/sim.lua 900 2 12` (a 12-minute track). `MUTES=1` toggles random mutes and solos each bar, `HKEY=1` makes random hand key and mode changes, `RESTART=1` sets track end to stop and restarts after each stop, `SEED=n` replays a run, `SNAP=dir` renders each visual theme to a PGM in `dir` through a small rasterizer (`test/raster.lua`), plus `_still` (the engine's ears silent) and `_loud` (ears pinned) versions. the sim feeds fake output polls from the music every 8th.
- `test/sc/run.sh` compiles `lib/Engine_Estuary.sc` against a stub CroneEngine, boots a local SuperCollider server, fires every command (including a nature load and play in the same tick for each slot), checks the output polls (`out_amp` rises with a note and falls back after its tail; `nat_amp` rises with nature) and renders a wav; it exits 1 if any check fails (needs SuperCollider.app on the Mac).

## license

MIT
