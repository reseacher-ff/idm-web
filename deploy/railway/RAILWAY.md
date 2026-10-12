# Deploying IDM on Railway — single container

Everything (MariaDB + Kafka + the app) runs in **one** Docker container,
managed by supervisord. You deploy **one Railway service** and attach **one
volume**. That's the whole infrastructure.

## How it works

The image (`deploy/railway/Dockerfile`) is built in stages:

1. **Node** builds the React web UI.
2. **Go** builds the backend (the UI is embedded into the binary).
3. **Debian** fetches Kafka 3.9 (KRaft mode — no ZooKeeper needed).
4. **Runtime** (`debian:bookworm-slim`) installs MariaDB + a JRE + supervisord,
   then on every boot:
   - `init-mysql.sh` — creates the datadir on first run, ensures the `idm`
     database and user exist
   - `init-kafka.sh` — formats Kafka storage on first run
   - supervisord starts **mariadb**, **kafka**, and **idm** (the app waits for
     both, renders its config, pre-creates the Kafka topic, and starts)

All persistent state lives under `/data` (MySQL datadir, Kafka logs,
downloaded files) — attach one Railway volume there and everything survives
restarts/redeploys.

## Step-by-step

### 1. Push the code to your GitHub

- Create a repo called `idm` on github.com
- Upload the contents of the `idm` folder from the provided zip

### 2. Deploy it on Railway

- railway.app → **New Project** → **Deploy from GitHub repo** → pick `idm`
- Railway detects `deploy/railway/railway.json` and builds the Dockerfile
  (first build takes a few minutes — it's installing MariaDB, Java and Kafka)

### 3. Attach one volume

- In the service → **Volumes** → **New Volume**
- Mount path: `/data`
- (Optional but recommended) set a `DB_PASSWORD` variable — otherwise it
  defaults to `idm-change-me`. Change it before you store anything real.

### 4. Go public

- **Settings** → **Networking** → **Generate Domain**
- Open the URL → sign up → log in → paste a file URL → it downloads in
  about a second, in real time.

That's it. No MySQL plugin, no separate Kafka service, no env-var wiring —
the container sorts itself out on boot.

## Variables (all optional)

| Variable | Default | What it does |
|---|---|---|
| `PORT` | `8081` | Set automatically by Railway; the app listens on `0.0.0.0:$PORT` |
| `DB_PASSWORD` | `idm-change-me` | Password for the MariaDB `idm` user (applied on every boot) |
| `DATA_DIR` | `/data` | Where MySQL data, Kafka logs and downloads live |

## Download limits: **NO LIMIT**

No size cap, quota, or rate limit exists in the app — `internal/logic/downloader.go`
streams the response body unbounded with `io.Copy`, and this was verified with
a 464 MB bit-identical download. The only bounds are your infrastructure:

- **Disk**: the `/data` volume you attach (this is the real limit — size it
  per your Railway plan).
- **RAM caveat**: only if you switch `download.mode` to `s3` — the S3 writer
  buffers the whole file in memory (`internal/dataaccess/file/client.go`).
  The default `local` mode streams cleanly to disk.

## Logs

If something looks wrong: Railway → your service → **Logs**, or check the
per-process logs inside the container at `/var/log/supervisor/`
(`mariadb.log`, `kafka.log`, `idm.log`).

## Bugs fixed in this copy (vs upstream)

1. Web UI didn't build — added missing `superagent` dependency.
2. UI called `http://localhost:8081` from the browser — now same-origin.
3. SPA handler: missing `return` after serving assets, debug print on every
   request, nil-pointer panic path — fixed.
4. Kafka topic race (consumer needs the topic at startup) — `topicinit`
   helper pre-creates it on every boot.
5. `auth.hash.cost: 32` in the YAML is dead config (the wiring never passes
   it; Go's bcrypt default of 10 is always used) — documented, not "fixed".
