#!/usr/bin/env bash
# Fetch CC0 placeholder field recordings from Freesound into audio/<folder>/.
# Each entry: folder|freesound_id|out_name
# A sound is only used if its OWN page states "Creative Commons 0" (CC0 1.0);
# otherwise that entry is refused. Downloads are treated as untrusted data:
# they land only under audio/<folder>/ and only ffmpeg/ffprobe read them.
# Output: 48 kHz stereo WAV, <= 90 s, 2 s fades, loudnorm then peak -3 dBFS.
set -u
FFMPEG=${FFMPEG:-/opt/homebrew/bin/ffmpeg}
FFPROBE=${FFPROBE:-$(dirname "$FFMPEG")/ffprobe}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
UA="Mozilla/5.0 (estuary placeholder fetch)"

ENTRIES=(
  "water|826598|brook_stones"
  "water|637831|stream_gentle"
  "water|758708|lake_shore"
  "water|818347|light_rain_evening"
  "birds|475682|dawn_birdsong_suburb"
  "birds|439615|songbirds_forest_brook"
  "birds|816567|birdsong_ambience"
  "wind|454360|soft_breeze"
  "wind|397092|soft_tonal_wind"
  "room|744447|cabin_room_tone"
  "room|637807|quiet_small_room"
)

fail=0
for entry in "${ENTRIES[@]}"; do
  IFS='|' read -r folder id name <<<"$entry"
  case "$folder$id$name" in *[!A-Za-z0-9_]*) echo "REFUSED $entry: bad characters"; fail=1; continue;; esac
  out="$ROOT/audio/$folder/$name.wav"
  if [ -s "$out" ]; then echo "skip   $folder/$name.wav (exists)"; continue; fi
  mkdir -p "$ROOT/audio/$folder"

  page=$(curl -fsSL -A "$UA" "https://freesound.org/s/$id/") || { echo "FAILED $entry: page fetch"; fail=1; continue; }
  if ! grep -q 'creativecommons.org/publicdomain/zero/1.0' <<<"$page" \
     || ! grep -q '>Creative Commons 0<' <<<"$page"; then
    echo "REFUSED $entry: page does not state Creative Commons 0"; fail=1; continue
  fi

  # og:audio is sometimes prefixed with the site origin twice; keep the last https:// URL
  prev=$(grep -o '<meta property="og:audio" content="[^"]*"' <<<"$page" | head -1 | sed 's/.*content="//;s/"$//;s#.*\(https://\)#\1#')
  case "$prev" in https://cdn.freesound.org/previews/*.mp3) ;; *) echo "FAILED $entry: no preview URL"; fail=1; continue;; esac
  tmp="$ROOT/audio/$folder/.$name.mp3"
  hq=${prev/-lq.mp3/-hq.mp3}
  curl -fsSL -A "$UA" -o "$tmp" "$hq" || curl -fsSL -A "$UA" -o "$tmp" "$prev" || { echo "FAILED $entry: download"; rm -f "$tmp"; fail=1; continue; }

  dur=$("$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$tmp" 2>/dev/null)
  len=$(awk -v d="${dur:-0}" 'BEGIN{ if (d+0 <= 0) print 0; else print (d>90?90:d) }')
  if [ "$len" = 0 ]; then echo "FAILED $entry: unreadable audio"; rm -f "$tmp"; fail=1; continue; fi
  fo=$(awk -v l="$len" 'BEGIN{printf "%.3f", l-2}')

  stage="$ROOT/audio/$folder/.$name.stage.wav"
  "$FFMPEG" -v error -y -i "$tmp" -vn -t "$len" -ac 2 \
    -af "afade=t=in:d=2,afade=t=out:st=$fo:d=2,loudnorm=I=-24:TP=-3:LRA=11,aresample=48000" \
    -ar 48000 "$stage" || { echo "FAILED $entry: ffmpeg"; rm -f "$tmp" "$stage"; fail=1; continue; }
  peak=$("$FFMPEG" -hide_banner -i "$stage" -af volumedetect -f null - 2>&1 | awk '/max_volume:/ {print $(NF-1)}')
  if [ -z "$peak" ]; then echo "FAILED $entry: peak detect"; rm -f "$tmp" "$stage"; fail=1; continue; fi
  gain=$(awk -v p="$peak" 'BEGIN{printf "%.2f", -3 - p}')
  "$FFMPEG" -v error -y -i "$stage" -af "volume=${gain}dB" -ar 48000 -ac 2 "$out" \
    || { echo "FAILED $entry: peak norm"; rm -f "$tmp" "$stage" "$out"; fail=1; continue; }
  rm -f "$tmp" "$stage"
  echo "ok     $folder/$name.wav (id $id, ${len}s, gain ${gain} dB)"
done
exit $fail
