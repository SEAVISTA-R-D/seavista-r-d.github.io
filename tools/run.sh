#!/bin/bash
# Run a command in the tools image, as you, on the host's network, with this
# checkout at the same path. Builds the image first (cached after the first time).
# ~/.ssh is mounted read-only, and /etc/passwd so ssh can name you.
set -euo pipefail
S=$(cd "$(dirname "$0")/.." && pwd)
docker build -q -t seavista-site-tools "$S/tools" >/dev/null
exec docker run --rm --init --network host --user "$(id -u):$(id -g)" \
  -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro \
  -v "$HOME/.ssh:$HOME/.ssh:ro" -e HOME="$HOME" \
  -v "$S:$S" -w "$S" seavista-site-tools "$@"
