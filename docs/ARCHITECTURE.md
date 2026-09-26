# Architecture

## Overview

```
FE (React/Vite)  ──REST──▶  BE (.NET API)  ──▶  PostgreSQL
     │                           │
     └─ static build             └─ Kestrel
            │                          │
            └──── nginx (Linux VPS edge :80/:443) ────┘
```

Production: **Docker Compose** runs FE / API / Postgres; **nginx on the host** terminates TLS and reverse-proxies by subdomain (or path).  
Optional alternative: [Dokploy](https://dokploy.com/) (PaaS UI + Traefik) if you prefer less manual nginx/CI setup.

## Folders

| Path | Role |
|------|------|
| `FE/` / `SFFE/` | Frontend repo |
| `BE/` / `SFBE/` | Backend repo |
| `workspace/` | Hub: docs, Cursor rules, scripts |

## BE — modular monolith

- **Account** — JWT, Google OAuth, Identity
- **Instrument** — search, favorites, alerts
- **Market**, **Crypto** orders/signals
- **Restaurant / Dishes** — legacy template (có thể xóa)

## Production target

- DB: **PostgreSQL** (Docker volume; one instance, app-specific databases as needed)
- Runtime: .NET 8 → **.NET 10 LTS** (Phase E)
- Host: **Linux (Ubuntu LTS) + Docker + nginx** (edge reverse proxy + Certbot SSL)
- FE: `npm run build` → static files (often nginx inside the FE image; host nginx still fronts HTTPS)

### Suggested prod topology (learning / Hostinger VPS)

| App | Internal listen | Public URL (via host nginx) |
|-----|-----------------|-----------------------------|
| SFFE | `127.0.0.1:3001` | `https://app.example.com` |
| SFBE | `127.0.0.1:3002` | `https://api.example.com` |
| Postgres | Docker network `postgres:5432` only | *(no public URL)* |

Public firewall: **only `80` / `443`**. Do **not** open SSH (`22`) or Postgres (`5432`) to the internet — DB stays on the VPS Docker network; admin via provider console or private VPN.  
Full CI/CD + schema migration: [DEPLOY-NGINX-DOCKER.md](./DEPLOY-NGINX-DOCKER.md).

### Local PostgreSQL (Phase A)

Preferred for native `dotnet run`: **PostgreSQL 18** Windows (`postgresql-x64-18`) — DB `centimildb`, user `sf`, port **5432**.

Connection string key: `ConnectionStrings:CentimilDB`  
Default native: `Host=localhost;Port=5432;Database=centimildb;Username=sf;Password=sf_dev_password`

EF provider: `Npgsql.EntityFrameworkCore.PostgreSQL`. Migrations: `InitialPostgres`.

### Local Docker stack (Phase B)

From `SFBE/` (builds BE + FE from sibling `SFFE/`):

```powershell
cd D:\Projects\SF\SFBE
copy .env.example .env   # set VITE_GOOGLE_CLIENT_ID
docker compose up -d --build
```

| Service | URL / port |
|---------|------------|
| FE (nginx) | http://localhost |
| API | http://localhost:8080/swagger |
| API via FE proxy | http://localhost/api/... |
| Postgres (Docker) | host **5433** → container 5432 |

Docker DB uses host port **5433** so it does not clash with native PG 18 on 5432.

### Config / secrets (Phase C)

| Variable | Where | Purpose |
|----------|--------|---------|
| `ConnectionStrings__CentimilDB` | SFBE `.env` / VPS env | Postgres connection |
| `Cors__Origins` | SFBE `.env` / VPS env | Comma-separated FE origins (e.g. `http://localhost:5173,https://app.example.com`) |
| `JWT__Key`, `JWT__Issuer`, `JWT__Audience` | SFBE `.env` / VPS env | JWT signing |
| `Authentication__Google__ClientId/Secret` | SFBE `.env` / VPS env | Google OAuth (API) |
| `BlobStorage__*` | SFBE `.env` / VPS env | Azure Blob (optional local) |
| `VITE_API_PREFIX` | SFBE `.env` (compose build) / SFFE env | `/` behind nginx path proxy; full URL for native Vite or public API subdomain |
| `VITE_GOOGLE_CLIENT_ID` | FE build env | Required at FE boot |

- Native `dotnet run`: may keep using `appsettings.Development.json`.
- Docker compose: `api` loads `SFBE/.env` via `env_file` (copy from `.env.example`).
- Do not commit `.env`. Production sets the same keys in a gitignored file on the VPS (or CI secrets injected at deploy).

## Principles

1. Swagger = API contract
2. Env-based config
3. Backend before frontend
4. One workspace: `workspace/SF.code-workspace`
5. Edge = nginx; apps = Docker; schema changes = EF migrations (see deploy doc)
