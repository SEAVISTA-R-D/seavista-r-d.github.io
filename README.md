# SEAVISTA page

Static page for the SEAVISTA videos, served as the organisation's GitHub Pages site
(https://seavista-r-d.github.io) once it is cleared. Until then the repo is private.

Everything in this repo is meant to be published. Working material (the newsletter item, the
reception review of this page) lives in `SEAVISTA-R-D/seavista-comms`.

- `videos.json` is the list of videos, in page order, with their titles and blurbs in English and Greek.
- `tools/media.sh` encodes every listed video from `~/work/seavista_videos/episodes/<id>/<id>.mp4`
  (web encode, poster, an 8 s loop cropped to the stage, the hero loop). It skips anything current.
- Preview: `docker run -d --name seavista-site-preview -p 127.0.0.1:8090:80 -v $PWD:/usr/share/nginx/html:ro nginx:alpine`, then http://127.0.0.1:8090

Adding a video: add its entry to `videos.json`, run `tools/media.sh`, reload.
