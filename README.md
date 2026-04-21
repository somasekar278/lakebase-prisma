# Prisma multi-database migration starter

Minimal pattern for **schema migrations as code**: one Prisma schema and one linear migration history in Git. Apply migrations **locally** (`npm run db:migrate:deploy` or `./scripts/migrate-all-local.sh`) against a **primary** Postgres and optionally **two child** endpoints—same migration files, different connection strings—without relying on DB branch merge for DDL.

(This repo intentionally does **not** run `migrate deploy` from GitHub Actions: hosted runners are often blocked by workspace IP ACL when targeting Lakebase.)

## Operating model

| Concept | Meaning |
|--------|---------|
| **Single source of truth** | `prisma/schema.prisma` + `prisma/migrations/*` in this repository |
| **Replay, not merge** | Each database runs `prisma migrate deploy`, which applies any pending migrations from `_prisma_migrations`. Same files, same order, different `DATABASE_URL`. |
| **Root first (multi-DB)** | When using `scripts/migrate-all-local.sh`, the root URL runs first, then child 1 and child 2—mirrors the order you’d use operationally. |

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
│       └── pr-validate.yml         # optional: validate + format check (no DB)
├── scripts/
│   └── migrate-all-local.sh        # root → child 1 → child 2 (URLs in .env)
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

   After the first install, commit `package-lock.json` if you use GitHub PR validation (`npm ci`).

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
   npm run db:migrate:dev -- --name describe_your_change
   ```

3. Commit `prisma/schema.prisma` and the new folder under `prisma/migrations/`.

4. Optional: open a PR; **PR — validate Prisma** checks schema and formatting (no database).

5. Apply migrations **from your machine** (or any host that can reach Lakebase):

   ```bash
   npm run db:migrate:deploy
   ```

   For **root + two children** in one shot, add these to **`.env`** (see `.env.example`): `DATABASE_URL_ROOT`, `DATABASE_URL_CHILD_1`, `DATABASE_URL_CHILD_2` — same migration SQL, different host per Lakebase branch. Then:

   ```bash
   chmod +x scripts/migrate-all-local.sh
   ./scripts/migrate-all-local.sh
   ```

   The script loads `.env` automatically and runs `migrate deploy` three times (Prisma itself only ever sees one `DATABASE_URL` at a time).

Always use **`migrate deploy`** for applying committed migrations (non-interactive, idempotent). Use **`migrate dev`** only when authoring new migrations locally.

## GitHub Actions (optional)

| Workflow | Trigger | Behavior |
|----------|---------|----------|
| `pr-validate.yml` | Pull requests to `main` | `prisma validate`, `prisma format --check`, `prisma generate` — **no** database or secrets required. |

There is **no** workflow that applies migrations in CI; DDL is deployed manually as above.

Connection strings use standard Postgres URLs, for example:

`postgresql://USER:PASSWORD@HOST.example.com:5432/dbname?schema=public&sslmode=require`

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
