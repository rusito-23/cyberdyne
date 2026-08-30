#!/usr/bin/env bash
# Creates the data/ directory structure following the TRaSH Guides
# convention (https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Docker/).
#
# Why this script exists: data/ is gitignored (media files are large and
# personal), so the structure can't be cloned from the repo. This script
# recreates it from scratch.
#
# Usage:
#   ./scripts/init-data-dirs.sh           # uses ./data (default)
#   DATA_DIR=/srv/media/data ./scripts/init-data-dirs.sh
#
# Idempotent: safe to run even if the folders already exist.

set -euo pipefail

DATA_DIR="${DATA_DIR:-./data}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { printf "${GREEN}[+]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[!]${NC} %s\n" "$*"; }

main() {
  log "Creating data/ structure at ${DATA_DIR} (TRaSH Guides layout)"

  # Torrents (staging): qBittorrent writes here, *arr moves finished files to media/
  for kind in movies series music; do
    mkdir -p "${DATA_DIR}/torrents/${kind}"
  done

  # Media (final library): Plex and Bazarr read from here
  for kind in movies series music; do
    mkdir -p "${DATA_DIR}/media/${kind}"
  done

  log "Structure created:"
  if command -v tree >/dev/null 2>&1; then
    tree -L 2 "${DATA_DIR}"
  else
    find "${DATA_DIR}" -type d | sort | sed 's/^/  /'
  fi

  echo
  warn "Next step: docker compose up -d"
  warn "Then: bash scripts/configure-base-urls.sh (for the subpaths)"
}

main "$@"
