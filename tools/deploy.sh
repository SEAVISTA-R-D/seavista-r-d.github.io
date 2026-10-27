#!/bin/bash
# Put the committed site on the server.
#
#   tools/deploy.sh          show what would change (nothing is sent)
#   tools/deploy.sh --go     send it, then confirm the live page is this commit
#
# Deploys HEAD, not the working tree: the tree must be clean, HEAD must be
# on origin (for --go), and the check must pass on the local preview. README.md, tools/
# and .gitignore stay behind. Files on the server that are not in the commit
# are deleted, except the host's own: icon/ and the awstats links.
set -euo pipefail
S=$(cd "$(dirname "$0")/.." && pwd); cd "$S"
source tools/site.env
GO=${1:-}
[ -z "$GO" ] || [ "$GO" = --go ] || { echo "usage: tools/deploy.sh [--go]" >&2; exit 2; }
[ -z "$(git status --porcelain)" ] || { echo "deploy: the tree has uncommitted changes; commit them first" >&2; exit 1; }
[ -z "$GO" ] || [ -n "$(git branch -r --contains HEAD)" ] || { echo "deploy: HEAD is not on origin; push it first" >&2; exit 1; }
# Reuse a running preview: recreating it changes Docker's network under Chromium (ERR_NETWORK_CHANGED).
[ "$(docker inspect -f '{{.State.Running}}' seavista-site-preview 2>/dev/null)" = true ] || { tools/serve.sh >/dev/null; sleep 2; }
tools/check.sh
exec tools/run.sh bash -euc '
  # mktemp makes the folder 700, and rsync would carry that onto public_html
  # itself, which the web server then cannot read (a 403 on the first deploy).
  out=$(mktemp -d); chmod 755 "$out"
  git archive HEAD | tar -x -C "$out"
  rm -rf "$out/tools" "$out/README.md" "$out/.gitignore"
  ssh_="ssh -o BatchMode=yes -o StrictHostKeyChecking=yes"
  flags=(-rlptz --delete --exclude=/icon/ --exclude="/awstats*" --itemize-changes -e "$ssh_")
  [ "$1" = --go ] || flags+=(--dry-run)
  rsync "${flags[@]}" "$out/" "$2:$3/" | grep -v "^\.[fd] " || true
  if [ "$1" != --go ]; then echo "deploy: dry run of $(git rev-parse --short HEAD); tools/deploy.sh --go to send it"; exit 0; fi
  want=$(sha1sum < "$out/index.html"); got=$(curl -fsS --http1.1 "$4/index.html?$(date +%s)" | sha1sum)
  [ "$want" = "$got" ] || { echo "deploy: $4 does not serve this commit'"'"'s index.html" >&2; exit 1; }
  echo "deploy: $4 serves $(git rev-parse --short HEAD)"
' _ "$GO" "$HOST" "$ROOT" "$SITE"
