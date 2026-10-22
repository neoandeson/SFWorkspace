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
| **Migrate data** | Export CSV từ MSSQL → import bằng pgAdmin (không dùng API Update/Patch) |

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
8. Import bảng **`Instruments`** từ MSSQL (~362 rows) qua CSV + pgAdmin; EBoard (`app.kofani.net`) đọc được data.

Trạng thái: `sf-api` / `sf-web` / `postgresql-ci6n-postgresql-1` chạy; `centimildb` có schema; Instruments đã có data production.

---

## 3. Thông số thực tế (VPS) — cấu hình quan trọng

| Mục | Giá trị (thời điểm setup) |
|-----|---------------------------|
| VPS IP | `72.62.196.220` |
| App FE / API (host nginx) | `127.0.0.1:3001` / `127.0.0.1:3002` |
| Container Postgres | `postgresql-ci6n-postgresql-1` |
| User DB | `pguser` (**không** có role mặc định `postgres`) |
| Password | `POSTGRES_PASSWORD` trong panel / `printenv` của container — **không commit** |
| DB mặc định panel | `pgdbvps` |
| DB của SF | `centimildb` |
| Port trong Docker | `5432` |
| IP container (ví dụ) | `172.16.1.2` — **có thể đổi** sau recreate → kiểm tra lại bằng `docker inspect` |
| Network compose SF | `POSTGRES_DOCKER_NETWORK` (gợi ý `postgresql-ci6n_default`) — **phải** khớp network thật của container Postgres |
| MSSQL nguồn | Server riêng (RDP/SSMS); DB `CentimilDB` — thao tác export trên server đó |

Kiểm tra trên VPS:

```bash
docker exec postgresql-ci6n-postgresql-1 printenv | grep -E 'POSTGRES_USER|POSTGRES_DB|POSTGRES_PASSWORD'
docker inspect postgresql-ci6n-postgresql-1 --format '{{range.NetworkSettings.Networks}}{{.IPAddress}} {{end}}'
docker inspect postgresql-ci6n-postgresql-1 --format '{{json .NetworkSettings.Networks}}'
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}"
```

`psql` trong container phải chỉ rõ database (không mặc định DB = tên user):

```bash
docker exec -it postgresql-ci6n-postgresql-1 psql -U pguser -d pgdbvps -c '\l'
docker exec -it postgresql-ci6n-postgresql-1 psql -U pguser -d centimildb -c '\dt'
```

---

## 4. Connection string — local vs prod

### Prod (`docker-compose.prod.yml`)

API **không** dùng `Host=db`. Compose ghi đè:

`ConnectionStrings__CentimilDB` ← `POSTGRES_HOST` + `POSTGRES_DB` + `POSTGRES_USER` + `POSTGRES_PASSWORD`.

Trong `/opt/sf/SFBE/.env` cần có:

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

- SSH Tunnel **On** → Connection Host = IP container (resolve được **từ VPS**), Port `5432`.
- Hoặc CMD `ssh -N -L 15432:172.16.1.2:5432 ...` → SSH Tunnel **Off**, Connection = `localhost` / `15432`.

Lưu ý PC personal: cổng local `5432` thường bị Postgres Windows chiếm → nếu dùng CMD tunnel thì map `15432`, không map `5432`.

**Không** mở `0.0.0.0:5432` trên VPS chỉ để dùng pgAdmin.

Import CSV: dùng luôn pgAdmin (file trên PC personal) — **không bắt buộc** WinSCP / `docker cp`.

---

## 6. Migrate data MSSQL → Postgres (CSV)

### 6.1 Nguyên tắc

- Schema do **EF migrations** tạo sẵn; chỉ copy **data**.
- **Không** restore `.bak` MSSQL vào Postgres.
- **Không** dùng API Update/Patch để đổ data.
- Ưu tiên **CSV + pgAdmin Import**; SQL INSERT từ SSMS thường **không chạy nguyên** trên PG (xem §6.4).

### 6.2 Export CSV từ SSMS (server MSSQL)

| Cách | Thao tác |
|------|----------|
| Nhanh | Query `SELECT * FROM dbo.<Table>` → **Results to Grid** → click phải lưới → **Save Results As…** → CSV |
| Wizard | Chuột phải **database** `CentimilDB` (không phải bảng) → **Tasks** → **Export Data…** → Flat File CSV |

**Không dùng** Results to Text (file canh cột bằng space; cột `Note` nhiều dòng sẽ vỡ row).

Click phải từng bảng **không** có mục “Export CSV”.

### 6.3 Checklist file CSV trước khi import

| Kiểm tra | Chi tiết |
|----------|----------|
| UTF-8 **không BOM** | BOM gây lỗi `invalid input syntax … "ï»¿Id"` |
| Phân tách phẩy + header dòng 1 | CSV thật, không phải text cố định độ rộng |
| **Thứ tự cột** | pgAdmin `\copy` map theo **thứ tự cột bảng PG**, không theo tên header CSV. Sắp CSV khớp thứ tự cột bảng (hoặc map cột trong wizard) |
| Null Strings | SSMS hay ghi text `NULL` → trong pgAdmin Import đặt Null Strings = `NULL` |
| Multiline (`Note`, …) | Được nếu giá trị nằm trong `"..."` |

**Thứ tự cột `Instruments` (khớp EF / pgAdmin)** — đã dùng thành công:

```text
Id, Name, Price, Symbol, Description, Type, Section, TableName,
UpdateDate, ChangeDate, IsFavorite, IsTrading, IsNotifyRSIUnderSetting,
LowPriceAlert, HighPriceAlert, CMA, CMAText, CMAState, CMAUpdateTime,
RSIText, RSI, RSIState, RSIOverUpdateTime, EMA34Text, EMA34State, EMA34UpdateTime,
EMA89Text, EMA89State, EMA89UpdateTime, EMA610Text, EMA610State, EMA610UpdateTime,
SMA208Text, SMA208State, SMA208UpdateTime, Priority, IsViewed, Note, TimeFrame
```

Import pgAdmin: bảng `"Instruments"` → Import/Export Data → Header = Yes → Null Strings = `NULL`.

Sau import (mọi bảng có identity/serial):

```sql
SELECT setval(pg_get_serial_sequence('"Instruments"', 'Id'),
  COALESCE((SELECT MAX("Id") FROM "Instruments"), 1));
-- lặp tương tự cho bảng khác: thay tên bảng / cột Id
```

### 6.4 MSSQL vs PostgreSQL (khi đụng raw SQL)

| Chủ đề | MSSQL | PostgreSQL |
|--------|--------|------------|
| Quote tên | `[Table]`, `[Col]` | `"Table"`, `"Col"` (PascalCase EF) |
| String | `N'...'` | `'...'` (UTF-8) |
| Boolean | `bit` 0/1 | `boolean` (0/1 thường OK với COPY) |
| Identity | `IDENTITY` / `IDENTITY_INSERT` | insert Id tường minh rồi `setval` |
| Ngày giờ | `datetime` / `datetime2` | `timestamp` / `timestamptz` |
| Schema | `dbo` | `public` |

Generate Scripts INSERT từ SSMS **không** paste nguyên vào PG — cần convert hoặc dùng CSV.

### 6.5 Thứ tự bảng còn lại (FK)

```text
AspNetRoles → AspNetUsers → AspNetUserRoles / Claims / Logins / Tokens
Settings / EndpointMappings / Strategies (nếu có)
CryptoSignals → CryptoSignalHistories
CryptoOrders → CryptoOrderHistories
```

Không import Restaurant/Dishes (đã drop trên PG).

Truncate/replace: xóa bảng con trước; cẩn thận đụng seed `AspNetUsers` nếu chỉ muốn giữ user seed.

---

## 7. Lưu ý vận hành / kiến trúc

1. **Một instance Postgres, nhiều database** — phù hợp monolith + vài app trên cùng VPS.
2. App khác có thể dùng cùng instance với **DB/user riêng**.
3. API và Postgres **phải cùng Docker network**.
4. Sau recreate container Postgres, **IP đổi** → cập nhật Host trong pgAdmin.
5. Seed Identity chỉ user/roles tối thiểu — không thay full data MSSQL.
6. File CSV tạm có thể để `D:\Projects\SF\Data\` (local) — **không** commit secret/password.

---

## 8. Lệnh vận hành nhanh (VPS)

```bash
cd /opt/sf/SFBE
git pull
# chỉnh .env nếu cần (POSTGRES_*), rồi:
docker compose -f docker-compose.prod.yml up -d --build
docker logs sf-api --tail 80
docker rm -f sf-postgres   # chỉ khi còn sót container cũ
```

Smoke: FE/API qua nginx HTTPS; pgAdmin xem `centimildb` → Tables; EBoard filter/search Instruments.

---

## 9. Việc còn lại (backlog)

- [x] Instruments — CSV import (~362 rows), EBoard OK
- [ ] AspNet* / Settings / Strategies / EndpointMappings (nếu cần data MSSQL)
- [ ] CryptoSignals → CryptoSignalHistories
- [ ] CryptoOrders → CryptoOrderHistories
- [ ] (Tuỳ chọn) Map Postgres `127.0.0.1:5432` trên VPS để pgAdmin Host = `127.0.0.1` ổn định hơn IP Docker
- [ ] CI/CD migrate schema nếu chưa có job riêng trên VPS
