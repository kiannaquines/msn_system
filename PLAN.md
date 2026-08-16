# M&S Delivery System — Gemini Takeover Plan

## Objective

Finish, verify, and—only when production configuration and authorization are
available—deploy the three-application M&S Delivery System without changing the
frozen product scope.

## Current Repository State

The repository contains a substantial local implementation:

- FastAPI backend with authentication, rotating refresh tokens, role checks,
  stores, menus, addresses, COD orders, assignments, deliveries, locations,
  feedback, reports, audit records, signed-upload authorization, Mapbox route
  metrics, device tokens, and a Firebase notification outbox.
- Alembic revision `0001` and a separate Supabase SQL migration for private
  Realtime broadcasts, RLS, and `menu-images` Storage.
- Shared Flutter packages for API access, domain models, design, session refresh,
  and two-topic Realtime subscriptions with polling recovery.
- Separate customer, rider, and administrator Flutter source trees.
- Vercel Python Function configuration and production preflight/smoke scripts.

Last locally verified state before Gemini takeover:

- Backend tests: 5 passed.
- Python compilation: passed.
- Clean SQLite Alembic upgrade to `0001`: passed.
- YAML parsing: passed.
- Generated FastAPI OpenAPI document: 39 paths.
- Local Vercel build: passed using Python 3.12.
- A Vercel project was automatically linked as
  `kians-projects-3b7614ec/backend`; nothing was deployed.

Do not treat these historical results as current. Re-run them after inspecting
the working tree.

## Known Gaps and Risks

1. Flutter and Dart were not installed during the preceding implementation.
   Flutter dependency resolution, analyzer, tests, native project generation,
   browser rendering, and release builds have not been executed.
2. The customer and rider folders do not yet contain generated Android/iOS host
   projects. The admin folder does not yet contain the generated Web host.
3. Firebase Messaging initialization and device-token registration are exposed
   by the API but are not fully wired into both mobile apps.
4. The administrator catalog does not yet provide the complete browser image
   picker, signed upload, finalize, menu-item update, replacement, and orphan
   cleanup experience.
5. Storage finalize behavior must verify the Supabase object before recording
   it; orphan replacement/deletion behavior needs tests.
6. The static contract and generated FastAPI OpenAPI need a semantic drift check,
   including aliases where FastAPI names an order identifier as a delivery path
   parameter.
7. Private Realtime RLS has not been proven against a real Supabase project.
8. Firebase outbox delivery, Mapbox production routing, signed uploads, and
   production CORS have not been tested with real services.
9. The required simulation of 20 active riders and 100 tracking viewers does
   not exist yet.
10. No Android APK/AAB, iOS release, Flutter Web release, production backend URL,
    or administrator URL has been produced.

## Phase 1 — Re-establish a Reproducible Baseline

- Inspect the complete repository and current working-tree state before edits.
- Confirm Python 3.12, `uv`, Node, Vercel CLI, Flutter, Dart, Android tooling,
  Xcode, and browser availability without printing environment values.
- Install or select a project-compatible Flutter stable SDK with Dart 3.6 or
  newer. Do not silently modify global machine configuration.
- Run backend tests, compilation, a clean migration, YAML parsing, and a local
  Vercel build.
- Generate Android/iOS/Web host projects only inside their corresponding app
  folders, preserving existing `lib`, `test`, README, analysis, and pubspec files.
- Resolve Flutter dependencies, then run shared-package and app analyzers/tests.

Exit gate: all existing checks execute rather than being inferred, and every
failure is recorded before feature work starts.

## Phase 2 — Contract and Security Audit

- Compare `contracts/openapi.yaml` with `backend/app.main.app.openapi()` by HTTP
  method, normalized path, request fields, response fields, required headers,
  status codes, and enum values.
- Update the static contract and shared Dart client together when drift is real.
- Verify automatic 401 refresh performs one retry, rotates the refresh token,
  clears failed sessions, and never loops.
- Verify customer, rider, and administrator accounts cannot enter another role's
  application after login or restored session.
- Verify retryable checkout, delivery status, rider location, and COD actions
  preserve one stable idempotency key through offline replay.
- Add tests proving JWT `role=authenticated`, separate `business_role`, subject
  identity, expiry, token type, and refresh revocation behavior.
- Audit every order/delivery query for customer ownership, assigned-rider access,
  and administrator access.

Exit gate: no contract mismatch or cross-role/cross-customer access is present.

## Phase 3 — Complete Mobile Platform Integration

Customer application:

- Configure Android and iOS application identifiers and required networking/map
  settings.
- Add Firebase Core and Messaging initialization using platform configuration
  files supplied outside source control.
- Request notification permission at an appropriate time and register refreshed
  FCM tokens through `/api/v1/devices`.
- Verify registration/login, saved GPS addresses, catalog, cart, COD checkout,
  history, receipt details, feedback, notifications, Mapbox tracking, private
  Realtime events, reconnect snapshot recovery, and HTTPS polling fallback.
- Confirm the customer app never requests background-location permission.

Rider application:

- Add exact Android foreground-service/background-location declarations and iOS
  location usage/background modes documented by the rider README.
- Add Firebase Messaging and device-token registration.
- Verify tracking starts only for an assigned active delivery and stops on
  completion, cancellation, assignment removal, or logout.
- Verify 10-second moving and 30-second stationary behavior, unchanged-position
  suppression, visible tracking disclosure, GPS gating, SQLite persistence, and
  idempotent replay after process restart.
- Verify COD must be confirmed before delivery completion.

Exit gate: analyzers and unit/widget/integration tests pass on both apps, with an
Android emulator/device test for permissions and background tracking.

## Phase 4 — Complete Administrator Web Integration

- Verify administrator session restoration, refresh, logout, and role rejection.
- Replace any remaining demo-only production behavior with real API calls while
  retaining explicit `DEMO_MODE=true` for credential-free UI review.
- Complete responsive store/category/menu/pricing/availability management.
- Implement menu image selection with MIME/size validation, signed direct upload,
  finalize, menu record update, replacement, deletion, and user-visible errors.
- Render live authorized rider coordinates on the Mapbox map and refresh the
  authoritative snapshot on Realtime events/reconnect.
- Verify pending-order confirmation/assignment, rider creation, audited
  cancellation, COD state, stale-location indicators, feedback, audit history,
  filters, CSV export, and printable PDF output.
- Visually verify wide desktop, tablet width, empty/loading/error states, dialogs,
  and long datasets in a real browser.

Exit gate: Flutter Web analyze/test/release build succeeds and browser workflows
match the backend contract.

## Phase 5 — Finish Storage, Notifications, and Durable Processing

- Make Storage finalize verify object existence, bucket/path, MIME type, and size
  using backend-only credentials before saving the menu image path.
- Add tests for invalid MIME, oversized files, missing objects, unauthorized
  uploads, replacement, deletion, and orphan cleanup.
- Test Firebase service-account decoding without exposing its contents.
- Mock Firebase for unit tests and verify recipient selection, retry attempts,
  idempotency, failure retention, and processed timestamps.
- Confirm the protected Vercel Cron route never marks a required notification
  complete before Firebase accepts it.
- Review outbox concurrency so overlapping invocations cannot deliver the same
  event twice.

Exit gate: Storage and notification behavior is durable and covered by tests.

## Phase 6 — Supabase Realtime and Load Acceptance

Use a dedicated non-production Supabase project first.

- Apply Alembic `0001`, then the Supabase Realtime/Storage migration.
- Configure Supabase to verify the FastAPI public signing key.
- Prove authorized customer, assigned rider, and administrator subscriptions.
- Prove an unrelated customer and unrelated rider cannot subscribe.
- Prove Flutter clients cannot publish rider locations directly.
- Verify location and status topics, reconnect snapshot recovery, inactive-screen
  subscription closure, delivery-end shutdown, and HTTPS polling fallback.
- Build an automated test harness for at least 20 active riders and 100 tracking
  viewers. Measure authorization failures, API errors, message latency, database
  connections, Realtime connections/messages, and quota consumption.
- Confirm healthy-network location changes are visible within 15 seconds.

Exit gate: authorization isolation and load acceptance evidence is saved without
capturing tokens or customer information.

## Phase 7 — Release Builds

- Scan Flutter compilation inputs and output bundles for private environment
  variable names and recognizable secret material.
- Produce customer and rider testing APKs and release AABs.
- Produce signed iOS release builds only when Apple credentials and profiles are
  supplied securely; otherwise report this as a blocker.
- Produce the administrator release with `flutter build web --release` using
  only public compile-time values.
- Record checksums and absolute artifact paths.

Exit gate: all achievable release builds complete, launch, and point to the
intended API without embedded private secrets.

## Phase 8 — Controlled Production Deployment

Do not begin until the user confirms the exact Supabase and Vercel production
targets and the non-disclosing preflight passes.

1. Validate environment presence using `backend/scripts/deployment_check.py`.
2. Confirm the linked Vercel project and Supabase region are the intended targets.
3. Create and record a Supabase recovery point.
4. Apply Alembic through `DIRECT_DATABASE_URL` outside Function startup.
5. Apply the Supabase Realtime/Storage migration.
6. Run backend and contract tests again.
7. Build and deploy the FastAPI production function.
8. Run health, OpenAPI, authentication, authorization, and lifecycle smoke tests.
9. Deploy the administrator Flutter Web build as a separate Vercel project.
10. Restrict backend CORS to the deployed administrator and approved app origins.
11. Configure mobile production endpoints and run the complete acceptance flow.

Rollback rules:

- Promote the prior Vercel deployment for application regressions.
- Keep migrations backward-compatible and use forward corrective migrations.
- Restore Supabase only when necessary.
- Switch tracking consumers to HTTPS polling when Realtime fails.
- Never discard orders, COD records, audit events, or location history.

## Final Acceptance Scenario

1. Customer registers and saves an address.
2. Administrator creates a rider, store, category, menu item, and signed image.
3. Customer places one idempotent COD order with a server-calculated route fee.
4. Administrator confirms the order and assigns an available rider.
5. Rider receives the assignment, advances valid states, and shares location.
6. Customer and administrator receive only authorized live location/status data.
7. Rider loses connectivity; queued events replay once without duplication.
8. Rider confirms COD and completes delivery.
9. Customer history/receipt and administrator reports update.
10. Customer submits feedback.
11. An unrelated user is denied HTTP and Realtime access.
12. Realtime interruption recovers through polling and later resynchronizes.

## Required Final Handoff

- Production backend and administrator URLs.
- Vercel project and deployment identifiers.
- Applied Alembic revision and Supabase migration confirmation.
- Customer/rider APK and AAB paths with checksums.
- iOS build paths or an explicit signing blocker.
- Administrator Flutter Web build path.
- Backend, Flutter, browser, service-integration, load, and end-to-end results.
- Realtime authorization evidence and observed latency.
- Confirmation that no private secret appears in Flutter artifacts.
- Free-tier connection/message/storage status.
- Rollback procedure and unresolved blockers.

