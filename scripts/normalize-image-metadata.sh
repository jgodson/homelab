#!/usr/bin/env bash

set -euo pipefail

if ! command -v exiftool >/dev/null 2>&1; then
  echo "exiftool is required to remove image metadata." >&2
  exit 1
fi

if ! command -v jpegtran >/dev/null 2>&1; then
  echo "jpegtran is required to preserve JPEG orientation without re-encoding." >&2
  exit 1
fi

for image_file in "$@"; do
  [[ -f "$image_file" ]] || continue

  case "$image_file" in
    *.jpg|*.JPG|*.jpeg|*.JPEG) ;;
    *) continue ;;
  esac

  orientation="$(exiftool -s3 -n -Orientation "$image_file")"
  metadata_count="$(
    exiftool -s -EXIF:all -XMP:all -IPTC:all "$image_file" | wc -l | tr -d ' '
  )"

  if [[ -z "$orientation" && "$metadata_count" -eq 0 ]]; then
    continue
  fi

  if [[ -z "$orientation" || "$orientation" == "1" ]]; then
    exiftool -overwrite_original -all= "$image_file" >/dev/null
  else
    case "$orientation" in
      2) transform=(-flip horizontal) ;;
      3) transform=(-rotate 180) ;;
      4) transform=(-flip vertical) ;;
      5) transform=(-transpose) ;;
      6) transform=(-rotate 90) ;;
      7) transform=(-transverse) ;;
      8) transform=(-rotate 270) ;;
      *)
        echo "Unsupported EXIF orientation '$orientation' in $image_file" >&2
        exit 1
        ;;
    esac

    temporary_file="$(mktemp "${TMPDIR:-/tmp}/homelab-image.XXXXXX")"
    trap 'if [[ -n "${temporary_file:-}" && -f "$temporary_file" ]]; then rm -f "$temporary_file"; fi' EXIT

    jpegtran -copy none -optimize "${transform[@]}" \
      -outfile "$temporary_file" "$image_file"
    exiftool -overwrite_original -all= "$temporary_file" >/dev/null
    chmod 0644 "$temporary_file"
    mv "$temporary_file" "$image_file"
    temporary_file=""
  fi

  remaining_metadata="$(
    exiftool -s -EXIF:all -XMP:all -IPTC:all "$image_file" | wc -l | tr -d ' '
  )"
  remaining_orientation="$(exiftool -s3 -n -Orientation "$image_file")"

  if [[ "$remaining_metadata" -ne 0 || -n "$remaining_orientation" ]]; then
    echo "Metadata removal verification failed for $image_file" >&2
    exit 1
  fi

  echo "Normalized orientation and removed metadata: $image_file"
done
