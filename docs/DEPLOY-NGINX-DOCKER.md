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
                     ├── Docker network → postgres:5432
                     └── Docker network → sf-telegram:3003  (alerts; not public)
```

Telegram sidecar (`TelegramTranmission`): clone to `/opt/sf/TelegramTranmission`, set `TELEGRAM_*` in SFBE `.env`, compose builds service `sf-telegram`. API uses `TELEGRAM_BotSendMessage_URL=http://sf-telegram:3003/sendMsg`. Do **not** put `/sendMsg` on nginx. See repo `TelegramTranmission/README.md`.

| Piece | Role |
|-------|------|
| **nginx (host)** | Edge reverse proxy, Certbot SSL; **only public ports `80` / `443`** |
| **Docker Compose** | Run API, FE, Postgres; publish app ports to **localhost** only |
| **Postgres** | One instance, volume `pgdata`; **Docker network only** — never publish `5432` to the host public interface / internet |
| **UFW (public)** | Allow **`80` and `443` only**. Do **not** open `22` to the world. |

### Admin access (no public SSH)

Prefer operating the VPS without exposing SSH:

- Provider **web console / VNC** (e.g. Hostinger panel), or
- **VPN / Tailscale / WireGuard**, or
- SSH bound to a private interface / allowlisted IP only (never `0.0.0.0/0` on `22`)

CI/CD that needs a shell should use the same private path (self-hosted runner on the VPS, Tailscale SSH, or console-triggered deploy) — not an open `22` from the internet.

Extra services on the same VPS (Telegram API, trade API, …): same pattern — new internal port + new `server_name` (or path). Prefer **separate Postgres databases/users** per app on the shared instance.

---

## One-time VPS setup (checklist)

1. Ubuntu LTS; UFW: allow **`80/tcp`**, **`443/tcp`** only (default deny incoming). Manage the box via provider console or private VPN — **do not** open `22` publicly.
2. Install Docker Engine + Compose plugin.
3. Install nginx + Certbot (`python3-certbot-nginx`).
4. Clone/copy compose stack under e.g. `/opt/sf/` (SFBE compose + env file, gitignored secrets). Postgres: no `ports:` to the public host (or only if needed for local debug on `127.0.0.1` — never `0.0.0.0:5432`).
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
         → reach VPS via private path (self-hosted runner / Tailscale / console — not public :22)
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
| Reachability | Do not open SSH to `0.0.0.0/0` for CD; prefer runner on the VPS or VPN |

### Minimal CD without a registry (acceptable early learning)

On the VPS (console or private VPN): `git pull` (or rsync over private net) → `docker compose build && up -d` → migrate.  
Prefer registry + pull once comfortable.

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
| Host port | `5433` → container `5432` (avoid clash with native PG) | **No** host publish; apps reach DB only on Docker network (`Host=db`) |
| Conn string | `Host=db;Port=5432;...` | Same; never a public IP:`5432` |
| Apply migrations | compose up + MigrateAsync / ef update | CD migrate step on the VPS (same Docker network) + verify |

---

## Env mapping (prod)

Same keys as [SFBE/.env.example](../../SFBE/.env.example):

- `ConnectionStrings__CentimilDB`
- `Cors__Origins=https://app.example.com`
- `JWT__*`, Google OAuth as needed
- FE build-args: `VITE_API_PREFIX`, `VITE_GOOGLE_CLIENT_ID`
- Telegram: `TELEGRAM_BOT_TOKEN`, `TELEGRAM_BOT_APPKEY`, `TELEGRAM_ID`, `TELEGRAM_BotSendMessage_URL`, optional `TELEGRAM_CONTEXT`

Subdomain split (recommended): `VITE_API_PREFIX=https://api.example.com/` + CORS includes `https://app.example.com`.  
Same-origin path proxy: FE nginx proxies `/api` → API, `VITE_API_PREFIX=/`.

### Prod compose + host nginx artifacts

| Artifact | Path |
|----------|------|
| Local learning compose | `SFBE/docker-compose.yml` (FE `:80`, API `:8080`, DB host `:5433`) |
| Prod-oriented compose | `SFBE/docker-compose.prod.yml` — FE/API bound to `127.0.0.1:3001` / `:3002`; Postgres **no** host publish |
| Host nginx vhosts | [`deploy/nginx/`](../deploy/nginx/) (`sf-app.conf` / `sf-api.conf`) or combined [`examples/nginx-host-app-api.conf`](./examples/nginx-host-app-api.conf) |

Runtime: **.NET 10** API image (`SFBE/Dockerfile`). Azure Blob was removed with the Restaurant logo feature; re-add only if a new upload use-case needs it. EF migration `DropRestaurantLegacy` drops `Restaurants` / `Dishes` tables.

---

## Phase D done when

- [ ] HTTPS FE and API reachable
- [ ] Login JWT / Google OK with prod origins
- [ ] Postgres data survives container recreate (volume)
- [ ] Documented way to ship a new migration via CI/CD or on-box script (no public SSH required)
- [ ] UFW public: **only `80` / `443`** — no `22`, no Postgres, no raw app ports
- [ ] Postgres reachable only inside the VPS Docker network
