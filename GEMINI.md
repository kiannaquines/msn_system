# Gemini Project Instructions — M&S Delivery System

@./PLAN.md

## Purpose

Take over and finish the M&S Delivery System described in `PLAN.md`. This is a
contract-first delivery platform for customers, riders, and M&S administrators.
Do not claim production completion until every acceptance gate in `PLAN.md` has
been run successfully or is reported as a concrete blocker.

## Architecture

- `backend/`: Python 3.12, FastAPI, SQLAlchemy, Alembic, Pydantic, Supabase
  PostgreSQL, Supabase Storage, Firebase Admin, and Mapbox. It is packaged for a
  Vercel Python Function in Singapore.
- `supabase/`: SQL applied after Alembic for private Realtime broadcasts, RLS,
  and the `menu-images` Storage bucket.
- `contracts/`: frozen HTTP and Realtime contracts. Contract changes require a
  coordinated backend and shared-client update.
- `ui/apps/customer/`: Flutter Android/iOS customer application.
- `ui/apps/rider/`: Flutter Android/iOS rider application.
- `ui/apps/admin/`: Flutter Web administrator dashboard.
- `ui/packages/`: shared Dart API, domain, design, authentication, and Realtime
  packages used by all three applications.

Excluded technologies and features: React, TypeScript UI, MySQL, Supabase Auth,
Redis, backend-hosted WebSockets, online payments, multi-store carts, merchant
self-service, and a single universal Flutter app.

## Non-Negotiable Business Rules

- Cash on delivery is the only payment method.
- One store per order and one active delivery per rider.
- Order lifecycle:
  `pending -> confirmed -> assigned -> picked_up -> on_the_way -> delivered`.
- Cancellation is allowed only through server-authorized transitions.
- Customers access only their own records; riders access only assigned
  deliveries; administrators use explicit administrative endpoints.
- Retryable writes require stable `Idempotency-Key` values.
- Only FastAPI may ingest rider locations or write application data.
- Flutter clients may subscribe to private Supabase Realtime topics but must
  never publish locations directly or access PostgreSQL directly.
- Sensitive administrative actions require an audit reason.

## Coding Conventions

- Read the target file and its callers before editing. Make the smallest change
  that satisfies a verified requirement; avoid unrelated refactors.
- Preserve `/api/v1` routes, response fields, enum wire values, Realtime topics,
  and idempotency behavior unless the contract is deliberately updated.
- Alembic is the sole application-schema migration authority. Never create or
  alter application tables at FastAPI startup.
- Keep authorization and business transitions server-side.
- Backend services must not depend on local filesystem persistence, process
  memory, or required FastAPI background tasks because Vercel is serverless.
- Shared Dart packages contain reusable contracts and infrastructure. Do not
  duplicate shared models, authentication refresh logic, or design tokens in an
  individual application.
- Use Riverpod for Flutter state and `MnsTheme`/the shared design system for UI.
- Production Flutter builds must require explicit public configuration. Demo
  data is allowed only behind `--dart-define=DEMO_MODE=true`.
- Never invent API payloads. Compare `contracts/openapi.yaml`, FastAPI's
  generated OpenAPI document, and `ui/packages/api_client` before changing a
  consumer.

## Security Boundaries

- Never open, print, copy, modify, commit, or summarize `.env`, `.env.*`, Vercel
  downloaded environment files, credentials, signing material, service-account
  JSON, or private keys. `.env.example` is safe to inspect.
- Never put `SUPABASE_SECRET_KEY`, `MAPBOX_SECRET_TOKEN`, Firebase service
  credentials, database passwords, or JWT signing keys into Flutter, logs,
  documentation, fixtures, screenshots, or chat output.
- Flutter may contain only public values such as API URL, Supabase URL,
  Supabase publishable key, and Mapbox public token.
- Do not deploy, apply production migrations, restore a database, change RLS,
  rotate credentials, promote a Vercel deployment, or publish mobile builds
  without first showing the exact target and completing the relevant preflight.
- Never run migrations during Vercel Function startup.
- Do not weaken role checks, private Realtime authorization, audit requirements,
  or idempotency to make a test pass.
- Preserve submitted orders, COD records, audit history, and rider location
  history during rollback.

## Required Verification

Run the narrow relevant checks while iterating and the complete applicable set
before reporting completion.

Backend:

```sh
cd backend
uv sync --extra test
.venv/bin/python -m compileall -q app api scripts
.venv/bin/pytest -q
DATABASE_URL=sqlite:////tmp/mns-gemini-migration.db .venv/bin/alembic upgrade head
vercel build --yes
```

Flutter packages and applications, after installing Flutter with Dart 3.6 or
newer and generating the missing host projects as directed by each app README:

```sh
cd ui
flutter pub get
flutter analyze
flutter test

cd apps/customer
flutter analyze && flutter test

cd ../rider
flutter analyze && flutter test

cd ../admin
flutter analyze && flutter test
flutter build web --release \
  --dart-define=API_BASE_URL=https://YOUR_API_URL \
  --dart-define=MAPBOX_PUBLIC_TOKEN=YOUR_PUBLIC_TOKEN
```

Never use a real secret in a command shown in a report. Android, iOS, Realtime,
Storage, Firebase, load, and production smoke verification must follow the gates
in `PLAN.md`.

## Completion Reporting

Lead with what works. Then list every command run and its result, generated
artifact paths, deployed URLs and identifiers when applicable, Alembic revision,
and unresolved blockers. Distinguish source inspection from executed tests and
local builds from production verification. Plausible source code is not proof.

