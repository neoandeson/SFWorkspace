# Finance Accounts (Phase B) — Design

**Date:** 2026-10-22  
**Status:** Draft (awaiting user review of written spec)  
**Repos:** SFBE / SFFE / workspace  
**Approach:** A — thin Finance module (`FinanceAccount` + `AccountBalanceSnapshot`)

## Goals

1. Replace Excel “account tổng” with a personal finance account list in SF.
2. Generic accounts: free-form names (ACB, Binance, TCBS…); no hardcoded banks/exchanges.
3. Manual number entry only — no trading/broker API links.
4. Native currency + FX rate → VND; portfolio total in VND.
5. Snapshot history on every balance/rate save for viewing and later statistics.
6. Data scoped per Identity user.

## Non-goals (later specs)

- Ladder / term-deposit contracts UI and sync
- Derived `TermSaving` balance from open contracts
- Excel import
- Broker/exchange API integration
- Double-entry journal / full accounting ledger
- Household / shared workspaces

## Context

SF today has Identity auth, instruments/market, and crypto trading UI. `LedgerDBContext` is only the EF context name; `AccountController` is login — not financial accounts. Phase B adds a new Finance module without colliding with those names.

Future ladder decisions (not implemented here, but design must not block them):

- Renewal = close old contract + create new
- Mid-term: allow editing principal on Open contracts (with snapshots)
- When a `TermSaving` account has open contracts → balance derived; when none → manual

## Data model

### `FinanceAccount`

| Field | Type | Notes |
|-------|------|--------|
| `Id` | int | PK (match existing SF entities) |
| `UserId` | string | Identity user owner |
| `Name` | string | Free text, e.g. `TPBank Saving`, `BinanceEarn USDT` |
| `Type` | enum | `Cash`, `TermSaving`, `Crypto`, `Brokerage`, `Other` |
| `Currency` | string | e.g. `VND`, `USDT`, `USD` |
| `Balance` | decimal | Amount in `Currency` |
| `FxRateToVnd` | decimal | Multiply balance → VND; forced `1` when `Currency = VND` |
| `SortOrder` | int | Display order (Excel-like) |
| `IsArchived` | bool | Soft-hide from default totals |
| `CreatedAt` | DateTime | |
| `UpdatedAt` | DateTime | |

**Computed:** `ValueVnd = Balance * FxRateToVnd`  
**Portfolio total:** sum of `ValueVnd` for non-archived accounts of the current user.

### `AccountBalanceSnapshot`

| Field | Type | Notes |
|-------|------|--------|
| `Id` | int | PK |
| `FinanceAccountId` | int | FK → FinanceAccount |
| `UserId` | string | Denormalized for fast queries |
| `Balance` | decimal | Value after save |
| `FxRateToVnd` | decimal | Rate at save |
| `ValueVnd` | decimal | Precomputed |
| `RecordedAt` | DateTime | |

**When to write a snapshot**

- On account create
- On update when `Balance` or `FxRateToVnd` changes
- Name/type/sort/archive-only updates → no snapshot

## API

Base path: `api/finance/accounts`  
Auth: Bearer JWT; all queries filtered by current `UserId`.

| Method | Path | Behavior |
|--------|------|----------|
| `GET` | `/api/finance/accounts` | List accounts + `valueVnd`; include `totalVnd`. Default `IsArchived = false`; `?includeArchived=true` optional |
| `POST` | `/api/finance/accounts` | Create + first snapshot |
| `PUT`/`PATCH` | `/api/finance/accounts/{id}` | Update fields; snapshot if balance/rate changed |
| `DELETE` | `/api/finance/accounts/{id}` | Soft archive (`IsArchived = true`). Phase B: no hard delete |
| `GET` | `/api/finance/accounts/{id}/snapshots` | History, newest first, paginated |
| `GET` | `/api/finance/summary` | `totalVnd` + breakdown by `Type` |

### Update flow

1. Load account; verify ownership (else 404).
2. If `Currency = VND`, force `FxRateToVnd = 1`.
3. If `Balance` or `FxRateToVnd` changed → insert snapshot.
4. Save account; bump `UpdatedAt`.

### Errors

| Case | HTTP |
|------|------|
| Unauthenticated | 401 |
| Missing / other user’s id | 404 |
| Invalid body | 400 + field messages |
| Archive already archived | no-op success |

### Validation

- `Name`: required, max 100
- `Type`: valid enum
- `Currency`: required, short uppercase code
- `Balance`: ≥ 0
- `FxRateToVnd`: > 0 (and = 1 for VND)
- `SortOrder`: ≥ 0

## Frontend

- New nav/route under Finance (e.g. **Finance → Accounts**), separate from existing crypto Portfolio.
- Main view mirrors Excel account tổng: rows (name, type, currency, balance, rate, VND) + footer total.
- Create/edit form; history view from snapshots API.
- FE service in `SFFE/src/services/`; update `workspace/docs/API-MAP.md` when endpoints land.

## Testing (BE)

- Create → one snapshot; `valueVnd` correct
- Update name only → no new snapshot
- Update balance or rate → new snapshot; summary changes
- User A cannot read User B’s accounts
- VND accounts always persist `FxRateToVnd = 1`

## Architecture notes

- Modular monolith: handlers/repos under Finance feature area in Web.Application / Web.Infrastructure / Web.API.
- Entity names `FinanceAccount` / `AccountBalanceSnapshot` avoid clash with Identity `Account`.
- Extension point: later `TermDeposit.FinanceAccountId` for ladder (separate spec).

## Success criteria

- Logged-in user can CRUD (archive) their accounts and see VND total.
- Changing balance/rate produces history rows usable for later charts/stats.
- Adding a new bank/exchange is just creating an account with a free name — no code change.
