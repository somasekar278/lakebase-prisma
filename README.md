# Lakebase Prisma migrations

One **Prisma** schema and one history under `prisma/migrations/`. We **replay** that SQL on a **primary** Lakebase branch and up to **two children**—same files, different URLs. **DDL runs from your machine**; we skip GitHub `migrate deploy` because **IP ACL** usually blocks hosted runners.

## End-to-end

1. **`.env`** — From `.env.example`: set `DATABASE_URL`, `SHADOW_DATABASE_URL` (empty primary scratch DB for `migrate dev`), and for all three targets add `DATABASE_URL_CHILD_1` and `DATABASE_URL_CHILD_2` (primary can be `DATABASE_URL` only).

2. **Setup** — `npm install`, `npm run db:generate`.

3. **Change schema** — Edit `prisma/schema.prisma`, then `npm run db:migrate:dev -- --name your_change`. Commit schema + new `prisma/migrations/*` folders.

4. **Apply** — **One DB:** `npm run db:migrate:deploy`. **Primary + both children:** `./scripts/migrate-all-local.sh` (root → child 1 → child 2). The script loads `.env` (including `&` in query strings) and uses your `SHADOW_DATABASE_URL` so Prisma never treats shadow and target as the same DB.

5. **Grants** — The migration role must have **DDL on `public`** on every branch you hit, not just primary.

6. **Optional** — `pr-validate.yml` on PRs: validate, format, generate; no DB.

## Commands

| Command | Purpose |
|---------|---------|
| `npm run db:migrate:dev -- --name x` | Author a migration |
| `npm run db:migrate:deploy` | Deploy to `DATABASE_URL` only |
| `./scripts/migrate-all-local.sh` | Deploy to primary + both children |

Use standard Postgres URLs (see `.env.example`). This is **schema delivery** only, not data sync between branches.
