# Finance Ladder / Term Deposits — Design

**Date:** 2026-10-22  
**Status:** Approved  
**Repos:** SFBE / SFFE / workspace  
**Depends on:** Phase B Finance Accounts (`2026-10-22-finance-accounts-phase-b-design.md`)  
**Approach:** A — `TermDeposit` entity linked to `FinanceAccount` (`TermSaving`), with balance sync  
**Terminology:** [FINANCE-TERMINOLOGY.md](../../FINANCE-TERMINOLOGY.md) — use **Tổng lãi** / `TotalInterest`, never Excel “Margin”

## Goals

1. Replace Excel ladder sheets (per bank) with generic term-deposit contracts under any `TermSaving` account.
2. Compute expected interest with simple interest by term length.
3. Sync parent account `Balance` = sum of **Open** principals.
4. Support mid-term principal edit, close, and renew (close old + create new).
5. UI: ladder per account + Finance → Ladder (cross-account).
6. Overdue: UI badge only; status stays `Open` until user closes/renews.

## Non-goals

- Auto status `Matured` on past maturity date
- Excel import
- Compound interest or manual override of computed interest
- Deep multi-year analytics charts (Closed list is enough for now)
- Crypto / brokerage ladders

## Formulas

```text
ExpectedInterest = Principal × (AnnualRatePercent / 100) × (TermMonths / 12)
MaturityAmount   = Principal + ExpectedInterest
MaturityDate     = StartDate + TermMonths   (calendar months; server-owned)
YieldPercent     = TotalInterest / TotalPrincipal × 100   (0 if TotalPrincipal = 0)
```

Totals on a ladder view (default: Open only):

| API field | UI (VI) |
|-----------|---------|
| `TotalPrincipal` | Tổng gốc |
| `TotalExpectedInterest` | Tổng lãi (dự tính) |
| `TotalMaturityAmount` | Tổng đáo hạn |
| `YieldPercent` | Tỷ suất lãi (%) |

## Data model

### `TermDepositStatus`

`Open = 0`, `Closed = 1`

### `TermDeposit`

| Field | Type | Notes |
|-------|------|--------|
| `Id` | int | PK |
| `UserId` | string | Identity owner |
| `FinanceAccountId` | int | FK → `FinanceAccount` |
| `Principal` | decimal | Gốc |
| `AnnualRatePercent` | decimal | % / year |
| `TermMonths` | int | 1…120 |
| `StartDate` | DateOnly | Ngày gửi |
| `MaturityDate` | DateOnly | Derived from start + term |
| `ExpectedInterest` | decimal | Stored, recomputed on change |
| `MaturityAmount` | decimal | Stored, recomputed on change |
| `Status` | enum | `Open` / `Closed` |
| `ClosedAt` | DateTime? | Set on close/renew |
| `Notes` | string? | Optional, max 500 |
| `CreatedAt` / `UpdatedAt` | DateTime | UTC |

### Parent sync (`FinanceAccount`)

When `Type == TermSaving`:

1. `Balance = Σ Principal` for deposits with `Status == Open` on that account (same `UserId`).
2. If `Balance` changed → write `AccountBalanceSnapshot` (Phase B rules).
3. Client updates to `Balance` on `TermSaving` accounts are rejected (**400**). Balance is always derived (new TermSaving starts at 0 until first Open deposit).

## Lifecycle

| Action | Behavior |
|--------|----------|
| Create | `Open`; compute fields; sync parent |
| Update | Only if `Open`; recompute; sync |
| Close | `Closed` + `ClosedAt`; sync |
| Renew | Close current + create new `Open` from body; sync once at end |
| Mid-term principal change | Allowed on `Open` via Update |

Overdue: `Status` remains `Open` if `MaturityDate < today`; FE shows **Quá hạn** badge.

## API

Auth: Bearer JWT; all scoped to current user.

| Method | Path | Behavior |
|--------|------|----------|
| `GET` | `/api/finance/accounts/{accountId}/deposits` | List; `?status=Open\|Closed\|All` (default `Open`) |
| `POST` | `/api/finance/accounts/{accountId}/deposits` | Create Open |
| `PUT` | `/api/finance/deposits/{id}` | Update Open |
| `POST` | `/api/finance/deposits/{id}/close` | Close |
| `POST` | `/api/finance/deposits/{id}/renew` | Body = new deposit fields; close + create |
| `GET` | `/api/finance/deposits` | Cross-account list; `?accountId=&status=` |
| `GET` | `/api/finance/accounts/{accountId}/deposits/summary` | Totals (Open by default; `?status=` optional) |

### Errors

| Case | HTTP |
|------|------|
| Unauthenticated | 401 |
| Missing / other user’s id | 404 |
| Account not `TermSaving` | 400 |
| Edit/close/renew on `Closed` | 400 |
| Invalid body | 400 |
| Balance patch on `TermSaving` | 400 |

### Validation

- Account exists, owned, `Type == TermSaving`
- `Principal ≥ 0`
- `AnnualRatePercent > 0`
- `TermMonths` in 1…120
- `StartDate` required
- `Notes` max 500

## Frontend

- Accounts (`TermSaving`): action **Ladder** → `/app/finance/accounts/:accountId/ladder`
- Nav **Finance → Ladder** → `/app/finance/ladder` (account filter)
- Table columns: Gốc, Lãi suất, Lãi dự tính, Kỳ hạn, Ngày gửi, Đáo hạn, Số dư đáo hạn, Status (+ Quá hạn)
- Footer: Tổng gốc / Tổng lãi / Tổng đáo hạn / Tỷ suất lãi
- Dialogs: Add, Edit, Close confirm, Renew
- Service: `SFFE/src/services/FinanceService.ts` (extend) or `TermDepositService.ts`
- Update `workspace/docs/API-MAP.md`

## Testing (BE)

- Two Open deposits → account `Balance` = sum of principals + snapshot
- Close one → balance decreases
- Renew → one Closed + one Open; balance = new principal
- Formula A matches expected decimals
- Other user’s account/deposit → 404
- Create on `Cash` account → 400
- Update `TermSaving` balance via accounts API → 400

## Architecture notes

- Feature area: `Web.Application/TermDeposits` (or `FinanceAccounts/TermDeposits`), repos in Infrastructure, `TermDepositsController` or extend finance controllers.
- Keep Identity `Account` naming collision free.
- Extension: later Closed history analytics without changing Open sync rules.

## Success criteria

- User can manage ladders for any named TermSaving bank account.
- Account tổng TermSaving balance stays consistent with Open principals.
- Terminology matches FINANCE-TERMINOLOGY (no Margin labels).
