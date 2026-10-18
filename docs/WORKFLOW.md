# Workflow

## Local dev

```powershell
cd D:\Projects\SF
.\workspace\scripts\dev.ps1
```

Hoặc thủ công:

```powershell
# Postgres — Windows PostgreSQL 18 on :5432
# BE
cd D:\Projects\SF\SFBE\src\Web.API
dotnet run

# FE
cd D:\Projects\SF\SFFE
npm start
```

FE env (`SFFE/.env.development`) — native Vite talking to API on 5272:

```env
VITE_API_PREFIX=http://localhost:5272/
VITE_GOOGLE_CLIENT_ID=...
VITE_ENABLE_MOCK=false
```

### Docker full stack (Phase B + C)

```powershell
cd D:\Projects\SF\SFBE
copy .env.example .env   # fill JWT, Google, VITE_GOOGLE_CLIENT_ID, ConnectionStrings
docker compose up -d --build
```

- FE: http://localhost (`VITE_API_PREFIX=/`, nginx proxies `/api`)
- API Swagger: http://localhost:8080/swagger
- Docker Postgres on host port **5433** (native PG 18 stays on 5432)
- API secrets/CORS come from `SFBE/.env` (`env_file`), not from committed secrets

## Feature mới

1. BE: endpoint + handler + **EF migration** (nếu đổi schema)
2. Test Swagger
3. Cập nhật `workspace/docs/API-MAP.md`
4. FE: `src/services/` → UI
5. Test E2E

Schema deploy rules: [DEPLOY-NGINX-DOCKER.md](./DEPLOY-NGINX-DOCKER.md#database-schema-migrations).

## Git

- `SFUI` / `SFWeb` (hoặc remote tương ứng) — branch cùng tên: `feature/xyz`
- `workspace/` — có thể repo riêng cho docs/scripts

## Cursor / AI

1. Mở `workspace/SF.code-workspace`
2. Một chat chính cho fullstack
3. Nói rõ: `BE only` / `FE only` / `fullstack`

## Migration roadmap

| Phase | Việc |
|-------|------|
| 0 | Hub setup ✓ |
| 1 | FE env config ✓ (Phase 1) |
| 2 | BE → PostgreSQL ✓ (Phase A) |
| 2b | Docker BE+FE ✓ (Phase B) |
| 3 | Config/secrets/CORS ✓ (Phase C) |
| 4 | **VPS: nginx + Docker deploy** (Phase D) — see [DEPLOY-NGINX-DOCKER.md](./DEPLOY-NGINX-DOCKER.md) |
| 5 | .NET 10 + Blob/nginx refine + Restaurant legacy cleanup (Phase E) ✓ |

Optional: Dokploy as an alternative PaaS UI instead of hand-rolled nginx/CI — not the default path.

## Legacy folders

`SFUI/` và `SFWeb/` là repo cũ. `FE/` và `BE/` đang junction trỏ vào đó — sửa code qua `FE/` hoặc `BE/` trong workspace. Khi sẵn sàng, chuyển git root vào `FE/`/`BE/` rồi xóa folder legacy.
