#!/bin/bash
# Build a copy of the page that fits a claude.ai Artifact (private preview): videos under 15 MB each,
# Plex from Google Fonts, no document skeleton. Output: _artifact/
set -euo pipefail
S=$(cd "$(dirname "$0")/.." && pwd); O=$S/_artifact
[ -f ~/.claude/skills/flow/flow.sh ] && source ~/.claude/skills/flow/flow.sh || { flow(){ :; }; step(){ echo "$1"; }; ok(){ :; }; progress(){ :; }; }
ff(){ docker run --rm -u $(id -u) -e HOME=/tmp -v $S:$S --entrypoint ffmpeg seavista-video/encode -v error -y "$@"; }
mkdir -p $O/media $O/assets
flow "Artifact build of the page" 2
ids=$(python3 -c "import json;print(' '.join(v['id'] for v in json.load(open('$S/videos.json'))['videos']))"); n=$(wc -w <<<"$ids")
step "720p encodes"; i=0
for id in $ids; do i=$((i+1)); progress $i $n "$id"
  [ $O/media/$id.mp4 -nt $S/media/$id.mp4 ] || ff -i $S/media/$id.mp4 -vf scale=1280:-2 -c:v libx264 -crf 27 -preset slow -pix_fmt yuv420p -c:a aac -b:a 96k -movflags +faststart $O/media/$id.mp4
  sz=$(stat -c %s $O/media/$id.mp4); [ $sz -lt 15000000 ] || { echo "$id is $sz bytes, over 15 MB" >&2; exit 1; }
  cp $S/media/$id.{jpg,json} $O/media/
done; ok
step "page"
rm -rf $O/loops $O/story; mkdir -p $O/story; cp $S/story/*.webp $O/story/; cp $S/assets/*.png $O/assets/; cp $S/videos.json $O/
python3 - $S/index.html $O/index.html <<'PY'
import re,sys
s=open(sys.argv[1]).read()
s=re.sub(r'<!doctype html>\s*<html[^>]*>\s*<head>\s*','',s); s=s.replace('</head>\n<body>\n','')
s=s.replace('</body>\n</html>\n','')
s=re.sub(r'<meta [^>]*>\n','',s)
s=re.sub(r'\s*@font-face[^\n]*\n','\n',s)
if 'fonts.googleapis' not in s: s=s.replace('<style>','<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono&family=IBM+Plex+Sans:wght@400;600;700&display=swap">\n<style>',1)
s=s.replace('Plex, system-ui','"IBM Plex Sans", system-ui').replace('Plex, sans-serif','"IBM Plex Sans", sans-serif').replace('PlexMono, monospace','"IBM Plex Mono", monospace')
s=s.replace('--max: 1180px;','--max: 1180px; color-scheme: dark;')
open(sys.argv[2],'w').write(s)
PY
ok
du -sh $O; ls -la $O/media/*.mp4 | awk '{print $5, $9}'
