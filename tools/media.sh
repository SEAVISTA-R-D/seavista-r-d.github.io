#!/bin/bash
# Encode every video in videos.json for the web, its poster, its loop, and the hero loop.
# Reads the camera-ready mp4s from the videos repo; skips any output newer than its source.
set -euo pipefail
S=$(cd "$(dirname "$0")/.." && pwd)
V=${SEAVISTA_VIDEOS:-$HOME/work/seavista_videos}
[ -f ~/.claude/skills/flow/flow.sh ] && source ~/.claude/skills/flow/flow.sh || { flow(){ :; }; step(){ echo "$1"; }; ok(){ :; }; progress(){ :; }; }
ff(){ docker run --rm -u $(id -u) -e HOME=/tmp -v $V:$V -v $S:$S --entrypoint ffmpeg seavista-video/encode -v error -y "$@"; }
fresh(){ [ -f "$1" ] && [ "$1" -nt "$2" ]; }
CROP="crop=1920:856:0:88,scale=1280:-2"   # the stage: below the 86 px band, above the 136 px footer
mapfile -t ROWS < <(python3 -c "
import json; m=json.load(open('$S/videos.json'))
for v in m['videos']: print(v['id'], v.get('loop_at') or '-', v.get('loop_name') or '-')
h=m.get('hero'); print('HERO', h['render'], 0) if h else None")
n=${#ROWS[@]}; mkdir -p $S/media $S/loops $S/assets
flow "Encode media for the page" 2
step "videos"; i=0
for r in "${ROWS[@]}"; do read a b c <<<"$r"; i=$((i+1)); progress $i $n "$a $b"
  if [ "$a" = HERO ]; then src=$V/remotion/out/$b.mp4; out=$S/loops/hero.mp4   # the whole loop, cropped to the page's band
    [ -f $src ] || { echo "missing $src: render the $b composition first" >&2; exit 1; }
    fresh $out $src || { ff -i $src -an -vf "crop=1920:856:0:112,scale=1600:-2" -c:v libx264 -crf 22 -preset slow -pix_fmt yuv420p -movflags +faststart $out
      ff -i $src -frames:v 1 -vf "crop=1920:856:0:112,scale=1600:-2" -q:v 3 $S/loops/hero.jpg; }; continue; fi
  src=$V/episodes/$a/$a.mp4; [ -f $src ] || { echo "missing $src" >&2; exit 1; }
  fresh $S/media/$a.mp4 $src || ff -i $src -c:v libx264 -crf 25 -preset slow -pix_fmt yuv420p -c:a aac -b:a 128k -movflags +faststart $S/media/$a.mp4
  fresh $S/media/$a.jpg $src || ff -ss 5 -i $src -frames:v 1 -vf scale=1280:-2 -q:v 3 $S/media/$a.jpg
  cp -u $V/episodes/$a/$a.srt $S/media/
  python3 - "$V/episodes/$a/film.json" "$S/media/$a.json" <<'PY'
import json,sys; d=json.load(open(sys.argv[1])); json.dump({"seconds": round(d["total"]/d["fps"],1)}, open(sys.argv[2],"w"))
PY
  if [ "$b" != - ]; then out=$S/loops/$c.mp4
    fresh $out $src || { ff -ss $b -t 8 -i $src -an -vf "$CROP" -c:v libx264 -crf 23 -preset slow -pix_fmt yuv420p -movflags +faststart $out
      ff -ss $((b+3)) -i $src -frames:v 1 -vf "$CROP" -q:v 3 $S/loops/$c.jpg; }; fi
done; ok
step "fonts and marks"
cp -u $V/assets/logos/{FORTH-ICS.png,CVRL.png,FRONTEX-rev.png,FRONTEX.png} $S/assets/; ok
du -sh $S/media $S/loops
