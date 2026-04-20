# Prisma multi-database migration starter

Minimal, production-sensible pattern for **schema migrations as code**: one Prisma schema and one linear migration history in Git, applied explicitly to a **root** Postgres and **two independent child** Postgres endpoints via GitHub Actions—without relying on database branch merge, reset, or parent-to-child schema propagation.

## Operating model

| Concept | Meaning |
|--------|---------|
| **Single source of truth** | `prisma/schema.prisma` + `prisma/migrations/*` in this repository |
| **Replay, not merge** | Each database runs `prisma migrate deploy`, which applies any pending migrations from `_prisma_migrations`. Same files, same order, different `DATABASE_URL`. |
| **Root first** | CI applies migrations to the root database first. Child jobs run only after the root job succeeds. |
| **Children in parallel** | After root succeeds, child 1 and child 2 deploy in parallel (both still depend on root). |

This is **DDL delivery**: it evolves tables, indexes, and constraints. It does **not** replicate **data** between root and children. Application data in each database remains independent unless you add separate data pipelines.

## Why migration replay instead of DB branch propagation?

Managed Postgres “branch” products often copy storage snapshots or use replication semantics that conflate **storage forks** with **schema evolution**. For application teams, that can create ambiguity about which environment owns which schema version.

Replaying the **same migration SQL** from Git onto each endpoint makes the contract explicit: every target is brought to the same schema revision by running the same versioned steps. You avoid assuming that a child branch “inherits” parent DDL automatically or that merging branches merges schema safely without conflicts.

## Repository layout

```text
.
├── .env.example
├── .github/
│   └── workflows/
│       ├── deploy-migrations.yml   # migrate deploy: root → children
│       └── pr-validate.yml         # validate + format check (no DB)
├── package.json
├── prisma/
│   ├── schema.prisma
│   └── migrations/
│       ├── migration_lock.toml
│       ├── 20250420120000_init_user_project/
│       │   └── migration.sql
│       └── 20250420120100_add_schema_migration_audit/
│           └── migration.sql
└── README.md
```

## Local setup

1. **Install Node.js 20+** and a local Postgres (Docker or otherwise).

2. **Copy environment template** and set `DATABASE_URL` to your dev database:

   ```bash
   cp .env.example .env
   # Edit .env with a real connection string.
   ```

3. **Install and generate the client**:

   ```bash
   npm install
   npm run db:generate
   ```

   After the first install, consider committing `package-lock.json` and switching GitHub Actions to `npm ci` for reproducible CI installs.

4. **First-time DB** (if empty): either apply committed migrations:

   ```bash
   npm run db:migrate:deploy
   ```

   Or use interactive dev flow (creates new migration folders — use only when authoring):

   ```bash
   npm run db:migrate:dev
   ```

## Adding a new migration

1. Edit `prisma/schema.prisma` with the desired model or field changes.

2. Create a migration (local dev, against a scratch database):

   ```bash
   npx prisma migrate dev --name describe_your_change
   ```

3. Commit `prisma/schema.prisma` and the new folder under `prisma/migrations/`.

4. Open a PR; **PR — validate Prisma** checks schema and formatting.

5. Merge to `main`; **Deploy — Prisma migrations** runs `prisma migrate deploy` on root, then on each child.

In CI, always use **`migrate deploy`**, not `migrate dev`, so runs are non-interactive and idempotent per database.

## GitHub Actions

| Workflow | Trigger | Behavior |
|----------|---------|----------|
| `pr-validate.yml` | Pull requests to `main` | `prisma validate`, `prisma format --check`, `prisma generate` (no DB credentials required). |
| `deploy-migrations.yml` | Push to `main` or manual `workflow_dispatch` | Sets `DATABASE_URL` from secrets and runs `prisma migrate deploy` per job. |

### Required secrets

Configure in **Settings → Secrets and variables → Actions** (names must match the workflow):

| Secret | Used by |
|--------|---------|
| `DATABASE_URL_ROOT` | Root Postgres connection string |
| `DATABASE_URL_CHILD_1` | First child Postgres connection string |
| `DATABASE_URL_CHILD_2` | Second child Postgres connection string |

Optional: the deploy jobs use `environment: production` so you can gate secrets and approvals in GitHub Environments.

### Connection string notes

Use standard Postgres URLs, for example:

`postgresql://USER:PASSWORD@HOST.example.com:5432/dbname?schema=public&sslmode=require`

Each secret can point to a different host, database name, or account—as long as Prisma can reach Postgres and the role has rights to run DDL from your migrations.

## Limits of this pattern

- **No automatic data sync**: Row-level replication, ETL, or backfills are out of scope; only schema migrations in `prisma/migrations` are applied.
- **Drift and permissions**: If someone applies DDL outside Prisma, `_prisma_migrations` can diverge; fix operationally (restore discipline or repair). The DB user must be allowed to run your migration SQL.
- **Ordering across services**: If application code requires a two-phase rollout (code first vs migrations first), coordinate releases; this repo only demonstrates schema delivery.
- **One migration history**: All three databases share the same migration folder; they are not independent version lines.

## Scripts reference

| Script | Purpose |
|--------|---------|
| `npm run db:validate` | Validate `schema.prisma` |
| `npm run db:format:check` | Ensure formatting matches Prisma defaults |
| `npm run db:generate` | Generate `@prisma/client` |
| `npm run db:migrate:deploy` | Apply pending migrations (uses `DATABASE_URL`) |
| `npm run db:migrate:dev` | Interactive dev migrations (local authoring) |
