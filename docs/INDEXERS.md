# Indexers, Jackett, and FlareSolverr

> This document covers the part that got cut from the YouTube video about
> the stack. YouTube doesn't explain exactly which clip violates its
> guidelines, so the idea is to keep the full detailed setup here, in text,
> where it can be described step by step without ambiguity.

This doc assumes the stack is already up (see [GETTING_STARTED.md](GETTING_STARTED.md)). If
Jackett and FlareSolverr are running, we're good to go.

---

## Why we talk in internal URLs

Every service in the stack shares the `proxy` Docker network. That means
**containers can see each other by name inside the network**. If Radarr
wants to talk to Jackett, it doesn't need to go out to the Internet or
through Caddy: it just hits `http://jackett:9117` and that's it.

That's the URL we'll use everywhere:

| From | To Jackett | To FlareSolverr |
| --- | --- | --- |
| From your browser | `http://<your-server>:9117` | `http://<your-server>:8191` |
| From a *arr (Sonarr/Radarr) | `http://jackett:9117` | `http://flaresolverr:8191` |
| From Jackett to FlareSolverr | — | `http://flaresolverr:8191/` |

Using the external URL (`<your-server>:9117`) from inside the *arr apps
also works, but it needlessly goes through Caddy/the public network. The
internal URL is faster and doesn't depend on the proxy being up.

---

## 1. Adding indexers in Jackett

1. Open Jackett at `http://<your-server>:9117`.
2. First time in, it asks you to set an admin password. **Write it down** —
   it's the same one it'll ask for every time you log in.
3. Click **+ Add Indexer**.
4. Search for the tracker you want to add (there are hundreds: 1337x, RARBG,
   YTS, etc.).
5. Click it → the configuration screen opens:
   - **Configure site**: if the tracker requires login (username and
     password), fill in the fields. Public trackers often need nothing.
   - **Configure Torznab**: you can set extra capabilities (categories,
     language, etc.). Leave the defaults to start.
6. Click **OK** and you're back at the main list.

Test that it works by clicking the indexer you just added. In the indexer
list, the status icon on the left should be green. If it's red/yellow, check
the JSON response shown below the "Download Select" button — it tells you
what broke.

### Getting the Torznab feed URL

For each indexer you want to use from the *arr apps, you need its Torznab
feed URL:

1. In the main list, find the indexer.
2. Right-click it → **Copy Feed URL** (or the "Copy" button next to the
   Torznab feed shown in the list).
3. You'll get something like:

   ```
   http://jackett:9117/api/v2.0/indexers/1337x/results/torznab/api?apikey=ABC123...
   ```

   That's the URL you'll paste into Sonarr/Radarr.

### Jackett API key

You need it so the *arr apps can authenticate against the feed. It's in the
top-right of the Jackett UI, under **Dashboard → API Key**. It's the same
key for every indexer, not per-indexer.

---

## 2. Configuring FlareSolverr in Jackett

Many major trackers (1337x, RARBG, The Pirate Bay, and plenty more) put a
**Cloudflare Challenge** in front. Without something to solve it, Jackett
can't fetch the page and parse results. That's where FlareSolverr comes in:
a proxy that uses a headless Chrome to solve the challenge and hand back
clean HTML.

> **TL;DR**: if your favorite indexer fails with something like "Cloudflare
> detected" or "403 Forbidden" in Jackett's logs, this step is what you're
> missing.

### Per-indexer configuration (recommended)

1. In Jackett, click the indexer having the problem (not "Add Indexer" —
   click the existing one).
2. Scroll to the bottom of the form. There's a dropdown labeled
   **FlareSolverr Proxy** with values like `Disabled` and `FlareSolverr`.
3. Change it to **FlareSolverr**.
4. A field appears for the URL. Enter:

   ```
   http://flaresolverr:8191/
   ```

   (Note the trailing slash — some trackers complain without it.)
5. Click **OK** and test the indexer again.

### Global configuration (optional)

If you want FlareSolverr on by default for every indexer that supports it,
you can set the environment variable when the container starts:

```yaml
# docker-compose.yml, in the 'jackett' service
environment:
  - FlareSolverrUrl=http://flaresolverr:8191/
```

Then restart Jackett and any new indexers will use it by default. Ones you
already configured keep their individual settings.

---

## 3. Configuring indexers in Radarr and Sonarr

Now the part that ties everything together. Repeat this for every indexer
you want to use in Radarr (movies) and Sonarr (TV).

### In Sonarr (TV)

1. Open Sonarr at `http://<your-server>/sonarr`.
2. **Settings → Indexers → Add → Torznab** (not Prowlarr or Newznab —
   Jackett's feed is Torznab).
3. Fill in the form:

   | Field | Value |
   | --- | --- |
   | **Name** | Whatever you want (e.g. `1337x via Jackett`). |
   | **Enable** | `ON` |
   | **URL** | The Torznab feed URL you copied from Jackett. **It must start with `http://jackett:9117/...`**, not `http://<your-server>:9117/...`. If you have the public URL, replace the first part with `jackett:9117`. |
   | **API Key** | Jackett's API key (Dashboard → API Key). |
   | **Categories** | `5000, 5020, 5030, 5040, 5045, 5050, 5060` (standard for TV; add/remove as needed). |
   | **Anime Categories** | `5070` if you want anime to show up under TV. |
   | **Tags** | Leave empty for now. The `flaresolverr` tag is only if you configured FlareSolverr as an Indexer Proxy in the *arr app (see bonus section below) — it's not required. |
   | **Anime Standard Format Search** | `ON` only if you'll be using anime. |

4. Click **Test**. If it says "Test was successful", save.
5. Repeat for every indexer you want available.

### In Radarr (movies)

1. **Settings → Indexers → Add → Torznab**.
2. Same fields, with these changes:

   | Field | Value |
   | --- | --- |
   | **URL** | Same pattern: `http://jackett:9117/api/v2.0/indexers/.../torznab/...` |
   | **API Key** | Jackett's API key. |
   | **Categories** | `2000, 2010, 2020, 2030, 2040, 2045, 2050, 2060` (movies, including HD and UHD). |
   | **Tags** | Leave empty. |

3. **Test** and save.

---

## Bonus: FlareSolverr as an Indexer Proxy in the *arr apps

Instead of configuring FlareSolverr inside Jackett, you can configure it in
the *arr app as an Indexer Proxy. Both approaches work; this one has the
advantage that every indexer configured as Torznab benefits from the proxy
without touching each one individually, and the disadvantage that the *arr
app has to wait for FlareSolverr to solve the challenge before it can ask
Jackett for results (one extra round trip).

If you want to go this route:

1. In the *arr app: **Settings → Indexer Proxies → Add → FlareSolverr**.
2. **Host**: `flaresolverr` (the container's name on the `proxy` network).
3. **Port**: `8191`.
4. **URL Base**: leave empty.
5. Click **Save**. It takes you to the **Tags** step — check every indexer
   you want routed through the proxy.
6. Each indexer you checked inherits the config and will use FlareSolverr
   for challenges.

> **My recommendation**: configure FlareSolverr in Jackett (section 2 of
> this doc). It's simpler, faster, and challenges are solved once and
> cached for every indexer that asks for the same thing. The *arr-as-Indexer-
> Proxy approach is only useful if you have indexers that aren't inside
> Jackett (like direct Prowlarr or Newznab feeds).

---

## Troubleshooting

- **"Test was successful" but searches return 0 results.** The indexer
  works but has no feeds for what you're searching. Try something popular
  (a well-known release) to rule this out.
- **Indexers show green in Jackett but fail in the *arr app.** Almost
  always means you pasted the external URL (`http://<your-server>:9117/...`)
  instead of the internal one (`http://jackett:9117/...`). Edit the indexer
  and fix it.
- **"401 Unauthorized" error on the *arr app's indexers.** Jackett's API key
  was copied wrong or got regenerated. Copy it again from Jackett's
  Dashboard.
- **Jackett doesn't respond at `http://jackett:9117` from the *arr app.**
  Both containers need to be on the same Docker network. They are here (the
  `proxy` network), so if it's failing, something custom broke it. Check
  with `docker inspect <container> | grep Networks`.
- **Cloudflare challenge still isn't solved after configuring
  FlareSolverr.** Check logs: `docker logs flaresolverr`. Chrome headless
  errors can mean the container doesn't have enough RAM (FlareSolverr spins
  up a real Chromium, needing ~300-500 MB per request). Add RAM to the host
  or lower indexer concurrency.
- **Jackett returns "Indexer download error: Connection refused".** The
  FlareSolverr service isn't running or is on a different network. Check
  with `docker compose ps flaresolverr`.
