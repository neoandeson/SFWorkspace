# Architecture

## Overview

```
FE (React/Vite)  ──REST──▶  BE (.NET API)  ──▶  PostgreSQL (target)
     │                           │
     └─ static build             └─ Kestrel
            │                          │
            └──────── nginx (Linux VPS) ────────┘
```

## Folders

| Path | Role |
|------|------|
| `FE/` | Frontend repo (junction → `SFUI/`) |
| `BE/` | Backend repo (junction → `SFWeb/`) |
| `workspace/` | Hub: docs, Cursor rules, scripts |

## BE — modular monolith

- **Account** — JWT, Google OAuth, Identity
- **Instrument** — search, favorites, alerts
- **Market**, **Crypto** orders/signals
- **Restaurant / Dishes** — legacy template (có thể xóa)

## Production target

- DB: **PostgreSQL** (local: `SFBE/docker-compose.yml` service `db`)
- Runtime: .NET 8 → **.NET 10 LTS** (Phase E)
- Host: IIS → **Linux + nginx / Dokploy**
- FE: `npm run build` → static files

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
| `ConnectionStrings__CentimilDB` | SFBE `.env` / Dokploy | Postgres connection |
| `Cors__Origins` | SFBE `.env` / Dokploy | Comma-separated FE origins (e.g. `http://localhost:5173,http://localhost`) |
| `JWT__Key`, `JWT__Issuer`, `JWT__Audience` | SFBE `.env` / Dokploy | JWT signing |
| `Authentication__Google__ClientId/Secret` | SFBE `.env` / Dokploy | Google OAuth (API) |
| `BlobStorage__*` | SFBE `.env` / Dokploy | Azure Blob (optional local) |
| `VITE_API_PREFIX` | SFBE `.env` (compose build) / SFFE env | `/` behind nginx proxy; full URL for native Vite or public API |
| `VITE_GOOGLE_CLIENT_ID` | FE build env | Required at FE boot |

- Native `dotnet run`: may keep using `appsettings.Development.json`.
- Docker compose: `api` loads `SFBE/.env` via `env_file` (copy from `.env.example`).
- Do not commit `.env`. Production (Dokploy) sets the same keys in the UI.

## Principles

1. Swagger = API contract
2. Env-based config
3. Backend before frontend
4. One workspace: `workspace/SF.code-workspace`
