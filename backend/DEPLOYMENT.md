# Vercel deployment handoff

The Vercel project root must be this `backend` directory. Vercel detects the
top-level ASGI `app` in `api/index.py`, reads Python 3.12 from `pyproject.toml`
and `.python-version`, and deploys it as one Python Function in Singapore.

Current Vercel Python guidance recognizes `api/index.py` directly and selects
the Python version from project metadata; an explicit community-runtime value
is neither needed nor used. The function bundle excludes tests, migrations,
local databases, caches, and the virtual environment.

## Required environment

Copy the names in `.env.example` into the Vercel Production environment. Use:

- `DATABASE_URL`: Supabase shared transaction-pooler URL on port 6543.
- `DIRECT_DATABASE_URL`: direct URL on port 5432 for migrations from a
  network with IPv6, or a controlled session-pooler URL on port 5432.
- Matching RSA PEM values for `JWT_SIGNING_PRIVATE_KEY` and
  `JWT_VERIFYING_PUBLIC_KEY`; escaped newlines are accepted.
- A random `CRON_SECRET` of at least 16 characters. Vercel automatically sends
  it as `Authorization: Bearer <CRON_SECRET>` to the configured Cron path.
- Explicit HTTPS origins in `ALLOWED_ORIGINS`; never use `*` in production.

Run the non-disclosing preflight before migration or deployment:

```bash
APP_ENV=production .venv/bin/python scripts/deployment_check.py
```

SQLAlchemy uses no process-local connection pool, disables psycopg automatic
prepared statements, and schema-qualifies application tables. These settings
are required for Supavisor transaction mode and avoid relying on connection
session state.

## Controlled release

From `backend` after linking the correct Vercel project:

```bash
vercel pull --yes --environment=production
APP_ENV=production .venv/bin/python scripts/deployment_check.py
DIRECT_DATABASE_URL="$DIRECT_DATABASE_URL" .venv/bin/alembic upgrade head
vercel build --prod
vercel deploy --prebuilt --prod
.venv/bin/python scripts/smoke_production.py https://DEPLOYED-URL
```

Apply `../supabase/migrations/0002_realtime_and_storage.sql` through the
Supabase migration workflow after Alembic revision `0001` and before accepting
traffic. Never run migrations from FastAPI startup.

The configured outbox Cron runs every ten minutes. Vercel plan-specific Cron
frequency limits must be checked before deployment; if the selected plan cannot
run that frequently, upgrade the plan rather than silently weakening delivery
retries.

## Rollback

Record the Vercel deployment ID and Alembic revision after smoke checks. For an
application regression, promote the prior Vercel deployment. Database revisions
must remain backward compatible; use a forward corrective migration rather than
running a destructive downgrade. If Supabase Realtime is unavailable, retain
HTTPS location ingestion and enable the clients' polling fallback.

References: [Vercel FastAPI](https://vercel.com/docs/frameworks/backend/fastapi),
[Vercel Python runtime](https://vercel.com/docs/functions/runtimes/python),
[Vercel Cron security](https://vercel.com/docs/cron-jobs/manage-cron-jobs), and
[Supabase database connections](https://supabase.com/docs/guides/database/connecting-to-postgres).
