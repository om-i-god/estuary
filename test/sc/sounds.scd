// sounds v2 checks, loaded by run.scd after the smoke test (inside its
// routine, with ~eng, ~root and ~demoDir set):
//   - the engine's voice / pad lists match lib/palettes.lua (VOICES, PADS)
//   - every motif voice alone, at 3 pitches x 3 brightnesses: RMS over the
//     note, peak, NaN, onset; at each brightness the voices' RMS (mean over
//     the pitches) must sit within 3 dB of each other
//   - every pad character alone on one chord: RMS within 3 dB of each other
//   - `tweak pad_sound` + `pad`: the next voicing is the new character and
//     the old one releases (crossfade, no cut)
//   - a ~24 s demo wav per palette in ~demoDir (palettes parsed from
//     lib/palettes.lua), each checked for peak, NaN and level
// lines: CHECK ... (FAILED on a miss), SOUNDS ok / SOUNDS FAILED at the end
var s = Server.default;
var sr = s.sampleRate;
var fails = 0;
var fail = { |what| fails = fails + 1; ("CHECK FAILED " ++ what).postln };
var dbs = { |x| x.max(1e-9).ampdb };
var loadArr = { |b|
  var c = Condition.new, res;
  b.loadToFloatArray(action: { |a| res = a; c.test = true; c.signal });
  c.wait;
  res
};
var src = File.readAllString(~root +/+ "lib/palettes.lua");
var listOf = { |key|
  var line = src.split($\n).detect { |l| l.beginsWith("P." ++ key ++ " = {") };
  line.findRegexp("\"([a-z]+)\"").select { |m, i| i.odd }.collect { |m| m[1] };
};
var voices = listOf.("VOICES"), pads = listOf.("PADS");
var palettes = src.split($\n).select { |l| l.contains("{name = \"") }.collect { |l|
  var q = l.findRegexp("\"([a-z]+)\"").select { |m, i| i.odd }.collect { |m| m[1] };
  var num = { |k| var m = l.findRegexp(k ++ " = (-?[0-9.]+)"); m[1][1].asFloat };
  (name: q[0], voices: q[1..4], pad: q[5], bright: num.("bright"), send: num.("send"))
};
var junk = Bus.audio(s, 2);
// run synths in parallel, each on its own bus into its own buffer; returns
// per item [rms (window), peak, nan, onset ratio]
var measure = { |items, secs, w0, w1|
  var g = Group.tail(s);
  var runs = items.collect { |it| [it, Bus.audio(s, 2), Buffer.alloc(s, (sr * secs).asInteger, 2)] };
  var out;
  s.sync;
  s.bind {
    runs.do { |r| Synth(\snd_rec, [\in, r[1].index, \buf, r[2]], g, \addToTail) };
    runs.do { |r| Synth(r[0][0], [\out, r[1].index, \echoOut, junk.index, \verbOut, junk.index] ++ r[0][1], g, \addToHead) };
  };
  (secs + 0.5).wait;
  out = runs.collect { |r|
    var a = loadArr.(r[2]);
    var n0 = (w0 * sr).asInteger * 2, n1 = ((w1 * sr).asInteger * 2).min(a.size);
    var seg = a.copyRange(n0, n1 - 1);
    var nan = a.any { |x| x.isNaN or: { x.abs == inf } };
    var peak = a.abs.maxItem;
    var first = a.copyRange(0, ((sr * 0.001).asInteger * 2) - 1).abs.maxItem;
    r[1].free; r[2].free;
    [(seg.squared.sum / seg.size.max(1)).sqrt, peak, nan, first / peak.max(1e-9)]
  };
  g.free;
  out
};

SynthDef(\snd_rec, { arg in, buf;
  RecordBuf.ar(In.ar(in, 2), buf, loop: 0, doneAction: 2);
}).add;
s.sync;

// ------------------------------------------------------------ the lists
if(voices.collect { |v| ("est_" ++ v).asSymbol } == ~eng.voiceDefs.asArray, {
  ("CHECK voice list matches palettes.lua (" ++ voices.size ++ " voices)").postln;
}, { fail.("voice list: engine " ++ ~eng.voiceDefs ++ " palettes.lua " ++ voices) });
if(pads.collect { |v| ("est_pad_" ++ v).asSymbol } == ~eng.padDefs.asArray, {
  ("CHECK pad list matches palettes.lua (" ++ pads.size ++ " pads)").postln;
}, { fail.("pad list: engine " ++ ~eng.padDefs ++ " palettes.lua " ++ pads) });
(~eng.voiceDefs ++ ~eng.padDefs ++ [\est_pedal]).do { |d|
  var desc = SynthDescLib.global[d];
  if(desc.isNil, { fail.("no SynthDef " ++ d) }, {
    ("CHECK ugens " ++ d ++ " " ++ desc.def.children.size ++ " (audio rate "
      ++ desc.def.children.count { |u| u.rate == \audio } ++ ")").postln;
  });
};
palettes.do { |p|
  if(((p[\voices] ++ [p[\pad]]).every { |n| voices.includesEqual(n) or: { pads.includesEqual(n) } }).not
    or: { pads.includesEqual(p[\pad]).not }, { fail.("palette " ++ p[\name] ++ " names an unknown sound") });
};
("CHECK " ++ palettes.size ++ " palettes parsed").postln;
if(palettes.size < 6, { fail.("fewer than 6 palettes") });

// ------------------------------------------------------------ motif voices
// vel 0.6 at motif level 1 (the engine's amp = vel * 0.2), a 1.5 s note;
// RMS over the note and its first second of tail
{
  var vel = 0.6, dur = 1.5, brights = [0.2, 0.5, 0.9], midis = [60, 67, 74];
  var items = List.new, keys = List.new, res, table = Dictionary.new;
  ~eng.voiceDefs.do { |d|
    brights.do { |b|
      midis.do { |m|
        items.add([d, [\freq, m.midicps, \amp, vel * 0.2, \vel, vel, \dur, dur, \pan, 0, \bright, b, \echo, 0, \verb, 0]]);
        keys.add([d, b, m]);
      };
    };
  };
  res = measure.(items, dur + 1.6, 0, dur + 1.0);
  keys.do { |k, i|
    var r = res[i];
    if(r[2], { fail.("NaN in " ++ k) });
    if(r[1] >= 1.0, { fail.("clipping in " ++ k ++ " peak " ++ r[1]) });
    if(r[3] > 0.2, { fail.("hard onset in " ++ k ++ ": " ++ r[3].round(0.01) ++ " of peak in the first ms") });
    table[[k[0], k[1]]] = (table[[k[0], k[1]]] ? []) ++ [r];
  };
  "CHECK voice RMS dB (mean of midi 60/67/74; peak dBFS at bright 0.5)".postln;
  "CHECK   voice        b0.2    b0.5    b0.9   peak".postln;
  ~voiceRms = Dictionary.new;
  ~eng.voiceDefs.do { |d|
    var row = brights.collect { |b| table[[d, b]].collect { |r| dbs.(r[0]) }.mean };
    var pk = table[[d, 0.5]].collect { |r| r[1] }.maxItem;
    ~voiceRms[d] = row;
    ("CHECK   " ++ d.asString.drop(4).padRight(10) ++ row.collect { |x| x.round(0.1).asString.padLeft(8) }.join
      ++ dbs.(pk).round(0.1).asString.padLeft(7)).postln;
  };
  brights.do { |b, j|
    var col = ~eng.voiceDefs.collect { |d| ~voiceRms[d][j] };
    var spread = col.maxItem - col.minItem;
    ("CHECK voice spread at bright " ++ b ++ ": " ++ spread.round(0.01) ++ " dB"
      ++ (if(spread <= 3.0, { " ok" }, { " FAILED (> 3 dB)" }))).postln;
    if(spread > 3.0, { fails = fails + 1 });
  };
  // brightness changes timbre more than level: each voice stays within 4 dB
  // from bright 0.2 to 0.9
  ~eng.voiceDefs.do { |d|
    var row = ~voiceRms[d];
    if((row.maxItem - row.minItem) > 4.0, { fail.(d ++ " level moves " ++ (row.maxItem - row.minItem).round(0.1) ++ " dB with brightness") });
  };
}.value;

// ------------------------------------------------------------ pads
{
  var f = [48, 55, 62, 67].midicps, items, res;
  items = ~eng.padDefs.collect { |d|
    [d, [\f1, f[0], \f2, f[1], \f3, f[2], \f4, f[3], \amp, 0.06, \bright, 0.45, \atk, 0.5, \rel, 0.5]]
  };
  res = measure.(items, 4.0, 1.0, 4.0);
  "CHECK pad RMS dB (chord 48 55 62 67, bright 0.45, after the attack)".postln;
  ~padRms = res.collect { |r| dbs.(r[0]) };
  ~eng.padDefs.do { |d, i|
    var r = res[i];
    if(r[2], { fail.("NaN in " ++ d) });
    if(r[1] >= 1.0, { fail.("clipping in " ++ d) });
    if(r[3] > 0.05, { fail.("hard onset in " ++ d) });
    ("CHECK   " ++ d.asString.drop(8).padRight(10) ++ ~padRms[i].round(0.1).asString.padLeft(8)
      ++ "  peak " ++ dbs.(r[1]).round(0.1)).postln;
  };
  {
    var spread = ~padRms.maxItem - ~padRms.minItem;
    ("CHECK pad spread: " ++ spread.round(0.01) ++ " dB" ++ (if(spread <= 3.0, { " ok" }, { " FAILED (> 3 dB)" }))).postln;
    if(spread > 3.0, { fails = fails + 1 });
  }.value;
}.value;

// ------------------------------------------------------------ the pedal
{
  var r = measure.([[\est_pedal, [\freq, 36.midicps, \amp, 0.5 * 0.25, \dur, 2]]], 1.0, 0, 1.0)[0];
  if(r[2] or: { r[1] >= 1.0 } or: { r[3] > 0.05 }, { fail.("pedal: nan/clip/onset " ++ r) });
  ("CHECK pedal rms " ++ dbs.(r[0]).round(0.1) ++ " dB  onset " ++ r[3].round(0.001)).postln;
}.value;

// ------------------------------------------------------------ pad_sound crossfade
{
  var old, nw;
  ~eng.cmd(\tweak, "pad_xfade", 0.4);
  ~eng.cmd(\tweak, "pad_sound", 3);
  ~eng.cmd(\pad, 48, 55, 62, 67);
  s.sync;
  old = ~eng.padSynth;
  NodeWatcher.register(old, true);
  if(old.defName.asSymbol != \est_pad_glass, { fail.("pad_sound 3 played " ++ old.defName) });
  0.5.wait;
  ~eng.cmd(\tweak, "pad_sound", 2);
  ~eng.cmd(\pad, 50, 57, 64, 69);
  s.sync;
  nw = ~eng.padSynth;
  NodeWatcher.register(nw, true);
  if(nw.defName.asSymbol != \est_pad_strings, { fail.("pad_sound 2 played " ++ nw.defName) });
  0.2.wait;
  if(old.isPlaying.not, { fail.("the old pad was cut, not crossfaded") });
  0.6.wait;
  if(old.isPlaying, { fail.("the old pad never released") });
  if(nw.isPlaying.not, { fail.("the new pad stopped") });
  ~eng.cmd(\tweak, "pad_sound", 99);     // out of range: clipped, never an error
  ~eng.cmd(\pad, 48, 55, 62, 67);
  s.sync;
  if(~eng.padSynth.defName.asSymbol != ~eng.padDefs.last, { fail.("pad_sound 99 not clipped") });
  ~eng.cmd(\tweak, "pad_sound", 1);
  ~eng.cmd(\pad, 0, 0, 0, 0);
  ~eng.cmd(\tweak, "pad_level", 0);
  "CHECK pad_sound crossfade".postln;
}.value;

// ------------------------------------------------------------ palette demos
// one engine per palette, all at once, each recorded from its own out bus
if(~demoDir.notNil, {
  var engs, recs, paths, c = Condition.new, ready = 0;
  var ev = [
    // [secs, slot, midi, dur]
    [0.8, 1, 64, 1.2], [2.0, 1, 67, 1.0], [3.2, 1, 69, 1.6], [5.0, 1, 67, 1.0], [6.2, 1, 64, 2.0],
    [4.0, 2, 79, 1.0], [4.8, 2, 76, 1.4], [7.0, 2, 74, 1.0], [7.8, 2, 76, 2.0],
    [10.0, 3, 60, 1.4], [11.4, 3, 64, 1.0], [12.4, 3, 67, 1.6], [14.4, 3, 64, 1.2], [15.6, 3, 60, 2.0],
    [12.0, 4, 84, 1.0], [13.0, 4, 79, 1.2], [16.4, 4, 81, 1.0], [17.2, 4, 79, 2.0],
    [17.6, 1, 69, 2.0]
  ].sort { |a, b| a[0] < b[0] };
  File.mkdir(~demoDir);
  engs = palettes.collect { |p|
    var ctx = (server: s, xg: Group.tail(s), in_b: [Bus.audio(s, 1), Bus.audio(s, 1)], out_b: Bus.audio(s, 2));
    Engine_Estuary.new(ctx, { ready = ready + 1; if(ready == palettes.size, { c.test = true; c.signal }) });
  };
  c.wait;
  s.sync;
  paths = palettes.collect { |p, i| ~demoDir +/+ ("palette_" ++ (i + 1) ++ "_" ++ p[\name] ++ ".wav") };
  recs = engs.collect { |e, i|
    var r = Recorder(s);
    r.recHeaderFormat = "wav";
    r.recSampleFormat = "int24";
    r.record(paths[i], e.context.out_b.index, 2);
    r
  };
  1.0.wait;
  engs.do { |e, i|
    var p = palettes[i];
    e.cmd(\tweak, "pad_xfade", 2.5);
    e.cmd(\tweak, "pad_sound", pads.indexOfEqual(p[\pad]) + 1);
    e.cmd(\pad, 48, 55, 62, 64);
    e.cmd(\pedal, 36, 0.5, 9);
  };
  {
    var t = 0, chord2 = false;
    ev.do { |x|
      if(chord2.not and: { x[0] >= 9.5 }, {
        (9.5 - t).wait; t = 9.5; chord2 = true;
        engs.do { |e| e.cmd(\pad, 53, 57, 60, 64); e.cmd(\pedal, 41, 0.5, 9) };
      });
      (x[0] - t).wait; t = x[0];
      engs.do { |e, i|
        var p = palettes[i];
        var v = voices.indexOfEqual(p[\voices][x[1] - 1]) + 1;
        var pan = if(x[1].odd, { -0.35 }, { 0.35 });
        e.cmd(\note, v, x[2], 0.6, x[3], pan, (0.55 + p[\bright]).clip(0, 1), (0.5 * p[\send]).clip(0, 1));
      };
    };
    (20 - t).wait;
  }.value;
  engs.do { |e| e.cmd(\pad, 0, 0, 0, 0); e.cmd(\tweak, "pad_level", 0); e.cmd(\pedal, 0, 0, 0) };
  4.wait;
  recs.do(_.stopRecording);
  1.0.wait;
  paths.do { |path, i|
    SoundFile.use(path, { |f|
      var d = FloatArray.newClear(f.numFrames * f.numChannels), pk, rms, nan;
      f.readData(d);
      pk = d.abs.maxItem;
      rms = (d.squared.sum / d.size.max(1)).sqrt;
      nan = d.any { |x| x.isNaN };
      ("CHECK demo " ++ palettes[i][\name].padRight(11) ++ " peak " ++ dbs.(pk).round(0.1) ++ " dB  rms "
        ++ dbs.(rms).round(0.1) ++ " dB  " ++ (f.numFrames / f.sampleRate).round(0.1) ++ " s  " ++ path).postln;
      if(nan or: { pk >= 1.0 } or: { dbs.(rms) < -45 }, { fail.("demo " ++ palettes[i][\name]) });
    });
  };
  engs.do { |e| e.free; e.context.xg.free };
});

("SOUNDS " ++ (if(fails == 0, { "ok" }, { "FAILED " ++ fails }))).postln;
