# Finance module — terminology

Canonical terms for SF personal finance (Accounts, Ladder, later stats).  
Excel personal labels are mapped here so UI/API/docs stay consistent and professional.

## Account tổng (Phase B)

| Concept | Code / API (EN) | UI (VI) | Avoid |
|---------|-----------------|---------|--------|
| Account name | `Name` | Tên tài khoản | — |
| Asset type | `Type` (`Cash`, `TermSaving`, …) | Loại | — |
| Linked screener row | `InstrumentId` | Instrument | — |
| Native currency | `Currency` | Tiền tệ | — |
| Balance / quantity | `Balance` | Số dư (cash) / **Số lượng** (khi có Instrument) | — |
| FX to VND (manual / derived) | `FxRateToVnd` | Tỷ giá → VND | — |
| Value in VND | `ValueVnd` | Giá trị (VND) | — |
| Portfolio sum (non-archived) | `TotalVnd` | **Tổng** (VND) | — |

## Portfolio mark-to-market (Feature 3)

| Concept | Code / API (EN) | UI (VI) | Notes |
|---------|-----------------|---------|--------|
| Global USD→VND rate | `UsdVndRate` (`Finance.UsdVndRate`) | Tỷ giá USD→VND | Setting CRUD |
| Unit price from screener | `UnitPrice` | Giá | `Instrument.Price` at mark |
| Quote currency | `QuoteCurrency` | `USD` / `VND` | CK VN → VND; crypto/khác → USD |
| Native value | `ValueNative` | Giá trị (native) | `Balance × UnitPrice` when linked |
| Portfolio total USD | `TotalUsd` | **Tổng (USD)** | Format `$` + `en-US` |
| Portfolio total VND | `TotalVnd` | **Tổng (VND)** | `TotalUsd × UsdVndRate`; format `đ` + `vi-VN` |

Mark runs when user opens Portfolio — not on every Instrument patch.

## Ladder / term deposit (next phases)

| Excel (legacy) | Meaning | Code / API (EN) | UI (VI) | Avoid |
|----------------|---------|-----------------|---------|--------|
| Số dư đầu kỳ | Principal deposited | `Principal` | **Gốc** | “net” alone in UI |
| Total net | Sum of principals | `TotalPrincipal` | **Tổng gốc** | — |
| lãi suất | Annual interest rate % | `AnnualRatePercent` | **Lãi suất** (%/năm) | — |
| lãi dự tính | Expected interest for term | `ExpectedInterest` | **Lãi dự tính** | Margin |
| số tháng | Term length | `TermMonths` | **Kỳ hạn** (tháng) | — |
| Datetime gửi | Deposit / start date | `StartDate` | **Ngày gửi** | — |
| Datetime nhận | Maturity date | `MaturityDate` | **Ngày đáo hạn** | — |
| Số dư cuối kỳ ls | Principal + interest at maturity | `MaturityAmount` | **Số dư đáo hạn** | — |
| Total ls | Sum of maturity amounts | `TotalMaturityAmount` | **Tổng đáo hạn** | Total ls |
| **Margin** | Interest earned | `TotalInterest` | **Tổng lãi** | **Margin** |
| **%Margin** | Interest ÷ principal | `YieldPercent` | **Tỷ suất lãi** (%) | **%Margin** |

### Formulas (simple interest by term — ladder design)

- `ExpectedInterest = Principal × (AnnualRatePercent / 100) × (TermMonths / 12)`
- `MaturityAmount = Principal + ExpectedInterest`
- `TotalExpectedInterest` (UI: Tổng lãi dự tính) = sum of `ExpectedInterest` for the filtered set (usually Open)
- `TotalInterest` may equal `TotalExpectedInterest` for Open ladders; realized interest after close can be refined later
- `YieldPercent = TotalExpectedInterest / TotalPrincipal × 100` (0 if principal is 0)

Legacy Excel often used `Principal × rate` for ~12-month rows only; SF uses the pro-rata formula above.

## Why not “margin”?

In trading/banking English, **margin** usually means collateral or business profit margin — not deposit interest.  
For term savings, use **interest** / **lãi** and **yield** / **tỷ suất lãi**.

## Enforcement

- New Finance specs, plans, API field names, and FE copy must use the **Code/API** and **UI (VI)** columns above.
- Mentions of Excel “Margin” in historical notes must map to `TotalInterest` / **Tổng lãi**.
