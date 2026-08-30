# Cyberdyne

My Raspberry Pi home server config: media automation and network-wide ad-blocking DNS, running behind a single Caddy reverse proxy.

## Components

- **Caddy** — reverse proxy, single entrypoint routed by path
- **Sonarr** / **Radarr** — TV and movie automation
- **Jackett** + **FlareSolverr** — indexer manager and Cloudflare challenge solver
- **Bazarr** — automatic subtitles
- **qBittorrent** — torrent client
- **Plex** — media server
- **Jellyseerr** — request UI
- **Wizarr** — user invitations
- **Pi-hole** — network-wide DNS ad-blocking
- **Beszel** — CPU, RAM, and disk monitoring

See [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md) to bring the stack up.

## Acknowledgments

Forked from [Pelado-Nerdworks/media-stack](https://github.com/Pelado-Nerdworks/media-stack) — thanks for the starting point.
