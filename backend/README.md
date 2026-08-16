# M&S Delivery Backend

FastAPI is the sole business and write API. Production data is PostgreSQL on
Supabase; Supabase Storage and private Realtime channels are configured by the
SQL migration under `../supabase/migrations`.

## Local verification

```bash
uv venv --python 3.12 .venv
uv pip install --python .venv/bin/python -e '.[test]'
DATABASE_URL=sqlite:///./test.db .venv/bin/alembic upgrade head
DATABASE_URL=sqlite:///./test.db .venv/bin/pytest
```

For production, set both Supabase pooler `DATABASE_URL` and direct
`DIRECT_DATABASE_URL`, apply Alembic first, then apply the Supabase SQL migration.
The local Mapbox distance and Storage URL fallbacks are deterministic development
helpers and are rejected by `/api/health/ready` when `APP_ENV=production`.

Production release commands, environment requirements, smoke checks, and
rollback instructions are in [DEPLOYMENT.md](DEPLOYMENT.md).
