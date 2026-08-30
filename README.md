# Cyberdyne

My Raspberry Pi home server config: media automation and network-wide ad-blocking DNS, running behind a single Caddy reverse proxy. Grows as I add more self-hosted services over time.

## Components

- **Caddy** — reverse proxy, single entrypoint routed by path
- **Sonarr** / **Radarr** — TV and movie automation
- **Jackett** + **FlareSolverr** — indexer manager and Cloudflare challenge solver
- **Bazarr** — automatic subtitles
- **qBittorrent** — torrent client
- **Pi-hole** — network-wide DNS ad-blocking

## Setup

1. Clone the repo and copy the env example:

   ```bash
   git clone git@github.com:rusito-23/cyberdyne.git
   cd cyberdyne
   cp .env.example .env
   ```

2. Create the `data/` structure (gitignored, so it needs to be created locally):

   ```bash
   bash scripts/init-data-dirs.sh
   ```

3. Bring the stack up:

   ```bash
   docker compose up -d
   ```

4. Once each app has generated its initial config, set the Caddy subpaths and restart:

   ```bash
   bash scripts/configure-base-urls.sh
   docker compose restart
   ```

See [docs/DATA_LAYOUT.md](docs/DATA_LAYOUT.md) for how `data/` is structured, and [docs/INDEXERS.md](docs/INDEXERS.md) for the full Jackett + FlareSolverr + Sonarr/Radarr indexer setup.

## Acknowledgments

Forked from [Pelado-Nerdworks/media-stack](https://github.com/Pelado-Nerdworks/media-stack) — thanks for the starting point.
