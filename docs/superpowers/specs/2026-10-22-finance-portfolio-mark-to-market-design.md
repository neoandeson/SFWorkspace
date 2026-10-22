# Finance Portfolio — Mark-to-Market + History (Feature 3)

**Date:** 2026-10-22  
**Status:** Approved (user: approach A; design §§1–6 OK; implement **3 then 1**)  
**Repos:** SFBE / SFFE / workspace  
**Depends on:** Phase B Finance Accounts + Ladder Term Deposits  
**Follow-up:** Feature 1 — Ledger / journal (separate spec after this ships)  
**Terminology:** [FINANCE-TERMINOLOGY.md](../../FINANCE-TERMINOLOGY.md) — extend for USD/`đ`/`$` display rules below  
**Auth notes:** [AUTH-JWT.md](../../AUTH-JWT.md) (unrelated; JWT 8h already shipped)

## Goals

1. Portfolio **summary + history chart** from `AccountBalanceSnapshot` (forward-fill by day).
2. **Mark-to-market when user opens** Portfolio / stats view (not on every Instrument patch).
3. Link account → optional `InstrumentId`; `Balance` = **quantity** when linked.
4. Quote currency from instrument classification: **CK Việt Nam → VND**; **crypto / other → USD**.
5. Global **USD→VND rate** in `Setting` + FE CRUD (manual).
6. Money format: VND → `đ` + vi-VN grouping; USD → `$` + en-US grouping.

## Non-goals

- Ledger / double-entry journal (Feature 1)
- External price fetch / websocket / TradingView from Finance views
- Updating Finance on every `PatchInstrument`
- Replacing screener / EBoard
- Excel import

## Approach

**A — Mark-on-view + Setting `Finance.UsdVndRate` + enriched snapshots**

- Screener continues to patch `Instrument.Price` only.
- Finance read path (summary / history / explicit mark) loads linked instruments, computes values, optionally writes a snapshot if materially changed.
- No background job required for v1.

---

## 1. Data model

### 1.1 `FinanceAccount` (extend)

| Field | Change |
|-------|--------|
| `InstrumentId` | `int?` FK → `Instruments.Id`, optional |
| `Balance` | Semantics: **quantity** when `InstrumentId` set; unchanged for Cash / TermSaving without instrument (cash amount / ladder principal sum) |
| `FxRateToVnd` | Kept for accounts **without** instrument (manual); for linked accounts may be refreshed from derived VND/unit on mark for backward compatibility with existing list DTOs |
| `Currency` | Still stored; for linked accounts prefer display quote from instrument rules (USD/VND), not free-form conflict |

### 1.2 `AccountBalanceSnapshot` (extend)

Existing: `Balance`, `FxRateToVnd`, `ValueVnd`, `RecordedAt`.

Add:

| Field | Type | Notes |
|-------|------|--------|
| `UnitPrice` | decimal | `Instrument.Price` at mark (0 if N/A) |
| `QuoteCurrency` | string | `USD` or `VND` |
| `ValueNative` | decimal | `Balance × UnitPrice` (or cash balance if no instrument) |
| `ValueUsd` | decimal | Normalized USD at mark |
| `UsdVndRate` | decimal | Rate used when computing VND from USD (or 1 if quote VND-only path) |

Keep `ValueVnd` as source for VND series. Migration: nullable new cols or defaults `0` / `VND` for old rows; history API treats missing `ValueUsd` as `ValueVnd / rate` when rate known, else omit USD series point.

### 1.3 `Setting`

Reuse table. Canonical name (add to `WebConstants.SettingNames`):

- **Name:** `Finance.UsdVndRate`
- **Type:** `Finance`
- **Value:** decimal string, e.g. `25500`
- **IsActive:** true when used
- Seed or ensure-on-read if missing (default agreed in plan, e.g. `1` until user sets).

No new settings table.

### 1.4 Instrument → quote currency

Primary: `Instrument.Type` (and fallback `Section` if Type empty), case-insensitive.

| Classification | Quote | Match hints (constants; adjustable in plan) |
|----------------|-------|-----------------------------------------------|
| VN equity | **VND** | Type/Section in `ckvn`, `tcbs`, `CKVN`, `stock-vn`, … |
| Crypto / other | **USD** | `crypto`, `fx`, empty, or anything not in VN set |

Document exact string list in implementation plan after sampling prod `Instruments.Type` / `Section` distinct values. User-facing rule remains: CK VN → VND; crypto & other → USD.

---

## 2. Valuation rules (mark-to-market)

Inputs per non-archived account:

**A. Linked (`InstrumentId` present, instrument found)**

```text
unitPrice    = Instrument.Price
quote        = QuoteFrom(Instrument)   // VND | USD
valueNative  = Balance × unitPrice
valueUsd     = quote == USD ? valueNative : valueNative / UsdVndRate
valueVnd     = quote == VND ? valueNative : valueNative × UsdVndRate
```

Require `UsdVndRate > 0`. If rate missing/invalid → 400 on mark endpoints (or skip mark + toast on FE).

**B. Unlinked Cash / Other with manual FX (Phase B)**

```text
valueNative  = Balance
quote        = Currency == "VND" ? VND : USD   // pragmatic: non-VND treated as USD units for totals
valueVnd     = Balance × FxRateToVnd           // existing
valueUsd     = valueVnd / UsdVndRate
```

**C. TermSaving (ladder)**

No instrument. `Balance` = sum open principals (existing sync). Treat as **VND** (current product use) unless `Currency` ≠ VND then use Phase B FX path.

**Portfolio totals**

```text
totalUsd = Σ valueUsd
totalVnd = totalUsd × UsdVndRate
```

(Equivalent to Σ valueVnd when every line used the same rate.)

**Snapshot write (on mark)**

Compare to latest snapshot for account (or compare computed `ValueVnd` / `ValueUsd` / `UnitPrice`). If changed beyond trivial epsilon → insert snapshot with full new fields + update account `FxRateToVnd` / `UpdatedAt` when useful for list page consistency.

**Not on PatchInstrument.**

---

## 3. API

Auth: Bearer JWT; scope by `UserId`.

| Method | Path | Behavior |
|--------|------|----------|
| extend | `POST/PUT .../accounts` | Accept `instrumentId` (nullable); validate ownership of instrument exists |
| `GET` | `/api/finance/settings` | Finance settings (at least `usdVndRate`) |
| `PUT` | `/api/finance/settings/usd-vnd-rate` | Body `{ "rate": number }` — upsert `Finance.UsdVndRate` |
| `POST` | `/api/finance/portfolio/mark` | Run mark-to-market for current user; write snapshots if needed; return summary DTO |
| `GET` | `/api/finance/summary` | May call same valuation as mark **without** requiring separate POST; or FE always `POST mark` then `GET summary` — **prefer single `POST mark` that returns summary** to avoid double work |
| `GET` | `/api/finance/portfolio/history?from=&to=&grain=day` | Daily series: for each day, per account latest snapshot `RecordedAt ≤ endOfDay`, sum `ValueUsd` / `ValueVnd`; forward-fill gaps |

### Summary DTO (extend)

- `totalUsd`, `totalVnd`, `usdVndRate`
- `items[]`: account id, name, type, quantity (`balance`), `instrumentId`, `unitPrice`, `quoteCurrency`, `valueNative`, `valueUsd`, `valueVnd`
- Optional breakdown by `FinanceAccountType` and/or quote currency

### Errors

| Case | HTTP |
|------|------|
| Unauthenticated | 401 |
| Invalid rate ≤ 0 | 400 |
| Unknown instrumentId | 400 |
| Missing / other user account | 404 |

---

## 4. Frontend

### 4.1 Portfolio / thống kê view (new or extend Accounts)

On mount:

1. Load `usdVndRate` (settings).
2. `POST /api/finance/portfolio/mark` (or equivalent) → table + totals.
3. Load history → chart (ApexCharts already in Elstar).

### 4.2 Accounts form

- Optional Instrument select (search/filter by Type/Section).
- Help text: Balance = số lượng when instrument linked.
- TermSaving: keep ladder-derived balance (disabled).

### 4.3 Settings UI

- Simple Finance settings page or modal: edit USD→VND rate; list/create/update via API above (v1 may be rate-only CRUD).

### 4.4 Formatting (shared util)

| | VND | USD |
|--|-----|-----|
| Symbol | `đ` (suffix or locale `vi-VN`) | `$` prefix |
| Grouping | `vi-VN` (e.g. `1.234.567`) | `en-US` (e.g. `1,234.56`) |
| Fractions | 0 for whole đồng (or 0–2 if needed) | 2 default |

Do not mix locales on one number.

### 4.5 Nav

Finance → Portfolio (or “Thống kê”) + keep Accounts / Ladder. Remove or demote “Ledger - Google Sheets” only when Feature 1 ships (out of scope here).

---

## 5. Non-goals (reminder)

Ledger, external quotes, patch-driven Finance updates — see above.

---

## 6. Delivery order

1. **This spec** → implementation plan → ship Feature 3.  
2. **Then** brainstorm + spec Feature 1 (Ledger).

---

## Testing (acceptance)

- Linked crypto account: Price from Instruments, quote USD, totals use setting rate; format `$` / `đ`.
- Linked CKVN-style instrument: quote VND; contributes to `totalUsd` via ÷ rate.
- Open Portfolio twice with unchanged prices → no duplicate spam snapshots (or only one if first mark).
- Patch instrument price while Portfolio closed → no new Finance snapshot until next mark.
- History chart forward-fills days without snapshots.
- Rate ≤ 0 rejected; UI shows error.
- TermSaving / Cash without instrument still appear in totals.

## Open points for plan (not blocking design)

- Exact Type/Section string whitelist from prod sample.
- Default `Finance.UsdVndRate` seed value.
- Epsilon for “value changed” snapshot write.
- Whether list `GET /accounts` also marks or stays stale until Portfolio visit (recommend: list stays Phase B fields; Portfolio always marks).

## Spec self-review

| Check | Result |
|-------|--------|
| Placeholders / TBD | None in normative sections; open points deferred to plan only |
| Contradictions | Mark-on-view vs patch: consistent (no patch writes). Totals `Σ valueUsd` then `× rate` aligned with per-line `valueVnd` |
| Ambiguity | Instrument Type/Section strings explicitly “sample in plan”; Balance dual semantics (qty vs cash) documented |
| Scope | Feature 1 Ledger excluded; JWT/UI rewrite excluded |
| Consistency with Phase B | `FxRateToVnd` / TermSaving / snapshots retained and extended |
