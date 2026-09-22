# Deploy: nginx + Docker (VPS)

Default production path for SF: **Ubuntu LTS VPS → Docker Compose → host nginx (TLS) → subdomain routing**.

Optional alternative: Dokploy (PaaS UI + Traefik) if you want less manual nginx/CI — not required for this stack.

Related: [ARCHITECTURE.md](./ARCHITECTURE.md), [WORKFLOW.md](./WORKFLOW.md).

---

## Target layout

```text
Internet → :443 nginx (host)
              ├── app.example.com  → 127.0.0.1:3001  (SFFE)
              └── api.example.com  → 127.0.0.1:3002  (SFBE)
                     │
                     └── Docker network → postgres:5432  (db_sf / centimildb)
```

| Piece | Role |
|-------|------|
| **nginx (host)** | Edge reverse proxy, Certbot SSL, only public HTTP(S) |
| **Docker Compose** | Run API, FE, Postgres; publish app ports to **localhost** only |
| **Postgres** | One instance, volume `pgdata`; do not publish `5432` to the internet |
| **UFW** | Allow `22`, `80`, `443` only |

Extra services on the same VPS (Telegram API, trade API, …): same pattern — new internal port + new `server_name` (or path). Prefer **separate Postgres databases/users** per app on the shared instance.

---

## One-time VPS setup (checklist)

1. Ubuntu LTS, SSH keys, UFW (`22/80/443`).
2. Install Docker Engine + Compose plugin.
3. Install nginx + Certbot (`python3-certbot-nginx`).
4. Clone/copy compose stack under e.g. `/opt/sf/` (SFBE compose + env file, gitignored secrets).
5. DNS A records: `app` / `api` → VPS IP.
6. `docker compose up -d --build` (or pull pre-built images).
7. nginx `server` blocks → `proxy_pass` localhost ports; set `Host`, `X-Forwarded-For`, `X-Forwarded-Proto`.
8. `certbot --nginx` for each domain.
9. Set prod env: `Cors__Origins=https://app…`, `VITE_API_PREFIX=https://api…/` (or `/` if same-origin path proxy), Google OAuth origins.
10. Smoke: FE HTTPS, Swagger/API, login JWT/Google.

---

## CI/CD (recommended learning path)

```text
git push main
    → GitHub Actions (CI)
         → restore/build/test (optional)
         → build Docker images (SFBE, SFFE)
         → push to registry (GHCR / Docker Hub)
    → CD (same workflow or separate)
         → SSH to VPS
         → docker compose pull
         → run DB migrate (see below)
         → docker compose up -d
         → healthcheck curl https://api…/swagger or /health
```

### Principles

| Step | Do |
|------|----|
| Secrets | GitHub Actions secrets + VPS `.env` — never commit |
| Images | Tag with git SHA; deploy that tag (avoid floating `latest` only) |
| Zero-ish downtime | Pull new images → migrate → recreate API/FE containers; keep Postgres volume |
| Rollback | Redeploy previous image tag; reverse migration only if you wrote a safe `Down` |
| FE env | `VITE_*` baked at **image build** — wrong prefix ⇒ rebuild FE image |

### Minimal CD without a registry (acceptable early learning)

Actions SSHs to VPS → `git pull` (or rsync) → `docker compose build && up -d` → migrate.  
Prefer registry+pull once comfortable.

### Example job order on the VPS

```bash
# after new images are available
cd /opt/sf
docker compose pull
docker compose run --rm api dotnet ef database update --project ...   # or migrate sidecar / entrypoint flag
docker compose up -d
curl -fsS https://api.example.com/swagger/index.html >/dev/null
```

Exact `dotnet ef` paths depend on how the API image is built (SDK tool in a migrate job vs runtime). Prefer a **one-shot migrate container** or explicit CD step over silent auto-migrate in every web request once you leave early learning.

---

## Database schema migrations

SF uses **EF Core** migrations under `SFBE/src/Web.Infrastructure/Migrations/` (e.g. `InitialPostgres`).

### Dev (local)

1. Change entities / configurations.
2. From Infrastructure project context:

   ```powershell
   cd D:\Projects\SF\SFBE
   dotnet ef migrations add <Name> --project src\Web.Infrastructure --startup-project src\Web.API
   ```

3. Apply:

   ```powershell
   dotnet ef database update --project src\Web.Infrastructure --startup-project src\Web.API
   ```

   Or rely on app `MigrateAsync()` on startup in Development only (if enabled).

4. Commit migration `.cs` files with the feature.

### Deploy / prod

| Practice | Detail |
|----------|--------|
| **Source of truth** | Migration files in Git |
| **When** | Apply schema **before** or **as the first step of** serving traffic on the new API build |
| **How** | CD step: `database update` against prod connection string; or controlled startup migrate |
| **Backup first** | `pg_dump` (or volume snapshot) before non-trivial prod migrations |
| **Data** | Prefer additive migrations (new columns nullable / defaults); destructive changes need a plan |
| **Volume** | Never `docker compose down -v` on prod — that deletes Postgres data |
| **Multi-app VPS** | One Postgres instance, **separate databases** per app; migrate each app’s DB independently |

### Local Docker vs prod

| | Local compose | Prod VPS |
|--|---------------|----------|
| Host port | `5433` → container `5432` (avoid clash with native PG) | Prefer **no** public publish; only Docker network |
| Conn string | `Host=db;Port=5432;...` | Same hostname inside compose network |
| Apply migrations | compose up + MigrateAsync / ef update | CD migrate step + verify |

---

## Env mapping (prod)

Same keys as [SFBE/.env.example](../../SFBE/.env.example):

- `ConnectionStrings__CentimilDB`
- `Cors__Origins=https://app.example.com`
- `JWT__*`, Google, Blob as needed
- FE build-args: `VITE_API_PREFIX`, `VITE_GOOGLE_CLIENT_ID`

Subdomain split (recommended): `VITE_API_PREFIX=https://api.example.com/` + CORS includes `https://app.example.com`.  
Same-origin path proxy: FE nginx proxies `/api` → API, `VITE_API_PREFIX=/`.

---

## Phase D done when

- [ ] HTTPS FE and API reachable
- [ ] Login JWT / Google OK with prod origins
- [ ] Postgres data survives container recreate (volume)
- [ ] Documented way to ship a new migration via CI/CD or scripted SSH
- [ ] UFW does not expose Postgres or raw app ports
