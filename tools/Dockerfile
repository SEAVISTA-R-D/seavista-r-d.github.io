# The site's tools in one image, so nothing is installed on the host:
# Chromium for the check, rsync and ssh for the deploy.
FROM node:22-bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      chromium rsync openssh-client git ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
