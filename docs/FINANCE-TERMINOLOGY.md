# Finance module — terminology

Canonical terms for SF personal finance (Accounts, Ladder, later stats).  
Excel personal labels are mapped here so UI/API/docs stay consistent and professional.

## Account tổng (Phase B)

| Concept | Code / API (EN) | UI (VI) | Avoid |
|---------|-----------------|---------|--------|
| Account name | `Name` | Tên tài khoản | — |
| Asset type | `Type` (`Cash`, `TermSaving`, …) | Loại | — |
| Native currency | `Currency` | Tiền tệ | — |
| Balance in native currency | `Balance` | Số dư | — |
| FX to VND | `FxRateToVnd` | Tỷ giá → VND | — |
| Value in VND | `ValueVnd` | Giá trị (VND) | — |
| Portfolio sum (non-archived) | `TotalVnd` | **Tổng** | — |

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

### Formulas (simple interest, as in Excel)

- `ExpectedInterest = Principal × (AnnualRatePercent / 100) × (TermMonths / 12)`  
  *(If Excel used `Principal × rate` for a full 12-month term only, document that variant explicitly in the ladder spec when rates are confirmed.)*
- `MaturityAmount = Principal + ExpectedInterest`
- `TotalInterest = TotalMaturityAmount − TotalPrincipal`
- `YieldPercent = TotalInterest / TotalPrincipal × 100` (0 if principal is 0)

## Why not “margin”?

In trading/banking English, **margin** usually means collateral or business profit margin — not deposit interest.  
For term savings, use **interest** / **lãi** and **yield** / **tỷ suất lãi**.

## Enforcement

- New Finance specs, plans, API field names, and FE copy must use the **Code/API** and **UI (VI)** columns above.
- Mentions of Excel “Margin” in historical notes must map to `TotalInterest` / **Tổng lãi**.
