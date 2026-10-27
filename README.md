# SF Project Workspace

Multi-root workspace for the SF backend, current frontend, new trading research UI and shared engineering docs.

## Repositories

```text
D:\Projects\SF\
├── SFBE/        → .NET API and database
├── SFFE/        → Existing React frontend, kept intact
├── SFWebUI/     → New React trading research frontend and rebuilt EBoard UI
└── workspace/   → Shared docs, Cursor rules, scripts and workspace file
```

`SF.code-workspace` includes the repositories above. Open it with **File → Open Workspace from File**.

## Frontend boundary

SFWebUI is the new user-facing application, built with React 19, Tailwind 4, shadcn/ui, Animate UI and TanStack Table. EBoard's layout in SFFE is a reference; SFWebUI recreates the screen with its own design and routes, without linking users to SFFE. SFBE and SFFE remain unchanged; SFWebUI calls existing SFBE API contracts.

## Shared docs

- [Architecture](docs/ARCHITECTURE.md)
- [API map](docs/API-MAP.md)
- [Workflow](docs/WORKFLOW.md)
- [SFWebUI decisions](../SFWebUI/docs/DECISIONS.md)
- [Deploy: nginx + Docker](docs/DEPLOY-NGINX-DOCKER.md)
