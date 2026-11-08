#!/bin/sh
# usage: test/sc/run.sh [extra.scd]
# compiles lib/Engine_Estuary.sc against a stub CroneEngine, boots a local
# server, fires every command (or runs extra.scd with ~eng set), renders a
# wav and prints its levels, then runs sounds.scd: every voice and pad
# character measured alone (RMS / peak / NaN / onset, the 3 dB loudness
# match) and a demo wav per palette in $DEMO_DIR (default
# $TMPDIR/estuary_demos), then react.scd: the reactive sound (water, room,
# self), a null test against the v2 engine (compiled from git at $V2_REF as
# Engine_EstuaryV2, rendered in NRT) and a 60 s runaway check, plus a react
# demo. killed after 600s if sclang hangs.
#
# the stub lives as CroneStub.stub so it can never be compiled on a norns
# (a second CroneEngine class there = "DUPLICATE ENGINES"); it's copied to a
# temp class dir as .sc only for this run.
EXTRA=""
[ -n "$1" ] && EXTRA="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
DEMO_DIR="${DEMO_DIR:-${TMPDIR:-/tmp}/estuary_demos}"
mkdir -p "$DEMO_DIR"
export DEMO_DIR="$(cd "$DEMO_DIR" && pwd)"
cd "$(dirname "$0")"
SCLANG=/Applications/SuperCollider.app/Contents/MacOS/sclang
OUT="${TMPDIR:-/tmp}/estuary_test.wav"
LIB="${TMPDIR:-/tmp}/estuary_sclib"
rm -rf "$LIB"; mkdir -p "$LIB"
cp CroneStub.stub "$LIB/CroneStub.sc"
# the v2 engine, renamed so it can live beside this one (test-only, in the
# temp class dir: never a second engine on a norns)
V2_REF="${V2_REF:-3ef160a}"
if ! git -C ../.. show "$V2_REF:lib/Engine_Estuary.sc" 2>/dev/null \
  | sed -e 's/^Engine_Estuary :/Engine_EstuaryV2 :/' -e 's/\\est_/\\v2est_/g' -e 's/"est_/"v2est_/g' > "$LIB/EstuaryV2.sc" \
  || ! grep -q "^Engine_EstuaryV2 :" "$LIB/EstuaryV2.sc"; then
  echo "run.sh: FAIL (no v2 engine at $V2_REF for the null test)"; exit 1
fi
cat > "$LIB/lang.yaml" <<YAML
includePaths:
  - $LIB
  - $(cd ../../lib && pwd)
excludePaths: []
postInlineWarnings: false
YAML
LOG=$(perl -e 'alarm 600; exec @ARGV' "$SCLANG" -l "$LIB/lang.yaml" run.scd "$OUT" $EXTRA 2>&1 \
  | grep -E "ERROR|WARNING|FAILURE|ENGINE|SMOKE|LEVELS|SEG|EARS|poll |Message|RECEIVER|not understood|nil|CHECK|SOUNDS|REACT|EXTRA|exception|Exception|error|late" \
  | grep -v "^Exception in World_OpenUDP")
echo "$LOG"
# belt and braces: never leave a test server behind
pkill -f "SuperCollider.app/Contents/Resources/../Resources/scsynth" 2>/dev/null
# teeth: any failed check, error or a missing SMOKE ok fails the run
if echo "$LOG" | grep -qE "NOT-RISING|NOT-FALLING|NOT-SILENT|ERROR|FAILED"; then echo "run.sh: FAIL"; exit 1; fi
if ! echo "$LOG" | grep -q "SMOKE ok"; then echo "run.sh: FAIL (no SMOKE ok)"; exit 1; fi
if ! echo "$LOG" | grep -q "SOUNDS ok"; then echo "run.sh: FAIL (no SOUNDS ok)"; exit 1; fi
if ! echo "$LOG" | grep -q "REACT ok"; then echo "run.sh: FAIL (no REACT ok)"; exit 1; fi
echo "run.sh: ok"
exit 0
