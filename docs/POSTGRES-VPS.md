# PostgreSQL trên VPS — quyết định & lưu ý setup

Tài liệu vận hành (Hostinger VPS). Liên quan: [ARCHITECTURE.md](./ARCHITECTURE.md), [DEPLOY-NGINX-DOCKER.md](./DEPLOY-NGINX-DOCKER.md), compose prod: `SFBE/docker-compose.prod.yml`.

---

## 1. Đã chốt gì

| Quyết định | Chi tiết |
|------------|----------|
| **Một Postgres dùng chung** | Container Hostinger/Dokploy: `postgresql-ci6n-postgresql-1` (image `postgres:17`) |
| **Không** chạy Postgres riêng trong compose SF | Đã bỏ service `db` / container `sf-postgres` khỏi `docker-compose.prod.yml` |
| **Tách database theo app** | SF dùng DB `centimildb`; instance còn DB mặc định `pgdbvps` (và `postgres`) |
| **Không mở port 5432 ra internet** | Postgres chỉ trong Docker network; UFW public chỉ `80`/`443` |
| **Admin UI** | pgAdmin trên **PC personal** qua **SSH Tunnel** (tab trong pgAdmin), không publish DB |

Local (PC): vẫn dùng `SFBE/docker-compose.yml` có service `db` (`Host=db`) hoặc Postgres Windows native — không đụng setup VPS.

---

## 2. Việc đã làm (checklist lịch sử)

1. Chọn giữ Postgres chung `postgresql-ci6n`, bỏ Postgres trùng của stack SF.
2. Cập nhật repo `SFBE`:
   - `docker-compose.prod.yml` — không còn service `db`; API join network external Postgres; conn string build từ `POSTGRES_*`.
   - `.env.example` — thêm `POSTGRES_HOST`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DOCKER_NETWORK`.
3. Trên VPS: tạo DB `centimildb` (owner user Postgres của instance).
4. Trên VPS: điền `/opt/sf/SFBE/.env` với `POSTGRES_*` (file **gitignore**, `git pull` **không** ghi đè).
5. `git pull` + `docker compose -f docker-compose.prod.yml up -d --build`; gỡ `sf-postgres` nếu còn.
6. EF migrate / seed chạy qua API → schema + user seed trong `centimildb`.
7. Kết nối pgAdmin từ PC personal tới VPS (SSH tunnel) để quản trị.

Trạng thái đã xác nhận: `sf-api` / `sf-web` / `postgresql-ci6n-postgresql-1` chạy; `centimildb` có bảng (Identity, Crypto*, …) và seed users.

---

## 3. Thông số thực tế (VPS)

| Mục | Giá trị (thời điểm setup) |
|-----|---------------------------|
| VPS IP | `72.62.196.220` |
| Container Postgres | `postgresql-ci6n-postgresql-1` |
| User DB | `pguser` (không có role mặc định `postgres`) |
| Password | `POSTGRES_PASSWORD` trong panel / `printenv` của container — **không commit** |
| DB mặc định panel | `pgdbvps` |
| DB của SF | `centimildb` |
| Port trong Docker | `5432` |
| IP container (ví dụ) | `172.16.1.2` — **có thể đổi** sau recreate → kiểm tra lại bằng `docker inspect` |
| Network compose SF | `POSTGRES_DOCKER_NETWORK` (mặc định gợi ý `postgresql-ci6n_default`) — **phải** khớp network thật của container Postgres |

Kiểm tra trên VPS:

```bash
docker exec postgresql-ci6n-postgresql-1 printenv | grep -E 'POSTGRES_USER|POSTGRES_DB'
docker inspect postgresql-ci6n-postgresql-1 --format '{{range.NetworkSettings.Networks}}{{.IPAddress}} {{end}}'
docker inspect postgresql-ci6n-postgresql-1 --format '{{json .NetworkSettings.Networks}}'
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}"
```

`psql` trong container phải chỉ rõ database (không mặc định DB = tên user):

```bash
docker exec -it postgresql-ci6n-postgresql-1 psql -U pguser -d pgdbvps -c '\l'
```

---

## 4. Connection string — local vs prod

### Prod (`docker-compose.prod.yml`)

API **không** dùng `Host=db`. Compose ghi đè:

`ConnectionStrings__CentimilDB` ← `POSTGRES_HOST` + `POSTGRES_DB` + `POSTGRES_USER` + `POSTGRES_PASSWORD`.

Trong `/opt/sf/SFBE/.env` cần có (ví dụ):

```env
POSTGRES_HOST=postgresql-ci6n-postgresql-1
POSTGRES_DB=centimildb
POSTGRES_USER=pguser
POSTGRES_PASSWORD=...
POSTGRES_DOCKER_NETWORK=postgresql-ci6n_default
```

Dòng `ConnectionStrings__CentimilDB=Host=db;...` trong `.env` (nếu còn) **bị bỏ qua** khi chạy prod compose — có thể sửa cho dễ đọc nhưng không bắt buộc.

### Local (`docker-compose.yml`)

Giữ `Host=db` (service Postgres trong compose local).

### `git pull` trên VPS

| File | Pull có ghi đè? |
|------|-----------------|
| `.env` | **Không** (gitignore) |
| `docker-compose.prod.yml`, `.env.example` | **Có** (theo repo) |

---

## 5. pgAdmin trên PC personal

**Cách khuyến nghị:** tab **SSH Tunnel** trong pgAdmin (không cần CMD `ssh -L`).

| Tab | Ô | Giá trị |
|-----|---|---------|
| SSH Tunnel | Use SSH tunneling | On |
| | Tunnel host | `72.62.196.220` |
| | Tunnel port | `22` |
| | Username | `root` (hoặc user SSH VPS) |
| | Authentication | Password (hoặc identity file) |
| Connection | Host name/address | IP container, vd. `172.16.1.2` (**không** `localhost` khi dùng SSH Tunnel của pgAdmin) |
| | Port | `5432` |
| | Maintenance database | `centimildb` |
| | Username | `pguser` |
| | Password | password Postgres |

**Không trộn hai cách:**

- SSH Tunnel **On** → Connection Host = IP container (hoặc hostname resolve được **từ VPS**), Port `5432`.
- Hoặc CMD `ssh -N -L 15432:172.16.1.2:5432 ...` → SSH Tunnel **Off**, Connection = `localhost` / `15432`.

Lưu ý PC personal: cổng local `5432` thường bị Postgres Windows chiếm → nếu dùng CMD tunnel thì map `15432` (hoặc cổng khác), không map `5432`.

**Không** mở `0.0.0.0:5432` trên VPS chỉ để dùng pgAdmin.

---

## 6. Lưu ý vận hành / kiến trúc

1. **Một instance Postgres, nhiều database** — phù hợp monolith + vài app trên cùng VPS; không bắt buộc mỗi app một container Postgres.
2. App khác (Hermes, …) có thể dùng cùng instance với **DB/user riêng**; tránh share chung một DB/schema với SF nếu không cố ý.
3. API và Postgres **phải cùng Docker network** — sai `POSTGRES_DOCKER_NETWORK` → API không resolve hostname.
4. Sau recreate container Postgres, **IP đổi** → cập nhật Host trong pgAdmin (và bất kỳ chỗ hardcode IP nào).
5. Schema do **EF migrations** tạo; không restore file `.bak` MSSQL vào Postgres.
6. **Chưa làm (bước sau):** copy data production từ MSSQL → `centimildb` (pgloader / CSV / script) — **không** dùng API Update/Patch để đổ data.
7. Sau bulk import kèm Id cũ: reset sequence/identity Postgres (`setval`) trước khi app insert thêm.
8. Seed hiện tại chỉ user/roles tối thiểu — không thay thế full data MSSQL.

---

## 7. Lệnh vận hành nhanh (VPS)

```bash
cd /opt/sf/SFBE
git pull
# chỉnh .env nếu cần (POSTGRES_*), rồi:
docker compose -f docker-compose.prod.yml up -d --build
docker logs sf-api --tail 80
docker rm -f sf-postgres   # chỉ khi còn sót container cũ
```

Smoke: FE/API qua nginx HTTPS; pgAdmin xem `centimildb` → Tables.

---

## 8. Việc còn lại (backlog)

- [ ] Import data từ MSSQL sang `centimildb` (tool/script, thứ tự FK, reset sequences)
- [ ] (Tuỳ chọn) Map Postgres `127.0.0.1:5432` trên VPS để pgAdmin Connection Host = `127.0.0.1` ổn định hơn IP Docker
- [ ] Cập nhật CI/CD migrate bước nếu chưa có job riêng trên VPS
