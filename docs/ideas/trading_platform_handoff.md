# Trading Platform — Context Handoff

> Tài liệu bàn giao ngữ cảnh để tiếp tục ở một ChatGPT/Codex session khác. Tổng hợp từ trao đổi đến 26/10/2026. Các lựa chọn công nghệ là **đề xuất**, chưa mặc nhiên được triển khai hoặc kiểm chứng trong repository.

## 1. Bối cảnh hiện tại

- Đang phát triển **Trading Screener Web** bằng **.NET 10 (ASP.NET Core), React + TypeScript, PostgreSQL, Docker, Ubuntu, Nginx**.
- Hosting: **Hostinger VPS KVM2, RAM 8 GB**.
- Screener hiện có polling giá và một số chỉ báo TA; source và tài liệu đã được xây dựng bằng **Cursor + Superpowers**.
- Muốn mở rộng từ screener thành nền tảng **Trading Research / Knowledge Base / Pattern & Case Study / Prediction Evaluation / AI Agent / MCP** cho crypto và chứng khoán Việt Nam.
- Muốn dùng **Codex CLI đăng nhập bằng ChatGPT subscription** để đọc hiểu source/docs, audit security, review code, hiện đại hóa React/TypeScript và redesign giao diện chuyên nghiệp, ít cảm giác “AI-generated”.

## 2. Mục tiêu sản phẩm

1. **Screener**: giá, watchlist, TA, bộ lọc, biểu đồ, market context.
2. **Knowledge Base CRUD**: lưu lý thuyết, bài viết, patterns, trading cases, Markdown, hình ảnh/chart, file đính kèm, tags, nguồn, phiên bản và quan hệ giữa các mục.
3. **Hybrid retrieval**: tìm case theo metadata/SQL, full-text, semantic embedding và (về sau) image similarity; AI giải thích điểm tương đồng/khác biệt.
4. **AI Trading Analysis**: ví dụ “Phân tích BTCUSDT.P M30” gồm TA, FA, DXY, OI/funding, xu hướng đa timeframe, lịch sử tương đồng, kịch bản và điều kiện vô hiệu.
5. **Prediction / Thesis history**: dự đoán do người dùng hoặc agent/persona tạo; lưu snapshot tại thời điểm tạo, theo dõi outcome, pass/fail và thống kê hiệu quả.
6. **MCP Server**: expose các công cụ truy vấn dữ liệu, tìm KB, phân tích indicator, chart, prediction để AI clients sử dụng.
7. **OpenAI SDK**: ứng dụng web gọi model qua API và cho model sử dụng remote MCP khi phù hợp; tách biệt với Codex CLI subscription.

## 3. Quyết định kiến trúc được ưu tiên

**Hybrid, data/evidence-first**, không lấy một RAG framework làm lõi ngay từ đầu.

```text
React + TypeScript Web UI
         |
.NET 10 API (auth, CRUD, application services)
         |
         +-- PostgreSQL (domain data, snapshots, predictions)
         +-- pgvector (embeddings) + PostgreSQL FTS
         +-- Local volume / object storage (images, PDF, chart)
         +-- Market data adapters (crypto, CKVN, macro)
         +-- Analysis services (TA, pattern features, backtest)
         +-- MCP Server (initially read-only tools)
         |
OpenAI Responses API / other MCP-compatible clients
         |
AI reasoning + evidence-based report
```

- Giữ .NET 10/React/PostgreSQL hiện tại, tránh thêm Dify/RAGFlow/LangGraph/Qdrant/MinIO nếu chưa có nhu cầu thực tế.
- **pgvector** và PostgreSQL FTS đủ để thử nghiệm retrieval ở giai đoạn đầu; cân nhắc Qdrant khi tải/tính năng thực sự yêu cầu.
- Có thể dùng **MCP C# SDK** để đồng nhất stack. Python worker chỉ thêm khi cần quantitative analysis/backtest hoặc thư viện chuyên dụng.
- Không chạy LLM lớn trên VPS 8 GB; dùng hosted AI API cho reasoning/embedding ở giai đoạn đầu.
- Chart screenshot và nguồn dữ liệu phải kèm timestamp; tránh để LLM tự bịa giá/indicator.

## 4. Phản biện về RAG và chọn 3 cases

Ý tưởng ban đầu: lấy case matched nhất, sau đó để AI chọn thêm 2 case theo ngữ cảnh (top 2/3 hoặc tốt nhất/tệ nhất). Điều chỉnh được đề xuất:

- Retrieval **không phải reasoning**; vector chỉ là một nguồn tạo candidates.
- Pipeline: `Query parsing -> metadata/SQL + FTS + vector/image candidates -> rank fusion -> rerank bằng rule/cross-encoder/LLM -> chọn evidence đa dạng -> reasoning`.
- **RRF** (Reciprocal Rank Fusion) hợp nhất ranking từ nhiều nguồn; **MMR** (Maximal Marginal Relevance) giúp giảm trùng lặp. Có thể kết hợp constraints theo market regime/timeframe và outcome.
- Ưu tiên 3 **vai trò bằng chứng**, không nhất thiết top 3 similarity:
  1. **Nearest match**: tương đồng nhất với setup hiện tại.
  2. **Confirming case**: bằng chứng độc lập hỗ trợ cùng giả thuyết.
  3. **Counterexample**: case tương tự nhưng outcome trái ngược/thất bại, giúp tìm điều kiện invalidation.
- Không ép đủ 3 khi KB thiếu case; phải báo thiếu bằng chứng. Tránh anchoring bias từ case đầu tiên.
- Tách rõ `match_score`, `evidence_quality` và `calibrated_outcome_probability`. Similarity 95% **không có nghĩa** xác suất thắng 95%.
- Nếu ý tưởng “JEV” thực ra là **JEPA**, đó là hướng representation learning có thể nghiên cứu sau; chưa nên đưa vào MVP khi chưa rõ yêu cầu/benchmark.

## 5. Data model khuyến nghị

- `KnowledgeItem`: Id, Type, Title, MarkdownContent, Tags, Source, Version, timestamps.
- `Attachment`: KnowledgeItemId, Type, StoragePath, Hash, Metadata, chart timestamp.
- `PatternCase`: Symbol, Market, Timeframe, Pattern, structured features, regime, entry/invalidation, outcome.
- `KnowledgeLink`: Supports / Contradicts / DerivedFrom / SimilarTo.
- `MarketSnapshot`: symbol, timestamp, OHLCV/indicator state, DXY, funding/OI, data sources, as-of times.
- `Prediction` hoặc `Thesis`: author/agent, immutable version, snapshot ID, hypothesis, direction, entry/SL/TP, horizon, confidence, criteria.
- `PredictionEvaluation`: status, outcome, MFE/MAE, R-multiple, evaluation rule version, evaluated timestamp.
- `AnalysisRun`: model, prompt version, tools invoked, retrieved case IDs, output, tokens/cost, timestamps.
- `EmbeddingRecord`: source item/version, modality, embedding model/version, vector, indexing status.

**Nguyên tắc:** giữ bản gốc của thesis; ghi sửa đổi dưới dạng version mới. Chốt điều kiện pass/fail trước khi outcome xuất hiện; tránh look-ahead bias và data leakage. Có thể import Markdown + ảnh hiện tại vào hệ thống thay vì bỏ đi.

## 6. Các repository/framework đáng khảo sát

| Nhu cầu | Repo / URL | Ghi chú |
|---|---|---|
| Vector trong PostgreSQL | https://github.com/pgvector/pgvector | Ưu tiên MVP |
| .NET pgvector | https://github.com/pgvector/pgvector-dotnet | EF Core integration |
| MCP C# | https://github.com/modelcontextprotocol/csharp-sdk | Ưu tiên nếu triển khai .NET |
| MCP Python | https://github.com/modelcontextprotocol/python-sdk | Tùy chọn Python services |
| RAG framework | https://github.com/infiniflow/ragflow | Chỉ benchmark ingestion/retrieval nếu cần |
| AI workflow | https://github.com/langgenius/dify | Không cần làm core ngay |
| Vector DB riêng | https://github.com/qdrant/qdrant | Phương án scale/feature sau |
| Stateful agent | https://github.com/langchain-ai/langgraph | Chỉ khi workflow phức tạp |
| Quant backtest | https://github.com/polakowo/vectorbt | Nghiên cứu compatibility/licensing |
| .NET orchestration | https://github.com/microsoft/semantic-kernel | Tùy chọn |

TCBS MCP / Binance MCP được nhắc tới như **ứng viên data adapter**, chưa xác minh mức độ chính thức, API coverage, licensing hay reliability. Nên thiết kế adapter độc lập và kiểm tra trước khi tích hợp.

## 7. Dashboard UI — shortlist đã thảo luận

1. **Vault — Investment Dashboard**: https://dashboardpack.com/templates/ — nhiều bố cục tài chính; cần kiểm tra demo/license/source.
2. **Fortress — Trading Desk**: https://dashboardpack.com/templates/ — hướng terminal nhiều dữ liệu; cần kiểm tra tính sẵn có.
3. **CryptoTraderPro**: https://github.com/Gzeu/CryptoTraderPro — tham khảo crypto/realtime; đánh giá code/license trước khi dùng.
4. **TailAdmin React**: https://github.com/TailAdmin/free-react-tailwind-admin-dashboard — ưu tiên nếu cần nền React dễ tích hợp.
5. **Mosaic / Cruip**: https://cruip.com/ — tham khảo analytics/fintech UI.

Đây là **shortlist theo mức độ phù hợp**, không phải xếp hạng khách quan/benchmark. Cần xác minh các template và phiên bản React mới nhất trước khi chọn.

**Hướng thiết kế:** khoảng 70% modern fintech + 30% trading terminal; dark-first; dữ liệu compact; bảng số tabular, căn phải; chart ưu tiên không gian; giảm gradient/neon/card trang trí; design tokens nhất quán; responsive; table virtualization và realtime state performance.

**Đề xuất:** trước tiên dùng Codex tạo **một Screener screen proof-of-concept**, so sánh với template. Không redesign cả app ngay hoặc thay framework chỉ vì UI mẫu.

## 8. Codex CLI, subscription và skills

- **Codex CLI** có thể mở local repository, đọc source/docs, review, chỉnh sửa và chạy tests tùy quyền cấp. Đăng nhập bằng ChatGPT subscription được hỗ trợ theo hạn mức sản phẩm; **OpenAI API usage tính riêng**.
- Codex **không tự có lịch sử chat Cursor**: chuyển quyết định quan trọng vào `docs/` và `AGENTS.md`.
- Cần chạy trên user thường, không root; bảo vệ secrets; trên production ưu tiên read-only audit, xác nhận trước khi thay đổi.
- Gợi ý cài Windows (kiểm tra Node/npm):

```powershell
npm install -g @openai/codex
codex login
codex login status
cd C:\Projects\TradingPlatform
codex
```

- Skill cộng đồng **Taste Skill**: https://github.com/Leonxlnx/taste-skill — cân nhắc `npx skills add Leonxlnx/taste-skill -a codex` **sau khi kiểm tra repo, SKILL.md, scripts, quyền và tương thích hiện tại**.
- Kết hợp skill theo vai trò: một visual design skill (Taste), một React/TypeScript performance/best-practices skill, một browser/Playwright QA skill. Tránh nhiều skill visual có chỉ dẫn xung đột.
- Tạo **custom trading-terminal-design skill** quy định mật độ dữ liệu, số liệu, chart, watchlist, trạng thái loading/empty/error, dark mode, tránh UI generic.
- `AGENTS.md` root: đọc docs trước khi sửa, bảo toàn API/business logic, audit-only trước, không cài dependency/nâng React khi chưa duyệt, screenshot + lint/typecheck/tests sau thay đổi.

## 9. Prompt đầu tiên cho Codex (audit-only)

```text
Act as a Principal React Engineer and Senior Fintech Product Designer.

This is an existing Trading Screener application built with React, TypeScript,
.NET 10 and PostgreSQL. It was developed using Cursor and Superpowers.

PHASE 1: AUDIT ONLY. DO NOT MODIFY CODE.

1. Read the repository, docs, architecture decisions, and existing agent instructions.
2. Identify React version, UI libraries, routing, state management, component architecture,
   API contracts and performance-sensitive screener/chart flows.
3. Audit UI/UX for generic AI-generated styling, accessibility, information density,
   responsiveness and consistency.
4. If installed, use Taste Skill for visual evaluation and React best-practice skills
   for technical evaluation. Do not assume a skill exists without checking.
5. Propose 2–3 distinct design directions inspired by professional trading terminals
   and modern fintech products, with explicit trade-offs.
6. Recommend whether to retain or upgrade React/TypeScript and dependencies;
   distinguish confirmed facts from assumptions.
7. Plan an incremental redesign of ONE Screener screen first.
8. Preserve existing backend APIs, market calculations, polling, and functionality.
9. Do not install packages, change files, overwrite Cursor/Superpowers instructions,
   or refactor the app without approval.

Deliver: architecture audit, UI/UX audit, proposed design tokens/components,
React modernization risks, and a scoped Screener proof-of-concept plan.
Stop and request approval before implementation.
```

## 10. Kế hoạch thực hiện theo pha

1. **Audit repository**: source/docs, React/TS dependencies, design system, performance, security.
2. **UI POC**: redesign một Screener page; screenshot/browser QA, giữ API/logic; quyết định mua template hay custom.
3. **Knowledge CRUD**: types, tags, attachments, versioning, import `.md`/images.
4. **Patterns & Prediction**: structured case, market snapshot, immutable thesis, evaluation worker.
5. **Hybrid search**: FTS + pgvector + metadata filtering, RRF, rerank, MMR, 3-role evidence.
6. **Read-only MCP**: get_ohlcv, calculate_indicators, get_market_context, search_knowledge, search_similar_patterns, get_prediction_history, capture_chart (nếu có).
7. **AI integration**: OpenAI SDK / Responses API, logging `AnalysisRun`, tool permissions, evidence-backed answers.
8. **Evaluation**: historical outcomes, walk-forward tests, calibration, agent/persona comparisons; không tự động đưa mọi AI output vào KB như sự thật.

## 11. Những điều cần xác minh trong session kế tiếp

- Cấu trúc repo thật, package.json, React version, UI library, chart library, docs hiện có.
- VPS thực tế đang dùng bao nhiêu RAM/CPU, database và Docker layout; backup/rollback.
- Template URLs/demo/license và skill installation commands còn phù hợp hay không.
- Quyền truy cập Codex và cách đăng nhập trên Windows/VPS tại thời điểm cài.
- Market data licensing, Binance/TCBS MCP availability, DXY data sources.
- Định nghĩa outcome/TP/SL và điều kiện pass/fail, tránh hindsight bias.

## 12. Câu mở đầu cho session mới

> Đây là tài liệu handoff cho dự án Trading Platform. Hãy đọc toàn bộ, xem các lựa chọn là đề xuất chưa triển khai. Tôi đang dùng Cursor + Superpowers và muốn tích hợp Codex CLI/Taste Skill để audit và redesign từng phần React/TypeScript, trước hết là màn hình Screener. Hãy bắt đầu bằng việc hỏi/kiểm tra cấu trúc repository và docs hiện tại; không tự thay đổi code khi chưa có phê duyệt.
