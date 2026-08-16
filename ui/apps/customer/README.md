# M&S Customer App

Flutter customer experience for browsing M&S stores, creating a single-store
cash-on-delivery order, tracking the assigned rider, viewing receipts, and
submitting delivery feedback.

## Run

The app expects a Flutter release that includes Dart 3.6 or newer and the shared packages in
`../../packages`. Generate the Android and iOS host folders from this directory
when Flutter is installed:

```sh
flutter create --platforms=android,ios .
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=https://your-api.example.com \
  --dart-define=MAPBOX_PUBLIC_TOKEN=your-public-mapbox-token
```

For live tracking, also provide public `SUPABASE_URL` and
`SUPABASE_PUBLISHABLE_KEY` dart defines. The private service-role key is never
used by this app.

Production mode uses the shared typed `mns_api_client` and requires
`API_BASE_URL`. For credential-free UI review, demo data is available only when
explicitly enabled with `--dart-define=DEMO_MODE=true`.

## Verification

```sh
flutter analyze
flutter test
```
