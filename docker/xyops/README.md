# xyOps

Workflow automation and server monitoring stack. Runs a single conductor container that orchestrates jobs, events, and plugins across worker nodes.

- Upstream: [pixlcore/xyops](https://github.com/pixlcore/xyops)
- Image: `ghcr.io/pixlcore/xyops:latest`

---

## Deployment

### Prerequisites

- Docker + Compose V2
- The conductor hostname must be **resolvable by every worker** on your network. Use DNS, Tailscale, or add an `/etc/hosts` entry on each worker.

### Environment setup

Copy `.env.example` to `.env` and fill in the values:

```bash
cp .env.example .env
```

| Variable | Description |
|---|---|
| `USER` | Linux username on the Docker host (used for volume paths) |
| `TZ` | Host timezone (e.g. `America/Sao_Paulo`) |
| `XYOPS_HOSTNAME` | Fully-qualified hostname workers use to reach this conductor |
| `XYOPS_SECRET_KEY` | Encryption/auth secret — generate with `openssl rand -hex 32` |

### Start the stack

```bash
docker compose up -d
```

The UI is available at:
- `http://<host>:5522`
- `https://<host>:5523` (HTTPS / Secure WebSocket)

### Volumes

| Host path | Container path | Purpose |
|---|---|---|
| `appdata/` | `/opt/xyops/data` | SQLite DB, job history, state |
| `conf/` | `/opt/xyops/conf` | Config, TLS certs, email templates |
| `plugins/` | `/opt/xyops/plugins` | Custom event plugins |
| `/var/run/docker.sock` | `/var/run/docker.sock` | Docker integration (enabled) |

`appdata/` is gitignored — back it up separately if you need job history persistence.

---

## Conductor vs Worker

xyOps uses a conductor/worker architecture:

- **Conductor** — the single orchestration server (this stack). Stores all configuration, schedules events, and distributes jobs. The hostname must be reachable by workers.
- **Worker** — any machine running the xyOps satellite agent (`xysat`). Workers pull jobs from the conductor and execute them locally. The satellite is enabled in this stack via `XYOPS_xysat_local: "true"`, which means the conductor also acts as a local worker.

Multi-conductor clusters are possible by setting `XYOPS_masters` to a comma-separated list of hostnames.

---

## Secrets

API credentials for programmatic access are stored in `.secrets` (gitignored):

```
XYOPS_BASE_URL=http://localhost:5522
XYOPS_API_KEY=<your-api-key>
```

Generate an API key from the xyOps UI under **Admin → API Keys**.

---

## Plugins

Custom plugins live in `plugins/` and are mounted into the container at `/opt/xyops/plugins`. Each plugin is a subdirectory containing:

- `plugin.js` — the executable (Node.js; guaranteed available at `/usr/local/bin/node`)
- `plugin-def.json` — Portable Data Object (PDO) for importing the plugin via the xyOps UI

### Wire Protocol

Plugins communicate with xyOps over **JSON on STDIO**. Each message is a single JSON object followed by a newline:

```js
// Progress update
{ xy: 1, status: "Working..." }

// Structured table output (rendered in the UI)
{ xy: 1, table: { title: "...", header: ["Key", "Value"], rows: [...] } }

// Attach arbitrary data for downstream job chaining
{ xy: 1, data: { ...responseObject } }

// Exit success
{ xy: 1, code: 0 }

// Exit failure
{ xy: 1, code: 1, description: "Error message" }
```

### Parameter Interpolation

xyOps has two interpolation systems — they operate at different scopes and **must not be confused**:

| Syntax | Resolved by | Scope |
|---|---|---|
| `{{ param_id }}` | xyOps (native) | Upstream job output data |
| `{param_id}` | Plugin code | Sibling params within the same plugin invocation |

Use `{key}` in plugin param values to reference other params defined in the same plugin. Use `{{ key }}` only when the value comes from a previous job's output.

### Importing a Plugin

1. Open the xyOps UI → **Plugins → Import**
2. Upload `plugin-def.json`
3. The PDO format requires `type: "xypdf"`, `version: "1.0"`, and each item must have `type: "plugin"` (lowercase)

---

## Built-in Plugins

### `api-ingest`

**Path:** `plugins/api-ingest/`

Fetches JSON from any HTTP/HTTPS endpoint and passes the response as output data for downstream chaining.

**Params:**

| ID | Description |
|---|---|
| `url` | Full URL to fetch. Supports `{param_id}` interpolation. |
| `name` | Example sibling param — interpolated into the URL via `{name}`. Can also be fed from upstream job output using `{{ name }}`. |

**Example use case:** Chain this plugin as the first step in a workflow to pull external API data, then pass it to a downstream transformation or notification step.

**Command registered in xyOps:**
```
/usr/local/bin/node /opt/xyops/plugins/api-ingest/plugin.js
```

---

## Debugging

```bash
# Follow container logs
docker logs -f xyops-conductor-01

# Inspect the SQLite database directly
sqlite3 appdata/sqlite.db ".tables"
sqlite3 appdata/sqlite.db "SELECT key, substr(value,1,200) FROM items WHERE key LIKE 'global/plugins%';"
```

Useful debug loop via the API:
1. Trigger an event with `run_event`
2. Capture the returned job ID
3. Poll with `get_job` to inspect `data`, `table`, and `state` fields
