#!/usr/bin/env bash
# Usage: tools/push_audio.sh <norns-host>
# Copies audio/{water,birds,wind,room} to the norns sample folder.
set -eu
[ $# -eq 1 ] || { echo "usage: $0 <host>" >&2; exit 2; }
HOST=$1
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT/audio"
# NORNS_SSH_KEY=<path> to use a specific key
SSH="ssh${NORNS_SSH_KEY:+ -i $NORNS_SSH_KEY}"
$SSH "we@$HOST" "mkdir -p /home/we/dust/audio/estuary"
rsync -av -e "$SSH" water birds wind room "we@$HOST:/home/we/dust/audio/estuary/"
