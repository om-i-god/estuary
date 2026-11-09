// sounds v3 checks: everything listening. loaded by run.scd after
// sounds.scd (inside its routine, with ~root and ~demoDir set):
//   - neutral: at react 0, with every source pushed to the top, every nudge
//     on the react bus is exactly neutral (+0, x1, pad bright 0.45)
//   - null: the v2 engine (test/sc/run.sh compiles it from git as
//     Engine_EstuaryV2 with v2est_ SynthDefs) and this one, rendered in NRT
//     from the same score with the same random seed: at react 0 they null;
//     at react 0.8 they must not (the test has teeth)
//   - water: at react 0.8, a loud nature level brightens the music (the
//     share of energy above 2.5 kHz) and widens the reverb send
//   - room: in_amp, while listening, brightens and adds echo feedback; it
//     lets go when listening stops
//   - self: busy motifs duck the pad (2-3 dB at most), sparse ones open the
//     reverb; the followers are slow
//   - runaway: 60 s with everything at max, the output fed back into the
//     input (a room mic hearing the speakers): bounded, no NaN, the nudges
//     stay inside their clamps, the level does not climb
//   - a react demo: one palette under a water swell, react 0 and react 0.8
// lines: CHECK ... (FAILED on a miss), REACT ok / REACT FAILED at the end
var s = Server.default;
var sr = s.sampleRate;
var fails = 0;
var fail = { |what| fails = fails + 1; ("CHECK FAILED " ++ what).postln };
var dbs = { |x| x.max(1e-9).ampdb };
var fix = ~root +/+ "test/sc/fixtures/";
var tmp = "TMPDIR".getenv ? "/tmp";
var mkEngs = { |cls, n|
  var c = Condition.new, ready = 0, es;
  es = n.collect {
    var ctx = (server: s, xg: Group.tail(s), in_b: [Bus.audio(s, 1), Bus.audio(s, 1)], out_b: Bus.audio(s, 2));
    cls.new(ctx, { ready = ready + 1; if(ready == n, { c.test = true; c.signal }) });
  };
  c.wait;
  s.sync;
  es
};
var freeEng = { |e| e.free; e.context.xg.free };
var vals = { |e| e.reactVals.asArray };
var fmt = { |v| v.collect { |x| x.round(0.001) } };
var notes = { |e, voice, t0, secs|
  // a gentle repeating figure on one voice, plus a pad
  fork {
    var t = 0, k = 0;
    while { t < secs } {
      e.cmd(\note, voice, [64, 67, 71, 69, 72, 67][k % 6], 0.6, 0.8, 0, 0.55, 0.5);
      0.6.wait; t = t + 0.6; k = k + 1;
    };
  };
};

// a tap on an engine's output: [mono, mono above 2.5 kHz] into a buffer
SynthDef(\react_tap, { arg in, buf;
  var m = Mix(In.ar(in, 2)) * 0.5;
  RecordBuf.ar([m, HPF.ar(HPF.ar(m, 2500), 2500)], buf, loop: 0, doneAction: 2);
}).add;
// the room mic: last block's output (InFeedback) into the inputs, written
// at the head of the engine's group so est_listen hears it this block
SynthDef(\react_loop, { arg from, to, gain = 2;
  var sig = InFeedback.ar(from, 2) * gain;
  Out.ar(to, sig[0]); Out.ar(to + 1, sig[1]);
}).add;
s.sync;

// ------------------------------------------------------------ neutral at 0
{
  var e = mkEngs.(Engine_Estuary, 1)[0];
  var nb = Bus.control(s, 1), rb = Bus.control(s, 1), v;
  nb.set(1); rb.set(1);
  e.reactSynth.set(\natIn, nb.index, \inIn, rb.index);
  e.cmd(\tweak, "react", 0); e.cmd(\tweak, "react_src", 4); e.cmd(\listen, 1);
  e.cmd(\tweak, "pad_sound", 1); e.cmd(\pad, 48, 55, 62, 67);
  notes.(e, 1, 0, 4);
  3.5.wait;
  v = vals.(e);
  ("CHECK react 0, sources maxed: " ++ fmt.(v)).postln;
  if((v[0] != 0) or: { v[1] != 0 } or: { v[2] != 0 } or: { v[3] != 1 } or: { (v[4] - 0.45).abs > 1e-6 }, {
    fail.("react 0 is not neutral: " ++ v)
  });
  1.wait;
  freeEng.(e); nb.free; rb.free;
}.value;

// ------------------------------------------------------------ null vs v2 (NRT)
if(\Engine_EstuaryV2.asClass.isNil, { fail.("no Engine_EstuaryV2 (run via test/sc/run.sh)") }, {
  var v2 = mkEngs.(\Engine_EstuaryV2.asClass, 1)[0];
  var bytes = { |name| SynthDescLib.global[name].def.asBytes };
  var c = Condition.new, files, res;
  var oldVoices = [\rhodes, \bell, \sine, \marimba, \vibes, \celesta, \kalimba, \flute, \glass];
  var oldPads = [\warm, \strings, \glass, \air, \organ];
  // one score: pre = "est_" (this engine) or "v2est_"; v3 adds the motif
  // bus, est_react and the react inputs, exactly as alloc wires them
  var score = { |pre, v3, react|
    var d = { |n| (pre ++ n).asSymbol };
    var l = List.new, id = 2000;
    var defs = (oldVoices.collect { |v| v.asString } ++ oldPads.collect { |p| "pad_" ++ p }
      ++ ["padmix", "natfx", "echo", "verb", "master", "pedal", "natloop1"]
      ++ (if(v3, { ["motifmix", "react"] }, { [] })));
    l.add([0.0, [\d_recv, SynthDef(\nrt_seed, { RandSeed.ir(1, 1234); Line.kr(0, 0, 0.01, doneAction: 2) }).asBytes]]);
    defs.do { |n| l.add([0.0, [\d_recv, bytes.(d.(n))]]) };
    l.add([0.0, [\b_allocRead, 0, fix ++ "water.wav"]]);
    l.add([0.0, [\c_setn, 9, 5, 0, 0, 0, 1, 0.45]]);
    l.add([0.0, [\c_set, 14, 0.3]]);                       // a loud room
    l.add([0.0, [\g_new, 100, 0, 0]]);
    l.add([0.0, [\g_new, 101, 3, 100]]);
    l.add([0.0, [\s_new, \nrt_seed, 999, 0, 0]]);
    if(v3, { l.add([0.0, [\s_new, d.("motifmix"), 1001, 1, 101, \in, 26, \out, 16, \ampOut, 8]]) });
    l.add([0.0, [\s_new, d.("padmix"), 1002, 1, 101, \in, 22, \out, 16, \echoOut, 18, \verbOut, 20, \level, 0.8]
      ++ (if(v3, { [\duckIn, 12] }, { [] }))]);
    l.add([0.0, [\s_new, d.("natfx"), 1003, 1, 101, \in, 24, \out, 16, \verbOut, 20, \ampOut, 3]]);
    l.add([0.0, [\s_new, d.("echo"), 1004, 1, 101, \in, 18, \out, 16, \verbOut, 20, \fb, 0.55]
      ++ (if(v3, { [\fbIn, 11] }, { [] }))]);
    l.add([0.0, [\s_new, d.("verb"), 1005, 1, 101, \in, 20, \out, 16, \send, 0.8]
      ++ (if(v3, { [\sendIn, 10] }, { [] }))]);
    if(v3, { l.add([0.0, [\s_new, d.("react"), 1007, 0, 101, \out, 9, \natIn, 3, \inIn, 14, \motifIn, 8,
      \react, react, \src, 4, \listening, 1]]) });
    l.add([0.0, [\s_new, d.("master"), 1006, 1, 101, \in, 16, \out, 0, \ampOut, 4, \level, 0.9]]);
    l.add([0.05, [\s_new, d.("natloop1"), 1100, 0, 100, \out, 24, \buf, 0, \ampOut, 1, \level, 0.9, \fade, 2]]);
    l.add([0.2, [\s_new, d.("pedal"), 1200, 0, 100, \out, 16, \verbOut, 20, \freq, 36.midicps, \amp, 0.12, \dur, 14]]);
    [[0.3, 1, [48, 55, 62, 64]], [7.0, 3, [53, 57, 60, 64]], [11.0, 5, [50, 57, 62, 65]]].do { |p, k|
      if(k > 0, { l.add([p[0], [\n_set, 1300 + k - 1, \rel, 2, \gate, 0]]) });
      l.add([p[0], [\s_new, d.("pad_" ++ oldPads[p[1] - 1]), 1300 + k, 0, 100, \out, 22,
        \f1, p[2][0].midicps, \f2, p[2][1].midicps, \f3, p[2][2].midicps, \f4, p[2][3].midicps,
        \atk, 2, \rel, 2, \amp, 0.06, \bright, (if(v3, { "c13" }, { 0.45 }))]]);
    };
    // every old voice, two notes each, overlapping (busy for the self follower)
    18.do { |k|
      var t = 0.5 + (k * 0.7);
      l.add([t, [\s_new, d.(oldVoices[k % 9]), id, 0, 100, \out, (if(v3, { 26 }, { 16 })), \echoOut, 18, \verbOut, 20,
        \freq, [60, 64, 67, 71, 72, 76][k % 6].midicps, \amp, 0.12, \vel, 0.6, \dur, 1.0,
        \pan, ((k % 3) - 1) * 0.4, \bright, 0.55, \echo, 0.35, \verb, 0.5]]);
      id = id + 1;
    };
    l.add([16.0, [\c_set, 0, 0]]);
    Score(l.asArray)
  };
  var opts = ServerOptions.new.numOutputBusChannels_(2).numInputBusChannels_(0).sampleRate_(48000).memSize_(2 ** 16);
  var render = { |sc, path|
    var cc = Condition.new;
    sc.recordNRT(path ++ ".osc", path, nil, 48000, "WAV", "float", opts, "", 16.0, { cc.test = true; cc.signal });
    cc.wait;
  };
  var read = { |path|
    var d;
    SoundFile.use(path, { |f| d = FloatArray.newClear(f.numFrames * f.numChannels); f.readData(d) });
    d
  };
  files = [tmp +/+ "estuary_null_v2.wav", tmp +/+ "estuary_null_v3_r0.wav", tmp +/+ "estuary_null_v3_r8.wav"];
  render.(score.("v2est_", false, 0), files[0]);
  render.(score.("est_", true, 0), files[1]);
  render.(score.("est_", true, 0.8), files[2]);
  res = files.collect(read);
  freeEng.(v2);
  if(res.any { |r| r.size < (sr * 10) }, { fail.("null: a render is missing " ++ res.collect(_.size)) }, {
    var n = res.collect(_.size).minItem;
    var resid = { |a, b|
      var pk = 0, sq = 0;
      n.do { |i| var x = a[i] - b[i]; pk = pk.max(x.abs); sq = sq + (x * x) };
      [pk, (sq / n).sqrt]
    };
    var lvl = (res[0].copyRange(0, n - 1).squared.sum / n).sqrt;
    var r0 = resid.(res[0], res[1]), r8 = resid.(res[0], res[2]);
    var nan = res.any { |r| r.any { |x| x.isNaN } };
    ("CHECK null v2 vs react 0: signal rms " ++ dbs.(lvl).round(0.1) ++ " dB, residual peak "
      ++ dbs.(r0[0]).round(0.1) ++ " dB rms " ++ dbs.(r0[1]).round(0.1) ++ " dB"
      ++ (if(r0[0] < 1e-4, { " ok" }, { " FAILED" }))).postln;
    if(r0[0] >= 1e-4, { fails = fails + 1 });
    ("CHECK null v2 vs react 0.8 (must differ): residual rms " ++ dbs.(r8[1]).round(0.1) ++ " dB"
      ++ (if(dbs.(r8[1]) > -60, { " ok" }, { " FAILED (react 0.8 changes nothing)" }))).postln;
    if(dbs.(r8[1]) <= -60, { fails = fails + 1 });
    if(nan or: { lvl < 0.001 }, { fail.("null: NaN or silent renders") });
  });
});

// ------------------------------------------------------------ water, room, self
{
  var e = mkEngs.(Engine_Estuary, 1)[0];
  var nb = Bus.control(s, 1), rb = Bus.control(s, 1);
  var buf = Buffer.alloc(s, (sr * 26).asInteger, 2);
  var va, vb, a, ratio, w;
  nb.set(0); rb.set(0);
  e.reactSynth.set(\natIn, nb.index, \inIn, rb.index);
  e.cmd(\tweak, "react", 0.8); e.cmd(\tweak, "react_src", 1);
  e.cmd(\tweak, "pad_sound", 1); e.cmd(\pad, 48, 55, 62, 67);
  s.sync;
  Synth(\react_tap, [\in, e.context.out_b.index, \buf, buf], e.context.xg, \addToTail);
  // 0-12 s dry water, 12-24 s loud water; the same figure on the rhodes in
  // both, measured 6-12 and 18-24 s (after the followers settle)
  notes.(e, 1, 0, 24);
  11.wait; va = vals.(e);
  1.wait; nb.set(1);
  11.wait; vb = vals.(e);
  3.wait;
  {
    var c = Condition.new, d;
    buf.loadToFloatArray(action: { |x| d = x; c.test = true; c.signal });
    c.wait;
    a = d;
  }.value;
  w = { |t0, t1|
    var i0 = (t0 * sr).asInteger * 2, i1 = (t1 * sr).asInteger * 2, all = 0, hi = 0;
    forBy(i0, i1 - 2, 2, { |i| all = all + a[i].squared; hi = hi + a[i + 1].squared });
    (hi / all.max(1e-12)).sqrt
  };
  ratio = dbs.(w.(18, 24)) - dbs.(w.(6, 12));
  ("CHECK water at react 0.8: nudges dry " ++ fmt.(va) ++ " loud " ++ fmt.(vb)).postln;
  ("CHECK water brightens: energy above 2.5 kHz " ++ dbs.(w.(6, 12)).round(0.1) ++ " -> "
    ++ dbs.(w.(18, 24)).round(0.1) ++ " dB of the whole (" ++ ratio.round(0.01) ++ " dB)"
    ++ (if(ratio >= 1.0, { " ok" }, { " FAILED (< 1 dB)" }))).postln;
  if(ratio < 1.0, { fails = fails + 1 });
  if((vb[1] - va[1]) < 0.2, { fail.("water did not widen the reverb send: " ++ va[1] ++ " -> " ++ vb[1]) });
  if((vb[4] - va[4]) < 0.15, { fail.("water did not open the pad: " ++ va[4] ++ " -> " ++ vb[4]) });
  if(va[0] > 0.01, { fail.("dry water still brightens: " ++ va[0]) });
  // the room: in_amp only counts while listening
  nb.set(0);
  e.cmd(\tweak, "react_src", 2);
  rb.set(0.25);
  4.wait; va = vals.(e);
  e.cmd(\listen, 1);
  5.wait; vb = vals.(e);
  e.cmd(\listen, 0);
  8.wait; w = vals.(e);
  ("CHECK room at react 0.8: not listening " ++ fmt.(va) ++ " listening " ++ fmt.(vb) ++ " stopped " ++ fmt.(w)).postln;
  if((va[2] > 0.001) or: { vb[2] < 0.04 } or: { vb[0] < 0.05 } or: { w[2] > 0.01 }, { fail.("room follower") });
  // self: busy motifs duck the pad; sparse ones open the reverb
  e.cmd(\tweak, "react_src", 3);
  rb.set(0);
  fork { 30.do { |k| e.cmd(\note, [1, 5, 2, 4][k % 4], 60 + ((k * 5) % 19), 0.8, 0.6, 0, 0.5, 0.5); 0.2.wait } };
  1.0.wait; va = vals.(e);
  4.0.wait; vb = vals.(e);
  9.wait; w = vals.(e);
  ("CHECK self at react 0.8: 1 s into a busy run " ++ fmt.(va) ++ " 5 s in " ++ fmt.(vb) ++ " after " ++ fmt.(w)).postln;
  ("CHECK self duck " ++ dbs.(vb[3]).round(0.01) ++ " dB" ++ (if((vb[3] < 0.93) and: { vb[3] >= 0.7 }, { " ok" }, { " FAILED" }))).postln;
  if((vb[3] >= 0.93) or: { vb[3] < 0.7 }, { fails = fails + 1 });
  if(vb[3] < (va[3] - 0.01), { "CHECK self: slow follower (the duck deepens over seconds)".postln }, {
    fail.("self follower is not slow: " ++ va[3] ++ " then " ++ vb[3]) });
  if((w[3] < 0.97) or: { w[1] < 0.15 }, { fail.("self: sparse passage did not release the duck / open the reverb " ++ w) });
  buf.free; freeEng.(e); nb.free; rb.free;
}.value;

// ------------------------------------------------------------ runaway
{
  var e = mkEngs.(Engine_Estuary, 1)[0];
  var path = tmp +/+ "estuary_runaway.wav";
  var rec = Recorder(s), lp, worst = [0, 0, 0, 1, 0.45], bad = false, playing = true;
  rec.recHeaderFormat = "wav"; rec.recSampleFormat = "float";
  // the room mic hears the speakers, louder than life
  lp = Synth(\react_loop, [\from, e.context.out_b.index, \to, e.context.in_b[0].index, \gain, 2], e.context.xg, \addToHead);
  [\react, 1, \react_src, 4, \echo_fb, 0.85, \verb_size, 1, \verb_send, 1, \level, 1, \tone, 1,
   \motif_level, 1, \pad_level, 1, \pedal_level, 1, \bed_level, 1, \swell_level, 1, \moment_level, 1,
   \nature_tone, 1, \echo_time, 0.42].clump(2).do { |kv| e.cmd(\tweak, kv[0].asString, kv[1]) };
  e.cmd(\listen, 1);
  e.cmd(\nature_load, 1, fix ++ "water.wav"); e.cmd(\nature_play, 1, 1, 0.5);
  e.cmd(\nature_load, 2, fix ++ "room.wav");  e.cmd(\nature_play, 2, 1, 0.5);
  e.cmd(\nature_load, 3, fix ++ "water.wav"); e.cmd(\nature_play, 3, 1, 0.5);
  s.sync;
  rec.record(path, e.context.out_b.index, 2);
  fork {
    var k = 0;
    while { playing } {
      e.cmd(\note, (k % e.voiceDefs.size) + 1, 55 + ((k * 7) % 36), 1, 1.5, ((k % 5) - 2) * 0.4, 1, 1);
      if(k % 16 == 0, {
        e.cmd(\tweak, "pad_sound", ((k / 16).asInteger % e.padDefs.size) + 1);
        e.cmd(\pad, *([48, 55, 62, 67] + ((k / 16).asInteger % 5)));
        e.cmd(\pedal, 36, 1, 4);
      });
      if(k % 20 == 0, { e.cmd(\nature_play, 3, 1, 0.3) });
      k = k + 1;
      0.25.wait;
    };
  };
  60.do {
    var v;
    1.wait;
    v = vals.(e);
    if(v.any { |x| x.isNaN }, { bad = true });
    worst = [worst[0].max(v[0]), worst[1].max(v[1]), worst[2].max(v[2]), worst[3].min(v[3]), worst[4].max(v[4])];
  };
  playing = false;
  rec.stopRecording;
  1.wait;
  lp.free;
  SoundFile.use(path, { |f|
    var d = FloatArray.newClear(f.numFrames * f.numChannels), secs = f.numFrames / f.sampleRate, win, pk, nan;
    f.readData(d);
    pk = d.abs.maxItem;
    nan = d.any { |x| x.isNaN or: { x.abs == inf } };
    win = { |t0, t1|
      var seg = d.copyRange((t0 * f.sampleRate).asInteger * 2, ((t1 * f.sampleRate).asInteger * 2).min(d.size) - 1);
      dbs.((seg.squared.sum / seg.size.max(1)).sqrt)
    };
    ("CHECK runaway 60 s, everything at max + output fed to the input: peak " ++ dbs.(pk).round(0.1)
      ++ " dB  rms 15-30 s " ++ win.(15, 30).round(0.1) ++ " dB, 45-60 s " ++ win.(45, secs).round(0.1)
      ++ " dB  nudges at their furthest " ++ fmt.(worst)).postln;
    if(nan or: { bad }, { fail.("runaway: NaN") });
    if(pk >= 1.0, { fail.("runaway: clipping " ++ pk) });
    if((win.(45, secs) - win.(15, 30)) > 3, { fail.("runaway: the level climbs") });
    // the loop has teeth: the room really leans the echo, within its clamp
    if(worst[2] < 0.03, { fail.("runaway: the room loop never reached the echo feedback " ++ worst[2]) });
    if((worst[0] > 0.3001) or: { worst[1] > 0.5001 } or: { worst[2] > 0.1001 } or: { worst[3] < 0.6999 } or: { worst[4] > 0.8001 }, {
      fail.("runaway: a nudge left its clamp " ++ worst) });
  });
  File.delete(path);
  freeEng.(e);
}.value;

// ------------------------------------------------------------ react demo
if(~demoDir.notNil, {
  var src = File.readAllString(~root +/+ "lib/palettes.lua");
  var vl = src.split($\n).detect { |l| l.beginsWith("P.VOICES = {") }.findRegexp("\"([a-z]+)\"").select { |m, i| i.odd }.collect { |m| m[1] };
  var pl = src.split($\n).detect { |l| l.beginsWith("P.PADS = {") }.findRegexp("\"([a-z]+)\"").select { |m, i| i.odd }.collect { |m| m[1] };
  var line = src.split($\n).detect { |l| l.contains("{name = \"lantern\"") };
  var q = line.findRegexp("\"([a-z]+)\"").select { |m, i| i.odd }.collect { |m| m[1] };
  var es = mkEngs.(Engine_Estuary, 2), depths = [0, 0.8], recs, paths;
  paths = depths.collect { |r| ~demoDir +/+ ("react_" ++ (if(r == 0, { "0" }, { "08" })) ++ "_lantern_water_swell.wav") };
  es.do { |e, i|
    e.cmd(\tweak, "react", depths[i]); e.cmd(\tweak, "react_src", 4);
    e.cmd(\tweak, "pad_xfade", 2.5); e.cmd(\tweak, "pad_sound", pl.indexOfEqual(q[5]) + 1);
    e.cmd(\nature_load, 1, fix ++ "water.wav");
    e.cmd(\nature_play, 1, 0.12, 0.5);
  };
  s.sync;
  recs = es.collect { |e, i|
    var r = Recorder(s);
    r.recHeaderFormat = "wav"; r.recSampleFormat = "int24";
    r.record(paths[i], e.context.out_b.index, 2);
    r
  };
  1.wait;
  es.do { |e| e.cmd(\pad, 48, 55, 62, 64); e.cmd(\pedal, 36, 0.5, 16) };
  // the water swells in from 8 s to 16, holds, ebbs from 22 s
  fork { 7.wait; es.do { |e| e.cmd(\nature_play, 1, 1.0, 8) }; 14.wait; es.do { |e| e.cmd(\nature_play, 1, 0.12, 8) } };
  {
    var t = 0, k = 0, fig = [[1, 64], [2, 79], [3, 67], [1, 69], [4, 84], [2, 76], [3, 60], [1, 67]];
    while { t < 34 } {
      var x = fig[k % fig.size];
      es.do { |e| e.cmd(\note, vl.indexOfEqual(q[x[0]]) + 1, x[1], 0.6, 1.2, if(x[0].odd, -0.35, 0.35), 0.6, 0.55) };
      if(k == 24, { es.do { |e| e.cmd(\pad, 53, 57, 60, 64); e.cmd(\pedal, 41, 0.5, 16) } });
      1.2.wait; t = t + 1.2; k = k + 1;
    };
  }.value;
  es.do { |e| e.cmd(\pad, 0, 0, 0, 0); e.cmd(\tweak, "pad_level", 0); e.cmd(\pedal, 0, 0, 0) };
  4.wait;
  recs.do(_.stopRecording);
  1.wait;
  paths.do { |p, i|
    SoundFile.use(p, { |f|
      var d = FloatArray.newClear(f.numFrames * f.numChannels), pk;
      f.readData(d);
      pk = d.abs.maxItem;
      ("CHECK react demo " ++ depths[i] ++ " peak " ++ dbs.(pk).round(0.1) ++ " dB  " ++ p).postln;
      if(pk >= 1.0 or: { d.any(_.isNaN) }, { fail.("react demo " ++ depths[i]) });
    });
  };
  es.do(freeEng);
});

("REACT " ++ (if(fails == 0, { "ok" }, { "FAILED " ++ fails }))).postln;
