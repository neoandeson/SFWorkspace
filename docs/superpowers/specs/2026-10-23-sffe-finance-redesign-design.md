# SFFE Finance Redesign — Design Brief

**Date:** 2026-10-23
**Status:** Draft for review
**Pilot:** Finance Portfolio
**Visual direction:** Taste `achromatic-ledger` / Open Plane, light theme

## Context

SFFE is the active frontend for SFBE. The current UI is built on React 18, Vite, TypeScript, Tailwind, Redux, and the Elstar template. Its dark-indigo template styling and generic dashboard patterns make the finance experience feel like a stock admin template rather than a focused personal finance workspace.

The user wants SFFE redesigned for finance, securities, and crypto with a professional, current visual language that does not look machine-generated. SFBE remains the source of truth for existing finance data and behavior. SFUI and SFWeb are legacy projects and are outside this work.

## Product question for the pilot

**“Tổng tài sản theo giá mới nhất là bao nhiêu, và giá trị đó đã thay đổi thế nào trong 90 ngày?”**

The portfolio page should answer this quickly, then let the user inspect the assets behind the total.

## Chosen sequence

1. Redesign the shared SFFE shell and Finance Portfolio as the pilot, keeping scope limited to changes required to make this page coherent.
2. Apply the validated visual system to Finance Accounts and Ladder.
3. Extend it to EBoard and Crypto after reviewing those workflows and their data separately.

Two alternatives were considered:

- **EBoard/Crypto first:** useful if market monitoring is the primary daily workflow, but it does not validate the finance account and valuation model already documented in SFBE.
- **Rewrite every SFFE screen at once:** creates a large review surface and mixes workflows with different data and interaction needs.

Finance-first was selected. The later phases are not part of this pilot.

## Design direction

The Taste project-local skill generated a light `achromatic-ledger` direction in `SFFE/.taste-skill/finance-redesign/direction.json` (seed `735355706`). Its first overview suggestion assumed budgets, recent spending, and bills, which are not supported by the current SFBE finance API. That pattern was discarded. The overview was redrawn as `kpi-tabs-chart`, which maps to the actual portfolio totals and 90-day history.

The visual system should use:

- An airy, light shell with warm-neutral page ground, white surfaces, dark neutral text, and restrained separators.
- Geist or the closest already available sans-serif; no decorative display type.
- A single restrained blue data accent (`#1d5fbf`) for selected series and actions. Positive/negative movement must not be implied unless the API provides a valid comparison.
- Tabular numerals and right-aligned money values. Keep color usage sparse and avoid gradients, glowing panels, ornamental cards, and default template shadows.
- A compact page heading, clear section labels, and consistent spacing. Keep the existing SF identity asset if it works on the light shell; do not create new branding as part of the pilot.

The page should feel like an instrument for reading a personal balance sheet: quiet structure, precise amounts, visible dates and units, and little decoration.

## Finance Portfolio page

### Information hierarchy

1. Page title and valuation timestamp/status.
2. Total portfolio value in the currently selected display currency, with an explicit VND/USD switch or equivalent clear currency control.
3. A compact KPI selector for VND and USD values that switches the chart series. Do not present the two currencies as separate assets or add them together.
4. A 90-day line chart with a clear date axis and tooltip values. Keep the chart focused on the selected currency rather than plotting VND and USD together on incomparable scales.
5. A positions table showing the assets that compose the current total.

The table should prioritize instrument/name, quantity, latest price, value, and currency. If the current API provides additional useful fields, expose them without turning the table into a dense nine-column spreadsheet. On narrow screens, allow horizontal scrolling or a deliberate stacked row layout; do not silently omit the asset identity or value.

### Behavior and data integrity

- Continue using existing Finance services and API contracts. No backend or endpoint changes are in scope.
- Preserve the current valuation behavior: the portfolio is marked on opening the Portfolio page; do not mark every instrument during unrelated edits.
- Preserve current account, position, exchange-rate, and history semantics. Make loading, empty, stale, and error states explicit.
- Show the valuation/history date so users can distinguish latest marks from older snapshots.
- Do not call historical change “investment return” or infer profit/loss. Deposits, withdrawals, and other flows can change portfolio value, so a return metric requires a supported flow-adjusted calculation.
- Do not add budget, bill, spending, or performance metrics without corresponding API data and agreed definitions.
- Keep values and conversions internally consistent with the current API response. A chart tooltip and table row must use the same currency and formatting rules as their selected display state.

### Controls

Retain the existing currency/FX editing and refresh actions where they are currently supported. Present them as clear, secondary controls, with labels and feedback for save/refresh success or failure. Do not change field names, routes, or request payloads as a styling shortcut.

## Shared shell

For the pilot, adjust only shared shell elements that directly affect the Finance experience: page background, content width, typography, navigation contrast, active item state, and spacing. Keep current route paths and navigation destinations. Finance navigation labels may be clarified in Vietnamese if that does not change route identity or confuse existing users. Defer broad navigation regrouping until the remaining finance and market screens are reviewed together.

## Responsive behavior

Review at 1440px, 768px, and 390px widths:

- Desktop: maintain a readable content measure and let the positions table use available width.
- Tablet: retain the headline totals and chart hierarchy; allow table overflow when needed.
- Mobile: stack heading, currency control, chart, and rows; keep the current value and asset identity easy to scan; prevent page-level horizontal overflow.

## Accessibility and states

Use semantic headings, labeled controls, keyboard-accessible tabs/actions, visible focus, and sufficient contrast. Do not rely on color alone to communicate selected currency or movement. Provide intentional loading skeletons, a useful empty state when no positions exist, and a recoverable error state for failed history or valuation requests.

## Scope boundaries

Included in this pilot:

- Finance Portfolio UI and the minimum shared-shell styling needed for it.
- Reuse of existing SFFE components and services where they fit the design.
- Small component-level adjustments required for responsive layout and accessible controls.

Excluded:

- SFBE API, database, valuation rules, or data migrations.
- SFUI and SFWeb legacy projects.
- Finance Accounts and Ladder redesign beyond avoiding regressions from shared-shell changes.
- EBoard and Crypto redesign.
- Trading, order entry, budgeting, bill tracking, or new return calculations.
- A framework migration or a full SFFE rewrite.

## Validation approach

Before implementation, inspect the current SFFE scripts and available browser tooling. Prefer the repo’s existing test setup. For the pilot, validate:

- Finance Portfolio route loads and existing valuation/history/settings requests remain wired.
- Currency selector updates the displayed series and values consistently.
- Loading, empty, and failed-request states render clearly.
- FX edit/refresh controls remain usable if present on this route.
- Desktop, tablet, and mobile layouts at 1440px, 768px, and 390px; no page-level horizontal overflow at mobile width.
- Visual review against the Taste direction, with screenshots for the three widths.

Playwright is a suitable option if already available or if adding it is agreed after inspecting the current setup. Computer control can supplement visual review, but should not replace repeatable route and interaction checks.

## Acceptance criteria

- The Finance Portfolio page answers the product question above without unsupported metrics.
- A user can understand the total, its currency, the history period, and the positions composing it.
- Currency selection, history, FX actions, and valuation behavior preserve existing API semantics.
- Loading, empty, error, and stale-data states are understandable.
- The shared shell and page form a cohesive light finance experience at the three target widths.
- Existing SFFE routes and non-pilot workflows continue to work.

## Review gate

This is a design proposal, not implementation approval. After the user reviews this brief, the next step is to write an implementation plan and then make the pilot changes in SFFE. No code has been changed as part of this brief.
