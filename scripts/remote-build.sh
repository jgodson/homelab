#!/usr/bin/env bash
set -euo pipefail

REMOTE_HOST="manager@192.168.1.113"
REGISTRY_PREFIX="gitea.home.jasongodson.com/homelab"

usage() {
  echo "Usage: $0 <local-directory>"
  exit 1
}

[[ $# -eq 1 ]] || usage

SOURCE_DIR="${1%/}"
[[ -d "$SOURCE_DIR" ]] || { echo "Directory not found: $SOURCE_DIR" >&2; exit 1; }

SOURCE_DIR_ABS="$(cd "$SOURCE_DIR" && pwd)"
FOLDER_NAME="$(basename "$SOURCE_DIR_ABS")"
REMOTE_PATH="~/${FOLDER_NAME}"
IMAGE_TAG="${REGISTRY_PREFIX}/${FOLDER_NAME}:latest"

RSYNC_SOURCE="${SOURCE_DIR_ABS%/}/"

rsync -av \
  --delete \
  --exclude 'target' \
  --exclude 'node_modules' \
  --exclude '.git' \
  "$RSYNC_SOURCE" "${REMOTE_HOST}:${REMOTE_PATH}/"

ssh "$REMOTE_HOST" "cd ${REMOTE_PATH} && docker build -t ${IMAGE_TAG} . && docker push ${IMAGE_TAG}"
