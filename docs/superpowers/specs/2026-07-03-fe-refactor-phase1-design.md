# FE Refactor — Phase 1 Design

**Date:** 2026-07-03  
**Status:** Approved (user: execute FE refactor first)

## Goals

1. Environment-based configuration (no hardcoded prod URL/secrets in source)
2. Remove Elstar demo routes and navigation
3. Keep crypto + auth + home as production routes
4. No dependency major upgrade in this phase

## Out of scope (later phases)

- React/Vite major upgrade
- OpenAPI codegen
- Removing `mock/` folder entirely
- Renaming package `elstar` → product name

## Changes

| Area | Action |
|------|--------|
| `app.config.ts` | Read `import.meta.env.VITE_*` |
| `.env.development` | Local defaults (localhost:5272) |
| `.env.example` | Template for prod/staging |
| `main.tsx` | `VITE_GOOGLE_CLIENT_ID` |
| `routes.config.ts` | Remove demo routes |
| `navigation.config` | Remove demo menu |
| `PostButton.tsx` | Fix path `google-auth` (align with AuthService) |

## Verify

- `npm run build` succeeds
- Dev uses `VITE_API_PREFIX` from `.env.development`
