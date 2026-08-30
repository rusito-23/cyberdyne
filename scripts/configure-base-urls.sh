#!/usr/bin/env bash
# Configures each app's "Base URL" / "UrlBase" to match its Caddy subpath
# (/sonarr, /radarr, etc.).
#
# After this, each app responds ONLY on its subpath:
#   http://<IP>/sonarr     → Sonarr (with UrlBase=/sonarr)
#   etc.
#
# Idempotent: no-op if the value is already set.
#
# Apps that don't easily support a subpath and are left with a warning:
#   - jellyseerr: depends on the version, we try APP_BASE_URL as an env var
#   - wizarr: configured via the web UI on first login
#
# Usage:
#   ./scripts/configure-base-urls.sh
#
# Requires:
#   - The stack already up (docker compose up -d)
#   - Containers already booted at least once (so config.xml exists)

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { printf "${GREEN}[+]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[!]${NC} %s\n" "$*"; }
err()  { printf "${RED}[x]${NC} %s\n" "$*"; }

wait_for_config() {
  local container="$1"
  local path="$2"
  local timeout="${3:-120}"
  log "Waiting for ${container} to generate ${path}..."
  for i in $(seq 1 "$timeout"); do
    if docker exec "$container" test -f "$path" 2>/dev/null; then
      log "  ${container}: ${path} ready (${i}s)"
      return 0
    fi
    sleep 1
  done
  err "  ${container}: TIMEOUT waiting for ${path}"
  return 1
}

set_urlbase_xml() {
  # *arr apps: edit <UrlBase></UrlBase> in config.xml
  local container="$1"
  local path="$2"
  local value="$3"
  docker exec "$container" bash -c "
    if grep -q '<UrlBase></UrlBase>' '${path}'; then
      sed -i 's|<UrlBase></UrlBase>|<UrlBase>${value}</UrlBase>|' '${path}'
      echo '  UrlBase updated to ${value}'
    elif grep -q '<UrlBase>${value}</UrlBase>' '${path}'; then
      echo '  UrlBase already set to ${value} (no-op)'
    else
      echo '  WARN: <UrlBase></UrlBase> not found in ${path}; check manually'
    fi
  "
}

set_urlbase_bazarr() {
  # Bazarr: uses config.yaml, the url_base key may not exist yet
  local container="$1"
  local path="$2"
  local value="$3"
  docker exec "$container" bash -c "
    if grep -qE '^url_base:[[:space:]]*${value}' '${path}'; then
      echo '  Bazarr url_base already set to ${value} (no-op)'
    elif grep -qE '^url_base:' '${path}'; then
      sed -i 's|^url_base:.*|url_base: ${value}|' '${path}'
      echo '  Bazarr url_base updated'
    else
      # Doesn't exist — append it (Bazarr accepts top-level YAML keys)
      echo 'url_base: ${value}' >> '${path}'
      echo '  Bazarr url_base appended to the YAML'
    fi
  "
}

restart_apps() {
  log "Restarting apps to apply the new URL Base..."
  for c in "$@"; do
    if docker ps -q -f name="^/${c}\$" >/dev/null 2>&1; then
      docker restart "$c" >/dev/null
      log "  ${c}: restarted"
    else
      warn "  ${c}: not running, skipping"
    fi
  done
}

main() {
  log "============================================"
  log "  Configuring *arr stack URL Base"
  log "============================================"
  echo

  # *arr apps (config.xml with <UrlBase></UrlBase>)
  wait_for_config sonarr /config/config.xml 180
  set_urlbase_xml sonarr /config/config.xml /sonarr
  echo

  wait_for_config radarr /config/config.xml 180
  set_urlbase_xml radarr /config/config.xml /radarr
  echo

  # Bazarr (config.yaml at /config/config/config.yaml for the LSIO image)
  wait_for_config bazarr /config/config/config.yaml 180
  set_urlbase_bazarr bazarr /config/config/config.yaml /bazarr
  echo

  # Jellyseerr: depends on the version. If it supports APP_BASE_URL as an
  # env var, set it in the compose file before the first boot. Otherwise
  # it stays reachable only at root.
  warn "Jellyseerr: check whether it supports APP_BASE_URL as an env var. If not, it stays reachable only at root"
  echo

  # Wizarr: uses SQLite, not easily editable from here
  warn "Wizarr: configure the base URL manually on first login (Settings → General → Application URL)"
  echo

  restart_apps sonarr radarr bazarr

  echo
  log "============================================"
  log "  Done. Access URLs:"
  log "    http://<IP>/sonarr      → TV shows"
  log "    http://<IP>/radarr      → Movies"
  log "    http://<IP>/bazarr      → Subtitles"
  log "    http://<IP>/jellyseerr  → Requests (if subpath is supported)"
  log "    http://<IP>/wizarr      → Invitations (configure manually)"
  log "    http://<IP>:8080        → qBittorrent (dedicated port)"
  log "    http://<IP>:9117        → Jackett (dedicated port)"
  log "    http://<IP>:8191        → FlareSolverr (dedicated port)"
  log "    http://<IP>:32400/web   → Plex (dedicated port)"
  log "============================================"
}

main "$@"
