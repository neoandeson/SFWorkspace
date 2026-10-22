# Finance Accounts Phase B Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship personal Finance Accounts (Excel “account tổng”) with manual balances, FX→VND, and balance/rate snapshots — no ladder yet.

**Architecture:** New Finance feature in the SF modular monolith: domain entities + repository → MediatR commands/queries → `FinanceAccountsController`. FE adds Finance → Accounts page calling REST. Snapshots written in the same SaveChanges as create / balance-or-rate updates. Ownership via `IUserContext` + `UserId`.

**Tech Stack:** .NET 10, EF Core + PostgreSQL (`LedgerDBContext`), MediatR, FluentValidation, xUnit/Moq/FluentAssertions; React 18 + Vite + Redux toolkit patterns already in SFFE; Axios `ApiService`.

**Spec:** `workspace/docs/superpowers/specs/2026-10-22-finance-accounts-phase-b-design.md`

## Global Constraints

- Entity names: `FinanceAccount`, `AccountBalanceSnapshot` (never collide with Identity `Account`).
- Types enum only: `Cash`, `TermSaving`, `Crypto`, `Brokerage`, `Other`.
- Names/providers are free text — no hardcoded TPB/TCB/Binance.
- `Currency = VND` ⇒ server forces `FxRateToVnd = 1`.
- `ValueVnd = Balance * FxRateToVnd` (store on snapshot; compute on DTO for list).
- Snapshot on create and when `Balance` or `FxRateToVnd` changes; not on name/type/sort/archive-only.
- `DELETE` = soft archive (`IsArchived = true`); no hard delete in this phase.
- All data scoped to current Identity user; wrong id / other user → `NotFoundException` → 404.
- Ladder / derived TermSaving / Excel import / broker APIs are out of scope.
- Backend-first: API + migration → Swagger → FE → update `workspace/docs/API-MAP.md`.
- Repos: SFBE = `D:\Projects\SF\SFBE`, SFFE = `D:\Projects\SF\SFFE`, docs = `D:\Projects\SF\workspace`. Commit in the repo you change.

---

## File structure (locked in)

### SFBE — create

| Path | Responsibility |
|------|----------------|
| `src/Web.Domain/Entities/FinanceAccount.cs` | Account aggregate |
| `src/Web.Domain/Entities/AccountBalanceSnapshot.cs` | History row |
| `src/Web.Domain/Enums/FinanceAccountType.cs` | Fixed types |
| `src/Web.Domain/Repositories/IFinanceAccountRepository.cs` | Persistence + snapshots in one UoW |
| `src/Web.Infrastructure/Repositories/FinanceAccountRepository.cs` | EF implementation |
| `src/Web.Application/FinanceAccounts/Dtos/*.cs` | List/detail/summary/snapshot DTOs |
| `src/Web.Application/FinanceAccounts/Commands/CreateFinanceAccount/*` | Create + validator |
| `src/Web.Application/FinanceAccounts/Commands/UpdateFinanceAccount/*` | Update + snapshot rules + validator |
| `src/Web.Application/FinanceAccounts/Commands/ArchiveFinanceAccount/*` | Soft archive |
| `src/Web.Application/FinanceAccounts/Queries/GetFinanceAccounts/*` | List + totalVnd |
| `src/Web.Application/FinanceAccounts/Queries/GetFinanceSummary/*` | Breakdown by type |
| `src/Web.Application/FinanceAccounts/Queries/GetAccountSnapshots/*` | Paginated history |
| `src/Web.API/Controllers/FinanceAccountsController.cs` | REST surface |
| `tests/Web.Application.Tests/FinanceAccounts/*.cs` | Handler unit tests |

### SFBE — modify

| Path | Change |
|------|--------|
| `src/Web.Infrastructure/Persistence/LedgerDBContext.cs` | DbSets + FK config |
| `src/Web.Infrastructure/Extensions/ServiceCollectionExtensions.cs` | Register `IFinanceAccountRepository` |
| `src/Web.Infrastructure/Migrations/*` | EF migration `AddFinanceAccounts` |

### SFFE — create

| Path | Responsibility |
|------|----------------|
| `src/services/FinanceService.ts` | API client |
| `src/views/finance/Accounts/index.ts` | Barrel |
| `src/views/finance/Accounts/Accounts.tsx` | Table + total + CRUD/history UI |

### SFFE — modify

| Path | Change |
|------|--------|
| `src/configs/routes.config/routes.config.ts` | Protected route |
| `src/configs/navigation.config/index.ts` | Finance → Accounts nav |
| `src/configs/navigation-icon.config.tsx` | Icon key if needed |

### workspace — modify

| Path | Change |
|------|--------|
| `docs/API-MAP.md` | Finance endpoints table |
| `docs/superpowers/specs/2026-10-22-finance-accounts-phase-b-design.md` | Status Approved (if not already) |

---

### Task 1: Domain entities + repository contract

**Files:**
- Create: `SFBE/src/Web.Domain/Enums/FinanceAccountType.cs`
- Create: `SFBE/src/Web.Domain/Entities/FinanceAccount.cs`
- Create: `SFBE/src/Web.Domain/Entities/AccountBalanceSnapshot.cs`
- Create: `SFBE/src/Web.Domain/Repositories/IFinanceAccountRepository.cs`

**Interfaces:**
- Produces: `FinanceAccountType`, `FinanceAccount`, `AccountBalanceSnapshot`, `IFinanceAccountRepository` (signatures below)

- [ ] **Step 1: Add enum**

```csharp
namespace Web.Domain.Enums;

public enum FinanceAccountType
{
    Cash = 0,
    TermSaving = 1,
    Crypto = 2,
    Brokerage = 3,
    Other = 4
}
```

- [ ] **Step 2: Add entities**

```csharp
using Web.Domain.Enums;

namespace Web.Domain.Entities;

public class FinanceAccount
{
    public int Id { get; set; }
    public string UserId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public FinanceAccountType Type { get; set; }
    public string Currency { get; set; } = default!;
    public decimal Balance { get; set; }
    public decimal FxRateToVnd { get; set; }
    public int SortOrder { get; set; }
    public bool IsArchived { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public ICollection<AccountBalanceSnapshot> Snapshots { get; set; } = new List<AccountBalanceSnapshot>();
}
```

```csharp
namespace Web.Domain.Entities;

public class AccountBalanceSnapshot
{
    public int Id { get; set; }
    public int FinanceAccountId { get; set; }
    public FinanceAccount? FinanceAccount { get; set; }
    public string UserId { get; set; } = default!;
    public decimal Balance { get; set; }
    public decimal FxRateToVnd { get; set; }
    public decimal ValueVnd { get; set; }
    public DateTime RecordedAt { get; set; }
}
```

- [ ] **Step 3: Add repository interface**

```csharp
using Web.Domain.Entities;

namespace Web.Domain.Repositories;

public interface IFinanceAccountRepository
{
    Task<FinanceAccount?> GetByIdForUserAsync(int id, string userId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<FinanceAccount>> ListForUserAsync(string userId, bool includeArchived, CancellationToken cancellationToken = default);
    Task<int> CreateWithSnapshotAsync(FinanceAccount account, AccountBalanceSnapshot snapshot, CancellationToken cancellationToken = default);
    Task UpdateAsync(FinanceAccount account, AccountBalanceSnapshot? newSnapshot, CancellationToken cancellationToken = default);
    Task<(IReadOnlyList<AccountBalanceSnapshot> Items, int TotalCount)> ListSnapshotsAsync(
        int accountId, string userId, int pageIndex, int pageSize, CancellationToken cancellationToken = default);
}
```

- [ ] **Step 4: Build Domain project**

Run: `dotnet build D:\Projects\SF\SFBE\src\Web.Domain\Web.Domain.csproj`  
Expected: 0 errors

- [ ] **Step 5: Commit (SFBE)**

```bash
git -C D:/Projects/SF/SFBE add src/Web.Domain/Enums/FinanceAccountType.cs src/Web.Domain/Entities/FinanceAccount.cs src/Web.Domain/Entities/AccountBalanceSnapshot.cs src/Web.Domain/Repositories/IFinanceAccountRepository.cs
git -C D:/Projects/SF/SFBE commit -m "feat(finance): add FinanceAccount domain model and repository contract"
```

---

### Task 2: EF persistence, migration, DI

**Files:**
- Modify: `SFBE/src/Web.Infrastructure/Persistence/LedgerDBContext.cs`
- Create: `SFBE/src/Web.Infrastructure/Repositories/FinanceAccountRepository.cs`
- Modify: `SFBE/src/Web.Infrastructure/Extensions/ServiceCollectionExtensions.cs`
- Create: migration via `dotnet ef`

**Interfaces:**
- Consumes: `IFinanceAccountRepository`, entities from Task 1
- Produces: working EF mapping + registered repo

- [ ] **Step 1: Extend DbContext**

Add DbSets and relationship (inside `LedgerDBContext`):

```csharp
internal DbSet<FinanceAccount> FinanceAccounts { get; set; }
internal DbSet<AccountBalanceSnapshot> AccountBalanceSnapshots { get; set; }
```

In `OnModelCreating`, after existing config:

```csharp
modelBuilder.Entity<FinanceAccount>(e =>
{
    e.Property(x => x.Name).HasMaxLength(100).IsRequired();
    e.Property(x => x.Currency).HasMaxLength(16).IsRequired();
    e.Property(x => x.UserId).HasMaxLength(450).IsRequired();
    e.Property(x => x.Balance).HasPrecision(18, 4);
    e.Property(x => x.FxRateToVnd).HasPrecision(18, 6);
    e.HasIndex(x => new { x.UserId, x.IsArchived });
    e.HasMany(x => x.Snapshots)
        .WithOne(s => s.FinanceAccount!)
        .HasForeignKey(s => s.FinanceAccountId)
        .OnDelete(DeleteBehavior.Cascade);
});

modelBuilder.Entity<AccountBalanceSnapshot>(e =>
{
    e.Property(x => x.UserId).HasMaxLength(450).IsRequired();
    e.Property(x => x.Balance).HasPrecision(18, 4);
    e.Property(x => x.FxRateToVnd).HasPrecision(18, 6);
    e.Property(x => x.ValueVnd).HasPrecision(18, 2);
    e.HasIndex(x => new { x.FinanceAccountId, x.RecordedAt });
});
```

- [ ] **Step 2: Implement repository**

```csharp
using Microsoft.EntityFrameworkCore;
using Web.Domain.Entities;
using Web.Domain.Repositories;
using Web.Infrastructure.Persistence;

namespace Web.Infrastructure.Repositories;

internal class FinanceAccountRepository(LedgerDBContext dbContext) : IFinanceAccountRepository
{
    public async Task<FinanceAccount?> GetByIdForUserAsync(int id, string userId, CancellationToken cancellationToken = default)
        => await dbContext.FinanceAccounts
            .FirstOrDefaultAsync(a => a.Id == id && a.UserId == userId, cancellationToken);

    public async Task<IReadOnlyList<FinanceAccount>> ListForUserAsync(string userId, bool includeArchived, CancellationToken cancellationToken = default)
    {
        var q = dbContext.FinanceAccounts.AsNoTracking().Where(a => a.UserId == userId);
        if (!includeArchived) q = q.Where(a => !a.IsArchived);
        return await q.OrderBy(a => a.SortOrder).ThenBy(a => a.Id).ToListAsync(cancellationToken);
    }

    public async Task<int> CreateWithSnapshotAsync(FinanceAccount account, AccountBalanceSnapshot snapshot, CancellationToken cancellationToken = default)
    {
        dbContext.FinanceAccounts.Add(account);
        await dbContext.SaveChangesAsync(cancellationToken);
        snapshot.FinanceAccountId = account.Id;
        dbContext.AccountBalanceSnapshots.Add(snapshot);
        await dbContext.SaveChangesAsync(cancellationToken);
        return account.Id;
    }

    public async Task UpdateAsync(FinanceAccount account, AccountBalanceSnapshot? newSnapshot, CancellationToken cancellationToken = default)
    {
        dbContext.FinanceAccounts.Update(account);
        if (newSnapshot is not null)
            dbContext.AccountBalanceSnapshots.Add(newSnapshot);
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<(IReadOnlyList<AccountBalanceSnapshot> Items, int TotalCount)> ListSnapshotsAsync(
        int accountId, string userId, int pageIndex, int pageSize, CancellationToken cancellationToken = default)
    {
        var q = dbContext.AccountBalanceSnapshots.AsNoTracking()
            .Where(s => s.FinanceAccountId == accountId && s.UserId == userId);
        var total = await q.CountAsync(cancellationToken);
        var items = await q.OrderByDescending(s => s.RecordedAt)
            .Skip(pageIndex * pageSize).Take(pageSize)
            .ToListAsync(cancellationToken);
        return (items, total);
    }
}
```

Prefer single `SaveChanges` on create: add account + snapshot in one graph (`account.Snapshots.Add(snapshot)` then one save). If using graph insert, adjust Step 2 accordingly so `FinanceAccountId` is set by EF — either approach is fine; pick **one SaveChanges** if possible:

```csharp
account.Snapshots.Add(snapshot);
dbContext.FinanceAccounts.Add(account);
await dbContext.SaveChangesAsync(cancellationToken);
return account.Id;
```

- [ ] **Step 3: Register DI**

In `ServiceCollectionExtensions.cs` next to other repos:

```csharp
services.AddScoped<IFinanceAccountRepository, FinanceAccountRepository>();
```

- [ ] **Step 4: Add migration**

Run:

```powershell
cd D:\Projects\SF\SFBE
dotnet ef migrations add AddFinanceAccounts --project src/Web.Infrastructure --startup-project src/Web.API
```

Expected: new files under `src/Web.Infrastructure/Migrations/` creating `FinanceAccounts` and `AccountBalanceSnapshots`.

- [ ] **Step 5: Apply migration locally**

Run: `dotnet ef database update --project src/Web.Infrastructure --startup-project src/Web.API`  
Expected: success against local Postgres (`CentimilDB`).

- [ ] **Step 6: Commit (SFBE)**

```bash
git -C D:/Projects/SF/SFBE add src/Web.Infrastructure/Persistence/LedgerDBContext.cs src/Web.Infrastructure/Repositories/FinanceAccountRepository.cs src/Web.Infrastructure/Extensions/ServiceCollectionExtensions.cs src/Web.Infrastructure/Migrations
git -C D:/Projects/SF/SFBE commit -m "feat(finance): persist FinanceAccounts and snapshots"
```

---

### Task 3: CreateFinanceAccount (TDD)

**Files:**
- Create: `SFBE/src/Web.Application/FinanceAccounts/Dtos/FinanceAccountDto.cs`
- Create: `SFBE/src/Web.Application/FinanceAccounts/Commands/CreateFinanceAccount/CreateFinanceAccountCommand.cs`
- Create: `SFBE/src/Web.Application/FinanceAccounts/Commands/CreateFinanceAccount/CreateFinanceAccountCommandValidator.cs`
- Create: `SFBE/src/Web.Application/FinanceAccounts/Commands/CreateFinanceAccount/CreateFinanceAccountCommandHandler.cs`
- Test: `SFBE/tests/Web.Application.Tests/FinanceAccounts/CreateFinanceAccountCommandHandlerTests.cs`

**Interfaces:**
- Consumes: `IFinanceAccountRepository`, `IUserContext`
- Produces: `CreateFinanceAccountCommand : IRequest<int>`, handler creating account + snapshot; VND rate forced to 1

- [ ] **Step 1: Write failing tests**

```csharp
using FluentAssertions;
using Moq;
using Web.Application.FinanceAccounts.Commands.CreateFinanceAccount;
using Web.Application.Users;
using Web.Domain.Entities;
using Web.Domain.Enums;
using Web.Domain.Repositories;
using Xunit;

namespace Web.Application.Tests.FinanceAccounts;

public class CreateFinanceAccountCommandHandlerTests
{
    [Fact]
    public async Task Handle_CreatesAccountAndSnapshot_WithValueVnd()
    {
        FinanceAccount? saved = null;
        AccountBalanceSnapshot? snap = null;
        var repo = new Mock<IFinanceAccountRepository>();
        repo.Setup(r => r.CreateWithSnapshotAsync(It.IsAny<FinanceAccount>(), It.IsAny<AccountBalanceSnapshot>(), It.IsAny<CancellationToken>()))
            .Callback<FinanceAccount, AccountBalanceSnapshot, CancellationToken>((a, s, _) => { saved = a; snap = s; })
            .ReturnsAsync(7);

        var userCtx = new Mock<IUserContext>();
        userCtx.Setup(u => u.GetCurrentUser()).Returns(new CurrentUser("user-1", "a@b.c", [], null, null));

        var handler = new CreateFinanceAccountCommandHandler(repo.Object, userCtx.Object);
        var id = await handler.Handle(new CreateFinanceAccountCommand
        {
            Name = "BinanceEarn USDT",
            Type = FinanceAccountType.Crypto,
            Currency = "USDT",
            Balance = 1291m,
            FxRateToVnd = 26050m,
            SortOrder = 5
        }, CancellationToken.None);

        id.Should().Be(7);
        saved!.UserId.Should().Be("user-1");
        saved.Balance.Should().Be(1291m);
        snap!.ValueVnd.Should().Be(1291m * 26050m);
        snap.UserId.Should().Be("user-1");
    }

    [Fact]
    public async Task Handle_WhenCurrencyVnd_ForcesFxRateToOne()
    {
        FinanceAccount? saved = null;
        var repo = new Mock<IFinanceAccountRepository>();
        repo.Setup(r => r.CreateWithSnapshotAsync(It.IsAny<FinanceAccount>(), It.IsAny<AccountBalanceSnapshot>(), It.IsAny<CancellationToken>()))
            .Callback<FinanceAccount, AccountBalanceSnapshot, CancellationToken>((a, _, _) => saved = a)
            .ReturnsAsync(1);
        var userCtx = new Mock<IUserContext>();
        userCtx.Setup(u => u.GetCurrentUser()).Returns(new CurrentUser("u", "a@b.c", [], null, null));

        var handler = new CreateFinanceAccountCommandHandler(repo.Object, userCtx.Object);
        await handler.Handle(new CreateFinanceAccountCommand
        {
            Name = "TPBank Cash",
            Type = FinanceAccountType.Cash,
            Currency = "vnd",
            Balance = 5_000_000m,
            FxRateToVnd = 99m,
            SortOrder = 0
        }, CancellationToken.None);

        saved!.Currency.Should().Be("VND");
        saved.FxRateToVnd.Should().Be(1m);
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL**

Run: `dotnet test D:\Projects\SF\SFBE\tests\Web.Application.Tests\Web.Application.Tests.csproj --filter FullyQualifiedName~CreateFinanceAccountCommandHandlerTests`  
Expected: FAIL (types/handler missing)

- [ ] **Step 3: Implement DTO, command, validator, handler**

`FinanceAccountDto.cs`:

```csharp
using Web.Domain.Enums;

namespace Web.Application.FinanceAccounts.Dtos;

public class FinanceAccountDto
{
    public int Id { get; set; }
    public string Name { get; set; } = default!;
    public FinanceAccountType Type { get; set; }
    public string Currency { get; set; } = default!;
    public decimal Balance { get; set; }
    public decimal FxRateToVnd { get; set; }
    public decimal ValueVnd { get; set; }
    public int SortOrder { get; set; }
    public bool IsArchived { get; set; }
    public DateTime UpdatedAt { get; set; }
}
```

Command + handler (minimal):

```csharp
using MediatR;
using Web.Domain.Enums;

namespace Web.Application.FinanceAccounts.Commands.CreateFinanceAccount;

public class CreateFinanceAccountCommand : IRequest<int>
{
    public string Name { get; set; } = default!;
    public FinanceAccountType Type { get; set; }
    public string Currency { get; set; } = default!;
    public decimal Balance { get; set; }
    public decimal FxRateToVnd { get; set; } = 1m;
    public int SortOrder { get; set; }
}
```

```csharp
using FluentValidation;
using Web.Domain.Enums;

namespace Web.Application.FinanceAccounts.Commands.CreateFinanceAccount;

public class CreateFinanceAccountCommandValidator : AbstractValidator<CreateFinanceAccountCommand>
{
    public CreateFinanceAccountCommandValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        RuleFor(x => x.Type).IsInEnum();
        RuleFor(x => x.Currency).NotEmpty().MaximumLength(16);
        RuleFor(x => x.Balance).GreaterThanOrEqualTo(0);
        RuleFor(x => x.FxRateToVnd).GreaterThan(0);
        RuleFor(x => x.SortOrder).GreaterThanOrEqualTo(0);
    }
}
```

```csharp
using MediatR;
using Web.Application.Users;
using Web.Domain.Entities;
using Web.Domain.Repositories;

namespace Web.Application.FinanceAccounts.Commands.CreateFinanceAccount;

internal class CreateFinanceAccountCommandHandler(
    IFinanceAccountRepository repository,
    IUserContext userContext) : IRequestHandler<CreateFinanceAccountCommand, int>
{
    public async Task<int> Handle(CreateFinanceAccountCommand request, CancellationToken cancellationToken)
    {
        var user = userContext.GetCurrentUser()
            ?? throw new UnauthorizedAccessException("User is not authenticated");

        var currency = request.Currency.Trim().ToUpperInvariant();
        var rate = currency == "VND" ? 1m : request.FxRateToVnd;
        var now = DateTime.UtcNow;

        var account = new FinanceAccount
        {
            UserId = user.Id,
            Name = request.Name.Trim(),
            Type = request.Type,
            Currency = currency,
            Balance = request.Balance,
            FxRateToVnd = rate,
            SortOrder = request.SortOrder,
            IsArchived = false,
            CreatedAt = now,
            UpdatedAt = now
        };

        var snapshot = new AccountBalanceSnapshot
        {
            UserId = user.Id,
            Balance = account.Balance,
            FxRateToVnd = account.FxRateToVnd,
            ValueVnd = account.Balance * account.FxRateToVnd,
            RecordedAt = now
        };

        return await repository.CreateWithSnapshotAsync(account, snapshot, cancellationToken);
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

Run: same `dotnet test` filter as Step 2  
Expected: PASS

- [ ] **Step 5: Commit (SFBE)**

```bash
git -C D:/Projects/SF/SFBE add src/Web.Application/FinanceAccounts tests/Web.Application.Tests/FinanceAccounts/CreateFinanceAccountCommandHandlerTests.cs
git -C D:/Projects/SF/SFBE commit -m "feat(finance): create finance account with initial snapshot"
```

---

### Task 4: UpdateFinanceAccount — snapshot rules (TDD)

**Files:**
- Create: `SFBE/src/Web.Application/FinanceAccounts/Commands/UpdateFinanceAccount/UpdateFinanceAccountCommand.cs`
- Create: `SFBE/src/Web.Application/FinanceAccounts/Commands/UpdateFinanceAccount/UpdateFinanceAccountCommandValidator.cs`
- Create: `SFBE/src/Web.Application/FinanceAccounts/Commands/UpdateFinanceAccount/UpdateFinanceAccountCommandHandler.cs`
- Test: `SFBE/tests/Web.Application.Tests/FinanceAccounts/UpdateFinanceAccountCommandHandlerTests.cs`

**Interfaces:**
- Consumes: `IFinanceAccountRepository.GetByIdForUserAsync`, `UpdateAsync`
- Produces: update handler; throws `NotFoundException` if missing/other user

- [ ] **Step 1: Write failing tests**

Cover: (1) name-only → `newSnapshot` null; (2) balance change → snapshot with new ValueVnd; (3) missing id → `NotFoundException`; (4) VND forces rate 1.

```csharp
using FluentAssertions;
using Moq;
using Web.Application.FinanceAccounts.Commands.UpdateFinanceAccount;
using Web.Application.Users;
using Web.Domain.Entities;
using Web.Domain.Enums;
using Web.Domain.Exceptions;
using Web.Domain.Repositories;
using Xunit;

namespace Web.Application.Tests.FinanceAccounts;

public class UpdateFinanceAccountCommandHandlerTests
{
    private static FinanceAccount Seed() => new()
    {
        Id = 3,
        UserId = "user-1",
        Name = "ACB",
        Type = FinanceAccountType.TermSaving,
        Currency = "VND",
        Balance = 100m,
        FxRateToVnd = 1m,
        SortOrder = 1,
        CreatedAt = DateTime.UtcNow.AddDays(-1),
        UpdatedAt = DateTime.UtcNow.AddDays(-1)
    };

    [Fact]
    public async Task Handle_NameOnly_DoesNotCreateSnapshot()
    {
        var account = Seed();
        var repo = new Mock<IFinanceAccountRepository>();
        repo.Setup(r => r.GetByIdForUserAsync(3, "user-1", It.IsAny<CancellationToken>())).ReturnsAsync(account);
        AccountBalanceSnapshot? snapArg = new AccountBalanceSnapshot(); // sentinel
        repo.Setup(r => r.UpdateAsync(account, It.IsAny<AccountBalanceSnapshot?>(), It.IsAny<CancellationToken>()))
            .Callback<FinanceAccount, AccountBalanceSnapshot?, CancellationToken>((_, s, _) => snapArg = s)
            .Returns(Task.CompletedTask);

        var userCtx = new Mock<IUserContext>();
        userCtx.Setup(u => u.GetCurrentUser()).Returns(new CurrentUser("user-1", "a@b.c", [], null, null));

        var handler = new UpdateFinanceAccountCommandHandler(repo.Object, userCtx.Object);
        await handler.Handle(new UpdateFinanceAccountCommand
        {
            Id = 3,
            Name = "ACB Saving",
            Type = FinanceAccountType.TermSaving,
            Currency = "VND",
            Balance = 100m,
            FxRateToVnd = 1m,
            SortOrder = 1
        }, CancellationToken.None);

        snapArg.Should().BeNull();
        account.Name.Should().Be("ACB Saving");
    }

    [Fact]
    public async Task Handle_BalanceChange_CreatesSnapshot()
    {
        var account = Seed();
        var repo = new Mock<IFinanceAccountRepository>();
        repo.Setup(r => r.GetByIdForUserAsync(3, "user-1", It.IsAny<CancellationToken>())).ReturnsAsync(account);
        AccountBalanceSnapshot? snapArg = null;
        repo.Setup(r => r.UpdateAsync(account, It.IsAny<AccountBalanceSnapshot?>(), It.IsAny<CancellationToken>()))
            .Callback<FinanceAccount, AccountBalanceSnapshot?, CancellationToken>((_, s, _) => snapArg = s)
            .Returns(Task.CompletedTask);
        var userCtx = new Mock<IUserContext>();
        userCtx.Setup(u => u.GetCurrentUser()).Returns(new CurrentUser("user-1", "a@b.c", [], null, null));

        var handler = new UpdateFinanceAccountCommandHandler(repo.Object, userCtx.Object);
        await handler.Handle(new UpdateFinanceAccountCommand
        {
            Id = 3,
            Name = "ACB",
            Type = FinanceAccountType.TermSaving,
            Currency = "VND",
            Balance = 150m,
            FxRateToVnd = 1m,
            SortOrder = 1
        }, CancellationToken.None);

        snapArg.Should().NotBeNull();
        snapArg!.Balance.Should().Be(150m);
        snapArg.ValueVnd.Should().Be(150m);
    }

    [Fact]
    public async Task Handle_Missing_ThrowsNotFound()
    {
        var repo = new Mock<IFinanceAccountRepository>();
        repo.Setup(r => r.GetByIdForUserAsync(99, "user-1", It.IsAny<CancellationToken>()))
            .ReturnsAsync((FinanceAccount?)null);
        var userCtx = new Mock<IUserContext>();
        userCtx.Setup(u => u.GetCurrentUser()).Returns(new CurrentUser("user-1", "a@b.c", [], null, null));

        var handler = new UpdateFinanceAccountCommandHandler(repo.Object, userCtx.Object);
        var act = () => handler.Handle(new UpdateFinanceAccountCommand
        {
            Id = 99,
            Name = "X",
            Type = FinanceAccountType.Other,
            Currency = "VND",
            Balance = 0,
            FxRateToVnd = 1,
            SortOrder = 0
        }, CancellationToken.None);

        await act.Should().ThrowAsync<NotFoundException>();
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL**

Run: `dotnet test ... --filter FullyQualifiedName~UpdateFinanceAccountCommandHandlerTests`

- [ ] **Step 3: Implement command, validator (same rules as create + Id > 0), handler**

Handler logic:
1. Resolve user; load `GetByIdForUserAsync` or `NotFoundException(nameof(FinanceAccount), id)`.
2. Normalize currency uppercase; if VND force rate 1.
3. Detect change: `balanceChanged || rateChanged`.
4. Apply fields; `UpdatedAt = UtcNow`.
5. If changed, build snapshot (`FinanceAccountId = account.Id`, `UserId`, balances, `ValueVnd`, `RecordedAt`).
6. `UpdateAsync(account, snapshotOrNull)`.

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit (SFBE)**

```bash
git -C D:/Projects/SF/SFBE commit -am "feat(finance): update finance account with conditional snapshots"
```

(Prefer explicit `git add` of the new UpdateFinanceAccount files + test file.)

---

### Task 5: List, summary, archive, snapshots queries

**Files:**
- Create: `.../Dtos/FinanceAccountListDto.cs` (`Items` + `TotalVnd`)
- Create: `.../Dtos/FinanceSummaryDto.cs` (`TotalVnd` + `IReadOnlyList<FinanceTypeBreakdownDto>` with `Type`, `TotalVnd`)
- Create: `.../Dtos/AccountBalanceSnapshotDto.cs`
- Create: `.../Dtos/PagedSnapshotsDto.cs` (`Items`, `TotalCount`, `PageIndex`, `PageSize`)
- Create: GetFinanceAccounts query + handler
- Create: GetFinanceSummary query + handler
- Create: ArchiveFinanceAccount command + handler
- Create: GetAccountSnapshots query + handler
- Test: `GetFinanceAccountsQueryHandlerTests.cs` (totalVnd sum, exclude archived by default)
- Test: `ArchiveFinanceAccountCommandHandlerTests.cs` (idempotent archive)

**Interfaces:**
- `GetFinanceAccountsQuery(bool IncludeArchived) : IRequest<FinanceAccountListDto>`
- `GetFinanceSummaryQuery : IRequest<FinanceSummaryDto>` — only non-archived
- `ArchiveFinanceAccountCommand { int Id } : IRequest`
- `GetAccountSnapshotsQuery { int AccountId, int PageIndex = 0, int PageSize = 50 } : IRequest<PagedSnapshotsDto>` — verify account ownership first (404 if not)

- [ ] **Step 1: Write failing tests for list total + archive no-op**

List test: two accounts balances/rates → `TotalVnd` equals sum of `Balance * FxRateToVnd`.  
Archive test: already `IsArchived=true` → still calls `UpdateAsync` with null snapshot (or skip update — either OK; prefer set true + UpdateAsync with null snapshot, idempotent).

- [ ] **Step 2: Run — FAIL**

- [ ] **Step 3: Implement handlers**

Mapping helper (inline in handlers is fine):

```csharp
static FinanceAccountDto ToDto(FinanceAccount a) => new()
{
    Id = a.Id,
    Name = a.Name,
    Type = a.Type,
    Currency = a.Currency,
    Balance = a.Balance,
    FxRateToVnd = a.FxRateToVnd,
    ValueVnd = a.Balance * a.FxRateToVnd,
    SortOrder = a.SortOrder,
    IsArchived = a.IsArchived,
    UpdatedAt = a.UpdatedAt
};
```

Summary: group listed non-archived by `Type`, sum ValueVnd.

Snapshots: `pageSize` clamp 1..100; `pageIndex` >= 0.

- [ ] **Step 4: Run tests — PASS**

- [ ] **Step 5: Commit (SFBE)**

```bash
git -C D:/Projects/SF/SFBE commit -m "feat(finance): list, summary, archive, and snapshot history queries"
```

---

### Task 6: API controller + Swagger smoke

**Files:**
- Create: `SFBE/src/Web.API/Controllers/FinanceAccountsController.cs`

**Interfaces:**
- Consumes: all MediatR requests from Tasks 3–5
- Produces: routes matching spec

- [ ] **Step 1: Add controller**

```csharp
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Web.Application.FinanceAccounts.Commands.ArchiveFinanceAccount;
using Web.Application.FinanceAccounts.Commands.CreateFinanceAccount;
using Web.Application.FinanceAccounts.Commands.UpdateFinanceAccount;
using Web.Application.FinanceAccounts.Dtos;
using Web.Application.FinanceAccounts.Queries.GetAccountSnapshots;
using Web.Application.FinanceAccounts.Queries.GetFinanceAccounts;
using Web.Application.FinanceAccounts.Queries.GetFinanceSummary;

namespace Web.API.Controllers;

[ApiController]
[Authorize]
[Route("api/finance")]
public class FinanceAccountsController(IMediator mediator) : ControllerBase
{
    [HttpGet("accounts")]
    public async Task<ActionResult<FinanceAccountListDto>> List([FromQuery] bool includeArchived = false, CancellationToken ct = default)
        => Ok(await mediator.Send(new GetFinanceAccountsQuery(includeArchived), ct));

    [HttpPost("accounts")]
    public async Task<ActionResult<int>> Create([FromBody] CreateFinanceAccountCommand command, CancellationToken ct = default)
    {
        var id = await mediator.Send(command, ct);
        return CreatedAtAction(nameof(List), new { id }, id);
    }

    [HttpPut("accounts/{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateFinanceAccountCommand command, CancellationToken ct = default)
    {
        command.Id = id;
        await mediator.Send(command, ct);
        return NoContent();
    }

    [HttpDelete("accounts/{id:int}")]
    public async Task<IActionResult> Archive(int id, CancellationToken ct = default)
    {
        await mediator.Send(new ArchiveFinanceAccountCommand { Id = id }, ct);
        return NoContent();
    }

    [HttpGet("accounts/{id:int}/snapshots")]
    public async Task<ActionResult<PagedSnapshotsDto>> Snapshots(
        int id, [FromQuery] int pageIndex = 0, [FromQuery] int pageSize = 50, CancellationToken ct = default)
        => Ok(await mediator.Send(new GetAccountSnapshotsQuery(id, pageIndex, pageSize), ct));

    [HttpGet("summary")]
    public async Task<ActionResult<FinanceSummaryDto>> Summary(CancellationToken ct = default)
        => Ok(await mediator.Send(new GetFinanceSummaryQuery(), ct));
}
```

Ensure query record/class constructors match what you implemented in Task 5 (`GetFinanceAccountsQuery` etc.).

- [ ] **Step 2: Run API + hit Swagger**

Run: `dotnet run --project D:\Projects\SF\SFBE\src\Web.API`  
Open: `http://localhost:5272/swagger`  
Manually: authorize → POST account → GET accounts → PUT balance → GET snapshots → GET summary → DELETE archive.

- [ ] **Step 3: Commit (SFBE)**

```bash
git -C D:/Projects/SF/SFBE add src/Web.API/Controllers/FinanceAccountsController.cs
git -C D:/Projects/SF/SFBE commit -m "feat(finance): expose finance accounts REST API"
```

---

### Task 7: FE service + Accounts page + nav

**Files:**
- Create: `SFFE/src/services/FinanceService.ts`
- Create: `SFFE/src/views/finance/Accounts/Accounts.tsx`
- Create: `SFFE/src/views/finance/Accounts/index.ts`
- Modify: `SFFE/src/configs/routes.config/routes.config.ts`
- Modify: `SFFE/src/configs/navigation.config/index.ts`
- Modify: `SFFE/src/configs/navigation-icon.config.tsx` (reuse an existing icon key if possible, e.g. `wallet` / `dashboard`)

**Interfaces:**
- Consumes: REST from Task 6
- Produces: UI list with total VND, create/edit dialog, archive, snapshots drawer/modal

- [ ] **Step 1: Add FinanceService**

```typescript
import ApiService from './ApiService'

export type FinanceAccountType = 'Cash' | 'TermSaving' | 'Crypto' | 'Brokerage' | 'Other'

export type FinanceAccount = {
    id: number
    name: string
    type: FinanceAccountType | number
    currency: string
    balance: number
    fxRateToVnd: number
    valueVnd: number
    sortOrder: number
    isArchived: boolean
    updatedAt: string
}

export type FinanceAccountList = {
    items: FinanceAccount[]
    totalVnd: number
}

export type CreateFinanceAccountPayload = {
    name: string
    type: FinanceAccountType | number
    currency: string
    balance: number
    fxRateToVnd: number
    sortOrder: number
}

export async function apiGetFinanceAccounts<T = FinanceAccountList>(includeArchived = false) {
    return ApiService.fetchData<T>({
        url: '/api/finance/accounts',
        method: 'get',
        params: { includeArchived },
    })
}

export async function apiCreateFinanceAccount<T = number>(data: CreateFinanceAccountPayload) {
    return ApiService.fetchData<T>({
        url: '/api/finance/accounts',
        method: 'post',
        data,
    })
}

export async function apiUpdateFinanceAccount<T = void>(id: number, data: CreateFinanceAccountPayload) {
    return ApiService.fetchData<T>({
        url: `/api/finance/accounts/${id}`,
        method: 'put',
        data,
    })
}

export async function apiArchiveFinanceAccount<T = void>(id: number) {
    return ApiService.fetchData<T>({
        url: `/api/finance/accounts/${id}`,
        method: 'delete',
    })
}

export async function apiGetAccountSnapshots<T>(id: number, pageIndex = 0, pageSize = 50) {
    return ApiService.fetchData<T>({
        url: `/api/finance/accounts/${id}/snapshots`,
        method: 'get',
        params: { pageIndex, pageSize },
    })
}

export async function apiGetFinanceSummary<T>() {
    return ApiService.fetchData<T>({
        url: '/api/finance/summary',
        method: 'get',
    })
}
```

Note: ASP.NET default JSON is camelCase — match property names accordingly. If enum serializes as number, map in UI (`Cash=0` …).

- [ ] **Step 2: Build Accounts view**

Keep UI consistent with existing Elstar tables/forms (look at `Portfolio.tsx` / Market tables for Table, Button, Dialog patterns). Required UX:

- Table columns: Name, Type, Currency, Balance, Rate, Value (VND)
- Footer / header: **Tổng** = `totalVnd` formatted
- Actions: Add, Edit, Archive, History (loads snapshots)
- Format VND with `vi-VN` locale

`index.ts`: `export { default } from './Accounts'`

- [ ] **Step 3: Wire route + nav**

Route (in `protectedRoutes`):

```typescript
{
    key: 'appsFinance.accounts',
    path: `${APP_PREFIX_PATH}/finance/accounts`,
    component: lazy(() => import('@/views/finance/Accounts')),
    authority: [],
    meta: { header: 'Accounts' },
},
```

Nav: new collapse **Finance** with child **Accounts** (`translateKey` can reuse title string for now).

- [ ] **Step 4: Manual FE verify**

Run FE (`npm run dev` in SFFE) + BE; login; open Finance → Accounts; create sample rows matching Excel account tổng; edit crypto rate; confirm history rows; archive one and confirm it drops from total.

- [ ] **Step 5: Commit (SFFE)**

```bash
git -C D:/Projects/SF/SFFE add src/services/FinanceService.ts src/views/finance src/configs/routes.config/routes.config.ts src/configs/navigation.config/index.ts src/configs/navigation-icon.config.tsx
git -C D:/Projects/SF/SFFE commit -m "feat(finance): accounts page for personal portfolio totals"
```

---

### Task 8: API-MAP + final verification

**Files:**
- Modify: `workspace/docs/API-MAP.md`
- Modify: spec status to Approved if needed

- [ ] **Step 1: Append API map section**

```markdown
## Finance — `FE/src/services/FinanceService.ts` → `FinanceAccountsController`

| FE | Method | BE path |
|----|--------|---------|
| `apiGetFinanceAccounts` | GET | `api/finance/accounts` |
| `apiCreateFinanceAccount` | POST | `api/finance/accounts` |
| `apiUpdateFinanceAccount` | PUT | `api/finance/accounts/{id}` |
| `apiArchiveFinanceAccount` | DELETE | `api/finance/accounts/{id}` |
| `apiGetAccountSnapshots` | GET | `api/finance/accounts/{id}/snapshots` |
| `apiGetFinanceSummary` | GET | `api/finance/summary` |
```

- [ ] **Step 2: Run full BE tests**

Run: `dotnet test D:\Projects\SF\SFBE\tests\Web.Application.Tests\Web.Application.Tests.csproj`  
Expected: all green including FinanceAccounts.*

- [ ] **Step 3: Commit (workspace)**

```bash
git -C D:/Projects/SF/workspace add docs/API-MAP.md docs/superpowers/specs/2026-10-22-finance-accounts-phase-b-design.md docs/superpowers/plans/2026-10-22-finance-accounts-phase-b.md
git -C D:/Projects/SF/workspace commit -m "docs: finance accounts Phase B plan and API map"
```

---

## Self-review (plan vs spec)

| Spec requirement | Task |
|------------------|------|
| FinanceAccount fields + types enum | 1 |
| AccountBalanceSnapshot | 1–2 |
| CRUD list/create/update + soft delete | 3–6 |
| Snapshot on create / balance|rate change | 3–4 |
| VND rate forced to 1 | 3–4 |
| Per-user ownership / 404 | 4–5 |
| Summary by type | 5–6 |
| FE Accounts + total VND | 7 |
| API-MAP | 8 |
| No ladder / no broker link | Global Constraints — not scheduled |

**Placeholder scan:** none intentional.  
**Type consistency:** `FinanceAccountType` enum shared Domain → Application → FE union/number mapping noted in Task 7.
