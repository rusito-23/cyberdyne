# Getting started

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

See [DATA_LAYOUT.md](DATA_LAYOUT.md) for how `data/` is structured, and [INDEXERS.md](INDEXERS.md) for the full Jackett + FlareSolverr + Sonarr/Radarr indexer setup.
