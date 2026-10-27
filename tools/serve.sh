#!/bin/bash
# Serve this checkout at http://127.0.0.1:$PREVIEW_PORT, as the server will.
# nginx, not python's http.server: the videos need range requests. The
# container is recreated every time, because a bind mount pins the folder's
# inode and keeps serving a folder that has since been moved or replaced.
set -euo pipefail
S=$(cd "$(dirname "$0")/.." && pwd)
source "$S/tools/site.env"
docker rm -f seavista-site-preview >/dev/null 2>&1 || true
docker run -d --name seavista-site-preview -p 127.0.0.1:$PREVIEW_PORT:80 \
  -v "$S":/usr/share/nginx/html:ro nginx:alpine >/dev/null
echo "http://127.0.0.1:$PREVIEW_PORT"
