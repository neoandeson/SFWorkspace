# SFFE Finance Portfolio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the SFFE Finance Portfolio screen as a clear, responsive light finance workspace while preserving current API and valuation behavior.

**Architecture:** Keep the existing React/Vite/Tailwind/Redux/Elstar stack. Rework the Finance Portfolio page and its scoped styles, keep calls through `FinanceService`, and make the chart display one selected currency series at a time. Change only shared theme/shell defaults needed for the approved light direction; preserve route paths and service contracts.

**Tech Stack:** React 18, TypeScript, Vite 5, Tailwind 3, ApexCharts, Vitest, Testing Library, Taste app-screen inspector.

**Spec:** `D:/Projects/SF/workspace/docs/superpowers/specs/2026-10-23-sffe-finance-redesign-design.md`

## Global Constraints

- Keep current route paths, FinanceService request payloads, API semantics, and mark-on-Portfolio-mount behavior.
- Use only real Finance API data; do not add budgets, bills, investment returns, or other unsupported metrics.
- Keep USD and VND totals separate and switch the chart between one series at a time.
- Keep the React 18, Vite, Tailwind, Redux, and Elstar stack.
- Support 1440px, 768px, and 390px viewports; prevent page-level horizontal overflow at 390px.
- Do not modify SFBE, SFUI, or SFWeb; do not commit or push.

## Review Focus

- Portfolio mark succeeds while history or settings fails; retain and show available data with an explicit partial error.
- Empty positions and empty history; show truthful, useful empty states without invented values.
- VND and USD values are not combined or shown on incomparable chart axes.
- Invalid or failed USD/VND rate save; preserve the current rate and provide clear feedback.
- A long account or instrument label at 390px; keep identity and value readable without page overflow.

---

### Task 1: Add focused Finance Portfolio component tests

**Files:**
- Modify: `SFFE/package.json`
- Modify: `SFFE/package-lock.json`
- Create: `SFFE/vitest.config.ts`
- Create: `SFFE/src/views/finance/Portfolio/Portfolio.test.tsx`

**Interfaces:**
- Consumes: current Portfolio component and FinanceService exports.
- Produces: a deterministic test setup that can render Portfolio with mocked FinanceService calls and assert screen behavior.

- [ ] **Step 1: Add the test runner and DOM test dependencies**

Add Vitest, jsdom, and `@testing-library/react` as development dependencies, with a `test` script running `vitest run`. Configure Vitest to use the existing `@` source alias and jsdom. Do not change existing build or lint scripts.

- [ ] **Step 2: Write the failing Portfolio interaction tests**

Add named tests asserting that the page requests a mark, a 90-day history and settings on mount; renders a VND total; selecting USD switches the chart to only USD history; a failed history request leaves the loaded mark visible and shows an explicit history error; and empty positions show a finance-specific empty state.

Mock the chart wrapper and UI notifications where needed, but do not mock the Portfolio state transitions under test.

- [ ] **Step 3: Run the tests and confirm the expected failures**

Run: `npm test -- --reporter=verbose`
Expected: tests fail because the current screen has no currency selector and does not preserve partial results or expose explicit history state.

---

### Task 2: Rebuild the Finance Portfolio page and scoped styles

**Files:**
- Modify: `SFFE/src/views/finance/Portfolio/Portfolio.tsx`
- Create: `SFFE/src/views/finance/Portfolio/Portfolio.css`
- Modify: `SFFE/src/views/finance/Portfolio/Portfolio.test.tsx`

**Interfaces:**
- Consumes: `PortfolioMark`, `PortfolioPosition`, `PortfolioHistoryPoint` and the existing FinanceService functions.
- Produces: a responsive Finance Portfolio page with a selected-currency control, one matching history series, explicit per-request loading/error state, rate editing, refresh action, and a compact positions table.

- [ ] **Step 1: Add focused state tests for partial loading, history selection, and rate errors**

Ensure tests cover independent mark/history/settings request outcomes, USD/VND series switching, invalid rate input, save failure, loading state, and empty data. Keep request payload assertions aligned with the existing service signatures.

- [ ] **Step 2: Run tests and confirm the focused assertions fail**

Run: `npm test -- --reporter=verbose`
Expected: FAIL on missing independent states, selector behavior, and responsive content semantics.

- [ ] **Step 3: Implement the new Portfolio hierarchy and state handling**

In `Portfolio.tsx`, preserve the mark call on mount and the existing 90-day history range. Load mark, history and settings independently so one failure does not discard successful responses. Add accessible VND/USD tabs that update the headline total and chart to the selected currency. Keep the chart on a single series, with straight line, restrained blue data hue, faint grid, date tooltip, and no legend. Show valuation timestamp only if the current response actually provides one; otherwise label the valuation as refreshed on opening or by the explicit refresh action without inventing a timestamp.

Use Vietnamese finance labels consistent with `FINANCE-TERMINOLOGY.md`. Keep the FX save and re-mark behavior. Add a manual refresh action. Use a compact five-field positions table: account/instrument identity, quantity, unit price, native currency/value, and selected-currency value. Preserve underlying values and do not imply return or profit.

Use `Portfolio.css` for page-specific rules only. Keep the light Open Plane shell, #f8f8f8 ground, white surfaces, neutral ink, restrained `#1d5fbf` chart hue, Geist with loaded Inter fallback if Geist is unavailable, tabular numerals, thin rules, and no resting shadows. At widths below 640px convert table rows to two-line records or contain horizontal scrolling inside the table frame; keep the page itself from scrolling sideways.

- [ ] **Step 4: Run focused tests and confirm they pass**

Run: `npm test -- --reporter=verbose`
Expected: all Finance Portfolio tests pass, including partial API failures and currency switching.

- [ ] **Step 5: Run lint and production build**

Run: `npm run lint`
Expected: ESLint exits 0.

Run: `npm run build`
Expected: Vite builds the production bundle successfully.

---

### Task 3: Apply the approved light shared shell and navigation label

**Files:**
- Modify: `SFFE/src/configs/theme.config.ts`
- Modify: `SFFE/src/configs/navigation.config/index.ts`

**Interfaces:**
- Consumes: existing Modern layout, navigation tree and route paths.
- Produces: light neutral default shell and a Finance Portfolio navigation label that matches the page purpose without changing route identity.

- [ ] **Step 1: Apply the light neutral theme defaults**

Set the default mode to light and use a restrained neutral primary theme compatible with the Open Plane finance styling. Preserve layout type, route keys, and all navigation paths. Rename only the Finance Portfolio title from the ambiguous `Thống kê` to `Danh mục` (or `Portfolio` if that better matches the existing locale convention discovered during implementation).

- [ ] **Step 2: Run lint and build**

Run: `npm run lint && npm run build`
Expected: both complete successfully; no route or TypeScript errors.

---

### Task 4: Verify the pilot in browser at target widths

**Files:**
- Create/update: `SFFE/.taste-skill/finance-redesign/before/` screenshots and inspector report, if baseline capture is available.
- Create: `SFFE/.taste-skill/finance-redesign/after/` screenshots and inspector report.

**Interfaces:**
- Consumes: Finance Portfolio route, development server and a reachable authenticated finance API or deterministic local mock session.
- Produces: screenshots and concise visual/interactions QA notes for 1440px, 768px and 390px.

- [ ] **Step 1: Capture the current route as the before state**

Use `node .agents/skills/design-taste-frontend/scripts/inspect.mjs <portfolio-url> --app --widths 1440,768,390 --out .taste-skill/finance-redesign/before` when the route can be opened. If authentication or backend availability blocks capture, record that constraint and use the available browser control to inspect the authenticated app if already open.

- [ ] **Step 2: Capture and inspect the redesigned route**

Use `node .agents/skills/design-taste-frontend/scripts/inspect.mjs <portfolio-url> --app --widths 1440,768,390 --out .taste-skill/finance-redesign/after`. Compare the layout to the approved direction. Fix any page overflow, clipped money values, inaccessible control, misleading chart state, or generated-dashboard tell found in the screenshots.

- [ ] **Step 3: Verify primary interactions in the browser**

Check currency selection, history tooltip, manual refresh, USD/VND save validation, and navigation to Finance Portfolio. Verify an empty or failed-history state if the existing dev environment can reproduce it without changing backend data.

- [ ] **Step 4: Run the complete available verification set**

Run: `npm test -- --reporter=verbose`
Run: `npm run lint`
Run: `npm run build`
Expected: all commands exit 0. Report any browser/API limitation separately from test results.

---

## Self-review

- **Spec coverage:** Product question, selected currency, 90-day history, positions, rate actions, honest loading/empty/error states, responsive widths, accessible controls, and shared light shell are covered by Tasks 1–4.
- **Stack and API:** No framework, route, service signature, payload, or SFBE change is planned.
- **Type consistency:** Tests mock the existing FinanceService response types; implementation consumes those types without changing them.
- **Review focus:** Partial requests, empty data, currency units, FX save, and long mobile labels are assigned to component tests or browser review.
- **Proportion:** The plan is limited to the Finance pilot and shared shell changes needed by that pilot.
