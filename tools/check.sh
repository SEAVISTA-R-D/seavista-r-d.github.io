#!/bin/bash
# Test the site in headless Chromium: tools/check.sh [url], default the local preview.
exec "$(dirname "$0")/run.sh" node tools/check.mjs "$@"
