# estuary

a generative ambient set for norns. press play and let it ride.

estuary plays small melodies, slow bright chords, a low pedal note and a lot of air, and every so often the sound of water comes in. it runs by itself for as long as you leave it. you can steer it, but you don't have to.

the melodies, pad and pedal can also go out over USB MIDI or crow, each one: **internal**, **midi**, or **both**.

---

## what you hear

**motifs.** four short phrases, each a handful of notes and rests with its own odd-length cycle, so they drift in and out of phase with each other. each note is a step on a ladder of the current chord's own tones laid out close together (in the pentatonic modes only the ones the pentatonic allows; when that leaves fewer than four, a mode tone fills the widest gap), so a step is the next chord tone up or down, a motif stays within about an octave, and the melody always sits inside the harmony. a note held longer than a beat never sits a semitone right above a pad note. now and then a quick neighbour tone passes between two notes. up to three motifs sound at once, and they fade in and out over several bars. the four take turns: the one that has rested longest comes in next, and when the texture is full, every couple of phrases the longest-playing one makes way for one that has rested two phrases. each motif has a voice, chosen by the track's palette (see **sounds** below) or set by hand.

**pad.** a four-note chord that crossfades slowly whenever the harmony moves. it opens up as the bloom rises. it has eight characters (see **sounds**); a change of character arrives with the next voicing, crossfaded like any other.

**pedal.** a soft low note under the chord. it plays in the middle and upper bloom (not at the very top) and holds the key's tonic through the calm sections, so the chords move above it. it sits at least a 4th below the pad, never a semitone (or a major 7th) from a chord note or a bare tritone under one; when it can't sit clear of a chord, it rests. it is a pure low tone with a soft second harmonic for warmth, a slow gentle swell in its level and a soft 80 ms onset.

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

## sounds

the instruments are modelled on the gear of 80s environmental music: soft FM electric piano and bells, sine tones, mallets, plucked strings, a soft voice, glassy digital pads and gentle analog strings, all through the same warm echo and hall. nothing is distorted, every note starts softly (no clicks), and at the same velocity and brightness every voice is equally loud, so any palette sits in the same mix. brightness changes the tone (more FM index, harder mallet, more upper partials), not the level.

**motif voices** (PARAMS > SOUND > motif 1-4 voice):
- **rhodes:** a DX-style FM electric piano. a warm body with a short bell-like tine ping on top, harder and brighter with velocity, a gentle stereo tremolo; high notes fade a little sooner.
- **bell:** a glassy FM bell with a soft strike, a faint inharmonic shimmer in the first second and a long tail that turns slowly in the stereo field.
- **sine:** a pure tone with a breathy puff at the start and a slow, shallow vibrato once the note has settled.
- **marimba:** round wooden bars (tuned 1 : 4 : 10 modes) with a soft felt mallet; softer notes have fewer overtones.
- **vibes:** a vibraphone with a long ring and a slow motor tremolo that sways between the speakers.
- **celesta:** small, high and sweet, like a music box: a short ring with a soft octave and a tiny glint.
- **kalimba:** a soft thumb pluck with the tine's brief inharmonic shimmer leaning to one side.
- **flute:** a breathy pan flute or ocarina. a sine core with soft harmonics, a gentle chiff, quiet breath and late vibrato; it holds for the length of the note.
- **glass:** a glass harmonica. a slow swell to a pure tone with a faint shine growing in and a slow shimmer.
- **harp:** a soft pluck on a long-ringing string; its upper harmonics fade first and open slightly across the speakers.
- **koto:** a gentle pluck that starts a hair sharp and settles onto the note in a moment, with a soft nasal attack and no twang.
- **choir:** a soft "ooh": a rounded vowel that swells in slowly, with a late vibrato and a slow shimmer between the speakers. it holds for the length of the note.
- **glock:** a small, soft glockenspiel. rounder than the celesta: mostly fundamental, with the bar's bright overtones kept low and short, and a long tail that turns slowly between the speakers.
- **piano:** a soft felt piano, synthesised rather than sampled: a slightly stiff string that rings out after a softer prompt sound, a second string turning slowly in the stereo field, and a felt thump. the damper comes down a little after the note.
- **dulcimer:** a hammered dulcimer played softly: a quick felt hammer on a pair of strings whose gentle shimmer turns between the speakers.
- **steelpan:** a soft, round steel pan. a mellow mallet with the octave blooming in just after the strike, never clangy.
- **guitar:** a warm nylon-string pluck, fingered a fifth of the way along the string, with a breath of finger noise.
- **horn:** a soft 80s analog brass voice: a filtered saw whose filter swells open after a slow-ish onset and settles, with a little chorus on one side. it holds for the length of the note and never blares.

**pad characters** (PARAMS > SOUND > pad sound):
- **warm:** triangle and sine with a soft sub, each note drifting and breathing slowly under a moving low-pass.
- **strings:** soft analog strings: gently filtered saws with a slow ensemble chorus.
- **glass:** a digital FM pad with a gentle double-octave shimmer that comes and goes on each note.
- **air:** a breathy choir: noise tuned to each note and its octave over a quiet sine core.
- **organ:** soft sine drawbars, each note swaying slowly like a rotor.
- **shimmer:** a soft core with a halo an octave up that arrives slowly after the chord and breathes on each note, mirrored across the stereo field.
- **tape:** warm and rounded, with a little low-end bump and a very slow drift of about two cents that moves every note together, like tape speed. it never beats sour.
- **reed:** a soft harmonium: gently filtered reeds with the bellows breathing slowly in the level.

**palettes.** a palette is one record's worth of sound: a voice for each motif, a pad character, and a small lean in brightness and echo/reverb. with **palette** on **auto**, every new track picks one: the choice is seeded, and every palette comes round once before any comes again, favouring the ones whose voices you haven't heard yet, so the same one never comes twice in a row (rebuilding the same seed keeps it). pick a name to pin it: it applies at once and on every new track after. **motif voice** and **pad sound** on **auto** follow the palette; set them by name to override it.

| palette | motif 1 | motif 2 | motif 3 | motif 4 | pad |
|---|---|---|---|---|---|
| harbor | rhodes | bell | sine | vibes | warm |
| shallows | marimba | celesta | flute | kalimba | air |
| glasshouse | sine | glass | rhodes | bell | glass |
| morning | vibes | celesta | sine | marimba | strings |
| riverbank | flute | kalimba | marimba | celesta | warm |
| tidepool | kalimba | glass | marimba | bell | organ |
| veranda | rhodes | vibes | flute | celesta | strings |
| mist | sine | glass | flute | bell | air |
| atrium | rhodes | celesta | vibes | glass | organ |
| lantern | piano | glock | choir | celesta | shimmer |
| teahouse | koto | dulcimer | flute | glock | tape |
| chapel | choir | bell | harp | glass | shimmer |
| orchard | harp | glock | guitar | koto | reed |
| parlour | piano | vibes | horn | celesta | tape |
| lagoon | steelpan | harp | piano | glock | air |
| boathouse | guitar | dulcimer | piano | harp | reed |
| sandbar | koto | steelpan | choir | guitar | shimmer |
| promenade | horn | steelpan | rhodes | dulcimer | strings |
| cloister | choir | dulcimer | horn | bell | glass |
| courtyard | horn | steelpan | guitar | koto | tape |

motifs 2 and 4 play an octave above 1 and 3, so the small high voices sit there. the new voices live in the engine: after updating, run **SYSTEM > RESTART** once before loading the script. saved psets keep their voices (the old choices keep their positions in every list).

**react: everything listening.** the notes never change, but the sound listens and leans with what it hears. **react** (PARAMS > SOUND, 0-1, default 0.5) sets how far; **react source** picks what it listens to: **water**, **room**, **self** or **all** (the default).
- **water:** as the field recordings swell, the music brightens with them: new notes come in a little brighter, the pad's filter opens, and the reverb send widens, so the set breathes with the tide. as the water falls back, so does the shine.
- **room:** while **LISTEN > follow input key** is on, the level coming into the norns inputs tilts the notes a little brighter and lengthens the echo slightly, so the set leans into a lively room. when listening stops it lets go.
- **self:** under busy motif passages the pad dips gently (under 3 dB at the full depth), and in sparse passages the reverb opens out a little. it listens to the motif voices' dry sound (before echo and reverb), not the whole output, so neither the pad's dip nor the wider reverb can feed back into what it hears.

every change moves slowly (it rises over a second or so and settles back over several), so nothing pumps. each one has a ceiling, and the engine measures each source upstream of anything react changes, so nothing can run away, even with a microphone hearing the speakers. at 0 the sound is exactly as it was before react existed. after updating, run **SYSTEM > RESTART** once: react lives in the engine.

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
- **SOUND:** palette (auto, or pin one by name), pad sound (auto, warm, strings, glass, air, organ, shimmer, tape, reed), motif 1-4 voice (auto, rhodes, bell, sine, marimba, vibes, celesta, kalimba, flute, glass, harp, koto, choir, glock, piano, dulcimer, steelpan, guitar, horn); auto follows the palette. react (0-1), react source (water / room / self / all)
- **LISTEN:** follow input key, input gate (dB), hold before move (s)
- **MOTIF OUT / PAD OUT / PEDAL OUT:** output (internal / midi / both), midi device, midi channel (defaults: motifs ch 3, pad ch 2, pedal ch 1)
- **MOTIF OUT > motifs to midi:** all four on one channel, a single motif (for a mono synth: the others keep playing on norns), or each motif on its own channel. velocity follows the part's fade and the note length follows the note
- **SYNC OUT:** a midi device to send start / stop to, on the bar the music begins and when it stops. the clock itself comes from norns: **PARAMS > CLOCK > midi out**
- **CROW:** four outputs, each assignable to lead pitch, lead gate, chord root, bloom (0-5V), pedal pitch or pedal gate. pitches are 1V/oct with C3 at 0V, gates 8V. **lead motif** picks which motif drives the lead outputs (0 = any), **pitch slew** adds glide, **pitch octave** shifts every pitch output
- **CC OUT:** a midi device and channel (default 16) for the arc as CCs: bloom cc, tone cc, and a phrase pulse cc (127 on the first bar of each phrase, then 0). a cc number of 0 is off. sent once a bar, only when the value changes
- **VISUALS:**
  - **theme:** twenty-two quiet places, each drawn from what the music is doing and from what the engine hears of its own output: its overall **level**, the **low** end, the **mid**, the **top** end, and the **water sounds** (the out_amp, out_lo, out_mid, out_hi and nat_amp polls). the same water runs under all of them: a slow current flows out to sea while the bloom rises and back in while it falls, a swell pushes it inland, the low end adds a long slow heave and the top end scatters short-lived glints. every place has depth (a far layer that barely moves, a middle and a near layer that move with the current at their own rates) and is drawn with a hand-made, irregular dither rather than ruled lines. the bloom works like daylight: as it opens the place warms and brightens, as it falls it cools, and the water reflects what is above it. every place answers each input in its own way:
    - **notes** land where their pitch is, and each motif makes its own kind of mark
    - **the chord** is always in the scene (clouds, bands, pools, stars, swells), moving to its new arrangement over a few seconds when it changes
    - **the bar** is a slow breath of light
    - **a swell** changes the whole place (water rising, fog thickening, a squall, a surge)
    - **a passing moment** brings something rare and special to that place
    - and now and then, rarely and one at a time, a small natural thing happens on its own: a heron, a fish jumping, a leaf, a passing boat. each place has three of these.

    the picture keeps moving gently through silence, everything eases in and out, and a theme change fades through black.
    - **ripples:** a still pond under a dark tree line, the evening sky lying in it, reeds close by at the corners. *notes:* rings at their pitch, in their motif's band (smaller further away): a ring, a double ring, a ring with a bounced droplet, or a little cluster; echoes follow at the echo time, and the rings bend the reflection as they pass. *chord:* four wisps of cloud, across by pitch and higher for higher tones, lying in the water too. *bar:* light breathes into the sky's reflection. *swell:* the water rises up the bank and broad bands of light roll down the pond. *moment:* a cat's paw of wind runs across the pond. *level:* ring brightness and spread. *low:* the heave, the lily pads bobbing. *mid:* a band of wavelets across the middle water. *top:* sparkle on the reflections. *water sounds:* water boatmen dimpling the surface. *now and then:* a fish rises, a heron passes low, leaves drop from the tall tree.
    - **horizon:** open water to a low sun, a dark headland on the left, long clouds far off; the sun climbs a little as the bloom opens. *notes:* a crest catches the light close in, a pair of wavelets opens further out, a light shows in the sky with its path below, or a far sail glints on the line. *chord:* soft bands of light under the waterline, across by pitch, lower notes deeper. *bar:* the line and the glow round the sun breathe. *swell:* the sea rises. *moment:* a skein of geese crosses, reflected below. *level:* chop on the line. *low:* the long swell. *mid:* crests behind the line and long rollers coming in. *top:* the sun's glittering path. *water sounds:* chop and whitecaps. *now and then:* a sail crosses the line, a cloud passes the sun, a porpoise rolls.
    - **postcards:** four windows onto the same estuary from four spots along it: a sandy shore, open water with a far sail, a reed bank, and the rocks at the mouth, each with far hills, a drifting cloud, water and something close by. *notes:* a motif's last note hangs in its window's sky at its pitch with its path on the water, the frame brightens, and the window answers at that pitch: a wave breaks on the sand, a gull dips to the water, a reed head glows and sheds seeds, spray leaps off the rocks. *chord:* each window's far hills stand at the height of one chord tone. *bar:* the frames breathe. *swell:* the water rises in every window. *moment:* one bird flies through all four windows in turn. *level:* chop. *low:* the heave at each spot. *mid:* whitecaps. *top:* sparkle. *water sounds:* the wash, the reeds leaning, spray at the rocks. *now and then:* a cloud passes over all four, a boat crosses the open water, a heron stands in the reeds. a caption under each window shows where its motif is in its cycle.
    - **rain:** soft rain over a far tree line under a pale sky, low cloud over it all and a grassy bank coming down on the right. *notes:* drops fall from their pitch, slanted by the wind: a long drop, a pair, a heavy drop that throws a crown, or a slow drip that leaves a bubble riding the water. *chord:* four heavier clouds, across by pitch, higher for higher tones, each trailing its own rain. *bar:* the water's light breathes. *swell:* a squall: the rain slants harder and the water rises. *moment:* a rainbow stands over the trees. *level:* how hard the drops fall. *low:* the heave and the mist over the water. *mid:* the low cloud thickens. *top:* a fine drizzle close by. *water sounds:* curtains of rain in the distance and fine rings all over the water. *now and then:* a duck paddles across, a few birds cross under the cloud, a gust drives a curtain of rain over the water.
    - **tide:** a beach from the dunes, the sea above and the sand below, a strip of sky on the far line and dune grass close by. the last 80 bars of bloom make the shoreline, scrolling smoothly; at the live edge, waves wash up the sand and draw back, foam at their front and a wet sheen behind. two small shore birds keep just ahead of the wash. *notes:* foam bursts on the wash, a shell glints on the wet sand, spray lifts off a swell out at sea, or a gull settles on the water. *chord:* four long swells out at sea, nearer for lower tones. *bar:* the shoreline breathes. *swell:* the beach floods. *moment:* a patch of sunlight crosses the sea. *level:* how far the waves run up. *low:* the heave and a slower wave rhythm. *mid:* thicker foam and the swell lines out at sea. *top:* glitter on the foam, the sheen and the sea. *water sounds:* the reach of the waves and the dune grass in the wind. *now and then:* a gull glides along the shore, a crab scuttles over the sand, driftwood rides the wash.
    - **drift:** a pool from above between two grassy banks, turning in four slow eddies, its bed showing through and grass blades leaning out over the water. each motif is a leaf carried round its eddy at its cycle length; petals ride the eddies more slowly, and a shimmering line joins two leaves when their phases line up. *notes:* land on their motif's eddy, across by pitch: a ringing drop, a petal, a spinning seed, or a few bubbles. *chord:* four pools of sunlight on the bed, across by pitch. *bar:* the eddies' paths breathe. *swell:* the pool rises over the banks' edges. *moment:* a slow whirlpool opens in the middle. *level:* how fast the eddies turn. *low:* the eddies wobble. *mid:* the eddies' paths fill and brighten. *top:* shimmer on the paths and the sheens. *water sounds:* wind ruffling the surface. *now and then:* a water strider skates across, a big leaf drifts through, a fish's shadow passes under.
    - **reeds:** a reed bed at the water's edge under an evening sky, a low glow along the far bank and the first stars, in three layers: a dim far bank, a middle bed and a few tall reeds close by. every stem sways with the current and the heave. *notes:* the nearest reed nods and the water at its foot rings, a seed head lets go a few seeds, a dragonfly hovers, or a ring opens on the water. *chord:* four brighter stars, across by pitch, higher for higher tones, warming the glow under them and lying in the water. *bar:* the glow breathes. *swell:* a slow wave of bending runs across the bed. *moment:* the moon comes up over the bank. *level:* how far the reeds bend. *low:* the sway. *mid:* the middle bed swaying. *top:* glints on the seed heads and the water. *water sounds:* wind running along the far bank. *now and then:* a heron stands in the shallows, a small bird swings on a near reed, a fish jumps.
    - **koi:** a garden pond from above, stones round its rim, a gravel bed under the water and a maple branch over one corner. each motif is a fish swimming a slow loop of its own; a quiet motif's fish sinks deeper and dims. *notes:* the fish flicks its tail and a ring opens at the note's pitch, level with it, each fish ringing the water its own way. *chord:* lily pads, one per tone, bigger for lower notes, drifting to their tone's place across the pond; one flowers once the bloom opens. *bar:* the surface and the rim stones breathe. *swell:* the water laps over the rim. *moment:* blossom falls on the pond. *level:* how hard the fish swim. *low:* the pads rock and broad light rolls across. *mid:* the fishes' wakes. *top:* glints on the water, the pads and the fish. *water sounds:* a little stream running in at the corner. *now and then:* a frog hops off a pad, a maple leaf drifts across, a dragonfly darts over.
    - **kelp:** under the water in a kelp forest, the surface glowing overhead, far fronds dim in the haze and a sandy, stony floor. fronds sway with the current; a small school turns in the middle water. *notes:* a column of bubbles, one big wobbling bubble, a small fish darting out, or a glint running up the nearest frond, all at the note's pitch. *chord:* four shafts of light down from the surface, across by pitch. *bar:* the surface breathes. *swell:* a surge leans every frond. *moment:* a turtle glides through. *level:* the blades flutter. *low:* the fronds' heave. *mid:* the school, wider and brighter. *top:* the shafts and the light on the floor shimmer. *water sounds:* drifting motes. *now and then:* a seal passes far off, a jellyfish drifts up, a crab walks the floor.
    - **fireflies:** a marsh at dusk: the last light over a dark tree line, a few first stars, reeds at the edge, cattails close by and the glow lying in the still water. a few fireflies always drift faintly; every one shows again in the water. *notes:* light a firefly at their pitch: a bright glow with a halo, a double blink answered nearby, a slow light climbing with a tail, or a frog's plop on the water. *chord:* four small swarms hovering across by pitch, higher for higher tones. *bar:* the fireflies glow up together. *swell:* an evening mist lifts off the water. *moment:* the milky way shows for a while. *level:* how many fireflies are awake. *low:* the water's glow sways. *mid:* the reeds and cattails sway. *top:* stars and fireflies twinkle, the water glitters. *water sounds:* frogs on the water and crickets in the grass. *now and then:* a bat flits over, an owl glides along the trees, a little boat drifts by with a lantern.
    - **mist:** morning fog on the estuary: a faint far shore and a pale sun behind banks of mist drifting over still water, reed stalks close by. *notes:* open a clear patch at their pitch and show what stands there: a pair of mooring posts, a buoy with its slow light, a moored boat, or a cormorant on a rock drying its wings. *chord:* four denser layers in the fog, higher for higher tones. *bar:* the fog breathes. *swell:* more fog rolls in. *moment:* the sun breaks through and lays its path on the water. *level:* the drift. *low:* how thick the fog is. *mid:* the fog drawn out into long tendrils. *top:* sparkle on the still water. *water sounds:* thicker fog and water lapping at the near edge. *now and then:* a rowing boat crosses far off, a swan glides by, geese pass over.
    - **flock:** a flock of eighteen small waders over the mudflats under a pale sky with long clouds and a far shore; channels wind across the mud and salt-marsh grass stands close by. the flock keeps together by simple rules (stay close, match your neighbours, don't crowd) and drifts the way the tide is turning. *notes:* a few birds near the pitch bank, catch the light and swing out toward it; one bird flares up; a pool ripples on the mud; or one bird peels off in a loop. *chord:* four shining pools on the mud, across by pitch, bigger for lower tones. *bar:* the sky and the channels breathe. *swell:* the flock lifts and the channels fill. *moment:* the flock gathers into a slow wheeling murmuration. *level:* how wide the flock spreads. *low:* the flock rising and falling. *mid:* quicker, brighter wingbeats. *top:* glints on the wet mud and the channels. *water sounds:* the water rising in the channels and wind in the grass. *now and then:* a heron stalks along a channel, a curlew probes the mud, a far flock passes high over.
    - **brook:** a stream running over stones, seen a little from above, between a grassy far bank and a near bank with grass arching over the water; the bed's pebbles waver under the moving surface. streamlines run downstream, faster mid-stream, bending round the stones. *notes:* every note sets the stone nearest its pitch glinting, and leaves a mark there: a small standing wave, a pebble glinting on the bed, a boil welling up and carried off, or a string of bubbles. *chord:* the stones themselves, across by pitch, bigger for lower tones, each with a pillow of water in front and a wake behind; they shift slowly when the chord moves and the water finds its way round them again. *bar:* daylight breathes on the bed and the water. *swell:* the water comes up the banks and runs faster over the stones. *moment:* a shoal of minnows comes up the stream and holds against the current. *level:* how fast the stream runs. *low:* the surface heaves and the near grass sways. *mid:* longer, brighter wakes. *top:* glints on the water and the wet stones. *water sounds:* white water, flecks of foam running off the stones. *now and then:* a dipper bobs on the bank, a leaf boat rides the current, a trout rises.
    - **rockpool:** a tide pool at low tide from above: the sea breaking beyond a rim of wet rock, a sandy floor with pebbles, weed trailing from the rim and anemones on the rocks. *notes:* small creatures dart at their pitch: a shrimp flicks backwards, a crab scuttles sideways, a goby darts, a few fry scatter. *chord:* four starfish on the floor, across by pitch, bigger for lower tones, turning slowly and creeping to their new places. *bar:* the sky's sheen breathes in the pool. *swell:* the pool refills from its rim, foam spilling in. *moment:* a net of sunlight ripples over the floor. *level:* the surface's movement and the weed's flutter. *low:* the anemones open, and close as it falls; the weed sways. *mid:* cat's paws of wind across the pool. *top:* glints on the wet rim, the starfish and the water. *water sounds:* the sea breaking white beyond the rim and spray over it. *now and then:* a hermit crab crosses, a wave slops in over the rim, a gull's shadow passes.
    - **dew:** a spider's web strung between two reeds at dawn, close up, the sky paling toward a low sun over a far reed bed and a few motes drifting in the light. *notes:* each lights the dew drop at its pitch's place on the web: a drop that glows and trembles, a bead running down a spoke, a drop flaring into a star, or a run of beads along the spiral. *chord:* the four anchor threads tying the web to the reeds, tied higher for a higher tone, sliding to their new places. *bar:* the dawn glow breathes. *swell:* a breeze billows the web and bends the reeds. *moment:* a wave of light spirals out through the dew. *level:* the web trembles. *low:* the web sways on its threads. *mid:* light runs round the spiral. *top:* the dew sparkles. *water sounds:* a low mist drifts through the reeds. *the bloom:* the sun rising behind the web, lighting the threads from behind. *now and then:* the spider tends a thread, a heavy drop gathers and falls, a damselfly settles on a reed.
    - **cascade:** a small waterfall stepping down a rock face into a pool, woods above and ferns close by, a branch reaching over the pool. *notes:* flashes in the pool at their pitch: a fish turning silver, a pebble glinting, a small fish leaping, a ring spreading. *chord:* the stepped ledges the water falls over, each set across by its tone and wider for lower tones, so the fall steps left and right down the rock and shifts when the chord moves. *bar:* the falling water breathes. *swell:* the fall swells and the pool rises. *moment:* sun finds the fall and lights the mist over the pool. *level:* how fast the water falls. *low:* the ferns sway and the pool heaves. *mid:* streaks running down the falling sheet. *top:* spray thrown up round the plunge, glints on the falling water and the pool. *water sounds:* white water where it lands on each ledge and in the pool. *now and then:* a kingfisher dives from the branch, a rainbow stands in the spray, a log drifts across the pool.
    - **mangrove:** a mangrove at the waterline: a dark canopy, far trunks in the shade, three near trunks splitting into prop roots that arch into slow, tea-coloured water, aerial roots hanging from the branches. the tide comes in among the roots as the bloom rises and drains as it falls. *notes:* small fish between the roots at their pitch: one flicks past, a pair dart, one rises and rings the surface, one turns trailing a glint. *chord:* four big roots arching into the water in front, across by pitch, wider for lower tones, their backs catching the light. *bar:* the water breathes. *swell:* the tide surges in. *moment:* shafts of sun slant down through the canopy. *level:* the water's movement. *low:* the hanging roots sway and broad swells of light roll across the water. *mid:* the reflections wobble. *top:* flecks of sun through the leaves and glints on the water. *water sounds:* the water laps at the roots. *now and then:* a heron stalks the shallows, a mudskipper hops along a root, a canoe glides past.
    - **aurora:** a calm northern fjord at night, dark mountains either side of still water and stars over them, the aurora hanging in soft curtains and lying again in the water. *notes:* light rays at their pitch: one tall ray, a pair, a ray running along the curtain, or a soft pulsing patch. *chord:* the curtains, each across by its tone and higher for a higher tone, drifting to their new places. *bar:* the aurora breathes. *swell:* a wave of light rolls along every curtain and they hang lower and brighter. *moment:* a corona opens overhead. *level:* how fast the curtains drift. *low:* long slow folds in the curtains. *mid:* finer ripples in the folds. *top:* the rays shimmer. *water sounds:* the shore laps and the reflection breaks up. *the bloom:* how strongly the aurora burns. *now and then:* a shooting star, a seal surfacing, a cabin window lighting on the shore.
    - **shoal:** under the water by a pier: the surface wavering overhead with the deck's shadow across it, far piles in the haze, a sandy bed with weed, and a silver school of thirty fish turning as one. *notes:* at their pitch's height: a few fish turn and flash, one darts out, one rolls silver, or a string of bubbles rises. *chord:* four piles close by, across by pitch, each with a band of sunlight down it, higher for a higher tone. *bar:* the light from above breathes. *swell:* a surge pushes the school and leans the weed. *moment:* the school draws into a tight, turning ball. *level:* the school quickens and spreads. *low:* the school lifts and drops; the weed sways. *mid:* the light ripples on the piles and the bed. *top:* glints on the surface and the fish. *water sounds:* drifting motes. *the tide:* which way the school heads. *now and then:* a ray glides along the bed, a turtle passes, a bigger fish cruises through and the school parts round it.
    - **paddies:** terraced rice paddies after rain, stepping down a hillside toward you, each flooded terrace a mirror of the sky with young rice in rows, misty hills behind. *notes:* a ripple on the terrace matching the pitch (higher notes on the higher, further terraces), across by pitch: a ring, a wide double ring, a ring with a bounced drop, or a cluster of dimples. *chord:* the terraces' light, each mirroring a patch of sky across by its tone, brighter for a higher tone. *bar:* the sky breathes in the mirrors. *swell:* a soft shower drifts over the hill. *moment:* a band of sunlight sweeps down the terraces. *level:* the clouds' reflections drift faster. *low:* the rice sways. *mid:* cat's paws on the mirrors. *top:* glints on the wet rice. *water sounds:* water trickling down from terrace to terrace. *now and then:* an egret glides in to land, a farmer's hat moves along a far path, frogs ring a pool.
    - **echo bridge:** an old concrete bridge over a slow river at sunset, after the one on the river's south side known for its echo: one broad arch under a closed spandrel wall, its reflection completing the ellipse, trees on the banks behind and the far bank and the evening sky through the arch. *notes:* a soft ring of light rises under the arch at the note's pitch (a ring, an opening arc, a pair of small rings or a burst of points), then comes back as fading copies at the echo time, bouncing along the arch's curve, each as much quieter as the echo feedback makes it. *chord:* four warm lanterns strung along the far bank through the arch, across by pitch, lying in the water. *bar:* the sunset glow breathes. *swell:* the river comes up the piers. *moment:* the whole arch rings with light. *level:* how far the echoes travel along the arch, and as the sound falls away its tail lingers as light under the arch. *low:* a slow swell rolls under the arch. *mid:* the echoes travel further and the sky through the arch wavers in the water. *top:* glints on the water, the parapet and the lanterns. *water sounds:* the river's murmur across its surface. *the bloom:* the sunset deepening and warming. *now and then:* a heron flies through the arch, a kayak passes beneath, swallows dart out from under it.
    - **confluence:** a park where a creek meets a river, under a row of tall concrete petals rising from narrow feet and flaring wide, leaning together in pairs to make arches, shaped to gather rain and dew and run it down to a cistern at their feet; a soft sky, the two waters meeting in the distance, native grasses and wildflowers close by. *notes:* a drop runs down the petal nearest the pitch into the cistern: a single drop, a pair, a drop leaving a glistening trail, or a drop that rings the cistern as it lands. *chord:* the petals' lit faces, one arch each, lit higher for a higher tone. *bar:* the sky and the petals breathe. *swell:* a shower slides down every petal. *moment:* light flows down the whole canopy into the cistern. *level:* the waters and the cistern's ripples run faster. *low:* the grasses sway. *mid:* the wildflowers nod and brighten. *top:* dew glints along the petals' edges. *water sounds:* the shimmer where the two waters meet. *the bloom:* the cistern's glow rising at the petals' feet. *now and then:* a monarch drifts by, an egret stands at the confluence, a rain cloud passes.
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

- `lua test/unit.lua test/unit_*.lua` runs the unit tests (run from the repo root). `test/unit_visuals.lua` draws every theme through silence, a mid texture, a peak and a swell into the rasterizer, and checks how much of the screen is lit, frame-to-frame change, the draw-call budget, NaN, motion at silence, reaction to the top and low bands, and bad input. a reactivity matrix checks that every theme visibly answers each input on its own (a note, a chord change, the bar, a bloom ramp, a swell, a moment and each of the five polls), that the four motifs leave different marks and that low and high notes land in different places, and a 20-minute run checks each theme's small happenings: at least two kinds, one at a time, each easing in and out. `VISREPORT=1` prints its numbers.
- `lua test/rules_selftest.lua` checks the music-rules checker itself.
- `lua test/sim.lua [bars] [mode 1=set 2=track] [minutes] [tempo]` runs the script headless against stubbed norns APIs, prints the arc every 100 bars, and ends with `RULES ok` or a list of rule violations (exit 1). examples: `lua test/sim.lua 2160 1` (two hours of set), `lua test/sim.lua 900 2 12` (a 12-minute track), `lua test/sim.lua 900 2 4` (several short tracks: also checks that more than one palette's voices get heard). `MUTES=1` toggles random mutes and solos each bar, `HKEY=1` makes random hand key and mode changes, `RESTART=1` sets track end to stop and restarts after each stop, `SEED=n` replays a run, `SNAP=dir` renders each visual theme to a PGM in `dir` through a small rasterizer (`test/raster.lua`), plus `_still` (the engine's ears silent), `_loud` (ears pinned) and `_incident` (one of its small happenings) versions. the sim feeds fake output polls from the music every 8th.
- `test/sc/run.sh` compiles `lib/Engine_Estuary.sc` against a stub CroneEngine, boots a local SuperCollider server, fires every command (including a nature load and play in the same tick for each slot), checks the output polls (`out_amp` rises with a note and falls back after its tail; `nat_amp` rises with nature) and renders a wav. then `test/sc/sounds.scd` plays every motif voice (3 pitches x 3 brightnesses) and every pad character alone, prints their RMS and peak, checks no NaN, no clipping, soft onsets and that voices (and pads) sit within 3 dB of each other, checks a pad-character change crossfades, and renders a demo wav per palette to `$DEMO_DIR` (default `$TMPDIR/estuary_demos`). then `test/sc/react.scd` checks react: at 0 every nudge is neutral with every source pushed to the top; a null test renders the v2 engine (taken from git at `$V2_REF`) and this one from the same score in non-realtime with the same random seed, and they must cancel at react 0 and differ at 0.8; at 0.8 loud water must raise the share of energy above 2.5 kHz and widen the reverb send, the room must only count while listening, busy motifs must duck the pad by 2-3 dB at most and slowly; and 60 s with everything at max and the output fed back into the input must stay bounded. it renders a react demo (one palette under a water swell, at react 0 and 0.8) next to the palette demos. it exits 1 if any check fails (needs SuperCollider.app on the Mac and git).

## license

MIT
