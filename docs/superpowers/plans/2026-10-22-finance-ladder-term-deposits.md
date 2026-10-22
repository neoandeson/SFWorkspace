# Finance Ladder / Term Deposits Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship term-deposit ladders under `TermSaving` accounts with interest formula A, parent balance sync (sum Open principals), close/renew, and FE ladder pages.

**Architecture:** New `TermDeposit` aggregate + `ITermDepositRepository`; MediatR commands/queries sync parent `FinanceAccount.Balance` via existing `IFinanceAccountRepository.UpdateAsync` + snapshot. REST under `api/finance/...`. FE extends Finance nav/routes and Accounts actions.

**Tech Stack:** Same as Phase B — .NET 10, EF/Postgres, MediatR, FluentValidation, xUnit/Moq; React/Vite SFFE + `ApiService`.

**Spec:** `workspace/docs/superpowers/specs/2026-10-22-finance-ladder-term-deposits-design.md`  
**Terminology:** `workspace/docs/FINANCE-TERMINOLOGY.md`

## Global Constraints

- Entity `TermDeposit`; status `Open` / `Closed` only (no auto Matured).
- Link only to `FinanceAccount` with `Type == TermSaving`.
- `ExpectedInterest = Principal × (AnnualRatePercent/100) × (TermMonths/12)`.
- `MaturityAmount = Principal + ExpectedInterest`; `MaturityDate = StartDate.AddMonths(TermMonths)`.
- Parent `Balance = Σ Principal` of **Open** deposits; always derived for TermSaving; reject client balance updates with **400**.
- Sync writes `AccountBalanceSnapshot` when Balance changes (Phase B).
- Renew = close old + create new Open.
- Mid-term edit allowed on Open only.
- UI/API names: Gốc/Principal, Tổng lãi/`TotalExpectedInterest`, Tỷ suất lãi/`YieldPercent` — **never Margin**.
- Per Identity user; wrong owner → 404.
- Backend-first; update `API-MAP.md`.
- Repos: SFBE / SFFE / workspace as before.

---

## File structure

### SFBE — create

| Path | Responsibility |
|------|----------------|
| `src/Web.Domain/Enums/TermDepositStatus.cs` | Open/Closed |
| `src/Web.Domain/Entities/TermDeposit.cs` | Contract entity |
| `src/Web.Domain/Exceptions/BadRequestException.cs` | Maps to HTTP 400 |
| `src/Web.Domain/Repositories/ITermDepositRepository.cs` | Persistence |
| `src/Web.Domain/Services/TermDepositCalculator.cs` | Pure formula helpers (static) |
| `src/Web.Infrastructure/Repositories/TermDepositRepository.cs` | EF |
| `src/Web.Application/TermDeposits/Dtos/*.cs` | DTOs + summary |
| `src/Web.Application/TermDeposits/Commands/**` | Create/Update/Close/Renew |
| `src/Web.Application/TermDeposits/Queries/**` | List by account, list all, summary |
| `src/Web.Application/TermDeposits/TermDepositSync.cs` | Shared sync helper |
| `src/Web.API/Controllers/TermDepositsController.cs` | REST |

### SFBE — modify

| Path | Change |
|------|--------|
| `LedgerDBContext.cs` | DbSet + FK config |
| `ServiceCollectionExtensions.cs` (Infrastructure) | Register repo |
| `ErrorHandlingMiddleware.cs` | Catch `BadRequestException` → 400 |
| `UpdateFinanceAccountCommandHandler.cs` | Reject Balance/Fx changes when Type is TermSaving (or Type becoming TermSaving with balance push) — reject **Balance** change when account.Type is TermSaving |
| Migrations | `AddTermDeposits` |

### SFFE — create/modify

| Path | Change |
|------|--------|
| `src/services/FinanceService.ts` | Deposit API methods + types |
| `src/views/finance/Ladder/Ladder.tsx` | Shared ladder table UI |
| `src/views/finance/Ladder/index.ts` | Barrel |
| `routes.config.ts` | `/finance/ladder`, `/finance/accounts/:accountId/ladder` |
| `navigation.config/index.ts` | Finance → Ladder |
| `views/finance/Accounts/Accounts.tsx` | Ladder button for TermSaving; disable balance edit when type TermSaving |

### workspace

| Path | Change |
|------|--------|
| `docs/API-MAP.md` | Term deposit endpoints |
| Spec status | Approved |

---

### Task 1: Domain — entity, status, calculator, BadRequestException

**Files:**
- Create: `SFBE/src/Web.Domain/Enums/TermDepositStatus.cs`
- Create: `SFBE/src/Web.Domain/Entities/TermDeposit.cs`
- Create: `SFBE/src/Web.Domain/Exceptions/BadRequestException.cs`
- Create: `SFBE/src/Web.Domain/Services/TermDepositCalculator.cs`
- Create: `SFBE/src/Web.Domain/Repositories/ITermDepositRepository.cs`
- Test: `SFBE/tests/Web.Domain.Tests/TermDepositCalculatorTests.cs` (create project if missing — prefer put tests in `Web.Application.Tests` as `TermDeposits/TermDepositCalculatorTests.cs` calling Domain static helper to avoid new csproj)

**Interfaces:**
- Produces: `TermDepositCalculator.Compute(principal, annualRatePercent, termMonths, startDate) → (expectedInterest, maturityAmount, maturityDate)`
- Produces: `ITermDepositRepository` signatures below

```csharp
public enum TermDepositStatus { Open = 0, Closed = 1 }

public class TermDeposit
{
    public int Id { get; set; }
    public string UserId { get; set; } = default!;
    public int FinanceAccountId { get; set; }
    public FinanceAccount? FinanceAccount { get; set; }
    public decimal Principal { get; set; }
    public decimal AnnualRatePercent { get; set; }
    public int TermMonths { get; set; }
    public DateOnly StartDate { get; set; }
    public DateOnly MaturityDate { get; set; }
    public decimal ExpectedInterest { get; set; }
    public decimal MaturityAmount { get; set; }
    public TermDepositStatus Status { get; set; }
    public DateTime? ClosedAt { get; set; }
    public string? Notes { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class BadRequestException(string message) : Exception(message);

public static class TermDepositCalculator
{
    public static (decimal ExpectedInterest, decimal MaturityAmount, DateOnly MaturityDate) Compute(
        decimal principal, decimal annualRatePercent, int termMonths, DateOnly startDate)
    {
        var interest = principal * (annualRatePercent / 100m) * (termMonths / 12m);
        // Round money to 2 decimal places for VND-friendly display consistency
        interest = Math.Round(interest, 2, MidpointRounding.AwayFromZero);
        var maturity = principal + interest;
        var maturityDate = startDate.AddMonths(termMonths);
        return (interest, maturity, maturityDate);
    }
}

public interface ITermDepositRepository
{
    Task<TermDeposit?> GetByIdForUserAsync(int id, string userId, CancellationToken ct = default);
    Task<IReadOnlyList<TermDeposit>> ListForAccountAsync(int accountId, string userId, TermDepositStatus? statusFilter, CancellationToken ct = default);
    Task<IReadOnlyList<TermDeposit>> ListForUserAsync(string userId, int? accountId, TermDepositStatus? statusFilter, CancellationToken ct = default);
    Task<decimal> SumOpenPrincipalAsync(int accountId, string userId, CancellationToken ct = default);
    Task<int> CreateAsync(TermDeposit deposit, CancellationToken ct = default);
    Task UpdateAsync(TermDeposit deposit, CancellationToken ct = default);
}
```

- [ ] **Step 1: Write failing calculator tests**

```csharp
[Fact]
public void Compute_12Months_MatchesSimpleInterest()
{
    var (interest, maturity, date) = TermDepositCalculator.Compute(50_000_000m, 5.7m, 12, new DateOnly(2025, 12, 10));
    interest.Should().Be(2_850_000m);
    maturity.Should().Be(52_850_000m);
    date.Should().Be(new DateOnly(2026, 12, 10));
}

[Fact]
public void Compute_9Months_IsProRata()
{
    var (interest, _, date) = TermDepositCalculator.Compute(100_000_000m, 8m, 9, new DateOnly(2026, 1, 1));
    interest.Should().Be(6_000_000m); // 100M * 0.08 * 0.75
    date.Should().Be(new DateOnly(2026, 10, 1));
}
```

- [ ] **Step 2: Run → RED**

`dotnet test ... --filter FullyQualifiedName~TermDepositCalculatorTests`

- [ ] **Step 3: Implement domain files**

- [ ] **Step 4: Run → GREEN**

- [ ] **Step 5: Commit (SFBE)**

```bash
git -C D:/Projects/SF/SFBE commit -m "feat(finance): add TermDeposit domain and interest calculator"
```

---

### Task 2: EF + repository + BadRequest middleware

**Files:**
- Modify: `LedgerDBContext.cs`, `ServiceCollectionExtensions.cs`, `ErrorHandlingMiddleware.cs`
- Create: `TermDepositRepository.cs`, migration `AddTermDeposits`

**Interfaces:**
- Consumes: `ITermDepositRepository`, entity from Task 1
- Middleware: `catch (BadRequestException ex) { StatusCode = 400; WriteAsync(ex.Message); }`

- [ ] **Step 1: DbSet + fluent config**

Precision: Principal/Interest/MaturityAmount `18,2`; AnnualRatePercent `9,4`. Index `(FinanceAccountId, Status)`, `(UserId, Status)`. FK cascade from account optional — prefer **Restrict** delete (accounts are archived, not hard-deleted).

- [ ] **Step 2: Implement repository** (`SumOpenPrincipalAsync` = sum Principal where Open)

- [ ] **Step 3: DI + middleware 400**

- [ ] **Step 4: `dotnet ef migrations add AddTermDeposits` + `database update` locally**

- [ ] **Step 5: Commit**

```bash
git -C D:/Projects/SF/SFBE commit -m "feat(finance): persist TermDeposits and map BadRequest to 400"
```

---

### Task 3: Sync helper + reject TermSaving balance updates (TDD)

**Files:**
- Create: `Web.Application/TermDeposits/TermDepositBalanceSync.cs`
- Modify: `UpdateFinanceAccountCommandHandler.cs`
- Test: `UpdateFinanceAccountCommandHandlerTests` (add case) + sync unit test optional

**Interfaces:**
```csharp
public static class TermDepositBalanceSync // or injected service
{
    // Load account, set Balance = sumOpenPrincipal, snapshot if changed, UpdateAsync
}
```

Prefer injectable:

```csharp
public interface ITermDepositBalanceSync
{
    Task SyncAccountAsync(int financeAccountId, string userId, CancellationToken ct = default);
}
```

Implementation uses `ITermDepositRepository.SumOpenPrincipalAsync` + `IFinanceAccountRepository`.

Update handler: after load, if `account.Type == FinanceAccountType.TermSaving` && `request.Balance != account.Balance` → `throw new BadRequestException("TermSaving balance is derived from open term deposits.");`  
Allow name/sort/rate/currency updates; if Type is TermSaving, ignore or reject balance change only.

- [ ] **Step 1: Failing test** — update TermSaving balance → BadRequestException

- [ ] **Step 2: RED**

- [ ] **Step 3: Implement sync + handler guard**

- [ ] **Step 4: GREEN**

- [ ] **Step 5: Commit**

```bash
git -C D:/Projects/SF/SFBE commit -m "feat(finance): sync TermSaving balance and reject manual balance edits"
```

---

### Task 4: Create + List + Summary (TDD)

**Files:**
- DTOs: `TermDepositDto`, `TermDepositListDto` (optional), `TermDepositSummaryDto`
- Commands/Queries: Create, ListByAccount, ListAll, Summary
- Validators for create
- Tests: Create two Open → balance sync; summary YieldPercent; Cash account → 400

**Create body:** `Principal`, `AnnualRatePercent`, `TermMonths`, `StartDate`, `Notes?`  
Handler: verify account TermSaving + owner; compute; `Status=Open`; create; `SyncAccountAsync`.

**Summary DTO:**

```csharp
public class TermDepositSummaryDto
{
    public decimal TotalPrincipal { get; set; }
    public decimal TotalExpectedInterest { get; set; }
    public decimal TotalMaturityAmount { get; set; }
    public decimal YieldPercent { get; set; }
}
```

`YieldPercent = TotalPrincipal == 0 ? 0 : TotalExpectedInterest / TotalPrincipal * 100`

- [ ] **Steps:** TDD create+sync → list → summary → commit

```bash
git -C D:/Projects/SF/SFBE commit -m "feat(finance): create and list term deposits with summary"
```

---

### Task 5: Update, Close, Renew (TDD)

**Files:** Update/Close/Renew commands + validators + tests

- Update: Open only; recompute; sync
- Close: set Closed + ClosedAt UtcNow; sync
- Renew command body = same fields as create; transactionally close + create; sync once

- [ ] **Steps:** TDD each → commit

```bash
git -C D:/Projects/SF/SFBE commit -m "feat(finance): update close and renew term deposits"
```

---

### Task 6: API controller

**Files:** Create `TermDepositsController.cs` under `api/finance` routes matching spec.

Wire MediatR. `[Authorize]`.

- [ ] **Step 1: Controller**
- [ ] **Step 2: `dotnet build` Web.API**
- [ ] **Step 3: Commit**

```bash
git -C D:/Projects/SF/SFBE commit -m "feat(finance): expose term deposit REST API"
```

---

### Task 7: FE Ladder UI + nav + Accounts link

**Files:** FinanceService extensions, Ladder view, routes, nav, Accounts.tsx

**API client:** unwrap `response.data` (Axios).

**Ladder page props:** optional `accountId` from route; if missing, show Select of TermSaving accounts from `apiGetFinanceAccounts`.

**Accounts:** For `type === TermSaving` (or enum 1): show Ladder button; in edit dialog disable Balance input + helper text “Derived from ladder”.

**Labels (VI):** Gốc, Lãi suất, Lãi dự tính, Kỳ hạn, Ngày gửi, Đáo hạn, Số dư đáo hạn, Tổng gốc, Tổng lãi, Tổng đáo hạn, Tỷ suất lãi; badge Quá hạn when `maturityDate < today` && Open.

- [ ] **Step 1: Service methods**
- [ ] **Step 2: Ladder.tsx + routes + nav**
- [ ] **Step 3: Accounts integration**
- [ ] **Step 4: `npm run build`**
- [ ] **Step 5: Commit (SFFE)**

```bash
git -C D:/Projects/SF/SFFE commit -m "feat(finance): term deposit ladder UI"
```

---

### Task 8: API-MAP + verification

**Files:** `workspace/docs/API-MAP.md`

```markdown
## Finance Term Deposits — FinanceService → TermDepositsController

| FE | Method | BE path |
|----|--------|---------|
| `apiGetTermDepositsByAccount` | GET | `api/finance/accounts/{accountId}/deposits` |
| `apiCreateTermDeposit` | POST | `api/finance/accounts/{accountId}/deposits` |
| `apiUpdateTermDeposit` | PUT | `api/finance/deposits/{id}` |
| `apiCloseTermDeposit` | POST | `api/finance/deposits/{id}/close` |
| `apiRenewTermDeposit` | POST | `api/finance/deposits/{id}/renew` |
| `apiGetTermDeposits` | GET | `api/finance/deposits` |
| `apiGetTermDepositSummary` | GET | `api/finance/accounts/{accountId}/deposits/summary` |
```

- [ ] **Step 1: Update API-MAP**
- [ ] **Step 2: `dotnet test` filter TermDeposit + FinanceAccounts**
- [ ] **Step 3: Commit workspace**

```bash
git -C D:/Projects/SF/workspace commit -m "docs: map term deposit ladder API and approve ladder spec"
```

---

## Self-review (plan vs spec)

| Spec item | Task |
|-----------|------|
| Entity + formula A | 1 |
| EF + 400 middleware | 2 |
| Derived balance + reject manual | 3 |
| CRUD list/summary | 4–5 |
| Close/renew | 5 |
| REST | 6 |
| FE both entry points | 7 |
| API-MAP + terms | 8 |
| No Margin naming | Global Constraints |
| No auto Matured | Global Constraints |

**Placeholder scan:** none intentional.  
**Type consistency:** `TermDepositStatus`, summary field names match terminology doc.
