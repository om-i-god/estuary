// Engine_Estuary
//
// Soft, warm, spacious voices for an ambient set. No saturation anywhere;
// the only dynamics processor is a Limiter at the master.
//
// signal flow
//   voices -> mainBus (dry), echoBus (send), verbBus (send)
//   pad    -> padBus  -> est_padmix -> mainBus/echoBus/verbBus
//   nature -> natBus  -> est_natfx  -> mainBus/verbBus
//   est_echo (ping-pong) -> mainBus + verbBus
//   est_verb (hall) -> mainBus ;  est_master -> hardware out
//
// NOTE: sclang binary operators have no precedence (strict left-to-right),
// so every compound expression below is fully parenthesized.
//
// commands (formats are parsed by the headless sim, keep them literal)
//   note        voice midi vel dur pan bright send   (voice 1 rhodes 2 bell 3 sine 4 marimba)
//   pad         m1 m2 m3 m4     (crossfades from the current pad over pad_xfade s)
//   pedal       midi vel dur
//   nature_load slot path       (1 bed, 2 swell, 3 moment)
//   nature_play slot level fade (1/2 loop from a random position when rising
//                                from silence; 3 one-shot, level 0 stops it)
//   listen      on              (key tracker on the audio input)
//   tweak       key val
//
// polls
//   in_key  KeyTrack estimate of the audio input: 0-11 C..B major, 12-23 C..B minor
//   in_amp  input amplitude

Engine_Estuary : CroneEngine {
  var voiceGroup, fxGroup;
  var mainBus, echoBus, verbBus, padBus, natBus;
  var keyBus, inAmpBus, natAmpBus;
  var padSynth, padMixSynth, natFxSynth, echoSynth, verbSynth, masterSynth, listenSynth;
  var natBufs, natSynths, natLevels;
  var st, fx, fxMap, fxVals;

  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }

  // last measured amplitude of a nature slot (1..3); used by the test
  natAmp { arg slot;
    ^natAmpBus.getSynchronous(slot - 1);
  }

  alloc {
    var s = context.server;
    // 0..1 -> log-scaled Hz; values above 1 are taken as Hz already
    var toHz = { arg v, lo, hi;
      var u = v.clip(0, 1);
      Select.kr(v > 1, [u.linexp(0, 1, lo, hi), v.clip(lo, hi)])
    };

    mainBus  = Bus.audio(s, 2);
    echoBus  = Bus.audio(s, 2);
    verbBus  = Bus.audio(s, 2);
    padBus   = Bus.audio(s, 2);
    natBus   = Bus.audio(s, 2);
    keyBus    = Bus.control(s, 1);
    inAmpBus  = Bus.control(s, 1);
    natAmpBus = Bus.control(s, 3);

    voiceGroup = Group.head(context.xg);
    fxGroup    = Group.after(voiceGroup);

    natBufs   = Array.fill(3, nil);
    natSynths = Array.fill(3, nil);
    natLevels = Array.fill(3, 0);

    // values read at spawn time (set via `tweak`)
    st = IdentityDictionary.new;
    st.put(\motif_level, 1.0);
    st.put(\pedal_level, 1.0);
    st.put(\pad_xfade, 4.0);

    // ---------------------------------------------------------------- voices

    // electric piano: 2-op FM, ratio 1, index decaying 3 -> 0.5, slow tremolo
    SynthDef(\est_rhodes, {
      arg out, echoOut, verbOut, freq=261, amp=0.2, dur=1, pan=0, bright=0.5, echo=0.3, verb=0.3;
      var idx  = XLine.kr((0.8 + (bright * 2.2)), 0.5, 1.4);
      var mod  = SinOsc.ar(freq, 0, idx * 0.5);
      var car  = SinOsc.ar(freq, mod);
      var trem = (1 + (0.07 * SinOsc.kr(4.5, Rand(0, 2pi))));
      var env  = EnvGen.kr(Env([0, 1, 0.55, 0], [0.006, (dur * 0.5), (dur * 0.9) + 0.9], [-2, -2, -4]), doneAction: 2);
      var sig  = car * env * trem * amp;
      sig = LPF.ar(sig, (2200 + (bright * 5500)));
      sig = Pan2.ar(sig, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // glassy bell: 2-op FM ratio 3.5, soft index, long tail
    SynthDef(\est_bell, {
      arg out, echoOut, verbOut, freq=523, amp=0.2, dur=1, pan=0, bright=0.5, echo=0.3, verb=0.3;
      var idx = XLine.kr((0.5 + (bright * 0.9)), 0.15, 2.0);
      var mod = SinOsc.ar((freq * 3.5), 0, idx);
      var car = SinOsc.ar(freq, mod);
      var env = EnvGen.kr(Env([0, 1, 0], [0.004, dur + 2.2], [-2, -5]), doneAction: 2);
      var sig = car * env * amp * 0.8;
      sig = LPF.ar(sig, (3000 + (bright * 6000)));
      sig = Pan2.ar(sig, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // pure sine with a slow 30-80 ms attack
    SynthDef(\est_sine, {
      arg out, echoOut, verbOut, freq=261, amp=0.2, dur=1, pan=0, bright=0.5, echo=0.3, verb=0.3;
      var atk = (0.08 - (bright * 0.05));
      var env = EnvGen.kr(Env([0, 1, 0.7, 0], [atk, dur * 0.4, (dur * 0.6) + 0.6], [2, -2, -3]), doneAction: 2);
      var sig = SinOsc.ar(freq) + (SinOsc.ar((freq * 2)) * 0.15 * bright);
      sig = Pan2.ar(sig * env * amp, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // marimba: modal bank struck by a soft impulse
    SynthDef(\est_marimba, {
      arg out, echoOut, verbOut, freq=261, amp=0.2, dur=1, pan=0, bright=0.5, echo=0.3, verb=0.3;
      var ex  = LPF.ar(Decay.ar(Impulse.ar(0), 0.004, 0.5), (2500 + (bright * 5000)));
      var sig = DynKlank.ar(`[
        [freq, (freq * 3.93), (freq * 9.2)].min(14000),
        [1, 0.22, 0.05],
        [1.1, 0.35, 0.12]
      ], ex);
      var env = EnvGen.kr(Env.linen(0, dur + 1.3, 0.3), doneAction: 2);
      sig = Pan2.ar(sig * env * amp * 0.7, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // pad: four detune-free tri+sine voices through a gentle low-pass.
    // gate 0 releases it over `rel` s, so two pads crossfade.
    SynthDef(\est_pad, {
      arg out, f1=130, f2=196, f3=293, f4=392, amp=0.08, bright=0.5, atk=4, rel=4, gate=1;
      var env = EnvGen.kr(Env.asr(atk, 1, rel, [2, -2]), gate, doneAction: 2);
      var cut = (800 + (bright * 2700)) * (1 + (0.05 * SinOsc.kr(0.07, Rand(0, 2pi))));
      var sig = [f1, f2, f3, f4].collect { |f, i|
        var v = (LFTri.ar(f) * 0.5) + (SinOsc.ar(f) * 0.5) + (SinOsc.ar((f * 0.5)) * 0.2);
        Pan2.ar(v, [-0.5, -0.17, 0.17, 0.5][i]);
      };
      sig = Mix(sig);
      sig = LPF.ar(LPF.ar(sig, cut), (cut * 1.5));
      Out.ar(out, sig * env * amp);
    }).add;

    // pad mixer: level, plus sends
    SynthDef(\est_padmix, {
      arg in, out, echoOut, verbOut, level=1, echo=0.25, verb=0.5;
      var sig = In.ar(in, 2) * Lag.kr(level, 0.3);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // pedal: low sine plus a quiet octave above
    SynthDef(\est_pedal, {
      arg out, verbOut, freq=65, amp=0.2, dur=4;
      var env = EnvGen.kr(Env([0, 1, 0.8, 0], [0.06, dur, (dur * 0.3).max(1.5)], [2, -1, -3]), doneAction: 2);
      var sig = (SinOsc.ar(freq) + (SinOsc.ar((freq * 2)) * 0.25)) * env * amp;
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

    // nature tone + sends
    SynthDef(\est_natfx, {
      arg in, out, verbOut, tone=0.7, verb=0.2;
      var sig = In.ar(in, 2);
      sig = LPF.ar(sig, Lag.kr(toHz.value(tone, 800, 16000), 0.3));
      sig = HPF.ar(sig, 40) * 0.5;
      Out.ar(out, sig);
      Out.ar(verbOut, sig * verb);
    }).add;

    // ----------------------------------------------------------------- fx

    // ping-pong echo, clean: tone and hp filters in the loop, slow wow
    SynthDef(\est_echo, {
      arg in, out, verbOut, time=0.83, fb=0.45, tone=0.5, wow=0.0008, level=0.7, verb=0.35;
      var src = In.ar(in, 2);
      var t   = Lag.kr(time, 0.4).clip(0.02, 3.5);
      var mod = SinOsc.kr([0.31, 0.37], [0, 1]) * wow.clip(0, 0.002);
      var loop = LocalIn.ar(1);
      var dl  = DelayC.ar((Mix(src) * 0.7) + (loop * fb.clip(0, 0.85)), 4, (t + mod[0]).clip(0.01, 3.9));
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
      arg in, out, size=0.95, damp=0.55, level=0.8, send=1;
      var sig = In.ar(in, 2) * send;
      sig = DelayN.ar(sig, 0.1, 0.04);
      [0.013, 0.017, 0.023, 0.031].do { |dt|
        sig = AllpassC.ar(sig, 0.08, (dt * [1, 1.13]) + (LFNoise2.kr([0.1, 0.11]) * 0.0008), 1.8);
      };
      sig = FreeVerb2.ar(sig[0], sig[1], 1, Lag.kr(size, 1).clip(0, 1), damp);
      sig = HPF.ar(sig, 120);
      sig = LPF.ar(sig, 7500);
      Out.ar(out, sig * level);
    }).add;

    // master: tone, level, limiter at -1 dBFS (no saturation)
    SynthDef(\est_master, {
      arg in, out, level=0.9, tone=0.75;
      var sig = In.ar(in, 2);
      sig = HPF.ar(sig, 25);
      sig = LPF.ar(sig, Lag.kr(toHz.value(tone, 2500, 16000), 0.3));
      sig = Limiter.ar(sig * level, 0.89, 0.01);
      Out.ar(out, sig);
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

    padMixSynth = Synth(\est_padmix, [
      \in, padBus.index, \out, mainBus.index,
      \echoOut, echoBus.index, \verbOut, verbBus.index
    ], fxGroup, \addToTail);
    natFxSynth = Synth(\est_natfx, [
      \in, natBus.index, \out, mainBus.index, \verbOut, verbBus.index
    ], fxGroup, \addToTail);
    echoSynth = Synth(\est_echo, [
      \in, echoBus.index, \out, mainBus.index, \verbOut, verbBus.index
    ], fxGroup, \addToTail);
    verbSynth = Synth(\est_verb, [
      \in, verbBus.index, \out, mainBus.index
    ], fxGroup, \addToTail);
    listenSynth = Synth(\est_listen, [
      \in_l, context.in_b[0].index, \in_r, context.in_b[1].index,
      \keyOut, keyBus.index, \ampOut, inAmpBus.index
    ], fxGroup, \addToHead);
    listenSynth.run(false);
    masterSynth = Synth(\est_master, [
      \in, mainBus.index, \out, context.out_b.index
    ], fxGroup, \addToTail);

    // persistent synths by name; nature synths are registered as they appear
    fx = IdentityDictionary.new;
    fx.put(\padmix, padMixSynth);
    fx.put(\natfx, natFxSynth);
    fx.put(\echo, echoSynth);
    fx.put(\verb, verbSynth);
    fx.put(\master, masterSynth);
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
      \pedal_level -> [\st, \pedal_level],
      \bed_level -> [\bed, \trim],
      \swell_level -> [\swell, \trim],
      \moment_level -> [\moment, \trim],
      \nature_tone -> [\natfx, \tone]
    ];

    // ------------------------------------------------------------- commands

    this.addCommand(\note, "fffffff", { |msg|
      var def = [\est_rhodes, \est_bell, \est_sine, \est_marimba].clipAt(msg[1].asInteger - 1);
      var send = msg[7].clip(0, 1);
      Synth(def, [
        \out, mainBus.index, \echoOut, echoBus.index, \verbOut, verbBus.index,
        \freq, msg[2].midicps, \amp, ((msg[3].clip(0, 1) * 0.2) * st[\motif_level]),
        \dur, msg[4].max(0.05), \pan, msg[5].clip(-1, 1), \bright, msg[6].clip(0, 1),
        \echo, (send * 0.7), \verb, (0.1 + (send * 0.8))
      ], voiceGroup);
    });

    this.addCommand(\pad, "ffff", { |msg|
      var old = padSynth;
      var xf = st[\pad_xfade].max(0.1);
      var f = msg[1..4].collect(_.midicps);
      if(old.notNil, { old.set(\rel, xf); old.set(\gate, 0) });
      padSynth = Synth(\est_pad, [
        \out, padBus.index, \f1, f[0], \f2, f[1], \f3, f[2], \f4, f[3],
        \atk, xf, \rel, xf, \amp, 0.06, \bright, 0.45
      ], voiceGroup);
    });

    this.addCommand(\pedal, "fff", { |msg|
      Synth(\est_pedal, [
        \out, mainBus.index, \verbOut, verbBus.index,
        \freq, msg[1].midicps, \amp, ((msg[2].clip(0, 1) * 0.25) * st[\pedal_level]),
        \dur, msg[3].max(0.2)
      ], voiceGroup);
    });

    this.addCommand(\nature_load, "is", { |msg|
      var slot = msg[1].asInteger.clip(1, 3) - 1;
      var path = msg[2].asString;
      var sf = SoundFile.new;
      if(sf.openRead(path), {
        var nc = sf.numChannels.min(2);
        sf.close;
        Buffer.readChannel(s, path, channels: if(nc == 1, { [0] }, { [0, 1] }), action: { |b|
          var old = natBufs[slot];
          var oldSynth = natSynths[slot];
          natBufs[slot] = b;
          if(slot < 2, {
            // loop slots: a persistent silent player, replaced in place
            if(oldSynth.notNil, { oldSynth.free });
            natSynths[slot] = Synth(("est_natloop" ++ nc).asSymbol, [
              \out, natBus.index, \buf, b, \ampOut, (natAmpBus.index + slot),
              \level, 0, \startPos, (b.numFrames * 1.0.rand)
            ], voiceGroup);
            this.prNatRegister(slot);
            natLevels[slot] = 0;
          });
          if(old.notNil, { old.free });
        });
      }, {
        ("estuary: nature file not found: " ++ path).postln;
      });
    });

    this.addCommand(\nature_play, "iff", { |msg|
      var slot = msg[1].asInteger.clip(1, 3) - 1;
      var level = msg[2].clip(0, 1);
      var fade = msg[3].max(0.01);
      var b = natBufs[slot];
      var node = natSynths[slot];
      if(b.notNil, {
        if(slot < 2, {
          if(node.notNil, {
            if((level > 0) and: { natLevels[slot] <= 0.001 }, {
              // rising from silence: restart from a random position
              node.set(\startPos, (b.numFrames * 1.0.rand), \t_rst, 1);
            });
            node.set(\level, level, \fade, fade);
            natLevels[slot] = level;
          });
        }, {
          if(node.notNil, {
            node.set(\level, 0, \fade, fade);
            SystemClock.sched((fade + 0.2), { node.free; nil });
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
            this.prNatRegister(slot);
            syn.set(\level, level, \fade, fade);
            syn.onFree({
              if(natSynths[2] === syn, { natSynths[2] = nil; fx.removeAt(\moment) });
            });
          });
        });
      });
    });

    this.addCommand(\listen, "f", { |msg|
      listenSynth.run(msg[1] > 0);
    });

    this.addPoll(\in_key, { keyBus.getSynchronous });
    this.addPoll(\in_amp, { inAmpBus.getSynchronous });

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
    natBufs.do { |b| if(b.notNil, { b.free }) };
  }
}
