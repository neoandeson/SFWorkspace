# SF — Fullstack workspace

Hub docs, Cursor rules, and scripts for the SF BE + FE repos. **Not** application code.

Remote: https://github.com/neoandeson/SFWorkspace

## Clone layout (sibling folders)

```powershell
cd D:\Projects\SF   # or any parent folder
git clone https://github.com/neoandeson/SFBE.git
git clone https://github.com/neoandeson/SFFE.git
git clone https://github.com/neoandeson/SFWorkspace.git workspace
```

Expected tree:

```text
SF/
├── SFBE/        → API (.NET)
├── SFFE/        → Frontend (React/Vite)
└── workspace/   → this repo (docs, rules, SF.code-workspace)
```

`SF.code-workspace` references `../SFBE` and `../SFFE` — keep the three folders side by side with these names (or adjust paths in the workspace file).

## Open in Cursor

**File → Open Workspace from File** → `workspace/SF.code-workspace`

## Local run

```powershell
cd D:\Projects\SF
.\workspace\scripts\dev.ps1
```

Or see [docs/WORKFLOW.md](docs/WORKFLOW.md) (native + Docker).

## Docs

- [ARCHITECTURE](docs/ARCHITECTURE.md)
- [API-MAP](docs/API-MAP.md)
- [WORKFLOW](docs/WORKFLOW.md)
- [DEPLOY nginx + Docker](docs/DEPLOY-NGINX-DOCKER.md) — VPS, CI/CD, EF migrations

## Scope

| In this repo | In SFBE / SFFE |
|--------------|----------------|
| Docs, plans, Cursor rules | Application source |
| `SF.code-workspace`, scripts | Dockerfiles, app config |
