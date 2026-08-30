# Data layout

This document explains how the `data/` directory is structured, why it's structured that way, and how each app sees it from inside its container.

We follow the **[TRaSH Guides: Docker folder structure](https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Docker/)** convention so the *arr apps (Sonarr, Radarr) can use hardlinks and atomic moves instead of copy + delete.

## Folder tree

```
data/
├── torrents/              # qBittorrent writes here. *arr moves finished files out.
│   ├── movies/
│   ├── series/
│   └── music/
└── media/                 # Final library. Plex and Bazarr read from here.
    ├── movies/
    ├── series/
    └── music/
```

`.gitkeep` files keep each subfolder tracked (empty) in git so the structure is reproducible from a fresh clone.

## Who sees what (container mounts)

Each app only sees the part of `data/` it needs:

| App | Path in container | Path on host | Purpose |
| --- | --- | --- | --- |
| **Sonarr** | `/data` | `${DATA_DIR:-./data}` | Reads torrents, imports into media. Needs the whole tree for hardlinks. |
| **Radarr** | `/data` | `${DATA_DIR:-./data}` | Same as Sonarr. |
| **qBittorrent** | `/data/torrents` | `${DATA_DIR:-./data}/torrents` | Only writes downloads. Never touches media. |
| **Plex** | `/data/media` | `${DATA_DIR:-./data}/media` | Reads the final library. |
| **Bazarr** | `/data/media` | `${DATA_DIR:-./data}/media` | Reads the final library to fetch subtitles. |
| Jackett, FlareSolverr, Jellyseerr, Wizarr, Caddy | — | — | Don't access `data/`. |

## Why not mount `/data/movies` and `/data/downloads` separately?

That's the shortcut most quick-start guides suggest, and it's what this stack used to do. It works, but has a real cost:

- **No hardlinks**. When Radarr moves a finished file from `downloads/` to `movies/`, Docker treats the two mounts as separate filesystems even though they aren't. Radarr falls back to **copy + delete**: the file temporarily exists twice on disk, you pay double I/O, and the move isn't atomic.
- **No atomic moves**. If the process dies mid-move, you're left with a half-copied file in `movies/` and an orphan in `downloads/`.
- **Higher peak disk usage**. During the copy, a 50 GB movie temporarily needs 50 GB free plus the 50 GB it's copying from.
- **More SSD wear**. Unnecessary write amplification.

The TRaSH layout fixes all of this by mounting `/data` whole into the *arr apps. They see the same filesystem as the host, so the kernel can hardlink files between `torrents/` and `media/`, and a rename is a single inode operation.

## Inside the apps

Once the stack is up, configure each app's Root Folders to match:

- **Sonarr**: Settings → Media Management → Root Folders → add `/data/series`
- **Radarr**: Settings → Media Management → Root Folders → add `/data/movies`
- **qBittorrent**: Tools → Options → Downloads → Default Save Path → `/data/torrents`
- **Plex**: Add Library → Movies `/data/media/movies`, TV Shows `/data/media/series`, Music `/data/media/music`
- **Bazarr**: Settings → Sonarr/Radarr → Folder mappings with the same paths

## Adding a new media type

If you ever add Books (Readarr) or Audiobooks (Audiobookshelf), extend the layout the same way:

```bash
mkdir -p data/torrents/books data/torrents/audiobooks data/media/books data/media/audiobooks
touch data/torrents/{books,audiobooks}/.gitkeep data/media/{books,audiobooks}/.gitkeep
```

Mount `/data` in Readarr (or whatever new *arr you add), and `/data/torrents/<type>` in the torrent client. The hardlink trick still works because every folder stays under the same parent on the host.

## Migrating from the old layout

If you're coming from an older version of this stack that used a flat `data/{movies,series,music,downloads}/`, follow these steps. **Stop the stack first** so nothing is writing:

```bash
cd /opt/cyberdyne
docker compose down

# Move existing downloads into the new staging tree
mkdir -p data/torrents
mv data/downloads/* data/torrents/
rmdir data/downloads

# Move existing libraries into the new media tree
mkdir -p data/media
mv data/movies data/series data/music data/media/

# Restart
docker compose up -d
bash scripts/configure-base-urls.sh
docker compose restart
```

Then update the Root Folders inside Sonarr/Radarr to `/data/series` and `/data/movies` respectively. Plex and Bazarr need no changes (their `/data/media` mount target didn't change).

## Source

- [TRaSH Guides — Docker folder structure](https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Docker/)
- [Servarr Wiki — Hardlinks and atomic moves](https://wiki.servarr.com/docker-guide#hard-links-and-moves)
