// Engine_Estuary
//
// Soft, warm, spacious voices for an ambient set. No saturation anywhere;
// the only dynamics processor is a Limiter at the master.
//
// signal flow
//   voices -> motifBus -> est_motifmix -> mainBus (dry); echoBus, verbBus (sends)
//   pad    -> padBus  -> est_padmix -> mainBus/echoBus/verbBus
//   nature -> natBus  -> est_natfx  -> mainBus/verbBus
//   est_echo (ping-pong) -> mainBus + verbBus
//   est_verb (hall) -> mainBus ;  est_master -> hardware out
//   est_react: slow followers on the water (nat_amp), the room (in_amp,
//   while listening) and the motifs (motifBus) -> reactBus, which nudges
//   motif and pad brightness, the reverb send, echo feedback and the pad's
//   level. at react 0 every nudge is exactly neutral (+0 / x1)
//
// NOTE: sclang binary operators have no precedence (strict left-to-right),
// so every compound expression below is fully parenthesized.
//
// commands (formats are parsed by the headless sim, keep them literal)
//   note        voice midi vel dur pan bright send   (voice 1 rhodes 2 bell 3 sine 4 marimba
//                                                    5 vibes 6 celesta 7 kalimba 8 flute 9 glass
//                                                    10 harp 11 koto 12 choir 13 glock 14 piano
//                                                    15 dulcimer 16 steelpan 17 guitar 18 horn)
//   pad         m1 m2 m3 m4     (crossfades from the current pad over pad_xfade s,
//                                in the character set by `tweak pad_sound`:
//                                1 warm 2 strings 3 glass 4 air 5 organ
//                                6 shimmer 7 tape 8 reed)
//   pedal       midi vel dur   (one voice: a new pedal releases the old; vel 0 only releases)
//   nature_load slot path       (1 bed, 2 swell, 3 moment)
//   nature_play slot level fade (1/2 loop from a random position when rising
//                                from silence; 3 one-shot, level 0 stops it)
//   listen      on              (key tracker on the audio input; the room
//                                follower only listens while it is on)
//   tweak       key val         (react 0..1 depth; react_src 1 water 2 room
//                                3 self 4 all)
//
// polls
//   in_key  KeyTrack estimate of the audio input: 0-11 C..B major, 12-23 C..B minor
//   in_amp  input amplitude
//   out_amp, out_lo, out_mid, out_hi  what estuary itself sounds like, for
//           the visuals: the master mix (reverb included, before level and
//           limiter) overall and in three bands (< 250 Hz, 250 Hz-2.5 kHz,
//           > 2.5 kHz), each an envelope mapped from dB to 0..1
//   nat_amp the nature bus (all three slots after their tone), same mapping

Engine_Estuary : CroneEngine {
  var voiceGroup, fxGroup;
  var mainBus, echoBus, verbBus, padBus, natBus, motifBus;
  var keyBus, <inAmpBus, natAmpBus, outBus, <natSumBus, <motifAmpBus, <reactBus;
  var pedalSynth, padMixSynth, natFxSynth, echoSynth, verbSynth, masterSynth, listenSynth;
  var motifMixSynth, <reactSynth;
  var natBufs, natSynths, natLevels, natLoading, natPending, natGen, natOnceUse;
  var st, fx, fxMap, fxVals;
  // engine voice / pad_sound indices (1-based) -> SynthDefs. these lists
  // only grow at the end; lib/palettes.lua mirrors them (VOICES, PADS)
  var <voiceDefs, <padDefs, <padSynth;

  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }

  // last measured amplitude of a nature slot (1..3); used by the test
  natAmp { arg slot;
    ^natAmpBus.getnSynchronous(3)[slot - 1];
  }

  // the reactive nudges now: [bright add, verb send add, echo fb add, pad
  // duck, pad bright]; used by the test
  reactVals {
    ^reactBus.getnSynchronous(5);
  }

  alloc {
    var s = context.server;
    // an amplitude envelope -> 0..1 for the visuals: lo..hi dB mapped
    // linearly, clipped (silence reads 0)
    var toVis = { arg a, lo, hi;
      a.max(0.00001).ampdb.linlin(lo, hi, 0, 1)
    };
    // 0..1 -> log-scaled Hz; values above 1 are taken as Hz already
    var toHz = { arg v, lo, hi;
      var u = v.clip(0, 1);
      Select.kr(v > 1, [u.linexp(0, 1, lo, hi), v.clip(lo, hi)])
    };
    // a motif voice's way out: mono -> Pan2; [l, r] -> Balance2 (both are
    // equal-power, 0.707 per side at the centre); then the dry bus and the
    // two sends
    var vout = { arg sig, pan, out, echoOut, verbOut, echo, verb;
      var o = if(sig.isArray, { Balance2.ar(sig[0], sig[1], pan) }, { Pan2.ar(sig, pan) });
      Out.ar(out, o);
      Out.ar(echoOut, o * echo);
      Out.ar(verbOut, o * verb);
    };

    mainBus  = Bus.audio(s, 2);
    echoBus  = Bus.audio(s, 2);
    verbBus  = Bus.audio(s, 2);
    padBus   = Bus.audio(s, 2);
    natBus   = Bus.audio(s, 2);
    motifBus = Bus.audio(s, 2);
    keyBus    = Bus.control(s, 1);
    inAmpBus  = Bus.control(s, 1);
    natAmpBus = Bus.control(s, 3);
    outBus    = Bus.control(s, 4);     // out_amp, out_lo, out_mid, out_hi
    natSumBus = Bus.control(s, 1);     // nat_amp
    motifAmpBus = Bus.control(s, 1);   // the motif voices' level (est_motifmix)
    reactBus  = Bus.control(s, 5);     // est_react: bright, verb, fb, duck, pad bright
    reactBus.setn([0, 0, 0, 1, 0.45]);  // neutral until est_react runs

    voiceGroup = Group.head(context.xg);
    fxGroup    = Group.after(voiceGroup);

    natBufs   = Array.fill(3, nil);
    natSynths = Array.fill(3, nil);
    natLevels = Array.fill(3, 0);
    natLoading = Array.fill(3, false);   // a load is in flight
    natPending = Array.fill(3, nil);     // [level, fade] asked for while loading
    natGen     = Array.fill(3, 0);       // load count: a stale load is dropped
    natOnceUse = IdentityDictionary.new; // buffer -> one-shots playing it

    // values read at spawn time (set via `tweak`)
    st = IdentityDictionary.new;
    st.put(\motif_level, 1.0);
    st.put(\pedal_level, 1.0);
    st.put(\pad_xfade, 4.0);
    st.put(\pad_sound, 1);

    voiceDefs = [\est_rhodes, \est_bell, \est_sine, \est_marimba, \est_vibes, \est_celesta, \est_kalimba, \est_flute, \est_glass, \est_harp, \est_koto, \est_choir, \est_glock, \est_piano, \est_dulcimer, \est_steelpan, \est_guitar, \est_horn];
    padDefs = [\est_pad_warm, \est_pad_strings, \est_pad_glass, \est_pad_air, \est_pad_organ, \est_pad_shimmer, \est_pad_tape, \est_pad_reed];

    // ---------------------------------------------------------------- voices

    // Every motif voice takes the same args. amp carries vel and the motif
    // level; vel alone shapes the timbre (FM index, mallet hardness), so the
    // level param never changes the tone. Each voice ends in vout. A GAIN
    // constant per voice keeps them within 3 dB RMS of each other at equal
    // vel and bright (test/sc/sounds.scd measures it). No onset is faster than
    // 4 ms (5 ms on the mallets), and nothing saturates. ks shortens decays
    // on high notes.

    // electric piano, the DX "E.PIANO 1" family: a body pair (1:1, index
    // falls with time) plus a tine pair (1:14, a short bright ping), both
    // scaled by vel and bright; a gentle stereo tremolo
    SynthDef(\est_rhodes, {
      arg out, echoOut, verbOut, freq=261, amp=0.2, vel=0.7, dur=1, pan=0, bright=0.5, echo=0.3, verb=0.3;
      var ks   = (freq / 261).clip(0.25, 8).pow(-0.4);
      var hard = ((vel * 0.5) + (bright * 0.7)) * Rand(0.92, 1.08);
      var bIdx = EnvGen.kr(Env([(0.3 + (hard * 1.3)), 0.25], [(1.6 * ks)], [-3]));
      var body = SinOsc.ar(freq, SinOsc.ar(freq, 0, bIdx));
      var tIdx = EnvGen.kr(Env([0, (0.2 + (hard * 0.8)), 0], [0.004, (0.22 * ks)], [\sin, -5]));
      var tine = SinOsc.ar(freq, SinOsc.ar((freq * 14).min(18000), Rand(0, 2pi), tIdx));
      var tEnv = EnvGen.kr(Env([1, 0.2], [(0.9 * ks)], [-4]));
      var env  = EnvGen.ar(Env([0, 1, 0.55, 0], [0.004, (dur * 0.8), (((dur * 0.4) + 1.1) * ks)], [\sin, -3, -4]), doneAction: 2);
      var tr   = SinOsc.kr(Rand(4.0, 4.6), Rand(0, 2pi)) * (0.05 + (0.04 * bright));
      var sig  = (body * 0.75) + ((tine * 0.4) * tEnv);
      sig = LPF.ar(sig, (2400 + (bright * 5200))) * env * amp * 1.03;
      vout.value([sig * (1 + tr), sig * (1 - tr)], pan, out, echoOut, verbOut, echo, verb);
    }).add;

    // glassy DX/TX bell: 1:3.5 FM with a long tail, an inharmonic strike
    // partial (2.76) that fades in under a second, and a partner a fraction
    // of a hertz away added to the left and subtracted from the right: each
    // side beats slowly, opposite in phase, so the tail turns gently between
    // the speakers (the partner cancels in a mono sum)
    SynthDef(\est_bell, {
      arg out, echoOut, verbOut, freq=523, amp=0.2, vel=0.7, dur=1, pan=0, bright=0.5, echo=0.3, verb=0.3;
      var hard = ((vel * 0.4) + (bright * 0.8)) * Rand(0.9, 1.1);
      var i1   = EnvGen.kr(Env([(0.25 + (hard * 1.1)), 0.1], [2.8], [-4]));
      var c1   = SinOsc.ar(freq, SinOsc.ar((freq * 3.5).min(18000), 0, i1));
      var c2   = SinOsc.ar((freq * 2.76).min(16000)) * EnvGen.kr(Env([0, 1, 0], [0.006, 0.9], [\sin, -4])) * (0.06 + (0.2 * bright));
      var c3   = SinOsc.ar(freq + Rand(0.25, 0.6), Rand(0, 2pi)) * 0.3;
      var env  = EnvGen.kr(Env([0, 1, 0], [0.006, (dur + 3.2)], [\sin, -5]), doneAction: 2);
      var cut  = 3500 + (bright * 6000);
      var mid  = c1 + c2;
      var sig  = LPF.ar([mid + c3, mid - c3], cut) * (env * amp * 0.93);
      vout.value(sig, pan, out, echoOut, verbOut, echo, verb);
    }).add;

    // pure sine with a breathy onset (a puff of band-passed noise) and a
    // slow, shallow vibrato that only arrives after the note has settled
    SynthDef(\est_sine, {
      arg out, echoOut, verbOut, freq=261, amp=0.2, vel=0.7, dur=1, pan=0, bright=0.5, echo=0.3, verb=0.3;
      var atk  = 0.09 - (bright * 0.05);
      var env  = EnvGen.kr(Env([0, 1, 0.75, 0], [atk, (dur * 0.5), ((dur * 0.5) + 0.8)], [\sin, -1, -3]), doneAction: 2);
      var vd   = EnvGen.kr(Env([0, 0, 1], [0.6, 1.8], [0, 2])) * 0.0025;
      var f    = freq * (1 + (SinOsc.kr(Rand(3.2, 3.8), Rand(0, 2pi)) * vd));
      var core = SinOsc.ar(f) + (SinOsc.ar(f * 2) * (0.03 + (0.12 * bright))) + (SinOsc.ar(f * 3) * (0.035 * bright));
      var br   = BPF.ar(WhiteNoise.ar, (freq * 2).min(12000), 0.7) * ((500 / freq).sqrt * 0.32) * EnvGen.kr(Env([0, 1, 0], [0.012, 0.15], [\sin, -4])) * (0.2 + (vel * 0.25));
      var sig  = (core + br) * env * amp * 0.78;
      vout.value(sig, pan, out, echoOut, verbOut, echo, verb);
    }).add;

    // marimba: three tuned bar modes (1 : 4 : 10) with their own decays, a
    // soft mallet (a slower onset and fewer upper modes when soft) and a
    // little felt thump
    SynthDef(\est_marimba, {
      arg out, echoOut, verbOut, freq=261, amp=0.2, vel=0.7, dur=1, pan=0, bright=0.5, echo=0.3, verb=0.3;
      var ks  = (freq / 261).clip(0.25, 8).pow(-0.5);
      var h   = ((vel * 0.4) + (bright * 0.6)) * Rand(0.9, 1.1);
      var atk = (0.007 - (h * 0.002)).max(0.005);
      var m1  = SinOsc.ar(freq) * EnvGen.ar(Env([0, 1, 0], [atk, (1.6 * ks)], [\sin, -4]), doneAction: 2);
      var m2  = SinOsc.ar((freq * 3.99).min(16000)) * EnvGen.kr(Env([0, 1, 0], [atk, (0.32 * ks)], [\sin, -5])) * (0.04 + (0.12 * h));
      var m3  = SinOsc.ar((freq * 9.9).min(17000)) * EnvGen.kr(Env([0, 1, 0], [atk, 0.08], [\sin, -5])) * (0.008 + (0.03 * h));
      var th  = LPF.ar(WhiteNoise.ar, (freq * 1.5).min(4000)) * EnvGen.kr(Env([0, 1, 0], [0.005, 0.03], [\sin, -4])) * 0.15;
      var sig = (m1 + m2 + m3 + th) * amp * 1.64;
      vout.value(sig, pan, out, echoOut, verbOut, echo, verb);
    }).add;

    // vibraphone: metal bar modes (1 : 4 : 10) with a long fundamental, a
    // slow motor tremolo on the fundamental, 90 degrees apart left and right
    // (the turning discs); damped a little after the note ends
    SynthDef(\est_vibes, {
      arg out, echoOut, verbOut, freq=261, amp=0.2, vel=0.7, dur=1, pan=0, bright=0.5, echo=0.3, verb=0.3;
      var ks   = (freq / 261).clip(0.25, 8).pow(-0.45);
      var h    = ((vel * 0.4) + (bright * 0.6)) * Rand(0.9, 1.1);
      var atk  = (0.0065 - (h * 0.0015)).max(0.005);
      var trem = SinOsc.kr(Rand(3.4, 4.0), [0, 0.5pi] + Rand(0, 2pi)) * 0.22;
      var m1   = SinOsc.ar(freq) * EnvGen.ar(Env([0, 1, 0], [atk, (3.2 * ks)], [\sin, -4]));
      var m2   = SinOsc.ar((freq * 4).min(16000)) * EnvGen.kr(Env([0, 1, 0], [atk, (0.7 * ks)], [\sin, -5])) * (0.05 + (0.16 * h));
      var m3   = SinOsc.ar((freq * 10).min(17000)) * EnvGen.kr(Env([0, 1, 0], [atk, 0.12], [\sin, -5])) * (0.01 + (0.035 * h));
      var damp = EnvGen.kr(Env([1, 1, 0], [((dur + 1.0).min(3.3 * ks)), 0.8], [0, -3]), doneAction: 2);
      var up   = m2 + m3;
      var g    = damp * amp * 1.16;
      vout.value([((m1 * (1 + trem[0])) + up) * g, ((m1 * (1 + trem[1])) + up) * g], pan, out, echoOut, verbOut, echo, verb);
    }).add;

    // celesta / music box: small, high and sweet. a fundamental, a quieter
    // octave and double octave, and a tiny strike glint
    SynthDef(\est_celesta, {
      arg out, echoOut, verbOut, freq=523, amp=0.2, vel=0.7, dur=1, pan=0, bright=0.5, echo=0.3, verb=0.3;
      var ks  = (freq / 261).clip(0.25, 8).pow(-0.4);
      var h   = ((vel * 0.4) + (bright * 0.6)) * Rand(0.9, 1.1);
      var atk = 0.005;
      var m1  = SinOsc.ar(freq) * EnvGen.ar(Env([0, 1, 0], [atk, (1.8 * ks)], [\sin, -4]), doneAction: 2);
      var m0  = SinOsc.ar((freq * 2).min(16000)) * EnvGen.kr(Env([0, 1, 0], [atk, (0.6 * ks)], [\sin, -5])) * 0.22;
      var m2  = SinOsc.ar((freq * 4).min(16000)) * EnvGen.kr(Env([0, 1, 0], [atk, (0.3 * ks)], [\sin, -5])) * (0.04 + (0.12 * h));
      var m3  = SinOsc.ar((freq * 9).min(17000)) * EnvGen.kr(Env([0, 1, 0], [atk, 0.05], [\sin, -5])) * (0.01 + (0.03 * h));
      var sig = (m1 + m0 + m2 + m3) * amp * 1.51;
      vout.value(sig, pan, out, echoOut, verbOut, echo, verb);
    }).add;

    // kalimba: a soft thumb pluck (a 1:1 FM blip for the body, falling in
    // 80 ms) with the tine's short inharmonic shimmer (5.93) leaning to one side
    SynthDef(\est_kalimba, {
      arg out, echoOut, verbOut, freq=261, amp=0.2, vel=0.7, dur=1, pan=0, bright=0.5, echo=0.3, verb=0.3;
      var ks  = (freq / 261).clip(0.25, 8).pow(-0.5);
      var h   = ((vel * 0.4) + (bright * 0.6)) * Rand(0.9, 1.1);
      var atk = 0.005;
      var bi  = EnvGen.kr(Env([(0.2 + (0.6 * h)), 0], [0.08], [-3]));
      var m1  = SinOsc.ar(freq, SinOsc.ar(freq, 0, bi)) * EnvGen.ar(Env([0, 1, 0], [atk, (1.4 * ks)], [\sin, -4]), doneAction: 2);
      var m2  = SinOsc.ar((freq * 5.93).min(17000)) * EnvGen.kr(Env([0, 1, 0], [atk, (0.14 * ks)], [\sin, -4])) * (0.05 + (0.15 * h));
      var g   = amp * 1.75;
      vout.value([(m1 + (m2 * 1.3)) * g, (m1 + (m2 * 0.7)) * g], pan, out, echoOut, verbOut, echo, verb);
    }).add;

    // pan flute / ocarina: a sine core with soft 2nd and 3rd harmonics, a
    // gentle chiff, a quiet breath under it, vibrato after it settles; holds
    // for the note's length
    SynthDef(\est_flute, {
      arg out, echoOut, verbOut, freq=261, amp=0.2, vel=0.7, dur=1, pan=0, bright=0.5, echo=0.3, verb=0.3;
      var atk  = (0.11 - (bright * 0.06)) * Rand(0.85, 1.15);
      var env  = EnvGen.kr(Env([0, 1, 0.82, 0.82, 0], [atk, 0.25, (dur - atk - 0.25).max(0.01), 0.4], [\sin, -2, 0, -3]), doneAction: 2);
      var vd   = EnvGen.kr(Env([0, 0, 1], [0.4, 1.0], [0, 2])) * 0.003;
      var f    = freq * (1 + (SinOsc.kr(Rand(4.4, 5.0), Rand(0, 2pi)) * vd));
      var core = SinOsc.ar(f) + (SinOsc.ar(f * 2) * (0.05 + (0.1 * bright))) + (SinOsc.ar(f * 3) * (0.04 + (0.06 * bright)));
      var air  = BPF.ar(WhiteNoise.ar, (freq * 1.5).min(12000), 1.0) * ((667 / freq).sqrt * 0.3) * (0.15 + (EnvGen.kr(Env.perc(0.02, 0.1)) * (0.3 + (vel * 0.2))));
      var sig  = (core + air) * env * amp * 0.64;
      vout.value(sig, pan, out, echoOut, verbOut, echo, verb);
    }).add;

    // glass harmonica: a slow swell to a pure core, faint upper partials and
    // a shine that grows in, a slow shimmer opposite left and right
    SynthDef(\est_glass, {
      arg out, echoOut, verbOut, freq=523, amp=0.2, vel=0.7, dur=1, pan=0, bright=0.5, echo=0.3, verb=0.3;
      var atk  = (0.3 - (bright * 0.16)) * Rand(0.9, 1.1);
      var env  = EnvGen.kr(Env([0, 1, 0.85, 0], [atk, dur.max(0.2), 1.4], [\sin, -1, -4]), doneAction: 2);
      var sh   = SinOsc.kr(Rand(0.6, 0.9), [0, pi]) * 0.05;
      var core = SinOsc.ar(freq) + (SinOsc.ar(freq * 2) * (0.06 + (0.1 * bright))) + (SinOsc.ar((freq * 3).min(16000)) * (0.02 + (0.05 * bright)));
      var shine = SinOsc.ar((freq * 4).min(16000)) * EnvGen.kr(Env([0, 1], [(0.5 + atk)])) * (0.03 * (0.5 + bright));
      var sig  = (core + shine) * env * amp * 0.545;
      vout.value([sig * (1 + sh[0]), sig * (1 + sh[1])], pan, out, echoOut, verbOut, echo, verb);
    }).add;

    // harp: a soft pluck on a long-ringing string. harmonic partials (1, 2,
    // 3, 5) with their own decays, the 2nd and 3rd leaning opposite ways so
    // the ring opens a little in the stereo field
    SynthDef(\est_harp, {
      arg out, echoOut, verbOut, freq=261, amp=0.2, vel=0.7, dur=1, pan=0, bright=0.5, echo=0.3, verb=0.3;
      var ks  = (freq / 261).clip(0.25, 8).pow(-0.45);
      var h   = ((vel * 0.4) + (bright * 0.6)) * Rand(0.9, 1.1);
      var atk = 0.005;
      var m1  = SinOsc.ar(freq) * EnvGen.ar(Env([0, 1, 0], [atk, (3.6 * ks)], [\sin, -4.5]), doneAction: 2);
      var m2  = SinOsc.ar((freq * 2).min(16000), Rand(0, 2pi)) * EnvGen.kr(Env([0, 1, 0], [atk, (1.8 * ks)], [\sin, -5])) * (0.2 + (0.16 * h));
      var m3  = SinOsc.ar((freq * 3).min(16000), Rand(0, 2pi)) * EnvGen.kr(Env([0, 1, 0], [atk, (0.8 * ks)], [\sin, -5])) * (0.05 + (0.12 * h));
      var m4  = SinOsc.ar((freq * 5).min(17000)) * EnvGen.kr(Env([0, 1, 0], [atk, (0.22 * ks)], [\sin, -5])) * (0.008 + (0.04 * h));
      var g   = amp * 1.13;
      vout.value([(m1 + (m2 * 1.15) + (m3 * 0.85) + m4) * g, (m1 + (m2 * 0.85) + (m3 * 1.15) + m4) * g], pan, out, echoOut, verbOut, echo, verb);
    }).add;

    // koto: a gentle pluck that starts a hair sharp (about 20 cents) and
    // settles onto the note in 120 ms; a 1:2 FM body whose index falls fast
    // (a soft nasal attack, no twang), a short 3rd-partial ping, a low-pass
    SynthDef(\est_koto, {
      arg out, echoOut, verbOut, freq=261, amp=0.2, vel=0.7, dur=1, pan=0, bright=0.5, echo=0.3, verb=0.3;
      var ks  = (freq / 261).clip(0.25, 8).pow(-0.5);
      var h   = ((vel * 0.4) + (bright * 0.6)) * Rand(0.9, 1.1);
      var f   = freq * EnvGen.kr(Env([1.0116, 1], [0.12], [-3]));
      var bi  = EnvGen.kr(Env([(0.25 + (0.6 * h)), 0.06], [(0.3 * ks)], [-4]));
      var m1  = SinOsc.ar(f, SinOsc.ar((f * 2), 0, bi)) * EnvGen.ar(Env([0, 1, 0], [0.004, (1.9 * ks)], [\sin, -4]), doneAction: 2);
      var m2  = SinOsc.ar((f * 3).min(16000)) * EnvGen.kr(Env([0, 1, 0], [0.004, (0.15 * ks)], [\sin, -5])) * (0.03 + (0.08 * h));
      var sig = LPF.ar((m1 + m2), (1800 + (bright * 4200)).min(freq * 12)) * (amp * 1.41);
      vout.value(sig, pan, out, echoOut, verbOut, echo, verb);
    }).add;

    // choir: a soft "ooh". four harmonics weighted by a round vowel's two
    // formants (about 330 and 760 Hz) and normalised so every pitch is as
    // loud; a slow onset, late vibrato, a hair of pitch life and a slow
    // shimmer opposite left and right
    SynthDef(\est_choir, {
      arg out, echoOut, verbOut, freq=261, amp=0.2, vel=0.7, dur=1, pan=0, bright=0.5, echo=0.3, verb=0.3;
      var atk  = (0.34 - (bright * 0.1)) * Rand(0.9, 1.1);
      var env  = EnvGen.kr(Env([0, 1, 0.9, 0], [atk, dur.max(0.2), 1.1], [\sin, -1, -4]), doneAction: 2);
      var vd   = EnvGen.kr(Env([0, 0, 1], [0.5, 1.2], [0, 2])) * 0.004;
      var f    = freq * (1 + (SinOsc.kr(Rand(4.6, 5.2), Rand(0, 2pi)) * vd) + (LFNoise2.kr(2.5) * 0.0012));
      var w    = { |k|
        var fr = freq * k;
        (1 / (1 + ((fr - 330) / 140).squared)) + (0.5 / (1 + ((fr - 760) / 180).squared)) + 0.04
      };
      var tilt = 0.6 + (0.8 * bright);
      var a    = [w.(1), w.(2), (w.(3) * tilt), ((w.(4) * tilt) / 2)];
      var norm = a.squared.sum.sqrt.reciprocal;
      var sh   = SinOsc.kr(Rand(0.18, 0.26), [0, pi]) * 0.12;
      var low  = SinOsc.ar(f) * a[0];
      var up   = (SinOsc.ar(f * 2) * a[1]) + (SinOsc.ar((f * 3).min(16000)) * a[2]) + (SinOsc.ar((f * 4).min(16000)) * a[3]);
      var g    = env * norm * (amp * 0.53);
      vout.value([(low + (up * (1 + sh[0]))) * g, (low + (up * (1 + sh[1]))) * g], pan, out, echoOut, verbOut, echo, verb);
    }).add;

    // glockenspiel, small and soft: a long round fundamental, the bar's
    // inharmonic 2.76 and 5.4 modes kept low and short (rounder than the
    // celesta), and a partner a fraction of a hertz away that turns the tail
    // slowly between the speakers (it cancels in a mono sum)
    SynthDef(\est_glock, {
      arg out, echoOut, verbOut, freq=523, amp=0.2, vel=0.7, dur=1, pan=0, bright=0.5, echo=0.3, verb=0.3;
      var ks  = (freq / 261).clip(0.25, 8).pow(-0.4);
      var h   = ((vel * 0.4) + (bright * 0.6)) * Rand(0.9, 1.1);
      var atk = 0.005;
      var e1  = EnvGen.ar(Env([0, 1, 0], [atk, (2.6 * ks)], [\sin, -4]), doneAction: 2);
      var m1  = SinOsc.ar(freq) * e1;
      var m2  = SinOsc.ar((freq * 2.76).min(16000)) * EnvGen.kr(Env([0, 1, 0], [atk, (0.35 * ks)], [\sin, -5])) * (0.03 + (0.08 * h));
      var m3  = SinOsc.ar((freq * 5.4).min(17000)) * EnvGen.kr(Env([0, 1, 0], [atk, 0.07], [\sin, -5])) * (0.005 + (0.02 * h));
      var c3  = SinOsc.ar(freq + Rand(0.3, 0.7), Rand(0, 2pi)) * (e1 * 0.2);
      var mid = (m1 + m2 + m3) * (amp * 1.26);
      var sid = c3 * (amp * 1.26);
      vout.value([mid + sid, mid - sid], pan, out, echoOut, verbOut, echo, verb);
    }).add;

    // felt piano: a slightly stiff string (partials 1-3 a hair sharp of
    // harmonic), each with its own decay, a prompt sound falling into a long
    // aftersound, a second string a fraction of a hertz away (left plus,
    // right minus: a slow turn, cancelling in mono), a soft felt thump; the
    // damper comes down a while after the note
    SynthDef(\est_piano, {
      arg out, echoOut, verbOut, freq=261, amp=0.2, vel=0.7, dur=1, pan=0, bright=0.5, echo=0.3, verb=0.3;
      var ks   = (freq / 261).clip(0.25, 8).pow(-0.5);
      var h    = ((vel * 0.5) + (bright * 0.5)) * Rand(0.92, 1.08);
      var p    = [1, 2, 3].collect { |n| n * (1 + (0.0004 * n * n)).sqrt };
      var e1   = EnvGen.kr(Env([0, 1, 0.45, 0], [0.005, (0.4 * ks), (3.4 * ks)], [\sin, -3, -4]));
      var damp = EnvGen.ar(Env([1, 1, 0], [(dur + 0.8), 0.8], [0, -4]), doneAction: 2);
      var s1   = SinOsc.ar(freq);
      var s2   = SinOsc.ar((freq * p[1]).min(16000), Rand(0, 2pi)) * EnvGen.kr(Env([0, 1, 0], [0.005, (1.6 * ks)], [\sin, -5])) * (0.22 + (0.2 * h));
      var s3   = SinOsc.ar((freq * p[2]).min(16000), Rand(0, 2pi)) * EnvGen.kr(Env([0, 1, 0], [0.005, (0.7 * ks)], [\sin, -5])) * (0.05 + (0.14 * h));
      var s5   = SinOsc.ar(freq + Rand(0.2, 0.45), Rand(0, 2pi)) * 0.22;
      var th   = LPF.ar(WhiteNoise.ar, (freq * 2).min(2500)) * EnvGen.kr(Env([0, 1, 0], [0.005, 0.04], [\sin, -4])) * (0.05 + (0.06 * vel));
      var g    = damp * (amp * 1.43);
      var mid  = (((s1 * e1) + s2 + s3) + th) * g;
      var sid  = (s5 * e1) * g;
      vout.value([mid + sid, mid - sid], pan, out, echoOut, verbOut, echo, verb);
    }).add;

    // hammered dulcimer, soft: a quick felt hammer on a pair of strings. the
    // pair sits a fraction of a hertz apart on the fundamental and the 2nd
    // (left plus, right minus: a slow shimmer that turns between the
    // speakers and cancels in mono, never a sour beat); harmonics 2-4 decay
    // sooner, a tiny hammer tick under it all
    SynthDef(\est_dulcimer, {
      arg out, echoOut, verbOut, freq=261, amp=0.2, vel=0.7, dur=1, pan=0, bright=0.5, echo=0.3, verb=0.3;
      var ks  = (freq / 261).clip(0.25, 8).pow(-0.45);
      var h   = ((vel * 0.4) + (bright * 0.6)) * Rand(0.9, 1.1);
      var atk = 0.004;
      var e1  = EnvGen.ar(Env([0, 1, 0], [atk, (2.6 * ks)], [\sin, -4.5]), doneAction: 2);
      var e2  = EnvGen.kr(Env([0, 1, 0], [atk, (1.2 * ks)], [\sin, -5]));
      var dt  = Rand(0.3, 0.6);
      var m1  = SinOsc.ar(freq) * e1;
      var m2  = SinOsc.ar((freq * 2).min(16000), Rand(0, 2pi)) * e2 * (0.2 + (0.2 * h));
      var m3  = SinOsc.ar((freq * 3).min(16000)) * EnvGen.kr(Env([0, 1, 0], [atk, (0.5 * ks)], [\sin, -5])) * (0.05 + (0.12 * h));
      var m4  = SinOsc.ar((freq * 4).min(17000)) * EnvGen.kr(Env([0, 1, 0], [atk, (0.2 * ks)], [\sin, -5])) * (0.01 + (0.05 * h));
      var p1  = SinOsc.ar(freq + dt, Rand(0, 2pi)) * (e1 * 0.3);
      var p2  = SinOsc.ar(((freq * 2) + (dt * 2)).min(16000), Rand(0, 2pi)) * (e2 * (0.06 + (0.06 * h)));
      var tk  = BPF.ar(WhiteNoise.ar, (freq * 4).min(6000), 1.2) * EnvGen.kr(Env([0, 1, 0], [0.004, 0.02], [\sin, -4])) * 0.05;
      var g   = amp * 1.29;
      var mid = (m1 + m2 + m3 + m4 + tk) * g;
      var sid = (p1 + p2) * g;
      vout.value([mid + sid, mid - sid], pan, out, echoOut, verbOut, echo, verb);
    }).add;

    // steel pan, soft and round: a mellow mallet on the fundamental, the
    // octave swelling in just after the strike and dying away (the pan's
    // note blooming), a faint 3rd; no clang
    SynthDef(\est_steelpan, {
      arg out, echoOut, verbOut, freq=261, amp=0.2, vel=0.7, dur=1, pan=0, bright=0.5, echo=0.3, verb=0.3;
      var ks  = (freq / 261).clip(0.25, 8).pow(-0.5);
      var h   = ((vel * 0.4) + (bright * 0.6)) * Rand(0.9, 1.1);
      var atk = 0.006;
      var m1  = SinOsc.ar(freq) * EnvGen.ar(Env([0, 1, 0], [atk, (1.7 * ks)], [\sin, -4]), doneAction: 2);
      var m2  = SinOsc.ar((freq * 2).min(16000), Rand(0, 2pi)) * EnvGen.kr(Env([0, 1, 0], [0.04, (0.7 * ks)], [\sin, -4])) * (0.18 + (0.2 * h));
      var m3  = SinOsc.ar((freq * 3).min(16000)) * EnvGen.kr(Env([0, 1, 0], [0.02, (0.25 * ks)], [\sin, -5])) * (0.02 + (0.06 * h));
      var sh  = SinOsc.kr(Rand(0.7, 1.0), [0, pi]) * 0.06;
      var sig = (m1 + m2 + m3) * (amp * 1.57);
      vout.value([sig * (1 + sh[0]), sig * (1 + sh[1])], pan, out, echoOut, verbOut, echo, verb);
    }).add;

    // nylon guitar: a warm fingered pluck. harmonics 1-5 shaped by the
    // plucking point (a fifth of the way along, so the 5th is almost gone),
    // higher ones fading sooner, a soft low-pass and a breath of finger
    SynthDef(\est_guitar, {
      arg out, echoOut, verbOut, freq=261, amp=0.2, vel=0.7, dur=1, pan=0, bright=0.5, echo=0.3, verb=0.3;
      var ks  = (freq / 261).clip(0.25, 8).pow(-0.5);
      var h   = ((vel * 0.4) + (bright * 0.6)) * Rand(0.9, 1.1);
      var atk = 0.005;
      var m1  = SinOsc.ar(freq) * EnvGen.ar(Env([0, 1, 0], [atk, (2.3 * ks)], [\sin, -4.5]), doneAction: 2);
      var up  = [2, 3, 4, 5].collect { |n, i|
        var w = ((n * pi) / 5).sin.abs / n;
        SinOsc.ar((freq * n).min(16000), Rand(0, 2pi)) * EnvGen.kr(Env([0, 1, 0], [atk, ((1.3 / (i + 1)) * ks)], [\sin, -5])) * (w * (0.8 + (1.2 * h)))
      };
      var fn  = BPF.ar(WhiteNoise.ar, (freq * 3).min(5000), 1.5) * EnvGen.kr(Env([0, 1, 0], [0.005, 0.03], [\sin, -4])) * 0.04;
      var sig = LPF.ar((m1 + Mix(up) + fn), (1500 + (bright * 4000)).min(freq * 10)) * (amp * 1.29);
      vout.value([sig * 1.04, sig * 0.96], pan, out, echoOut, verbOut, echo, verb);
    }).add;

    // horn: a soft 80s analog brass voice. one saw through two low-passes
    // whose cutoff swells open after a slow-ish onset and settles (kept low:
    // never blaring); the right side is half a slowly swaying chorus tap
    SynthDef(\est_horn, {
      arg out, echoOut, verbOut, freq=261, amp=0.2, vel=0.7, dur=1, pan=0, bright=0.5, echo=0.3, verb=0.3;
      var atk = (0.16 - (bright * 0.05)) * Rand(0.9, 1.1);
      var env = EnvGen.kr(Env([0, 1, 0.85, 0.85, 0], [atk, 0.3, (dur - atk - 0.3).max(0.01), 0.6], [\sin, -2, 0, -3]), doneAction: 2);
      var top = (freq * (2.2 + (bright * 1.6) + (vel * 0.6))).clip(300, 2600);
      var cut = EnvGen.kr(Env([(freq * 1.2).clip(150, 2000), top, (top * 0.75)], [(atk + 0.08), 0.6], [2, -3]));
      var sig = Saw.ar(freq * (1 + (LFNoise2.kr(0.3) * 0.0006)));
      sig = LPF.ar(LPF.ar(sig, cut), (cut * 1.5)) * (env * (amp * 1.95));
      vout.value([sig, ((sig * 0.6) + (DelayC.ar(sig, 0.02, (0.008 + (SinOsc.kr(0.37, Rand(0, 2pi)) * 0.002))) * 0.6))], pan, out, echoOut, verbOut, echo, verb);
    }).add;

    // pads: four notes, gate 0 releases over `rel` s, so two pads crossfade
    // (the `pad` command starts the next one at `atk` = pad_xfade). Every
    // character keeps that contract; a GAIN per character matches them
    // within 3 dB RMS on the same chord.

    // warm: triangle + sine + a sub, each voice drifting a hair and
    // breathing slowly, through a gentle moving low-pass
    SynthDef(\est_pad_warm, {
      arg out, f1=130, f2=196, f3=293, f4=392, amp=0.08, bright=0.5, atk=4, rel=4, gate=1;
      var env = EnvGen.kr(Env.asr(atk, 1, rel, [2, -2]), gate, doneAction: 2);
      var cut = (800 + (bright * 2700)) * (1 + (0.06 * SinOsc.kr(0.07, Rand(0, 2pi))));
      var sig = [f1, f2, f3, f4].collect { |f, i|
        var d = f * (1 + (LFNoise2.kr(0.12) * 0.0006));
        var v = (LFTri.ar(d) * 0.45) + (SinOsc.ar(f) * 0.5) + (SinOsc.ar(f * 0.5) * 0.18);
        Pan2.ar(v * (1 + (LFNoise2.kr(0.09) * 0.12)), [-0.55, -0.18, 0.18, 0.55][i]);
      };
      sig = Mix(sig);
      sig = LPF.ar(LPF.ar(sig, cut), (cut * 1.5));
      Out.ar(out, sig * env * amp * 1.08);
    }).add;

    // strings: soft analog strings. one saw per note, drifting slowly,
    // through two gentle low-passes, then an ensemble of two slowly
    // swaying delay taps (one per side)
    SynthDef(\est_pad_strings, {
      arg out, f1=130, f2=196, f3=293, f4=392, amp=0.08, bright=0.5, atk=4, rel=4, gate=1;
      var env = EnvGen.kr(Env.asr(atk, 1, rel, [2, -2]), gate, doneAction: 2);
      var cut = (650 + (bright * 1500)) * (1 + (0.05 * SinOsc.kr(0.05, Rand(0, 2pi))));
      var sig = [f1, f2, f3, f4].collect { |f, i|
        var v = Saw.ar(f * (1 + (LFNoise2.kr(0.15) * 0.0008)));
        Pan2.ar(v, [-0.5, -0.17, 0.17, 0.5][i]);
      };
      sig = Mix(sig);
      sig = LPF.ar(LPF.ar(sig, cut), (cut * 1.4));
      sig = HPF.ar(sig, 100);
      sig = (sig * 0.6) + (DelayC.ar(sig, 0.03, (0.012 + (SinOsc.kr([0.23, 0.29], [0, 1.6]) * 0.004))) * 0.6);
      Out.ar(out, sig * env * amp * 2.82);
    }).add;

    // glass: a digital FM pad (1:2, the index drifting slowly) with a gentle
    // double-octave shimmer that comes and goes on each note
    SynthDef(\est_pad_glass, {
      arg out, f1=130, f2=196, f3=293, f4=392, amp=0.08, bright=0.5, atk=4, rel=4, gate=1;
      var env = EnvGen.kr(Env.asr(atk, 1, rel, [2, -2]), gate, doneAction: 2);
      var sig = [f1, f2, f3, f4].collect { |f, i|
        var idx = (0.35 + (bright * 0.4)) * (1 + (LFNoise2.kr(0.1) * 0.3));
        var v = SinOsc.ar(f, SinOsc.ar((f * 2), Rand(0, 2pi), idx));
        var sh = SinOsc.ar((f * 4).min(15000)) * (0.05 + (0.08 * bright)) * (0.5 + (0.5 * SinOsc.kr(Rand(0.08, 0.16), Rand(0, 2pi))));
        Pan2.ar(v + sh, [-0.5, -0.17, 0.17, 0.5][i]);
      };
      sig = LPF.ar(Mix(sig), 7000);
      Out.ar(out, sig * env * amp * 1.0);
    }).add;

    // air: a breathy choir. noise through very narrow band-passes at each
    // note and its octave (level-matched across pitch), over a quiet sine core
    SynthDef(\est_pad_air, {
      arg out, f1=130, f2=196, f3=293, f4=392, amp=0.08, bright=0.5, atk=4, rel=4, gate=1;
      var env = EnvGen.kr(Env.asr(atk, 1, rel, [2, -2]), gate, doneAction: 2);
      var n   = WhiteNoise.ar;
      var sig = [f1, f2, f3, f4].collect { |f, i|
        var b1 = BPF.ar(n, f, 0.01) * (f.reciprocal.sqrt * 1000);
        var b2 = BPF.ar(n, (f * 2).min(12000), 0.01) * ((f * 2).reciprocal.sqrt * 1000) * (0.2 + (bright * 0.3));
        var v  = b1 + b2 + (SinOsc.ar(f) * 0.3);
        Pan2.ar(v, [-0.55, -0.18, 0.18, 0.55][i]);
      };
      sig = LPF.ar(Mix(sig), (1500 + (bright * 2500)));
      Out.ar(out, sig * env * amp * 1.12);
    }).add;

    // organ: soft sine drawbars (8', 4', 2 2/3'), each note swaying gently
    // in the stereo field like a slow rotor
    SynthDef(\est_pad_organ, {
      arg out, f1=130, f2=196, f3=293, f4=392, amp=0.08, bright=0.5, atk=4, rel=4, gate=1;
      var env = EnvGen.kr(Env.asr(atk, 1, rel, [2, -2]), gate, doneAction: 2);
      var sig = [f1, f2, f3, f4].collect { |f, i|
        var v = SinOsc.ar(f) + (SinOsc.ar(f * 2) * (0.25 + (0.2 * bright))) + (SinOsc.ar((f * 3).min(15000)) * (0.06 + (0.1 * bright)));
        Pan2.ar(v, ([-0.5, -0.17, 0.17, 0.5][i] + (SinOsc.kr((0.4 + (i * 0.05)), Rand(0, 2pi)) * 0.15)).clip(-1, 1));
      };
      sig = LPF.ar(Mix(sig), 5000);
      Out.ar(out, sig * env * amp * 0.83);
    }).add;
    // shimmer: a soft sine/triangle core with a halo an octave up (and a
    // faint double octave) that arrives slowly after the chord, breathes on
    // each note, and sits mirrored across the stereo field from its note
    SynthDef(\est_pad_shimmer, {
      arg out, f1=130, f2=196, f3=293, f4=392, amp=0.08, bright=0.5, atk=4, rel=4, gate=1;
      var env  = EnvGen.kr(Env.asr(atk, 1, rel, [2, -2]), gate, doneAction: 2);
      var halo = EnvGen.kr(Env([0, 0, 1], [(atk * 0.5), ((atk * 1.5) + 2)], [0, 2]));
      var sig = [f1, f2, f3, f4].collect { |f, i|
        var p    = [-0.5, -0.17, 0.17, 0.5][i];
        var core = (SinOsc.ar(f) * 0.55) + (LFTri.ar(f) * 0.2);
        var oct  = SinOsc.ar((f * 2).min(15000), Rand(0, 2pi)) * (0.3 + (0.15 * bright)) * (0.65 + (0.35 * SinOsc.kr(Rand(0.05, 0.11), Rand(0, 2pi))));
        var top  = SinOsc.ar((f * 4).min(15000)) * (0.03 + (0.05 * bright)) * (0.5 + (0.5 * LFNoise2.kr(0.13)));
        Pan2.ar(core, p) + Pan2.ar(((oct + top) * halo), p.neg)
      };
      sig = LPF.ar(Mix(sig), 9000);
      Out.ar(out, sig * env * amp * 1.23);
    }).add;

    // tape: warm triangle and sine with a soft 2nd harmonic, rounded off on
    // top with a little low-end bump, and a very slow drift of about two
    // cents that moves every note together (the tape's speed), so nothing
    // beats against anything
    SynthDef(\est_pad_tape, {
      arg out, f1=130, f2=196, f3=293, f4=392, amp=0.08, bright=0.5, atk=4, rel=4, gate=1;
      var env   = EnvGen.kr(Env.asr(atk, 1, rel, [2, -2]), gate, doneAction: 2);
      var drift = 1 + (LFNoise2.kr(0.06) * 0.0012) + (SinOsc.kr(0.043, Rand(0, 2pi)) * 0.0003);
      var cut   = 900 + (bright * 1800);
      var sig = [f1, f2, f3, f4].collect { |f, i|
        var d = f * drift;
        var v = (LFTri.ar(d) * 0.5) + (SinOsc.ar(d) * 0.45) + (SinOsc.ar(d * 2) * (0.06 + (0.06 * bright)));
        Pan2.ar(v * (1 + (LFNoise2.kr(0.07) * 0.08)), [-0.45, -0.15, 0.15, 0.45][i]);
      };
      sig = Mix(sig);
      sig = LPF.ar(LPF.ar(sig, cut), (cut * 1.6));
      sig = BLowShelf.ar(sig, 160, 1, 2.5);
      sig = BHiShelf.ar(sig, 4000, 1, -3);
      Out.ar(out, sig * env * amp * 1.0);
    }).add;

    // reed: a soft harmonium. a narrow pulse (a reed's odd and even
    // harmonics) over a sine, through two gentle low-passes, with the
    // bellows breathing slowly in the level
    SynthDef(\est_pad_reed, {
      arg out, f1=130, f2=196, f3=293, f4=392, amp=0.08, bright=0.5, atk=4, rel=4, gate=1;
      var env  = EnvGen.kr(Env.asr(atk, 1, rel, [2, -2]), gate, doneAction: 2);
      var bel  = 1 + (LFNoise2.kr(0.18) * 0.07);
      var cut  = 850 + (bright * 1400);
      var sig = [f1, f2, f3, f4].collect { |f, i|
        var v = (Pulse.ar(f * (1 + (LFNoise2.kr(0.1) * 0.0004)), 0.32) * 0.5) + (SinOsc.ar(f) * 0.4);
        Pan2.ar(v, [-0.5, -0.17, 0.17, 0.5][i]);
      };
      sig = Mix(sig) * bel;
      sig = LPF.ar(LPF.ar(sig, cut), (cut * 1.3));
      sig = HPF.ar(sig, 90);
      Out.ar(out, sig * env * amp * 1.53);
    }).add;
    // pad mixer: level (and est_react's gentle duck, 1 at react 0), plus sends
    SynthDef(\est_padmix, {
      arg in, out, echoOut, verbOut, duckIn, level=1, echo=0.25, verb=0.5;
      var sig = In.ar(in, 2) * Lag.kr(level, 0.3) * In.kr(duckIn);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // pedal: a low sine with a soft 2nd harmonic and a trace of the 3rd for
    // warmth, a slow gentle swell in its level, an 80 ms onset. gate 0 lets
    // it go over 2 s
    SynthDef(\est_pedal, {
      arg out, verbOut, freq=65, amp=0.2, dur=4, gate=1;
      var env = EnvGen.kr(Env([0, 1, 0.8, 0], [0.08, dur, (dur * 0.3).max(1.5)], [\sin, -1, -3]), doneAction: 2);
      var rel = EnvGen.kr(Env.asr(0.01, 1, 2.0, -3), gate, doneAction: 2);
      var br  = 1 + (SinOsc.kr(0.11, Rand(0, 2pi)) * 0.04);
      var sig = (SinOsc.ar(freq) + (SinOsc.ar((freq * 2)) * 0.22) + (SinOsc.ar((freq * 3)) * 0.04)) * env * rel * br * amp;
      sig = sig ! 2;
      Out.ar(out, sig);
      Out.ar(verbOut, sig * 0.25);
    }).add;

    // nature players: loop (slots 1,2) and one-shot (slot 3), mono and stereo.
    // a measured amplitude is written to natAmpBus for each slot.
    [1, 2].do { |nc|
      SynthDef(("est_natloop" ++ nc).asSymbol, {
        arg out, buf, ampOut, level=0, fade=1, trim=1, startPos=0, t_rst=0;
        var g   = Lag.kr(level, fade) * trim;
        var sig = PlayBuf.ar(nc, buf, BufRateScale.kr(buf), t_rst, startPos, 1);
        sig = if(nc == 1, { sig ! 2 }, { sig });
        sig = sig * g;
        Out.kr(ampOut, Amplitude.kr(sig.sum, 0.05, 0.5));
        Out.ar(out, sig);
      }).add;
      SynthDef(("est_natonce" ++ nc).asSymbol, {
        arg out, buf, ampOut, level=0, fade=1, trim=1, dur=5;
        var g   = Lag.kr(level, fade) * trim;
        var env = EnvGen.kr(Env.linen(0.02, (dur - 0.15).max(0.01), 0.13), doneAction: 2);
        var sig = PlayBuf.ar(nc, buf, BufRateScale.kr(buf), 1, 0, 0);
        sig = if(nc == 1, { sig ! 2 }, { sig });
        sig = sig * g * env;
        Out.kr(ampOut, Amplitude.kr(sig.sum, 0.05, 0.5));
        Out.ar(out, sig);
      }).add;
    };

    // nature tone + sends; its level goes to the nat_amp poll
    SynthDef(\est_natfx, {
      arg in, out, verbOut, ampOut, tone=0.7, verb=0.2;
      var sig = In.ar(in, 2);
      sig = LPF.ar(sig, Lag.kr(toHz.value(tone, 800, 16000), 0.3));
      sig = HPF.ar(sig, 40) * 0.5;
      Out.kr(ampOut, toVis.value(Amplitude.kr(sig.sum * 0.5, 0.05, 0.4), -66, -18));
      Out.ar(out, sig);
      Out.ar(verbOut, sig * verb);
    }).add;

    // ----------------------------------------------------------------- fx

    // ping-pong echo, clean: tone and hp filters in the loop, slow wow
    SynthDef(\est_echo, {
      arg in, out, verbOut, fbIn, time=0.83, fb=0.45, tone=0.5, wow=0.0008, level=0.7, verb=0.35;
      var src = In.ar(in, 2);
      var t   = Lag.kr(time, 0.4).clip(0.02, 3.5);
      var mod = SinOsc.kr([0.31, 0.37], [0, 1]) * wow.clip(0, 0.002);
      var loop = LocalIn.ar(1);
      var dl  = DelayC.ar((Mix(src) * 0.7) + (loop * (fb + In.kr(fbIn)).clip(0, 0.85)), 4, (t + mod[0]).clip(0.01, 3.9));
      var dr  = DelayC.ar(dl, 4, (t + mod[1]).clip(0.01, 3.9));
      var fbk = HPF.ar(LPF.ar(dr, Lag.kr(toHz.value(tone, 600, 9000), 0.3)), 180);
      var wet;
      LocalOut.ar(fbk);
      wet = [dl, dr];
      wet = LPF.ar(wet, 9000);
      Out.ar(out, wet * level);
      Out.ar(verbOut, wet * verb);
    }).add;

    // large hall: diffusion into FreeVerb2 at a big size, warm top
    SynthDef(\est_verb, {
      arg in, out, sendIn, size=0.95, damp=0.55, level=0.8, send=1;
      var sig = In.ar(in, 2) * send * (1 + In.kr(sendIn));
      sig = DelayN.ar(sig, 0.1, 0.04);
      [0.013, 0.017, 0.023, 0.031].do { |dt|
        sig = AllpassC.ar(sig, 0.08, (dt * [1, 1.13]) + (LFNoise2.kr([0.1, 0.11]) * 0.0008), 1.8);
      };
      sig = FreeVerb2.ar(sig[0], sig[1], 1, Lag.kr(size, 1).clip(0, 1), damp);
      sig = HPF.ar(sig, 120);
      sig = LPF.ar(sig, 7500);
      Out.ar(out, sig * level);
    }).add;

    // master: tone, level, limiter at -1 dBFS (no saturation).
    // the visuals listen here, after the reverb (tails count) and before
    // level and limiter: three cheap 2-pole filters and four Amplitude
    // followers on the mono sum, no FFT
    SynthDef(\est_master, {
      arg in, out, ampOut, level=0.9, tone=0.75;
      var sig = In.ar(in, 2);
      var mono, lo, mid, hi;
      sig = HPF.ar(sig, 25);
      sig = LPF.ar(sig, Lag.kr(toHz.value(tone, 2500, 16000), 0.3));
      mono = (sig[0] + sig[1]) * 0.5;
      lo  = LPF.ar(mono, 250);
      mid = LPF.ar(HPF.ar(mono, 250), 2500);
      hi  = HPF.ar(mono, 2500);
      Out.kr(ampOut, [
        toVis.value(Amplitude.kr(mono, 0.05, 0.4), -64, -12),
        toVis.value(Amplitude.kr(lo, 0.05, 0.4), -66, -14),
        toVis.value(Amplitude.kr(mid, 0.05, 0.4), -68, -16),
        toVis.value(Amplitude.kr(hi, 0.05, 0.4), -76, -26)
      ]);
      sig = Limiter.ar(sig * level, 0.89, 0.01);
      Out.ar(out, sig);
    }).add;

    // the motif voices' dry bus -> the main mix, measured on the way: the
    // `self` follower listens here, upstream of everything react touches
    SynthDef(\est_motifmix, {
      arg in, out, ampOut;
      var sig = In.ar(in, 2);
      Out.kr(ampOut, Amplitude.kr(((sig[0] + sig[1]) * 0.5), 0.05, 0.4));
      Out.ar(out, sig);
    }).add;

    // everything listening: slow followers (a time constant of at least 0.3 s
    // rising and 1.5 s falling: LagUD's 60 dB times of 2.1-3 s and 10.5-12 s)
    // on three sources, scaled by the react depth and picked by src
    // (1 water 2 room 3 self 4 all), out to reactBus:
    //   0 bright add   motif notes (at spawn) brighten with water and room
    //   1 verb add     the reverb send widens with water and in sparse passages
    //   2 fb add       echo feedback leans into a loud room
    //   3 duck         the pad dips under busy motifs (2.7 dB at most)
    //   4 pad bright   the pad's filter opens with water and room
    // every source is measured where nothing react changes can raise it
    // (the nature bus, the audio input, the dry motif bus), and every output
    // is clamped, so nothing can run away. at react 0 every product is 0:
    // +0, x1 and 0.45, exactly the v2 sound
    SynthDef(\est_react, {
      arg out, natIn, inIn, motifIn, react=0, src=4, listening=0, padBase=0.45;
      var d      = Lag.kr(react.clip(0, 1), 0.5);
      var sel    = src.round(1).clip(1, 4) - 1;
      var wN     = Select.kr(sel, [1, 0, 0, 1]);
      var wR     = Select.kr(sel, [0, 1, 0, 1]) * Lag.kr(listening.clip(0, 1), 1.0);
      var wS     = Select.kr(sel, [0, 0, 1, 1]);
      var water  = LagUD.kr(In.kr(natIn).linlin(0.3, 0.9, 0, 1), 3.0, 12.0) * (wN * d);
      var room   = LagUD.kr(In.kr(inIn).max(0.00001).ampdb.linlin(-48, -12, 0, 1), 2.5, 11.0) * (wR * d);
      var busyR  = LagUD.kr(In.kr(motifIn).max(0.00001).ampdb.linlin(-40, -20, 0, 1), 2.1, 10.5);
      var busy   = busyR * (wS * d);
      var sparse = (1 - busyR) * (wS * d);
      var bright = ((water * 0.22) + (room * 0.12)).clip(0, 0.3);
      var verb   = ((water * 0.4) + (sparse * 0.3)).clip(0, 0.5);
      var fb     = (room * 0.08).clip(0, 0.1);
      var duck   = 1 - ((busy * 0.27).clip(0, 0.3));
      var padB   = padBase + (((water * 0.3) + (room * 0.1)).clip(0, 0.35));
      ReplaceOut.kr(out, [bright, verb, fb, duck, padB]);
    }).add;

    // input key tracker (KeyTrack has tables for 44.1k and 48k)
    SynthDef(\est_listen, {
      arg in_l, in_r, keyOut, ampOut, keydecay=4;
      var sig   = (In.ar(in_l) + In.ar(in_r)) * 0.5;
      var chain = FFT(LocalBuf(4096), sig);
      Out.kr(keyOut, KeyTrack.kr(chain, keydecay, 0.5));
      Out.kr(ampOut, Amplitude.kr(sig, 0.05, 0.5));
    }).add;

    s.sync;

    motifMixSynth = Synth(\est_motifmix, [
      \in, motifBus.index, \out, mainBus.index, \ampOut, motifAmpBus.index
    ], fxGroup, \addToTail);
    padMixSynth = Synth(\est_padmix, [
      \in, padBus.index, \out, mainBus.index,
      \echoOut, echoBus.index, \verbOut, verbBus.index, \duckIn, (reactBus.index + 3)
    ], fxGroup, \addToTail);
    natFxSynth = Synth(\est_natfx, [
      \in, natBus.index, \out, mainBus.index, \verbOut, verbBus.index,
      \ampOut, natSumBus.index
    ], fxGroup, \addToTail);
    echoSynth = Synth(\est_echo, [
      \in, echoBus.index, \out, mainBus.index, \verbOut, verbBus.index, \fbIn, (reactBus.index + 2)
    ], fxGroup, \addToTail);
    verbSynth = Synth(\est_verb, [
      \in, verbBus.index, \out, mainBus.index, \sendIn, (reactBus.index + 1)
    ], fxGroup, \addToTail);
    listenSynth = Synth(\est_listen, [
      \in_l, context.in_b[0].index, \in_r, context.in_b[1].index,
      \keyOut, keyBus.index, \ampOut, inAmpBus.index
    ], fxGroup, \addToHead);
    listenSynth.run(false);
    // first in the fx chain, so this block's nudges reach the mixers
    reactSynth = Synth(\est_react, [
      \out, reactBus.index, \natIn, natSumBus.index, \inIn, inAmpBus.index,
      \motifIn, motifAmpBus.index
    ], fxGroup, \addToHead);
    masterSynth = Synth(\est_master, [
      \in, mainBus.index, \out, context.out_b.index, \ampOut, outBus.index
    ], fxGroup, \addToTail);

    // persistent synths by name; nature synths are registered as they appear
    fx = IdentityDictionary.new;
    fx.put(\padmix, padMixSynth);
    fx.put(\natfx, natFxSynth);
    fx.put(\echo, echoSynth);
    fx.put(\verb, verbSynth);
    fx.put(\master, masterSynth);
    fx.put(\react, reactSynth);
    fxVals = IdentityDictionary.new;

    // tweak keys: [node, arg]. node \st keeps the value for spawn time;
    // \bed \swell \moment are the nature slot synths (applied when they exist)
    fxMap = IdentityDictionary[
      \echo_time -> [\echo, \time],
      \echo_fb -> [\echo, \fb],
      \echo_tone -> [\echo, \tone],
      \echo_wow -> [\echo, \wow],
      \verb_size -> [\verb, \size],
      \verb_send -> [\verb, \send],
      \tone -> [\master, \tone],
      \level -> [\master, \level],
      \motif_level -> [\st, \motif_level],
      \pad_level -> [\padmix, \level],
      \pad_xfade -> [\st, \pad_xfade],
      \pad_sound -> [\st, \pad_sound],
      \pedal_level -> [\st, \pedal_level],
      \bed_level -> [\bed, \trim],
      \swell_level -> [\swell, \trim],
      \moment_level -> [\moment, \trim],
      \nature_tone -> [\natfx, \tone],
      \react -> [\react, \react],
      \react_src -> [\react, \src]
    ];

    // ------------------------------------------------------------- commands

    this.addCommand(\note, "fffffff", { |msg|
      var def = voiceDefs.clipAt(msg[1].asInteger - 1);
      var send = msg[7].clip(0, 1);
      // the water and the room brighten the note as it starts (+0 at react 0)
      var bright = (msg[6].clip(0, 1) + reactBus.getnSynchronous(5)[0]).clip(0, 1);
      Synth(def, [
        \out, motifBus.index, \echoOut, echoBus.index, \verbOut, verbBus.index,
        \freq, msg[2].midicps, \amp, ((msg[3].clip(0, 1) * 0.2) * st[\motif_level]), \vel, msg[3].clip(0, 1),
        \dur, msg[4].max(0.05), \pan, msg[5].clip(-1, 1), \bright, bright,
        \echo, (send * 0.7), \verb, (0.1 + (send * 0.8))
      ], voiceGroup);
    });

    this.addCommand(\pad, "ffff", { |msg|
      var old = padSynth;
      var xf = st[\pad_xfade].max(0.1);
      var f = msg[1..4].collect(_.midicps);
      if(old.notNil, { old.set(\rel, xf); old.set(\gate, 0) });
      padSynth = Synth(padDefs.clipAt(st[\pad_sound].asInteger - 1), [
        \out, padBus.index, \f1, f[0], \f2, f[1], \f3, f[2], \f4, f[3],
        \atk, xf, \rel, xf, \amp, 0.06, \bright, reactBus.subBus(4).asMap
      ], voiceGroup);
    });

    this.addCommand(\pedal, "fff", { |msg|
      var old = pedalSynth;
      if(old.notNil, { old.set(\gate, 0); pedalSynth = nil });
      if(msg[2] > 0, {
        var syn = Synth(\est_pedal, [
          \out, mainBus.index, \verbOut, verbBus.index,
          \freq, msg[1].midicps, \amp, ((msg[2].clip(0, 1) * 0.25) * st[\pedal_level]),
          \dur, msg[3].max(0.2)
        ], voiceGroup);
        pedalSynth = syn;
        syn.onFree({ if(pedalSynth === syn, { pedalSynth = nil }) });
      });
    });

    // nature loads are asynchronous (a disk read on the server). a play that
    // arrives while its slot is loading is held and applied by the load
    // itself, so load + play in one tick (as the script sends them) is heard.
    // a buffer is freed only once nothing plays it.
    this.addCommand(\nature_load, "is", { |msg|
      var slot = msg[1].asInteger.clip(1, 3) - 1;
      var path = msg[2].asString;
      var sf = SoundFile.new;
      if(sf.openRead(path), {
        var nc = sf.numChannels.min(2);
        var gen = natGen[slot] + 1;
        sf.close;
        natGen[slot] = gen;
        natLoading[slot] = true;
        natPending[slot] = nil;
        Buffer.readChannel(s, path, channels: if(nc == 1, { [0] }, { [0, 1] }), action: { |b|
          if(natGen[slot] != gen, {
            b.free;                       // a newer load took the slot
          }, {
            var old = natBufs[slot];
            var oldSynth = natSynths[slot];
            var pend = natPending[slot];
            natBufs[slot] = b;
            natLoading[slot] = false;
            natPending[slot] = nil;
            if(slot < 2, {
              // loop slots: a new silent player; the old one fades out first
              natSynths[slot] = Synth(("est_natloop" ++ nc).asSymbol, [
                \out, natBus.index, \buf, b, \ampOut, (natAmpBus.index + slot),
                \level, 0, \startPos, (b.numFrames * 1.0.rand)
              ], voiceGroup);
              this.prNatRegister(slot);
              natLevels[slot] = 0;
              if(oldSynth.notNil, {
                oldSynth.set(\level, 0, \fade, 0.3);
                SystemClock.sched(0.5, { oldSynth.free; if(old.notNil, { old.free }); nil });
              }, {
                if(old.notNil, { old.free });
              });
            }, {
              // the moment slot: the old buffer goes once no one-shot plays it
              if(old.notNil and: { (natOnceUse[old] ? 0) <= 0 }, { old.free });
            });
            if(pend.notNil, { this.prNatPlay(slot, pend[0], pend[1]) });
          });
        });
      }, {
        ("estuary: nature file not found: " ++ path).postln;
      });
    });

    this.addCommand(\nature_play, "iff", { |msg|
      var slot = msg[1].asInteger.clip(1, 3) - 1;
      var level = msg[2].clip(0, 1);
      var fade = msg[3].max(0.01);
      if(natLoading[slot], {
        natPending[slot] = [level, fade];
      }, {
        this.prNatPlay(slot, level, fade);
      });
    });

    this.addCommand(\listen, "f", { |msg|
      listenSynth.run(msg[1] > 0);
      reactSynth.set(\listening, if(msg[1] > 0, 1, 0));
    });

    this.addPoll(\in_key, { keyBus.getSynchronous });
    this.addPoll(\in_amp, { inAmpBus.getSynchronous });
    // the visuals' ears (see est_master / est_natfx)
    [\out_amp, \out_lo, \out_mid, \out_hi].do { |name, i|
      this.addPoll(name, { outBus.getnSynchronous(4)[i] });
    };
    this.addPoll(\nat_amp, { natSumBus.getSynchronous });

    this.addCommand(\tweak, "sf", { |msg|
      var key = msg[1].asSymbol;
      var val = msg[2];
      var dest = fxMap[key];
      if(dest.notNil, {
        if(dest[0] == \st, {
          st.put(dest[1], val);
        }, {
          var node = fx[dest[0]];
          if(fxVals[dest[0]].isNil, { fxVals[dest[0]] = IdentityDictionary.new });
          fxVals[dest[0]].put(dest[1], val);
          if(node.notNil, { node.set(dest[1], val) });
        });
      });
    });
  }

  // a nature slot to `level` over `fade` s. loops (1, 2) restart from a
  // random place when rising from silence; slot 3 starts a one-shot (level 0
  // stops it)
  prNatPlay { arg slot, level, fade;
    var b = natBufs[slot];
    var node = natSynths[slot];
    if(b.notNil, {
      if(slot < 2, {
        if(node.notNil, {
          if((level > 0) and: { natLevels[slot] <= 0.001 }, {
            node.set(\startPos, (b.numFrames * 1.0.rand), \t_rst, 1);
          });
          node.set(\level, level, \fade, fade);
          natLevels[slot] = level;
        });
      }, {
        if(node.notNil, {
          node.set(\level, 0, \fade, fade);
          SystemClock.sched((fade + 0.2), { if(node.isPlaying, { node.free }); nil });
          natSynths[slot] = nil;
          fx.removeAt(\moment);
        });
        if(level > 0, {
          var nc = b.numChannels;
          var syn = Synth(("est_natonce" ++ nc).asSymbol, [
            \out, natBus.index, \buf, b, \ampOut, (natAmpBus.index + 2),
            \level, 0, \dur, (b.numFrames / b.sampleRate)
          ], voiceGroup);
          natSynths[slot] = syn;
          natOnceUse[b] = (natOnceUse[b] ? 0) + 1;
          this.prNatRegister(slot);
          syn.set(\level, level, \fade, fade);
          syn.onFree({
            natOnceUse[b] = natOnceUse[b] - 1;
            if(natSynths[2] === syn, { natSynths[2] = nil; fx.removeAt(\moment) });
            // a buffer a newer load replaced goes with its last one-shot
            if((natOnceUse[b] <= 0) and: { natBufs[2] !== b }, { natOnceUse.removeAt(b); b.free });
          });
        });
      });
    });
  }

  // register a nature slot synth under its tweak name and apply stored trim
  prNatRegister { arg slot;
    var name = [\bed, \swell, \moment][slot];
    var node = natSynths[slot];
    var vals = fxVals[name];
    fx.put(name, node);
    if(vals.notNil, { vals.keysValuesDo { |k, v| node.set(k, v) } });
  }

  free {
    voiceGroup.free;
    fxGroup.free;
    mainBus.free;
    echoBus.free;
    verbBus.free;
    padBus.free;
    natBus.free;
    keyBus.free;
    inAmpBus.free;
    natAmpBus.free;
    outBus.free;
    natSumBus.free;
    motifBus.free;
    motifAmpBus.free;
    reactBus.free;
    natBufs.do { |b| if(b.notNil, { b.free }) };
  }
}
