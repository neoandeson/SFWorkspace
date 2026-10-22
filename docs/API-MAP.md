# API Map (FE ↔ BE)

**Source of truth:** `http://localhost:5272/swagger`

Base URL dev: `http://localhost:5272/`  
Legacy prod: `http://115.165.166.146/port1/`

## Auth — `FE/src/services/AuthService.ts` → `AccountController`

| FE | Method | BE path |
|----|--------|---------|
| `apiSignIn` | POST | `api/account/sign-in` |
| `apiSignUp` | POST | `api/account/sign-up` |
| `apiSignInValidateGoogleToken` | POST | `api/account/google-auth` |
| `apiSignOut` | POST | `api/account/sign-out` |
| `apiForgotPassword` | POST | `forgot-password` |
| `apiResetPassword` | POST | `reset-password` |

## Instrument — `FE/src/services/CryptoService.ts` → `InstrumentController`

| FE | Method | BE path |
|----|--------|---------|
| `apiGetMarketData` | POST | `api/instrument/search` (body: tab, section, query, sort, pagination, optional `conditions[]`) |
| `apiUpdateFavorite` | POST | `api/instrument/update-favorite` |
| `apiUpdateIsViewed` | POST | `api/instrument/check-instrument-isviewed` |
| `apiUpdateInstrumentView` | POST | `api/instrument/update-instrument-view` |
| `apiGetCryptoDashboardData` | GET | `crypto/dashboard` |
| `apiGetPortfolioData` | GET | `crypto/portfolio` |
| `apiGetWalletData` | GET | `crypto/wallets` |
| `apiGetTransctionHistoryData` | POST | `crypto/wallets/history` |

## Finance — `FE/src/services/FinanceService.ts` → `FinanceAccountsController`

| FE | Method | BE path |
|----|--------|---------|
| `apiGetFinanceAccounts` | GET | `api/finance/accounts` |
| `apiCreateFinanceAccount` | POST | `api/finance/accounts` (body may include `instrumentId`) |
| `apiUpdateFinanceAccount` | PUT | `api/finance/accounts/{id}` (body may include `instrumentId`) |
| `apiArchiveFinanceAccount` | DELETE | `api/finance/accounts/{id}` |
| `apiGetAccountSnapshots` | GET | `api/finance/accounts/{id}/snapshots` |
| `apiGetFinanceSummary` | GET | `api/finance/summary` |

## Finance portfolio / settings — `FinanceService.ts` → `FinancePortfolioController` / `FinanceSettingsController`

| FE | Method | BE path |
|----|--------|---------|
| `apiGetFinanceSettings` | GET | `api/finance/settings` |
| `apiPutUsdVndRate` | PUT | `api/finance/settings/usd-vnd-rate` body `{ rate }` |
| `apiMarkPortfolio` | POST | `api/finance/portfolio/mark` |
| `apiGetPortfolioHistory` | GET | `api/finance/portfolio/history?from=&to=` (`DateOnly`, daily forward-fill) |

Mark-to-market runs on Portfolio view mount only — not on Instrument patch.

## Finance Term Deposits — `FE/src/services/FinanceService.ts` → `TermDepositsController`

| FE | Method | BE path |
|----|--------|---------|
| `apiGetTermDepositsByAccount` | GET | `api/finance/accounts/{accountId}/deposits` |
| `apiCreateTermDeposit` | POST | `api/finance/accounts/{accountId}/deposits` |
| `apiUpdateTermDeposit` | PUT | `api/finance/deposits/{id}` |
| `apiCloseTermDeposit` | POST | `api/finance/deposits/{id}/close` |
| `apiRenewTermDeposit` | POST | `api/finance/deposits/{id}/renew` |
| `apiGetTermDeposits` | GET | `api/finance/deposits` |
| `apiGetTermDepositSummary` | GET | `api/finance/accounts/{accountId}/deposits/summary` |

## Auth header

`Authorization: Bearer <token>` — `FE/src/services/BaseService.ts`
