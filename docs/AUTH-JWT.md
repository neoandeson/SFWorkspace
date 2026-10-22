# Auth / JWT — trạng thái hiện tại

**Cập nhật:** 2026-10-22  
**Access token lifetime:** **8 giờ** (`AccountController.GenerateJwtTokenAsync` → `AddHours(8)`).

## Cơ chế hiện có

| Cơ chế | Trạng thái | Ghi chú |
|--------|------------|---------|
| JWT access token (Bearer) | Có | Login / Google → JWT; FE lưu `localStorage` (redux-persist) |
| Refresh token | **Không** | Hết hạn 8h phải đăng nhập lại |
| Server-side revoke / blacklist | **Không** | Token còn hạn vẫn dùng được sau “logout” |
| `POST api/account/sign-out` | Có (yếu) | Chỉ `_signInManager.SignOutAsync()` (cookie Identity); **không** vô hiệu hóa JWT đã cấp |
| FE sign-out | Có | Xóa token local; mọi request 401 → `signOutSuccess()` |
| Rotate JWT signing key | Thủ công | Đổi `JWT:Key` trên VPS → mọi token cũ hết hiệu lực ngay |

## Rủi ro (personal app / monolith)

1. **Stolen token:** trong cửa sổ 8h, kẻ lấy được Bearer dùng được API cho đến khi hết hạn hoặc đổi signing key.
2. **Logout không revoke:** “Đăng xuất” chỉ phía client; JWT copy vẫn valid đến `exp`.
3. **Không refresh:** UX chấp nhận được với 8h; không có silent renew.

## Khuyến nghị (chưa implement — làm khi cần)

**Mức vừa (đủ cho app cá nhân / ít user):**

- Giữ access JWT ngắn hơn (vd. 1–2h) + **refresh token** httpOnly cookie hoặc opaque store DB, rotation khi refresh, revoke khi logout / đổi mật khẩu.
- Hoặc giữ 8h access như hiện tại nếu chấp nhận rủi ro stolen-token trong ngày làm việc.

**Mức chắc hơn:**

- Denylist `jti` (Redis/DB) khi logout / admin kick; validate `jti` trong JWT middleware.
- Absolute session max + idle timeout phía FE.

**Không làm ngay** trừ khi có threat model rõ: full OAuth2/OIDC server, device tracking.

## Package safety (lần kiểm 2026-10-22)

- **SFBE (NuGet):** `dotnet list package --vulnerable --include-transitive` — Web.API / Application / Infrastructure: **không có** vulnerable packages (nguồn nuget.org).
- **SFFE axios:** lockfile đang ở `axios@1.18.1` — **không** trùng bản supply-chain độc đã báo (`1.14.1` / `0.30.4`, CISA 2026-04). Giữ pin qua `package-lock.json`; tránh `npm update axios` mù.
- **SFFE `npm audit`:** ~54 findings (2 low / 30 moderate / 22 high), chủ yếu **toolchain build** (rollup/vite, source-map-js, svgo, yaml) — rủi ro runtime production thấp hơn dependency app. Chưa chạy `npm audit fix` / `--force` (có thể breaking). Làm riêng khi sẵn sàng bump Vite/tooling.

## Deploy

Sau khi đổi lifetime: rebuild/redeploy `sf-api`. Token cũ (1h) vẫn hết hạn theo `exp` đã ghi trong token; login mới nhận JWT 8h.
