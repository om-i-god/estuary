// compile + smoke-test Engine_Estuary: boot, alloc, fire every command,
// render 20 s, report SMOKE / LEVELS / CHECK nature. run via test/sc/run.sh
var out = thisProcess.argv[0] ? "/tmp/estuary_test.wav";
var fix = PathName(thisProcess.nowExecutingPath).pathOnly +/+ "fixtures/";
s.options.numInputBusChannels = 0;
s.options.numOutputBusChannels = 2;
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
    if(eng.polls[\in_key].isNil or: { eng.polls[\in_amp].isNil }, { "ERROR missing poll".postln });
    s.recHeaderFormat = "wav"; s.recSampleFormat = "float";
    s.record(out, numChannels: 2);
    0.3.wait;
    // every tweak key once
    [\echo_time, 0.83, \echo_fb, 0.45, \echo_tone, 0.5, \echo_wow, 0.001,
     \verb_size, 0.95, \verb_send, 0.8, \tone, 0.75, \level, 0.9,
     \motif_level, 1.0, \pad_level, 1.0, \pad_xfade, 3.0, \pedal_level, 1.0,
     \bed_level, 1.0, \swell_level, 1.0, \moment_level, 1.0, \nature_tone, 0.6
    ].clump(2).do { |kv| eng.cmd(\tweak, kv[0].asString, kv[1]) };
    eng.cmd(\nature_load, 1, fix ++ "room.wav");
    eng.cmd(\nature_load, 2, fix ++ "water.wav");
    eng.cmd(\nature_load, 3, fix ++ "water.wav");
    1.wait;
    eng.cmd(\listen, 1);
    eng.cmd(\pad, 48, 55, 62, 67);
    eng.cmd(\pedal, 36, 0.5, 6);
    // 4 voices, then a second pad
    [1, 2, 3, 4].do { |v, i|
      eng.cmd(\note, v, 60 + (i * 4), 0.7, 1.5, (i - 1.5) * 0.4, 0.5, 0.5);
      1.wait;
    };
    // nature: slot 2 rises (measured on its own amp bus)
    ~lo = eng.natAmp(2);
    eng.cmd(\nature_play, 2, 0.8, 2);
    eng.cmd(\nature_play, 1, 0.4, 2);
    4.wait;
    ~hi = eng.natAmp(2);
    ("CHECK nature before " ++ ~lo.round(0.0001) ++ " after " ++ ~hi.round(0.0001)
      ++ (if(~hi > (~lo + 0.001), { " rising" }, { " NOT-RISING" }))).postln;
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
  s.quit;
  0.5.wait;
  0.exit;
};
