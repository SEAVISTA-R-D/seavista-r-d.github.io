# SEAVISTA page

Static page for the SEAVISTA videos, served from FORTH at https://seavista.ics.forth.gr
(`web-hosting.ics.forth.gr`, account `seavista`, `public_html/`). `tools/site.env` holds those.

Everything in this repo is meant to be published. Working material (the newsletter item, the
reception review of this page) lives in `SEAVISTA-R-D/seavista-comms`.

- `videos.json` is the list of videos, in page order, with their titles and blurbs in English and Greek.
- `tools/media.sh` encodes every listed video from `~/work/seavista_videos/episodes/<id>/<id>.mp4`
  (web encode, poster, an 8 s loop cropped to the stage, the hero loop). It skips anything current.

Everything runs in Docker; nothing is installed on the host.

- `tools/serve.sh` serves this checkout at http://127.0.0.1:8090, as nginx will on the server.
- `tools/check.sh` loads the page in headless Chromium and fails on any failed request, script
  error, referenced file that is not committed, or link-preview tag not pointing at the site.
- `tools/deploy.sh` shows what would change on the server; `tools/deploy.sh --go` sends it and
  confirms the live page is this commit. It deploys HEAD (clean tree, pushed, check passing),
  leaves `README.md`, `tools/` and `.gitignore` behind, and deletes what the commit no longer has,
  except the host's `icon/` and awstats links. It needs your SSH key authorised on the account.

Adding a video: add its entry to `videos.json`, run `tools/media.sh`, reload, `tools/check.sh`,
commit, push, `tools/deploy.sh --go`.
