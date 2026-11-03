#!/usr/bin/env bash
# Usage: tools/push_audio.sh <norns-host>
# Copies audio/{water,birds,wind,room} to the norns sample folder.
set -eu
[ $# -eq 1 ] || { echo "usage: $0 <host>" >&2; exit 2; }
HOST=$1
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT/audio"
ssh "we@$HOST" "mkdir -p /home/we/dust/audio/estuary"
rsync -av -e "ssh" water birds wind room "we@$HOST:/home/we/dust/audio/estuary/"
