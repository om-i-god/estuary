# estuary

a generative ambient set for norns, in the spirit of Hiroshi Yoshimura. press play and let it ride.

estuary plays small melodies, slow bright chords, a low pedal note and a lot of air, and every so often the sound of water comes in. it runs by itself for as long as you leave it. you can steer it, but you don't have to.

the melodies, pad and pedal can also go out over USB MIDI or crow, each one: **internal**, **midi**, or **both**.

---

## what you hear

**motifs.** four short phrases, each a handful of notes and rests with its own odd-length cycle, so they drift in and out of phase with each other. the notes come from a pentatonic-leaning set and are chosen relative to the current chord, so they always sit inside the harmony. now and then a quick neighbour tone passes between two notes. up to three motifs sound at once, and they fade in and out over several bars. the lowest free slot enters first. each motif has a voice: **rhodes**, **bell**, **sine** or **marimba** (set to **auto** and the seed picks).

**pad.** a four-note chord that crossfades slowly whenever the harmony moves. it opens up as the bloom rises.

**pedal.** a soft low note under the chord. it enters in the middle of the bloom and holds the key's tonic through the calm sections, so the chords move above it.

**bloom.** everything hangs off one slow value from 0 to 1. at the bottom, one motif and the pad are quiet in the air. as it rises a second and a third motif join, and the pedal arrives. the bloom decides who plays, how bright the notes are and how much echo and reverb they get.

**harmony.** one key and one mode, with chords that hold for 8 to 32 bars. every new chord is voice-led: each voice moves to the nearest note of the next chord, and every voicing is spaced so no two notes sit a semitone apart. three ways to move (PARAMS > KEY > harmony):

- **simple:** a pair of chords alternating.
- **rich:** loops of two to four chords.
- **drifting** (default): rich, plus each chord morphs into the next one voice at a time, so the in-between chords are heard too.

chord voicing is set by the bloom when on **auto**: open, quartal and sus2 shapes when it is low; add9, 6/9 and rootless m9 in the middle; maj7, 6/9 and add9 at the top. or pick one shape by hand. the screen shows the chord as a roman numeral, and `IV/I` means IV over a tonic pedal.

**modes.** six, all bright: ionian, lydian, mixolydian, major pentatonic, yoshimura (pentatonic with the 4th and 7th allowed as passing tones) and dorian. new tracks and key moves drift between them, favouring ionian, lydian and yoshimura. set the mode by hand (hold K2 + E3) to go anywhere.

**water.** a swell of water comes in: a recording from the `water` folder fades up over 8 to 16 bars, holds for 4 to 8, and fades away over 8 to 16. while it is in, one motif plays, the pad and pedal soften and the tone closes a little. halfway through the fade-out the music changes once: a motif is replaced, a new chord progression starts, or the key moves. swells arrive on their own once or twice per cycle, or when you press **tide**.

**moments.** a short recording from the `birds` or `wind` folder passes by, a few bars long, every few phrases. **moments** (PARAMS > NATURE) sets how often: off, rare or some.

**bed.** a recording from the `room` folder (or `wind` if there is no room) loops quietly under everything while it plays, fading in over a few seconds.

**two modes.**
- **set (endless):** the bloom swells and falls over a cycle of 20 to 40 minutes, with a slow random walk on top. the screen shows `trough` or `swell`. at the bottom of the cycle the music is nearly bare.
- **track:** a fixed arc over the track length (default 12 min): **arrival** → **bloom** → **tide** (with a water swell) → **return** → **settling**. at the end it either stops or rolls into a new track with a new seed and sometimes a new key.

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

**encoder pages**

| page | E1 | E2 | E3 |
|---|---|---|---|
| play | bloom nudge (relaxes back over a few bars) | space (echo + reverb) | tone |
| nature | bed level | swell level | moments (off / rare / some) |
| sound | pad level | echo feedback | reverb size |
| parts | bloom nudge | pick a part | that part's level |

the page name shows under the chord when you're off the play page.

**parts page.** a strip of every part (`1 2 3 4 P L`: the four motifs, the pad, the pedal) with the picked one underlined. here **K2** mutes / unmutes the picked part and **K3** solos it (soloed parts are boxed, and more than one can be soloed). K2 + K3 still plays / stops. a mute lands at once; the other parts keep their usual fades.

**actions.** besides breathe and tide, **mutate** changes the motifs now (each sounding motif has an even chance of one change, and rarely the oldest is replaced by a new one) and **new track** starts a fresh seed and mode. all five actions are triggers in **PARAMS > PERFORM**, so you can map them to a MIDI controller (PARAMS > MAP).

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
- **MIX:** space (echo + reverb), tone, echo time (1/8, 1/4, 3/8, 1/2), echo feedback, reverb size, level
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
  - **theme:** six quiet ones, each drawn from what the music is doing:
    - **ripples:** each note drops a ring where its pitch is, in its motif's band; echoes follow at the echo time
    - **horizon:** the chord voices as soft bands under a waterline that rises with a swell
    - **postcards:** four small frames, one per motif, lighting when it plays
    - **rain:** notes as drops sliding down from their pitch; long notes fall slowly
    - **tide:** the last 80 bars of bloom as a shoreline; swells leave wet sand
    - **drift:** each motif a point orbiting at its own cycle length, a line joining two when their phases line up
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

drop in `.wav`, `.aif`, `.aiff` or `.flac` files (mono or stereo). each swell, moment and bed picks a file at random from its folder, so more files means more variety. the folders are read when the script loads, so reload the script after adding files.

the repo ships placeholder recordings in `audio/`. they are CC0 field recordings from Freesound, credited one by one in `audio/SOURCES.md`, and were fetched with `tools/fetch_placeholders.sh` (needs ffmpeg). they are there to get you started; replace them with your own.

## install

copy the folder to `~/dust/code/estuary/` on norns, without `test/`, `docs/`, `tools/` and `audio/`. it ships its own engine (`lib/Engine_Estuary.sc`), so after the first install, and after any update that touches the engine, run **SYSTEM > RESTART** before loading the script.

then put the recordings in place: `tools/push_audio.sh <norns-host>` copies the four folders from `audio/` to `/home/we/dust/audio/estuary/`, or copy your own files there by hand.

## dev

- `lua test/unit.lua test/unit_*.lua` runs the unit tests (run from the repo root).
- `lua test/rules_selftest.lua` checks the music-rules checker itself.
- `lua test/sim.lua [bars] [mode 1=set 2=track] [minutes] [tempo]` runs the script headless against stubbed norns APIs, prints the arc every 100 bars, and ends with `RULES ok` or a list of rule violations (exit 1). examples: `lua test/sim.lua 2160 1` (two hours of set), `lua test/sim.lua 900 2 12` (a 12-minute track). `MUTES=1` toggles random mutes and solos each bar, `HKEY=1` makes random hand key and mode changes, `SNAP=dir` renders each visual theme to a PGM in `dir` through a small rasterizer (`test/raster.lua`).
- `test/sc/run.sh` compiles `lib/Engine_Estuary.sc` against a stub CroneEngine, boots a local SuperCollider server, fires every command and renders a wav (needs SuperCollider.app on the Mac).

## license

MIT
