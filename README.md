# M&S Delivery

Contract-first universal delivery platform for M&S Delivery Express.

## Components

- `backend/` - FastAPI REST API for Vercel
- `supabase/` - PostgreSQL and Realtime authorization migrations
- `ui/apps/customer/` - Flutter customer application
- `ui/apps/rider/` - Flutter rider application
- `ui/apps/admin/` - Flutter Web operations dashboard
- `ui/packages/` - shared Dart models, API, authentication, Realtime, and design system
- `contracts/` - public API and event contracts

Copy each component's `.env.example` before running it. Secrets must never be placed in Flutter build configuration.

