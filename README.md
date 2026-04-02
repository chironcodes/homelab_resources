# homelab_resources

Personal homelab Docker Compose stacks for self-hosted services, plus scaffolding for custom-built applications.

## Repository Layout

```
docker/           — Compose stacks, one directory per service
  airflow/        — Apache Airflow (CeleryExecutor + Redis + PostgreSQL)
  cloudf-tunnel/  — Cloudflare Zero Trust tunnel daemon
  code-server/    — VS Code in the browser
  example-app/    — Template for custom-built apps (copy to start a new one)
  jenkins/        — Jenkins CI + Ansible
  kuma/           — Uptime Kuma monitoring
  neo4j/          — Neo4j graph database
  portainer/      — Portainer Docker management UI

apps/             — Source code for custom-built applications
  example-app/    — Reference template (copy to apps/<your-app>/ to start)
```

## Starting a Stack

```bash
cd docker/<service>
cp .env.example .env   # fill in values — .env is gitignored
docker compose up -d
```

For the Airflow stack (custom build):
```bash
cd docker/airflow
docker compose up --build -d
# Scale workers: docker compose up --build --scale airflow-worker=3 -d
```

## Adding a Custom Application

1. Copy `apps/example-app/` to `apps/<your-app>/` and write your code.
2. Copy `docker/example-app/` to `docker/<your-app>/` and update ports, env vars, and the build context path.
3. Copy `.env.example` to `.env` and set values.
4. Build and start: `docker compose up --build -d`

See [apps/example-app/Dockerfile](apps/example-app/Dockerfile) for the multi-stage build pattern and non-root user setup.

## Networks

Two named Docker networks are used for external routing. They are commented out in compose files pending routing strategy review. To re-enable:

```bash
docker network create nginx-default       # for nginx reverse proxy services
docker network create cloudfare-default   # for Cloudflare Tunnel services
```

Then uncomment the `networks:` blocks in the relevant compose files.

| Network             | Intended for                         |
|---------------------|--------------------------------------|
| `nginx-default`     | kuma, code-server                    |
| `cloudfare-default` | jenkins, portainer, cloudf-tunnel    |

## Conventions

| Convention | Rule |
|---|---|
| **Volumes** | Persistent data goes to `/home/${USER}/resources/docker/<service>/appdata/` — gitignored |
| **Secrets** | Use `.env` files (gitignored). Document all required vars in `.env.example` |
| **Log rotation** | Every service includes `logging: driver: json-file, max-size: 100m, max-file: 10` |
| **Non-root** | Dockerfiles must end with `USER <non-root-user>` before `CMD` |
| **Security** | All services include `security_opt: no-new-privileges:true` (except init containers that require root) |
| **Image tags** | `latest` is acceptable during development — pin to specific versions before production |

## Service Reference

| Service       | Port(s)    | Notes                                     |
|---------------|------------|-------------------------------------------|
| airflow       | 8080       | Custom build — run with `--build`         |
| cloudf-tunnel | —          | Runs in `network_mode: host`              |
| code-server   | 8443       | Requires `PUID`, `PGID`, `TZ`, `PASSWORD` |
| jenkins       | 8081       | Custom build (Jenkins + Ansible)          |
| kuma          | 3001       | Uptime monitoring dashboard               |
| neo4j         | 7474, 7687 | Includes APOC, n10s, graph-data-science   |
| portainer     | 9443       | Mounts Docker socket (read-only)          |
| xyops         | 5522, 5523 | Workflow automation and server monitoring |
