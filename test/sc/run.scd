// compile + smoke-test Engine_Estuary: boot, alloc, fire every command,
// render ~26 s, report SMOKE / LEVELS / CHECK nature; then sounds.scd
// (voices, pads, loudness match, palette demos). run via test/sc/run.sh
var out = thisProcess.argv[0] ? "/tmp/estuary_test.wav";
var here = PathName(thisProcess.nowExecutingPath).pathOnly;
var fix = here +/+ "fixtures/";
s.options.numInputBusChannels = 0;
s.options.numOutputBusChannels = 2;
s.options.memSize = 2 ** 18;            // sounds.scd runs one engine per palette at once
s.waitForBoot {
  var xg = Group.new(s), inb = [Bus.audio(s, 1), Bus.audio(s, 1)];
  var ctx = (server: s, xg: xg, in_b: inb, out_b: Bus.new(\audio, 0, 2, s));
  var cond = Condition.new, eng, n = 0, expect;
  expect = [\note, \pad, \pedal, \nature_load, \nature_play, \listen, \tweak];
  eng = Engine_Estuary.new(ctx, { cond.test = true; cond.signal });
  cond.wait;
  s.sync;
  "ENGINE ALLOCATED".postln;
  try {
    expect.do { |c|
      if(eng.commands[c].isNil, { ("ERROR missing command " ++ c).postln }, { n = n + 1 });
    };
    eng.polls.keysValuesDo { |k, f| n = n + 0 };
    [\in_key, \in_amp, \out_amp, \out_lo, \out_mid, \out_hi, \nat_amp].do { |p|
      if(eng.polls[p].isNil, { ("ERROR missing poll " ++ p).postln });
    };
    s.recHeaderFormat = "wav"; s.recSampleFormat = "float";
    s.record(out, numChannels: 2);
    0.3.wait;
    // every tweak key once
    [\echo_time, 0.83, \echo_fb, 0.45, \echo_tone, 0.5, \echo_wow, 0.001,
     \verb_size, 0.95, \verb_send, 0.8, \tone, 0.75, \level, 0.9,
     \motif_level, 1.0, \pad_level, 1.0, \pad_xfade, 3.0, \pedal_level, 1.0,
     \bed_level, 1.0, \swell_level, 1.0, \moment_level, 1.0, \nature_tone, 0.6
    ].clump(2).do { |kv| eng.cmd(\tweak, kv[0].asString, kv[1]) };
    // the visuals' ears: out_amp rises while a note sounds and falls back
    // after its tail; every band is printed (they map dB to 0..1)
    ~ears = { |tag|
      var v = [\out_amp, \out_lo, \out_mid, \out_hi, \nat_amp].collect { |p| eng.polls[p].value };
      ("EARS " ++ tag ++ " amp/lo/mid/hi/nat " ++ v.collect(_.round(0.01))).postln;
      v
    };
    ~before = ~ears.("before")[0];
    eng.cmd(\note, 1, 60, 0.7, 1.5, 0, 0.5, 0.5);
    eng.cmd(\pedal, 36, 0.5, 1.5);
    0.6.wait;
    ~during = ~ears.("during")[0];
    eng.cmd(\pedal, 0, 0, 0);
    [1.5, 1.5, 1.5, 1.5, 2].do { |w, i| w.wait; ~ears.("after" ++ i) };
    ~after = eng.polls[\out_amp].value;
    ("CHECK out_amp before " ++ ~before.round(0.001) ++ " during " ++ ~during.round(0.001)
      ++ (if((~during > (~before + 0.25)), { " rising" }, { " NOT-RISING" }))).postln;
    ("CHECK out_amp after " ++ ~after.round(0.001)
      ++ (if(~after < (~during * 0.5), { " falling" }, { " NOT-FALLING" }))).postln;
    // a bell for the top band
    eng.cmd(\note, 2, 84, 0.8, 1, 0, 0.9, 0.3);
    0.3.wait;
    ~ears.("bell");
    3.wait;
    // load + play in the same tick, as the script sends them: every slot
    // must be heard (the play waits for the async load)
    eng.cmd(\nature_load, 1, fix ++ "room.wav");  eng.cmd(\nature_play, 1, 0.6, 0.5);
    eng.cmd(\nature_load, 2, fix ++ "water.wav"); eng.cmd(\nature_play, 2, 0.8, 0.5);
    eng.cmd(\nature_load, 3, fix ++ "water.wav"); eng.cmd(\nature_play, 3, 0.8, 0.5);
    3.wait;
    ~nat = ~ears.("nature")[4];
    ("CHECK nat_amp " ++ ~nat.round(0.001) ++ (if(~nat > 0.1, { " rising" }, { " NOT-RISING" }))).postln;
    [1, 2, 3].do { |k|
      var a = eng.natAmp(k);
      ("CHECK same-tick slot" ++ k ++ " " ++ a.round(0.0001)
        ++ (if(a > 0.02, { " rising" }, { " NOT-RISING" }))).postln;
    };
    // a second moment loaded over one still playing: no error, old buffer kept
    eng.cmd(\nature_load, 3, fix ++ "room.wav"); eng.cmd(\nature_play, 3, 0.5, 0.5);
    1.wait;
    [1, 2, 3].do { |k| eng.cmd(\nature_play, k, 0, 0.3) };
    1.5.wait;
    eng.cmd(\nature_load, 1, fix ++ "room.wav");
    eng.cmd(\nature_load, 2, fix ++ "water.wav");
    eng.cmd(\nature_load, 3, fix ++ "water.wav");
    1.wait;
    eng.cmd(\listen, 1);
    eng.cmd(\pad, 48, 55, 62, 67);
    eng.cmd(\pedal, 36, 0.5, 6);
    eng.cmd(\pedal, 43, 0.5, 6);         // one voice: releases the first
    0.5.wait;
    eng.cmd(\pedal, 0, 0, 0);            // vel 0: release only
    eng.cmd(\pedal, 36, 0.5, 6);
    // 4 voices, then a second pad
    [1, 2, 3, 4].do { |v, i|
      eng.cmd(\note, v, 60 + (i * 4), 0.7, 1.5, (i - 1.5) * 0.4, 0.5, 0.5);
      1.wait;
    };
    // nature: slot 2 rises (measured on its own amp bus)
    // slot 1 stays silent while slot 2 rises
    ~lo = eng.natAmp(2);
    eng.cmd(\nature_play, 2, 0.8, 2);
    4.wait;
    ~hi = eng.natAmp(2);
    ~s1 = eng.natAmp(1);
    ("CHECK nature slot2 before " ++ ~lo.round(0.0001) ++ " after " ++ ~hi.round(0.0001)
      ++ (if((~lo < 0.001) and: { ~hi > 0.02 }, { " rising" }, { " NOT-RISING" }))).postln;
    ("CHECK nature slot1 " ++ ~s1.round(0.0001)
      ++ (if(~s1 < 0.001, { " silent" }, { " NOT-SILENT" }))).postln;
    eng.cmd(\nature_play, 1, 0.4, 2);
    eng.cmd(\nature_play, 3, 0.6, 0.5);
    eng.cmd(\pad, 50, 57, 64, 69);
    4.do { |i|
      eng.cmd(\note, (i % 4) + 1, 67 + (i * 2), 0.6, 1.2, 0, 0.4, 0.6);
      2.wait;
    };
    eng.cmd(\nature_play, 3, 0, 0.5);
    eng.cmd(\nature_play, 2, 0, 2);
    // fill out to 20 s of render
    4.wait;
    // test/sc/run.sh extra.scd: run it with ~eng set
    thisProcess.argv[1] !? { |p| ~eng = eng; ("EXTRA " ++ p).postln; p.load };
  } { |err| ("ERROR in test body: " ++ err.errorString).postln };
  eng.polls.keysValuesDo { |k, f| ("poll " ++ k ++ " = " ++ f.value).postln };
  s.stopRecording;
  1.wait;
  SoundFile.use(out, { |f|
    var data = FloatArray.newClear(f.numFrames * f.numChannels), peak, rms, db;
    f.readData(data);
    peak = data.abs.maxItem;
    rms = (data.squared.sum / data.size.max(1)).sqrt;
    db = rms.ampdb;
    ("LEVELS peak " ++ peak.round(0.001) ++ " (" ++ peak.ampdb.round(0.1) ++ " dB)  rms "
      ++ rms.round(0.0001) ++ " (" ++ db.round(0.1) ++ " dB)  secs "
      ++ (f.numFrames / f.sampleRate).round(0.1)
      ++ (if((peak < 1.0) and: { db > -45 }, { " OK" }, { " ERROR-LEVELS" }))).postln;
    ("SMOKE " ++ (if(n == expect.size, { "ok" }, { "FAILED" })) ++ " n=" ++ n).postln;
  });
  "SMOKE DONE".postln;
  // sounds v2: every voice and pad character, loudness match, palette demos
  try {
    ~eng = eng;
    ~root = here +/+ "../../";
    ~demoDir = "DEMO_DIR".getenv;
    (here +/+ "sounds.scd").load;
  } { |err| ("ERROR in sounds.scd: " ++ err.errorString).postln };
  s.quit;
  0.5.wait;
  0.exit;
};
