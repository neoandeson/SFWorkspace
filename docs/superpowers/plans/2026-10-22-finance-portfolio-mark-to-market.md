# Finance Portfolio Mark-to-Market + History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Portfolio mark-to-market (Instruments price on view enter), USD↔VND setting, enriched snapshots, and history chart — before Ledger.

**Architecture:** Pure `PortfolioValuator` + MediatR `MarkPortfolio` / `GetPortfolioHistory` / finance settings commands. `FinanceAccount.InstrumentId` optional; snapshots gain quote fields. FE Portfolio page calls `POST mark` on mount, then history; Accounts form picks instrument via existing `POST /api/instrument/search`. No changes to `PatchInstrument`.

**Tech Stack:** .NET 10, EF/Postgres, MediatR, FluentValidation, xUnit/Moq/FluentAssertions; React 18 / Vite / Elstar UI + ApexCharts; Axios `ApiService`.

**Spec:** `workspace/docs/superpowers/specs/2026-10-22-finance-portfolio-mark-to-market-design.md`  
**Terminology:** `workspace/docs/FINANCE-TERMINOLOGY.md`

## Global Constraints

- Mark-to-market **only** on `POST /api/finance/portfolio/mark` (Portfolio mount) — never inside `PatchInstrument`.
- `Balance` = **quantity** when `InstrumentId` set; Cash/TermSaving without instrument keep Phase B / ladder semantics.
- Quote: VN equity tags → `VND`; everything else → `USD` (see `InstrumentQuoteRules` below).
- `Finance.UsdVndRate` setting; rate must be `> 0` or mark/settings update → 400.
- Snapshot write epsilon: change in `UnitPrice`, `ValueUsd`, or `ValueVnd` by **≥ 0.01**.
- `GET /api/finance/accounts` does **not** mark (stale FX OK until Portfolio visit).
- Default seed rate: **25000** if setting missing (user can edit).
- Money UI: VND `đ` + `vi-VN`; USD `$` + `en-US`.
- No Ledger in this plan. Backend-first → Swagger → FE → `API-MAP.md`.
- Repos: SFBE `D:\Projects\SF\SFBE`, SFFE `D:\Projects\SF\SFFE`, docs `D:\Projects\SF\workspace`.
- Route-sourced ids: do not FluentValidate `Id` before controller assigns (existing finance fix).

### Locked open points

| Topic | Decision |
|-------|----------|
| VN quote tags | Case-insensitive match on `Type`, else `Section`, against: `ckvn`, `tcbs`, `ckvn`, `stock-vn`, `stock_vn` |
| Default rate | `25000` |
| Epsilon | `0.01m` |
| List accounts | No auto-mark |

---

## File structure (locked in)

### SFBE — create

| Path | Responsibility |
|------|----------------|
| `src/Web.Domain/Services/InstrumentQuoteRules.cs` | Type/Section → `USD`/`VND` |
| `src/Web.Domain/Services/PortfolioValuator.cs` | Pure valuation math |
| `src/Web.Application/FinancePortfolio/Dtos/*.cs` | Mark + history DTOs |
| `src/Web.Application/FinancePortfolio/Commands/MarkPortfolio/*` | Mark + snapshots |
| `src/Web.Application/FinancePortfolio/Queries/GetPortfolioHistory/*` | Daily series |
| `src/Web.Application/FinanceSettings/Commands/UpsertUsdVndRate/*` | Setting write |
| `src/Web.Application/FinanceSettings/Queries/GetFinanceSettings/*` | Setting read |
| `src/Web.API/Controllers/FinancePortfolioController.cs` | mark + history routes |
| `src/Web.API/Controllers/FinanceSettingsController.cs` | settings routes |
| `tests/Web.Application.Tests/FinancePortfolio/*` | Valuator + handlers |
| `tests/Web.Domain.Tests/…` **or** keep valuator tests under Application.Tests | Prefer `Web.Application.Tests/FinancePortfolio/PortfolioValuatorTests.cs` calling Domain statics |

### SFBE — modify

| Path | Change |
|------|--------|
| `Web.Domain/Entities/FinanceAccount.cs` | `InstrumentId` |
| `Web.Domain/Entities/AccountBalanceSnapshot.cs` | mark fields |
| `Web.Domain/Repositories/IFinanceAccountRepository.cs` | latest snapshots batch; list snapshots in range |
| `Web.Infrastructure/Repositories/FinanceAccountRepository.cs` | implement |
| `Web.Infrastructure/Persistence/LedgerDBContext.cs` | FK Instrument optional |
| `Web.Application/Common/WebConstants.cs` | `Finance.UsdVndRate` |
| `Web.Infrastructure/Seeders/DatabaseSeeder.cs` | ensure setting |
| Create/Update finance account commands + validators + handlers | `InstrumentId` |
| Finance account DTOs | expose `instrumentId` |
| Migrations | `AddFinancePortfolioMarkToMarket` |

### SFFE — create / modify

| Path | Responsibility |
|------|----------------|
| `src/utils/financeMoney.ts` | `formatVnd` / `formatUsd` |
| `src/views/finance/Portfolio/*` | Mark + chart + totals |
| `src/views/finance/Settings/*` or modal on Portfolio | USD rate editor |
| `src/services/FinanceService.ts` | new APIs |
| `Accounts.tsx` | instrument select |
| routes + navigation | Portfolio (+ optional Settings under Finance) |

### workspace

| Path | Change |
|------|--------|
| `docs/API-MAP.md` | new endpoints |
| `docs/FINANCE-TERMINOLOGY.md` | quantity, USD/VND display |

---

### Task 1: Domain valuation + quote rules (TDD)

**Files:**
- Create: `SFBE/src/Web.Domain/Services/InstrumentQuoteRules.cs`
- Create: `SFBE/src/Web.Domain/Services/PortfolioValuator.cs`
- Create: `SFBE/tests/Web.Application.Tests/FinancePortfolio/PortfolioValuatorTests.cs`

**Interfaces:**
- Produces: `InstrumentQuoteRules.ResolveQuote(string? type, string? section) → "USD"|"VND"`
- Produces: `PortfolioValuator.EvaluateLinked(decimal qty, decimal unitPrice, string quote, decimal usdVndRate) → (valueNative, valueUsd, valueVnd)`
- Produces: `PortfolioValuator.EvaluateUnlinked(decimal balance, string currency, decimal fxRateToVnd, decimal usdVndRate) → …`
- Produces: `PortfolioValuator.ChangedEnough(prev, next) → bool` with epsilon `0.01m`

- [ ] **Step 1: Write failing tests**

```csharp
public class PortfolioValuatorTests
{
    [Theory]
    [InlineData("ckvn", null, "VND")]
    [InlineData("Crypto", "crypto", "USD")]
    [InlineData(null, "tcbs", "VND")]
    [InlineData(null, null, "USD")]
    public void ResolveQuote_MapsTypeOrSection(string? type, string? section, string expected)
        => InstrumentQuoteRules.ResolveQuote(type, section).Should().Be(expected);

    [Fact]
    public void EvaluateLinked_Usd_MultipliesToVnd()
    {
        var r = PortfolioValuator.EvaluateLinked(2m, 100m, "USD", 25000m);
        r.ValueNative.Should().Be(200m);
        r.ValueUsd.Should().Be(200m);
        r.ValueVnd.Should().Be(5_000_000m);
    }

    [Fact]
    public void EvaluateLinked_Vnd_DividesToUsd()
    {
        var r = PortfolioValuator.EvaluateLinked(10m, 15000m, "VND", 25000m);
        r.ValueNative.Should().Be(150_000m);
        r.ValueUsd.Should().Be(6m);
        r.ValueVnd.Should().Be(150_000m);
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL** (types missing)

```bash
dotnet test D:/Projects/SF/SFBE/tests/Web.Application.Tests/Web.Application.Tests.csproj --filter FullyQualifiedName~PortfolioValuatorTests
```

- [ ] **Step 3: Implement domain helpers**

```csharp
// InstrumentQuoteRules.cs
public static class InstrumentQuoteRules
{
    private static readonly HashSet<string> VndTags = new(StringComparer.OrdinalIgnoreCase)
    { "ckvn", "tcbs", "stock-vn", "stock_vn" };

    public static string ResolveQuote(string? type, string? section)
    {
        if (!string.IsNullOrWhiteSpace(type) && VndTags.Contains(type.Trim())) return "VND";
        if (!string.IsNullOrWhiteSpace(section) && VndTags.Contains(section.Trim())) return "VND";
        return "USD";
    }
}

// PortfolioValuator.cs — EvaluateLinked / EvaluateUnlinked / ChangedEnough as in Interfaces
```

Throw `ArgumentOutOfRangeException` if `usdVndRate <= 0`.

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git -C D:/Projects/SF/SFBE add src/Web.Domain/Services tests/Web.Application.Tests/FinancePortfolio
git -C D:/Projects/SF/SFBE commit -m "feat(finance): add portfolio valuator and instrument quote rules"
```

---

### Task 2: Entities, migration, repository

**Files:**
- Modify: `FinanceAccount.cs`, `AccountBalanceSnapshot.cs`, `IFinanceAccountRepository.cs`, `FinanceAccountRepository.cs`, `LedgerDBContext.cs`
- Create: EF migration `AddFinancePortfolioMarkToMarket`
- Modify: `WebConstants.cs`, `DatabaseSeeder.cs` (or ensure-on-read in GetFinanceSettings)

**Interfaces:**
- `FinanceAccount.InstrumentId` (`int?`)
- Snapshot: `UnitPrice`, `QuoteCurrency` (max 3), `ValueNative`, `ValueUsd`, `UsdVndRate` (defaults: 0, `"VND"`, 0, 0, 0)
- `Task<IReadOnlyDictionary<int, AccountBalanceSnapshot>> GetLatestSnapshotsForUserAsync(string userId, CancellationToken ct)`
- `Task<IReadOnlyList<AccountBalanceSnapshot>> ListSnapshotsForUserBetweenAsync(string userId, DateTime fromUtc, DateTime toUtc, CancellationToken ct)`

- [ ] **Step 1: Extend entities + DbContext FK** (`InstrumentId` optional, no cascade delete required — `OnDelete(SetNull)` or Restrict)

- [ ] **Step 2: Add migration and update repository methods**

```bash
dotnet ef migrations add AddFinancePortfolioMarkToMarket --project D:/Projects/SF/SFBE/src/Web.Infrastructure --startup-project D:/Projects/SF/SFBE/src/Web.API
```

- [ ] **Step 3: Seed / constants**

```csharp
public const string FinanceUsdVndRate = "Finance.UsdVndRate";
// Seeder: if missing, insert Value="25000", Type="Finance", IsActive=true
```

- [ ] **Step 4: Commit**

```bash
git -C D:/Projects/SF/SFBE commit -am "feat(finance): InstrumentId and enriched balance snapshots"
```

---

### Task 3: Finance settings API (TDD)

**Files:**
- Create: `GetFinanceSettingsQuery` → `FinanceSettingsDto { decimal UsdVndRate }`
- Create: `UpsertUsdVndRateCommand { decimal Rate }` + validator `Rate > 0`
- Create: `FinanceSettingsController` under `api/finance/settings`
- Test: `UpsertUsdVndRateCommandHandlerTests`, `GetFinanceSettingsQueryHandlerTests`

**Interfaces:**
- `GET api/finance/settings` → `{ usdVndRate }`
- `PUT api/finance/settings/usd-vnd-rate` body `{ rate }` → 204
- Uses `ISettingRepository.GetByNameAsync` / `CreateAsync` / `UpdateAsync`

- [ ] **Step 1: Failing handler tests** (mock `ISettingRepository`)

- [ ] **Step 2: Implement handlers + controller + validator**

- [ ] **Step 3: `dotnet test` filter `FullyQualifiedName~FinanceSettings` — PASS**

- [ ] **Step 4: Commit**

```bash
git -C D:/Projects/SF/SFBE commit -am "feat(finance): USD/VND rate settings API"
```

---

### Task 4: MarkPortfolio command (TDD)

**Files:**
- Create: `MarkPortfolioCommand : IRequest<PortfolioMarkDto>`
- Create: handler, DTOs (`PortfolioMarkDto`, `PortfolioPositionDto`)
- Test: `MarkPortfolioCommandHandlerTests`
- Modify: `IInstrumentRepository` usage — `GetByIdAsync`; if missing instrument treat as unlinked or skip price (prefer **BadRequest** if `InstrumentId` set but instrument missing)

**Interfaces:**
- Consumes: `IFinanceAccountRepository.ListForUserAsync(user, includeArchived:false)`, `GetLatestSnapshotsForUserAsync`, `UpdateAsync(account, snapshot?)`, `ISettingRepository`, `IInstrumentRepository`, `IUserContext`, `PortfolioValuator`
- Produces: `PortfolioMarkDto` with `totalUsd`, `totalVnd`, `usdVndRate`, `items[]`

Handler outline:

1. Load user + rate (missing → treat as 25000 **or** upsert seed; invalid ≤0 → `BadRequestException`).
2. List non-archived accounts.
3. For each: resolve valuation (linked vs unlinked vs TermSaving-as-VND cash path).
4. If `ChangedEnough` vs latest snapshot → build snapshot + set `account.FxRateToVnd` for linked to `valueVnd/Balance` when Balance≠0 else keep; `UpdateAsync`.
5. Return aggregated DTO.

- [ ] **Step 1: Write tests** — linked USD, unlinked VND cash, no snapshot when unchanged, rate ≤0 throws

- [ ] **Step 2: Implement handler**

- [ ] **Step 3: Tests PASS**

- [ ] **Step 4: Commit**

```bash
git -C D:/Projects/SF/SFBE commit -am "feat(finance): mark portfolio to market on demand"
```

---

### Task 5: Portfolio history query (TDD)

**Files:**
- Create: `GetPortfolioHistoryQuery(DateOnly From, DateOnly To)` → `PortfolioHistoryDto { IReadOnlyList<PortfolioHistoryPointDto> Points }`
- Point: `Date`, `TotalUsd`, `TotalVnd`
- Test: `GetPortfolioHistoryQueryHandlerTests` with in-memory snapshot list (mock repo)

**Logic:**

1. Validate `From <= To` and range ≤ 366 days (400 if not).
2. Load all user snapshots with `RecordedAt` in `[fromUtc, toUtc+1day)` **plus** latest snapshot before `from` per account (for forward-fill start).
3. For each calendar day D in range (UTC date): for each account take newest snapshot with `RecordedAt.Date <= D`; sum `ValueUsd`/`ValueVnd` (legacy rows: `ValueUsd = ValueVnd/rate` if `ValueUsd==0` && rate>0).
4. Return ascending points.

- [ ] **Step 1–4:** TDD + commit

```bash
git -C D:/Projects/SF/SFBE commit -am "feat(finance): portfolio history with forward-fill"
```

---

### Task 6: InstrumentId on create/update account

**Files:**
- Modify: `CreateFinanceAccountCommand`, `UpdateFinanceAccountCommand`, handlers, validators, list DTOs
- Validate: if `InstrumentId` has value, `IInstrumentRepository.GetByIdAsync` must succeed else `BadRequestException`
- TermSaving: allow null instrument only (validator: if Type==TermSaving && InstrumentId!=null → 400) **or** allow but ignore — **prefer 400**

- [ ] **Step 1:** Extend tests in `CreateFinanceAccountCommandHandlerTests` / `UpdateFinanceAccountCommandHandlerTests`

- [ ] **Step 2:** Implement

- [ ] **Step 3:** Commit

```bash
git -C D:/Projects/SF/SFBE commit -am "feat(finance): optional InstrumentId on accounts"
```

---

### Task 7: API controllers + wire-up

**Files:**
- Create: `FinancePortfolioController` — `[Authorize] [Route("api/finance")]`
  - `POST portfolio/mark` → `MarkPortfolioCommand`
  - `GET portfolio/history?from=&to=` → `GetPortfolioHistoryQuery`
- Create: `FinanceSettingsController` — routes as Task 3
- Confirm DI: validators auto-registered

- [ ] **Step 1: Add controller actions** (no FluentValidation on empty mark command body)

- [ ] **Step 2: Manual smoke via `dotnet run` + Swagger** (local): settings PUT → mark → history

- [ ] **Step 3: Commit**

```bash
git -C D:/Projects/SF/SFBE commit -am "feat(finance): expose portfolio mark, history, settings HTTP API"
```

---

### Task 8: FE money helpers + FinanceService

**Files:**
- Create: `SFFE/src/utils/financeMoney.ts`
- Modify: `SFFE/src/services/FinanceService.ts`

```typescript
export function formatVnd(value: number): string {
  return `${Number(value || 0).toLocaleString('vi-VN', { maximumFractionDigits: 0 })} đ`
}
export function formatUsd(value: number): string {
  return `$${Number(value || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}
```

API helpers: `apiGetFinanceSettings`, `apiPutUsdVndRate`, `apiMarkPortfolio`, `apiGetPortfolioHistory`, extend account payloads with `instrumentId`.

- [ ] **Step 1: Implement utils + service methods**

- [ ] **Step 2: Commit SFFE**

```bash
git -C D:/Projects/SF/SFFE commit -am "feat(finance): portfolio API client and money formatters"
```

---

### Task 9: Portfolio page + settings + nav

**Files:**
- Create: `SFFE/src/views/finance/Portfolio/Portfolio.tsx` (+ `index.ts`)
- On mount: `apiMarkPortfolio()` → table; `apiGetPortfolioHistory(from, to)` default last 90 days → ApexCharts line (`totalVnd` primary, optional `totalUsd`)
- Rate editor: Input + Save → `apiPutUsdVndRate` → re-mark
- Modify: `routes.config.ts`, `navigation.config/index.ts` — item **Portfolio** / **Thống kê**
- Reuse Chart patterns from existing crypto dashboard if present; else minimal `ReactApexChart` type `line`

- [ ] **Step 1: Build Portfolio UI**

- [ ] **Step 2: `npm run build` in SFFE — expect success**

- [ ] **Step 3: Commit**

```bash
git -C D:/Projects/SF/SFFE commit -am "feat(finance): Portfolio mark-to-market view and USD rate editor"
```

---

### Task 10: Accounts form — instrument picker

**Files:**
- Modify: `Accounts.tsx`
- Use `apiGetMarketData` / CryptoService search (`POST /api/instrument/search`) to populate Select options `{ value: id, label: symbol + name }`
- When instrument selected: show hint “Balance = số lượng”; still send `balance` as quantity
- Include `instrumentId` in create/update payload (null to clear)

- [ ] **Step 1: Wire select + payload**

- [ ] **Step 2: Commit**

```bash
git -C D:/Projects/SF/SFFE commit -am "feat(finance): link accounts to Instruments"
```

---

### Task 11: Docs

**Files:**
- `workspace/docs/API-MAP.md` — settings, mark, history, `instrumentId` on accounts
- `workspace/docs/FINANCE-TERMINOLOGY.md` — Quantity, UnitPrice, TotalUsd, TotalVnd, format rules

- [ ] **Step 1: Update docs**

- [ ] **Step 2: Commit workspace**

```bash
git -C D:/Projects/SF/workspace commit -am "docs: map portfolio mark-to-market API and terminology"
```

---

### Task 12: Verify acceptance

- [ ] **Step 1: Run BE tests**

```bash
dotnet test D:/Projects/SF/SFBE/tests/Web.Application.Tests/Web.Application.Tests.csproj --filter FullyQualifiedName~Finance
```

Expected: all Pass.

- [ ] **Step 2: Checklist vs spec**

- Linked crypto → USD formatting + `totalVnd = totalUsd × rate`
- CKVN tag → VND quote
- Second mark unchanged → no new snapshot (epsilon)
- History forward-fill
- Rate ≤ 0 → 400
- TermSaving still in totals without instrument

- [ ] **Step 3: Final commit only if drift fixes needed**

---

## Plan self-review

| Spec item | Task |
|-----------|------|
| InstrumentId + quantity | 2, 6, 10 |
| Quote CK VN / crypto | 1 |
| UsdVndRate Setting + CRUD UI | 3, 9 |
| Mark on view not patch | 4, 7, 9 |
| Enriched snapshots | 2, 4 |
| History forward-fill | 5, 9 |
| Format đ / $ | 8, 9 |
| API-MAP / terminology | 11 |
| No Ledger | excluded |

**Placeholder scan:** none intentional.  
**Type consistency:** `PortfolioMarkDto` / `PortfolioHistoryDto` names reused FE/BE camelCase JSON.
