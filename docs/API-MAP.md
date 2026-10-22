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
| `apiCreateFinanceAccount` | POST | `api/finance/accounts` |
| `apiUpdateFinanceAccount` | PUT | `api/finance/accounts/{id}` |
| `apiArchiveFinanceAccount` | DELETE | `api/finance/accounts/{id}` |
| `apiGetAccountSnapshots` | GET | `api/finance/accounts/{id}/snapshots` |
| `apiGetFinanceSummary` | GET | `api/finance/summary` |

## Auth header

`Authorization: Bearer <token>` — `FE/src/services/BaseService.ts`
